//
//  ProviderFactory.swift
//  SwiftSpeak
//
//  Unified factory for creating provider instances
//

import Foundation

/// Central factory for creating provider instances based on configuration
/// Supports all Phase 3 providers for transcription, translation, and power mode
@MainActor
struct ProviderFactory {

    private let settings: SharedSettings

    init(settings: SharedSettings? = nil) {
        self.settings = settings ?? SharedSettings.shared
    }

    // MARK: - Transcription Providers

    /// Create a transcription provider for the specified AI provider
    /// - Parameter provider: The AI provider type
    /// - Returns: A configured TranscriptionProvider, or nil if not configured
    func createTranscriptionProvider(for provider: AIProvider) -> TranscriptionProvider? {
        guard let config = settings.getAIProviderConfig(for: provider),
              provider.supportsTranscription else {
            return nil
        }

        switch provider {
        case .openAI:
            return OpenAITranscriptionService(config: config)

        case .assemblyAI:
            guard !config.apiKey.isEmpty else { return nil }
            return AssemblyAITranscriptionService(
                apiKey: config.apiKey,
                model: config.transcriptionModel ?? "default"
            )

        case .deepgram:
            guard !config.apiKey.isEmpty else { return nil }
            return DeepgramTranscriptionService(
                apiKey: config.apiKey,
                model: config.transcriptionModel ?? "nova-2"
            )

        case .google:
            guard !config.apiKey.isEmpty,
                  let projectId = config.googleProjectId,
                  !projectId.isEmpty else { return nil }
            return GoogleSTTService(
                apiKey: config.apiKey,
                projectId: projectId,
                model: config.transcriptionModel ?? "long"
            )

        case .local:
            // TODO: Implement local transcription provider (Whisper via Ollama/etc)
            return nil

        case .elevenLabs:
            // TODO: Implement ElevenLabs transcription (Phase 3 scope but lower priority)
            return nil

        case .anthropic, .deepL, .azure:
            // These providers don't support transcription
            return nil
        }
    }

    /// Create the currently selected transcription provider
    func createSelectedTranscriptionProvider() -> TranscriptionProvider? {
        createTranscriptionProvider(for: settings.selectedTranscriptionProvider)
    }

    // MARK: - Translation Providers

    /// Create a translation provider for the specified AI provider
    /// - Parameter provider: The AI provider type
    /// - Returns: A configured TranslationProvider, or nil if not configured
    func createTranslationProvider(for provider: AIProvider) -> TranslationProvider? {
        guard let config = settings.getAIProviderConfig(for: provider),
              provider.supportsTranslation else {
            return nil
        }

        switch provider {
        case .openAI:
            return OpenAITranslationService(config: config)

        case .deepL:
            guard !config.apiKey.isEmpty else { return nil }
            return DeepLTranslationService(apiKey: config.apiKey)

        case .google:
            guard !config.apiKey.isEmpty else { return nil }
            return GoogleTranslationService(apiKey: config.apiKey)

        case .azure:
            guard !config.apiKey.isEmpty,
                  let region = config.azureRegion,
                  !region.isEmpty else { return nil }
            return AzureTranslatorService(
                apiKey: config.apiKey,
                region: region
            )

        case .anthropic:
            // Anthropic can translate via LLM - use formatting provider approach
            guard !config.apiKey.isEmpty else { return nil }
            return AnthropicTranslationAdapter(
                formattingService: AnthropicService(
                    apiKey: config.apiKey,
                    model: config.translationModel ?? "claude-3-5-sonnet-latest"
                )
            )

        case .local:
            // TODO: Implement local translation provider
            return nil

        case .assemblyAI, .deepgram, .elevenLabs:
            // These providers don't support translation
            return nil
        }
    }

    /// Create the currently selected translation provider
    func createSelectedTranslationProvider() -> TranslationProvider? {
        createTranslationProvider(for: settings.selectedTranslationProvider)
    }

    // MARK: - Formatting Providers (Power Mode)

    /// Create a formatting provider for the specified AI provider
    /// - Parameter provider: The AI provider type
    /// - Returns: A configured FormattingProvider, or nil if not configured
    func createFormattingProvider(for provider: AIProvider) -> FormattingProvider? {
        guard let config = settings.getAIProviderConfig(for: provider),
              provider.supportsPowerMode else {
            return nil
        }

        switch provider {
        case .openAI:
            return OpenAIFormattingService(config: config)

        case .anthropic:
            guard !config.apiKey.isEmpty else { return nil }
            return AnthropicService(
                apiKey: config.apiKey,
                model: config.powerModeModel ?? "claude-3-5-sonnet-latest"
            )

        case .google:
            guard !config.apiKey.isEmpty else { return nil }
            return GeminiService(
                apiKey: config.apiKey,
                model: config.powerModeModel ?? "gemini-2.0-flash-exp"
            )

        case .local:
            // TODO: Implement local formatting provider
            return nil

        case .assemblyAI, .deepgram, .elevenLabs, .deepL, .azure:
            // These providers don't support power mode
            return nil
        }
    }

    /// Create the currently selected formatting/power mode provider
    func createSelectedFormattingProvider() -> FormattingProvider? {
        createFormattingProvider(for: settings.selectedPowerModeProvider)
    }

    /// Create a formatting provider for text formatting (uses translation provider setting)
    func createSelectedTextFormattingProvider() -> FormattingProvider? {
        // For text formatting, we use the translation provider setting
        // since both use LLM capabilities
        createFormattingProvider(for: settings.selectedTranslationProvider)
    }

    // MARK: - Validation Helpers

    /// Check if a provider is fully configured for a specific capability
    func isProviderConfigured(_ provider: AIProvider, for category: ProviderUsageCategory) -> Bool {
        guard let config = settings.getAIProviderConfig(for: provider) else {
            return false
        }

        // Check API key (except for local providers)
        if !provider.isLocalProvider && config.apiKey.isEmpty {
            return false
        }

        // Check provider-specific requirements
        switch (provider, category) {
        case (.google, .transcription):
            // Google STT requires project ID
            return config.googleProjectId?.isEmpty == false

        case (.azure, .translation):
            // Azure requires region
            return config.azureRegion?.isEmpty == false

        case (.local, _):
            // Local requires valid base URL
            return config.localConfig?.baseURL.isEmpty == false

        default:
            return true
        }
    }

    /// Get all configured providers for a capability
    func configuredProviders(for category: ProviderUsageCategory) -> [AIProvider] {
        AIProvider.allCases.filter { provider in
            switch category {
            case .transcription:
                return provider.supportsTranscription && isProviderConfigured(provider, for: category)
            case .translation:
                return provider.supportsTranslation && isProviderConfigured(provider, for: category)
            case .powerMode:
                return provider.supportsPowerMode && isProviderConfigured(provider, for: category)
            }
        }
    }
}

// MARK: - Anthropic Translation Adapter

/// Adapter to use Anthropic's formatting service as a translation provider
/// Since Anthropic Claude can translate via prompting
private final class AnthropicTranslationAdapter: TranslationProvider {

    let providerId: AIProvider = .anthropic
    var isConfigured: Bool { formattingService.isConfigured }
    var model: String { formattingService.model }
    var supportedLanguages: [Language] { Language.allCases }
    var supportsFormality: Bool { true } // LLM can understand formality through context

    private let formattingService: AnthropicService

    init(formattingService: AnthropicService) {
        self.formattingService = formattingService
    }

    func translate(
        text: String,
        from sourceLanguage: Language?,
        to targetLanguage: Language,
        formality: Formality?,
        context: PromptContext?
    ) async throws -> String {
        // If we have a context with content, use the PromptContext's translation prompt builder
        if let ctx = context, ctx.hasContent {
            let translationPrompt = ctx.buildTranslationPrompt(to: targetLanguage, from: sourceLanguage)
            return try await formattingService.format(text: text, mode: .raw, customPrompt: translationPrompt, context: nil)
        }

        // Build basic translation prompt with optional formality
        var prompt = """
        Translate the following text to \(targetLanguage.displayName).
        \(sourceLanguage != nil ? "The source language is \(sourceLanguage!.displayName)." : "Detect the source language automatically.")
        """

        if let f = formality {
            switch f {
            case .formal:
                prompt += "\nUse formal language and polite forms of address."
            case .informal:
                prompt += "\nUse casual, informal language."
            case .neutral:
                break
            }
        }

        prompt += "\nOnly return the translated text, nothing else."

        return try await formattingService.format(text: text, mode: .raw, customPrompt: prompt, context: nil)
    }
}
