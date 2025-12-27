//
//  AnthropicService.swift
//  SwiftSpeak
//
//  Created by Claude Code on 26/12/2025.
//

import Foundation

/// Anthropic Claude formatting service
/// Uses Claude to format transcribed text according to templates
final class AnthropicService: FormattingProvider, StreamingFormattingProvider {

    // MARK: - FormattingProvider

    let providerId: AIProvider = .anthropic

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

    /// Messages endpoint
    private let endpoint = URL(string: Constants.API.anthropic)!

    // MARK: - Initialization

    /// Initialize with API key and optional model
    /// - Parameters:
    ///   - apiKey: Anthropic API key
    ///   - model: Claude model to use (default: claude-3-5-sonnet-latest)
    ///   - apiClient: API client instance
    init(
        apiKey: String,
        model: String = "claude-3-5-sonnet-latest",
        apiClient: APIClient = .shared
    ) {
        self.apiKey = apiKey
        self.modelName = model
        self.apiClient = apiClient
    }

    /// Initialize from provider configuration
    /// - Parameter config: AI provider configuration
    convenience init?(config: AIProviderConfig) {
        guard config.provider == .anthropic,
              !config.apiKey.isEmpty
        else { return nil }

        let model = config.powerModeModel ?? "claude-3-5-sonnet-latest"
        self.init(apiKey: config.apiKey, model: model)
    }

    // MARK: - Formatting

    func format(
        text: String,
        mode: FormattingMode,
        customPrompt: String?,
        context: PromptContext?
    ) async throws -> String {
        guard isConfigured else {
            throw TranscriptionError.apiKeyMissing
        }

        // Raw mode returns text unchanged (unless context requires processing)
        if mode == .raw && customPrompt == nil && (context == nil || !context!.hasContent) {
            return text
        }

        // Build the system prompt
        let basePrompt = customPrompt ?? mode.prompt
        let systemPrompt: String

        if let ctx = context, ctx.hasContent {
            // Use PromptContext to build enriched prompt with memory, tone, and instructions
            systemPrompt = ctx.buildSystemPrompt(task: basePrompt)
        } else {
            systemPrompt = basePrompt
        }

        // Build request
        let request = AnthropicMessageRequest(
            model: modelName,
            maxTokens: 4096,
            system: systemPrompt,
            messages: [
                AnthropicMessage(role: "user", content: text)
            ]
        )

        // Make API call
        let response: AnthropicMessageResponse = try await apiClient.post(
            url: endpoint,
            body: request,
            headers: [
                "x-api-key": apiKey,
                "anthropic-version": "2023-06-01"
            ],
            timeout: 30
        )

        // Extract formatted text
        guard let firstContent = response.content.first,
              firstContent.type == "text",
              !firstContent.text.isEmpty
        else {
            throw TranscriptionError.emptyResponse
        }

        return firstContent.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - StreamingFormattingProvider

    var supportsStreaming: Bool { true }

    func formatStreaming(
        text: String,
        mode: FormattingMode,
        customPrompt: String?,
        context: PromptContext?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard isConfigured else {
                        continuation.finish(throwing: TranscriptionError.apiKeyMissing)
                        return
                    }

                    // Raw mode returns text unchanged
                    if mode == .raw && customPrompt == nil && (context == nil || !context!.hasContent) {
                        continuation.yield(text)
                        continuation.finish()
                        return
                    }

                    // Build the system prompt
                    let basePrompt = customPrompt ?? mode.prompt
                    let systemPrompt: String

                    if let ctx = context, ctx.hasContent {
                        systemPrompt = ctx.buildSystemPrompt(task: basePrompt)
                    } else {
                        systemPrompt = basePrompt
                    }

                    // Build streaming request
                    let request = AnthropicStreamingRequest(
                        model: modelName,
                        maxTokens: 4096,
                        system: systemPrompt,
                        messages: [
                            AnthropicMessage(role: "user", content: text)
                        ],
                        stream: true
                    )

                    // Stream API call
                    for try await event in await apiClient.streamPost(
                        url: endpoint,
                        body: request,
                        headers: [
                            "x-api-key": apiKey,
                            "anthropic-version": "2023-06-01"
                        ],
                        timeout: 120
                    ) {
                        // Check for done signal
                        if event.isAnthropicDone {
                            continuation.finish()
                            return
                        }

                        // Extract text content
                        if let content = event.anthropicContent() {
                            continuation.yield(content)
                        }
                    }

                    continuation.finish()

                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Request/Response Models

private struct AnthropicMessageRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [AnthropicMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
    }
}

private struct AnthropicStreamingRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [AnthropicMessage]
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
        case stream
    }
}

private struct AnthropicMessage: Codable {
    let role: String
    let content: String
}

private struct AnthropicMessageResponse: Decodable {
    let id: String
    let type: String
    let role: String
    let content: [AnthropicContent]
    let model: String
    let stopReason: String?
    let usage: AnthropicUsage?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case role
        case content
        case model
        case stopReason = "stop_reason"
        case usage
    }
}

private struct AnthropicContent: Decodable {
    let type: String
    let text: String
}

private struct AnthropicUsage: Decodable {
    let inputTokens: Int
    let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

// Note: FormattingMode.prompt is defined in Models.swift
