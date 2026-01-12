//
//  ProviderFactory.swift
//  SwiftSpeak
//
//  Unified factory for creating provider instances
//  Phase 10f: Added local provider support (WhisperKit, Apple Translation, Apple Intelligence)
//

import Foundation
import SwiftSpeakCore

/// Central factory for creating provider instances based on configuration
/// Supports all Phase 3 providers for transcription, translation, and power mode
/// Phase 10f: Added local on-device provider support
@MainActor
struct ProviderFactory {

    private let settings: SharedSettings

    // Cache WhisperKit service to avoid reloading model on each transcription
    private static var cachedWhisperKitService: WhisperKitTranscriptionService?
    private static var cachedWhisperKitModel: String?

    init(settings: SharedSettings? = nil) {
        self.settings = settings ?? SharedSettings.shared
    }

    // MARK: - Transcription Providers

    /// Create a transcription provider for the specified AI provider
    /// - Parameter provider: The AI provider type
    /// - Returns: A configured TranscriptionProvider, or nil if not configured
    func createTranscriptionProvider(for provider: AIProvider) -> TranscriptionProvider? {
        // Handle local providers first - they don't need AIProviderConfig
        switch provider {
        case .whisperKit, .local:
            // WhisperKit on-device transcription (uses whisperKitConfig, not AIProviderConfig)
            return createWhisperKitProvider()
        case .appleSpeech:
            // On-device Apple Speech Recognition (SFSpeechRecognizer)
            return SwiftSpeakCore.AppleSpeechTranscriptionService()
        default:
            break
        }

        // Cloud providers need AIProviderConfig
        guard let config = settings.getAIProviderConfig(for: provider),
              provider.supportsTranscription else {
            return nil
        }

        switch provider {
        case .openAI:
            return SwiftSpeakCore.OpenAITranscriptionService(config: config)

        case .assemblyAI:
            guard !config.apiKey.isEmpty else { return nil }
            return SwiftSpeakCore.AssemblyAITranscriptionService(config: config)

        case .deepgram:
            guard !config.apiKey.isEmpty else { return nil }
            return SwiftSpeakCore.DeepgramTranscriptionService(config: config)

        case .google:
            guard !config.apiKey.isEmpty,
                  let projectId = config.googleProjectId,
                  !projectId.isEmpty else { return nil }
            return SwiftSpeakCore.GoogleSTTService(config: config)

        case .elevenLabs:
            guard !config.apiKey.isEmpty else { return nil }
            return SwiftSpeakCore.ElevenLabsTranscriptionService(config: config)

        case .anthropic, .deepL, .azure:
            // These providers don't support transcription
            return nil

        case .local, .appleSpeech, .whisperKit:
            // Already handled above
            return nil
        }
    }

    /// Create the currently selected transcription provider
    func createSelectedTranscriptionProvider() -> TranscriptionProvider? {
        createTranscriptionProvider(for: settings.selectedTranscriptionProvider)
    }

    /// Create transcription provider from ProviderSelection (supports context overrides)
    func createTranscriptionProvider(for selection: ProviderSelection) -> TranscriptionProvider? {
        switch selection.providerType {
        case .cloud(let provider):
            return createTranscriptionProvider(for: provider)
        case .local(let localType):
            switch localType {
            case .whisperKit:
                return createWhisperKitProvider()
            case .ollama, .lmStudio:
                // TODO: Implement self-hosted transcription providers
                return nil
            case .appleTranslation, .appleIntelligence:
                return nil // These don't support transcription
            }
        }
    }

    /// Create transcription provider using effective provider (respects context overrides)
    func createEffectiveTranscriptionProvider() -> TranscriptionProvider? {
        createTranscriptionProvider(for: settings.effectiveTranscriptionProvider)
    }

    // MARK: - Streaming Transcription Providers

    /// Create a streaming transcription provider for real-time transcription
    /// - Parameter provider: The AI provider type (must support streaming)
    /// - Returns: A configured StreamingTranscriptionProvider, or nil if not supported
    func createStreamingTranscriptionProvider(for provider: AIProvider) -> StreamingTranscriptionProvider? {
        // Apple Speech doesn't need API key for streaming
        if provider == .appleSpeech {
            return SwiftSpeakCore.AppleSpeechStreamingService()
        }

        guard let config = settings.getAIProviderConfig(for: provider),
              !config.apiKey.isEmpty,
              provider.supportsStreamingTranscription else {
            return nil
        }

        switch provider {
        case .openAI:
            return SwiftSpeakCore.OpenAIStreamingService(config: config)

        case .assemblyAI:
            return SwiftSpeakCore.AssemblyAIStreamingService(config: config)

        case .deepgram:
            return SwiftSpeakCore.DeepgramStreamingService(config: config)

        case .google:
            return SwiftSpeakCore.GoogleStreamingSTTService(config: config)

        default:
            return nil
        }
    }

    /// Create streaming provider for the currently selected transcription provider
    func createSelectedStreamingProvider() -> StreamingTranscriptionProvider? {
        createStreamingTranscriptionProvider(for: settings.selectedTranscriptionProvider)
    }

    /// Check if the current provider supports streaming transcription
    var isStreamingAvailable: Bool {
        let provider = settings.selectedTranscriptionProvider
        return provider == .openAI || provider == .deepgram || provider == .assemblyAI || provider == .google || provider == .appleSpeech
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
            return SwiftSpeakCore.OpenAITranslationService(config: config)

        case .deepL:
            guard !config.apiKey.isEmpty else { return nil }
            return SwiftSpeakCore.DeepLTranslationService(config: config)

        case .google:
            guard !config.apiKey.isEmpty else { return nil }
            return SwiftSpeakCore.GoogleTranslationService(config: config)

        case .azure:
            guard !config.apiKey.isEmpty,
                  let region = config.azureRegion,
                  !region.isEmpty else { return nil }
            return SwiftSpeakCore.AzureTranslatorService(config: config)

        case .anthropic:
            // Anthropic can translate via LLM - use formatting provider approach
            guard !config.apiKey.isEmpty else { return nil }
            return AnthropicTranslationAdapter(
                formattingService: SwiftSpeakCore.AnthropicService(
                    apiKey: config.apiKey,
                    model: config.translationModel ?? "claude-3-5-sonnet-latest"
                )
            )

        case .local:
            // Phase 10f: Apple Translation on-device
            return createAppleTranslationProvider()

        case .assemblyAI, .deepgram, .elevenLabs, .appleSpeech, .whisperKit:
            // These providers don't support translation
            return nil
        }
    }

    /// Create the currently selected translation provider
    func createSelectedTranslationProvider() -> TranslationProvider? {
        createTranslationProvider(for: settings.selectedTranslationProvider)
    }

    /// Create translation provider from ProviderSelection (supports context overrides)
    func createTranslationProvider(for selection: ProviderSelection) -> TranslationProvider? {
        switch selection.providerType {
        case .cloud(let provider):
            return createTranslationProvider(for: provider)
        case .local(let localType):
            switch localType {
            case .appleTranslation:
                return createAppleTranslationProvider()
            case .ollama, .lmStudio:
                // TODO: Implement self-hosted translation providers
                return nil
            case .whisperKit, .appleIntelligence:
                return nil // These don't support translation
            }
        }
    }

    /// Create translation provider using effective provider (respects context overrides)
    func createEffectiveTranslationProvider() -> TranslationProvider? {
        createTranslationProvider(for: settings.effectiveTranslationProvider)
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
            return SwiftSpeakCore.OpenAIFormattingService(config: config)

        case .anthropic:
            guard !config.apiKey.isEmpty else { return nil }
            return SwiftSpeakCore.AnthropicService(
                apiKey: config.apiKey,
                model: config.powerModeModel ?? "claude-3-5-sonnet-latest"
            )

        case .google:
            guard !config.apiKey.isEmpty else { return nil }
            return SwiftSpeakCore.GeminiService(
                apiKey: config.apiKey,
                model: config.powerModeModel ?? "gemini-2.0-flash-exp"
            )

        case .local:
            // Phase 10f: Apple Intelligence on-device formatting
            return createAppleIntelligenceProvider()

        case .assemblyAI, .deepgram, .elevenLabs, .deepL, .azure, .appleSpeech, .whisperKit:
            // These providers don't support power mode
            return nil
        }
    }

    /// Create the currently selected formatting/power mode provider
    func createSelectedFormattingProvider() -> FormattingProvider? {
        createFormattingProvider(for: settings.selectedPowerModeProvider)
    }

    /// Create formatting provider from ProviderSelection (supports context overrides)
    func createFormattingProvider(for selection: ProviderSelection) -> FormattingProvider? {
        switch selection.providerType {
        case .cloud(let provider):
            return createFormattingProvider(for: provider)
        case .local(let localType):
            switch localType {
            case .appleIntelligence:
                return createAppleIntelligenceProvider()
            case .ollama, .lmStudio:
                // TODO: Implement self-hosted formatting providers
                return nil
            case .whisperKit, .appleTranslation:
                return nil // These don't support formatting/power mode
            }
        }
    }

    /// Create formatting provider using effective provider (respects context overrides)
    func createEffectiveFormattingProvider() -> FormattingProvider? {
        createFormattingProvider(for: settings.effectiveFormattingProvider)
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

        case (.local, .transcription):
            // WhisperKit requires model downloaded and enabled
            return settings.isWhisperKitReady

        case (.local, .translation):
            // Apple Translation requires iOS 17.4+ and languages downloaded
            return settings.hasLocalTranslation

        case (.local, .powerMode):
            // Apple Intelligence requires iOS 26+ and enabled
            return settings.isAppleIntelligenceReady

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
            case .formatting, .powerMode:
                return provider.supportsPowerMode && isProviderConfigured(provider, for: category)
            }
        }
    }

    // MARK: - Phase 10f: Local Provider Factory Methods

    /// Create WhisperKit transcription provider (cached for performance)
    private func createWhisperKitProvider() -> TranscriptionProvider? {
        guard settings.isWhisperKitReady else { return nil }

        let currentModel = settings.whisperKitConfig.selectedModel.rawValue

        // Return cached service if model hasn't changed
        if let cached = Self.cachedWhisperKitService,
           Self.cachedWhisperKitModel == currentModel {
            appLog("Using cached WhisperKit service (model: \(currentModel))", category: "ProviderFactory")
            return cached
        }

        // Create new service and cache it
        appLog("Creating new WhisperKit service (model: \(currentModel))", category: "ProviderFactory")
        let service = WhisperKitTranscriptionService(config: settings.whisperKitConfig)
        Self.cachedWhisperKitService = service
        Self.cachedWhisperKitModel = currentModel
        return service
    }

    /// Clear the cached WhisperKit service (call when model changes or to free memory)
    static func clearWhisperKitCache() {
        cachedWhisperKitService?.unloadModel()
        cachedWhisperKitService = nil
        cachedWhisperKitModel = nil
        appLog("WhisperKit cache cleared", category: "ProviderFactory")
    }

    /// Preload WhisperKit model in background (call when recording starts)
    /// This starts loading the model while user is speaking so it's ready when they finish
    func preloadWhisperKitModel() async {
        guard settings.isWhisperKitReady else { return }
        guard settings.selectedTranscriptionProvider == .whisperKit || settings.selectedTranscriptionProvider == .local else { return }

        // Get or create the cached service
        guard let service = createWhisperKitProvider() as? WhisperKitTranscriptionService else { return }

        do {
            appLog("Preloading WhisperKit model in background...", category: "ProviderFactory")
            try await service.initialize()
            appLog("WhisperKit model preloaded successfully", category: "ProviderFactory")
        } catch {
            appLog("WhisperKit preload failed: \(error)", category: "ProviderFactory")
        }
    }

    /// Create Apple Translation provider
    private func createAppleTranslationProvider() -> TranslationProvider? {
        guard settings.hasLocalTranslation else { return nil }

        if #available(iOS 17.4, *) {
            return AppleTranslationService(config: settings.appleTranslationConfig)
        }
        return nil
    }

    /// Create Apple Intelligence formatting provider
    private func createAppleIntelligenceProvider() -> FormattingProvider? {
        guard settings.isAppleIntelligenceReady else { return nil }

        if #available(iOS 26.0, macOS 26.0, *) {
            return AppleIntelligenceFormattingService(config: settings.appleIntelligenceConfig)
        }
        return AppleIntelligenceFormattingServiceFallback()
    }

    /// Create streaming formatting provider for Power Mode
    /// Returns a StreamingFormattingProvider if available, otherwise falls back to regular
    func createStreamingFormattingProvider(for provider: AIProvider) -> StreamingFormattingProvider? {
        switch provider {
        case .openAI:
            guard let config = settings.getAIProviderConfig(for: provider) else { return nil }
            return SwiftSpeakCore.OpenAIFormattingService(config: config)

        case .anthropic:
            guard let config = settings.getAIProviderConfig(for: provider),
                  !config.apiKey.isEmpty else { return nil }
            return SwiftSpeakCore.AnthropicService(
                apiKey: config.apiKey,
                model: config.powerModeModel ?? "claude-3-5-sonnet-latest"
            )

        case .local:
            // Apple Intelligence supports streaming
            guard settings.isAppleIntelligenceReady else { return nil }
            if #available(iOS 26.0, macOS 26.0, *) {
                return AppleIntelligenceFormattingService(config: settings.appleIntelligenceConfig)
            }
            return nil

        default:
            return nil
        }
    }

    /// Create the currently selected streaming provider for Power Mode
    func createSelectedStreamingFormattingProvider() -> StreamingFormattingProvider? {
        createStreamingFormattingProvider(for: settings.selectedPowerModeProvider)
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

    private let formattingService: SwiftSpeakCore.AnthropicService

    init(formattingService: SwiftSpeakCore.AnthropicService) {
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
