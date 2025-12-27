//
//  Constants.swift
//  SwiftSpeak
//
//  Shared constants between main app and keyboard extension
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

enum Constants {
    // MARK: - App Group
    static let appGroupIdentifier = "group.pawelgawliczek.swiftspeak"

    // MARK: - URL Scheme
    static let urlScheme = "swiftspeak"

    // MARK: - UserDefaults Keys
    enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let configuredAIProviders = "configuredAIProviders"
        static let selectedTranscriptionProvider = "selectedTranscriptionProvider"
        static let selectedTranslationProvider = "selectedTranslationProvider"
        static let selectedPowerModeProvider = "selectedPowerModeProvider"
        static let openAIAPIKey = "openAIAPIKey"
        static let anthropicAPIKey = "anthropicAPIKey"
        static let elevenLabsAPIKey = "elevenLabsAPIKey"
        static let deepgramAPIKey = "deepgramAPIKey"
        static let ollamaEndpoint = "ollamaEndpoint"
        static let selectedMode = "selectedMode"
        static let selectedTargetLanguage = "selectedTargetLanguage"
        static let isTranslationEnabled = "isTranslationEnabled"
        static let autoReturnEnabled = "autoReturnEnabled"
        static let lastTranscription = "lastTranscription"
        static let transcriptionHistory = "transcriptionHistory"
        static let subscriptionTier = "subscriptionTier"
        static let vocabulary = "vocabulary"
        static let customTemplates = "customTemplates"

        // Phase 4: Contexts and Power Modes
        static let contexts = "contexts"
        static let activeContextId = "activeContextId"
        static let powerModes = "powerModes"
        static let historyMemory = "historyMemory"
    }

    // MARK: - API Endpoints
    enum API {
        // OpenAI
        static let openAIWhisper = "https://api.openai.com/v1/audio/transcriptions"
        static let openAIChat = "https://api.openai.com/v1/chat/completions"

        // Anthropic
        static let anthropic = "https://api.anthropic.com/v1/messages"

        // ElevenLabs
        static let elevenLabs = "https://api.elevenlabs.io/v1/speech-to-text"

        // Deepgram
        static let deepgram = "https://api.deepgram.com/v1/listen"

        // AssemblyAI
        static let assemblyAIUpload = "https://api.assemblyai.com/v2/upload"
        static let assemblyAITranscript = "https://api.assemblyai.com/v2/transcript"

        // Google Cloud
        static let googleSTT = "https://speech.googleapis.com/v2/projects"
        static let googleTranslation = "https://translation.googleapis.com/language/translate/v2"
        static let gemini = "https://generativelanguage.googleapis.com/v1beta/models"

        // DeepL
        static let deepL = "https://api.deepl.com/v2/translate"
        static let deepLFree = "https://api-free.deepl.com/v2/translate"

        // Azure
        static let azureTranslator = "https://api.cognitive.microsofttranslator.com/translate"
    }

    // MARK: - Subscription Product IDs
    enum Products {
        static let proMonthly = "com.swiftspeak.pro.monthly"
        static let proYearly = "com.swiftspeak.pro.yearly"
        static let powerMonthly = "com.swiftspeak.power.monthly"
        static let powerYearly = "com.swiftspeak.power.yearly"
    }
}
