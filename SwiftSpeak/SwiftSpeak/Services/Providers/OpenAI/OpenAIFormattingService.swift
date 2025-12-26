//
//  OpenAIFormattingService.swift
//  SwiftSpeak
//
//  Created by Claude Code on 26/12/2025.
//

import Foundation

/// OpenAI GPT formatting service
/// Uses GPT to format transcribed text according to templates
final class OpenAIFormattingService: FormattingProvider {

    // MARK: - FormattingProvider

    let providerId: AIProvider = .openAI

    var isConfigured: Bool {
        !apiKey.isEmpty
    }

    var model: String {
        modelName
    }

    // MARK: - Properties

    private let apiKey: String
    private let modelName: String
    private let apiClient: APIClient

    /// Chat completions endpoint
    private let endpoint = URL(string: Constants.API.openAIChat)!

    // MARK: - Initialization

    /// Initialize with API key and optional model
    /// - Parameters:
    ///   - apiKey: OpenAI API key
    ///   - model: GPT model to use (default: gpt-4o-mini for cost efficiency)
    ///   - apiClient: API client instance
    init(
        apiKey: String,
        model: String = "gpt-4o-mini",
        apiClient: APIClient = .shared
    ) {
        self.apiKey = apiKey
        self.modelName = model
        self.apiClient = apiClient
    }

    /// Initialize from provider configuration
    /// - Parameter config: AI provider configuration
    convenience init?(config: AIProviderConfig) {
        guard config.provider == .openAI,
              !config.apiKey.isEmpty
        else { return nil }

        let model = config.translationModel ?? "gpt-4o-mini"
        self.init(apiKey: config.apiKey, model: model)
    }

    // MARK: - Formatting

    func format(
        text: String,
        mode: FormattingMode,
        customPrompt: String?
    ) async throws -> String {
        guard isConfigured else {
            throw TranscriptionError.apiKeyMissing
        }

        // Raw mode returns text unchanged
        if mode == .raw && customPrompt == nil {
            return text
        }

        // Build the system prompt
        let systemPrompt = customPrompt ?? mode.prompt

        // Build request
        let request = ChatCompletionRequest(
            model: modelName,
            messages: [
                Message(role: "system", content: systemPrompt),
                Message(role: "user", content: text)
            ],
            temperature: 0.3, // Lower temperature for more consistent formatting
            maxTokens: 2000
        )

        // Make API call
        let response: ChatCompletionResponse = try await apiClient.post(
            url: endpoint,
            body: request,
            headers: [
                "Authorization": "Bearer \(apiKey)"
            ],
            timeout: 30
        )

        // Extract formatted text
        guard let formattedText = response.choices.first?.message.content,
              !formattedText.isEmpty
        else {
            throw TranscriptionError.emptyResponse
        }

        return formattedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Request/Response Models

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [Message]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct Message: Codable {
    let role: String
    let content: String
}

private struct ChatCompletionResponse: Decodable {
    let id: String
    let choices: [Choice]
    let usage: Usage?

    struct Choice: Decodable {
        let index: Int
        let message: Message
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }

    struct Usage: Decodable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

// Note: FormattingMode.prompt is defined in Models.swift
