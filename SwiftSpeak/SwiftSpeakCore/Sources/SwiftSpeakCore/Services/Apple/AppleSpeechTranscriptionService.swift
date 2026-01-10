//
//  AppleSpeechTranscriptionService.swift
//  SwiftSpeakCore
//
//  On-device speech recognition using Apple's Speech framework (SFSpeechRecognizer)
//  Supports iOS 10+/macOS 10.15+ with enhanced features on iOS 17+/macOS 14+
//
//  Features:
//  - On-device processing (privacy-first)
//  - 50+ languages supported
//  - contextualStrings for vocabulary hints (up to 100 phrases) [All versions]
//  - iOS 17+/macOS 14+: SFCustomLanguageModelData for advanced vocabulary boosting
//    - Custom pronunciations using X-SAMPA notation
//    - Template patterns for phrase generation
//    - Weighted phrase counts
//

import Foundation
import Speech

// MARK: - Apple Speech Configuration

/// Configuration for Apple Speech vocabulary customization
public struct AppleSpeechVocabularyConfig: Codable, Equatable, Sendable {

    /// Simple vocabulary hints (used via contextualStrings, all iOS versions)
    public var phrases: [String]

    /// Weighted phrases with counts (iOS 17+ only)
    /// Higher count = more likely to be recognized
    public var weightedPhrases: [WeightedPhrase]

    /// Custom pronunciations using X-SAMPA notation (iOS 17+ only)
    public var pronunciations: [CustomPronunciation]

    /// Template patterns for generating phrase variations (iOS 17+ only)
    public var templates: [PhraseTemplate]

    /// Whether to prefer on-device recognition (true by default for privacy)
    public var requireOnDevice: Bool

    public init(
        phrases: [String] = [],
        weightedPhrases: [WeightedPhrase] = [],
        pronunciations: [CustomPronunciation] = [],
        templates: [PhraseTemplate] = [],
        requireOnDevice: Bool = true
    ) {
        self.phrases = phrases
        self.weightedPhrases = weightedPhrases
        self.pronunciations = pronunciations
        self.templates = templates
        self.requireOnDevice = requireOnDevice
    }

    /// Simple initializer with just phrase hints
    public init(phrases: [String]) {
        self.phrases = phrases
        self.weightedPhrases = []
        self.pronunciations = []
        self.templates = []
        self.requireOnDevice = true
    }

    /// Whether iOS 17+ features are being used
    public var usesAdvancedFeatures: Bool {
        !weightedPhrases.isEmpty || !pronunciations.isEmpty || !templates.isEmpty
    }
}

/// A phrase with a weight/count for training (iOS 17+)
public struct WeightedPhrase: Codable, Equatable, Sendable {
    public var phrase: String
    public var count: Int  // Higher = more likely to be recognized

    public init(phrase: String, count: Int = 10) {
        self.phrase = phrase
        self.count = max(1, count)
    }
}

/// Custom pronunciation using X-SAMPA notation (iOS 17+)
public struct CustomPronunciation: Codable, Equatable, Sendable {
    public var grapheme: String        // Written form (e.g., "Winawer")
    public var phonemes: [String]      // X-SAMPA pronunciations (e.g., ["w I n aU @r"])

    public init(grapheme: String, phonemes: [String]) {
        self.grapheme = grapheme
        self.phonemes = phonemes
    }

    /// Convenience initializer with single pronunciation
    public init(grapheme: String, phoneme: String) {
        self.grapheme = grapheme
        self.phonemes = [phoneme]
    }
}

/// Template pattern for generating phrase variations (iOS 17+)
public struct PhraseTemplate: Codable, Equatable, Sendable {
    /// Named word classes that can be substituted in the template
    /// e.g., ["prefix": ["Let's", "Please"], "action": ["play", "start"]]
    public var classes: [String: [String]]

    /// Template pattern using class names in angle brackets
    /// e.g., "<prefix> <action> the game"
    public var template: String

    /// Count per generated phrase
    public var count: Int

    public init(classes: [String: [String]], template: String, count: Int = 10) {
        self.classes = classes
        self.template = template
        self.count = max(1, count)
    }
}

// MARK: - Apple Speech Transcription Service

/// Apple Speech Recognition transcription service using SFSpeechRecognizer
/// Provides on-device speech-to-text without requiring an API key
public final class AppleSpeechTranscriptionService: TranscriptionProvider, @unchecked Sendable {

    // MARK: - TranscriptionProvider

    public let providerId: AIProvider = .appleSpeech

    public var isConfigured: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    public var model: String {
        if #available(iOS 17, macOS 14, *) {
            return "on-device-v2"  // iOS 17+ enhanced model with custom LM support
        }
        return "on-device"
    }

    // MARK: - Properties

    private let defaultLocale: Locale

    /// Vocabulary configuration for customizing speech recognition
    public var vocabularyConfig: AppleSpeechVocabularyConfig

    /// Simple vocabulary hints (convenience accessor)
    public var vocabularyHints: [String] {
        get { vocabularyConfig.phrases }
        set { vocabularyConfig.phrases = newValue }
    }

    /// Cached custom language model URL (iOS 17+)
    private var customLanguageModelURL: URL?

    /// Whether the custom language model needs to be rebuilt
    private var languageModelNeedsRebuild: Bool = true

    // MARK: - Initialization

    public init(locale: Locale = .current) {
        self.defaultLocale = locale
        self.vocabularyConfig = AppleSpeechVocabularyConfig()
    }

    public convenience init?(config: AIProviderConfig) {
        guard config.provider == .appleSpeech else { return nil }
        self.init()
    }

    /// Initialize with vocabulary hints (simple mode)
    public convenience init(vocabulary: [String], locale: Locale = .current) {
        self.init(locale: locale)
        self.vocabularyConfig = AppleSpeechVocabularyConfig(phrases: vocabulary)
    }

    /// Initialize with full vocabulary configuration (iOS 17+ features)
    public convenience init(config: AppleSpeechVocabularyConfig, locale: Locale = .current) {
        self.init(locale: locale)
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

    /// Check current authorization status
    public static var authorizationStatus: SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    // MARK: - Custom Language Model (iOS 17+)

    /// Prepare the custom language model for iOS 17+ (call off main thread)
    /// This should be called during app launch or when vocabulary changes
    @available(iOS 17, macOS 14, *)
    public func prepareCustomLanguageModel(for locale: Locale) async throws {
        guard vocabularyConfig.usesAdvancedFeatures else { return }
        guard languageModelNeedsRebuild else { return }

        // Build training data
        let trainingData = try buildCustomLanguageModelData(for: locale)

        // Export to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let trainingDataURL = tempDir.appendingPathComponent("swiftspeak_lm_training_\(locale.identifier).bin")

        try await trainingData.export(to: trainingDataURL)

        // Prepare the custom language model (this is the expensive operation)
        // The output is written to a directory adjacent to the input
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
        // Create the custom language model data using the result builder
        return try SFCustomLanguageModelData(
            locale: locale,
            identifier: "com.swiftspeak.customlm",
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

    // MARK: - Transcription

    public func transcribe(audioURL: URL, language: Language?, promptHint: String?) async throws -> String {
        // Check authorization
        let status = SFSpeechRecognizer.authorizationStatus()
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

        // Verify file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.audioFileNotFound
        }

        // Determine locale
        let locale: Locale
        if let lang = language {
            locale = Locale(identifier: lang.appleSpeechCode)
        } else {
            locale = defaultLocale
        }

        // Create speech recognizer for the locale
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw TranscriptionError.speechRecognitionNotAvailable
        }

        guard recognizer.isAvailable else {
            throw TranscriptionError.speechRecognitionNotAvailable
        }

        // Create recognition request
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation

        // Build contextual strings from vocabulary and prompt hints
        var contextualStrings: [String] = []

        // Add vocabulary hints
        contextualStrings.append(contentsOf: vocabularyConfig.phrases)

        // Add weighted phrases as contextual strings (works on all versions)
        for weighted in vocabularyConfig.weightedPhrases {
            contextualStrings.append(weighted.phrase)
        }

        // Add phrases from prompt hint
        if let hint = promptHint, !hint.isEmpty {
            contextualStrings.append(contentsOf: extractContextualStrings(from: hint))
        }

        // Set contextual strings (limit to 100 as per Apple docs)
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

        // Perform recognition
        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == "kAFAssistantErrorDomain" {
                        switch nsError.code {
                        case 1110:
                            continuation.resume(throwing: TranscriptionError.emptyResponse)
                        case 1700:
                            continuation.resume(throwing: TranscriptionError.languageNotSupported(locale.identifier))
                        default:
                            continuation.resume(throwing: TranscriptionError.transcriptionFailed(error.localizedDescription))
                        }
                    } else {
                        continuation.resume(throwing: TranscriptionError.transcriptionFailed(error.localizedDescription))
                    }
                    return
                }

                guard let result = result else {
                    continuation.resume(throwing: TranscriptionError.emptyResponse)
                    return
                }

                if result.isFinal {
                    let transcription = result.bestTranscription.formattedString
                    if transcription.isEmpty {
                        continuation.resume(throwing: TranscriptionError.emptyResponse)
                    } else {
                        continuation.resume(returning: transcription)
                    }
                }
            }
        }
    }

    public func validateAPIKey(_ key: String) async -> Bool {
        return SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    // MARK: - Helpers

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

    public static func isLanguageSupported(_ language: Language) -> Bool {
        supportedLocales.contains { $0.identifier.hasPrefix(language.rawValue) }
    }

    // MARK: - iOS 17+ Feature Detection

    /// Whether advanced language model features are available
    public static var supportsCustomLanguageModel: Bool {
        if #available(iOS 17, macOS 14, *) {
            return true
        }
        return false
    }
}
