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
        guard let config = settings.getAIProviderConfig(for: provider),
              !config.apiKey.isEmpty else { return nil }

        switch provider {
        case .openAI:
            return SwiftSpeakCore.OpenAITranscriptionService(config: config)

        case .assemblyAI:
            return SwiftSpeakCore.AssemblyAITranscriptionService(config: config)

        case .deepgram:
            return SwiftSpeakCore.DeepgramTranscriptionService(config: config)

        case .google:
            guard let projectId = config.googleProjectId, !projectId.isEmpty else { return nil }
            return SwiftSpeakCore.GoogleSTTService(config: config)

        default:
            return nil
        }
    }

    // MARK: - Streaming Transcription Providers

    func createStreamingTranscriptionProvider(for provider: AIProvider) -> StreamingTranscriptionProvider? {
        guard let config = settings.getAIProviderConfig(for: provider),
              !config.apiKey.isEmpty else { return nil }

        switch provider {
        case .openAI:
            return SwiftSpeakCore.OpenAIStreamingService(config: config)

        case .assemblyAI:
            return SwiftSpeakCore.AssemblyAIStreamingService(config: config)

        case .deepgram:
            return SwiftSpeakCore.DeepgramStreamingService(config: config)

        default:
            return nil
        }
    }

    // MARK: - Formatting Providers

    func createFormattingProvider(for provider: AIProvider) -> FormattingProvider? {
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
        createFormattingProvider(for: settings.selectedPowerModeProvider)
    }
}
