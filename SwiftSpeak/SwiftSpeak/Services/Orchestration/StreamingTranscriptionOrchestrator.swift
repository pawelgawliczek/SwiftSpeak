//
//  StreamingTranscriptionOrchestrator.swift
//  SwiftSpeak
//
//  Orchestrates streaming transcription with real-time text updates
//

import Foundation
import Combine
import SwiftSpeakCore

/// Orchestrates streaming transcription using WebSocket-based providers
/// Provides real-time transcript updates as the user speaks
@MainActor
final class StreamingTranscriptionOrchestrator: ObservableObject {

    // MARK: - Published State

    @Published private(set) var state: StreamingState = .idle
    @Published private(set) var partialTranscript: String = ""
    @Published private(set) var fullTranscript: String = ""
    @Published private(set) var error: TranscriptionError?
    @Published private(set) var audioLevel: Float = 0

    // MARK: - State Enum

    enum StreamingState: Equatable {
        case idle
        case connecting
        case streaming
        case processing // Post-stream processing (formatting, translation)
        case complete
        case error
    }

    // MARK: - Properties

    private var streamingProvider: StreamingTranscriptionProvider?
    private var streamingAudioRecorder: StreamingAudioRecorder?
    private var cancellables = Set<AnyCancellable>()

    private let settings: SharedSettings
    private let providerFactory: ProviderFactory

    // For formatting and translation after streaming
    private var formattingProvider: FormattingProvider?
    private var translationProvider: TranslationProvider?

    // MARK: - Initialization

    init(settings: SharedSettings = .shared, providerFactory: ProviderFactory? = nil) {
        self.settings = settings
        self.providerFactory = providerFactory ?? ProviderFactory(settings: settings)
    }

    // MARK: - Streaming Control

    /// Start streaming transcription
    func startStreaming() async throws {
        appLog("startStreaming() called, current state: \(String(describing: self.state))", category: "StreamingOrch")

        guard state == .idle else {
            appLog("Cannot start streaming: already in state \(String(describing: self.state))", category: "StreamingOrch", level: .warning)
            return
        }

        state = .connecting
        appLog("State changed to: connecting", category: "StreamingOrch")
        error = nil
        partialTranscript = ""
        fullTranscript = ""

        // Create streaming provider based on selected transcription provider
        let providerName = settings.selectedTranscriptionProvider.displayName
        appLog("Creating streaming provider for: \(providerName)", category: "StreamingOrch")
        let provider: StreamingTranscriptionProvider
        do {
            provider = try createStreamingProvider()
            self.streamingProvider = provider
            appLog("Created streaming provider: \(provider.providerId.displayName)", category: "StreamingOrch")
        } catch {
            appLog("Failed to create streaming provider: \(error.localizedDescription)", category: "StreamingOrch", level: .error)
            self.error = error as? TranscriptionError ?? .providerNotConfigured
            state = .error
            throw error
        }

        // Determine sample rate based on provider
        let sampleRate: Int
        if provider.providerId == .openAI {
            sampleRate = OpenAIStreamingService.requiredSampleRate // 24kHz
        } else {
            sampleRate = 16000 // Standard for Deepgram/AssemblyAI
        }
        appLog("Using sample rate: \(sampleRate) Hz", category: "StreamingOrch")

        // Create streaming audio recorder
        let recorder = StreamingAudioRecorder(sampleRate: sampleRate)
        self.streamingAudioRecorder = recorder
        appLog("Created streaming audio recorder", category: "StreamingOrch")

        // Subscribe to provider updates
        setupProviderSubscriptions(provider)

        // Setup audio chunk forwarding
        recorder.onAudioChunk = { [weak self, weak provider] data in
            provider?.sendAudio(data)
            Task { @MainActor in
                self?.audioLevel = recorder.currentLevel
            }
        }

        // Build transcription hints from context (domain jargon, vocabulary, etc.)
        // DEBUG: Log context state at streaming start
        appLog("StreamingOrch.startStreaming: settings.activeContextId=\(settings.activeContextId?.uuidString.prefix(8) ?? "nil")", category: "Context", level: .debug)
        appLog("StreamingOrch.startStreaming: settings.activeContext='\(settings.activeContext?.name ?? "nil")'", category: "Context", level: .debug)

        let promptContext = PromptContext.from(
            settings: settings,
            context: settings.activeContext,
            powerMode: nil
        )
        let transcriptionPrompt = promptContext.buildTranscriptionHint()

        if let hint = transcriptionPrompt {
            appLog("Connecting to streaming service with domain hint: \(hint.prefix(60))...", category: "StreamingOrch")
        } else {
            appLog("Connecting to streaming service...", category: "StreamingOrch")
        }

        // Connect to streaming service with domain hints
        do {
            try await provider.connect(
                language: settings.selectedDictationLanguage,
                sampleRate: sampleRate,
                transcriptionPrompt: transcriptionPrompt
            )
            appLog("Connected to streaming service successfully", category: "StreamingOrch")
        } catch {
            appLog("Failed to connect to streaming service: \(error.localizedDescription)", category: "StreamingOrch", level: .error)
            self.error = error as? TranscriptionError ?? .networkError(error.localizedDescription)
            state = .error
            throw error
        }

        // Start recording
        appLog("Starting audio recording...", category: "StreamingOrch")
        do {
            try await recorder.startRecording()
            state = .streaming
            appLog("Streaming transcription started, state: streaming", category: "StreamingOrch")
        } catch {
            appLog("Failed to start recording: \(error.localizedDescription)", category: "StreamingOrch", level: .error)
            provider.disconnect()
            self.error = error as? TranscriptionError ?? .recordingFailed(error.localizedDescription)
            state = .error
            throw error
        }
    }

    /// Stop streaming and finalize transcription using hybrid approach
    /// - Real-time streaming provides visual feedback during recording
    /// - Final transcription uses batch Whisper API for better quality/grammar
    func stopStreaming() async -> String? {
        appLog("stopStreaming() called, current state: \(String(describing: self.state))", category: "StreamingOrch")

        guard state == .streaming else {
            appLog("Cannot stop streaming: not in streaming state (current: \(String(describing: self.state)))", category: "StreamingOrch", level: .warning)
            return nil
        }

        // Wait for all in-flight audio chunks to be accumulated
        // The audio tap runs on a background queue and may have data in transit
        // Use 300ms to ensure we capture the final audio chunks from the audio engine
        try? await Task.sleep(nanoseconds: 300_000_000)  // 300ms buffer flush time

        // Stop recording and get accumulated audio before cleanup
        appLog("Stopping audio recorder...", category: "StreamingOrch")
        let audioURL = streamingAudioRecorder?.saveAccumulatedAudioAsWAV()
        streamingAudioRecorder?.stopRecording()

        // Signal end of audio to streaming provider (for cleanup)
        appLog("Signaling end of audio to streaming provider...", category: "StreamingOrch")
        streamingProvider?.finishAudio()

        // Get provider type before disconnecting
        let isOpenAI = streamingProvider?.providerId == .openAI

        // Disconnect streaming service
        appLog("Disconnecting from streaming service...", category: "StreamingOrch")
        streamingProvider?.disconnect()
        streamingProvider = nil

        // HYBRID APPROACH (OpenAI only): Use batch Whisper API for final transcription
        // OpenAI streaming is good for real-time feedback but Whisper API provides
        // better quality and grammar handling when processing the full audio
        // Other providers (Deepgram, AssemblyAI) have good streaming quality, use their result directly
        var transcript = ""

        if isOpenAI, let audioURL = audioURL {
            appLog("OpenAI hybrid approach: sending full audio to Whisper API for final transcription...", category: "StreamingOrch")
            state = .processing

            do {
                transcript = try await transcribeWithWhisper(audioURL: audioURL)
                appLog("Whisper transcription complete: \(transcript.count) chars", category: "StreamingOrch")

                // Clean up temp file
                try? FileManager.default.removeItem(at: audioURL)
            } catch {
                appLog("Whisper transcription failed: \(error.localizedDescription), falling back to streaming result", category: "StreamingOrch", level: .warning)
                // Fall back to streaming result
                transcript = fullTranscript.trimmingCharacters(in: .whitespacesAndNewlines)

                // Clean up temp file
                try? FileManager.default.removeItem(at: audioURL)
            }
        } else {
            // For non-OpenAI providers or if no audio file, use streaming result directly
            if !isOpenAI {
                appLog("Using streaming result directly (provider: \(settings.selectedTranscriptionProvider.displayName))", category: "StreamingOrch")
            } else {
                appLog("No audio file saved, using streaming result", category: "StreamingOrch", level: .warning)
            }
            transcript = fullTranscript.trimmingCharacters(in: .whitespacesAndNewlines)

            // Clean up temp file if exists
            if let audioURL = audioURL {
                try? FileManager.default.removeItem(at: audioURL)
            }
        }

        // Clean up recorder
        streamingAudioRecorder?.clearAccumulatedAudio()
        streamingAudioRecorder = nil

        if transcript.isEmpty {
            appLog("Transcript is empty, returning to idle state", category: "StreamingOrch", level: .warning)
            state = .idle
            return nil
        }

        // Apply formatting and translation if needed
        appLog("Post-processing transcript (\(transcript.count) chars)...", category: "StreamingOrch")
        state = .processing
        let finalText = await postProcess(transcript)

        state = .complete
        appLog("Streaming transcription complete: \(finalText.count) chars", category: "StreamingOrch")

        // Don't auto-reset - let the view handle dismissal
        return finalText
    }

    /// Transcribe audio file using batch Whisper API (better quality than streaming)
    private func transcribeWithWhisper(audioURL: URL) async throws -> String {
        // Get the transcription provider (should be OpenAI for streaming)
        guard let provider = providerFactory.createTranscriptionProvider(for: settings.selectedTranscriptionProvider) else {
            throw TranscriptionError.providerNotConfigured
        }

        appLog("Calling Whisper API with audio file: \(audioURL.lastPathComponent)", category: "StreamingOrch")

        // Use the standard transcription method
        let transcript = try await provider.transcribe(
            audioURL: audioURL,
            language: settings.selectedDictationLanguage
        )

        return transcript
    }

    /// Cancel streaming without processing
    func cancel() {
        appLog("cancel() called, current state: \(String(describing: self.state))", category: "StreamingOrch")
        streamingAudioRecorder?.cancelRecording()
        streamingProvider?.disconnect()
        streamingProvider = nil
        streamingAudioRecorder = nil
        reset()
    }

    /// Reset to idle state
    func reset() {
        appLog("reset() called, previous state: \(String(describing: self.state))", category: "StreamingOrch")
        state = .idle
        partialTranscript = ""
        fullTranscript = ""
        error = nil
        audioLevel = 0
        cancellables.removeAll()
    }

    // MARK: - Provider Creation

    private func createStreamingProvider() throws -> StreamingTranscriptionProvider {
        let selectedProvider = settings.selectedTranscriptionProvider
        appLog("createStreamingProvider() for: \(selectedProvider.displayName)", category: "StreamingOrch")

        // Get provider config
        guard let config = settings.configuredAIProviders.first(where: { $0.provider == selectedProvider }) else {
            appLog("No config found for provider: \(selectedProvider.displayName)", category: "StreamingOrch", level: .error)
            throw TranscriptionError.providerNotConfigured
        }
        appLog("Found config for provider, API key present: \(!config.apiKey.isEmpty)", category: "StreamingOrch")

        // Create appropriate streaming service
        switch selectedProvider {
        case .openAI:
            appLog("Creating OpenAI streaming service...", category: "StreamingOrch")
            guard let service = OpenAIStreamingService(config: config) else {
                throw TranscriptionError.providerNotConfigured
            }
            return service

        case .deepgram:
            appLog("Creating Deepgram streaming service...", category: "StreamingOrch")
            guard let service = DeepgramStreamingService(config: config) else {
                appLog("Failed to create Deepgram streaming service", category: "StreamingOrch", level: .error)
                throw TranscriptionError.providerNotConfigured
            }
            return service

        case .assemblyAI:
            appLog("Creating AssemblyAI streaming service...", category: "StreamingOrch")
            // Use shared service from SwiftSpeakCore
            guard let service = SwiftSpeakCore.AssemblyAIStreamingService(config: config) else {
                appLog("Failed to create AssemblyAI streaming service", category: "StreamingOrch", level: .error)
                throw TranscriptionError.providerNotConfigured
            }
            return service

        default:
            // Provider doesn't support streaming
            appLog("Provider \(selectedProvider.displayName) does not support streaming", category: "StreamingOrch", level: .error)
            throw TranscriptionError.unexpectedResponse("Provider \(selectedProvider.displayName) does not support streaming")
        }
    }

    private func setupProviderSubscriptions(_ provider: StreamingTranscriptionProvider) {
        appLog("Setting up provider subscriptions...", category: "StreamingOrch")

        // Subscribe to partial transcripts - ACCUMULATE them for real-time display
        provider.partialTranscriptPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self else { return }
                // Append each delta to build up the real-time transcript
                self.partialTranscript += text
                appLog("Partial transcript now: \(self.partialTranscript.suffix(30))...", category: "StreamingOrch", level: .debug)
            }
            .store(in: &cancellables)

        // Subscribe to final transcripts - when received, clear partial and add to full
        provider.finalTranscriptPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self else { return }
                appLog("Received final transcript segment: \(text.count) chars", category: "StreamingOrch")
                // Add to full transcript
                self.fullTranscript += text + " "
                // Clear partial transcript for next utterance
                self.partialTranscript = ""
            }
            .store(in: &cancellables)

        appLog("Provider subscriptions set up", category: "StreamingOrch")
    }

    // MARK: - Post Processing

    private func postProcess(_ transcript: String) async -> String {
        var result = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        // Apply vocabulary replacements
        result = applyVocabularyReplacements(result)

        // Apply formatting if not raw mode
        if settings.selectedMode != .raw {
            if let formatted = await applyFormatting(result) {
                result = formatted
            }
        }

        // Apply translation if enabled
        if settings.isTranslationEnabled {
            if let translated = await applyTranslation(result) {
                result = translated
            }
        }

        return result
    }

    private func applyVocabularyReplacements(_ text: String) -> String {
        var result = text
        for entry in settings.vocabularyEntries where entry.isEnabled {
            result = result.replacingOccurrences(
                of: entry.recognizedWord,
                with: entry.replacementWord,
                options: [.caseInsensitive]
            )
        }
        return result
    }

    private func applyFormatting(_ text: String) async -> String? {
        // Use the formatting provider for the selected transcription provider
        guard let provider = providerFactory.createFormattingProvider(for: settings.selectedTranscriptionProvider) else {
            // Try using the translation provider for formatting if transcription provider doesn't support it
            guard let fallbackProvider = providerFactory.createFormattingProvider(for: settings.selectedTranslationProvider) else {
                return nil
            }
            return try? await fallbackProvider.format(
                text: text,
                mode: settings.selectedMode,
                customPrompt: settings.selectedCustomTemplate?.prompt
            )
        }

        do {
            return try await provider.format(
                text: text,
                mode: settings.selectedMode,
                customPrompt: settings.selectedCustomTemplate?.prompt
            )
        } catch {
            appLog("Formatting failed: \(error.localizedDescription)", category: "StreamingOrch", level: .error)
            return nil
        }
    }

    private func applyTranslation(_ text: String) async -> String? {
        // Get translation provider
        guard let provider = providerFactory.createTranslationProvider(for: settings.selectedTranslationProvider) else {
            return nil
        }

        do {
            return try await provider.translate(
                text: text,
                from: settings.selectedDictationLanguage,
                to: settings.selectedTargetLanguage
            )
        } catch {
            appLog("Translation failed: \(error.localizedDescription)", category: "StreamingOrch", level: .error)
            return nil
        }
    }

    // MARK: - Streaming Availability

    /// Check if streaming is available for the current provider
    var isStreamingAvailable: Bool {
        let provider = settings.selectedTranscriptionProvider
        return provider == .openAI || provider == .deepgram || provider == .assemblyAI
    }

    /// Get the display name of the current streaming provider
    var streamingProviderName: String? {
        guard isStreamingAvailable else { return nil }
        return settings.selectedTranscriptionProvider.displayName
    }
}
