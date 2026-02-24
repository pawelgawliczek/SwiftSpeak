//
//  MacProviderFactory.swift
//  SwiftSpeakMac
//
//  Provider factory for macOS using shared services from SwiftSpeakCore
//

import Foundation
import SwiftSpeakCore

// MARK: - Provider Factory

@MainActor
struct ProviderFactory {
    private let settings: MacSettings

    // Cache WhisperKit service to avoid reloading model on each transcription
    private static var cachedWhisperKitService: WhisperKitTranscriptionService?
    private static var cachedWhisperKitModel: String?

    // Cache Parakeet service to avoid re-checking installation
    private static var cachedParakeetService: ParakeetTranscriptionService?

    init(settings: MacSettings) {
        self.settings = settings
    }

    // MARK: - Transcription Providers

    func createTranscriptionProvider(for provider: AIProvider) -> TranscriptionProvider? {
        // Handle local providers first - they don't need AIProviderConfig
        switch provider {
        case .whisperKit, .local:
            // WhisperKit on-device transcription (uses whisperKitConfig, not AIProviderConfig)
            return createWhisperKitProvider()
        case .parakeetMLX:
            // Parakeet MLX on-device transcription (macOS only)
            return createParakeetProvider()
        case .appleSpeech:
            // On-device Apple Speech Recognition
            return SwiftSpeakCore.AppleSpeechTranscriptionService()
        default:
            break
        }

        // Cloud providers need AIProviderConfig
        guard let config = settings.getAIProviderConfig(for: provider) else {
            macLog("Provider \(provider.displayName) not configured", category: "ProviderFactory", level: .error)
            return nil
        }

        guard !config.apiKey.isEmpty else {
            macLog("Provider \(provider.displayName) has empty API key", category: "ProviderFactory", level: .error)
            return nil
        }

        switch provider {
        case .openAI:
            return SwiftSpeakCore.OpenAITranscriptionService(config: config)

        case .assemblyAI:
            return SwiftSpeakCore.AssemblyAITranscriptionService(config: config)

        case .deepgram:
            return SwiftSpeakCore.DeepgramTranscriptionService(config: config)

        case .google:
            guard let projectId = config.googleProjectId, !projectId.isEmpty else {
                macLog("Google Cloud STT requires Project ID - currently empty or nil", category: "ProviderFactory", level: .error)
                return nil
            }
            return SwiftSpeakCore.GoogleSTTService(config: config)

        default:
            macLog("Provider \(provider.displayName) does not support transcription", category: "ProviderFactory", level: .error)
            return nil
        }
    }

    // MARK: - Streaming Transcription Providers

    func createStreamingTranscriptionProvider(for provider: AIProvider) -> StreamingTranscriptionProvider? {
        // Apple Speech doesn't need configuration or API key
        if provider == .appleSpeech {
            return SwiftSpeakCore.AppleSpeechStreamingService()
        }

        guard let config = settings.getAIProviderConfig(for: provider),
              !config.apiKey.isEmpty else { return nil }

        switch provider {
        case .openAI:
            return SwiftSpeakCore.OpenAIStreamingService(config: config)

        case .assemblyAI:
            return SwiftSpeakCore.AssemblyAIStreamingService(config: config)

        case .deepgram:
            return SwiftSpeakCore.DeepgramStreamingService(config: config)

        case .google:
            guard let projectId = config.googleProjectId, !projectId.isEmpty else {
                macLog("Google Cloud STT streaming requires Project ID", category: "ProviderFactory", level: .error)
                return nil
            }
            return SwiftSpeakCore.GoogleStreamingSTTService(config: config)

        default:
            return nil
        }
    }

    // MARK: - Formatting Providers

    func createFormattingProvider(for provider: AIProvider) -> FormattingProvider? {
        // Handle local providers (Apple Intelligence) - no API key needed
        if provider == .local {
            return createAppleIntelligenceProvider()
        }

        guard let config = settings.getAIProviderConfig(for: provider),
              !config.apiKey.isEmpty else { return nil }

        switch provider {
        case .openAI:
            return SwiftSpeakCore.OpenAIFormattingService(config: config)

        case .anthropic:
            return SwiftSpeakCore.AnthropicService(config: config)

        case .google:
            return SwiftSpeakCore.GeminiService(config: config)

        default:
            return nil
        }
    }

    // MARK: - Apple Intelligence

    /// Create Apple Intelligence formatting provider
    private func createAppleIntelligenceProvider() -> FormattingProvider? {
        guard settings.isAppleIntelligenceReady else {
            // Log detailed diagnostics
            let config = settings.appleIntelligenceConfig
            macLog("Apple Intelligence not ready - isAvailable: \(config.isAvailable), isEnabled: \(config.isEnabled), reason: \(config.unavailableReason ?? "none")", category: "ProviderFactory", level: .warning)
            return nil
        }

        if #available(macOS 26.0, *) {
            return AppleIntelligenceFormattingService(config: settings.appleIntelligenceConfig)
        }
        return AppleIntelligenceFormattingServiceFallback()
    }

    // MARK: - Streaming Formatting Providers

    func createStreamingFormattingProvider(for provider: AIProvider) -> StreamingFormattingProvider? {
        guard let config = settings.getAIProviderConfig(for: provider),
              !config.apiKey.isEmpty else { return nil }

        switch provider {
        case .openAI:
            return SwiftSpeakCore.OpenAIFormattingService(config: config)

        case .anthropic:
            return SwiftSpeakCore.AnthropicService(config: config)

        default:
            return nil
        }
    }

    // MARK: - Translation Providers

    func createTranslationProvider(for provider: AIProvider) -> TranslationProvider? {
        guard let config = settings.getAIProviderConfig(for: provider),
              !config.apiKey.isEmpty else { return nil }

        switch provider {
        case .openAI:
            return SwiftSpeakCore.OpenAITranslationService(config: config)

        case .deepL:
            return SwiftSpeakCore.DeepLTranslationService(config: config)

        case .google:
            return SwiftSpeakCore.GoogleTranslationService(config: config)

        case .azure:
            guard let region = config.azureRegion, !region.isEmpty else { return nil }
            return SwiftSpeakCore.AzureTranslatorService(config: config)

        default:
            return nil
        }
    }

    /// Create the currently selected translation provider
    func createSelectedTranslationProvider() -> TranslationProvider? {
        createTranslationProvider(for: settings.selectedTranslationProvider)
    }

    /// Create the currently selected transcription provider
    func createSelectedTranscriptionProvider() -> TranscriptionProvider? {
        createTranscriptionProvider(for: settings.selectedTranscriptionProvider)
    }

    /// Create the currently selected formatting provider
    func createSelectedFormattingProvider() -> FormattingProvider? {
        createFormattingProvider(for: settings.selectedFormattingProvider)
    }

    /// Create formatting provider from ProviderSelection (for context overrides)
    func createFormattingProvider(from selection: ProviderSelection) -> FormattingProvider? {
        switch selection.providerType {
        case .cloud(let provider):
            return createFormattingProvider(for: provider)
        case .local(let localType):
            switch localType {
            case .appleIntelligence:
                return createAppleIntelligenceProvider()
            case .whisperKit:
                // WhisperKit is transcription only, not formatting
                macLog("WhisperKit does not support formatting", category: "ProviderFactory", level: .error)
                return nil
            case .appleTranslation:
                // Apple Translation is translation only, not formatting
                macLog("Apple Translation does not support formatting", category: "ProviderFactory", level: .error)
                return nil
            case .ollama, .lmStudio:
                // TODO: Implement Ollama/LM Studio formatting support
                macLog("\(localType.displayName) formatting not yet implemented", category: "ProviderFactory", level: .error)
                return nil
            }
        }
    }

    // MARK: - Local Provider Factory Methods

    /// Create WhisperKit transcription provider (cached for performance)
    private func createWhisperKitProvider() -> TranscriptionProvider? {
        guard settings.whisperKitConfig.status == .ready else {
            macLog("WhisperKit not ready (status: \(settings.whisperKitConfig.status))", category: "ProviderFactory", level: .error)
            return nil
        }

        #if canImport(WhisperKit)
        let currentModel = settings.whisperKitConfig.selectedModel.rawValue

        // Return cached service if model hasn't changed
        if let cached = Self.cachedWhisperKitService,
           Self.cachedWhisperKitModel == currentModel {
            macLog("Using cached WhisperKit service (model: \(currentModel))", category: "ProviderFactory", level: .debug)
            return cached
        }

        // Create new service and cache it
        macLog("Creating new WhisperKit service (model: \(currentModel))", category: "ProviderFactory", level: .info)
        let service = WhisperKitTranscriptionService(config: settings.whisperKitConfig)
        Self.cachedWhisperKitService = service
        Self.cachedWhisperKitModel = currentModel
        return service
        #else
        macLog("WhisperKit framework not available - add WhisperKit to macOS target in Xcode", category: "ProviderFactory", level: .error)
        return nil
        #endif
    }

    /// Clear the cached WhisperKit service (call when model changes or to free memory)
    static func clearWhisperKitCache() {
        cachedWhisperKitService?.unloadModel()
        cachedWhisperKitService = nil
        cachedWhisperKitModel = nil
        macLog("WhisperKit cache cleared", category: "ProviderFactory", level: .info)
    }

    // MARK: - Parakeet MLX Provider

    /// Create Parakeet MLX transcription provider (cached)
    private func createParakeetProvider() -> TranscriptionProvider? {
        guard settings.parakeetMLXConfig.status == .ready else {
            macLog("Parakeet MLX not ready (status: \(settings.parakeetMLXConfig.status))", category: "ProviderFactory", level: .error)
            return nil
        }

        // Return cached service if available
        if let cached = Self.cachedParakeetService {
            macLog("Using cached Parakeet MLX service", category: "ProviderFactory", level: .debug)
            return cached
        }

        // Create new service and cache it
        macLog("Creating new Parakeet MLX service (model: \(settings.parakeetMLXConfig.modelId))", category: "ProviderFactory", level: .info)
        let service = ParakeetTranscriptionService(config: settings.parakeetMLXConfig)
        Self.cachedParakeetService = service
        return service
    }

    /// Clear the cached Parakeet service
    static func clearParakeetCache() {
        cachedParakeetService = nil
        macLog("Parakeet cache cleared", category: "ProviderFactory", level: .info)
    }

    /// Preload WhisperKit model in background (call when recording starts)
    /// This starts loading the model while user is speaking so it's ready when they finish
    func preloadWhisperKitModel() async {
        #if canImport(WhisperKit)
        guard settings.whisperKitConfig.status == .ready else { return }
        guard settings.selectedTranscriptionProvider == .whisperKit else { return }

        // Get or create the cached service
        guard let service = createWhisperKitProvider() as? WhisperKitTranscriptionService else { return }

        do {
            macLog("Preloading WhisperKit model in background...", category: "ProviderFactory", level: .info)
            try await service.initialize()
            macLog("WhisperKit model preloaded successfully", category: "ProviderFactory", level: .info)
        } catch {
            macLog("WhisperKit preload failed: \(error)", category: "ProviderFactory", level: .warning)
        }
        #endif
    }
}
