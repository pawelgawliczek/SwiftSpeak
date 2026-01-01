//
//  SwiftLinkSessionManager.swift
//  SwiftSpeak
//
//  Manages SwiftLink background audio sessions for inline keyboard dictation.
//  Uses continuous recording with selective processing (like Wispr Flow).
//

import AVFoundation
import Foundation
import Combine
import UIKit

/// Manages SwiftLink background recording sessions.
/// Enables dictation from keyboard without app switching.
@MainActor
final class SwiftLinkSessionManager: ObservableObject {

    // MARK: - Singleton

    static let shared = SwiftLinkSessionManager()

    // MARK: - Published State

    @Published private(set) var isSessionActive = false
    @Published private(set) var isRecording = false
    @Published private(set) var sessionStartTime: Date?
    @Published private(set) var sessionTimeRemaining: TimeInterval?
    @Published private(set) var currentDictationDuration: TimeInterval = 0
    @Published private(set) var isEditMode = false  // Phase 12: Edit mode flag
    @Published private(set) var isStreamingMode = false  // Whether using streaming transcription
    @Published private(set) var streamingTranscript = ""  // Live transcript for streaming

    // MARK: - Configuration

    var sessionDuration: Constants.SwiftLinkSessionDuration {
        get {
            let rawValue = sharedDefaults?.integer(forKey: Constants.Keys.swiftLinkSessionDuration) ?? 900
            return Constants.SwiftLinkSessionDuration(rawValue: rawValue) ?? .fifteenMinutes
        }
        set {
            sharedDefaults?.set(newValue.rawValue, forKey: Constants.Keys.swiftLinkSessionDuration)
        }
    }

    // MARK: - Private Properties

    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?

    private var dictationStartTime: Date?
    private var sessionTimer: Timer?
    private var dictationTimer: Timer?

    private let sharedDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
    private var cancellables = Set<AnyCancellable>()

    // Circular buffer for continuous recording
    private var audioBuffer: AVAudioPCMBuffer?
    private var bufferWritePosition: AVAudioFramePosition = 0

    // Streaming transcription support
    private var streamingCancellables = Set<AnyCancellable>()

    // Direct streaming provider (used when forwarding audio from existing tap)
    private var streamingProvider: StreamingTranscriptionProvider?
    private var streamingTargetSampleRate: Int = 24000  // OpenAI uses 24kHz, others use 16kHz
    private var audioConverter: AVAudioConverter?
    private var inputFormat: AVAudioFormat?

    // Audio buffering during streaming provider connection
    // Buffers audio while WebSocket is connecting so we don't lose the first 1-2 seconds
    private var pendingStreamingAudio: [Data] = []
    private var isStreamingProviderConnecting = false
    private let maxPendingAudioChunks = 100  // ~2-3 seconds at typical chunk rate

    // MARK: - Initialization

    private init() {
        setupDarwinNotificationObservers()
        restoreSessionStateIfNeeded()
    }

    // MARK: - Session Lifecycle

    /// Start a SwiftLink session. MUST be called from foreground.
    /// - Parameter targetApp: The app to return to after starting
    /// - Returns: URL scheme of target app for navigation
    func startSession(targetApp: SwiftLinkApp) async throws -> String? {
        guard UIApplication.shared.applicationState == .active else {
            throw SwiftLinkError.mustStartInForeground
        }

        guard !isSessionActive else {
            appLog("SwiftLink session already active", category: "SwiftLink")
            return targetApp.urlScheme
        }

        appLog("Starting SwiftLink session for \(targetApp.name)", category: "SwiftLink")

        // Configure audio session for background recording
        try await configureAudioSession()

        // Start continuous recording
        try startContinuousRecording()

        // Update state
        isSessionActive = true
        sessionStartTime = Date()
        persistSessionState(active: true)

        // Start session timer if duration is set
        startSessionTimer()

        // Save last used app
        saveLastUsedApp(targetApp)

        // Notify keyboard that session started
        DarwinNotificationManager.shared.postSessionStarted()

        appLog("SwiftLink session started successfully", category: "SwiftLink")

        return targetApp.urlScheme
    }

    /// Start a SwiftLink session for background processing (without specific target app).
    /// Used when AI processing is requested but SwiftLink is not yet active.
    func startBackgroundSession() async {
        guard !isSessionActive else {
            appLog("SwiftLink background session already active (isSessionActive=\(isSessionActive))", category: "SwiftLink")
            return
        }

        appLog("Starting SwiftLink background session for AI processing", category: "SwiftLink")

        do {
            // Configure audio session for background
            try await configureAudioSession()
            appLog("Audio session configured for background", category: "SwiftLink")

            // Start continuous recording (silent mode)
            try startContinuousRecording()
            appLog("Continuous recording started", category: "SwiftLink")

            // Update state
            isSessionActive = true
            sessionStartTime = Date()
            persistSessionState(active: true)
            appLog("Session state persisted (active=true)", category: "SwiftLink")

            // Start session timer if duration is set
            startSessionTimer()

            // Notify keyboard that session started
            DarwinNotificationManager.shared.postSessionStarted()
            appLog("Darwin notification posted: sessionStarted", category: "SwiftLink")

            appLog("SwiftLink background session started successfully", category: "SwiftLink")

        } catch {
            appLog("Failed to start SwiftLink background session: \(error.localizedDescription)", category: "SwiftLink", level: .error)
        }
    }

    /// End the current SwiftLink session.
    func endSession() {
        guard isSessionActive else { return }

        appLog("Ending SwiftLink session", category: "SwiftLink")

        // Stop recording
        stopContinuousRecording()

        // Stop timers
        sessionTimer?.invalidate()
        sessionTimer = nil
        dictationTimer?.invalidate()
        dictationTimer = nil

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        // Update state
        isSessionActive = false
        isRecording = false
        sessionStartTime = nil
        sessionTimeRemaining = nil
        persistSessionState(active: false)

        // Notify keyboard
        DarwinNotificationManager.shared.postSessionEnded()

        appLog("SwiftLink session ended", category: "SwiftLink")
    }

    // MARK: - Dictation Control (Called via Darwin Notifications)

    /// Check if streaming transcription is available and enabled
    private var shouldUseStreaming: Bool {
        let settings = SharedSettings.shared
        guard settings.transcriptionStreamingEnabled else { return false }

        // Check if provider supports streaming
        let provider = settings.selectedTranscriptionProvider
        return provider == .openAI || provider == .deepgram || provider == .assemblyAI
    }

    /// Mark the start of a dictation segment.
    /// Called when keyboard receives mic tap during active session.
    func markDictationStart() {
        appLog("Received dictation start notification (sessionActive: \(isSessionActive))", category: "SwiftLink")

        guard isSessionActive else {
            appLog("Cannot start dictation - no active session", category: "SwiftLink", level: .warning)
            // Notify keyboard that session is invalid
            sharedDefaults?.set("error", forKey: Constants.Keys.swiftLinkProcessingStatus)
            sharedDefaults?.set("Session expired - please restart SwiftLink", forKey: Constants.Keys.swiftLinkTranscriptionResult)
            sharedDefaults?.synchronize()
            DarwinNotificationManager.shared.postResultReady()
            return
        }

        // Check if we should use streaming
        if shouldUseStreaming {
            appLog("Starting streaming dictation", category: "SwiftLink")
            startStreamingDictation()
        } else {
            appLog("Starting batch dictation", category: "SwiftLink")
            startBatchDictation()
        }
    }

    /// Start batch (non-streaming) dictation
    private func startBatchDictation() {
        dictationStartTime = Date()
        isRecording = true
        isStreamingMode = false
        isStreamingProviderConnecting = false
        pendingStreamingAudio.removeAll()
        currentDictationDuration = 0

        // Store in App Groups for keyboard to read
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: Constants.Keys.swiftLinkDictationStartTime)
        sharedDefaults?.set("recording", forKey: Constants.Keys.swiftLinkProcessingStatus)
        sharedDefaults?.synchronize()

        // Ensure audio engine is running (may have been suspended in background)
        ensureAudioEngineRunning()

        // Start dictation duration timer
        startDictationTimer()

        // Start writing to file from this point
        startSegmentRecording()
    }

    /// Ensure the audio engine is running - iOS may suspend it in background
    private func ensureAudioEngineRunning() {
        if !audioEngine.isRunning {
            appLog("Audio engine was suspended, restarting...", category: "SwiftLink", level: .warning)
            do {
                // Reactivate audio session
                try AVAudioSession.sharedInstance().setActive(true)

                // Reinstall tap and start engine
                let inputNode = audioEngine.inputNode
                inputNode.removeTap(onBus: 0)  // Remove old tap if any

                let format = inputNode.outputFormat(forBus: 0)
                inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
                    self?.handleAudioBuffer(buffer)
                }

                try audioEngine.start()
                appLog("Audio engine restarted successfully", category: "SwiftLink")
            } catch {
                appLog("Failed to restart audio engine: \(error.localizedDescription)", category: "SwiftLink", level: .error)
            }
        }
    }

    /// Start streaming dictation by forwarding audio from existing tap to streaming provider
    private func startStreamingDictation() {
        dictationStartTime = Date()
        isRecording = true
        isStreamingMode = true
        currentDictationDuration = 0
        streamingTranscript = ""

        // Store in App Groups for keyboard to read
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: Constants.Keys.swiftLinkDictationStartTime)
        sharedDefaults?.set("streaming", forKey: Constants.Keys.swiftLinkProcessingStatus)
        sharedDefaults?.set("", forKey: Constants.Keys.swiftLinkStreamingTranscript)
        sharedDefaults?.synchronize()

        // Ensure audio engine is running (may have been suspended in background)
        ensureAudioEngineRunning()

        // Notify keyboard that streaming started
        DarwinNotificationManager.shared.postStreamingUpdate()

        // Start dictation duration timer
        startDictationTimer()

        // Create streaming provider directly (don't use orchestrator - we have our own audio)
        // Mark as connecting so audio gets buffered while WebSocket connects
        isStreamingProviderConnecting = true
        pendingStreamingAudio.removeAll()

        Task {
            do {
                let provider = try createStreamingProvider()

                // Determine sample rate based on provider
                if provider.providerId == .openAI {
                    streamingTargetSampleRate = 24000  // OpenAI Realtime uses 24kHz
                } else {
                    streamingTargetSampleRate = 16000  // Deepgram/AssemblyAI use 16kHz
                }

                // Setup audio format converter BEFORE connecting
                // This allows us to buffer converted audio during connection
                setupAudioConverter()

                // Subscribe to provider transcripts
                setupStreamingProviderSubscriptions(provider)

                // Connect to streaming service with vocabulary and instructions
                let settings = SharedSettings.shared
                let vocabularyPrompt = self.buildVocabularyPrompt(settings: settings)
                let instructions = self.buildTranscriptionInstructions(settings: settings)

                try await provider.connect(
                    language: settings.selectedDictationLanguage,
                    sampleRate: streamingTargetSampleRate,
                    transcriptionPrompt: vocabularyPrompt,
                    instructions: instructions
                )

                // NOW set the provider - this signals audio forwarding can begin
                self.streamingProvider = provider
                self.isStreamingProviderConnecting = false

                // Flush any audio that was buffered during connection
                let bufferedChunks = self.pendingStreamingAudio.count
                if bufferedChunks > 0 {
                    appLog("Flushing \(bufferedChunks) buffered audio chunks to streaming provider", category: "SwiftLink")
                    for audioData in self.pendingStreamingAudio {
                        provider.sendAudio(audioData)
                    }
                    self.pendingStreamingAudio.removeAll()
                }

                appLog("Streaming provider connected, forwarding audio from existing tap", category: "SwiftLink")

            } catch {
                appLog("Failed to start streaming: \(error.localizedDescription)", category: "SwiftLink", level: .error)
                // Reset connection state
                self.isStreamingProviderConnecting = false
                self.pendingStreamingAudio.removeAll()

                // Fall back to batch mode
                isStreamingMode = false
                streamingProvider = nil
                audioConverter = nil
                sharedDefaults?.set("recording", forKey: Constants.Keys.swiftLinkProcessingStatus)
                sharedDefaults?.synchronize()
                startSegmentRecording()
            }
        }
    }

    /// Build vocabulary prompt from vocabulary entries only
    /// - Returns: Comma-separated vocabulary words for transcription providers, or nil if no vocabulary
    /// Note: OpenAI's transcription prompt should ONLY contain vocabulary hints (words that might
    /// appear in the audio). Do NOT include descriptive metadata like "Context:" or "Tone:" as
    /// the model will echo these back in the transcript.
    private func buildVocabularyPrompt(settings: SharedSettings) -> String? {
        // ONLY use vocabulary words - descriptive context confuses the streaming transcription
        // and causes the model to echo back the context metadata in the transcript
        var vocabWords: [String] = []

        // Add vocabulary replacement words
        vocabWords.append(contentsOf: settings.vocabularyEntries
            .filter { $0.isEnabled }
            .map { $0.replacementWord }
        )

        // Add context-specific language hints (just the words, not descriptions)
        if let context = settings.activeContext {
            // Add language names if multiple languages expected
            if context.languageHints.count > 1 {
                vocabWords.append(contentsOf: context.languageHints.map { $0.displayName })
            }
        }

        // Limit to 30 words and deduplicate
        let uniqueWords = Array(Set(vocabWords)).prefix(30)

        guard !uniqueWords.isEmpty else { return nil }

        // Format as comma-separated vocabulary list
        let prompt = uniqueWords.joined(separator: ", ")
        appLog("Built vocabulary prompt: \(prompt.prefix(100))...", category: "SwiftLink")
        return prompt
    }

    /// Build system instructions for transcription formatting
    /// - Returns: Instructions string for formatting/style, or nil if no context
    /// These are passed as the `instructions` parameter to OpenAI Realtime API,
    /// NOT the `prompt` parameter (which is for vocabulary only).
    private func buildTranscriptionInstructions(settings: SharedSettings) -> String? {
        var instructions: [String] = []

        // Base instruction for proper transcription
        instructions.append("Transcribe the audio accurately with proper punctuation and capitalization.")

        // Get active context for style guidance
        if let context = settings.activeContext {
            // Add context-specific formatting hints
            if !context.toneDescription.isEmpty {
                instructions.append("Use \(context.toneDescription.lowercased()) formatting style.")
            }

            // Professional context = more formal punctuation
            if context.name.lowercased().contains("work") || context.name.lowercased().contains("professional") {
                instructions.append("Use professional formatting with complete sentences.")
            }
        }

        // Always return at least the base instructions
        let result = instructions.joined(separator: " ")
        appLog("Built transcription instructions: \(result.prefix(100))...", category: "SwiftLink")
        return result
    }

    /// Create streaming provider based on selected transcription provider
    private func createStreamingProvider() throws -> StreamingTranscriptionProvider {
        let settings = SharedSettings.shared
        let selectedProvider = settings.selectedTranscriptionProvider

        guard let config = settings.configuredAIProviders.first(where: { $0.provider == selectedProvider }) else {
            throw TranscriptionError.providerNotConfigured
        }

        switch selectedProvider {
        case .openAI:
            guard let service = OpenAIStreamingService(config: config) else {
                throw TranscriptionError.providerNotConfigured
            }
            return service

        case .deepgram:
            guard let service = DeepgramStreamingService(config: config) else {
                throw TranscriptionError.providerNotConfigured
            }
            return service

        case .assemblyAI:
            guard let service = AssemblyAIStreamingService(config: config) else {
                throw TranscriptionError.providerNotConfigured
            }
            return service

        default:
            throw TranscriptionError.unexpectedResponse("Provider \(selectedProvider.displayName) does not support streaming")
        }
    }

    /// Setup audio converter for resampling from device format to streaming format
    private func setupAudioConverter() {
        let inputNode = audioEngine.inputNode
        let deviceFormat = inputNode.outputFormat(forBus: 0)
        self.inputFormat = deviceFormat

        // Target format: PCM16 mono at target sample rate
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(streamingTargetSampleRate),
            channels: 1,
            interleaved: true
        ) else {
            appLog("Failed to create output audio format", category: "SwiftLink", level: .error)
            return
        }

        audioConverter = AVAudioConverter(from: deviceFormat, to: outputFormat)
        appLog("Audio converter: \(deviceFormat.sampleRate)Hz → \(streamingTargetSampleRate)Hz", category: "SwiftLink")
    }

    /// Setup subscriptions to streaming provider's publishers
    private func setupStreamingProviderSubscriptions(_ provider: StreamingTranscriptionProvider) {
        streamingCancellables.removeAll()

        // Subscribe to partial transcripts
        provider.partialTranscriptPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] partial in
                guard let self else { return }
                // Accumulate partial transcript
                let combined = provider.fullTranscript + partial
                if !combined.isEmpty {
                    self.updateStreamingTranscript(combined)
                }
            }
            .store(in: &streamingCancellables)

        // Subscribe to final transcripts
        provider.finalTranscriptPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                // Update with full transcript when a segment is finalized
                let full = provider.fullTranscript
                if !full.isEmpty {
                    self.updateStreamingTranscript(full)
                }
            }
            .store(in: &streamingCancellables)
    }

    /// Update streaming transcript in App Groups and notify keyboard
    private func updateStreamingTranscript(_ transcript: String) {
        guard isStreamingMode, isRecording else { return }

        // Only update if transcript actually changed
        guard transcript != streamingTranscript else { return }

        streamingTranscript = transcript

        // Store in App Groups
        sharedDefaults?.set(transcript, forKey: Constants.Keys.swiftLinkStreamingTranscript)
        sharedDefaults?.synchronize()

        // Notify keyboard of update
        DarwinNotificationManager.shared.postStreamingUpdate()
    }

    /// Mark the end of a dictation segment and process it.
    /// Called when keyboard receives stop tap during active session.
    func markDictationEnd() {
        appLog("Received dictation stop notification (sessionActive: \(isSessionActive), isRecording: \(isRecording), streaming: \(isStreamingMode))", category: "SwiftLink")

        guard isSessionActive, isRecording else {
            appLog("Cannot end dictation - not recording (session: \(isSessionActive), recording: \(isRecording))", category: "SwiftLink", level: .warning)
            // Notify keyboard that session is invalid
            sharedDefaults?.set("error", forKey: Constants.Keys.swiftLinkProcessingStatus)
            sharedDefaults?.set("Session not active", forKey: Constants.Keys.swiftLinkTranscriptionResult)
            sharedDefaults?.synchronize()
            DarwinNotificationManager.shared.postResultReady()
            return
        }

        appLog("Marking dictation end", category: "SwiftLink")

        // Stop dictation timer
        dictationTimer?.invalidate()
        dictationTimer = nil

        isRecording = false

        if isStreamingMode {
            stopStreamingDictation()
        } else {
            stopBatchDictation()
        }
    }

    /// Stop batch dictation and process
    private func stopBatchDictation() {
        // Store end time
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: Constants.Keys.swiftLinkDictationEndTime)
        sharedDefaults?.set("processing", forKey: Constants.Keys.swiftLinkProcessingStatus)
        sharedDefaults?.synchronize()

        // Stop segment recording and get the audio file
        let audioURL = stopSegmentRecording()

        // Process the audio segment
        Task {
            await processAudioSegment(url: audioURL)
        }
    }

    /// Stop streaming dictation and process final result
    private func stopStreamingDictation() {
        sharedDefaults?.set("processing", forKey: Constants.Keys.swiftLinkProcessingStatus)
        sharedDefaults?.synchronize()

        // Notify keyboard that we're now processing (not recording)
        DarwinNotificationManager.shared.postStreamingUpdate()

        Task {
            // Get the final transcript from the provider
            guard let provider = streamingProvider else {
                appLog("No streaming provider to stop", category: "SwiftLink", level: .error)
                sharedDefaults?.set("error", forKey: Constants.Keys.swiftLinkProcessingStatus)
                sharedDefaults?.set("Streaming session not active", forKey: Constants.Keys.swiftLinkTranscriptionResult)
                sharedDefaults?.synchronize()
                DarwinNotificationManager.shared.postResultReady()
                return
            }

            // Signal end of audio to provider
            appLog("Signaling end of audio to streaming provider...", category: "SwiftLink")
            provider.finishAudio()

            // Wait for provider to finish processing remaining audio buffer
            // Use a loop to wait until transcript stabilizes or max timeout
            var lastTranscript = provider.fullTranscript
            var stableCount = 0
            let maxWaitIterations = 20  // 20 * 200ms = 4 seconds max wait

            for iteration in 0..<maxWaitIterations {
                try? await Task.sleep(nanoseconds: 200_000_000)  // 200ms per check

                let currentTranscript = provider.fullTranscript
                if currentTranscript == lastTranscript {
                    stableCount += 1
                    // If transcript hasn't changed for 3 consecutive checks (600ms), consider it stable
                    if stableCount >= 3 {
                        appLog("Transcript stabilized after \(iteration * 200)ms", category: "SwiftLink")
                        break
                    }
                } else {
                    stableCount = 0
                    lastTranscript = currentTranscript
                    appLog("Transcript still updating: \(currentTranscript.suffix(30))...", category: "SwiftLink")
                }
            }

            // Get the accumulated transcript
            let finalTranscript = provider.fullTranscript.trimmingCharacters(in: .whitespacesAndNewlines)

            // Cleanup
            provider.disconnect()
            streamingProvider = nil
            audioConverter = nil
            streamingCancellables.removeAll()
            isStreamingMode = false
            isStreamingProviderConnecting = false
            pendingStreamingAudio.removeAll()

            appLog("Streaming stopped, transcript: \(finalTranscript.count) chars", category: "SwiftLink")

            // Process the transcript (formatting, translation, etc.)
            if !finalTranscript.isEmpty {
                await processStreamingResult(finalTranscript)
            } else {
                appLog("Streaming produced no transcript", category: "SwiftLink", level: .warning)
                sharedDefaults?.set("error", forKey: Constants.Keys.swiftLinkProcessingStatus)
                sharedDefaults?.set("No speech detected", forKey: Constants.Keys.swiftLinkTranscriptionResult)
                sharedDefaults?.synchronize()
                DarwinNotificationManager.shared.postResultReady()
            }
        }
    }

    /// Process the final streaming transcript (formatting, translation)
    /// Two-step process: streaming transcription returns raw text, then we apply formatting/translation
    private func processStreamingResult(_ transcript: String) async {
        let settings = SharedSettings.shared
        let providerFactory = ProviderFactory(settings: settings)

        var processedText = settings.applyVocabulary(to: transcript)

        // Get active context for context-aware formatting
        let activeContext = settings.activeContext

        do {
            // Apply formatting if not raw mode OR if context is active
            let mode = settings.selectedMode
            let customTemplate = settings.selectedCustomTemplate

            // Build context for formatting (includes memory, tone, instructions)
            let promptContext = PromptContext.from(
                settings: settings,
                context: activeContext,
                powerMode: nil
            )

            // Determine if we need formatting:
            // 1. Custom template selected
            // 2. Mode is not raw
            // 3. Context is active with content (memory, tone, instructions)
            let needsFormatting = customTemplate != nil || mode != .raw || promptContext.hasContent

            if needsFormatting {
                if let formattingProvider = providerFactory.createSelectedTextFormattingProvider() {
                    processedText = try await formattingProvider.format(
                        text: processedText,
                        mode: mode,
                        customPrompt: customTemplate?.prompt,
                        context: promptContext
                    )
                }
            }

            // Apply translation if enabled
            if settings.isTranslationEnabled {
                if let translationProvider = providerFactory.createSelectedTranslationProvider() {
                    processedText = try await translationProvider.translate(
                        text: processedText,
                        from: settings.selectedDictationLanguage,
                        to: settings.selectedTargetLanguage
                    )
                }
            }

            // Store result
            sharedDefaults?.set(processedText, forKey: Constants.Keys.swiftLinkTranscriptionResult)
            sharedDefaults?.set("complete", forKey: Constants.Keys.swiftLinkProcessingStatus)
            sharedDefaults?.removeObject(forKey: Constants.Keys.swiftLinkStreamingTranscript)
            sharedDefaults?.synchronize()

            settings.lastTranscription = processedText
            UIPasteboard.general.string = processedText

            // Build vocabulary prompt used for this session
            let vocabularyPrompt = buildVocabularyPrompt(settings: settings)

            // Build vocabulary words list
            let vocabularyWords = settings.vocabularyEntries
                .filter { $0.isEnabled }
                .map { $0.replacementWord }

            // Create history record with full metadata
            let record = TranscriptionRecord(
                rawTranscribedText: transcript,
                text: processedText,
                mode: mode,
                provider: settings.selectedTranscriptionProvider,
                timestamp: Date(),
                duration: currentDictationDuration,
                translated: settings.isTranslationEnabled,
                targetLanguage: settings.isTranslationEnabled ? settings.selectedTargetLanguage : nil,
                powerModeId: nil,
                powerModeName: nil,
                contextId: activeContext?.id,
                contextName: activeContext?.name,
                contextIcon: activeContext?.icon,
                estimatedCost: nil,  // TODO: Calculate streaming cost
                costBreakdown: nil,
                processingMetadata: ProcessingMetadata(
                    steps: [
                        ProcessingStepInfo(
                            stepType: .transcription,
                            provider: settings.selectedTranscriptionProvider,
                            modelName: "streaming",
                            startTime: dictationStartTime ?? Date(),
                            endTime: Date(),
                            inputTokens: nil,
                            outputTokens: nil,
                            cost: 0,
                            prompt: vocabularyPrompt
                        )
                    ],
                    totalProcessingTime: currentDictationDuration,
                    sourceLanguageHint: settings.selectedDictationLanguage,
                    vocabularyApplied: vocabularyWords.isEmpty ? nil : vocabularyWords,
                    memorySourcesUsed: activeContext != nil ? [activeContext!.name] : nil,
                    ragDocumentsQueried: nil,
                    webhooksExecuted: nil
                ),
                editContext: nil
            )

            settings.addTranscription(record)

            appLog("Streaming result saved to history (\(processedText.count) chars)", category: "SwiftLink")
            DarwinNotificationManager.shared.postResultReady()

        } catch {
            appLog("Failed to process streaming result: \(error.localizedDescription)", category: "SwiftLink", level: .error)
            sharedDefaults?.set("error", forKey: Constants.Keys.swiftLinkProcessingStatus)
            sharedDefaults?.set(error.localizedDescription, forKey: Constants.Keys.swiftLinkTranscriptionResult)
            sharedDefaults?.synchronize()
            DarwinNotificationManager.shared.postResultReady()
        }
    }

    // MARK: - Audio Session Configuration

    private func configureAudioSession() async throws {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            // Use playAndRecord for background capability (Apple recommended)
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers]
            )

            // Set preferred sample rate for Whisper
            try audioSession.setPreferredSampleRate(16000)

            // Activate the session
            try audioSession.setActive(true)

            appLog("Audio session configured for SwiftLink", category: "SwiftLink")

        } catch {
            appLog("Failed to configure audio session: \(error.localizedDescription)", category: "SwiftLink", level: .error)
            throw SwiftLinkError.audioSessionFailed(error.localizedDescription)
        }
    }

    // MARK: - Continuous Recording

    private func startContinuousRecording() throws {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // Validate format
        guard format.sampleRate > 0 else {
            throw SwiftLinkError.invalidAudioFormat
        }

        // Install tap for continuous audio monitoring
        // We don't write to file until dictation starts
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            // Buffer is available for processing when dictation is active
            self?.handleAudioBuffer(buffer)
        }

        try audioEngine.start()

        appLog("Continuous recording started (format: \(format.sampleRate)Hz)", category: "SwiftLink")
    }

    private func stopContinuousRecording() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        appLog("Continuous recording stopped", category: "SwiftLink")
    }

    // MARK: - Segment Recording

    private var segmentFile: AVAudioFile?

    private func startSegmentRecording() {
        // Create a new file for this dictation segment
        let fileName = "swiftlink_segment_\(Date().timeIntervalSince1970).m4a"
        let tempDir = FileManager.default.temporaryDirectory
        recordingURL = tempDir.appendingPathComponent(fileName)

        guard let url = recordingURL else { return }

        do {
            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)

            // Create audio file settings
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            segmentFile = try AVAudioFile(forWriting: url, settings: settings)

            appLog("Started segment recording to: \(LogSanitizer.sanitizeFile(url: url))", category: "SwiftLink")

        } catch {
            appLog("Failed to create segment file: \(error.localizedDescription)", category: "SwiftLink", level: .error)
        }
    }

    private func stopSegmentRecording() -> URL? {
        segmentFile = nil  // Close the file

        let url = recordingURL
        recordingURL = nil

        if let url = url {
            appLog("Stopped segment recording", category: "SwiftLink")
        }

        return url
    }

    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isRecording else { return }

        // If streaming mode, handle audio for streaming
        if isStreamingMode {
            // Check if provider is connected and ready
            if let provider = streamingProvider, provider.connectionState == .connected {
                // Provider ready - forward audio directly
                forwardAudioToStreamingProvider(buffer: buffer, provider: provider)
                return
            }

            // Provider is connecting or temporarily disconnected - buffer the audio
            if isStreamingProviderConnecting || streamingProvider != nil {
                bufferAudioForStreaming(buffer: buffer)
                return
            }
        }

        // Otherwise, write to file for batch processing
        guard let file = segmentFile else { return }

        do {
            try file.write(from: buffer)
        } catch {
            // Log but don't interrupt - we'll handle errors when processing
        }
    }

    /// Buffer audio during streaming provider connection or temporary disconnect
    private func bufferAudioForStreaming(buffer: AVAudioPCMBuffer) {
        guard let converter = audioConverter else { return }

        // Calculate output buffer size based on sample rate ratio
        let ratio = Double(streamingTargetSampleRate) / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: converter.outputFormat,
            frameCapacity: outputFrameCapacity
        ) else {
            return
        }

        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, error == nil else { return }

        // Extract PCM16 data
        guard let int16Data = outputBuffer.int16ChannelData else { return }
        let data = Data(bytes: int16Data[0], count: Int(outputBuffer.frameLength) * 2)

        // Add to buffer (with limit to prevent memory issues)
        if pendingStreamingAudio.count < maxPendingAudioChunks {
            pendingStreamingAudio.append(data)
        }
    }

    /// Convert and forward audio buffer to streaming provider
    private func forwardAudioToStreamingProvider(buffer: AVAudioPCMBuffer, provider: StreamingTranscriptionProvider) {
        guard let converter = audioConverter else {
            appLog("No audio converter available", category: "SwiftLink", level: .error)
            return
        }

        // Calculate output buffer size based on sample rate ratio
        let ratio = Double(streamingTargetSampleRate) / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: converter.outputFormat,
            frameCapacity: outputFrameCapacity
        ) else {
            return
        }

        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, error == nil else {
            if let error = error {
                appLog("Audio conversion error: \(error.localizedDescription)", category: "SwiftLink", level: .error)
            }
            return
        }

        // Extract PCM16 data from output buffer
        guard let int16Data = outputBuffer.int16ChannelData else { return }

        let data = Data(bytes: int16Data[0], count: Int(outputBuffer.frameLength) * 2)
        provider.sendAudio(data)
    }

    // MARK: - Audio Processing

    private func processAudioSegment(url: URL?) async {
        guard let url = url else {
            appLog("No audio URL for processing", category: "SwiftLink", level: .error)
            sharedDefaults?.set("error", forKey: Constants.Keys.swiftLinkProcessingStatus)
            sharedDefaults?.set("No audio recorded", forKey: Constants.Keys.swiftLinkTranscriptionResult)
            sharedDefaults?.synchronize()
            DarwinNotificationManager.shared.postResultReady()
            return
        }

        // Capture and reset edit mode state
        let wasEditMode = isEditMode
        isEditMode = false

        appLog("Processing audio segment (editMode: \(wasEditMode))", category: "SwiftLink")

        do {
            let settings = SharedSettings.shared
            let providerFactory = ProviderFactory(settings: settings)

            // Step 1: Transcribe
            guard let transcriptionProvider = providerFactory.createSelectedTranscriptionProvider() else {
                throw SwiftLinkError.recordingFailed("No transcription provider configured")
            }
            let rawText = try await transcriptionProvider.transcribe(
                audioURL: url,
                language: settings.selectedDictationLanguage
            )

            // Step 2: Apply vocabulary
            var processedText = settings.applyVocabulary(to: rawText)

            // Phase 12: Handle edit mode differently
            if wasEditMode {
                processedText = try await processEditMode(
                    instructions: processedText,
                    providerFactory: providerFactory
                )
            } else {
                // Normal formatting flow (two-step: transcription done, now format/translate)
                let mode = settings.selectedMode
                let customTemplate = settings.selectedCustomTemplate
                let activeContext = settings.activeContext

                // Build context for formatting (includes memory, tone, instructions)
                let promptContext = PromptContext.from(
                    settings: settings,
                    context: activeContext,
                    powerMode: nil
                )

                // Determine if we need formatting:
                // 1. Custom template selected
                // 2. Mode is not raw
                // 3. Context is active with content (memory, tone, instructions)
                let needsFormatting = customTemplate != nil || mode != .raw || promptContext.hasContent

                if needsFormatting {
                    if let formattingProvider = providerFactory.createSelectedTextFormattingProvider() {
                        processedText = try await formattingProvider.format(
                            text: processedText,
                            mode: mode,
                            customPrompt: customTemplate?.prompt,
                            context: promptContext
                        )
                    }
                }

                // Translate if enabled (not in edit mode)
                // Translation is always a separate step after formatting
                if settings.isTranslationEnabled {
                    if let translationProvider = providerFactory.createSelectedTranslationProvider() {
                        processedText = try await translationProvider.translate(
                            text: processedText,
                            from: settings.selectedDictationLanguage,
                            to: settings.selectedTargetLanguage
                        )
                    }
                }
            }

            // Store result in App Groups
            sharedDefaults?.set(processedText, forKey: Constants.Keys.swiftLinkTranscriptionResult)
            sharedDefaults?.set("complete", forKey: Constants.Keys.swiftLinkProcessingStatus)

            // Force sync before notifying keyboard
            sharedDefaults?.synchronize()

            // Also update lastTranscription for consistency
            settings.lastTranscription = processedText

            // Copy to clipboard
            UIPasteboard.general.string = processedText

            appLog("Audio segment processed successfully (\(processedText.count) chars, edit: \(wasEditMode))", category: "SwiftLink")

            // Notify keyboard that result is ready (after sync)
            DarwinNotificationManager.shared.postResultReady()

            // Clean up temp file
            try? FileManager.default.removeItem(at: url)

        } catch {
            appLog("Failed to process audio: \(LogSanitizer.sanitizeError(error))", category: "SwiftLink", level: .error)
            sharedDefaults?.set("error", forKey: Constants.Keys.swiftLinkProcessingStatus)
            sharedDefaults?.set(error.localizedDescription, forKey: Constants.Keys.swiftLinkTranscriptionResult)

            // Force sync before notifying keyboard
            sharedDefaults?.synchronize()

            // Still notify keyboard so it knows processing finished (with error)
            DarwinNotificationManager.shared.postResultReady()
        }
    }

    /// Phase 12: Process edit mode - apply LLM edit to original text
    private func processEditMode(instructions: String, providerFactory: ProviderFactory) async throws -> String {
        // Get original text from App Groups
        guard let originalText = sharedDefaults?.string(forKey: Constants.EditMode.swiftLinkEditOriginalText) else {
            throw SwiftLinkError.recordingFailed("No original text found for edit")
        }

        // Get formatting provider for LLM edit
        guard let formattingProvider = providerFactory.createSelectedTextFormattingProvider() else {
            throw SwiftLinkError.recordingFailed("No formatting provider for edit")
        }

        appLog("Edit mode using provider: \(formattingProvider.providerId.displayName), model: \(formattingProvider.model)", category: "SwiftLink")

        // Build edit prompt
        let systemPrompt = """
        You are a text editor. Modify the provided text according to the user's instructions.
        Return ONLY the modified text, nothing else.
        Preserve the original language unless translation is requested.
        """

        let userPrompt = """
        Original text:
        \(originalText)

        Instructions:
        \(instructions)
        """

        appLog("Applying edit: '\(LogSanitizer.sanitizeContent(instructions))' to \(originalText.count) chars", category: "SwiftLink")

        // Call LLM with edit prompt
        let result: String
        do {
            result = try await formattingProvider.format(
                text: userPrompt,
                mode: .raw,
                customPrompt: systemPrompt,
                context: nil
            )
            appLog("Edit LLM call succeeded (\(result.count) chars)", category: "SwiftLink")
        } catch {
            appLog("Edit LLM call failed: \(error)", category: "SwiftLink", level: .error)
            appLog("Error type: \(type(of: error))", category: "SwiftLink", level: .error)
            throw error
        }

        // Save edit to history
        await saveEditToHistory(
            originalText: originalText,
            instructions: instructions,
            result: result,
            providerFactory: providerFactory
        )

        return result
    }

    /// Phase 12: Save edit operation to history
    private func saveEditToHistory(
        originalText: String,
        instructions: String,
        result: String,
        providerFactory: ProviderFactory
    ) async {
        let settings = SharedSettings.shared

        // Find parent entry if original matches a recent transcription
        let parentEntryId = findParentEntryId(for: originalText, in: settings)

        let editContext = EditContext(
            originalText: originalText,
            instructions: instructions,
            parentEntryId: parentEntryId
        )

        // Calculate cost (rough estimate)
        let inputTokens = (originalText.count + instructions.count) / 4
        let outputTokens = result.count / 4
        let formattingCost = CostCalculator().llmCost(
            provider: settings.selectedTranslationProvider,
            model: settings.selectedTranslationProvider.defaultLLMModel ?? "unknown",
            inputTokens: inputTokens,
            outputTokens: outputTokens
        )

        let record = TranscriptionRecord(
            rawTranscribedText: instructions,  // The dictated instructions
            text: result,                       // The edited result
            mode: .raw,
            provider: settings.selectedTranscriptionProvider,
            timestamp: Date(),
            duration: currentDictationDuration,
            translated: false,
            targetLanguage: nil,
            powerModeId: nil,
            powerModeName: nil,
            contextId: nil,
            contextName: nil,
            contextIcon: nil,
            estimatedCost: formattingCost,
            costBreakdown: CostBreakdown(
                transcriptionCost: 0,
                formattingCost: formattingCost,
                translationCost: nil,
                powerModeCost: nil,
                ragCost: nil,
                inputTokens: inputTokens,
                outputTokens: outputTokens
            ),
            processingMetadata: nil,
            editContext: editContext
        )

        settings.addTranscription(record)

        appLog("Edit saved to history (parent: \(parentEntryId?.uuidString ?? "none"))", category: "SwiftLink")
    }

    /// Phase 12: Find parent entry if original text matches a recent transcription
    private func findParentEntryId(for originalText: String, in settings: SharedSettings) -> UUID? {
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)  // 24 hours
        let recentEntries = settings.transcriptionHistory
            .prefix(50)
            .filter { $0.timestamp > cutoff }

        // Match by exact text
        for entry in recentEntries {
            if entry.text == originalText {
                return entry.id
            }
        }

        return nil
    }

    // MARK: - Session Timer

    private func startSessionTimer() {
        sessionTimer?.invalidate()

        guard let duration = sessionDuration.timeInterval else {
            // Duration is "never" - no timer needed
            sessionTimeRemaining = nil
            return
        }

        sessionTimeRemaining = duration

        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSessionTimer()
            }
        }
    }

    private func updateSessionTimer() {
        guard var remaining = sessionTimeRemaining else { return }

        remaining -= 1

        if remaining <= 0 {
            appLog("SwiftLink session timed out", category: "SwiftLink")
            endSession()
        } else {
            sessionTimeRemaining = remaining
        }
    }

    private func startDictationTimer() {
        dictationTimer?.invalidate()

        dictationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startTime = self.dictationStartTime else { return }
                self.currentDictationDuration = Date().timeIntervalSince(startTime)
            }
        }
    }

    // MARK: - Darwin Notification Observers

    private func setupDarwinNotificationObservers() {
        // Observe dictation start from keyboard
        DarwinNotificationManager.shared.observeDictationStart { [weak self] in
            Task { @MainActor in
                self?.markDictationStart()
            }
        }

        // Observe dictation stop from keyboard
        DarwinNotificationManager.shared.observeDictationStop { [weak self] in
            Task { @MainActor in
                self?.markDictationEnd()
            }
        }

        // Phase 12: Observe edit start from keyboard
        DarwinNotificationManager.shared.startObserving(name: Constants.SwiftLinkNotifications.startEdit) { [weak self] in
            Task { @MainActor in
                self?.markEditStart()
            }
        }

        // Phase 13.11: Observe AI process request from keyboard
        DarwinNotificationManager.shared.startObserving(name: Constants.AIProcess.startProcess) { [weak self] in
            Task { @MainActor in
                self?.handleAIProcessRequest()
            }
        }
    }

    // MARK: - Phase 13.11: AI Process Request Handler

    /// Handle AI process request from keyboard (runs context/power mode on entered text)
    private func handleAIProcessRequest() {
        appLog("Received AI process request from keyboard", category: "SwiftLink")

        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        defaults?.synchronize()

        guard let pendingText = defaults?.string(forKey: Constants.AIProcess.pendingText),
              !pendingText.isEmpty else {
            appLog("AI Process: No pending text", category: "SwiftLink", level: .warning)
            defaults?.set("error", forKey: Constants.AIProcess.status)
            defaults?.synchronize()
            DarwinNotificationManager.shared.post(name: Constants.AIProcess.resultReady)
            return
        }

        let contextIdString = defaults?.string(forKey: Constants.AIProcess.contextId)
        let powerModeIdString = defaults?.string(forKey: Constants.AIProcess.powerModeId)

        appLog("AI Process: Starting (text: \(pendingText.count) chars, context: \(contextIdString ?? "none"))", category: "SwiftLink")

        // Set status to processing
        defaults?.set("processing", forKey: Constants.AIProcess.status)
        defaults?.synchronize()

        Task {
            do {
                let settings = SharedSettings.shared
                let startTime = Date()
                var result: String
                var processedWithContext: ConversationContext?
                var processedWithPowerMode: PowerMode?
                var usedProvider: AIProvider = .openAI

                if let contextIdString = contextIdString,
                   let contextId = UUID(uuidString: contextIdString),
                   let context = settings.contexts.first(where: { $0.id == contextId }) {

                    // Process with context
                    result = try await processTextWithContext(pendingText, context: context)
                    processedWithContext = context
                    usedProvider = settings.selectedPowerModeProvider

                } else if let powerModeIdString = powerModeIdString,
                          let powerModeId = UUID(uuidString: powerModeIdString),
                          let powerMode = settings.powerModes.first(where: { $0.id == powerModeId }) {

                    // Process with power mode
                    result = try await processTextWithPowerMode(pendingText, powerMode: powerMode)
                    processedWithPowerMode = powerMode
                    // Get provider from power mode override or default
                    if let override = powerMode.providerOverride {
                        switch override.providerType {
                        case .cloud(let provider): usedProvider = provider
                        case .local: usedProvider = settings.selectedPowerModeProvider
                        }
                    } else {
                        usedProvider = settings.selectedPowerModeProvider
                    }

                } else {
                    // No context or power mode - just return original text
                    appLog("AI Process: No context/power mode found, returning original", category: "SwiftLink", level: .warning)
                    result = pendingText
                }

                // Save history entry if processing was done
                if processedWithContext != nil || processedWithPowerMode != nil {
                    await saveKeyboardAIHistoryEntry(
                        originalText: pendingText,
                        resultText: result,
                        context: processedWithContext,
                        powerMode: processedWithPowerMode,
                        provider: usedProvider,
                        duration: Date().timeIntervalSince(startTime)
                    )
                }

                // Store result
                defaults?.set(result, forKey: Constants.AIProcess.result)
                defaults?.set("complete", forKey: Constants.AIProcess.status)
                defaults?.synchronize()

                // Notify keyboard
                DarwinNotificationManager.shared.post(name: Constants.AIProcess.resultReady)

                appLog("AI Process: Complete (\(result.count) chars)", category: "SwiftLink")

            } catch {
                appLog("AI Process: Error - \(error.localizedDescription)", category: "SwiftLink", level: .error)
                defaults?.set("error", forKey: Constants.AIProcess.status)
                defaults?.synchronize()

                // Notify keyboard of error
                DarwinNotificationManager.shared.post(name: Constants.AIProcess.resultReady)
            }
        }
    }

    /// Save history entry for keyboard AI processing
    private func saveKeyboardAIHistoryEntry(
        originalText: String,
        resultText: String,
        context: ConversationContext?,
        powerMode: PowerMode?,
        provider: AIProvider,
        duration: TimeInterval
    ) async {
        let settings = SharedSettings.shared

        // Calculate cost for formatting operation using CostCalculator
        let inputTokens = originalText.count / 4  // Rough token estimate
        let outputTokens = resultText.count / 4

        let costCalculator = CostCalculator()
        let formattingCost = costCalculator.llmCost(
            provider: provider,
            model: provider.defaultLLMModel ?? "unknown",
            inputTokens: inputTokens,
            outputTokens: outputTokens
        )

        let costBreakdown = CostBreakdown(
            transcriptionCost: 0,  // No transcription for keyboard AI
            formattingCost: formattingCost,
            translationCost: nil,
            powerModeCost: nil,
            ragCost: nil,
            inputTokens: inputTokens,
            outputTokens: outputTokens
        )

        let record = TranscriptionRecord(
            rawTranscribedText: originalText,
            text: resultText,
            mode: .raw,  // Keyboard AI uses custom prompts
            provider: provider,
            duration: duration,
            powerModeId: powerMode?.id,
            powerModeName: powerMode?.name,
            contextId: context?.id,
            contextName: context?.name,
            contextIcon: context?.icon,
            estimatedCost: costBreakdown.total,
            costBreakdown: costBreakdown,
            source: .keyboardAI
        )

        // Save to history
        await MainActor.run {
            settings.transcriptionHistory.insert(record, at: 0)
        }

        appLog("AI Process: History entry saved (cost: $\(String(format: "%.4f", costBreakdown.total)))", category: "SwiftLink")
    }

    private func processTextWithContext(_ text: String, context: ConversationContext) async throws -> String {
        let settings = SharedSettings.shared

        // Build prompt based on context and grammar fix setting
        var systemPrompt = context.customInstructions

        if context.aiAutocorrectEnabled {
            systemPrompt += "\n\nIMPORTANT: Fix any grammar and punctuation errors in the text, but preserve the original words and meaning. Do not add or remove content, only correct grammatical mistakes."
        }

        // Use the formatting provider to process
        let provider = settings.selectedPowerModeProvider
        guard settings.getAIProviderConfig(for: provider) != nil else {
            throw TranscriptionError.providerNotConfigured
        }

        let factory = ProviderFactory()
        guard let formattingService = factory.createFormattingProvider(for: provider) else {
            throw TranscriptionError.providerNotConfigured
        }

        // Create a custom prompt that includes context instructions
        let fullPrompt = """
        Context: \(context.name) - \(context.description)
        Tone: \(context.toneDescription)
        Formality: \(context.formality.displayName)

        \(systemPrompt)

        Process the following text according to the context above. Return only the processed text without any explanation:

        \(text)
        """

        // Use the formatting service with custom mode
        return try await formattingService.format(text: text, mode: FormattingMode.raw, customPrompt: fullPrompt)
    }

    private func processTextWithPowerMode(_ text: String, powerMode: PowerMode) async throws -> String {
        let settings = SharedSettings.shared

        // Build prompt based on power mode and grammar fix setting
        var instruction = powerMode.instruction

        if powerMode.aiAutocorrectEnabled {
            instruction += "\n\nIMPORTANT: Also fix any grammar and punctuation errors in the text, but preserve the original words and meaning."
        }

        // Get the provider from the override if set
        let aiProvider: AIProvider
        if let override = powerMode.providerOverride {
            switch override.providerType {
            case .cloud(let provider):
                aiProvider = provider
            case .local:
                aiProvider = settings.selectedPowerModeProvider
            }
        } else {
            aiProvider = settings.selectedPowerModeProvider
        }

        guard settings.getAIProviderConfig(for: aiProvider) != nil else {
            throw TranscriptionError.providerNotConfigured
        }

        let factory = ProviderFactory()
        guard let formattingService = factory.createFormattingProvider(for: aiProvider) else {
            throw TranscriptionError.providerNotConfigured
        }

        let fullPrompt = """
        \(instruction)

        Process the following text:

        \(text)
        """

        return try await formattingService.format(text: text, mode: FormattingMode.raw, customPrompt: fullPrompt)
    }

    // MARK: - Phase 12: Edit Mode

    /// Mark the start of an edit dictation segment.
    /// Called when keyboard initiates edit mode during active SwiftLink session.
    func markEditStart() {
        guard isSessionActive else {
            appLog("Cannot start edit - no active session", category: "SwiftLink", level: .warning)
            return
        }

        appLog("Marking edit mode start", category: "SwiftLink")

        isEditMode = true  // Set edit mode flag
        dictationStartTime = Date()
        isRecording = true
        currentDictationDuration = 0

        // Store in App Groups for keyboard to read
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: Constants.Keys.swiftLinkDictationStartTime)
        sharedDefaults?.set("recording", forKey: Constants.Keys.swiftLinkProcessingStatus)

        // Start dictation duration timer
        startDictationTimer()

        // Start writing to file from this point
        startSegmentRecording()
    }

    // MARK: - State Persistence

    private func persistSessionState(active: Bool) {
        sharedDefaults?.set(active, forKey: Constants.Keys.swiftLinkSessionActive)
        if active {
            sharedDefaults?.set(Date().timeIntervalSince1970, forKey: Constants.Keys.swiftLinkSessionStartTime)
        } else {
            sharedDefaults?.removeObject(forKey: Constants.Keys.swiftLinkSessionStartTime)
            sharedDefaults?.removeObject(forKey: Constants.Keys.swiftLinkDictationStartTime)
            sharedDefaults?.removeObject(forKey: Constants.Keys.swiftLinkDictationEndTime)
            sharedDefaults?.removeObject(forKey: Constants.Keys.swiftLinkTranscriptionResult)
            sharedDefaults?.removeObject(forKey: Constants.Keys.swiftLinkProcessingStatus)
        }
        // Force flush to ensure keyboard extension sees the updated state immediately
        sharedDefaults?.synchronize()
    }

    private func restoreSessionStateIfNeeded() {
        // Check if there's a persisted session that might still be valid
        // (e.g., app was briefly suspended but not killed)
        let wasActive = sharedDefaults?.bool(forKey: Constants.Keys.swiftLinkSessionActive) ?? false

        if wasActive {
            // Session was active but app was terminated
            // Mark as inactive - user needs to restart
            persistSessionState(active: false)
            appLog("Previous SwiftLink session was terminated", category: "SwiftLink")
        }
    }

    // MARK: - Last Used App

    private func saveLastUsedApp(_ app: SwiftLinkApp) {
        if let encoded = try? JSONEncoder().encode(app) {
            sharedDefaults?.set(encoded, forKey: Constants.Keys.swiftLinkLastUsedApp)
        }
    }

    func getLastUsedApp() -> SwiftLinkApp? {
        guard let data = sharedDefaults?.data(forKey: Constants.Keys.swiftLinkLastUsedApp),
              let app = try? JSONDecoder().decode(SwiftLinkApp.self, from: data)
        else { return nil }
        return app
    }

    // MARK: - Session Status (for keyboard)

    /// Check if session is active (called from keyboard via App Groups)
    static func isSessionActiveFromKeyboard() -> Bool {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        return defaults?.bool(forKey: Constants.Keys.swiftLinkSessionActive) ?? false
    }

    /// Get transcription result (called from keyboard after resultReady notification)
    static func getTranscriptionResult() -> String? {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        return defaults?.string(forKey: Constants.Keys.swiftLinkTranscriptionResult)
    }

    /// Get processing status
    static func getProcessingStatus() -> String? {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        return defaults?.string(forKey: Constants.Keys.swiftLinkProcessingStatus)
    }

    /// Clear transcription result after keyboard has used it
    static func clearTranscriptionResult() {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        defaults?.removeObject(forKey: Constants.Keys.swiftLinkTranscriptionResult)
        defaults?.removeObject(forKey: Constants.Keys.swiftLinkProcessingStatus)
    }
}

// MARK: - SwiftLink App Model

/// Represents an app configured for SwiftLink
struct SwiftLinkApp: Codable, Identifiable, Equatable, Hashable {
    var id: String { bundleId }
    let bundleId: String
    let name: String
    let urlScheme: String?
    let iconName: String?

    init(bundleId: String, name: String, urlScheme: String?, iconName: String? = nil) {
        self.bundleId = bundleId
        self.name = name
        self.urlScheme = urlScheme
        self.iconName = iconName
    }

    /// Create from AppInfo (from AppLibrary)
    /// Note: AppInfo doesn't include URL scheme - looks up from known schemes
    init(from appInfo: AppInfo, urlScheme: String? = nil) {
        self.bundleId = appInfo.id  // AppInfo uses 'id' as bundle ID
        self.name = appInfo.name
        // Use provided scheme, or look up from known schemes
        self.urlScheme = urlScheme ?? Self.knownURLSchemes[appInfo.id]
        self.iconName = nil  // AppInfo doesn't have icon info
    }

    /// Get the effective URL scheme (stored or looked up from known schemes)
    var effectiveURLScheme: String? {
        urlScheme ?? Self.knownURLSchemes[bundleId]
    }

    /// Known URL schemes for popular apps (bundleId -> scheme)
    static let knownURLSchemes: [String: String] = [
        // Messaging - WhatsApp variants (different schemes to distinguish between apps)
        "net.whatsapp.WhatsApp": "whatsapp://",           // Regular WhatsApp
        "net.whatsapp.WhatsAppSMB": "whatsapp-smb://",    // WhatsApp Business (SMB = Small/Medium Business)
        "net.whatsapp.WhatsAppBusiness": "whatsapp-smb://", // Alternative bundle ID for WhatsApp Business
        "com.facebook.Messenger": "fb-messenger://",
        "com.apple.MobileSMS": "sms://",
        "org.telegram.Telegram": "telegram://",
        "com.viber": "viber://",
        "jp.naver.line": "line://",
        "com.tencent.xin": "weixin://",
        "ph.telegra.Telegraph": "telegram://",
        "im.signal.Signal": "signal://",
        "com.hammerandchisel.discord": "discord://",
        "com.skype.skype": "skype://",
        "com.slack.Slack": "slack://",
        "com.microsoft.teams": "msteams://",
        "com.imo.IMO": "imo://",

        // Social Media
        "com.burbn.instagram": "instagram://",
        "com.atebits.Tweetie2": "twitter://",
        "com.facebook.Facebook": "fb://",
        "com.linkedin.LinkedIn": "linkedin://",
        "com.zhiliaoapp.musically": "tiktok://",
        "com.snapchat.Snapchat": "snapchat://",
        "com.pinterest": "pinterest://",
        "com.reddit.Reddit": "reddit://",
        "tv.twitch": "twitch://",
        "com.google.Threads": "barcelona://",

        // Email
        "com.apple.mobilemail": "mailto://",
        "com.google.Gmail": "googlegmail://",
        "com.microsoft.Outlook": "ms-outlook://",
        "com.readdle.smartemail": "spark://",
        "com.airmailapp.airmail": "airmail://",
        "com.yahoo.Aerogram": "ymail://",
        "com.protonmail.protonmail": "protonmail://",

        // Notes & Productivity
        "com.apple.mobilenotes": "mobilenotes://",
        "notion.id": "notion://",
        "com.google.Docs": "googledocs://",
        "com.evernote.iPhone.Evernote": "evernote://",
        "net.shinyfrog.bear": "bear://",
        "com.lukilabs.lukiapp": "craft://",
        "md.obsidian": "obsidian://",
        "com.apple.reminders": "x-apple-reminderkit://",
        "com.todoist.ios": "todoist://",
        "com.culturedcode.ThingsiPhone": "things://",
        "com.omnigroup.OmniFocus3.iOS": "omnifocus://",
        "com.trello.Trello": "trello://",
        "com.asana.Asana": "asana://",

        // Browsers
        "com.apple.mobilesafari": "x-web-search://",
        "com.google.chrome.ios": "googlechrome://",
        "org.mozilla.ios.Firefox": "firefox://",
        "com.brave.ios.browser": "brave://",
        "com.opera.OperaTouch": "opera://",
        "com.duckduckgo.mobile.ios": "ddgQuickLink://",
        "com.AnyOrganization.AnyBrowser": "arc://",

        // Cloud Storage
        "com.google.Drive": "googledrive://",
        "com.getdropbox.Dropbox": "dbapi-1://",
        "com.microsoft.skydrive": "ms-onedrive://",
        "com.apple.iCloudDriveApp": "shareddocuments://",

        // Calendar
        "com.apple.mobilecal": "calshow://",
        "com.flexibits.fantastical2.iphone": "fantastical://",
        "com.google.calendar": "googlecalendar://",

        // Media
        "com.google.ios.youtube": "youtube://",
        "com.spotify.client": "spotify://",
        "com.netflix.Netflix": "nflx://",
        "com.apple.podcasts": "podcasts://",
        "com.audible.iphone": "audible://",

        // Other
        "com.amazon.Amazon": "amazon://",
        "com.ubercab.UberClient": "uber://",
        "com.toyopagroup.picaboo": "lyft://",
        "com.airbnb.app": "airbnb://",
        "com.yelp.yelpiphone": "yelp://",
        "com.zhiliaoapp.musically.go": "snssdk1128://",
    ]
}

// MARK: - SwiftLink Errors

enum SwiftLinkError: LocalizedError {
    case mustStartInForeground
    case audioSessionFailed(String)
    case invalidAudioFormat
    case sessionNotActive
    case recordingFailed(String)

    var errorDescription: String? {
        switch self {
        case .mustStartInForeground:
            return "SwiftLink session must be started while app is in foreground"
        case .audioSessionFailed(let reason):
            return "Audio session failed: \(reason)"
        case .invalidAudioFormat:
            return "Invalid audio format from microphone"
        case .sessionNotActive:
            return "No active SwiftLink session"
        case .recordingFailed(let reason):
            return "Recording failed: \(reason)"
        }
    }
}
