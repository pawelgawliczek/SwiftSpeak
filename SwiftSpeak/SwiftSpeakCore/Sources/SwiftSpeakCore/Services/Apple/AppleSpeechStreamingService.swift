//
//  AppleSpeechStreamingService.swift
//  SwiftSpeakCore
//
//  Real-time streaming speech recognition using Apple's Speech framework
//  Uses SFSpeechAudioBufferRecognitionRequest for live audio processing
//  Works on iOS 10+ and macOS 10.15+ with enhanced features on iOS 17+/macOS 14+
//
//  iOS 17+ Features:
//  - SFCustomLanguageModelData for vocabulary boosting
//  - Custom pronunciations using X-SAMPA notation
//  - Template patterns for phrase generation
//

import Foundation
import Speech
import Combine
import AVFoundation

/// Apple Speech Recognition streaming service using SFSpeechAudioBufferRecognitionRequest
/// Provides real-time speech-to-text without requiring an API key
public final class AppleSpeechStreamingService: NSObject, StreamingTranscriptionProvider, @unchecked Sendable {

    // MARK: - StreamingTranscriptionProvider

    public let providerId: AIProvider = .appleSpeech

    public var isConfigured: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    public var supportsStreaming: Bool { true }

    public private(set) var connectionState: StreamingConnectionState = .disconnected

    public weak var delegate: StreamingTranscriptionDelegate?

    public var partialsAreDelta: Bool { false }  // Apple sends full replacement text

    public private(set) var fullTranscript: String = ""

    // MARK: - Publishers

    private let partialTranscriptSubject = PassthroughSubject<String, Never>()
    private let finalTranscriptSubject = PassthroughSubject<String, Never>()
    private let sessionEndedSubject = PassthroughSubject<Void, Never>()

    public var partialTranscriptPublisher: AnyPublisher<String, Never> {
        partialTranscriptSubject.eraseToAnyPublisher()
    }

    public var finalTranscriptPublisher: AnyPublisher<String, Never> {
        finalTranscriptSubject.eraseToAnyPublisher()
    }

    public var sessionEndedPublisher: AnyPublisher<Void, Never> {
        sessionEndedSubject.eraseToAnyPublisher()
    }

    // MARK: - Properties

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioFormat: AVAudioFormat?
    private var currentLanguage: Language?

    private let queue = DispatchQueue(label: "com.swiftspeak.applespeech.streaming", qos: .userInitiated)

    /// Vocabulary configuration for customizing speech recognition
    public var vocabularyConfig: AppleSpeechVocabularyConfig = AppleSpeechVocabularyConfig()

    /// Cached custom language model URL (iOS 17+)
    private var customLanguageModelURL: URL?

    /// Whether the custom language model needs to be rebuilt
    private var languageModelNeedsRebuild: Bool = true

    // MARK: - Initialization

    public override init() {
        super.init()
    }

    /// Initialize with vocabulary configuration
    public convenience init(config: AppleSpeechVocabularyConfig) {
        self.init()
        self.vocabularyConfig = config
    }

    // MARK: - Authorization

    /// Request speech recognition authorization
    public static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // MARK: - Custom Language Model (iOS 17+)

    /// Prepare the custom language model for iOS 17+ (call off main thread)
    @available(iOS 17, macOS 14, *)
    public func prepareCustomLanguageModel(for locale: Locale) async throws {
        guard vocabularyConfig.usesAdvancedFeatures else { return }
        guard languageModelNeedsRebuild else { return }

        // Build training data
        let trainingData = try buildCustomLanguageModelData(for: locale)

        // Export to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let trainingDataURL = tempDir.appendingPathComponent("swiftspeak_stream_lm_training_\(locale.identifier).bin")

        try await trainingData.export(to: trainingDataURL)

        // Prepare the custom language model
        try await SFSpeechLanguageModel.prepareCustomLanguageModel(
            for: trainingDataURL,
            configuration: SFSpeechLanguageModel.Configuration(),
            ignoresCache: false
        )

        // The prepared model is at the same location as the training data
        customLanguageModelURL = trainingDataURL
        languageModelNeedsRebuild = false
    }

    /// Build SFCustomLanguageModelData from our configuration
    @available(iOS 17, macOS 14, *)
    private func buildCustomLanguageModelData(for locale: Locale) throws -> SFCustomLanguageModelData {
        return try SFCustomLanguageModelData(
            locale: locale,
            identifier: "com.swiftspeak.customlm.streaming",
            version: "1.0"
        ) {
            // Add weighted phrases
            for weighted in vocabularyConfig.weightedPhrases {
                SFCustomLanguageModelData.PhraseCount(
                    phrase: weighted.phrase,
                    count: weighted.count
                )
            }

            // Add pronunciations
            for pronunciation in vocabularyConfig.pronunciations {
                SFCustomLanguageModelData.CustomPronunciation(
                    grapheme: pronunciation.grapheme,
                    phonemes: pronunciation.phonemes
                )
            }

            // Add template-based phrases
            for template in vocabularyConfig.templates {
                for phrase in generatePhrasesFromTemplate(template) {
                    SFCustomLanguageModelData.PhraseCount(
                        phrase: phrase,
                        count: template.count
                    )
                }
            }
        }
    }

    /// Generate all phrase variations from a template
    private func generatePhrasesFromTemplate(_ template: PhraseTemplate) -> [String] {
        var results: [String] = [template.template]

        for (className, options) in template.classes {
            var newResults: [String] = []
            let placeholder = "<\(className)>"

            for result in results {
                if result.contains(placeholder) {
                    for option in options {
                        newResults.append(result.replacingOccurrences(of: placeholder, with: option))
                    }
                } else {
                    newResults.append(result)
                }
            }
            results = newResults
        }

        return results
    }

    /// Mark that the language model needs rebuilding (call when vocabulary changes)
    public func invalidateLanguageModel() {
        languageModelNeedsRebuild = true
        customLanguageModelURL = nil
    }

    // MARK: - StreamingTranscriptionProvider Methods

    public func connect(language: Language?, sampleRate: Int, transcriptionPrompt: String?, instructions: String?) async throws {
        print("[AppleSpeech] connect() called - language: \(language?.displayName ?? "auto"), sampleRate: \(sampleRate)")

        // Reset counters for new session
        totalAudioBytesReceived = 0
        audioChunkCount = 0

        // Check authorization
        let status = SFSpeechRecognizer.authorizationStatus()
        print("[AppleSpeech] Authorization status: \(status.rawValue)")
        switch status {
        case .notDetermined:
            let authorized = await Self.requestAuthorization()
            if !authorized {
                throw TranscriptionError.speechRecognitionPermissionDenied
            }
        case .denied, .restricted:
            throw TranscriptionError.speechRecognitionPermissionDenied
        case .authorized:
            break
        @unknown default:
            throw TranscriptionError.speechRecognitionPermissionDenied
        }

        // Update state
        updateConnectionState(.connecting)

        // Determine locale
        let locale: Locale
        if let lang = language {
            locale = Locale(identifier: lang.appleSpeechCode)
            currentLanguage = lang
        } else {
            locale = .current
            currentLanguage = nil
        }

        // Create speech recognizer for the locale
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            updateConnectionState(.error("Language not supported"))
            throw TranscriptionError.speechRecognitionNotAvailable
        }

        guard recognizer.isAvailable else {
            updateConnectionState(.error("Speech recognition unavailable"))
            throw TranscriptionError.speechRecognitionNotAvailable
        }

        speechRecognizer = recognizer
        print("[AppleSpeech] Recognizer created for locale: \(locale.identifier), supportsOnDevice: \(recognizer.supportsOnDeviceRecognition)")

        // Check if on-device is available - required for background/SwiftLink mode
        // Cloud-based recognition doesn't work reliably when app is in background
        if !recognizer.supportsOnDeviceRecognition {
            print("[AppleSpeech] ERROR: On-device recognition not available for \(locale.identifier). Cannot use Apple Speech for this language in background mode.")
            updateConnectionState(.error("Language \(locale.identifier) requires on-device model. Download it in Settings > General > Keyboard > Dictation Languages, or use a cloud provider."))
            throw TranscriptionError.languageNotSupported(locale.identifier)
        }

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        print("[AppleSpeech] Recognition request created")

        // Build contextual strings from vocabulary and prompt hints
        var contextualStrings: [String] = []
        contextualStrings.append(contentsOf: vocabularyConfig.phrases)

        // Add weighted phrases as contextual strings
        for weighted in vocabularyConfig.weightedPhrases {
            contextualStrings.append(weighted.phrase)
        }

        // Add contextual strings from prompt
        if let prompt = transcriptionPrompt, !prompt.isEmpty {
            contextualStrings.append(contentsOf: extractContextualStrings(from: prompt))
        }

        // Set contextual strings (limit to 100)
        if !contextualStrings.isEmpty {
            request.contextualStrings = Array(Set(contextualStrings).prefix(100))
        }

        // Configure on-device and custom language model (iOS 17+)
        if #available(iOS 17, macOS 14, *) {
            // Always use on-device for privacy when supported
            if recognizer.supportsOnDeviceRecognition && vocabularyConfig.requireOnDevice {
                request.requiresOnDeviceRecognition = true
            }

            // Prepare custom language model if needed
            if vocabularyConfig.usesAdvancedFeatures {
                try await prepareCustomLanguageModel(for: locale)

                // Set the custom language model on the request
                if let modelURL = customLanguageModelURL {
                    request.customizedLanguageModel = SFSpeechLanguageModel.Configuration(
                        languageModel: modelURL
                    )
                }
            }
        } else if #available(iOS 13, macOS 10.15, *) {
            // Pre-iOS 17: Prefer on-device when available
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        }

        recognitionRequest = request

        // Configure audio format for the expected sample rate
        audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(sampleRate),
            channels: 1,
            interleaved: true
        )

        if let fmt = audioFormat {
            print("[AppleSpeech] Audio format configured: \(fmt.sampleRate)Hz, \(fmt.channelCount) ch, interleaved: \(fmt.isInterleaved)")
        } else {
            print("[AppleSpeech] ERROR: Failed to create audio format!")
        }

        // Reset transcript and tracking
        fullTranscript = ""
        accumulatedTranscript = ""
        lastPartialLength = 0

        // Start recognition task
        print("[AppleSpeech] Starting recognition task...")
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error)
        }

        print("[AppleSpeech] Recognition task started, connected!")
        updateConnectionState(.connected)
    }

    /// Track total audio bytes received for logging
    private var totalAudioBytesReceived: Int = 0
    private var audioChunkCount: Int = 0

    public func sendAudio(_ audioData: Data) {
        guard let request = recognitionRequest,
              let format = audioFormat else {
            print("[AppleSpeech] sendAudio: No request or format available")
            return
        }

        audioChunkCount += 1
        totalAudioBytesReceived += audioData.count

        // Log every 10th chunk to avoid spam
        if audioChunkCount % 10 == 1 {
            print("[AppleSpeech] sendAudio: chunk #\(audioChunkCount), \(audioData.count) bytes, total: \(totalAudioBytesReceived) bytes")
        }

        queue.async { [weak self] in
            // Convert raw PCM16 data to AVAudioPCMBuffer
            let frameCount = UInt32(audioData.count) / 2  // 2 bytes per Int16 sample

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                print("[AppleSpeech] sendAudio: Failed to create audio buffer")
                return
            }

            buffer.frameLength = frameCount

            // Copy audio data to buffer - use floatChannelData for non-interleaved or int16ChannelData
            audioData.withUnsafeBytes { rawBufferPointer in
                if let baseAddress = rawBufferPointer.baseAddress {
                    if let channelData = buffer.int16ChannelData?[0] {
                        memcpy(channelData, baseAddress, audioData.count)
                    } else {
                        print("[AppleSpeech] sendAudio: int16ChannelData is nil!")
                    }
                }
            }

            // Append to recognition request
            request.append(buffer)
        }
    }

    public func finishAudio() {
        print("[AppleSpeech] finishAudio() called - total received: \(totalAudioBytesReceived) bytes in \(audioChunkCount) chunks")
        queue.async { [weak self] in
            self?.recognitionRequest?.endAudio()
            print("[AppleSpeech] endAudio() called on recognition request")
        }
    }

    public func disconnect() {
        queue.async { [weak self] in
            self?.recognitionTask?.cancel()
            self?.recognitionTask = nil
            self?.recognitionRequest = nil
            self?.speechRecognizer = nil

            DispatchQueue.main.async {
                self?.updateConnectionState(.disconnected)
            }
        }
    }

    // MARK: - Private Methods

    /// Accumulated transcript from previous "segments" (when Apple resets on pause)
    private var accumulatedTranscript: String = ""

    /// Last known partial length (to detect resets)
    private var lastPartialLength: Int = 0

    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            let nsError = error as NSError
            print("[AppleSpeech] Recognition error: domain=\(nsError.domain), code=\(nsError.code), msg=\(error.localizedDescription)")
            let transcriptionError: TranscriptionError

            if nsError.domain == "kAFAssistantErrorDomain" {
                switch nsError.code {
                case 1110: // No speech detected
                    print("[AppleSpeech] Error 1110: No speech detected")
                    transcriptionError = .emptyResponse
                case 1700: // Language not available
                    print("[AppleSpeech] Error 1700: Language not available")
                    transcriptionError = .languageNotSupported(currentLanguage?.appleSpeechCode ?? "unknown")
                default:
                    transcriptionError = .transcriptionFailed(error.localizedDescription)
                }
            } else {
                transcriptionError = .transcriptionFailed(error.localizedDescription)
            }

            DispatchQueue.main.async { [weak self] in
                self?.delegate?.didEncounterError(transcriptionError)
                self?.updateConnectionState(.error(error.localizedDescription))
            }
            return
        }

        guard let result = result else {
            print("[AppleSpeech] handleRecognitionResult: result is nil")
            return
        }

        let currentTranscript = result.bestTranscription.formattedString
        print("[AppleSpeech] Result: isFinal=\(result.isFinal), transcript='\(currentTranscript.prefix(50))...'")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if result.isFinal {
                // Final result - combine accumulated + current
                let finalText = self.accumulatedTranscript.isEmpty
                    ? currentTranscript
                    : self.accumulatedTranscript + " " + currentTranscript
                self.fullTranscript = finalText
                self.finalTranscriptSubject.send(finalText)
                self.delegate?.didReceiveFinalTranscript(finalText)
                self.sessionEndedSubject.send()
            } else {
                // Partial result - check if Apple reset the transcript (pause detection)
                // If the new partial is shorter than the last one and doesn't start with
                // the same content, Apple has started a new segment
                if currentTranscript.count < self.lastPartialLength &&
                   self.lastPartialLength > 10 &&
                   !self.fullTranscript.isEmpty {
                    // Apple reset on pause - save the previous transcript as accumulated
                    self.accumulatedTranscript = self.fullTranscript
                }

                // Update tracking
                self.lastPartialLength = currentTranscript.count
                self.fullTranscript = currentTranscript

                // Send combined transcript (accumulated + current)
                let combinedTranscript = self.accumulatedTranscript.isEmpty
                    ? currentTranscript
                    : self.accumulatedTranscript + " " + currentTranscript

                self.partialTranscriptSubject.send(combinedTranscript)
                self.delegate?.didReceivePartialTranscript(combinedTranscript)
            }
        }
    }

    private func updateConnectionState(_ state: StreamingConnectionState) {
        connectionState = state
        delegate?.connectionStateDidChange(state)
    }

    private func extractContextualStrings(from hint: String) -> [String] {
        var strings: [String] = []

        let patterns = ["Common terms:", "Terms:", "Names:", "Vocabulary:"]
        for pattern in patterns {
            if let range = hint.range(of: pattern, options: .caseInsensitive) {
                let afterPattern = hint[range.upperBound...]
                let endIndex = afterPattern.firstIndex(of: ".") ?? afterPattern.endIndex
                let termsString = afterPattern[..<endIndex]
                let terms = termsString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                strings.append(contentsOf: terms)
            }
        }

        return strings
    }

    // MARK: - Supported Languages

    public static var supportedLocales: Set<Locale> {
        SFSpeechRecognizer.supportedLocales()
    }
}
