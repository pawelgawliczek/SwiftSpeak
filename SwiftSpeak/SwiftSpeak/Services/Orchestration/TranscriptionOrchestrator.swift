//
//  TranscriptionOrchestrator.swift
//  SwiftSpeak
//
//  Created by Claude Code on 26/12/2025.
//

import Combine
import Foundation
import UIKit

/// Central coordinator for the transcription workflow
/// Manages: recording → transcription → formatting → history
@MainActor
final class TranscriptionOrchestrator: ObservableObject {

    // MARK: - Published State

    /// Current state of the transcription workflow
    @Published private(set) var state: RecordingState = .idle

    /// Raw transcribed text (before formatting)
    @Published private(set) var transcribedText: String = ""

    /// Final formatted text (after applying mode formatting)
    @Published private(set) var formattedText: String = ""

    /// Current recording duration
    @Published private(set) var recordingDuration: TimeInterval = 0

    /// Current audio level (0.0 to 1.0) for waveform
    @Published private(set) var audioLevel: Float = 0

    /// Array of audio levels for waveform visualization
    @Published private(set) var audioLevels: [Float] = Array(repeating: 0, count: 12)

    /// Error message if state is .error
    @Published private(set) var errorMessage: String?

    // MARK: - Configuration

    /// Formatting mode to apply
    var mode: FormattingMode = .raw

    /// Whether to translate after transcription
    var translateEnabled: Bool = false

    /// Target language for translation
    var targetLanguage: Language = .spanish

    /// Source language hint for transcription (nil for auto-detect)
    var sourceLanguage: Language?

    // MARK: - Dependencies

    private let settings: SharedSettings
    private let audioRecorder: AudioRecorder
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        settings: SharedSettings = .shared,
        audioRecorder: AudioRecorder? = nil
    ) {
        self.settings = settings
        self.audioRecorder = audioRecorder ?? AudioRecorder()

        setupBindings()
    }

    private func setupBindings() {
        // Bind audio recorder properties
        audioRecorder.$duration
            .assign(to: &$recordingDuration)

        audioRecorder.$currentLevel
            .assign(to: &$audioLevel)

        // Generate audio levels array from current level
        audioRecorder.$currentLevel
            .map { level in
                (0..<12).map { index in
                    let variance = Float.random(in: -0.15...0.15)
                    let phase = sin(Float(index) * 0.5)
                    return max(0, min(1, level + variance * phase * level))
                }
            }
            .assign(to: &$audioLevels)
    }

    // MARK: - Workflow Control

    /// Start recording audio
    func startRecording() async {
        // Reset state
        transcribedText = ""
        formattedText = ""
        errorMessage = nil

        do {
            state = .recording
            try await audioRecorder.startRecording()
        } catch let error as TranscriptionError {
            handleError(error)
        } catch {
            handleError(.recordingFailed(error.localizedDescription))
        }
    }

    /// Stop recording and process the audio
    func stopRecording() async {
        guard state == .recording else { return }

        do {
            // Stop recording and get audio URL
            let audioURL = try audioRecorder.stopRecording()

            // Transcribe
            state = .processing
            let rawText = try await transcribe(audioURL: audioURL)
            transcribedText = rawText

            // Apply vocabulary replacements
            let processedText = settings.applyVocabulary(to: rawText)

            // Format if needed
            if mode != .raw {
                state = .formatting
                formattedText = try await format(text: processedText)
            } else {
                formattedText = processedText
            }

            // Save to history
            saveToHistory()

            // Update lastTranscription for keyboard
            settings.lastTranscription = formattedText

            // Copy to clipboard
            copyToClipboard()

            // Complete
            state = .complete(formattedText)

            // Clean up audio file
            audioRecorder.deleteRecording()

        } catch let error as TranscriptionError {
            handleError(error)
        } catch {
            handleError(.networkError(error.localizedDescription))
        }
    }

    /// Cancel the current operation
    func cancel() {
        audioRecorder.cancelRecording()
        state = .idle
        transcribedText = ""
        formattedText = ""
        errorMessage = nil
    }

    /// Reset to idle state
    func reset() {
        state = .idle
        transcribedText = ""
        formattedText = ""
        errorMessage = nil
        recordingDuration = 0
        audioLevel = 0
        audioLevels = Array(repeating: 0, count: 12)
    }

    /// Retry after an error
    func retry() async {
        reset()
        await startRecording()
    }

    // MARK: - Transcription

    private func transcribe(audioURL: URL) async throws -> String {
        // Get transcription provider
        guard let provider = createTranscriptionProvider() else {
            throw TranscriptionError.providerNotConfigured
        }

        return try await provider.transcribe(audioURL: audioURL, language: sourceLanguage)
    }

    private func createTranscriptionProvider() -> TranscriptionProvider? {
        let selectedProvider = settings.selectedTranscriptionProvider

        // Get config for selected provider
        guard let config = settings.getAIProviderConfig(for: selectedProvider) else {
            return nil
        }

        // Create provider based on type
        switch selectedProvider {
        case .openAI:
            return OpenAITranscriptionService(config: config)
        case .elevenLabs, .deepgram, .local:
            // TODO: Implement other providers in Phase 3
            return nil
        default:
            return nil
        }
    }

    // MARK: - Formatting

    private func format(text: String) async throws -> String {
        // Get formatting provider (can be different from transcription provider)
        guard let provider = createFormattingProvider() else {
            // If no formatting provider, return original text
            return text
        }

        return try await provider.format(text: text, mode: mode, customPrompt: nil)
    }

    private func createFormattingProvider() -> FormattingProvider? {
        // Use translation provider for formatting (it's an LLM)
        let selectedProvider = settings.selectedTranslationProvider

        // Get config for selected provider
        guard let config = settings.getAIProviderConfig(for: selectedProvider) else {
            // Try using transcription provider if it supports LLM
            if let transcriptionConfig = settings.getAIProviderConfig(for: settings.selectedTranscriptionProvider),
               settings.selectedTranscriptionProvider == .openAI {
                return OpenAIFormattingService(config: transcriptionConfig)
            }
            return nil
        }

        // Create provider based on type
        switch selectedProvider {
        case .openAI:
            return OpenAIFormattingService(config: config)
        case .anthropic, .google, .local:
            // TODO: Implement other providers in Phase 3
            return nil
        default:
            return nil
        }
    }

    // MARK: - History

    private func saveToHistory() {
        let record = TranscriptionRecord(
            id: UUID(),
            text: formattedText.isEmpty ? transcribedText : formattedText,
            mode: mode,
            provider: settings.selectedTranscriptionProvider,
            timestamp: Date(),
            duration: recordingDuration,
            translated: translateEnabled,
            targetLanguage: translateEnabled ? targetLanguage : nil
        )

        settings.addTranscription(record)
    }

    // MARK: - Clipboard

    private func copyToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = formattedText
        #endif
    }

    // MARK: - Error Handling

    private func handleError(_ error: TranscriptionError) {
        let message = error.errorDescription ?? "An error occurred"
        state = .error(message)
        errorMessage = message
        audioRecorder.cancelRecording()
    }
}

// MARK: - Convenience Properties

extension TranscriptionOrchestrator {
    /// Whether currently recording
    var isRecording: Bool {
        state == .recording
    }

    /// Whether processing (transcribing or formatting)
    var isProcessing: Bool {
        state == .processing || state == .formatting
    }

    /// Whether the workflow is complete
    var isComplete: Bool {
        if case .complete = state { return true }
        return false
    }

    /// Whether there was an error
    var hasError: Bool {
        if case .error = state { return true }
        return false
    }

    /// Whether idle and ready to start
    var isIdle: Bool {
        state == .idle
    }

    /// The result text (formatted or raw)
    var resultText: String {
        formattedText.isEmpty ? transcribedText : formattedText
    }

    /// Provider name for display
    var transcriptionProviderName: String {
        settings.selectedTranscriptionProvider.displayName
    }

    /// Model name for display
    var transcriptionModelName: String? {
        settings.getAIProviderConfig(for: settings.selectedTranscriptionProvider)?.transcriptionModel
    }

    /// Formatting provider name for display
    var formattingProviderName: String? {
        guard mode != .raw else { return nil }
        return settings.selectedTranslationProvider.displayName
    }
}
