//
//  Models.swift
//  SwiftSpeak
//
//  Shared data models between main app and keyboard extension
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation
import SwiftUI

// MARK: - Subscription Tier
enum SubscriptionTier: String, Codable, CaseIterable {
    case free = "free"
    case pro = "pro"
    case power = "power"

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .power: return "Power"
        }
    }

    var price: String {
        switch self {
        case .free: return "$0"
        case .pro: return "$6.99/mo"
        case .power: return "$12.99/mo"
        }
    }
}

// MARK: - Phase 6: Data Retention

/// Options for automatic transcription history cleanup
enum DataRetentionPeriod: String, Codable, CaseIterable, Identifiable {
    case never = "never"
    case sevenDays = "7days"
    case thirtyDays = "30days"
    case ninetyDays = "90days"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .never: return "Keep Forever"
        case .sevenDays: return "7 Days"
        case .thirtyDays: return "30 Days"
        case .ninetyDays: return "90 Days"
        }
    }

    /// Number of days before data is deleted, nil for never
    var days: Int? {
        switch self {
        case .never: return nil
        case .sevenDays: return 7
        case .thirtyDays: return 30
        case .ninetyDays: return 90
        }
    }
}

// MARK: - Local Provider Type
/// Different types of local/self-hosted AI providers
enum LocalProviderType: String, Codable, CaseIterable, Identifiable {
    case ollama = "ollama"
    case lmStudio = "lm_studio"
    case openAICompatible = "openai_compatible"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ollama: return "Ollama"
        case .lmStudio: return "LM Studio"
        case .openAICompatible: return "Other OpenAI-compatible"
        }
    }

    var icon: String {
        switch self {
        case .ollama: return "terminal.fill"
        case .lmStudio: return "desktopcomputer"
        case .openAICompatible: return "server.rack"
        }
    }

    var description: String {
        switch self {
        case .ollama: return "Ollama local AI server"
        case .lmStudio: return "LM Studio OpenAI-compatible server"
        case .openAICompatible: return "Any OpenAI-compatible API server"
        }
    }

    var defaultEndpoint: String {
        switch self {
        case .ollama: return "http://localhost:11434"
        case .lmStudio: return "http://localhost:1234"
        case .openAICompatible: return "http://localhost:8080"
        }
    }

    var placeholderEndpoint: String {
        switch self {
        case .ollama: return "http://192.168.1.50:11434"
        case .lmStudio: return "http://192.168.1.60:1234"
        case .openAICompatible: return "http://your-server:port"
        }
    }

    /// API endpoints differ between Ollama native API and OpenAI-compatible APIs
    var modelsEndpoint: String {
        switch self {
        case .ollama: return "/api/tags"
        case .lmStudio, .openAICompatible: return "/v1/models"
        }
    }

    var chatEndpoint: String {
        switch self {
        case .ollama: return "/api/chat"
        case .lmStudio, .openAICompatible: return "/v1/chat/completions"
        }
    }

    var generateEndpoint: String {
        switch self {
        case .ollama: return "/api/generate"
        case .lmStudio, .openAICompatible: return "/v1/completions"
        }
    }

    /// Alias for defaultEndpoint for consistency
    var defaultURL: String {
        defaultEndpoint
    }

    /// Default model suggestion for this provider type
    var defaultModel: String {
        switch self {
        case .ollama: return "llama3.2"
        case .lmStudio: return "local-model"
        case .openAICompatible: return "gpt-3.5-turbo"
        }
    }
}

// MARK: - Local Provider Configuration
/// Configuration for local/self-hosted AI providers
struct LocalProviderConfig: Codable, Equatable {
    var type: LocalProviderType
    var baseURL: String
    var authToken: String?
    var defaultModel: String?
    var streamingEnabled: Bool
    var timeoutSeconds: Int

    init(
        type: LocalProviderType = .ollama,
        baseURL: String = "",
        authToken: String? = nil,
        defaultModel: String? = nil,
        streamingEnabled: Bool = true,
        timeoutSeconds: Int = 10
    ) {
        self.type = type
        self.baseURL = baseURL.isEmpty ? type.defaultEndpoint : baseURL
        self.authToken = authToken
        self.defaultModel = defaultModel
        self.streamingEnabled = streamingEnabled
        self.timeoutSeconds = timeoutSeconds
    }

    /// Available timeout options
    static let timeoutOptions: [Int] = [5, 10, 20, 30, 60]

    /// Whether authentication is configured
    var hasAuthentication: Bool {
        authToken?.isEmpty == false
    }
}

// MARK: - Connection Test Result
/// Result of testing connection to a local provider
struct LocalProviderConnectionResult: Equatable {
    let success: Bool
    let latencyMs: Int?
    let availableModels: [String]
    let errorMessage: String?

    static let pending = LocalProviderConnectionResult(success: false, latencyMs: nil, availableModels: [], errorMessage: nil)

    static func success(latencyMs: Int, models: [String]) -> LocalProviderConnectionResult {
        LocalProviderConnectionResult(success: true, latencyMs: latencyMs, availableModels: models, errorMessage: nil)
    }

    static func failure(_ message: String) -> LocalProviderConnectionResult {
        LocalProviderConnectionResult(success: false, latencyMs: nil, availableModels: [], errorMessage: message)
    }
}

// MARK: - Unified AI Provider
/// A unified provider enum that covers all AI providers for transcription, translation, and power modes
enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case openAI = "openai"
    case anthropic = "anthropic"
    case google = "google"
    case elevenLabs = "elevenlabs"
    case deepgram = "deepgram"
    case local = "local"  // Renamed from ollama to support multiple local provider types
    // Phase 3 additions:
    case assemblyAI = "assemblyai"
    case deepL = "deepl"
    case azure = "azure"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic Claude"
        case .google: return "Google Cloud"
        case .elevenLabs: return "ElevenLabs"
        case .deepgram: return "Deepgram"
        case .local: return "Local AI"
        case .assemblyAI: return "AssemblyAI"
        case .deepL: return "DeepL"
        case .azure: return "Azure Translator"
        }
    }

    var shortName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Claude"
        case .google: return "Google"
        case .elevenLabs: return "ElevenLabs"
        case .deepgram: return "Deepgram"
        case .local: return "Local"
        case .assemblyAI: return "AssemblyAI"
        case .deepL: return "DeepL"
        case .azure: return "Azure"
        }
    }

    var icon: String {
        switch self {
        case .openAI: return "brain"
        case .anthropic: return "sparkles"
        case .google: return "globe"
        case .elevenLabs: return "waveform"
        case .deepgram: return "mic.fill"
        case .local: return "desktopcomputer"
        case .assemblyAI: return "waveform.circle.fill"
        case .deepL: return "character.book.closed.fill"
        case .azure: return "cloud.fill"
        }
    }

    var description: String {
        switch self {
        case .openAI: return "Whisper for transcription, GPT for AI processing"
        case .anthropic: return "Advanced reasoning and safety-focused AI"
        case .google: return "STT, Translation, and Gemini for AI processing"
        case .elevenLabs: return "Speech recognition with free tier (2.5 hrs/month)"
        case .deepgram: return "Fast transcription with competitive pricing"
        case .local: return "Local AI (Ollama, LM Studio, or OpenAI-compatible)"
        case .assemblyAI: return "Fast, accurate transcription with speaker diarization"
        case .deepL: return "High-quality neural machine translation"
        case .azure: return "Microsoft Azure Translator for 100+ languages"
        }
    }

    /// Whether this provider requires an API key (cloud providers)
    var requiresAPIKey: Bool {
        self != .local
    }

    /// Whether this is a local/self-hosted provider
    var isLocalProvider: Bool {
        self == .local
    }

    // MARK: - Capability Support

    var supportsTranscription: Bool {
        switch self {
        case .openAI, .elevenLabs, .deepgram, .local, .assemblyAI, .google: return true
        case .anthropic, .deepL, .azure: return false
        }
    }

    var supportsTranslation: Bool {
        switch self {
        case .openAI, .anthropic, .google, .local, .deepL, .azure: return true
        case .elevenLabs, .deepgram, .assemblyAI: return false
        }
    }

    var supportsPowerMode: Bool {
        switch self {
        case .openAI, .anthropic, .google, .local: return true
        case .elevenLabs, .deepgram, .assemblyAI, .deepL, .azure: return false
        }
    }

    var supportedCategories: Set<ProviderUsageCategory> {
        var categories: Set<ProviderUsageCategory> = []
        if supportsTranscription { categories.insert(.transcription) }
        if supportsTranslation { categories.insert(.translation) }
        if supportsPowerMode { categories.insert(.powerMode) }
        return categories
    }

    // MARK: - STT Models (for transcription)

    /// Default STT models - for local providers, these are fetched dynamically
    var availableSTTModels: [String] {
        switch self {
        case .openAI: return ["whisper-1"]
        case .elevenLabs: return ["scribe_v1"]
        case .deepgram: return ["nova-2", "nova", "enhanced", "base"]
        case .local: return [] // Models are fetched dynamically from the local server
        case .assemblyAI: return ["default", "nano"]
        case .google: return ["long", "short", "telephony", "medical_dictation", "medical_conversation"]
        case .anthropic, .deepL, .azure: return []
        }
    }

    var defaultSTTModel: String? {
        switch self {
        case .openAI: return "whisper-1"
        case .elevenLabs: return "scribe_v1"
        case .deepgram: return "nova-2"
        case .local: return nil // Must be selected after connecting
        case .assemblyAI: return "default"
        case .google: return "long"
        case .anthropic, .deepL, .azure: return nil
        }
    }

    // MARK: - LLM Models (for translation/power mode)

    /// Default LLM models - for local providers, these are fetched dynamically
    var availableLLMModels: [String] {
        switch self {
        case .openAI: return ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-3.5-turbo"]
        case .anthropic: return ["claude-3-5-sonnet-latest", "claude-3-5-haiku-latest", "claude-3-opus-latest"]
        case .google: return ["gemini-2.0-flash-exp", "gemini-1.5-pro", "gemini-1.5-flash"]
        case .local: return [] // Models are fetched dynamically from the local server
        case .deepL: return ["default"]  // DeepL doesn't have model selection
        case .azure: return ["default"]  // Azure Translator doesn't have model selection
        case .elevenLabs, .deepgram, .assemblyAI: return []
        }
    }

    var defaultLLMModel: String? {
        switch self {
        case .openAI: return "gpt-4o-mini"
        case .anthropic: return "claude-3-5-sonnet-latest"
        case .google: return "gemini-2.0-flash-exp"
        case .local: return nil // Must be selected after connecting
        case .deepL: return "default"
        case .azure: return "default"
        case .elevenLabs, .deepgram, .assemblyAI: return nil
        }
    }

    // MARK: - API Help

    var apiKeyHelpURL: URL? {
        switch self {
        case .openAI: return URL(string: "https://platform.openai.com/api-keys")
        case .anthropic: return URL(string: "https://console.anthropic.com/settings/keys")
        case .google: return URL(string: "https://console.cloud.google.com/apis/credentials")
        case .elevenLabs: return URL(string: "https://elevenlabs.io/app/settings/api-keys")
        case .deepgram: return URL(string: "https://console.deepgram.com/project/api-keys")
        case .local: return URL(string: "https://ollama.ai") // Default to Ollama docs
        case .assemblyAI: return URL(string: "https://www.assemblyai.com/app/account")
        case .deepL: return URL(string: "https://www.deepl.com/account/summary")
        case .azure: return URL(string: "https://portal.azure.com/#view/Microsoft_Azure_ProjectOxford/CognitiveServicesHub/~/TextTranslation")
        }
    }

    var setupInstructions: String {
        switch self {
        case .openAI:
            return """
            1. Go to platform.openai.com
            2. Sign in or create an account
            3. Navigate to API Keys section
            4. Click "Create new secret key"
            5. Copy and paste the key here
            """
        case .anthropic:
            return """
            1. Go to console.anthropic.com
            2. Sign in or create an account
            3. Go to Settings → API Keys
            4. Click "Create Key"
            5. Copy and paste the key here
            """
        case .google:
            return """
            1. Go to aistudio.google.com
            2. Sign in with your Google account
            3. Click "Get API Key"
            4. Create a new API key
            5. Copy and paste the key here
            """
        case .elevenLabs:
            return """
            1. Go to elevenlabs.io
            2. Sign in or create an account
            3. Click your profile icon
            4. Go to Settings → API Keys
            5. Copy your API key
            """
        case .deepgram:
            return """
            1. Go to console.deepgram.com
            2. Sign in or create an account
            3. Create a new project
            4. Go to API Keys section
            5. Create and copy your key
            """
        case .local:
            return """
            Choose your local AI server type:

            Ollama:
            1. Install Ollama (ollama.ai)
            2. Pull models: ollama pull llama3.2
            3. Server runs on http://localhost:11434

            LM Studio:
            1. Download LM Studio
            2. Download a model from the app
            3. Start the local server
            4. Server runs on http://localhost:1234

            Other OpenAI-compatible:
            Enter your server's URL and optional API token.
            """
        case .assemblyAI:
            return """
            1. Go to assemblyai.com
            2. Sign in or create an account
            3. Go to Account settings
            4. Copy your API key
            5. Paste the key here
            """
        case .deepL:
            return """
            1. Go to deepl.com/pro
            2. Sign in or create an account
            3. Go to Account summary
            4. Scroll to "API Keys" section
            5. Create and copy your key
            """
        case .azure:
            return """
            1. Go to portal.azure.com
            2. Create a Translator resource
            3. Go to Keys and Endpoint
            4. Copy Key 1 or Key 2
            5. Note the region (e.g., eastus)
            """
        }
    }

    var costPerMinute: Double {
        switch self {
        case .openAI: return 0.006
        case .elevenLabs: return 0.0
        case .deepgram: return 0.0043
        case .assemblyAI: return 0.00025  // $0.00025/second = $0.015/minute (universal model)
        case .anthropic, .google, .local, .deepL, .azure: return 0.0  // Per-character pricing doesn't translate to per-minute
        }
    }

    /// Whether this provider requires Power subscription tier
    var requiresPowerTier: Bool {
        switch self {
        case .local: return true
        case .openAI, .anthropic, .google, .elevenLabs, .deepgram, .assemblyAI, .deepL, .azure: return false
        }
    }

    /// Minimum subscription tier required for this provider
    var minimumTier: SubscriptionTier {
        requiresPowerTier ? .power : .free
    }
}

// MARK: - Azure Region
/// Azure Translator regions for configuration
enum AzureRegion: String, Codable, CaseIterable, Identifiable {
    case eastUS = "eastus"
    case eastUS2 = "eastus2"
    case westUS = "westus"
    case westUS2 = "westus2"
    case centralUS = "centralus"
    case northCentralUS = "northcentralus"
    case southCentralUS = "southcentralus"
    case westEurope = "westeurope"
    case northEurope = "northeurope"
    case southeastAsia = "southeastasia"
    case eastAsia = "eastasia"
    case australiaEast = "australiaeast"
    case brazilSouth = "brazilsouth"
    case canadaCentral = "canadacentral"
    case japanEast = "japaneast"
    case koreacentral = "koreacentral"
    case uksouth = "uksouth"
    case global = "global"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .eastUS: return "East US"
        case .eastUS2: return "East US 2"
        case .westUS: return "West US"
        case .westUS2: return "West US 2"
        case .centralUS: return "Central US"
        case .northCentralUS: return "North Central US"
        case .southCentralUS: return "South Central US"
        case .westEurope: return "West Europe"
        case .northEurope: return "North Europe"
        case .southeastAsia: return "Southeast Asia"
        case .eastAsia: return "East Asia"
        case .australiaEast: return "Australia East"
        case .brazilSouth: return "Brazil South"
        case .canadaCentral: return "Canada Central"
        case .japanEast: return "Japan East"
        case .koreacentral: return "Korea Central"
        case .uksouth: return "UK South"
        case .global: return "Global"
        }
    }
}

// MARK: - Unified AI Provider Configuration
struct AIProviderConfig: Codable, Identifiable, Equatable {
    var id: String { provider.rawValue }
    var provider: AIProvider
    var apiKey: String
    var endpoint: String?       // Legacy - kept for backward compatibility
    var usageCategories: Set<ProviderUsageCategory>

    // Model per capability - allows different models for each use case
    var transcriptionModel: String?    // STT model (e.g., whisper-1)
    var translationModel: String?      // LLM model for translation (e.g., gpt-4o-mini)
    var powerModeModel: String?        // LLM model for power mode (e.g., gpt-4o)

    // Local provider configuration (only used when provider == .local)
    var localConfig: LocalProviderConfig?

    // Cached models from last successful connection test (for local providers)
    var cachedModels: [String]?

    // Provider-specific configuration
    var azureRegion: String?           // Required for Azure Translator (e.g., "eastus", "westeurope")
    var googleProjectId: String?       // Required for Google Cloud STT

    init(
        provider: AIProvider,
        apiKey: String = "",
        endpoint: String? = nil,
        usageCategories: Set<ProviderUsageCategory>? = nil,
        transcriptionModel: String? = nil,
        translationModel: String? = nil,
        powerModeModel: String? = nil,
        localConfig: LocalProviderConfig? = nil,
        cachedModels: [String]? = nil,
        azureRegion: String? = nil,
        googleProjectId: String? = nil
    ) {
        self.provider = provider
        self.apiKey = apiKey
        self.endpoint = endpoint
        // Default to all supported categories
        self.usageCategories = usageCategories ?? provider.supportedCategories
        // Default models per capability
        self.transcriptionModel = transcriptionModel ?? provider.defaultSTTModel
        self.translationModel = translationModel ?? provider.defaultLLMModel
        self.powerModeModel = powerModeModel ?? provider.defaultLLMModel
        // Local config - create default if this is a local provider
        if provider.isLocalProvider {
            self.localConfig = localConfig ?? LocalProviderConfig()
        } else {
            self.localConfig = localConfig
        }
        self.cachedModels = cachedModels
        self.azureRegion = azureRegion
        self.googleProjectId = googleProjectId
    }

    /// Get the effective base URL for local providers
    var effectiveBaseURL: String? {
        if provider.isLocalProvider {
            return localConfig?.baseURL ?? endpoint
        }
        return nil
    }

    /// Get the effective auth token for local providers
    var effectiveAuthToken: String? {
        if provider.isLocalProvider {
            return localConfig?.authToken
        }
        return nil
    }

    /// Check if this local provider is configured
    var isLocalProviderConfigured: Bool {
        guard provider.isLocalProvider else { return true }
        guard let localConfig = localConfig else { return false }
        return !localConfig.baseURL.isEmpty
    }

    var isConfiguredForTranscription: Bool {
        usageCategories.contains(.transcription) && provider.supportsTranscription
    }

    var isConfiguredForTranslation: Bool {
        usageCategories.contains(.translation) && provider.supportsTranslation
    }

    var isConfiguredForPowerMode: Bool {
        usageCategories.contains(.powerMode) && provider.supportsPowerMode
    }

    /// Get the model for a specific category
    func model(for category: ProviderUsageCategory) -> String? {
        switch category {
        case .transcription: return transcriptionModel
        case .translation: return translationModel
        case .powerMode: return powerModeModel
        }
    }

    /// Get available models for a specific category
    /// For local providers, uses cached models if available
    func availableModels(for category: ProviderUsageCategory) -> [String] {
        // For local providers, use cached models if available
        if provider.isLocalProvider, let cached = cachedModels, !cached.isEmpty {
            switch category {
            case .transcription:
                // Filter whisper models for STT
                let whisperModels = cached.filter { $0.lowercased().contains("whisper") }
                return whisperModels.isEmpty ? cached : whisperModels
            case .translation, .powerMode:
                // Filter out whisper models for LLM
                let llmModels = cached.filter { !$0.lowercased().contains("whisper") }
                return llmModels.isEmpty ? cached : llmModels
            }
        }

        // Default models from provider
        switch category {
        case .transcription: return provider.availableSTTModels
        case .translation, .powerMode: return provider.availableLLMModels
        }
    }

    /// Display name showing selected model(s) grouped by unique models
    var modelSummary: String {
        var models: [String] = []
        if let model = transcriptionModel, isConfiguredForTranscription {
            models.append(model)
        }
        if let model = translationModel, isConfiguredForTranslation, !models.contains(model) {
            models.append(model)
        }
        if let model = powerModeModel, isConfiguredForPowerMode, !models.contains(model) {
            models.append(model)
        }
        return models.isEmpty ? "Not configured" : models.joined(separator: ", ")
    }

    /// Detailed summary showing which model is used for what
    var detailedModelSummary: [(ProviderUsageCategory, String)] {
        var result: [(ProviderUsageCategory, String)] = []
        if let model = transcriptionModel, isConfiguredForTranscription {
            result.append((.transcription, model))
        }
        if let model = translationModel, isConfiguredForTranslation {
            result.append((.translation, model))
        }
        if let model = powerModeModel, isConfiguredForPowerMode {
            result.append((.powerMode, model))
        }
        return result
    }
}

// MARK: - Provider Usage Category
enum ProviderUsageCategory: String, Codable, CaseIterable, Identifiable {
    case transcription = "transcription"
    case translation = "translation"
    case powerMode = "power_mode"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .transcription: return "Transcription"
        case .translation: return "Translation"
        case .powerMode: return "Power Mode"
        }
    }

    var icon: String {
        switch self {
        case .transcription: return "waveform"
        case .translation: return "globe"
        case .powerMode: return "bolt.fill"
        }
    }

    var description: String {
        switch self {
        case .transcription: return "Speech-to-text processing"
        case .translation: return "Text translation between languages"
        case .powerMode: return "AI-powered voice workflows"
        }
    }
}

// MARK: - Formatting Mode
enum FormattingMode: String, Codable, CaseIterable, Identifiable {
    case raw = "raw"
    case email = "email"
    case formal = "formal"
    case casual = "casual"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .raw: return "Raw"
        case .email: return "Email"
        case .formal: return "Formal"
        case .casual: return "Casual"
        }
    }

    var icon: String {
        switch self {
        case .raw: return "text.alignleft"
        case .email: return "envelope.fill"
        case .formal: return "briefcase.fill"
        case .casual: return "face.smiling.fill"
        }
    }

    var prompt: String {
        switch self {
        case .raw:
            return ""
        case .email:
            return """
            Format this dictated text as a professional email.
            Add appropriate greeting and sign-off.
            Fix grammar and punctuation. Keep the original meaning.
            """
        case .formal:
            return """
            Rewrite this text in a formal, professional tone.
            Use proper business language. Fix any grammatical errors.
            """
        case .casual:
            return """
            Clean up this text while keeping a casual, friendly tone.
            Fix grammar but maintain conversational style.
            """
        }
    }
}

// MARK: - Language
enum Language: String, Codable, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case arabic = "ar"
    case egyptianArabic = "arz"
    case russian = "ru"
    case polish = "pl"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .chinese: return "Chinese"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .arabic: return "Arabic"
        case .egyptianArabic: return "Egyptian Arabic"
        case .russian: return "Russian"
        case .polish: return "Polish"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .italian: return "🇮🇹"
        case .portuguese: return "🇵🇹"
        case .chinese: return "🇨🇳"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .arabic: return "🇸🇦"
        case .egyptianArabic: return "🇪🇬"
        case .russian: return "🇷🇺"
        case .polish: return "🇵🇱"
        }
    }

    // MARK: - Provider-specific language codes

    /// DeepL uses uppercase language codes
    var deepLCode: String {
        switch self {
        case .english: return "EN"
        case .spanish: return "ES"
        case .french: return "FR"
        case .german: return "DE"
        case .italian: return "IT"
        case .portuguese: return "PT"
        case .chinese: return "ZH"
        case .japanese: return "JA"
        case .korean: return "KO"
        case .arabic: return "AR"
        case .egyptianArabic: return "AR"  // DeepL doesn't distinguish Egyptian Arabic
        case .russian: return "RU"
        case .polish: return "PL"
        }
    }

    /// Google Cloud uses lowercase ISO codes
    var googleCode: String {
        switch self {
        case .english: return "en"
        case .spanish: return "es"
        case .french: return "fr"
        case .german: return "de"
        case .italian: return "it"
        case .portuguese: return "pt"
        case .chinese: return "zh"
        case .japanese: return "ja"
        case .korean: return "ko"
        case .arabic: return "ar"
        case .egyptianArabic: return "ar"  // Use standard Arabic for Google
        case .russian: return "ru"
        case .polish: return "pl"
        }
    }

    /// Azure Translator uses lowercase ISO codes (same as Google)
    var azureCode: String {
        googleCode
    }

    /// AssemblyAI language codes - returns nil for unsupported languages
    /// AssemblyAI supports: en, es, fr, de, it, pt, nl, hi, ja, zh, fi, ko, pl, ru, tr, uk, vi
    var assemblyAICode: String? {
        switch self {
        case .english: return "en"
        case .spanish: return "es"
        case .french: return "fr"
        case .german: return "de"
        case .italian: return "it"
        case .portuguese: return "pt"
        case .chinese: return "zh"
        case .japanese: return "ja"
        case .korean: return "ko"
        case .russian: return "ru"
        case .polish: return "pl"
        case .arabic, .egyptianArabic: return nil  // Not supported by AssemblyAI
        }
    }

    /// Google Cloud Speech-to-Text uses BCP-47 codes
    var googleSTTCode: String {
        switch self {
        case .english: return "en-US"
        case .spanish: return "es-ES"
        case .french: return "fr-FR"
        case .german: return "de-DE"
        case .italian: return "it-IT"
        case .portuguese: return "pt-BR"
        case .chinese: return "zh-CN"
        case .japanese: return "ja-JP"
        case .korean: return "ko-KR"
        case .arabic: return "ar-SA"
        case .egyptianArabic: return "ar-EG"
        case .russian: return "ru-RU"
        case .polish: return "pl-PL"
        }
    }
}

// MARK: - Cost Breakdown (Phase 9)

/// Breakdown of costs for a transcription operation
struct CostBreakdown: Codable, Equatable {
    let transcriptionCost: Double
    let formattingCost: Double
    let translationCost: Double?

    // Token counts (if available from LLM responses)
    let inputTokens: Int?
    let outputTokens: Int?

    /// Total cost of the operation
    var total: Double {
        transcriptionCost + formattingCost + (translationCost ?? 0)
    }

    /// Check if this breakdown has any costs
    var hasCosts: Bool {
        total > 0
    }

    /// Create a zero-cost breakdown
    static var zero: CostBreakdown {
        CostBreakdown(
            transcriptionCost: 0,
            formattingCost: 0,
            translationCost: nil,
            inputTokens: nil,
            outputTokens: nil
        )
    }
}

// MARK: - Double Extensions for Cost Formatting

extension Double {
    /// Format cost with appropriate precision
    var formattedCost: String {
        if self == 0 {
            return "Free"
        } else if self < 0.0001 {
            return "<$0.0001"
        } else if self < 0.01 {
            return String(format: "$%.4f", self)
        } else if self < 1 {
            return String(format: "$%.3f", self)
        } else {
            return String(format: "$%.2f", self)
        }
    }

    /// Compact cost format for badges (e.g., "3c" or "$1.50")
    var formattedCostCompact: String {
        if self == 0 {
            return "Free"
        } else if self < 0.001 {
            return "<0.1c"
        } else if self < 0.01 {
            return String(format: "%.1fc", self * 100)
        } else if self < 1 {
            return String(format: "%.0fc", self * 100)
        } else {
            return String(format: "$%.2f", self)
        }
    }
}

// MARK: - Transcription Record
struct TranscriptionRecord: Codable, Identifiable {
    let id: UUID
    let text: String
    let mode: FormattingMode
    let provider: AIProvider
    let timestamp: Date
    let duration: TimeInterval
    let translated: Bool
    let targetLanguage: Language?

    // Power Mode and Context tracking (Phase 4)
    let powerModeId: UUID?       // nil for regular transcriptions
    let powerModeName: String?   // Cached name for display even if mode deleted
    let contextId: UUID?         // nil if no context was active
    let contextName: String?     // Cached name for display even if context deleted
    let contextIcon: String?     // Cached icon for display

    // Cost tracking (Phase 9)
    let estimatedCost: Double?   // Total estimated cost for this transcription
    let costBreakdown: CostBreakdown?  // Detailed cost breakdown by operation type

    init(
        id: UUID = UUID(),
        text: String,
        mode: FormattingMode,
        provider: AIProvider,
        timestamp: Date = Date(),
        duration: TimeInterval,
        translated: Bool = false,
        targetLanguage: Language? = nil,
        powerModeId: UUID? = nil,
        powerModeName: String? = nil,
        contextId: UUID? = nil,
        contextName: String? = nil,
        contextIcon: String? = nil,
        estimatedCost: Double? = nil,
        costBreakdown: CostBreakdown? = nil
    ) {
        self.id = id
        self.text = text
        self.mode = mode
        self.provider = provider
        self.timestamp = timestamp
        self.duration = duration
        self.translated = translated
        self.targetLanguage = targetLanguage
        self.powerModeId = powerModeId
        self.powerModeName = powerModeName
        self.contextId = contextId
        self.contextName = contextName
        self.contextIcon = contextIcon
        self.estimatedCost = estimatedCost
        self.costBreakdown = costBreakdown
    }
}

// MARK: - Recording State
enum RecordingState: Equatable {
    case idle
    case recording
    case processing
    case formatting
    case translating
    case complete(String)
    case error(String)

    var statusText: String {
        switch self {
        case .idle: return "Tap to record"
        case .recording: return "Listening..."
        case .processing: return "Transcribing..."
        case .formatting: return "Formatting..."
        case .translating: return "Translating..."
        case .complete: return "Done!"
        case .error(let message): return message
        }
    }
}

// MARK: - Custom Template (LEGACY - No UI, kept for data compatibility)
// NOTE: CustomTemplate is legacy code kept for backwards compatibility with existing user data.
// New features should use Power Modes instead. Do not add new functionality to this type.
struct CustomTemplate: Codable, Identifiable {
    let id: UUID
    var name: String
    var prompt: String
    var icon: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        prompt: String,
        icon: String = "doc.text",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.icon = icon
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Vocabulary Entry
struct VocabularyEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var recognizedWord: String      // What the STT might produce (e.g., "john doe")
    var replacementWord: String     // What to replace it with (e.g., "John Doe")
    var category: VocabularyCategory
    var isEnabled: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        recognizedWord: String,
        replacementWord: String,
        category: VocabularyCategory = .name,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.recognizedWord = recognizedWord.lowercased()
        self.replacementWord = replacementWord
        self.category = category
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Sample entries for preview
    static let samples: [VocabularyEntry] = [
        VocabularyEntry(recognizedWord: "john doe", replacementWord: "John Doe", category: .name),
        VocabularyEntry(recognizedWord: "acme corp", replacementWord: "ACME Corp.", category: .company),
        VocabularyEntry(recognizedWord: "asap", replacementWord: "ASAP", category: .acronym),
        VocabularyEntry(recognizedWord: "gonna", replacementWord: "going to", category: .slang)
    ]
}

// MARK: - Vocabulary Category
enum VocabularyCategory: String, Codable, CaseIterable, Identifiable {
    case name = "name"
    case company = "company"
    case acronym = "acronym"
    case slang = "slang"
    case technical = "technical"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .name: return "Name"
        case .company: return "Company"
        case .acronym: return "Acronym"
        case .slang: return "Slang"
        case .technical: return "Technical"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .name: return "person.fill"
        case .company: return "building.2.fill"
        case .acronym: return "textformat.abc"
        case .slang: return "bubble.left.fill"
        case .technical: return "wrench.fill"
        case .other: return "tag.fill"
        }
    }

    var color: Color {
        switch self {
        case .name: return .blue
        case .company: return .purple
        case .acronym: return .orange
        case .slang: return .pink
        case .technical: return .green
        case .other: return .gray
        }
    }
}

// MARK: - Power Mode Capability (REMOVED)
// Old capabilities (webSearch, bashComputerUse, codeExecution) removed in Phase 4.
// Replaced by:
// - RAG (Retrieval-Augmented Generation) for document-based knowledge
// - Webhooks for external integrations
// - Streaming for real-time responses

// MARK: - Context Formality (Phase 4)

/// Explicit formality setting for translation providers
/// When set to .auto, formality is inferred from tone description
enum ContextFormality: String, Codable, CaseIterable, Identifiable {
    case auto = "auto"          // Infer from tone description
    case formal = "formal"      // Professional, respectful, business tone
    case informal = "informal"  // Casual, friendly, conversational
    case neutral = "neutral"    // No preference (provider default)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .formal: return "Formal"
        case .informal: return "Informal"
        case .neutral: return "Neutral"
        }
    }

    var description: String {
        switch self {
        case .auto: return "Automatically inferred from your tone description"
        case .formal: return "Professional and respectful language"
        case .informal: return "Casual and friendly language"
        case .neutral: return "Standard language, no preference"
        }
    }

    var icon: String {
        switch self {
        case .auto: return "sparkles"
        case .formal: return "briefcase.fill"
        case .informal: return "face.smiling.fill"
        case .neutral: return "equal.circle.fill"
        }
    }
}

// MARK: - Conversation Context (Phase 4)

/// A named context that customizes tone, language, and behavior
struct ConversationContext: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String                    // "Fatma", "Work", "Family"
    var icon: String                    // Emoji or SF Symbol
    var color: PowerModeColorPreset
    var description: String             // Short description for list view
    var toneDescription: String         // Detailed tone guidance for AI
    var formality: ContextFormality     // Explicit formality for translation (esp. DeepL)
    var languageHints: [Language]       // Expected languages in this context
    var customInstructions: String      // Injected into all prompts
    var memoryEnabled: Bool             // Context-level memory toggle
    var memory: String?                 // Stored memory for this context
    var lastMemoryUpdate: Date?
    var isActive: Bool                  // Currently selected context
    var appAssignment: AppAssignment    // Apps/categories that auto-enable this context
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        color: PowerModeColorPreset,
        description: String,
        toneDescription: String = "",
        formality: ContextFormality = .auto,
        languageHints: [Language] = [],
        customInstructions: String = "",
        memoryEnabled: Bool = false,
        memory: String? = nil,
        lastMemoryUpdate: Date? = nil,
        isActive: Bool = false,
        appAssignment: AppAssignment = AppAssignment(),
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.description = description
        self.toneDescription = toneDescription
        self.formality = formality
        self.languageHints = languageHints
        self.customInstructions = customInstructions
        self.memoryEnabled = memoryEnabled
        self.memory = memory
        self.lastMemoryUpdate = lastMemoryUpdate
        self.isActive = isActive
        self.appAssignment = appAssignment
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static var empty: ConversationContext {
        ConversationContext(
            name: "",
            icon: "person.circle",
            color: PowerModeColorPreset.blue,
            description: ""
        )
    }

    /// Sample contexts for previews and mock-ups
    static var samples: [ConversationContext] {
        [
            ConversationContext(
                name: "Fatma",
                icon: "💕",
                color: PowerModeColorPreset.pink,
                description: "Casual, loving conversation with my wife",
                toneDescription: "Casual and loving. We often joke around and use pet names. She speaks Polish primarily but we mix in English words sometimes. Keep translations warm and natural.",
                formality: ContextFormality.informal,  // Explicitly informal for DeepL
                languageHints: [Language.polish, Language.english],
                customInstructions: "When translating to Polish, use informal \"ty\" form. Add endearments where appropriate.",
                memoryEnabled: true,
                memory: "Fatma mentioned she has a meeting on Tuesday afternoon. We're planning dinner for Friday. She prefers Italian food lately.",
                lastMemoryUpdate: Date().addingTimeInterval(-3600),
                isActive: true
            ),
            ConversationContext(
                name: "Work",
                icon: "💼",
                color: PowerModeColorPreset.blue,
                description: "Professional, formal business communication",
                toneDescription: "Professional and formal. Use proper business language and avoid casual expressions.",
                formality: ContextFormality.formal,  // Explicitly formal for DeepL
                languageHints: [Language.english],
                customInstructions: "Maintain professional tone. Use formal salutations and sign-offs in emails.",
                memoryEnabled: true,
                memory: "Last email was to client about project delay.",
                lastMemoryUpdate: Date().addingTimeInterval(-86400)
            ),
            ConversationContext(
                name: "Family",
                icon: "👨‍👩‍👧",
                color: PowerModeColorPreset.green,
                description: "Warm, friendly family conversations",
                toneDescription: "Warm and friendly. Family talks are casual but respectful.",
                formality: ContextFormality.auto,  // Auto-infer from tone description
                languageHints: [Language.polish],
                customInstructions: "Use familiar Polish expressions common in family settings."
            )
        ]
    }
}

// MARK: - History Memory (Phase 4)

/// Global memory that stores user preferences and recent conversation summaries
struct HistoryMemory: Codable, Equatable {
    var summary: String
    var lastUpdated: Date
    var conversationCount: Int
    var recentTopics: [String]  // Last 5 topics for quick context

    init(
        summary: String = "",
        lastUpdated: Date = Date(),
        conversationCount: Int = 0,
        recentTopics: [String] = []
    ) {
        self.summary = summary
        self.lastUpdated = lastUpdated
        self.conversationCount = conversationCount
        self.recentTopics = recentTopics
    }

    /// Sample history memory for previews
    static var sample: HistoryMemory {
        HistoryMemory(
            summary: "User prefers formal English for work, casual Polish for family. Often discusses Swift programming and AI topics. Prefers concise responses.",
            lastUpdated: Date().addingTimeInterval(-7200),
            conversationCount: 47,
            recentTopics: ["Swift development", "AI news", "Family planning", "Work emails", "Polish translations"]
        )
    }
}

// MARK: - Knowledge Document (Phase 4 RAG)

/// Document types for the knowledge base
enum KnowledgeDocumentType: String, Codable {
    case localFile = "local"      // PDF, TXT, MD uploaded
    case remoteURL = "remote"     // Web page fetched

    // File format types (used by DocumentParser)
    case pdf = "pdf"
    case text = "text"
    case markdown = "markdown"
}

/// Auto-update interval for remote documents
enum UpdateInterval: String, Codable, CaseIterable {
    case never = "never"
    case daily = "daily"
    case weekly = "weekly"
    case always = "always"        // Check before each query

    var displayName: String {
        switch self {
        case .never: return "Never"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .always: return "Always"
        }
    }
}

/// A document in the knowledge base for RAG
struct KnowledgeDocument: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var type: KnowledgeDocumentType
    var sourceURL: URL?           // For remote documents
    var localPath: String?        // For uploaded files
    var contentHash: String       // For update detection
    var chunkCount: Int
    var fileSizeBytes: Int
    var isIndexed: Bool
    var lastUpdated: Date
    var autoUpdateInterval: UpdateInterval?
    var lastChecked: Date?

    init(
        id: UUID = UUID(),
        name: String,
        type: KnowledgeDocumentType,
        sourceURL: URL? = nil,
        localPath: String? = nil,
        contentHash: String = "",
        chunkCount: Int = 0,
        fileSizeBytes: Int = 0,
        isIndexed: Bool = false,
        lastUpdated: Date = Date(),
        autoUpdateInterval: UpdateInterval? = nil,
        lastChecked: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.sourceURL = sourceURL
        self.localPath = localPath
        self.contentHash = contentHash
        self.chunkCount = chunkCount
        self.fileSizeBytes = fileSizeBytes
        self.isIndexed = isIndexed
        self.lastUpdated = lastUpdated
        self.autoUpdateInterval = autoUpdateInterval
        self.lastChecked = lastChecked
    }

    var fileSizeFormatted: String {
        let bytes = Double(fileSizeBytes)
        if bytes < 1024 {
            return "\(fileSizeBytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        }
    }

    /// Sample documents for previews
    static var samples: [KnowledgeDocument] {
        [
            KnowledgeDocument(
                name: "API Documentation.pdf",
                type: .localFile,
                localPath: "/documents/api_docs.pdf",
                chunkCount: 156,
                fileSizeBytes: 2_400_000,
                isIndexed: true,
                lastUpdated: Date().addingTimeInterval(-86400)
            ),
            KnowledgeDocument(
                name: "Project Wiki",
                type: .remoteURL,
                sourceURL: URL(string: "https://wiki.example.com/project"),
                chunkCount: 89,
                fileSizeBytes: 450_000,
                isIndexed: true,
                lastUpdated: Date().addingTimeInterval(-172800),
                autoUpdateInterval: .weekly,
                lastChecked: Date().addingTimeInterval(-172800)
            ),
            KnowledgeDocument(
                name: "Style Guide.md",
                type: .localFile,
                localPath: "/documents/style_guide.md",
                chunkCount: 12,
                fileSizeBytes: 45_000,
                isIndexed: true,
                lastUpdated: Date().addingTimeInterval(-604800)
            )
        ]
    }
}

// MARK: - Webhook (Phase 4)

/// Webhook types for different execution points
enum WebhookType: String, Codable, CaseIterable {
    case contextSource = "context"     // GET before processing
    case outputDestination = "output"  // POST after completion
    case automationTrigger = "trigger" // POST for Make/Zapier

    var displayName: String {
        switch self {
        case .contextSource: return "Context Source"
        case .outputDestination: return "Output Destination"
        case .automationTrigger: return "Automation Trigger"
        }
    }

    var description: String {
        switch self {
        case .contextSource: return "Fetch data before processing"
        case .outputDestination: return "Send results after completion"
        case .automationTrigger: return "Trigger external automation"
        }
    }
}

/// Authentication types for webhooks
enum WebhookAuthType: String, Codable, CaseIterable {
    case none = "none"
    case bearerToken = "bearer"
    case apiKeyHeader = "api_key"
    case basicAuth = "basic"

    var displayName: String {
        switch self {
        case .none: return "None"
        case .bearerToken: return "Bearer Token"
        case .apiKeyHeader: return "API Key"
        case .basicAuth: return "Basic Auth"
        }
    }
}

/// Webhook template for common services
enum WebhookTemplate: String, Codable, CaseIterable {
    case slack = "slack"
    case notion = "notion"
    case todoist = "todoist"
    case make = "make"
    case zapier = "zapier"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .slack: return "Slack"
        case .notion: return "Notion"
        case .todoist: return "Todoist"
        case .make: return "Make"
        case .zapier: return "Zapier"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .slack: return "bubble.left.fill"
        case .notion: return "doc.text.fill"
        case .todoist: return "checkmark.circle.fill"
        case .make: return "bolt.fill"
        case .zapier: return "link"
        case .custom: return "gearshape.fill"
        }
    }
}

/// A webhook configuration
struct Webhook: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var type: WebhookType
    var template: WebhookTemplate
    var url: URL
    var isEnabled: Bool

    // Authentication
    var authType: WebhookAuthType
    var authToken: String?
    var authHeader: String?

    // Payload configuration (for POST)
    var includeInput: Bool
    var includeOutput: Bool
    var includeModeName: Bool
    var includeContext: Bool
    var includeTimestamp: Bool

    // Status
    var lastTriggered: Date?
    var lastStatus: String?

    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        type: WebhookType,
        template: WebhookTemplate = .custom,
        url: URL,
        isEnabled: Bool = true,
        authType: WebhookAuthType = .none,
        authToken: String? = nil,
        authHeader: String? = nil,
        includeInput: Bool = true,
        includeOutput: Bool = true,
        includeModeName: Bool = true,
        includeContext: Bool = true,
        includeTimestamp: Bool = true,
        lastTriggered: Date? = nil,
        lastStatus: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.template = template
        self.url = url
        self.isEnabled = isEnabled
        self.authType = authType
        self.authToken = authToken
        self.authHeader = authHeader
        self.includeInput = includeInput
        self.includeOutput = includeOutput
        self.includeModeName = includeModeName
        self.includeContext = includeContext
        self.includeTimestamp = includeTimestamp
        self.lastTriggered = lastTriggered
        self.lastStatus = lastStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Sample webhooks for previews
    static var samples: [Webhook] {
        [
            Webhook(
                name: "Calendar Events",
                type: .contextSource,
                template: .custom,
                url: URL(string: "https://api.calendar.com/today")!,
                authType: .bearerToken,
                authToken: "cal_xxxx",
                lastTriggered: Date().addingTimeInterval(-7200),
                lastStatus: "success"
            ),
            Webhook(
                name: "Slack Channel",
                type: .outputDestination,
                template: .slack,
                url: URL(string: "https://hooks.slack.com/services/xxx")!,
                lastTriggered: Date().addingTimeInterval(-86400),
                lastStatus: "success"
            ),
            Webhook(
                name: "Notion Database",
                type: .outputDestination,
                template: .notion,
                url: URL(string: "https://api.notion.com/v1/pages")!,
                isEnabled: false,
                authType: .bearerToken,
                authToken: "secret_xxx"
            ),
            Webhook(
                name: "Make.com Scenario",
                type: .automationTrigger,
                template: .make,
                url: URL(string: "https://hook.make.com/xxx")!,
                lastTriggered: Date().addingTimeInterval(-259200),
                lastStatus: "success"
            )
        ]
    }
}

// MARK: - Power Mode Color Preset
enum PowerModeColorPreset: String, Codable, CaseIterable, Identifiable {
    case orange = "orange"
    case blue = "blue"
    case purple = "purple"
    case pink = "pink"
    case green = "green"
    case red = "red"
    case teal = "teal"
    case indigo = "indigo"
    case yellow = "yellow"
    case mint = "mint"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .orange: return .orange
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .green: return .green
        case .red: return .red
        case .teal: return .teal
        case .indigo: return .indigo
        case .yellow: return .yellow
        case .mint: return .mint
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .orange: return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .blue: return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .purple: return LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .pink: return LinearGradient(colors: [.pink, .red.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .green: return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .red: return LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .teal: return LinearGradient(colors: [.teal, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .indigo: return LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .yellow: return LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .mint: return LinearGradient(colors: [.mint, .green], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - RAG Configuration
/// User-configurable settings for RAG (per Power Mode)
struct RAGConfiguration: Codable, Equatable, Hashable, Sendable {
    /// Chunking strategy for splitting documents
    var chunkingStrategy: RAGChunkingStrategy

    /// Target chunk size in tokens
    var maxChunkTokens: Int

    /// Overlap between chunks in tokens
    var overlapTokens: Int

    /// Number of top chunks to include in context
    var maxContextChunks: Int

    /// Minimum similarity score (0.0 - 1.0) for chunk retrieval
    var similarityThreshold: Float

    /// Embedding model to use
    var embeddingModel: RAGEmbeddingModel

    static var `default`: RAGConfiguration {
        RAGConfiguration(
            chunkingStrategy: .semantic,
            maxChunkTokens: 500,
            overlapTokens: 50,
            maxContextChunks: 5,
            similarityThreshold: 0.7,
            embeddingModel: .openAISmall
        )
    }
}

/// Chunking strategy options
enum RAGChunkingStrategy: String, Codable, CaseIterable, Hashable, Sendable {
    case semantic     // Split by paragraphs/sections
    case fixedSize    // Split by token count
    case sentence     // Split by sentences

    var displayName: String {
        switch self {
        case .semantic: return "Semantic"
        case .fixedSize: return "Fixed Size"
        case .sentence: return "Sentence"
        }
    }

    var description: String {
        switch self {
        case .semantic:
            return "Split by paragraphs and sections (recommended)"
        case .fixedSize:
            return "Split into fixed-size chunks"
        case .sentence:
            return "Split by individual sentences"
        }
    }
}

/// Embedding model options
enum RAGEmbeddingModel: String, Codable, CaseIterable, Hashable, Sendable {
    case openAISmall = "text-embedding-3-small"
    case openAILarge = "text-embedding-3-large"

    var displayName: String {
        switch self {
        case .openAISmall: return "OpenAI Small (Recommended)"
        case .openAILarge: return "OpenAI Large (Higher Quality)"
        }
    }

    var dimensions: Int {
        switch self {
        case .openAISmall: return 1536
        case .openAILarge: return 3072
        }
    }

    var costPer1MTokens: Double {
        switch self {
        case .openAISmall: return 0.02
        case .openAILarge: return 0.13
        }
    }
}

// MARK: - Power Mode
struct PowerMode: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var iconColor: PowerModeColorPreset
    var iconBackgroundColor: PowerModeColorPreset
    var instruction: String
    var outputFormat: String
    let createdAt: Date
    var updatedAt: Date
    var usageCount: Int

    // Phase 4: Memory support
    var memoryEnabled: Bool
    var memory: String?
    var lastMemoryUpdate: Date?

    // Phase 4: Knowledge base document IDs (RAG)
    var knowledgeDocumentIds: [UUID]

    // Phase 4e: RAG configuration (per Power Mode)
    var ragConfiguration: RAGConfiguration

    // Phase 4: Archive support for swipe actions
    var isArchived: Bool

    // App auto-enable assignment
    var appAssignment: AppAssignment    // Apps/categories that auto-enable this power mode

    // Phase 4f: Enabled webhook IDs (global webhooks enabled for this Power Mode)
    var enabledWebhookIds: [UUID]

    // Phase 10: Provider override (nil = use global default)
    var providerOverride: ProviderSelection?

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "bolt.fill",
        iconColor: PowerModeColorPreset = .orange,
        iconBackgroundColor: PowerModeColorPreset = .orange,
        instruction: String = "",
        outputFormat: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        usageCount: Int = 0,
        memoryEnabled: Bool = false,
        memory: String? = nil,
        lastMemoryUpdate: Date? = nil,
        knowledgeDocumentIds: [UUID] = [],
        ragConfiguration: RAGConfiguration = .default,
        isArchived: Bool = false,
        appAssignment: AppAssignment = AppAssignment(),
        enabledWebhookIds: [UUID] = [],
        providerOverride: ProviderSelection? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.iconColor = iconColor
        self.iconBackgroundColor = iconBackgroundColor
        self.instruction = instruction
        self.outputFormat = outputFormat
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.usageCount = usageCount
        self.memoryEnabled = memoryEnabled
        self.memory = memory
        self.lastMemoryUpdate = lastMemoryUpdate
        self.knowledgeDocumentIds = knowledgeDocumentIds
        self.ragConfiguration = ragConfiguration
        self.isArchived = isArchived
        self.appAssignment = appAssignment
        self.enabledWebhookIds = enabledWebhookIds
        self.providerOverride = providerOverride
    }

    /// Preset power modes for new users
    static let presets: [PowerMode] = [
        PowerMode(
            name: "Research Assistant",
            icon: "magnifyingglass.circle.fill",
            iconColor: .blue,
            iconBackgroundColor: .blue,
            instruction: """
            You are a research assistant. Help me find accurate, up-to-date information on the topic I describe.
            Cite sources when possible. Be thorough but concise.
            Focus on factual accuracy, recent developments, and multiple perspectives.
            """,
            outputFormat: "Use headers (##) for main topics. Include bullet points for key findings. Add a \"Sources\" section at the end."
        ),
        PowerMode(
            name: "Email Composer",
            icon: "envelope.fill",
            iconColor: .purple,
            iconBackgroundColor: .purple,
            instruction: """
            You are an email writing assistant. Help me compose professional emails based on my voice input.
            Understand the context and tone I want to convey. Ask clarifying questions if needed.
            """,
            outputFormat: "Format as a proper email with Subject line, greeting, body paragraphs, and professional sign-off."
        ),
        PowerMode(
            name: "Daily Planner",
            icon: "calendar",
            iconColor: .green,
            iconBackgroundColor: .green,
            instruction: """
            You are a daily planning assistant. Help me organize my day based on what I tell you.
            Consider priorities, time constraints, and suggest optimal scheduling.
            """,
            outputFormat: "Create a structured daily schedule with time blocks. Include priorities and any notes."
        ),
        PowerMode(
            name: "Idea Expander",
            icon: "lightbulb.fill",
            iconColor: .yellow,
            iconBackgroundColor: .yellow,
            instruction: """
            You are a creative brainstorming partner. Take my initial idea and help expand it.
            Explore different angles, potential challenges, and opportunities.
            """,
            outputFormat: "Start with the core idea summary, then list expansions, variations, and actionable next steps."
        )
    ]
}

// MARK: - Power Mode Question Option
struct PowerModeQuestionOption: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let description: String?
    let value: String

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        value: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.value = value ?? title
    }
}

// MARK: - Power Mode Question
struct PowerModeQuestion: Codable, Identifiable, Equatable {
    let id: UUID
    let questionText: String
    let options: [PowerModeQuestionOption]
    let allowFreeform: Bool

    init(
        id: UUID = UUID(),
        questionText: String,
        options: [PowerModeQuestionOption],
        allowFreeform: Bool = true
    ) {
        self.id = id
        self.questionText = questionText
        self.options = options
        self.allowFreeform = allowFreeform
    }

    /// Sample question for UI mockups
    static let sample = PowerModeQuestion(
        questionText: "What time period should I focus the research on?",
        options: [
            PowerModeQuestionOption(
                title: "Last 24 hours",
                description: "Most recent information and breaking news",
                value: "24h"
            ),
            PowerModeQuestionOption(
                title: "Last week",
                description: "Recent developments and trends",
                value: "week"
            ),
            PowerModeQuestionOption(
                title: "Last month",
                description: "Broader context and major stories",
                value: "month"
            ),
            PowerModeQuestionOption(
                title: "All time",
                description: "Comprehensive historical overview",
                value: "all"
            )
        ]
    )
}

// MARK: - Power Mode Result
struct PowerModeResult: Codable, Identifiable, Equatable {
    let id: UUID
    let powerModeId: UUID
    let powerModeName: String
    let userInput: String
    let markdownOutput: String
    let timestamp: Date
    let processingDuration: TimeInterval
    let versionNumber: Int

    // Phase 4: Track what context/memory was used
    var usedRAG: Bool
    var ragDocumentIds: [UUID]

    init(
        id: UUID = UUID(),
        powerModeId: UUID,
        powerModeName: String,
        userInput: String,
        markdownOutput: String,
        timestamp: Date = Date(),
        processingDuration: TimeInterval = 0,
        versionNumber: Int = 1,
        usedRAG: Bool = false,
        ragDocumentIds: [UUID] = []
    ) {
        self.id = id
        self.powerModeId = powerModeId
        self.powerModeName = powerModeName
        self.userInput = userInput
        self.markdownOutput = markdownOutput
        self.timestamp = timestamp
        self.processingDuration = processingDuration
        self.versionNumber = versionNumber
        self.usedRAG = usedRAG
        self.ragDocumentIds = ragDocumentIds
    }

    /// Sample result for UI mockups
    static let sample = PowerModeResult(
        powerModeId: UUID(),
        powerModeName: "Research Assistant",
        userInput: "Find me the latest news about artificial intelligence and summarize the key points",
        markdownOutput: """
        # AI News Summary - December 2024

        ## Key Developments

        - **OpenAI's Latest Release**: The company announced significant improvements to their reasoning models with enhanced capabilities for complex tasks.

        - **Google DeepMind**: New breakthroughs in protein folding prediction showing 95% accuracy.

        - **Anthropic Claude**: Released updated safety guidelines and constitutional AI improvements.

        ## Industry Trends

        1. Increased focus on AI safety and alignment
        2. Growing adoption in enterprise applications
        3. Regulatory frameworks taking shape globally

        ## Sources

        - TechCrunch: AI Weekly Roundup
        - MIT Technology Review
        - The Verge: AI Coverage
        """,
        processingDuration: 6.2
    )
}

// MARK: - Power Mode Session
struct PowerModeSession: Codable, Identifiable, Equatable {
    let id: UUID
    var results: [PowerModeResult]
    var currentVersionIndex: Int

    init(
        id: UUID = UUID(),
        results: [PowerModeResult] = [],
        currentVersionIndex: Int = 0
    ) {
        self.id = id
        self.results = results
        self.currentVersionIndex = results.isEmpty ? 0 : results.count - 1
    }

    var currentResult: PowerModeResult? {
        guard !results.isEmpty, currentVersionIndex < results.count else { return nil }
        return results[currentVersionIndex]
    }

    var hasMultipleVersions: Bool {
        results.count > 1
    }

    var canGoToPrevious: Bool {
        currentVersionIndex > 0
    }

    var canGoToNext: Bool {
        currentVersionIndex < results.count - 1
    }

    mutating func goToPrevious() {
        if canGoToPrevious {
            currentVersionIndex -= 1
        }
    }

    mutating func goToNext() {
        if canGoToNext {
            currentVersionIndex += 1
        }
    }

    mutating func addResult(_ result: PowerModeResult) {
        results.append(result)
        currentVersionIndex = results.count - 1
    }
}

// MARK: - Phase 10: Local Provider Types

/// Types of local/on-device AI providers
enum LocalModelType: String, Codable, CaseIterable, Identifiable {
    case whisperKit = "whisperkit"
    case appleIntelligence = "apple_intelligence"
    case appleTranslation = "apple_translation"
    case ollama = "ollama"
    case lmStudio = "lm_studio"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .whisperKit: return "WhisperKit"
        case .appleIntelligence: return "Apple Intelligence"
        case .appleTranslation: return "Apple Translation"
        case .ollama: return "Ollama"
        case .lmStudio: return "LM Studio"
        }
    }

    var icon: String {
        switch self {
        case .whisperKit: return "mic.fill"
        case .appleIntelligence: return "brain.head.profile"
        case .appleTranslation: return "globe"
        case .ollama: return "desktopcomputer"
        case .lmStudio: return "display"
        }
    }

    var description: String {
        switch self {
        case .whisperKit: return "On-device speech recognition"
        case .appleIntelligence: return "On-device text processing"
        case .appleTranslation: return "On-device translation"
        case .ollama: return "Self-hosted open-source LLMs"
        case .lmStudio: return "Local AI server with GUI"
        }
    }

    /// Whether this type runs on-device (vs self-hosted on network)
    var isOnDevice: Bool {
        switch self {
        case .whisperKit, .appleIntelligence, .appleTranslation: return true
        case .ollama, .lmStudio: return false
        }
    }

    /// Capabilities this local model type supports
    var supportedCategories: Set<ProviderUsageCategory> {
        switch self {
        case .whisperKit: return [.transcription]
        case .appleIntelligence: return [.powerMode]  // Formatting
        case .appleTranslation: return [.translation]
        case .ollama, .lmStudio: return [.transcription, .translation, .powerMode]
        }
    }
}

/// Status of a local model
enum LocalModelStatus: String, Codable {
    case notConfigured = "not_configured"
    case downloading = "downloading"
    case ready = "ready"
    case notAvailable = "not_available"  // Device/OS doesn't support
    case error = "error"

    var displayName: String {
        switch self {
        case .notConfigured: return "Not Set Up"
        case .downloading: return "Downloading"
        case .ready: return "Ready"
        case .notAvailable: return "Not Available"
        case .error: return "Error"
        }
    }

    var icon: String {
        switch self {
        case .notConfigured: return "circle.dashed"
        case .downloading: return "arrow.down.circle"
        case .ready: return "checkmark.circle.fill"
        case .notAvailable: return "xmark.circle"
        case .error: return "exclamationmark.triangle"
        }
    }
}

// MARK: - Phase 10: WhisperKit Models

/// Available WhisperKit model sizes
enum WhisperModel: String, Codable, CaseIterable, Identifiable {
    case tinyEn = "tiny.en"
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"
    case large = "large"
    case largeV2 = "large-v2"
    case largeV3 = "large-v3"
    case largeV3Turbo = "large-v3-turbo"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tinyEn: return "tiny.en"
        case .tiny: return "tiny"
        case .base: return "base"
        case .small: return "small"
        case .medium: return "medium"
        case .large: return "large"
        case .largeV2: return "large-v2"
        case .largeV3: return "large-v3"
        case .largeV3Turbo: return "large-v3-turbo"
        }
    }

    var description: String {
        switch self {
        case .tinyEn: return "English only · Fastest"
        case .tiny: return "All languages · Fastest"
        case .base: return "All languages · Fast"
        case .small: return "All languages · Balanced"
        case .medium: return "All languages · Good accuracy"
        case .large: return "All languages · High accuracy"
        case .largeV2: return "All languages · Higher accuracy"
        case .largeV3: return "All languages · Best accuracy"
        case .largeV3Turbo: return "All languages · Fast & accurate"
        }
    }

    /// Approximate model size in bytes
    var sizeBytes: Int {
        switch self {
        case .tinyEn: return 39 * 1024 * 1024      // 39 MB
        case .tiny: return 39 * 1024 * 1024        // 39 MB
        case .base: return 142 * 1024 * 1024       // 142 MB
        case .small: return 466 * 1024 * 1024      // 466 MB
        case .medium: return 1500 * 1024 * 1024    // 1.5 GB
        case .large: return 2900 * 1024 * 1024     // 2.9 GB
        case .largeV2: return 2900 * 1024 * 1024   // 2.9 GB
        case .largeV3: return 1500 * 1024 * 1024   // 1.5 GB (optimized)
        case .largeV3Turbo: return 809 * 1024 * 1024 // 809 MB
        }
    }

    var sizeFormatted: String {
        let mb = Double(sizeBytes) / (1024 * 1024)
        if mb >= 1000 {
            return String(format: "%.1f GB", mb / 1024)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }

    /// Whether this model supports English only
    var isEnglishOnly: Bool {
        self == .tinyEn
    }

    /// Minimum chip generation recommended for this model
    /// A12 = iPhone XR/XS, A14 = iPhone 12, A15 = iPhone 13, A16 = iPhone 14 Pro, A17 = iPhone 15 Pro
    var minimumChipGeneration: Int {
        switch self {
        case .tinyEn, .tiny: return 12    // A12+
        case .base: return 12             // A12+
        case .small: return 14            // A14+
        case .medium: return 15           // A15+
        case .large, .largeV2: return 17  // A17 Pro+
        case .largeV3: return 16          // A16+
        case .largeV3Turbo: return 15     // A15+
        }
    }

    /// Whether this model is recommended for the current device
    func isRecommendedForChip(_ chipGeneration: Int) -> Bool {
        chipGeneration >= minimumChipGeneration
    }

    /// Whether this model may have performance issues on the device
    func mayHavePerformanceIssues(_ chipGeneration: Int) -> Bool {
        chipGeneration < minimumChipGeneration && chipGeneration >= minimumChipGeneration - 1
    }

    /// Whether this model is not recommended for the device
    func isNotRecommended(_ chipGeneration: Int) -> Bool {
        chipGeneration < minimumChipGeneration - 1
    }

    /// Default model for a given chip generation
    static func recommendedModel(forChipGeneration chipGeneration: Int) -> WhisperModel {
        switch chipGeneration {
        case 17...: return .largeV3        // A17 Pro+
        case 16: return .largeV3           // A16
        case 15: return .largeV3Turbo      // A15
        case 14: return .small             // A14
        default: return .tinyEn            // A12-A13
        }
    }

    // MARK: - Language Support

    /// Languages supported by this model
    /// Whisper supports 99 languages, but quality varies
    /// English-only models only support English
    var supportedLanguages: [Language] {
        if isEnglishOnly {
            return [.english]
        }
        return Language.allCases
    }

    /// Get support level for a specific language
    /// Based on OpenAI Whisper model benchmarks
    func languageSupportLevel(for language: Language) -> LanguageSupportLevel {
        if isEnglishOnly {
            return language == .english ? .excellent : .unsupported
        }

        // Larger models have better accuracy across all languages
        let baseLevel = modelQualityTier

        // Language-specific adjustments based on Whisper training data representation
        switch language {
        case .english:
            return .excellent  // English is always excellent for non-EN models too
        case .spanish, .french, .german, .italian, .portuguese:
            return baseLevel   // Well-represented in training
        case .chinese, .japanese, .korean:
            return baseLevel == .excellent ? .excellent : .good
        case .russian, .polish:
            return baseLevel == .excellent ? .excellent : .good
        case .arabic:
            return baseLevel == .excellent ? .good : .limited
        case .egyptianArabic:
            return baseLevel == .excellent ? .limited : .limited
        }
    }

    /// Quality tier based on model size
    private var modelQualityTier: LanguageSupportLevel {
        switch self {
        case .tinyEn, .tiny:
            return .limited
        case .base:
            return .limited
        case .small:
            return .good
        case .medium:
            return .good
        case .large, .largeV2, .largeV3, .largeV3Turbo:
            return .excellent
        }
    }

    /// Check if a language is supported
    func supportsLanguage(_ language: Language) -> Bool {
        languageSupportLevel(for: language) != .unsupported
    }

    /// All languages with at least limited support
    var languagesWithSupport: [Language] {
        Language.allCases.filter { languageSupportLevel(for: $0) != .unsupported }
    }

    /// Languages with excellent or good support (recommended for use)
    var recommendedLanguages: [Language] {
        Language.allCases.filter {
            let level = languageSupportLevel(for: $0)
            return level == .excellent || level == .good
        }
    }
}

/// Configuration for WhisperKit on-device transcription
/// Note: Named "Settings" to avoid conflict with WhisperKit library's WhisperKitConfig class
struct WhisperKitSettings: Codable, Equatable {
    var selectedModel: WhisperModel
    var status: LocalModelStatus
    var downloadProgress: Double  // 0.0 - 1.0
    var downloadedBytes: Int
    var lastDownloadDate: Date?
    var isEnabled: Bool

    init(
        selectedModel: WhisperModel = .largeV3,
        status: LocalModelStatus = .notConfigured,
        downloadProgress: Double = 0,
        downloadedBytes: Int = 0,
        lastDownloadDate: Date? = nil,
        isEnabled: Bool = false
    ) {
        self.selectedModel = selectedModel
        self.status = status
        self.downloadProgress = downloadProgress
        self.downloadedBytes = downloadedBytes
        self.lastDownloadDate = lastDownloadDate
        self.isEnabled = isEnabled
    }

    static var `default`: WhisperKitSettings {
        WhisperKitSettings()
    }
}

// MARK: - Phase 10: Apple Intelligence

/// Configuration for Apple Intelligence on-device text processing
struct AppleIntelligenceConfig: Codable, Equatable {
    var isEnabled: Bool
    var isAvailable: Bool  // Determined by device/OS check
    var unavailableReason: String?  // "Requires iPhone 15 Pro" etc.

    init(
        isEnabled: Bool = false,
        isAvailable: Bool = false,
        unavailableReason: String? = nil
    ) {
        self.isEnabled = isEnabled
        self.isAvailable = isAvailable
        self.unavailableReason = unavailableReason
    }

    static var `default`: AppleIntelligenceConfig {
        AppleIntelligenceConfig()
    }
}

// MARK: - Phase 10: Apple Translation

/// Downloaded language for Apple Translation
struct DownloadedTranslationLanguage: Codable, Identifiable, Equatable {
    var id: String { language.rawValue }
    var language: Language
    var sizeBytes: Int
    var isSystem: Bool  // System language, can't be removed

    var sizeFormatted: String {
        let mb = Double(sizeBytes) / (1024 * 1024)
        return String(format: "%.0f MB", mb)
    }
}

/// Configuration for Apple Translation
struct AppleTranslationConfig: Codable, Equatable {
    var isAvailable: Bool  // iOS 17.4+
    var downloadedLanguages: [DownloadedTranslationLanguage]

    init(
        isAvailable: Bool = true,
        downloadedLanguages: [DownloadedTranslationLanguage] = []
    ) {
        self.isAvailable = isAvailable
        self.downloadedLanguages = downloadedLanguages
    }

    static var `default`: AppleTranslationConfig {
        AppleTranslationConfig()
    }
}

// MARK: - Phase 10: Provider Selection

/// A provider + model selection pair
struct ProviderSelection: Codable, Equatable, Hashable {
    var providerType: ProviderType
    var model: String?  // Optional model override, nil = use provider default

    init(providerType: ProviderType, model: String? = nil) {
        self.providerType = providerType
        self.model = model
    }

    var displayName: String {
        if let model = model {
            return "\(providerType.displayName) \(model)"
        }
        return providerType.displayName
    }

    var icon: String {
        providerType.icon
    }

    var isLocal: Bool {
        providerType.isLocal
    }
}

/// Unified provider type that covers both cloud and local providers
enum ProviderType: Codable, Equatable, Hashable {
    case cloud(AIProvider)
    case local(LocalModelType)

    var displayName: String {
        switch self {
        case .cloud(let provider): return provider.displayName
        case .local(let type): return type.displayName
        }
    }

    var shortName: String {
        switch self {
        case .cloud(let provider): return provider.shortName
        case .local(let type): return type.displayName
        }
    }

    var icon: String {
        switch self {
        case .cloud(let provider): return provider.icon
        case .local(let type): return type.icon
        }
    }

    var isLocal: Bool {
        if case .local = self { return true }
        return false
    }

    var isCloud: Bool {
        if case .cloud = self { return true }
        return false
    }

    /// Check if this provider type supports a given capability
    func supports(_ category: ProviderUsageCategory) -> Bool {
        switch self {
        case .cloud(let provider):
            return provider.supportedCategories.contains(category)
        case .local(let type):
            return type.supportedCategories.contains(category)
        }
    }
}

// Custom Codable for ProviderType
extension ProviderType {
    enum CodingKeys: String, CodingKey {
        case type, cloudProvider, localType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        if type == "cloud" {
            let provider = try container.decode(AIProvider.self, forKey: .cloudProvider)
            self = .cloud(provider)
        } else {
            let localType = try container.decode(LocalModelType.self, forKey: .localType)
            self = .local(localType)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .cloud(let provider):
            try container.encode("cloud", forKey: .type)
            try container.encode(provider, forKey: .cloudProvider)
        case .local(let localType):
            try container.encode("local", forKey: .type)
            try container.encode(localType, forKey: .localType)
        }
    }
}

/// Global default provider settings per capability
struct ProviderDefaults: Codable, Equatable {
    var transcription: ProviderSelection?
    var translation: ProviderSelection?
    var powerMode: ProviderSelection?
    var useLocalWhenOffline: Bool

    init(
        transcription: ProviderSelection? = nil,
        translation: ProviderSelection? = nil,
        powerMode: ProviderSelection? = nil,
        useLocalWhenOffline: Bool = true
    ) {
        self.transcription = transcription
        self.translation = translation
        self.powerMode = powerMode
        self.useLocalWhenOffline = useLocalWhenOffline
    }

    static var `default`: ProviderDefaults {
        ProviderDefaults()
    }
}

// MARK: - Power Mode Execution State
enum PowerModeExecutionState: Equatable {
    case idle
    case recording
    case transcribing
    case thinking              // Building context, fetching webhooks
    case queryingKnowledge     // Phase 4: RAG query
    case askingQuestion(PowerModeQuestion)
    case generating            // LLM response (blocking mode)
    case streaming(String)     // LLM response (streaming mode) - partial text
    case complete(PowerModeSession)
    case error(String)

    var statusText: String {
        switch self {
        case .idle: return "Tap to speak"
        case .recording: return "Listening..."
        case .transcribing: return "Transcribing..."
        case .thinking: return "Thinking..."
        case .queryingKnowledge: return "Searching knowledge base..."
        case .askingQuestion: return "Question"
        case .generating: return "Generating..."
        case .streaming: return "Generating..."
        case .complete: return "Complete"
        case .error(let message): return message
        }
    }

    var isProcessing: Bool {
        switch self {
        case .transcribing, .thinking, .queryingKnowledge, .generating, .streaming:
            return true
        default:
            return false
        }
    }

    /// Whether this state represents active streaming
    var isStreaming: Bool {
        if case .streaming = self { return true }
        return false
    }

    /// Get partial text if in streaming state
    var streamingText: String? {
        if case .streaming(let text) = self { return text }
        return nil
    }
}
