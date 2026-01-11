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

    init(settings: MacSettings) {
        self.settings = settings
    }

    // MARK: - Transcription Providers

    func createTranscriptionProvider(for provider: AIProvider) -> TranscriptionProvider? {
        // Apple Speech doesn't need configuration or API key
        if provider == .appleSpeech {
            return SwiftSpeakCore.AppleSpeechTranscriptionService()
        }

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
            macLog("Apple Intelligence not ready", category: "ProviderFactory", level: .warning)
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
}
