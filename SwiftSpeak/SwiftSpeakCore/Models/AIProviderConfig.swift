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
public enum LocalProviderType: String, Codable, CaseIterable, Identifiable {
    case ollama = "ollama"
    case lmStudio = "lm_studio"
    case openAICompatible = "openai_compatible"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .ollama: return "Ollama"
        case .lmStudio: return "LM Studio"
        case .openAICompatible: return "Other OpenAI-compatible"
        }
    }

    public var icon: String {
        switch self {
        case .ollama: return "terminal.fill"
        case .lmStudio: return "desktopcomputer"
        case .openAICompatible: return "server.rack"
        }
    }

    public var description: String {
        switch self {
        case .ollama: return "Ollama local AI server"
        case .lmStudio: return "LM Studio OpenAI-compatible server"
        case .openAICompatible: return "Any OpenAI-compatible API server"
        }
    }

    public var defaultEndpoint: String {
        switch self {
        case .ollama: return "http://localhost:11434"
        case .lmStudio: return "http://localhost:1234"
        case .openAICompatible: return "http://localhost:8080"
        }
    }

    public var placeholderEndpoint: String {
        switch self {
        case .ollama: return "http://192.168.1.50:11434"
        case .lmStudio: return "http://192.168.1.60:1234"
        case .openAICompatible: return "http://your-server:port"
        }
    }

    /// API endpoints differ between Ollama native API and OpenAI-compatible APIs
    public var modelsEndpoint: String {
        switch self {
        case .ollama: return "/api/tags"
        case .lmStudio, .openAICompatible: return "/v1/models"
        }
    }

    public var chatEndpoint: String {
        switch self {
        case .ollama: return "/api/chat"
        case .lmStudio, .openAICompatible: return "/v1/chat/completions"
        }
    }

    public var generateEndpoint: String {
        switch self {
        case .ollama: return "/api/generate"
        case .lmStudio, .openAICompatible: return "/v1/completions"
        }
    }

    /// Alias for defaultEndpoint for consistency
    public var defaultURL: String {
        defaultEndpoint
    }

    /// Default model suggestion for this provider type
    public var defaultModel: String {
        switch self {
        case .ollama: return "llama3.2"
        case .lmStudio: return "local-model"
        case .openAICompatible: return "gpt-3.5-turbo"
        }
    }
}

// MARK: - Local Provider Configuration
/// Configuration for local/self-hosted AI providers
public struct LocalProviderConfig: Codable, Equatable {
    public var type: LocalProviderType
    public var baseURL: String
    public var authToken: String?
    public var defaultModel: String?
    public var streamingEnabled: Bool
    public var timeoutSeconds: Int

    public init(
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
    public static let timeoutOptions: [Int] = [5, 10, 20, 30, 60]

    /// Whether authentication is configured
    public var hasAuthentication: Bool {
        authToken?.isEmpty == false
    }
}

// MARK: - Connection Test Result
/// Result of testing connection to a local provider
public struct LocalProviderConnectionResult: Equatable {
    public let success: Bool
    public let latencyMs: Int?
    public let availableModels: [String]
    public let errorMessage: String?

    public static let pending = LocalProviderConnectionResult(success: false, latencyMs: nil, availableModels: [], errorMessage: nil)

    public static func success(latencyMs: Int, models: [String]) -> LocalProviderConnectionResult {
        LocalProviderConnectionResult(success: true, latencyMs: latencyMs, availableModels: models, errorMessage: nil)
    }

    public static func failure(_ message: String) -> LocalProviderConnectionResult {
        LocalProviderConnectionResult(success: false, latencyMs: nil, availableModels: [], errorMessage: message)
    }
}

// MARK: - Unified AI Provider Configuration
public struct AIProviderConfig: Codable, Identifiable, Equatable {
    public var id: String { provider.rawValue }
    public var provider: AIProvider
    public var apiKey: String
    public var endpoint: String?       // Legacy - kept for backward compatibility
    public var usageCategories: Set<ProviderUsageCategory>

    // Model per capability - allows different models for each use case
    public var transcriptionModel: String?    // STT model (e.g., whisper-1)
    public var translationModel: String?      // LLM model for translation (e.g., gpt-4o-mini)
    public var powerModeModel: String?        // LLM model for power mode (e.g., gpt-4o)

    // Local provider configuration (only used when provider == .local)
    public var localConfig: LocalProviderConfig?

    // Cached models from last successful connection test (for local providers)
    public var cachedModels: [String]?

    // Provider-specific configuration
    public var azureRegion: String?           // Required for Azure Translator (e.g., "eastus", "westeurope")
    public var googleProjectId: String?       // Required for Google Cloud STT

    public init(
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
    public var effectiveBaseURL: String? {
        if provider.isLocalProvider {
            return localConfig?.baseURL ?? endpoint
        }
        return nil
    }

    /// Get the effective auth token for local providers
    public var effectiveAuthToken: String? {
        if provider.isLocalProvider {
            return localConfig?.authToken
        }
        return nil
    }

    /// Check if this local provider is configured
    public var isLocalProviderConfigured: Bool {
        guard provider.isLocalProvider else { return true }
        guard let localConfig = localConfig else { return false }
        return !localConfig.baseURL.isEmpty
    }

    public var isConfiguredForTranscription: Bool {
        usageCategories.contains(.transcription) && provider.supportsTranscription
    }

    public var isConfiguredForTranslation: Bool {
        usageCategories.contains(.translation) && provider.supportsTranslation
    }

    public var isConfiguredForPowerMode: Bool {
        usageCategories.contains(.powerMode) && provider.supportsPowerMode
    }

    /// Get the model for a specific category
    public func model(for category: ProviderUsageCategory) -> String? {
        switch category {
        case .transcription: return transcriptionModel
        case .translation: return translationModel
        case .powerMode: return powerModeModel
        }
    }

    /// Get available models for a specific category
    /// For local providers, uses cached models if available
    public func availableModels(for category: ProviderUsageCategory) -> [String] {
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
    public var modelSummary: String {
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
    public var detailedModelSummary: [(ProviderUsageCategory, String)] {
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
