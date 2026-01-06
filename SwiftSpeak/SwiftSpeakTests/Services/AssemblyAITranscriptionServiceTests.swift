//
//  AssemblyAITranscriptionServiceTests.swift
//  SwiftSpeakTests
//
//  Tests for AssemblyAITranscriptionService
//

import Testing
import Foundation
@testable import SwiftSpeak

@MainActor
struct AssemblyAITranscriptionServiceTests {

    // MARK: - Initialization

    @Test func serviceInitializesWithApiKey() {
        let service = AssemblyAITranscriptionService(apiKey: "test-key", model: "best")

        #expect(service.providerId == .assemblyAI)
        #expect(service.isConfigured == true)
        #expect(service.model == "best")
    }

    @Test func serviceNotConfiguredWithEmptyKey() {
        let service = AssemblyAITranscriptionService(apiKey: "", model: "best")

        #expect(service.isConfigured == false)
    }

    @Test func serviceDefaultsToBestModel() {
        let service = AssemblyAITranscriptionService(apiKey: "test-key")

        #expect(service.model == "best")
    }

    @Test func serviceSupportsNanoModel() {
        let service = AssemblyAITranscriptionService(apiKey: "test-key", model: "nano")

        #expect(service.model == "nano")
    }

    // MARK: - Provider Config Initialization

    @Test func serviceInitializesFromProviderConfig() {
        let config = SwiftSpeak.AIProviderConfig(
            provider: .assemblyAI,
            apiKey: "test-api-key",
            usageCategories: [.transcription],
            transcriptionModel: "nano"
        )

        let service = AssemblyAITranscriptionService(config: config)

        #expect(service != nil)
        #expect(service?.isConfigured == true)
        #expect(service?.model == "nano")
    }

    @Test func serviceReturnsNilForNonAssemblyAIConfig() {
        let config = SwiftSpeak.AIProviderConfig(
            provider: .openAI,
            apiKey: "test-api-key",
            usageCategories: [.transcription]
        )

        let service = AssemblyAITranscriptionService(config: config)

        #expect(service == nil)
    }

    @Test func serviceReturnsNilForEmptyApiKey() {
        let config = SwiftSpeak.AIProviderConfig(
            provider: .assemblyAI,
            apiKey: "",
            usageCategories: [.transcription]
        )

        let service = AssemblyAITranscriptionService(config: config)

        #expect(service == nil)
    }

    // MARK: - TranscriptionProvider Protocol

    @Test func serviceConformsToTranscriptionProvider() {
        let service = AssemblyAITranscriptionService(apiKey: "test-key")

        // Verify protocol properties
        #expect(service.providerId == .assemblyAI)
        #expect(type(of: service.isConfigured) == Bool.self)
        #expect(type(of: service.model) == String.self)
    }

    // MARK: - Language Support

    @Test func languageHasAssemblyAICode() {
        // Supported languages
        #expect(SwiftSpeak.Language.english.assemblyAICode == "en")
        #expect(SwiftSpeak.Language.spanish.assemblyAICode == "es")
        #expect(SwiftSpeak.Language.french.assemblyAICode == "fr")
        #expect(SwiftSpeak.Language.german.assemblyAICode == "de")
        #expect(SwiftSpeak.Language.italian.assemblyAICode == "it")
        #expect(SwiftSpeak.Language.portuguese.assemblyAICode == "pt")
        #expect(SwiftSpeak.Language.chinese.assemblyAICode == "zh")
        #expect(SwiftSpeak.Language.japanese.assemblyAICode == "ja")
        #expect(SwiftSpeak.Language.korean.assemblyAICode == "ko")
        #expect(SwiftSpeak.Language.russian.assemblyAICode == "ru")
        #expect(SwiftSpeak.Language.polish.assemblyAICode == "pl")
    }

    @Test func unsupportedLanguagesReturnNil() {
        // AssemblyAI doesn't support Arabic
        #expect(SwiftSpeak.Language.arabic.assemblyAICode == nil)
        #expect(SwiftSpeak.Language.egyptianArabic.assemblyAICode == nil)
    }

    // MARK: - Error Handling Tests

    @Test func serviceThrowsErrorForMissingApiKey() async throws {
        let service = AssemblyAITranscriptionService(apiKey: "")

        // Create temporary test file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        // Create minimal audio file
        let testData = Data([0x00, 0x01, 0x02, 0x03])
        try testData.write(to: tempURL)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        do {
            _ = try await service.transcribe(audioURL: tempURL, language: nil)
            Issue.record("Expected apiKeyMissing error")
        } catch let error as TranscriptionError {
            #expect(error == .apiKeyMissing)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func serviceThrowsErrorForMissingFile() async throws {
        let service = AssemblyAITranscriptionService(apiKey: "test-key")

        // Non-existent file
        let nonExistentURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("non-existent.m4a")

        do {
            _ = try await service.transcribe(audioURL: nonExistentURL, language: nil)
            Issue.record("Expected audioFileNotFound error")
        } catch let error as TranscriptionError {
            #expect(error == .audioFileNotFound)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}

// MARK: - AssemblyAI Model Tests

@MainActor
struct AssemblyAIModelTests {

    @Test func providerSupportsBestModel() {
        let models = SwiftSpeak.AIProvider.assemblyAI.availableSTTModels

        #expect(models.contains("best"))
    }

    @Test func providerSupportsNanoModel() {
        let models = SwiftSpeak.AIProvider.assemblyAI.availableSTTModels

        #expect(models.contains("nano"))
    }

    @Test func providerDefaultModelIsBest() {
        let defaultModel = SwiftSpeak.AIProvider.assemblyAI.defaultSTTModel

        #expect(defaultModel == "best")
    }

    @Test func providerSupportsTranscription() {
        #expect(SwiftSpeak.AIProvider.assemblyAI.supportsTranscription == true)
    }

    @Test func providerDoesNotSupportTranslation() {
        #expect(SwiftSpeak.AIProvider.assemblyAI.supportsTranslation == false)
    }

    @Test func providerDoesNotSupportPowerMode() {
        #expect(SwiftSpeak.AIProvider.assemblyAI.supportsPowerMode == false)
    }

    @Test func providerRequiresApiKey() {
        #expect(SwiftSpeak.AIProvider.assemblyAI.requiresAPIKey == true)
    }

    @Test func providerIsNotLocalProvider() {
        #expect(SwiftSpeak.AIProvider.assemblyAI.isLocalProvider == false)
    }
}

// MARK: - AssemblyAI Provider Info Tests

@MainActor
struct AssemblyAIProviderInfoTests {

    @Test func providerHasDisplayName() {
        #expect(SwiftSpeak.AIProvider.assemblyAI.displayName == "AssemblyAI")
    }

    @Test func providerHasShortName() {
        #expect(SwiftSpeak.AIProvider.assemblyAI.shortName == "AssemblyAI")
    }

    @Test func providerHasIcon() {
        #expect(SwiftSpeak.AIProvider.assemblyAI.icon == "waveform.circle.fill")
    }

    @Test func providerHasDescription() {
        let description = SwiftSpeak.AIProvider.assemblyAI.description

        #expect(!description.isEmpty)
        #expect(description.lowercased().contains("transcription"))
    }

    @Test func providerHasApiKeyHelpURL() {
        let helpURL = SwiftSpeak.AIProvider.assemblyAI.apiKeyHelpURL

        #expect(helpURL != nil)
        #expect(helpURL?.absoluteString.contains("assemblyai.com") == true)
    }

    @Test func providerHasSetupInstructions() {
        let instructions = SwiftSpeak.AIProvider.assemblyAI.setupInstructions

        #expect(!instructions.isEmpty)
        #expect(instructions.lowercased().contains("api key"))
    }

    @Test func providerHasCostPerMinute() {
        let cost = SwiftSpeak.AIProvider.assemblyAI.costPerMinute

        // AssemblyAI is $0.00025/second = $0.015/minute
        #expect(cost == 0.00025)
    }

    @Test func providerDoesNotRequirePowerTier() {
        #expect(SwiftSpeak.AIProvider.assemblyAI.requiresPowerTier == false)
    }

    @Test func providerMinimumTierIsFree() {
        #expect(SwiftSpeak.AIProvider.assemblyAI.minimumTier == .free)
    }
}

// MARK: - Constants Tests

@MainActor
struct AssemblyAIConstantsTests {

    @Test func uploadEndpointIsDefined() {
        let endpoint = Constants.API.assemblyAIUpload

        #expect(endpoint == "https://api.assemblyai.com/v2/upload")
    }

    @Test func transcriptEndpointIsDefined() {
        let endpoint = Constants.API.assemblyAITranscript

        #expect(endpoint == "https://api.assemblyai.com/v2/transcript")
    }
}

// MARK: - Integration Scenarios

@MainActor
struct AssemblyAIIntegrationTests {

    @Test func configurationWorkflowCreatesValidService() {
        // Simulate user configuration flow
        let config = SwiftSpeak.AIProviderConfig(
            provider: .assemblyAI,
            apiKey: "test-assemblyai-api-key",
            usageCategories: [.transcription],
            transcriptionModel: "default"
        )

        // Verify config is valid
        #expect(config.provider == .assemblyAI)
        #expect(config.isConfiguredForTranscription == true)
        #expect(config.isConfiguredForTranslation == false)
        #expect(config.isConfiguredForPowerMode == false)

        // Create service from config
        let service = AssemblyAITranscriptionService(config: config)

        #expect(service != nil)
        #expect(service?.isConfigured == true)
        #expect(service?.providerId == .assemblyAI)
    }

    @Test func multiProviderConfigurationSupportsAssemblyAI() {
        // User can have multiple providers configured
        let openAIConfig = SwiftSpeak.AIProviderConfig(
            provider: .openAI,
            apiKey: "openai-key",
            usageCategories: [.transcription, .translation, .powerMode]
        )

        let assemblyAIConfig = SwiftSpeak.AIProviderConfig(
            provider: .assemblyAI,
            apiKey: "assemblyai-key",
            usageCategories: [.transcription]
        )

        // Both should be valid
        #expect(openAIConfig.isConfiguredForTranscription == true)
        #expect(assemblyAIConfig.isConfiguredForTranscription == true)

        // Create services
        let openAIService = OpenAITranscriptionService(config: openAIConfig)
        let assemblyAIService = AssemblyAITranscriptionService(config: assemblyAIConfig)

        #expect(openAIService != nil)
        #expect(assemblyAIService != nil)
    }

    @Test func languageCodeHandlingForUnsupportedLanguages() {
        // Arabic is not supported by AssemblyAI
        let arabic = SwiftSpeak.Language.arabic

        #expect(arabic.assemblyAICode == nil)

        // Service should handle this gracefully by omitting language parameter
        // This is verified in the actual transcription implementation
    }

    @Test func modelSelectionPersistsInConfig() {
        let nanoConfig = SwiftSpeak.AIProviderConfig(
            provider: .assemblyAI,
            apiKey: "test-key",
            transcriptionModel: "nano"
        )

        let service = AssemblyAITranscriptionService(config: nanoConfig)

        #expect(service?.model == "nano")

        // Verify config stores the model choice
        #expect(nanoConfig.transcriptionModel == "nano")
        #expect(nanoConfig.model(for: .transcription) == "nano")
    }
}
