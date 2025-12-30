//
//  TranscriptionFlowIntegrationTests.swift
//  SwiftSpeakTests
//
//  Integration tests for the complete transcription flow
//  Tests state machine, settings, and error handling
//

import Testing
import Foundation
@testable import SwiftSpeak

// MARK: - Transcription Flow Integration Tests

@Suite("Transcription Flow Integration Tests")
@MainActor
struct TranscriptionFlowIntegrationTests {

    // MARK: - State Machine Tests

    @Test("Orchestrator starts in idle state")
    func orchestratorStartsInIdleState() {
        let orchestrator = TranscriptionOrchestrator()
        #expect(orchestrator.state == .idle)
    }

    @Test("Orchestrator state can be reset")
    func orchestratorStateCanBeReset() {
        let orchestrator = TranscriptionOrchestrator()

        // Reset should keep it in idle
        orchestrator.reset()
        #expect(orchestrator.state == .idle)
    }

    @Test("Cancel returns to idle state")
    func cancelReturnsToIdle() {
        let orchestrator = TranscriptionOrchestrator()

        orchestrator.cancel()
        #expect(orchestrator.state == .idle)
    }

    // MARK: - Configuration Tests

    @Test("Mode can be configured")
    func modeCanBeConfigured() {
        let orchestrator = TranscriptionOrchestrator()

        orchestrator.mode = .formal
        #expect(orchestrator.mode == .formal)

        orchestrator.mode = .email
        #expect(orchestrator.mode == .email)
    }

    @Test("Translation settings can be configured")
    func translationSettingsCanBeConfigured() {
        let orchestrator = TranscriptionOrchestrator()

        orchestrator.translateEnabled = true
        orchestrator.targetLanguage = .spanish

        #expect(orchestrator.translateEnabled == true)
        #expect(orchestrator.targetLanguage == .spanish)
    }

    @Test("Source language can be configured")
    func sourceLanguageCanBeConfigured() {
        let orchestrator = TranscriptionOrchestrator()

        orchestrator.sourceLanguage = .english
        #expect(orchestrator.sourceLanguage == .english)

        orchestrator.sourceLanguage = nil
        #expect(orchestrator.sourceLanguage == nil)
    }

    @Test("Custom template can be configured")
    func customTemplateCanBeConfigured() {
        let orchestrator = TranscriptionOrchestrator()
        let template = CustomTemplate(
            name: "Test Template",
            prompt: "Format this text professionally"
        )

        orchestrator.customTemplate = template
        #expect(orchestrator.customTemplate?.name == "Test Template")
    }

    // MARK: - Context Integration Tests

    @Test("Active context can be set")
    func activeContextCanBeSet() {
        let orchestrator = TranscriptionOrchestrator()
        let context = ConversationContext(
            name: "Work",
            icon: "briefcase",
            color: .blue,
            description: "Professional context"
        )

        orchestrator.activeContext = context
        #expect(orchestrator.activeContext?.name == "Work")
    }

    @Test("Active power mode can be set")
    func activePowerModeCanBeSet() {
        let orchestrator = TranscriptionOrchestrator()
        let powerMode = PowerMode(name: "Research")

        orchestrator.activePowerMode = powerMode
        #expect(orchestrator.activePowerMode?.name == "Research")
    }

    // MARK: - Initial State Tests

    @Test("Audio levels initialized correctly")
    func audioLevelsInitializedCorrectly() {
        let orchestrator = TranscriptionOrchestrator()

        #expect(orchestrator.audioLevels.count == 12)
        #expect(orchestrator.audioLevels.allSatisfy { $0 == 0 })
    }

    @Test("Recording duration starts at zero")
    func recordingDurationStartsAtZero() {
        let orchestrator = TranscriptionOrchestrator()
        #expect(orchestrator.recordingDuration == 0)
    }

    @Test("Transcribed text starts empty")
    func transcribedTextStartsEmpty() {
        let orchestrator = TranscriptionOrchestrator()
        #expect(orchestrator.transcribedText.isEmpty)
    }

    @Test("Formatted text starts empty")
    func formattedTextStartsEmpty() {
        let orchestrator = TranscriptionOrchestrator()
        #expect(orchestrator.formattedText.isEmpty)
    }

    @Test("Error message starts nil")
    func errorMessageStartsNil() {
        let orchestrator = TranscriptionOrchestrator()
        #expect(orchestrator.errorMessage == nil)
    }
}

// MARK: - Recording State Additional Tests

@Suite("Recording State Additional Tests")
@MainActor
struct RecordingStateAdditionalTests {

    @Test("Recording state enum has all expected cases")
    func recordingStateHasAllCases() {
        let states: [RecordingState] = [
            .idle,
            .recording,
            .processing,
            .formatting,
            .translating,
            .complete("done"),
            .error("test error")
        ]
        #expect(states.count == 7)
    }

    @Test("State equality works correctly")
    func stateEqualityWorks() {
        #expect(RecordingState.idle == RecordingState.idle)
        #expect(RecordingState.recording == RecordingState.recording)
        #expect(RecordingState.idle != RecordingState.recording)
    }
}

// MARK: - Transcription Error Additional Tests

@Suite("Transcription Error Additional Tests")
@MainActor
struct TranscriptionErrorAdditionalTests {

    @Test("All error types have descriptions")
    func allErrorTypesHaveDescriptions() {
        let errors: [TranscriptionError] = [
            .microphonePermissionDenied,
            .microphonePermissionNotDetermined,
            .recordingFailed("test"),
            .audioSessionConfigurationFailed("test"),
            .audioFileNotFound,
            .fileTooLarge(sizeMB: 30, maxSizeMB: 25),
            .networkError("test"),
            .networkTimeout,
            .serverError(statusCode: 500, message: nil),
            .apiKeyMissing,
            .apiKeyInvalid,
            .rateLimited(retryAfterSeconds: 60),
            .quotaExceeded,
            .providerNotConfigured,
            .emptyResponse,
            .cancelled
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
        }
    }

    @Test("Recoverable errors are marked correctly")
    func recoverableErrorsMarkedCorrectly() {
        // User-recoverable errors
        #expect(TranscriptionError.microphonePermissionDenied.isUserRecoverable == true)
        #expect(TranscriptionError.apiKeyMissing.isUserRecoverable == true)

        // Non-recoverable errors
        #expect(TranscriptionError.serverError(statusCode: 500, message: nil).isUserRecoverable == false)
    }

    @Test("Retryable errors are marked correctly")
    func retryableErrorsMarkedCorrectly() {
        // Should retry
        #expect(TranscriptionError.networkError("test").shouldRetry == true)
        #expect(TranscriptionError.networkTimeout.shouldRetry == true)

        // Should not retry
        #expect(TranscriptionError.apiKeyInvalid.shouldRetry == false)
        #expect(TranscriptionError.cancelled.shouldRetry == false)
    }

    @Test("Errors have appropriate icons")
    func errorsHaveAppropriateIcons() {
        let errors: [TranscriptionError] = [
            .microphonePermissionDenied,
            .networkError("test"),
            .apiKeyMissing,
            .rateLimited(retryAfterSeconds: 60)
        ]

        for error in errors {
            #expect(!error.iconName.isEmpty)
        }
    }
}

// MARK: - History Integration Tests

@Suite("History Integration Tests")
@MainActor
struct HistoryIntegrationTests {

    @Test("History records can be added")
    func historyRecordsCanBeAdded() {
        let settings = SharedSettings.shared
        let originalHistory = settings.transcriptionHistory

        let record = TranscriptionRecord(
            text: "Test transcription",
            mode: .raw,
            provider: .openAI,
            duration: 5.0
        )

        settings.addTranscription(record)

        #expect(settings.transcriptionHistory.contains(where: { $0.id == record.id }))

        // Clean up
        settings.clearHistory()
        settings.transcriptionHistory.forEach { _ in } // Access to restore
        for original in originalHistory {
            settings.addTranscription(original)
        }
    }

    @Test("History has 100 record limit")
    func historyHasRecordLimit() {
        let settings = SharedSettings.shared
        let original = settings.transcriptionHistory
        settings.clearHistory()

        for i in 0..<150 {
            settings.addTranscription(TranscriptionRecord(
                text: "Record \(i)",
                mode: .raw,
                provider: .openAI,
                duration: 1.0
            ))
        }

        #expect(settings.transcriptionHistory.count <= 100)

        // Clean up
        settings.clearHistory()
        for record in original {
            settings.addTranscription(record)
        }
    }

    @Test("History can be cleared")
    func historyCanBeCleared() {
        let settings = SharedSettings.shared

        settings.addTranscription(TranscriptionRecord(
            text: "Test",
            mode: .raw,
            provider: .openAI,
            duration: 1.0
        ))

        settings.clearHistory()
        #expect(settings.transcriptionHistory.isEmpty)
    }
}
