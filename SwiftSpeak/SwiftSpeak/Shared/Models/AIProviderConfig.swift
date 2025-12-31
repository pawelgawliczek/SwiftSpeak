//
//  AIProviderConfig.swift
//  SwiftSpeak
//
//  AI provider configuration models
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

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
