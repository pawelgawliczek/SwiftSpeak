//
//  ProviderSwitchingTests.swift
//  SwiftSpeakTests
//
//  Tests for switching between AI providers at runtime
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

// MARK: - Provider Switching Tests

@Suite("Provider Switching Tests")
@MainActor
struct ProviderSwitchingTests {

    // MARK: - Transcription Provider Switching

    @Test("Can switch transcription provider")
    func canSwitchTranscriptionProvider() {
        let settings = SharedSettings.shared
        let originalProvider = settings.selectedTranscriptionProvider

        settings.selectedTranscriptionProvider = .openAI
        #expect(settings.selectedTranscriptionProvider == .openAI)

        settings.selectedTranscriptionProvider = .deepgram
        #expect(settings.selectedTranscriptionProvider == .deepgram)

        settings.selectedTranscriptionProvider = originalProvider
    }

    @Test("Switched transcription provider creates correct service")
    func switchedTranscriptionProviderCreatesCorrectService() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders
        let originalSelected = settings.selectedTranscriptionProvider

        // Configure multiple transcription providers
        let openAIConfig = AIProviderConfig(
            provider: .openAI,
            apiKey: "test-key-openai",
            usageCategories: [.transcription],
            transcriptionModel: "whisper-1"
        )
        let deepgramConfig = AIProviderConfig(
            provider: .deepgram,
            apiKey: "test-key-deepgram",
            usageCategories: [.transcription],
            transcriptionModel: "nova-2"
        )
        settings.configuredAIProviders = [openAIConfig, deepgramConfig]

        let factory = ProviderFactory(settings: settings)

        // Switch to OpenAI
        settings.selectedTranscriptionProvider = .openAI
        var provider = factory.createSelectedTranscriptionProvider()
        #expect(provider?.providerId == .openAI)

        // Switch to Deepgram
        settings.selectedTranscriptionProvider = .deepgram
        provider = factory.createSelectedTranscriptionProvider()
        #expect(provider?.providerId == .deepgram)

        settings.configuredAIProviders = originalProviders
        settings.selectedTranscriptionProvider = originalSelected
    }

    // MARK: - Translation Provider Switching

    @Test("Can switch translation provider")
    func canSwitchTranslationProvider() {
        let settings = SharedSettings.shared
        let originalProvider = settings.selectedTranslationProvider

        settings.selectedTranslationProvider = .openAI
        #expect(settings.selectedTranslationProvider == .openAI)

        settings.selectedTranslationProvider = .deepL
        #expect(settings.selectedTranslationProvider == .deepL)

        settings.selectedTranslationProvider = originalProvider
    }

    @Test("Switched translation provider creates correct service")
    func switchedTranslationProviderCreatesCorrectService() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders
        let originalSelected = settings.selectedTranslationProvider

        // Configure multiple translation providers
        let openAIConfig = AIProviderConfig(
            provider: .openAI,
            apiKey: "test-key-openai",
            usageCategories: [.translation],
            translationModel: "gpt-4o-mini"
        )
        let deepLConfig = AIProviderConfig(
            provider: .deepL,
            apiKey: "test-key-deepl",
            usageCategories: [.translation]
        )
        settings.configuredAIProviders = [openAIConfig, deepLConfig]

        let factory = ProviderFactory(settings: settings)

        // Switch to OpenAI
        settings.selectedTranslationProvider = .openAI
        var provider = factory.createSelectedTranslationProvider()
        #expect(provider?.providerId == .openAI)

        // Switch to DeepL
        settings.selectedTranslationProvider = .deepL
        provider = factory.createSelectedTranslationProvider()
        #expect(provider?.providerId == .deepL)

        settings.configuredAIProviders = originalProviders
        settings.selectedTranslationProvider = originalSelected
    }

    // MARK: - Power Mode Provider Switching

    @Test("Can switch power mode provider")
    func canSwitchPowerModeProvider() {
        let settings = SharedSettings.shared
        let originalProvider = settings.selectedPowerModeProvider

        settings.selectedPowerModeProvider = .openAI
        #expect(settings.selectedPowerModeProvider == .openAI)

        settings.selectedPowerModeProvider = .anthropic
        #expect(settings.selectedPowerModeProvider == .anthropic)

        settings.selectedPowerModeProvider = originalProvider
    }

    @Test("Switched power mode provider creates correct service")
    func switchedPowerModeProviderCreatesCorrectService() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders
        let originalSelected = settings.selectedPowerModeProvider

        // Configure multiple power mode providers
        let openAIConfig = AIProviderConfig(
            provider: .openAI,
            apiKey: "test-key-openai",
            usageCategories: [.powerMode],
            powerModeModel: "gpt-4o"
        )
        let anthropicConfig = AIProviderConfig(
            provider: .anthropic,
            apiKey: "test-key-anthropic",
            usageCategories: [.powerMode],
            powerModeModel: "claude-3-5-sonnet-latest"
        )
        settings.configuredAIProviders = [openAIConfig, anthropicConfig]

        let factory = ProviderFactory(settings: settings)

        // Switch to OpenAI
        settings.selectedPowerModeProvider = .openAI
        var provider = factory.createSelectedFormattingProvider()
        #expect(provider?.providerId == .openAI)

        // Switch to Anthropic
        settings.selectedPowerModeProvider = .anthropic
        provider = factory.createSelectedFormattingProvider()
        #expect(provider?.providerId == .anthropic)

        settings.configuredAIProviders = originalProviders
        settings.selectedPowerModeProvider = originalSelected
    }

    // MARK: - Provider Persistence Tests

    @Test("Provider selection persists across factory instances")
    func providerSelectionPersists() {
        let settings = SharedSettings.shared
        let originalProvider = settings.selectedTranscriptionProvider
        let originalProviders = settings.configuredAIProviders

        let config = AIProviderConfig(
            provider: .deepgram,
            apiKey: "test-key",
            usageCategories: [.transcription],
            transcriptionModel: "nova-2"
        )
        settings.configuredAIProviders = [config]
        settings.selectedTranscriptionProvider = .deepgram

        // Create new factory instance
        let factory1 = ProviderFactory(settings: settings)
        let provider1 = factory1.createSelectedTranscriptionProvider()

        // Create another factory instance
        let factory2 = ProviderFactory(settings: settings)
        let provider2 = factory2.createSelectedTranscriptionProvider()

        // Both should return same provider type
        #expect(provider1?.providerId == provider2?.providerId)

        settings.selectedTranscriptionProvider = originalProvider
        settings.configuredAIProviders = originalProviders
    }

    // MARK: - Invalid Provider Switching Tests

    @Test("Switching to unconfigured provider returns nil")
    func switchingToUnconfiguredProviderReturnsNil() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders
        let originalSelected = settings.selectedTranscriptionProvider

        // Only configure OpenAI
        let openAIConfig = AIProviderConfig(
            provider: .openAI,
            apiKey: "test-key",
            usageCategories: [.transcription]
        )
        settings.configuredAIProviders = [openAIConfig]

        // Try to select Deepgram (not configured)
        settings.selectedTranscriptionProvider = .deepgram

        let factory = ProviderFactory(settings: settings)
        let provider = factory.createSelectedTranscriptionProvider()

        #expect(provider == nil)

        settings.configuredAIProviders = originalProviders
        settings.selectedTranscriptionProvider = originalSelected
    }

    // MARK: - Multi-Capability Provider Switching

    @Test("Provider with multiple capabilities can be used for each")
    func providerWithMultipleCapabilities() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        // Configure OpenAI for all capabilities
        let openAIConfig = AIProviderConfig(
            provider: .openAI,
            apiKey: "test-key",
            usageCategories: [.transcription, .translation, .powerMode],
            transcriptionModel: "whisper-1",
            translationModel: "gpt-4o-mini",
            powerModeModel: "gpt-4o"
        )
        settings.configuredAIProviders = [openAIConfig]

        let factory = ProviderFactory(settings: settings)

        let transcriptionProvider = factory.createTranscriptionProvider(for: .openAI)
        let translationProvider = factory.createTranslationProvider(for: .openAI)
        let formattingProvider = factory.createFormattingProvider(for: .openAI)

        #expect(transcriptionProvider != nil)
        #expect(translationProvider != nil)
        #expect(formattingProvider != nil)

        // All should be OpenAI
        #expect(transcriptionProvider?.providerId == .openAI)
        #expect(translationProvider?.providerId == .openAI)
        #expect(formattingProvider?.providerId == .openAI)

        settings.configuredAIProviders = originalProviders
    }
}

// MARK: - Model Switching Tests

@Suite("Model Switching Tests")
@MainActor
struct ModelSwitchingTests {

    @Test("Can switch transcription model")
    func canSwitchTranscriptionModel() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        var config = AIProviderConfig(
            provider: .openAI,
            apiKey: "test-key",
            usageCategories: [.transcription],
            transcriptionModel: "whisper-1"
        )
        settings.configuredAIProviders = [config]

        let factory = ProviderFactory(settings: settings)
        var provider = factory.createTranscriptionProvider(for: .openAI)
        #expect(provider?.model == "whisper-1")

        // Update model
        config = AIProviderConfig(
            provider: .openAI,
            apiKey: "test-key",
            usageCategories: [.transcription],
            transcriptionModel: "whisper-large-v3"
        )
        settings.configuredAIProviders = [config]

        let newFactory = ProviderFactory(settings: settings)
        provider = newFactory.createTranscriptionProvider(for: .openAI)
        #expect(provider?.model == "whisper-large-v3")

        settings.configuredAIProviders = originalProviders
    }

    @Test("Can switch power mode model")
    func canSwitchPowerModeModel() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        var config = AIProviderConfig(
            provider: .anthropic,
            apiKey: "test-key",
            usageCategories: [.powerMode],
            powerModeModel: "claude-3-5-sonnet-latest"
        )
        settings.configuredAIProviders = [config]

        let factory = ProviderFactory(settings: settings)
        var provider = factory.createFormattingProvider(for: .anthropic)
        #expect(provider?.model == "claude-3-5-sonnet-latest")

        // Update model to Opus
        config = AIProviderConfig(
            provider: .anthropic,
            apiKey: "test-key",
            usageCategories: [.powerMode],
            powerModeModel: "claude-opus-4-20250514"
        )
        settings.configuredAIProviders = [config]

        let newFactory = ProviderFactory(settings: settings)
        provider = newFactory.createFormattingProvider(for: .anthropic)
        #expect(provider?.model == "claude-opus-4-20250514")

        settings.configuredAIProviders = originalProviders
    }
}

// MARK: - Cloud to Local Switching Tests

@Suite("Cloud to Local Provider Switching Tests")
@MainActor
struct CloudToLocalSwitchingTests {

    @Test("Can switch from cloud to local transcription")
    func canSwitchFromCloudToLocalTranscription() {
        let settings = SharedSettings.shared
        let originalProvider = settings.selectedTranscriptionProvider

        // Switch between cloud and local
        settings.selectedTranscriptionProvider = .openAI
        #expect(!settings.selectedTranscriptionProvider.isLocalProvider)

        settings.selectedTranscriptionProvider = .local
        #expect(settings.selectedTranscriptionProvider.isLocalProvider)

        settings.selectedTranscriptionProvider = originalProvider
    }

    @Test("Local provider is detected correctly")
    func localProviderIsDetectedCorrectly() {
        #expect(AIProvider.local.isLocalProvider == true)
        #expect(AIProvider.openAI.isLocalProvider == false)
        #expect(AIProvider.anthropic.isLocalProvider == false)
    }

    @Test("Cloud provider is not local")
    func cloudProviderIsNotLocal() {
        #expect(AIProvider.openAI.isLocalProvider == false)
        #expect(AIProvider.anthropic.isLocalProvider == false)
        #expect(AIProvider.local.isLocalProvider == true)
    }
}
