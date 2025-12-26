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
        case .pro: return "$4.99/mo"
        case .power: return "$9.99/mo"
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

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic Claude"
        case .google: return "Google Gemini"
        case .elevenLabs: return "ElevenLabs"
        case .deepgram: return "Deepgram"
        case .local: return "Local AI"
        }
    }

    var shortName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Claude"
        case .google: return "Gemini"
        case .elevenLabs: return "ElevenLabs"
        case .deepgram: return "Deepgram"
        case .local: return "Local"
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
        }
    }

    var description: String {
        switch self {
        case .openAI: return "Whisper for transcription, GPT for AI processing"
        case .anthropic: return "Advanced reasoning and safety-focused AI"
        case .google: return "Multimodal AI with fast responses"
        case .elevenLabs: return "Speech recognition with free tier (2.5 hrs/month)"
        case .deepgram: return "Fast transcription with competitive pricing"
        case .local: return "Local AI (Ollama, LM Studio, or OpenAI-compatible)"
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
        case .openAI, .elevenLabs, .deepgram, .local: return true
        case .anthropic, .google: return false
        }
    }

    var supportsTranslation: Bool {
        switch self {
        case .openAI, .anthropic, .google, .local: return true
        case .elevenLabs, .deepgram: return false
        }
    }

    var supportsPowerMode: Bool {
        switch self {
        case .openAI, .anthropic, .google, .local: return true
        case .elevenLabs, .deepgram: return false
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
        case .anthropic, .google: return []
        }
    }

    var defaultSTTModel: String? {
        switch self {
        case .openAI: return "whisper-1"
        case .elevenLabs: return "scribe_v1"
        case .deepgram: return "nova-2"
        case .local: return nil // Must be selected after connecting
        case .anthropic, .google: return nil
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
        case .elevenLabs, .deepgram: return []
        }
    }

    var defaultLLMModel: String? {
        switch self {
        case .openAI: return "gpt-4o-mini"
        case .anthropic: return "claude-3-5-sonnet-latest"
        case .google: return "gemini-2.0-flash-exp"
        case .local: return nil // Must be selected after connecting
        case .elevenLabs, .deepgram: return nil
        }
    }

    // MARK: - API Help

    var apiKeyHelpURL: URL? {
        switch self {
        case .openAI: return URL(string: "https://platform.openai.com/api-keys")
        case .anthropic: return URL(string: "https://console.anthropic.com/settings/keys")
        case .google: return URL(string: "https://aistudio.google.com/app/apikey")
        case .elevenLabs: return URL(string: "https://elevenlabs.io/app/settings/api-keys")
        case .deepgram: return URL(string: "https://console.deepgram.com/project/api-keys")
        case .local: return URL(string: "https://ollama.ai") // Default to Ollama docs
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
        }
    }

    var costPerMinute: Double {
        switch self {
        case .openAI: return 0.006
        case .elevenLabs: return 0.0
        case .deepgram: return 0.0043
        case .anthropic, .google, .local: return 0.0
        }
    }

    /// Whether this provider requires Power subscription tier
    var requiresPowerTier: Bool {
        switch self {
        case .local: return true
        case .openAI, .anthropic, .google, .elevenLabs, .deepgram: return false
        }
    }

    /// Minimum subscription tier required for this provider
    var minimumTier: SubscriptionTier {
        requiresPowerTier ? .power : .free
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

    init(
        provider: AIProvider,
        apiKey: String = "",
        endpoint: String? = nil,
        usageCategories: Set<ProviderUsageCategory>? = nil,
        transcriptionModel: String? = nil,
        translationModel: String? = nil,
        powerModeModel: String? = nil,
        localConfig: LocalProviderConfig? = nil,
        cachedModels: [String]? = nil
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

    init(
        id: UUID = UUID(),
        text: String,
        mode: FormattingMode,
        provider: AIProvider,
        timestamp: Date = Date(),
        duration: TimeInterval,
        translated: Bool = false,
        targetLanguage: Language? = nil
    ) {
        self.id = id
        self.text = text
        self.mode = mode
        self.provider = provider
        self.timestamp = timestamp
        self.duration = duration
        self.translated = translated
        self.targetLanguage = targetLanguage
    }
}

// MARK: - Recording State
enum RecordingState: Equatable {
    case idle
    case recording
    case processing
    case formatting
    case complete(String)
    case error(String)

    var statusText: String {
        switch self {
        case .idle: return "Tap to record"
        case .recording: return "Listening..."
        case .processing: return "Transcribing..."
        case .formatting: return "Formatting..."
        case .complete: return "Done!"
        case .error(let message): return message
        }
    }
}

// MARK: - Custom Template
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

// MARK: - Power Mode Capability
enum PowerModeCapability: String, Codable, CaseIterable, Identifiable {
    case webSearch = "web_search"
    case bashComputerUse = "bash_computer_use"
    case codeExecution = "code_execution"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .webSearch: return "Web Search"
        case .bashComputerUse: return "Bash / Computer Use"
        case .codeExecution: return "Code Execution"
        }
    }

    var icon: String {
        switch self {
        case .webSearch: return "magnifyingglass"
        case .bashComputerUse: return "terminal.fill"
        case .codeExecution: return "chevron.left.forwardslash.chevron.right"
        }
    }

    var description: String {
        switch self {
        case .webSearch: return "Search the web for current information"
        case .bashComputerUse: return "Execute shell commands"
        case .codeExecution: return "Run Python code in sandbox"
        }
    }

    /// Which providers support this capability
    var supportedProviders: [AIProvider] {
        switch self {
        case .webSearch: return [.openAI, .anthropic, .google]
        case .bashComputerUse: return [.openAI, .anthropic]
        case .codeExecution: return [.openAI, .google]
        }
    }

    /// Check if a provider supports this capability
    func isSupported(by provider: AIProvider) -> Bool {
        supportedProviders.contains(provider)
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

// MARK: - Power Mode
struct PowerMode: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    var iconColor: PowerModeColorPreset
    var iconBackgroundColor: PowerModeColorPreset
    var instruction: String
    var outputFormat: String
    var enabledCapabilities: Set<PowerModeCapability>
    let createdAt: Date
    var updatedAt: Date
    var usageCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "bolt.fill",
        iconColor: PowerModeColorPreset = .orange,
        iconBackgroundColor: PowerModeColorPreset = .orange,
        instruction: String = "",
        outputFormat: String = "",
        enabledCapabilities: Set<PowerModeCapability> = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        usageCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.iconColor = iconColor
        self.iconBackgroundColor = iconBackgroundColor
        self.instruction = instruction
        self.outputFormat = outputFormat
        self.enabledCapabilities = enabledCapabilities
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.usageCount = usageCount
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
            outputFormat: "Use headers (##) for main topics. Include bullet points for key findings. Add a \"Sources\" section at the end.",
            enabledCapabilities: [.webSearch]
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
            outputFormat: "Format as a proper email with Subject line, greeting, body paragraphs, and professional sign-off.",
            enabledCapabilities: []
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
            outputFormat: "Create a structured daily schedule with time blocks. Include priorities and any notes.",
            enabledCapabilities: []
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
            outputFormat: "Start with the core idea summary, then list expansions, variations, and actionable next steps.",
            enabledCapabilities: [.webSearch]
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
    let capabilitiesUsed: [PowerModeCapability]
    let timestamp: Date
    let processingDuration: TimeInterval
    let versionNumber: Int

    init(
        id: UUID = UUID(),
        powerModeId: UUID,
        powerModeName: String,
        userInput: String,
        markdownOutput: String,
        capabilitiesUsed: [PowerModeCapability] = [],
        timestamp: Date = Date(),
        processingDuration: TimeInterval = 0,
        versionNumber: Int = 1
    ) {
        self.id = id
        self.powerModeId = powerModeId
        self.powerModeName = powerModeName
        self.userInput = userInput
        self.markdownOutput = markdownOutput
        self.capabilitiesUsed = capabilitiesUsed
        self.timestamp = timestamp
        self.processingDuration = processingDuration
        self.versionNumber = versionNumber
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
        capabilitiesUsed: [.webSearch],
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

// MARK: - Power Mode Execution State
enum PowerModeExecutionState: Equatable {
    case idle
    case recording
    case transcribing
    case thinking
    case usingCapability(PowerModeCapability)
    case askingQuestion(PowerModeQuestion)
    case generating
    case complete(PowerModeSession)
    case error(String)

    var statusText: String {
        switch self {
        case .idle: return "Tap to speak"
        case .recording: return "Listening..."
        case .transcribing: return "Transcribing..."
        case .thinking: return "Thinking..."
        case .usingCapability(let capability): return "Using \(capability.displayName)..."
        case .askingQuestion: return "Question"
        case .generating: return "Generating..."
        case .complete: return "Complete"
        case .error(let message): return message
        }
    }

    var isProcessing: Bool {
        switch self {
        case .transcribing, .thinking, .usingCapability, .generating:
            return true
        default:
            return false
        }
    }
}
