//
//  ProviderFactoryTests.swift
//  SwiftSpeakTests
//
//  Unit tests for ProviderFactory
//

import Testing
@testable import SwiftSpeak

// MARK: - Transcription Provider Creation Tests

@Suite("ProviderFactory - Transcription Providers")
struct ProviderFactoryTranscriptionTests {

    @Test("Creates OpenAI transcription provider")
    @MainActor
    func createsOpenAITranscriptionProvider() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        // Configure OpenAI provider
        let config = AIProviderConfig(
            provider: .openAI,
            apiKey: "test-key",
            usageCategories: [.transcription],
            transcriptionModel: "whisper-1"
        )
        settings.configuredAIProviders = [config]

        let factory = ProviderFactory(settings: settings)
        let provider = factory.createTranscriptionProvider(for: .openAI)

        #expect(provider != nil)
        #expect(provider?.providerId == .openAI)
        #expect(provider?.model == "whisper-1")

        // Restore
        settings.configuredAIProviders = originalProviders
    }

    @Test("Creates AssemblyAI transcription provider")
    @MainActor
    func createsAssemblyAITranscriptionProvider() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        let config = AIProviderConfig(
            provider: .assemblyAI,
            apiKey: "test-key",
            usageCategories: [.transcription],
            transcriptionModel: "default"
        )
        settings.configuredAIProviders = [config]

        let factory = ProviderFactory(settings: settings)
        let provider = factory.createTranscriptionProvider(for: .assemblyAI)

        #expect(provider != nil)
        #expect(provider?.providerId == .assemblyAI)

        settings.configuredAIProviders = originalProviders
    }

    @Test("Creates Deepgram transcription provider")
    @MainActor
    func createsDeepgramTranscriptionProvider() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        let config = AIProviderConfig(
            provider: .deepgram,
            apiKey: "test-key",
            usageCategories: [.transcription],
            transcriptionModel: "nova-2"
        )
        settings.configuredAIProviders = [config]

        let factory = ProviderFactory(settings: settings)
        let provider = factory.createTranscriptionProvider(for: .deepgram)

        #expect(provider != nil)
        #expect(provider?.providerId == .deepgram)
        #expect(provider?.model == "nova-2")

        settings.configuredAIProviders = originalProviders
    }

    @Test("Creates Google STT provider with project ID")
    @MainActor
    func createsGoogleSTTProvider() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        let config = AIProviderConfig(
            provider: .google,
            apiKey: "test-key",
            usageCategories: [.transcription],
            transcriptionModel: "long",
            googleProjectId: "test-project"
        )
        settings.configuredAIProviders = [config]

        let factory = ProviderFactory(settings: settings)
        let provider = factory.createTranscriptionProvider(for: .google)

        #expect(provider != nil)
        #expect(provider?.providerId == .google)
        #expect(provider?.model == "long")

        settings.configuredAIProviders = originalProviders
    }

    @Test("Returns nil for Google STT without project ID")
    @MainActor
    func returnsNilForGoogleSTTWithoutProjectId() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        let config = AIProviderConfig(
            provider: .google,
            apiKey: "test-key",
            usageCategories: [.transcription],
            googleProjectId: nil  // Missing project ID
        )
        settings.configuredAIProviders = [config]

        let factory = ProviderFactory(settings: settings)
        let provider = factory.createTranscriptionProvider(for: .google)

        #expect(provider == nil)

        settings.configuredAIProviders = originalProviders
    }

    @Test("Returns nil for provider that doesn't support transcription")
    @MainActor
    func returnsNilForNonTranscriptionProvider() {
        let settings = SharedSettings.shared
        let factory = ProviderFactory(settings: settings)

        // DeepL doesn't support transcription
        let provider = factory.createTranscriptionProvider(for: .deepL)
        #expect(provider == nil)
    }

    @Test("Returns nil for unconfigured provider")
    @MainActor
    func returnsNilForUnconfiguredTranscriptionProvider() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        // Clear all providers
        settings.configuredAIProviders = []

        let factory = ProviderFactory(settings: settings)
        let provider = factory.createTranscriptionProvider(for: .openAI)

        #expect(provider == nil)

        settings.configuredAIProviders = originalProviders
    }
}

// MARK: - Translation Provider Creation Tests

@Suite("ProviderFactory - Translation Providers")
struct ProviderFactoryTranslationTests {

    @Test("Creates OpenAI translation provider")
    @MainActor
    func createsOpenAITranslationProvider() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        let config = AIProviderConfig(
            provider: .openAI,
            apiKey: "test-key",
            usageCategories: [.translation],
            translationModel: "gpt-4o-mini"
        )
        settings.configuredAIProviders = [config]

        let factory = ProviderFactory(settings: settings)
        let provider = factory.createTranslationProvider(for: .openAI)

        #expect(provider != nil)
        #expect(provider?.providerId == .openAI)

        settings.configuredAIProviders = originalProviders
    }

    @Test("Creates DeepL translation provider")
    @MainActor
    func createsDeepLTranslationProvider() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        let config = AIProviderConfig(
            provider: .deepL,
            apiKey: "test-key",
            usageCategories: [.translation]
        )
        settings.configuredAIProviders = [config]

        let factory = ProviderFactory(settings: settings)
        let provider = factory.createTranslationProvider(for: .deepL)

        #expect(provider != nil)
        #expect(provider?.providerId == .deepL)

        settings.configuredAIProviders = originalProviders
    }

    @Test("Creates Google translation provider")
    @MainActor
    func createsGoogleTranslationProvider() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        let config = AIProviderConfig(
            provider: .google,
            apiKey: "test-key",
            usageCategories: [.translation]
        )
        settings.configuredAIProviders = [config]

        let factory = ProviderFactory(settings: settings)
        let provider = factory.createTranslationProvider(for: .google)

        #expect(provider != nil)
        #expect(provider?.providerId == .google)

        settings.configuredAIProviders = originalProviders
    }

    @Test("Creates Azure translation provider with region")
    @MainActor
    func createsAzureTranslationProvider() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        let config = AIProviderConfig(
            provider: .azure,
            apiKey: "test-key",
            usageCategories: [.translation],
            azureRegion: "eastus"
        )
        settings.configuredAIProviders = [config]

        let factory = ProviderFactory(settings: settings)
        let provider = factory.createTranslationProvider(for: .azure)

        #expect(provider != nil)
        #expect(provider?.providerId == .azure)

        settings.configuredAIProviders = originalProviders
    }

    @Test("Returns nil for Azure without region")
    @MainActor
    func returnsNilForAzureWithoutRegion() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        let config = AIProviderConfig(
            provider: .azure,
            apiKey: "test-key",
            usageCategories: [.translation],
            azureRegion: nil  // Missing region
        )
        settings.configuredAIProviders = [config]

        let factory = ProviderFactory(settings: settings)
        let provider = factory.createTranslationProvider(for: .azure)

        #expect(provider == nil)

        settings.configuredAIProviders = originalProviders
    }

    @Test("Creates Anthropic translation adapter")
    @MainActor
    func createsAnthropicTranslationAdapter() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        let config = AIProviderConfig(
            provider: .anthropic,
            apiKey: "test-key",
            usageCategories: [.translation],
            translationModel: "claude-3-5-sonnet-latest"
        )
        settings.configuredAIProviders = [config]

        let factory = ProviderFactory(settings: settings)
        let provider = factory.createTranslationProvider(for: .anthropic)

        #expect(provider != nil)
        #expect(provider?.providerId == .anthropic)

        settings.configuredAIProviders = originalProviders
    }

    @Test("Returns nil for provider that doesn't support translation")
    @MainActor
    func returnsNilForNonTranslationProvider() {
        let settings = SharedSettings.shared
        let factory = ProviderFactory(settings: settings)

        // Deepgram doesn't support translation
        let provider = factory.createTranslationProvider(for: .deepgram)
        #expect(provider == nil)
    }
}

// MARK: - Formatting Provider Creation Tests

@Suite("ProviderFactory - Formatting Providers")
struct ProviderFactoryFormattingTests {

    @Test("Creates OpenAI formatting provider")
    @MainActor
    func createsOpenAIFormattingProvider() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        let config = AIProviderConfig(
            provider: .openAI,
            apiKey: "test-key",
            usageCategories: [.powerMode],
            powerModeModel: "gpt-4o"
        )
        settings.configuredAIProviders = [config]

        let factory = ProviderFactory(settings: settings)
        let provider = factory.createFormattingProvider(for: .openAI)

        #expect(provider != nil)
        #expect(provider?.providerId == .openAI)

        settings.configuredAIProviders = originalProviders
    }

    @Test("Creates Anthropic formatting provider")
    @MainActor
    func createsAnthropicFormattingProvider() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        let config = AIProviderConfig(
            provider: .anthropic,
            apiKey: "test-key",
            usageCategories: [.powerMode],
            powerModeModel: "claude-3-5-sonnet-latest"
        )
        settings.configuredAIProviders = [config]

        let factory = ProviderFactory(settings: settings)
        let provider = factory.createFormattingProvider(for: .anthropic)

        #expect(provider != nil)
        #expect(provider?.providerId == .anthropic)
        #expect(provider?.model == "claude-3-5-sonnet-latest")

        settings.configuredAIProviders = originalProviders
    }

    @Test("Creates Gemini formatting provider")
    @MainActor
    func createsGeminiFormattingProvider() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        let config = AIProviderConfig(
            provider: .google,
            apiKey: "test-key",
            usageCategories: [.powerMode],
            powerModeModel: "gemini-2.0-flash-exp"
        )
        settings.configuredAIProviders = [config]

        let factory = ProviderFactory(settings: settings)
        let provider = factory.createFormattingProvider(for: .google)

        #expect(provider != nil)
        #expect(provider?.providerId == .google)
        #expect(provider?.model == "gemini-2.0-flash-exp")

        settings.configuredAIProviders = originalProviders
    }

    @Test("Returns nil for provider that doesn't support power mode")
    @MainActor
    func returnsNilForNonPowerModeProvider() {
        let settings = SharedSettings.shared
        let factory = ProviderFactory(settings: settings)

        // DeepL doesn't support power mode
        let provider = factory.createFormattingProvider(for: .deepL)
        #expect(provider == nil)
    }
}

// MARK: - Provider Validation Tests

@Suite("ProviderFactory - Validation")
struct ProviderFactoryValidationTests {

    @Test("Validates configured providers for transcription")
    @MainActor
    func validatesConfiguredProvidersForTranscription() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        // Configure OpenAI with valid API key
        let config = AIProviderConfig(
            provider: .openAI,
            apiKey: "test-key",
            usageCategories: [.transcription]
        )
        settings.configuredAIProviders = [config]

        let factory = ProviderFactory(settings: settings)
        let isConfigured = factory.isProviderConfigured(.openAI, for: .transcription)

        #expect(isConfigured == true)

        settings.configuredAIProviders = originalProviders
    }

    @Test("Fails validation for missing API key")
    @MainActor
    func failsValidationForMissingAPIKey() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        // Configure OpenAI WITHOUT API key
        let config = AIProviderConfig(
            provider: .openAI,
            apiKey: "",
            usageCategories: [.transcription]
        )
        settings.configuredAIProviders = [config]

        let factory = ProviderFactory(settings: settings)
        let isConfigured = factory.isProviderConfigured(.openAI, for: .transcription)

        #expect(isConfigured == false)

        settings.configuredAIProviders = originalProviders
    }

    @Test("Fails validation for Google STT without project ID")
    @MainActor
    func failsValidationForGoogleSTTWithoutProjectId() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        let config = AIProviderConfig(
            provider: .google,
            apiKey: "test-key",
            usageCategories: [.transcription],
            googleProjectId: nil
        )
        settings.configuredAIProviders = [config]

        let factory = ProviderFactory(settings: settings)
        let isConfigured = factory.isProviderConfigured(.google, for: .transcription)

        #expect(isConfigured == false)

        settings.configuredAIProviders = originalProviders
    }

    @Test("Fails validation for Azure without region")
    @MainActor
    func failsValidationForAzureWithoutRegion() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        let config = AIProviderConfig(
            provider: .azure,
            apiKey: "test-key",
            usageCategories: [.translation],
            azureRegion: nil
        )
        settings.configuredAIProviders = [config]

        let factory = ProviderFactory(settings: settings)
        let isConfigured = factory.isProviderConfigured(.azure, for: .translation)

        #expect(isConfigured == false)

        settings.configuredAIProviders = originalProviders
    }

    @Test("Gets configured providers for capability")
    @MainActor
    func getsConfiguredProvidersForCapability() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        // Configure multiple providers
        let openAIConfig = AIProviderConfig(
            provider: .openAI,
            apiKey: "test-key",
            usageCategories: [.transcription, .translation, .powerMode]
        )
        let deepLConfig = AIProviderConfig(
            provider: .deepL,
            apiKey: "test-key",
            usageCategories: [.translation]
        )
        settings.configuredAIProviders = [openAIConfig, deepLConfig]

        let factory = ProviderFactory(settings: settings)

        // Check transcription - only OpenAI supports it
        let transcriptionProviders = factory.configuredProviders(for: .transcription)
        #expect(transcriptionProviders.contains(.openAI))
        #expect(!transcriptionProviders.contains(.deepL))

        // Check translation - both support it
        let translationProviders = factory.configuredProviders(for: .translation)
        #expect(translationProviders.contains(.openAI))
        #expect(translationProviders.contains(.deepL))

        settings.configuredAIProviders = originalProviders
    }
}

// MARK: - Selected Provider Tests

@Suite("ProviderFactory - Selected Providers")
struct ProviderFactorySelectedTests {

    @Test("Creates selected transcription provider")
    @MainActor
    func createsSelectedTranscriptionProvider() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders
        let originalSelected = settings.selectedTranscriptionProvider

        let config = AIProviderConfig(
            provider: .openAI,
            apiKey: "test-key",
            usageCategories: [.transcription],
            transcriptionModel: "whisper-1"
        )
        settings.configuredAIProviders = [config]
        settings.selectedTranscriptionProvider = .openAI

        let factory = ProviderFactory(settings: settings)
        let provider = factory.createSelectedTranscriptionProvider()

        #expect(provider != nil)
        #expect(provider?.providerId == .openAI)

        settings.configuredAIProviders = originalProviders
        settings.selectedTranscriptionProvider = originalSelected
    }

    @Test("Creates selected translation provider")
    @MainActor
    func createsSelectedTranslationProvider() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders
        let originalSelected = settings.selectedTranslationProvider

        let config = AIProviderConfig(
            provider: .deepL,
            apiKey: "test-key",
            usageCategories: [.translation]
        )
        settings.configuredAIProviders = [config]
        settings.selectedTranslationProvider = .deepL

        let factory = ProviderFactory(settings: settings)
        let provider = factory.createSelectedTranslationProvider()

        #expect(provider != nil)
        #expect(provider?.providerId == .deepL)

        settings.configuredAIProviders = originalProviders
        settings.selectedTranslationProvider = originalSelected
    }

    @Test("Creates selected formatting provider")
    @MainActor
    func createsSelectedFormattingProvider() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders
        let originalSelected = settings.selectedPowerModeProvider

        let config = AIProviderConfig(
            provider: .anthropic,
            apiKey: "test-key",
            usageCategories: [.powerMode],
            powerModeModel: "claude-3-5-sonnet-latest"
        )
        settings.configuredAIProviders = [config]
        settings.selectedPowerModeProvider = .anthropic

        let factory = ProviderFactory(settings: settings)
        let provider = factory.createSelectedFormattingProvider()

        #expect(provider != nil)
        #expect(provider?.providerId == .anthropic)

        settings.configuredAIProviders = originalProviders
        settings.selectedPowerModeProvider = originalSelected
    }
}
