//
//  MacTranscribeOverlayViewModel.swift
//  SwiftSpeakMac
//
//  ViewModel for the Transcribe overlay
//  Handles transcription, context auto-selection, and translation toggle
//

import SwiftUI
import Combine
import SwiftSpeakCore

// MARK: - Transcribe Overlay State

enum TranscribeOverlayState: Equatable {
    case idle              // Overlay not visible
    case ready             // Overlay visible, waiting to record
    case initializing      // Audio engine starting up (new state)
    case recording         // Recording audio
    case transcribing      // Transcribing audio
    case formatting        // Formatting transcription
    case inserting         // Inserting text into target app (new state)
    case complete          // Transcription complete
    case error(String)     // Error state

    var statusText: String {
        switch self {
        case .idle: return ""
        case .ready: return "Ready"
        case .initializing: return "Preparing..."
        case .recording: return "Recording"
        case .transcribing: return "Transcribing..."
        case .formatting: return "Formatting..."
        case .inserting: return "Inserting..."
        case .complete: return "Complete"
        case .error: return "Error"
        }
    }

    var isProcessing: Bool {
        switch self {
        case .transcribing, .formatting, .inserting:
            return true
        default:
            return false
        }
    }

    /// Whether audio is being actively captured (for waveform display)
    var isActivelyRecording: Bool {
        self == .recording
    }
}

// MARK: - Transcribe Mode

enum TranscribeMode {
    case toggle      // User toggled the overlay (stays open until dismissed)
    case pushToTalk  // User is holding the hotkey (closes on release)
}

// MARK: - Streaming Delegate Bridge
// This class bridges streaming provider delegate calls to the MainActor view model

private class StreamingDelegateBridge: StreamingTranscriptionDelegate {
    weak var viewModel: MacTranscribeOverlayViewModel?
    let partialsAreDelta: Bool

    init(viewModel: MacTranscribeOverlayViewModel, partialsAreDelta: Bool) {
        self.viewModel = viewModel
        self.partialsAreDelta = partialsAreDelta
    }

    func didReceivePartialTranscript(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let vm = self.viewModel else { return }
            if self.partialsAreDelta {
                vm.liveTranscript += text
            } else {
                vm.liveTranscript = vm.streamingFullTranscript + text
            }
        }
    }

    func didReceiveFinalTranscript(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let vm = self.viewModel else { return }
            vm.streamingFullTranscript += text + " "
            vm.liveTranscript = vm.streamingFullTranscript
        }
    }

    func didEncounterError(_ error: TranscriptionError) {
        DispatchQueue.main.async { [weak self] in
            guard let vm = self?.viewModel else { return }
            macLog("Streaming error: \(error)", category: "Streaming", level: .error)
            vm.errorMessage = error.errorDescription
            vm.streamingConnectionErrorOccurred = true
        }
    }

    func connectionStateDidChange(_ state: StreamingConnectionState) {
        // Only log errors, not normal state changes
    }
}

// MARK: - MacTranscribeOverlayViewModel

@MainActor
final class MacTranscribeOverlayViewModel: ObservableObject {

    // MARK: - Published State

    @Published var state: TranscribeOverlayState = .idle {
        didSet {
            macLog("🔄 State changed: \(oldValue) → \(state)", category: "Transcribe")
        }
    }
    @Published var mode: TranscribeMode = .toggle

    /// Active context (auto-detected or manually selected)
    @Published var activeContext: ConversationContext?

    /// Translation enabled
    @Published var isTranslationEnabled: Bool = false

    /// Target language for translation
    @Published var targetLanguage: Language = .english

    /// Effective input language (from context or system default)
    @Published var inputLanguage: Language?

    /// Effective audio quality being used (resolved from auto)
    @Published private(set) var effectiveAudioQuality: AudioQualityMode = .high

    /// Live transcript during recording (if streaming available)
    @Published var liveTranscript: String = ""

    /// Final transcribed text
    @Published var transcribedText: String = ""

    /// Recording duration
    @Published var recordingDuration: TimeInterval = 0

    /// Audio level for visualization
    @Published var audioLevel: Float = 0

    /// Error message
    @Published var errorMessage: String?

    /// Source app info (for auto-context detection)
    @Published var sourceAppName: String = ""
    @Published var sourceAppBundleId: String = ""

    /// Signals that insertion is complete and overlay should close
    @Published var shouldAutoClose: Bool = false

    // MARK: - Dependencies

    let settings: MacSettings
    private let audioRecorder: MacAudioRecorder
    private var providerFactory: ProviderFactory?
    private var textInsertion: MacTextInsertionService?

    /// Callback to hide overlay before text insertion (set by controller)
    var onWillInsertText: (() -> Void)?

    // MARK: - Internal State

    private var cancellables = Set<AnyCancellable>()
    private var recordingTimer: Timer?
    private var previousApp: NSRunningApplication?

    /// Pre-captured context from hotkey callback
    private var preCapturedContext: HotkeyContext?

    /// Last recorded audio URL - stored for retry functionality
    private var lastRecordingURL: URL?

    // MARK: - Streaming State

    /// Whether this session is using streaming transcription
    private var isStreamingSession: Bool = false

    /// Active streaming provider (when streaming)
    private var streamingProvider: StreamingTranscriptionProvider?

    /// Streaming audio recorder (when streaming)
    private var streamingAudioRecorder: MacStreamingAudioRecorder?

    /// Accumulated full transcript from finals (when streaming)
    /// Note: fileprivate for delegate bridge access
    fileprivate var streamingFullTranscript: String = ""

    /// Whether a streaming connection error occurred (for batch fallback decision)
    fileprivate var streamingConnectionErrorOccurred: Bool = false

    /// Delegate bridge for streaming provider
    private var streamingDelegateBridge: StreamingDelegateBridge?

    // MARK: - Initialization

    init(
        settings: MacSettings,
        audioRecorder: MacAudioRecorder
    ) {
        self.settings = settings
        self.audioRecorder = audioRecorder

        setupBindings()
    }

    // MARK: - Dependency Injection

    func setDependencies(
        providerFactory: ProviderFactory,
        textInsertion: MacTextInsertionService
    ) {
        self.providerFactory = providerFactory
        self.textInsertion = textInsertion
    }

    // MARK: - Setup

    private func setupBindings() {
        // Sync translation settings from MacSettings
        isTranslationEnabled = settings.isTranslationEnabled
        targetLanguage = settings.selectedTargetLanguage
        inputLanguage = settings.selectedDictationLanguage

        // Observe audio recorder level - only when NOT in streaming mode
        // (Streaming mode uses its own audio recorder and timer for levels)
        audioRecorder.$currentLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] level in
                guard let self, !self.isStreamingSession else { return }
                self.audioLevel = level
            }
            .store(in: &cancellables)
    }

    // MARK: - Context Auto-Detection

    /// Set the pre-captured context from hotkey callback and auto-detect context
    func setPreCapturedContext(_ context: HotkeyContext) {
        self.preCapturedContext = context
        self.sourceAppName = context.frontmostAppName
        self.sourceAppBundleId = context.frontmostAppBundleId

        // Store the previous app for focus restoration
        if context.frontmostAppPid > 0 {
            self.previousApp = NSRunningApplication(processIdentifier: context.frontmostAppPid)
            macLog("Stored previous app: \(context.frontmostAppName) (pid: \(context.frontmostAppPid))", category: "Transcribe")
        }

        // Auto-detect context based on app bundle ID
        autoSelectContext(for: context.frontmostAppBundleId)
    }

    /// Auto-select context based on frontmost app's bundle ID
    private func autoSelectContext(for bundleId: String) {
        guard !bundleId.isEmpty else { return }

        // Find ALL contexts that match this app
        var matchingContexts: [ConversationContext] = []
        for context in settings.contexts {
            let matches = context.appAssignment.includes(
                bundleId: bundleId,
                userOverrides: [:],
                appLookup: { _ in nil }
            )

            if matches {
                matchingContexts.append(context)
            }
        }

        guard !matchingContexts.isEmpty else {
            // No app-specific match - use global active context
            activeContext = settings.activeContext
            return
        }

        // If only one match, use it
        if matchingContexts.count == 1 {
            let context = matchingContexts[0]
            activeContext = context
            macLog("Auto-selected context '\(context.name)' for '\(bundleId)'", category: "Transcribe")

            // Apply context's default input language (only if context has one)
            if let contextLanguage = context.defaultInputLanguage {
                inputLanguage = contextLanguage
            }
            return
        }

        // Multiple contexts match - check for last used preference
        if let lastUsedContextId = settings.getLastUsedContext(forApp: bundleId),
           let lastUsedContext = matchingContexts.first(where: { $0.id == lastUsedContextId }) {
            activeContext = lastUsedContext
            macLog("Auto-selected last used context '\(lastUsedContext.name)' for '\(bundleId)' (from \(matchingContexts.count) options)", category: "Transcribe")

            // Apply context's default input language
            if let contextLanguage = lastUsedContext.defaultInputLanguage {
                inputLanguage = contextLanguage
            }
            return
        }

        // No last used preference or it's not among matches - use first match
        let context = matchingContexts[0]
        activeContext = context
        macLog("Auto-selected first matching context '\(context.name)' for '\(bundleId)' (from \(matchingContexts.count) options)", category: "Transcribe")

        // Apply context's default input language
        if let contextLanguage = context.defaultInputLanguage {
            inputLanguage = contextLanguage
        }
    }

    // MARK: - Recording Control

    func startRecording() async {
        do {
            // Show initializing state while audio engine starts up
            // This prevents user from thinking they're recording when audio isn't captured yet
            state = .initializing
            recordingDuration = 0
            liveTranscript = ""
            streamingFullTranscript = ""
            streamingConnectionErrorOccurred = false
            errorMessage = nil
            audioLevel = 0

            // Clean up any leftover resources from previous session
            streamingCancellables.removeAll()
            streamingProvider?.disconnect()
            streamingProvider = nil
            streamingAudioRecorder = nil
            streamingDelegateBridge = nil

            // Check if streaming should be used
            let selectedProvider = settings.selectedTranscriptionProvider
            let streamingAvailable = selectedProvider == .openAI || selectedProvider == .deepgram || selectedProvider == .assemblyAI || selectedProvider == .google || selectedProvider == .appleSpeech
            let shouldUseStreaming = settings.transcriptionStreamingEnabled && streamingAvailable

            isStreamingSession = shouldUseStreaming
            macLog("Recording start - streaming: \(shouldUseStreaming), provider: \(selectedProvider.displayName)", category: "Transcribe")

            if shouldUseStreaming {
                // STREAMING MODE
                try await startStreamingRecording()
            } else {
                // BATCH MODE (existing behavior)
                try await startBatchRecording()
            }
        } catch {
            macLog("Failed to start recording: \(error)", category: "Transcribe", level: .error)
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            state = .error(error.localizedDescription)
        }
    }

    /// Start recording in batch mode (existing behavior)
    private func startBatchRecording() async throws {
        // Set recording format based on transcription provider
        // Google STT requires WAV (LINEAR16), other providers work with AAC (smaller files)
        audioRecorder.recordingFormat = RecordingFormat.forProvider(settings.selectedTranscriptionProvider)
        audioRecorder.audioQuality = settings.audioQuality

        // Resolve effective quality for UI display
        effectiveAudioQuality = settings.audioQuality == .auto
            ? NetworkQualityMonitor.shared.recommendedQuality
            : settings.audioQuality

        macLog("Using recording format: \(audioRecorder.recordingFormat), quality: \(effectiveAudioQuality.displayName)", category: "Transcribe")

        // Start audio recording (may take time on first call due to audio engine init)
        // We wait for this to complete BEFORE showing "Recording" state
        try await audioRecorder.startRecording()

        // NOW audio is actually being captured - switch to recording state
        state = .recording

        // Play start sound AFTER audio engine is ready (user can now speak)
        if settings.playSoundOnRecordStart {
            NSSound(named: "Tink")?.play()
        }

        // Start timer only after recording has actually begun
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.recordingDuration = self.audioRecorder.duration
            }
        }

        macLog("Recording started (batch mode)", category: "Transcribe")
    }

    /// Start recording in streaming mode
    private func startStreamingRecording() async throws {
        guard let factory = providerFactory else {
            throw TranscriptionError.providerNotConfigured
        }

        // Create streaming provider
        let selectedProvider = settings.selectedTranscriptionProvider
        guard let provider = factory.createStreamingTranscriptionProvider(for: selectedProvider) else {
            macLog("Failed to create streaming provider for \(selectedProvider.displayName), falling back to batch", category: "Transcribe", level: .warning)
            isStreamingSession = false
            try await startBatchRecording()
            return
        }

        self.streamingProvider = provider

        // Setup delegate for receiving transcription updates
        let delegateBridge = StreamingDelegateBridge(viewModel: self, partialsAreDelta: provider.partialsAreDelta)
        self.streamingDelegateBridge = delegateBridge
        provider.delegate = delegateBridge

        // Determine sample rate based on provider
        let sampleRate: Int
        if selectedProvider == .openAI {
            sampleRate = 24000 // OpenAI Realtime requires 24kHz
        } else {
            sampleRate = 16000 // Standard for Deepgram/AssemblyAI
        }

        // Create streaming audio recorder
        let streamRecorder = MacStreamingAudioRecorder(sampleRate: sampleRate)
        self.streamingAudioRecorder = streamRecorder

        // Setup provider subscriptions
        setupStreamingSubscriptions(provider)

        // Setup audio chunk forwarding (used after pre-buffer is flushed)
        streamRecorder.onAudioChunk = { [weak provider] data in
            provider?.sendAudio(data)
        }

        // Build transcription hints from context
        let promptContext = PromptContext.from(
            context: activeContext,
            powerMode: nil,
            globalMemory: settings.globalMemoryEnabled ? settings.globalMemory : nil,
            vocabularyEntries: settings.vocabulary
        )
        let transcriptionPrompt = promptContext.buildTranscriptionHint()

        // IMPORTANT: Subscribe to audio level BEFORE starting recording
        // Use same pattern as non-streaming mode in setupBindings() which works
        streamRecorder.audioLevelSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &streamingCancellables)

        // ============================================================
        // PRE-BUFFERING: Start recording IMMEDIATELY while connecting
        // This ensures no audio is lost during WebSocket connection delay
        // ============================================================

        // Start recording with pre-buffering enabled (captures audio to memory buffer)
        macLog("Starting audio recording with pre-buffering while provider connects...", category: "Transcribe")
        try await streamRecorder.startRecordingWithPreBuffering()

        // NOW audio is being captured to buffer - switch to recording state
        // User sees the recording indicator immediately
        state = .recording

        // Play start sound
        if settings.playSoundOnRecordStart {
            NSSound(named: "Tink")?.play()
        }

        // Start timer to track duration
        let startTime = Date()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }

        // Connect to streaming service (this takes 500ms-2s typically)
        // Audio is being captured to buffer during this time
        do {
            try await provider.connect(
                language: inputLanguage,
                sampleRate: sampleRate,
                transcriptionPrompt: transcriptionPrompt
            )

            // Provider is now connected - flush buffered audio and switch to direct streaming
            let bufferStatus = streamRecorder.preBufferStatus
            macLog("Provider connected! Flushing \(bufferStatus.chunkCount) pre-buffered chunks (\(String(format: "%.0f", bufferStatus.estimatedDurationMs))ms of audio)", category: "Transcribe")
            streamRecorder.stopBufferingAndFlush()

        } catch {
            // Provider connection failed - stop recording and rethrow
            macLog("Provider connection failed: \(error)", category: "Transcribe", level: .error)
            streamRecorder.stopRecording()
            state = .idle
            throw error
        }

    }

    /// Cancellables specifically for streaming subscriptions
    private var streamingCancellables = Set<AnyCancellable>()

    /// Setup subscriptions for streaming provider updates
    private func setupStreamingSubscriptions(_ provider: StreamingTranscriptionProvider) {
        streamingCancellables.removeAll()
    }

    func stopRecording() async {
        guard state == .recording else { return }

        recordingTimer?.invalidate()
        recordingTimer = nil

        // Play stop sound if enabled
        if settings.playSoundOnRecordEnd {
            NSSound(named: "Pop")?.play()
        }

        if isStreamingSession {
            // STREAMING MODE - use accumulated transcript
            await stopStreamingRecording()
        } else {
            // BATCH MODE - existing behavior
            do {
                let audioURL = try audioRecorder.stopRecording()
                macLog("Recording stopped, audio file: \(audioURL)", category: "Transcribe")

                // Store URL for potential retry
                lastRecordingURL = audioURL

                // Process the recording
                await processRecording(audioURL: audioURL)
            } catch {
                macLog("Failed to stop recording: \(error)", category: "Transcribe", level: .error)
                errorMessage = "Failed to stop recording: \(error.localizedDescription)"
                state = .error(error.localizedDescription)
            }
        }
    }

    /// Stop streaming recording and process result
    private func stopStreamingRecording() async {
        macLog("Stopping streaming recording...", category: "Transcribe")

        // Capture the current partial before we start cleanup
        // This is important because we might not get a final for the last utterance
        let lastPartial = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)

        // Stop streaming audio recorder first - no more audio to send
        streamingAudioRecorder?.stopRecording()

        // Signal end of audio - this tells the provider we're done sending
        streamingProvider?.finishAudio()

        // Wait for the provider to signal it's done processing all audio
        // Use sessionEndedPublisher with a timeout
        if let provider = streamingProvider {
            macLog("Waiting for provider to finish processing...", category: "Transcribe")

            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                // Use a class to safely track if we've resumed
                final class ContinuationState {
                    var hasResumed = false
                    let lock = NSLock()

                    func tryResume(_ continuation: CheckedContinuation<Void, Never>) -> Bool {
                        lock.lock()
                        defer { lock.unlock() }
                        if hasResumed { return false }
                        hasResumed = true
                        continuation.resume()
                        return true
                    }
                }

                let state = ContinuationState()
                var sessionEndedCancellable: AnyCancellable?

                // Set up timeout
                let timeoutTask = Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second timeout
                    sessionEndedCancellable?.cancel()
                    if state.tryResume(continuation) {
                        macLog("Session wait timed out after 2s", category: "Transcribe", level: .warning)
                    }
                }

                // Wait for session ended signal
                sessionEndedCancellable = provider.sessionEndedPublisher
                    .first()
                    .sink { _ in
                        timeoutTask.cancel()
                        if state.tryResume(continuation) {
                            macLog("Session ended signal received", category: "Transcribe")
                        }
                    }
            }
        }

        // Disconnect streaming service
        streamingProvider?.disconnect()
        streamingProvider = nil
        streamingDelegateBridge = nil

        // Save backup file URL before clearing recorder (needed for fallback)
        let backupFileURL = streamingAudioRecorder?.backupFileURL

        // Clear streaming subscriptions
        streamingCancellables.removeAll()

        // Get the accumulated transcript
        var transcript = streamingFullTranscript.trimmingCharacters(in: .whitespacesAndNewlines)

        // If there's a partial that wasn't finalized, include it
        // (This happens when user stops quickly before provider sends final)
        if !lastPartial.isEmpty {
            // Check if the last partial content is already in the transcript
            let lastPartialWords = lastPartial.components(separatedBy: .whitespaces).suffix(5).joined(separator: " ")
            if !transcript.contains(lastPartialWords) && lastPartialWords.count > 3 {
                macLog("Including unfinalzed partial: '\(lastPartial.suffix(50))'", category: "Transcribe")
                // Extract just the part that's not in the transcript
                if let range = lastPartial.range(of: transcript, options: .caseInsensitive) {
                    let remaining = String(lastPartial[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !remaining.isEmpty {
                        transcript += " " + remaining
                    }
                } else if transcript.isEmpty {
                    transcript = lastPartial
                }
            }
        }

        // Decide whether to fall back to batch transcription:
        // 1. Empty transcript - always fall back
        // 2. Error occurred AND transcript seems incomplete (less than ~0.5 words per second of recording)
        let shouldFallBackToBatch: Bool
        let fallbackReason: String

        if transcript.isEmpty {
            shouldFallBackToBatch = true
            fallbackReason = "transcript is empty"
        } else if streamingConnectionErrorOccurred {
            // Estimate expected words: typical speech is 2-3 words per second
            // If we have less than 0.5 words per second, likely incomplete
            let wordCount = transcript.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
            let expectedMinWords = max(1, Int(recordingDuration * 0.5))  // At least 0.5 words/sec

            if wordCount < expectedMinWords && recordingDuration > 1.5 {
                shouldFallBackToBatch = true
                fallbackReason = "streaming error occurred and transcript seems incomplete (\(wordCount) words for \(String(format: "%.1f", recordingDuration))s recording)"
            } else {
                shouldFallBackToBatch = false
                fallbackReason = ""
                macLog("Streaming error occurred but transcript seems complete (\(wordCount) words)", category: "Transcribe")
            }
        } else {
            shouldFallBackToBatch = false
            fallbackReason = ""
        }

        if shouldFallBackToBatch {
            macLog("Falling back to batch transcription - \(fallbackReason)", category: "Transcribe", level: .warning)

            // Fall back to batch transcription using the backup audio file
            if let backupURL = backupFileURL {
                macLog("Using backup file for batch fallback: \(backupURL.lastPathComponent)", category: "Transcribe")
                // Store for cleanup later
                lastRecordingURL = backupURL
                // Clear recorder now since we're using the backup
                streamingAudioRecorder = nil
                await processRecording(audioURL: backupURL)
                return
            } else {
                macLog("No backup file available for fallback", category: "Transcribe", level: .error)
                streamingAudioRecorder = nil
                state = .error("Streaming failed and no backup available")
                return
            }
        }

        // Streaming succeeded - delete backup file and clear recorder
        streamingAudioRecorder?.deleteBackupFile()
        streamingAudioRecorder = nil

        macLog("Streaming transcription complete: \(transcript.count) chars", category: "Transcribe")

        // Process the streaming result (formatting, translation, etc.)
        await processStreamingResult(transcript: transcript)
    }

    /// Process the result from streaming transcription
    private func processStreamingResult(transcript: String) async {
        state = .transcribing
        var processingSteps: [ProcessingStepInfo] = []
        let overallStartTime = Date()

        // Apply vocabulary corrections
        var processedText = settings.applyVocabulary(to: transcript)
        self.transcribedText = processedText
        let rawTranscription = processedText

        macLog("Streaming result: \(processedText.prefix(100))...", category: "Transcribe")

        // Create transcription processing step
        let transcriptionStep = ProcessingStepInfo(
            stepType: .transcription,
            provider: settings.selectedTranscriptionProvider,
            modelName: settings.selectedTranscriptionProvider.defaultTranscriptionModel,
            startTime: overallStartTime,
            endTime: Date(),
            cost: 0,
            prompt: nil
        )
        processingSteps.append(transcriptionStep)

        // Track if formatting was actually applied
        var formattingResult: FormattingResult?

        // Apply formatting if context has formatting enabled
        let shouldFormat = activeContext?.hasFormatting == true
        macLog("Context: \(activeContext?.name ?? "none"), hasFormatting: \(shouldFormat)", category: "Transcribe")

        if shouldFormat {
            state = .formatting
            do {
                formattingResult = try await formatTranscription(processedText)
                if let result = formattingResult {
                    processedText = result.text
                    self.transcribedText = processedText

                    // Create formatting processing step
                    let formattingStep = ProcessingStepInfo(
                        stepType: .formatting,
                        provider: settings.selectedPowerModeProvider,
                        modelName: settings.selectedPowerModeProvider.defaultLLMModel ?? "default",
                        startTime: result.startTime,
                        endTime: result.endTime,
                        cost: 0,
                        prompt: result.prompt
                    )
                    processingSteps.append(formattingStep)
                    macLog("Formatting applied", category: "Transcribe")
                }
            } catch {
                macLog("Formatting failed: \(error)", category: "Transcribe", level: .warning)
            }
        }

        // Translate if enabled
        if isTranslationEnabled {
            state = .formatting
            do {
                processedText = try await translateText(processedText)
                self.transcribedText = processedText
            } catch {
                macLog("Translation failed: \(error)", category: "Transcribe", level: .warning)
            }
        }

        state = .complete

        // Build processing metadata
        let overallEndTime = Date()
        let processingMetadata = ProcessingMetadata(
            steps: processingSteps,
            totalProcessingTime: overallEndTime.timeIntervalSince(overallStartTime),
            sourceLanguageHint: inputLanguage,
            vocabularyApplied: settings.vocabulary.isEmpty ? nil : settings.vocabulary.map { $0.recognizedWord }
        )

        // Save to history
        saveToHistory(
            rawText: rawTranscription,
            finalText: self.transcribedText,
            wasTranslated: isTranslationEnabled,
            didFormat: formattingResult != nil,
            processingMetadata: processingMetadata
        )

        // Execute the context's enter key behavior
        await executeEnterKeyBehavior()
    }

    /// Retry processing the last recording (used when transcription/formatting fails)
    func retryProcessing() async {
        guard let audioURL = lastRecordingURL else {
            macLog("No recording to retry - starting new recording", category: "Transcribe", level: .warning)
            await startRecording()
            return
        }

        // Verify file still exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            macLog("Recording file no longer exists - starting new recording", category: "Transcribe", level: .warning)
            lastRecordingURL = nil
            await startRecording()
            return
        }

        macLog("Retrying processing for: \(audioURL)", category: "Transcribe")
        errorMessage = nil

        // Process the existing recording again
        await processRecording(audioURL: audioURL)
    }

    func cancelRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        if isStreamingSession {
            // Clean up streaming resources
            streamingCancellables.removeAll()
            streamingAudioRecorder?.cancelRecording()
            streamingProvider?.disconnect()
            streamingProvider = nil
            streamingAudioRecorder = nil
            streamingDelegateBridge = nil
        } else {
            audioRecorder.cancelRecording()
        }

        state = .idle
        liveTranscript = ""
        transcribedText = ""
        streamingFullTranscript = ""
        isStreamingSession = false
        macLog("Recording cancelled", category: "Transcribe")
    }

    /// Clean up all resources - call before deallocation
    func cleanup() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        // Clean up streaming resources
        streamingCancellables.removeAll()
        streamingProvider?.disconnect()
        streamingProvider = nil
        streamingAudioRecorder = nil
        streamingDelegateBridge = nil

        cancellables.removeAll()
        macLog("Transcribe viewModel cleanup", category: "Transcribe")
    }

    // MARK: - Processing

    /// Result of formatting operation
    private struct FormattingResult {
        let text: String
        let prompt: String
        let startTime: Date
        let endTime: Date
    }

    private func processRecording(audioURL: URL) async {
        guard let factory = providerFactory else {
            errorMessage = "Provider factory not configured"
            state = .error("Configuration error")
            return
        }

        state = .transcribing
        var processingSteps: [ProcessingStepInfo] = []
        let overallStartTime = Date()

        do {
            // Get transcription provider
            let selectedProvider = settings.selectedTranscriptionProvider
            macLog("Using transcription provider: \(selectedProvider.displayName)", category: "Transcribe")

            guard let transcriptionProvider = factory.createTranscriptionProvider(
                for: selectedProvider
            ) else {
                // Log detailed config info for debugging
                if let config = settings.getAIProviderConfig(for: selectedProvider) {
                    macLog("Provider \(selectedProvider.displayName) config exists but failed to create:", category: "Transcribe", level: .error)
                    macLog("  - apiKey empty: \(config.apiKey.isEmpty)", category: "Transcribe", level: .error)
                    if selectedProvider == .google {
                        macLog("  - googleProjectId: \(config.googleProjectId ?? "nil")", category: "Transcribe", level: .error)
                    }
                } else {
                    macLog("No config found for provider \(selectedProvider.displayName)", category: "Transcribe", level: .error)
                    macLog("Configured providers: \(settings.configuredAIProviders.map { $0.provider.displayName })", category: "Transcribe", level: .error)
                }
                throw TranscriptionError.apiKeyMissing
            }

            // Log audio file info
            if let attrs = try? FileManager.default.attributesOfItem(atPath: audioURL.path),
               let fileSize = attrs[.size] as? Int64 {
                macLog("Audio file size: \(fileSize) bytes", category: "Transcribe")
            }

            // Build prompt context with global memory and vocabulary
            let promptContext = PromptContext.from(
                context: activeContext,
                powerMode: nil,
                globalMemory: settings.globalMemoryEnabled ? settings.globalMemory : nil,
                vocabularyEntries: settings.vocabulary
            )

            // Transcribe audio with language and vocabulary hints
            macLog("Transcribing with language: \(inputLanguage?.displayName ?? "auto-detect")", category: "Transcribe")

            let transcriptionStartTime = Date()
            var transcribedText = try await transcriptionProvider.transcribe(
                audioURL: audioURL,
                language: inputLanguage,
                promptHint: promptContext.buildTranscriptionHint()
            )
            let transcriptionEndTime = Date()

            // Apply vocabulary corrections
            transcribedText = settings.applyVocabulary(to: transcribedText)

            self.transcribedText = transcribedText
            let rawTranscription = transcribedText  // Store raw for history
            macLog("Transcription complete: \(transcribedText.prefix(100))...", category: "Transcribe")

            // Create transcription processing step
            let transcriptionStep = ProcessingStepInfo(
                stepType: .transcription,
                provider: selectedProvider,
                modelName: selectedProvider.defaultTranscriptionModel,
                startTime: transcriptionStartTime,
                endTime: transcriptionEndTime,
                cost: 0,  // Cost calculated separately
                prompt: promptContext.buildTranscriptionHint()
            )
            processingSteps.append(transcriptionStep)

            // Track if formatting was actually applied
            var formattingResult: FormattingResult?

            // Apply formatting if context has formatting enabled
            let shouldFormat = activeContext?.hasFormatting == true
            macLog("Context: \(activeContext?.name ?? "none"), hasFormatting: \(shouldFormat), examples: \(activeContext?.examples.count ?? 0), selectedInstructions: \(activeContext?.selectedInstructions ?? []), customInstructions: \(activeContext?.customInstructions?.prefix(50) ?? "")", category: "Transcribe")

            if shouldFormat {
                state = .formatting
                formattingResult = try await formatTranscription(transcribedText)
                if let result = formattingResult {
                    transcribedText = result.text
                    self.transcribedText = transcribedText

                    // Create formatting processing step
                    let formattingStep = ProcessingStepInfo(
                        stepType: .formatting,
                        provider: settings.selectedPowerModeProvider,
                        modelName: settings.selectedPowerModeProvider.defaultLLMModel ?? "default",
                        startTime: result.startTime,
                        endTime: result.endTime,
                        cost: 0,  // Cost calculated separately
                        prompt: result.prompt
                    )
                    processingSteps.append(formattingStep)
                    macLog("Formatting applied", category: "Transcribe")
                }
            }

            // Translate if enabled
            if isTranslationEnabled {
                state = .formatting
                transcribedText = try await translateText(transcribedText)
                self.transcribedText = transcribedText
            }

            state = .complete

            // Build processing metadata
            let overallEndTime = Date()
            let processingMetadata = ProcessingMetadata(
                steps: processingSteps,
                totalProcessingTime: overallEndTime.timeIntervalSince(overallStartTime),
                sourceLanguageHint: inputLanguage,
                vocabularyApplied: settings.vocabulary.isEmpty ? nil : settings.vocabulary.map { $0.recognizedWord }
            )

            // Save to history
            saveToHistory(
                rawText: rawTranscription,
                finalText: self.transcribedText,
                wasTranslated: isTranslationEnabled,
                didFormat: formattingResult != nil,
                processingMetadata: processingMetadata
            )

            // Execute the context's enter key behavior
            await executeEnterKeyBehavior()

        } catch {
            macLog("Processing failed: \(error)", category: "Transcribe", level: .error)

            // Provide user-friendly error messages for common issues
            let userMessage = friendlyErrorMessage(for: error)
            errorMessage = userMessage
            state = .error(userMessage)
        }
    }

    /// Convert technical errors into user-friendly messages with actionable guidance
    private func friendlyErrorMessage(for error: Error) -> String {
        let errorString = String(describing: error)
        let provider = settings.selectedTranscriptionProvider

        // Google Cloud specific errors
        if provider == .google {
            if errorString.contains("403") {
                if errorString.contains("Speech-to-Text API has not been used") || errorString.contains("it is disabled") {
                    return """
                    ❌ Google Speech-to-Text API Not Enabled

                    Fix in Google Cloud Console:
                    1. Go to console.cloud.google.com
                    2. Select your project
                    3. Go to: APIs & Services → Library
                    4. Search "Cloud Speech-to-Text API"
                    5. Click ENABLE
                    6. Wait 1-2 minutes, then retry
                    """
                }
                if errorString.contains("Permission") && errorString.contains("denied") {
                    return """
                    ❌ Google API Permission Denied

                    Your API key cannot access Speech-to-Text. Fix this:

                    1. Go to console.cloud.google.com
                    2. APIs & Services → Credentials
                    3. Click on your API key to edit it
                    4. Under "API restrictions":
                       • Select "Don't restrict key" OR
                       • Select "Restrict key" and ADD "Cloud Speech-to-Text API"
                    5. Click SAVE
                    6. Also verify: Project ID in SwiftSpeak matches the API key's project
                    """
                }
                return "Google API Error (403): Access denied.\n\nCheck API key permissions and project configuration."
            }

            if errorString.contains("404") {
                return """
                ❌ Google API Endpoint Not Found (404)

                The Project ID appears to be incorrect.

                Fix: Go to console.cloud.google.com and copy the correct Project ID from the project selector dropdown.
                """
            }

            if errorString.contains("400") {
                if errorString.contains("enhanced model") || errorString.contains("no enhanced") {
                    return """
                    ❌ Google Model Not Available

                    The selected model doesn't support this language.

                    Try changing the model in Settings → Google Cloud → Transcription Model.
                    Recommended: "default" for broad language support.
                    """
                }
                if errorString.contains("not supported for language") {
                    return """
                    ❌ Language Not Supported by Model

                    The selected Google STT model doesn't support your language.

                    Fix: Go to Settings → Edit Google Cloud provider
                    Change Transcription Model to "default"

                    Model language support:
                    • "default" - Most languages (125+)
                    • "latest_long/short" - English, Spanish, French, German, etc.
                    • "telephony" - Limited languages
                    """
                }
                return """
                ❌ Google API Bad Request (400)

                The request format was invalid.

                Error: \(errorString.prefix(300))
                """
            }
        }

        if errorString.contains("401") {
            return """
            ❌ Invalid API Key (401)

            Your API key is invalid or expired.

            Fix: Get a new API key from your provider's console and update it in SwiftSpeak Settings.
            """
        }

        // Generic transcription errors
        if case TranscriptionError.apiKeyMissing = error {
            return """
            ❌ API Key or Project ID Missing

            Configure your \(provider.displayName) provider in Settings → Transcription & AI.
            """
        }

        if case TranscriptionError.emptyResponse = error {
            return """
            ⚠️ No Speech Detected

            The transcription returned empty. Try:
            • Speaking louder or closer to the mic
            • Checking your microphone settings
            • Recording for longer (at least 1-2 seconds)
            """
        }

        if case TranscriptionError.audioFileNotFound = error {
            return "❌ Audio file not found. Recording may have failed."
        }

        // Network errors
        if errorString.contains("NSURLError") || errorString.contains("network") {
            return """
            ❌ Network Error

            Could not connect to \(provider.displayName). Check your internet connection.
            """
        }

        // Fallback with raw error
        return "❌ Transcription Failed\n\n\(error.localizedDescription)"
    }

    private func formatTranscription(_ text: String) async throws -> FormattingResult? {
        guard let factory = providerFactory,
              let context = activeContext,
              context.hasFormatting else {
            return nil
        }

        let startTime = Date()

        do {
            // Use Power Mode provider for formatting
            guard let formattingProvider = factory.createFormattingProvider(
                for: settings.selectedPowerModeProvider
            ) else {
                return nil
            }

            // Build prompt context
            let promptContext = PromptContext.from(
                context: context,
                globalMemory: settings.globalMemoryEnabled ? settings.globalMemory : nil
            )

            // Get the formatting prompt from context
            guard let formattingPrompt = promptContext.buildFormattingPrompt() else {
                return nil
            }

            let formatted = try await formattingProvider.format(
                text: text,
                mode: FormattingMode.raw,
                customPrompt: formattingPrompt,
                context: promptContext
            )

            let endTime = Date()
            macLog("Formatting complete", category: "Transcribe")

            return FormattingResult(
                text: formatted,
                prompt: formattingPrompt,
                startTime: startTime,
                endTime: endTime
            )
        } catch {
            macLog("Formatting failed: \(error)", category: "Transcribe", level: .warning)
            // Return nil if formatting fails
            return nil
        }
    }

    private func translateText(_ text: String) async throws -> String {
        guard let factory = providerFactory else {
            return text
        }

        do {
            guard let translationProvider = factory.createTranslationProvider(
                for: settings.selectedTranslationProvider
            ) else {
                return text
            }

            let promptContext = PromptContext.from(
                context: activeContext,
                globalMemory: settings.globalMemoryEnabled ? settings.globalMemory : nil
            )

            let translated = try await translationProvider.translate(
                text: text,
                from: inputLanguage,
                to: targetLanguage,
                formality: promptContext.inferFormality(),
                context: promptContext
            )

            macLog("Translation complete to \(targetLanguage.displayName)", category: "Transcribe")
            return translated
        } catch {
            macLog("Translation failed: \(error)", category: "Transcribe", level: .warning)
            return text
        }
    }

    // MARK: - Enter Key Behavior Execution

    private func executeEnterKeyBehavior() async {
        let behavior = activeContext?.enterKeyBehavior ?? .defaultNewLine
        macLog("Enter behavior: \(behavior.displayName)", category: "Transcribe")

        switch behavior {
        case .defaultNewLine, .formatThenInsert:
            await insertText()
        case .justSend, .formatAndSend:
            await insertTextAndSend()
        }

        shouldAutoClose = true
    }

    // MARK: - Text Insertion

    /// Restore focus to the previous app before text insertion
    /// Returns true if focus was successfully restored (or if no previous app)
    private func restoreFocusToPreviousApp() -> Bool {
        let startTime = CFAbsoluteTimeGetCurrent()

        guard let app = previousApp else {
            macLog("⏱️ [TIMING] No previous app to restore focus to", category: "Transcribe", level: .warning)
            return true  // No app to restore, proceed anyway
        }

        macLog("⏱️ [TIMING] Restoring focus to: \(app.localizedName ?? "unknown")", category: "Transcribe")
        app.activate()

        // Use Thread.sleep for precise timing - Task.sleep can be delayed by MainActor congestion
        // 50ms is usually enough for focus to transfer
        Thread.sleep(forTimeInterval: 0.05)  // 50ms - synchronous, not affected by actor congestion

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        // Verify the app is now frontmost
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier {
            macLog("⏱️ [TIMING] Focus restored successfully in \(String(format: "%.1f", elapsed))ms", category: "Transcribe")
            return true
        } else {
            macLog("⏱️ [TIMING] Focus may not have been fully restored after \(String(format: "%.1f", elapsed))ms, proceeding anyway", category: "Transcribe", level: .warning)
            return true
        }
    }

    func insertText() async {
        guard !transcribedText.isEmpty else { return }
        state = .inserting

        // Hide overlay before restoring focus
        onWillInsertText?()

        // Wait for Enter key event to clear before restoring focus
        Thread.sleep(forTimeInterval: 0.1)
        _ = restoreFocusToPreviousApp()

        if let textService = textInsertion {
            let result = await textService.insertText(transcribedText, replaceSelection: true)
            if case .failed(let error) = result {
                macLog("Text insertion failed: \(error)", category: "Transcribe", level: .error)
            }
        }

        state = .complete
    }

    private func insertTextAndSend() async {
        guard !transcribedText.isEmpty else { return }
        state = .inserting

        // Hide overlay before restoring focus
        onWillInsertText?()

        // Wait for Enter key event to clear before restoring focus
        Thread.sleep(forTimeInterval: 0.1)
        _ = restoreFocusToPreviousApp()

        if let textService = textInsertion {
            let result = await textService.insertText(transcribedText, replaceSelection: true)
            if case .failed(let error) = result {
                macLog("Text insertion failed: \(error)", category: "Transcribe", level: .error)
            }
        }

        // Brief delay before Enter for clipboard paste to complete
        Thread.sleep(forTimeInterval: 0.05)

        // Send Enter key
        let source = CGEventSource(stateID: .hidSystemState)
        let enterDown = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true)
        let enterUp = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false)
        enterDown?.flags = []
        enterUp?.flags = []
        enterDown?.post(tap: .cghidEventTap)
        enterUp?.post(tap: .cghidEventTap)

        state = .complete
    }

    func copyToClipboard() {
        guard !transcribedText.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(transcribedText, forType: .string)

        macLog("Copied to clipboard", category: "Transcribe")
    }

    // MARK: - Context Management

    /// Get contexts assigned to the current app
    private func contextsForCurrentApp() -> [ConversationContext] {
        guard !sourceAppBundleId.isEmpty else { return [] }

        return settings.contexts.filter { context in
            context.appAssignment.includes(
                bundleId: sourceAppBundleId,
                userOverrides: [:],
                appLookup: { _ in nil }
            )
        }
    }

    /// Cycle to next context: nil -> context1 -> context2 -> ... -> nil
    /// If contexts are assigned to the current app, only cycles through those
    func cycleToNextContext() {
        // If contexts are assigned to this app, only cycle through those
        let appContexts = contextsForCurrentApp()
        let contexts = appContexts.isEmpty ? settings.contexts : appContexts

        guard !contexts.isEmpty else { return }

        if let current = activeContext,
           let index = contexts.firstIndex(where: { $0.id == current.id }) {
            // If at last context, cycle back to nil (no context) only if using all contexts
            // For app-specific contexts, stay within that set
            if index == contexts.count - 1 {
                if appContexts.isEmpty {
                    activeContext = nil
                } else {
                    // Wrap around to first app context
                    activeContext = contexts.first
                }
            } else {
                activeContext = contexts[index + 1]
            }
        } else {
            // No context selected (or current not in list), start with first context
            activeContext = contexts.first
        }

        // Apply context's language override
        if let ctx = activeContext, let lang = ctx.defaultInputLanguage {
            inputLanguage = lang
        } else {
            inputLanguage = settings.selectedDictationLanguage
        }
    }

    /// Cycle to previous context: nil -> contextN -> ... -> context1 -> nil
    /// If contexts are assigned to the current app, only cycles through those
    func cycleToPreviousContext() {
        // If contexts are assigned to this app, only cycle through those
        let appContexts = contextsForCurrentApp()
        let contexts = appContexts.isEmpty ? settings.contexts : appContexts

        guard !contexts.isEmpty else { return }

        if let current = activeContext,
           let index = contexts.firstIndex(where: { $0.id == current.id }) {
            // If at first context, cycle back to nil (no context) only if using all contexts
            // For app-specific contexts, stay within that set
            if index == 0 {
                if appContexts.isEmpty {
                    activeContext = nil
                } else {
                    // Wrap around to last app context
                    activeContext = contexts.last
                }
            } else {
                activeContext = contexts[index - 1]
            }
        } else {
            // No context selected (or current not in list), start with last context
            activeContext = contexts.last
        }

        // Apply context's language override
        if let ctx = activeContext, let lang = ctx.defaultInputLanguage {
            inputLanguage = lang
        } else {
            inputLanguage = settings.selectedDictationLanguage
        }
    }

    func clearContext() {
        activeContext = nil
        inputLanguage = settings.selectedDictationLanguage
    }

    /// Select a specific context by ID (used for context hotkeys)
    func selectContext(by contextId: UUID) {
        guard let context = settings.contexts.first(where: { $0.id == contextId }) else {
            macLog("Context not found for ID: \(contextId)", category: "Transcribe", level: .error)
            return
        }

        activeContext = context
        macLog("Pre-selected context '\(context.name)' via hotkey", category: "Transcribe")

        // Apply context's language override
        if let lang = context.defaultInputLanguage {
            inputLanguage = lang
        }
    }

    // MARK: - Translation Toggle

    func toggleTranslation() {
        isTranslationEnabled.toggle()
        settings.isTranslationEnabled = isTranslationEnabled
    }

    func cycleTargetLanguage() {
        let languages = Language.allCases
        if let index = languages.firstIndex(of: targetLanguage) {
            let nextIndex = (index + 1) % languages.count
            targetLanguage = languages[nextIndex]
            settings.selectedTargetLanguage = targetLanguage
        }
    }

    // MARK: - History

    private func saveToHistory(
        rawText: String,
        finalText: String,
        wasTranslated: Bool,
        didFormat: Bool,
        processingMetadata: ProcessingMetadata
    ) {
        // Calculate cost breakdown using shared BaseCostCalculator
        let costCalculator = BaseCostCalculator()
        let transcriptionProvider = settings.selectedTranscriptionProvider
        let translationProvider = wasTranslated ? settings.selectedTranslationProvider : nil

        // Use didFormat flag (actual formatting happened) instead of hasFormatting (would formatting happen)
        let formattingProvider = didFormat ? settings.selectedPowerModeProvider : nil
        let formattingModel = didFormat ? settings.selectedPowerModeProvider.defaultLLMModel : nil

        macLog("Saving to history - didFormat: \(didFormat), formattingProvider: \(formattingProvider?.displayName ?? "none"), formattingModel: \(formattingModel ?? "none")", category: "Transcribe")

        let costBreakdown = costCalculator.calculateCostBreakdown(
            transcriptionProvider: transcriptionProvider,
            transcriptionModel: transcriptionProvider.defaultTranscriptionModel,
            formattingProvider: formattingProvider,
            formattingModel: formattingModel,
            translationProvider: translationProvider,
            translationModel: translationProvider?.defaultLLMModel,
            durationSeconds: recordingDuration,
            textLength: finalText.count,
            text: finalText
        )

        macLog("Cost breakdown - transcription: $\(String(format: "%.6f", costBreakdown.transcriptionCost)), formatting: $\(String(format: "%.6f", costBreakdown.formattingCost)), total: $\(String(format: "%.6f", costBreakdown.total))", category: "Transcribe")
        macLog("Processing steps: \(processingMetadata.steps.map { "\($0.stepType.displayName) (\($0.provider.displayName))" })", category: "Transcribe")

        let record = TranscriptionRecord(
            rawTranscribedText: rawText,
            text: finalText,
            mode: didFormat ? .formal : .raw,  // Set mode based on whether formatting was applied
            provider: transcriptionProvider,
            duration: recordingDuration,
            translated: wasTranslated,
            targetLanguage: wasTranslated ? targetLanguage : nil,
            contextId: activeContext?.id,
            contextName: activeContext?.name,
            contextIcon: activeContext?.icon,
            costBreakdown: costBreakdown,
            processingMetadata: processingMetadata,
            source: .app,
            globalMemoryEnabled: settings.globalMemoryEnabled,
            contextMemoryEnabled: activeContext?.useContextMemory ?? false
        )
        settings.addToHistory(record)
        macLog("Saved transcription to history with cost: $\(String(format: "%.6f", costBreakdown.total))", category: "Transcribe")

        // Remember last used context for this app (for multi-context apps)
        if let contextId = activeContext?.id, !sourceAppBundleId.isEmpty {
            settings.setLastUsedContext(contextId, forApp: sourceAppBundleId)
        }
    }

    // MARK: - Reset

    func reset() {
        state = .idle
        liveTranscript = ""
        transcribedText = ""
        recordingDuration = 0
        audioLevel = 0
        errorMessage = nil
        streamingFullTranscript = ""
        isStreamingSession = false

        // Clean up streaming resources for fresh start
        streamingCancellables.removeAll()
        streamingProvider?.disconnect()
        streamingProvider = nil
        streamingAudioRecorder = nil
        streamingDelegateBridge = nil

        macLog("ViewModel reset for next session", category: "Transcribe")
    }
}
