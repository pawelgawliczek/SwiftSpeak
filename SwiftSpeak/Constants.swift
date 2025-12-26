//
//  Constants.swift
//  SwiftSpeak
//
//  Shared constants between main app and keyboard extension
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
        static let selectedProvider = "selectedProvider"
        static let openAIAPIKey = "openAIAPIKey"
        static let anthropicAPIKey = "anthropicAPIKey"
        static let elevenLabsAPIKey = "elevenLabsAPIKey"
        static let deepgramAPIKey = "deepgramAPIKey"
        static let ollamaEndpoint = "ollamaEndpoint"
        static let selectedMode = "selectedMode"
        static let selectedTargetLanguage = "selectedTargetLanguage"
        static let lastTranscription = "lastTranscription"
        static let transcriptionHistory = "transcriptionHistory"
        static let subscriptionTier = "subscriptionTier"
    }

    // MARK: - API Endpoints
    enum API {
        static let openAIWhisper = "https://api.openai.com/v1/audio/transcriptions"
        static let openAIChat = "https://api.openai.com/v1/chat/completions"
        static let anthropic = "https://api.anthropic.com/v1/messages"
        static let elevenLabs = "https://api.elevenlabs.io/v1/speech-to-text"
        static let deepgram = "https://api.deepgram.com/v1/listen"
    }

    // MARK: - Subscription Product IDs
    enum Products {
        static let proMonthly = "com.swiftspeak.pro.monthly"
        static let proYearly = "com.swiftspeak.pro.yearly"
        static let powerMonthly = "com.swiftspeak.power.monthly"
        static let powerYearly = "com.swiftspeak.power.yearly"
    }
}
