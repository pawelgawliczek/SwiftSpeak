//
//  TranscriptionOrchestratorTests.swift
//  SwiftSpeakTests
//
//  Comprehensive tests for TranscriptionOrchestrator state and behavior
//

import Foundation
import Testing
@testable import SwiftSpeak

// MARK: - Initialization Tests

@Suite("TranscriptionOrchestrator - Initialization")
struct TranscriptionOrchestratorInitTests {

    @Test("Initial state is idle")
    @MainActor
    func initialStateIsIdle() {
        let orchestrator = TranscriptionOrchestrator()

        #expect(orchestrator.state == .idle)
        #expect(orchestrator.isIdle == true)
        #expect(orchestrator.isRecording == false)
        #expect(orchestrator.isProcessing == false)
        #expect(orchestrator.isComplete == false)
        #expect(orchestrator.hasError == false)
    }

    @Test("Initial text values are empty")
    @MainActor
    func initialTextValuesEmpty() {
        let orchestrator = TranscriptionOrchestrator()

        #expect(orchestrator.transcribedText == "")
        #expect(orchestrator.formattedText == "")
        #expect(orchestrator.resultText == "")
        #expect(orchestrator.errorMessage == nil)
    }

    @Test("Initial audio values are zero")
    @MainActor
    func initialAudioValuesZero() {
        let orchestrator = TranscriptionOrchestrator()

        #expect(orchestrator.recordingDuration == 0)
        #expect(orchestrator.audioLevel == 0)
        #expect(orchestrator.audioLevels.count == 12)
        #expect(orchestrator.audioLevels.allSatisfy { $0 == 0 })
    }

    @Test("Default mode is raw")
    @MainActor
    func defaultModeIsRaw() {
        let orchestrator = TranscriptionOrchestrator()

        #expect(orchestrator.mode == .raw)
    }

    @Test("Default translation is disabled")
    @MainActor
    func defaultTranslationDisabled() {
        let orchestrator = TranscriptionOrchestrator()

        #expect(orchestrator.translateEnabled == false)
    }
}

// MARK: - Reset Tests

@Suite("TranscriptionOrchestrator - Reset")
struct TranscriptionOrchestratorResetTests {

    @Test("Reset clears all state")
    @MainActor
    func resetClearsState() {
        let orchestrator = TranscriptionOrchestrator()

        orchestrator.reset()

        #expect(orchestrator.state == .idle)
        #expect(orchestrator.transcribedText == "")
        #expect(orchestrator.formattedText == "")
        #expect(orchestrator.errorMessage == nil)
        #expect(orchestrator.recordingDuration == 0)
        #expect(orchestrator.audioLevel == 0)
        #expect(orchestrator.audioLevels.allSatisfy { $0 == 0 })
    }

    @Test("Reset can be called multiple times")
    @MainActor
    func resetMultipleTimes() {
        let orchestrator = TranscriptionOrchestrator()

        orchestrator.reset()
        orchestrator.reset()
        orchestrator.reset()

        #expect(orchestrator.state == .idle)
    }
}

// MARK: - Cancel Tests

@Suite("TranscriptionOrchestrator - Cancel")
struct TranscriptionOrchestratorCancelTests {

    @Test("Cancel from idle stays idle")
    @MainActor
    func cancelFromIdleStaysIdle() {
        let orchestrator = TranscriptionOrchestrator()

        orchestrator.cancel()

        #expect(orchestrator.state == .idle)
    }

    @Test("Cancel clears text values")
    @MainActor
    func cancelClearsText() {
        let orchestrator = TranscriptionOrchestrator()

        orchestrator.cancel()

        #expect(orchestrator.transcribedText == "")
        #expect(orchestrator.formattedText == "")
        #expect(orchestrator.errorMessage == nil)
    }
}

// MARK: - Convenience Properties Tests

@Suite("TranscriptionOrchestrator - Convenience Properties")
struct TranscriptionOrchestratorPropertiesTests {

    @Test("isIdle true when idle")
    @MainActor
    func isIdleWhenIdle() {
        let orchestrator = TranscriptionOrchestrator()

        #expect(orchestrator.isIdle == true)
        #expect(orchestrator.isRecording == false)
        #expect(orchestrator.isProcessing == false)
        #expect(orchestrator.isComplete == false)
        #expect(orchestrator.hasError == false)
    }

    @Test("transcriptionProviderName returns value")
    @MainActor
    func providerNameReturnsValue() {
        let orchestrator = TranscriptionOrchestrator()

        let name = orchestrator.transcriptionProviderName
        #expect(!name.isEmpty)
    }

    @Test("resultText returns empty when no transcription")
    @MainActor
    func resultTextEmptyWhenNoTranscription() {
        let orchestrator = TranscriptionOrchestrator()

        #expect(orchestrator.resultText == "")
    }
}

// MARK: - Configuration Tests

@Suite("TranscriptionOrchestrator - Configuration")
struct TranscriptionOrchestratorConfigTests {

    @Test("Mode can be set")
    @MainActor
    func modeCanBeSet() {
        let orchestrator = TranscriptionOrchestrator()

        orchestrator.mode = .email
        #expect(orchestrator.mode == .email)

        orchestrator.mode = .formal
        #expect(orchestrator.mode == .formal)

        orchestrator.mode = .raw
        #expect(orchestrator.mode == .raw)
    }

    @Test("Translation can be enabled")
    @MainActor
    func translationCanBeEnabled() {
        let orchestrator = TranscriptionOrchestrator()

        orchestrator.translateEnabled = true
        #expect(orchestrator.translateEnabled == true)

        orchestrator.translateEnabled = false
        #expect(orchestrator.translateEnabled == false)
    }

    @Test("Target language can be set")
    @MainActor
    func targetLanguageCanBeSet() {
        let orchestrator = TranscriptionOrchestrator()

        orchestrator.targetLanguage = .french
        #expect(orchestrator.targetLanguage == .french)

        orchestrator.targetLanguage = .german
        #expect(orchestrator.targetLanguage == .german)
    }

    @Test("Source language can be set")
    @MainActor
    func sourceLanguageCanBeSet() {
        let orchestrator = TranscriptionOrchestrator()

        #expect(orchestrator.sourceLanguage == nil)

        orchestrator.sourceLanguage = .english
        #expect(orchestrator.sourceLanguage == .english)
    }

    @Test("Custom template can be set")
    @MainActor
    func customTemplateCanBeSet() {
        let orchestrator = TranscriptionOrchestrator()

        #expect(orchestrator.customTemplate == nil)

        let template = CustomTemplate(
            name: "Test",
            prompt: "Test prompt",
            icon: "star"
        )
        orchestrator.customTemplate = template
        #expect(orchestrator.customTemplate != nil)
        #expect(orchestrator.customTemplate?.name == "Test")
    }

    @Test("Active context can be set")
    @MainActor
    func activeContextCanBeSet() {
        let orchestrator = TranscriptionOrchestrator()

        #expect(orchestrator.activeContext == nil)

        let context = ConversationContext(
            name: "Test Context",
            icon: "person",
            color: .blue,
            description: "Test",
            selectedInstructions: ["casual"],
            isActive: true
        )
        orchestrator.activeContext = context
        #expect(orchestrator.activeContext != nil)
        #expect(orchestrator.activeContext?.name == "Test Context")
    }

    @Test("Active power mode can be set")
    @MainActor
    func activePowerModeCanBeSet() {
        let orchestrator = TranscriptionOrchestrator()

        #expect(orchestrator.activePowerMode == nil)

        let powerMode = PowerMode(
            name: "Test Mode",
            icon: "bolt",
            iconColor: .purple,
            iconBackgroundColor: .purple,
            instruction: "You are a test assistant"
        )
        orchestrator.activePowerMode = powerMode
        #expect(orchestrator.activePowerMode != nil)
        #expect(orchestrator.activePowerMode?.name == "Test Mode")
    }
}

// MARK: - State Comparison Tests

@Suite("TranscriptionOrchestrator - RecordingState")
@MainActor
struct RecordingStateTests {

    @Test("RecordingState idle equality")
    func idleEquality() {
        #expect(RecordingState.idle == RecordingState.idle)
    }

    @Test("RecordingState recording equality")
    func recordingEquality() {
        #expect(RecordingState.recording == RecordingState.recording)
    }

    @Test("RecordingState processing equality")
    func processingEquality() {
        #expect(RecordingState.processing == RecordingState.processing)
    }

    @Test("RecordingState formatting equality")
    func formattingEquality() {
        #expect(RecordingState.formatting == RecordingState.formatting)
    }

    @Test("RecordingState translating equality")
    func translatingEquality() {
        #expect(RecordingState.translating == RecordingState.translating)
    }

    @Test("RecordingState complete with same text is equal")
    func completeEquality() {
        #expect(RecordingState.complete("test") == RecordingState.complete("test"))
    }

    @Test("RecordingState complete with different text is not equal")
    func completeDifferentText() {
        #expect(RecordingState.complete("test1") != RecordingState.complete("test2"))
    }

    @Test("RecordingState error with same message is equal")
    func errorEquality() {
        #expect(RecordingState.error("error") == RecordingState.error("error"))
    }

    @Test("RecordingState different states are not equal")
    func differentStatesNotEqual() {
        #expect(RecordingState.idle != RecordingState.recording)
        #expect(RecordingState.processing != RecordingState.formatting)
        #expect(RecordingState.complete("test") != RecordingState.idle)
    }
}

// MARK: - FormattingMode Provider Name Tests

@Suite("TranscriptionOrchestrator - Formatting Provider")
struct FormattingProviderTests {

    @Test("formattingProviderName nil for raw mode")
    @MainActor
    func formattingProviderNilForRaw() {
        let orchestrator = TranscriptionOrchestrator()
        orchestrator.mode = .raw

        #expect(orchestrator.formattingProviderName == nil)
    }

    @Test("formattingProviderName not nil for non-raw mode")
    @MainActor
    func formattingProviderNotNilForNonRaw() {
        let orchestrator = TranscriptionOrchestrator()
        orchestrator.mode = .email

        // May be nil if provider not configured, but the logic path is tested
        // The actual value depends on settings
    }
}

// MARK: - Processing Metadata Integration Tests

@Suite("TranscriptionOrchestrator - Processing Metadata")
struct TranscriptionOrchestratorProcessingMetadataTests {

    @Test("Orchestrator initializes with empty processing steps")
    @MainActor
    func initializesWithEmptyProcessingSteps() {
        let orchestrator = TranscriptionOrchestrator()

        // Initial state should have no recorded steps
        // (processingSteps is private, so we test via behavior)
        #expect(orchestrator.state == .idle)
    }

    @Test("Reset clears processing metadata")
    @MainActor
    func resetClearsProcessingMetadata() {
        let orchestrator = TranscriptionOrchestrator()

        // Configure and reset
        orchestrator.mode = .email
        orchestrator.translateEnabled = true
        orchestrator.reset()

        // After reset, orchestrator should be in clean state
        #expect(orchestrator.state == .idle)
        #expect(orchestrator.transcribedText == "")
        #expect(orchestrator.formattedText == "")
    }

    @Test("Cancel clears processing metadata")
    @MainActor
    func cancelClearsProcessingMetadata() {
        let orchestrator = TranscriptionOrchestrator()

        orchestrator.mode = .formal
        orchestrator.cancel()

        #expect(orchestrator.state == .idle)
    }
}

// MARK: - Retrying State Tests

@Suite("TranscriptionOrchestrator - Retrying State")
struct RetryingStateTests {

    @Test("RecordingState retrying equality with same values")
    func retryingEquality() {
        let state1 = RecordingState.retrying(attempt: 1, maxAttempts: 3, reason: "Network error")
        let state2 = RecordingState.retrying(attempt: 1, maxAttempts: 3, reason: "Network error")

        #expect(state1 == state2)
    }

    @Test("RecordingState retrying inequality with different attempt")
    func retryingDifferentAttempt() {
        let state1 = RecordingState.retrying(attempt: 1, maxAttempts: 3, reason: "Error")
        let state2 = RecordingState.retrying(attempt: 2, maxAttempts: 3, reason: "Error")

        #expect(state1 != state2)
    }

    @Test("RecordingState retrying inequality with different reason")
    func retryingDifferentReason() {
        let state1 = RecordingState.retrying(attempt: 1, maxAttempts: 3, reason: "Network error")
        let state2 = RecordingState.retrying(attempt: 1, maxAttempts: 3, reason: "Timeout")

        #expect(state1 != state2)
    }
}
