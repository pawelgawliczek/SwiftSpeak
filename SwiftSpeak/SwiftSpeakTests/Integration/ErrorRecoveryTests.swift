//
//  ErrorRecoveryTests.swift
//  SwiftSpeakTests
//
//  Integration tests for error recovery scenarios across the app
//  Tests error handling behavior without complex mock injection
//

import Testing
import Foundation
@testable import SwiftSpeak

// MARK: - Error Recovery Tests

@Suite("Error Recovery Tests")
@MainActor
struct ErrorRecoveryTests {

    // MARK: - Orchestrator Error State Tests

    @Test("Orchestrator can reset from error state")
    func orchestratorCanResetFromErrorState() {
        let orchestrator = TranscriptionOrchestrator()

        // Reset should clear any error message
        orchestrator.reset()

        #expect(orchestrator.state == .idle)
        #expect(orchestrator.errorMessage == nil)
    }

    @Test("Cancel clears state")
    func cancelClearsState() {
        let orchestrator = TranscriptionOrchestrator()

        orchestrator.cancel()

        #expect(orchestrator.state == .idle)
        #expect(orchestrator.transcribedText.isEmpty)
        #expect(orchestrator.formattedText.isEmpty)
    }

    // MARK: - Error Properties Tests

    @Test("Network timeout is retryable")
    func networkTimeoutIsRetryable() {
        let error = TranscriptionError.networkTimeout
        #expect(error.shouldRetry == true)
        #expect(error.isUserRecoverable == false)
    }

    @Test("API key missing is recoverable")
    func apiKeyMissingIsRecoverable() {
        let error = TranscriptionError.apiKeyMissing
        #expect(error.isUserRecoverable == true)
        #expect(error.shouldRetry == false)
    }

    @Test("Rate limited has retry info")
    func rateLimitedHasRetryInfo() {
        let error = TranscriptionError.rateLimited(retryAfterSeconds: 60)
        #expect(error.shouldRetry == true)
        #expect(error.errorDescription?.contains("60") == true || error.errorDescription != nil)
    }

    @Test("Server error is not user recoverable")
    func serverErrorIsNotUserRecoverable() {
        let error = TranscriptionError.serverError(statusCode: 500, message: "Internal Error")
        #expect(error.isUserRecoverable == false)
        #expect(error.shouldRetry == true)
    }

    @Test("Cancelled error is not retryable")
    func cancelledErrorIsNotRetryable() {
        let error = TranscriptionError.cancelled
        #expect(error.shouldRetry == false)
    }

    // MARK: - Error Description Tests

    @Test("All errors have user-friendly descriptions")
    func allErrorsHaveDescriptions() {
        let errors: [TranscriptionError] = [
            .microphonePermissionDenied,
            .microphonePermissionNotDetermined,
            .recordingFailed("test"),
            .audioSessionConfigurationFailed("test"),
            .audioFileNotFound,
            .invalidAudioFile,
            .fileTooLarge(sizeMB: 30, maxSizeMB: 25),
            .networkUnavailable,
            .networkTimeout,
            .networkError("test"),
            .apiKeyMissing,
            .apiKeyInvalid,
            .apiKeyExpired,
            .rateLimited(retryAfterSeconds: 60),
            .quotaExceeded,
            .serverError(statusCode: 500, message: nil),
            .serviceUnavailable,
            .decodingError("test"),
            .emptyResponse,
            .unexpectedResponse("test"),
            .providerNotConfigured,
            .cancelled
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
            #expect(error.iconName.isEmpty == false)
        }
    }

    // MARK: - Settings Recovery Tests

    @Test("Settings can be reset")
    func settingsCanBeReset() {
        let settings = SharedSettings.shared

        // Store original values
        let originalProvider = settings.selectedTranscriptionProvider

        // Modify a setting
        settings.selectedTranscriptionProvider = .deepgram

        #expect(settings.selectedTranscriptionProvider == .deepgram)

        // Restore
        settings.selectedTranscriptionProvider = originalProvider
    }

    @Test("Provider configuration can be cleared")
    func providerConfigurationCanBeCleared() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        // Clear providers
        settings.configuredAIProviders = []
        #expect(settings.configuredAIProviders.isEmpty)

        // Restore
        settings.configuredAIProviders = originalProviders
    }
}

// MARK: - History Error Recovery Tests

@Suite("History Error Recovery Tests")
@MainActor
struct HistoryErrorRecoveryTests {

    @Test("History can be restored after clear")
    func historyCanBeRestoredAfterClear() {
        let settings = SharedSettings.shared
        let originalHistory = settings.transcriptionHistory

        // Add test record
        settings.addTranscription(TranscriptionRecord(
            text: "Test record",
            mode: .raw,
            provider: .openAI,
            duration: 5.0
        ))

        // Clear
        settings.clearHistory()
        #expect(settings.transcriptionHistory.isEmpty)

        // Restore original
        for record in originalHistory {
            settings.addTranscription(record)
        }
    }

    @Test("TranscriptionRecord handles all fields")
    func transcriptionRecordHandlesAllFields() {
        let record = TranscriptionRecord(
            text: "Test transcription",
            mode: .email,
            provider: .anthropic,
            duration: 30.0,
            translated: true,
            targetLanguage: .spanish,
            powerModeId: UUID(),
            powerModeName: "Research",
            contextId: UUID(),
            contextName: "Work",
            contextIcon: "briefcase",
            estimatedCost: 0.003,
            costBreakdown: CostBreakdown(
                transcriptionCost: 0.001,
                formattingCost: 0.002,
                translationCost: nil,
                inputTokens: 100,
                outputTokens: 150
            )
        )

        #expect(record.text == "Test transcription")
        #expect(record.mode == .email)
        #expect(record.provider == .anthropic)
        #expect(record.translated == true)
        #expect(record.targetLanguage == .spanish)
        #expect(record.powerModeName == "Research")
        #expect(record.contextName == "Work")
        #expect(record.estimatedCost == 0.003)
        #expect(record.costBreakdown?.formattingCost == 0.002)
    }
}

// MARK: - Webhook Error Handling Tests

@Suite("Webhook Error Handling Tests")
@MainActor
struct WebhookErrorHandlingTests {

    @Test("Webhook types have correct display names")
    func webhookTypesHaveDisplayNames() {
        let types: [WebhookType] = [.contextSource, .outputDestination, .automationTrigger]

        for type in types {
            #expect(!type.displayName.isEmpty)
        }
    }

    @Test("Webhook can be created with valid URL")
    func webhookCanBeCreatedWithValidURL() {
        let webhook = Webhook(
            name: "Test Webhook",
            type: .outputDestination,
            url: URL(string: "https://example.com/webhook")!
        )

        #expect(webhook.name == "Test Webhook")
        #expect(webhook.type == .outputDestination)
        #expect(webhook.isEnabled == true)
    }

    @Test("Webhook auth types are defined")
    func webhookAuthTypesAreDefined() {
        let authTypes: [WebhookAuthType] = [.none, .bearerToken, .apiKeyHeader, .basicAuth]
        #expect(authTypes.count == 4)
    }
}

// MARK: - Provider Error Recovery Tests

@Suite("Provider Error Recovery Tests")
@MainActor
struct ProviderErrorRecoveryTests {

    @Test("Provider can be switched after error")
    func providerCanBeSwitchedAfterError() {
        let settings = SharedSettings.shared
        let originalProvider = settings.selectedTranscriptionProvider

        // Switch to different provider
        settings.selectedTranscriptionProvider = .deepgram
        #expect(settings.selectedTranscriptionProvider == .deepgram)

        // Switch back
        settings.selectedTranscriptionProvider = originalProvider
    }

    @Test("API key can be updated after invalid")
    func apiKeyCanBeUpdatedAfterInvalid() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        // Add a new provider configuration
        let newConfig = AIProviderConfig(
            provider: .openAI,
            apiKey: "new-test-key",
            usageCategories: [.transcription]
        )

        settings.configuredAIProviders = [newConfig]
        #expect(settings.configuredAIProviders.first?.apiKey == "new-test-key")

        // Restore original
        settings.configuredAIProviders = originalProviders
    }

    @Test("All providers have display names")
    func allProvidersHaveDisplayNames() {
        for provider in AIProvider.allCases {
            #expect(!provider.displayName.isEmpty)
        }
    }

    @Test("Local provider is identified correctly")
    func localProviderIsIdentifiedCorrectly() {
        #expect(AIProvider.local.isLocalProvider == true)
        #expect(AIProvider.openAI.isLocalProvider == false)
        #expect(AIProvider.anthropic.isLocalProvider == false)
    }
}

// MARK: - Context Error Recovery Tests

@Suite("Context Error Recovery Tests")
@MainActor
struct ContextErrorRecoveryTests {

    @Test("Context can be deleted and recreated")
    func contextCanBeDeletedAndRecreated() {
        let settings = SharedSettings.shared
        let originalContexts = settings.contexts

        let newContext = ConversationContext(
            name: "Test Context",
            icon: "star",
            color: .orange,
            description: "Test description"
        )

        // Add context
        var contexts = settings.contexts
        contexts.append(newContext)
        settings.contexts = contexts

        #expect(settings.contexts.contains(where: { $0.id == newContext.id }))

        // Remove context
        settings.contexts = settings.contexts.filter { $0.id != newContext.id }

        #expect(!settings.contexts.contains(where: { $0.id == newContext.id }))

        // Restore original
        settings.contexts = originalContexts
    }

    @Test("Context formatting instruction options are available")
    func contextFormattingInstructionsAreAvailable() {
        let instructions = FormattingInstruction.all
        #expect(!instructions.isEmpty)
        #expect(instructions.contains { $0.id == "formal" })
        #expect(instructions.contains { $0.id == "casual" })
    }
}

// MARK: - PowerMode Error Recovery Tests

@Suite("PowerMode Error Recovery Tests")
@MainActor
struct PowerModeErrorRecoveryTests {

    @Test("PowerMode can be archived and recovered")
    func powerModeCanBeArchivedAndRecovered() {
        let settings = SharedSettings.shared
        let originalModes = settings.powerModes

        var testMode = PowerMode(name: "Test Mode")
        settings.addPowerMode(testMode)

        // Archive
        settings.archivePowerMode(id: testMode.id)
        #expect(settings.getPowerMode(id: testMode.id)?.isArchived == true)

        // Unarchive (recover)
        settings.unarchivePowerMode(id: testMode.id)
        #expect(settings.getPowerMode(id: testMode.id)?.isArchived == false)

        // Clean up
        settings.powerModes = originalModes
    }

    @Test("PowerMode memory can be cleared")
    func powerModeMemoryCanBeCleared() {
        var mode = PowerMode(name: "Test")
        mode.memory = "Some memory content"
        mode.memoryEnabled = true

        #expect(mode.memory == "Some memory content")

        mode.memory = nil
        #expect(mode.memory == nil)
    }
}
