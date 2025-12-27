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

    /// Custom template for formatting (overrides mode if set)
    var customTemplate: CustomTemplate?

    /// Whether to translate after transcription
    var translateEnabled: Bool = false

    /// Target language for translation
    var targetLanguage: Language = .spanish

    /// Source language hint for transcription (nil for auto-detect)
    var sourceLanguage: Language?

    // MARK: - Dependencies

    private let settings: SharedSettings
    private let audioRecorder: AudioRecorder
    private let providerFactory: ProviderFactory
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        settings: SharedSettings? = nil,
        audioRecorder: AudioRecorder? = nil,
        providerFactory: ProviderFactory? = nil
    ) {
        let resolvedSettings = settings ?? SharedSettings.shared
        self.settings = resolvedSettings
        self.audioRecorder = audioRecorder ?? AudioRecorder()
        self.providerFactory = providerFactory ?? ProviderFactory(settings: resolvedSettings)

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

            // Format if needed (custom template or built-in mode)
            if customTemplate != nil || mode != .raw {
                state = .formatting
                formattedText = try await format(text: processedText)
            } else {
                formattedText = processedText
            }

            // Translate if enabled
            if translateEnabled {
                state = .translating
                formattedText = try await translate(text: formattedText)
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
        // Get transcription provider via factory
        guard let provider = providerFactory.createSelectedTranscriptionProvider() else {
            throw TranscriptionError.providerNotConfigured
        }

        return try await provider.transcribe(audioURL: audioURL, language: sourceLanguage)
    }

    // MARK: - Formatting

    private func format(text: String) async throws -> String {
        // Get formatting provider via factory
        guard let provider = providerFactory.createSelectedTextFormattingProvider() else {
            // If no formatting provider, return original text
            return text
        }

        // Use custom template prompt if provided, otherwise use mode
        let customPrompt = customTemplate?.prompt
        return try await provider.format(text: text, mode: mode, customPrompt: customPrompt)
    }

    // MARK: - Translation

    private func translate(text: String) async throws -> String {
        // Get translation provider via factory
        guard let provider = providerFactory.createSelectedTranslationProvider() else {
            throw TranscriptionError.providerNotConfigured
        }

        return try await provider.translate(text: text, from: sourceLanguage, to: targetLanguage)
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
