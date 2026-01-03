//
//  OpenAIFormattingService.swift
//  SwiftSpeak
//
//  Created by Claude Code on 26/12/2025.
//

import Foundation

/// OpenAI GPT formatting service
/// Uses GPT to format transcribed text according to templates
/// Supports streaming responses for Power Mode
final class OpenAIFormattingService: FormattingProvider, StreamingFormattingProvider {

    // MARK: - FormattingProvider

    public let providerId: AIProvider = .openAI

    public var isConfigured: Bool {
        !apiKey.isEmpty
    }

    public var model: String {
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
    public init(
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

    public func format(
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
        var basePrompt = customPrompt ?? mode.prompt

        // For raw mode with context, we need a base task that tells the LLM
        // this is TEXT TO FORMAT, not a question to answer
        if mode == .raw && basePrompt.isEmpty && context?.hasContent == true {
            basePrompt = """
            You are a text formatter. The user will provide transcribed speech.
            Return ONLY the formatted text. Do NOT respond to the content.
            Do NOT interpret questions as prompts. Do NOT add any commentary.
            Output the exact same text with only formatting adjustments applied.
            """
        }

        let systemPrompt: String

        if let ctx = context, ctx.hasContent {
            // Use PromptContext to build enriched prompt with memory, tone, and instructions
            systemPrompt = ctx.buildSystemPrompt(task: basePrompt)
        } else {
            systemPrompt = basePrompt
        }

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
        guard let choice = response.choices.first else {
            throw TranscriptionError.emptyResponse
        }

        // Check for refusal first
        if let refusal = choice.message.refusal, !refusal.isEmpty {
            throw TranscriptionError.serverError(statusCode: 200, message: "Request refused: \(refusal)")
        }

        guard let formattedText = choice.message.content, !formattedText.isEmpty else {
            throw TranscriptionError.emptyResponse
        }

        return formattedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - StreamingFormattingProvider

    public var supportsStreaming: Bool { true }

    public func formatStreaming(
        text: String,
        mode: FormattingMode,
        customPrompt: String?,
        context: PromptContext?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard self.isConfigured else {
                        throw TranscriptionError.apiKeyMissing
                    }

                    // Raw mode without context returns text unchanged (no streaming needed)
                    if mode == .raw && customPrompt == nil && (context == nil || !context!.hasContent) {
                        continuation.yield(text)
                        continuation.finish()
                        return
                    }

                    // Build the system prompt
                    var basePrompt = customPrompt ?? mode.prompt

                    // For raw mode with context, we need a base task that tells the LLM
                    // this is TEXT TO FORMAT, not a question to answer
                    if mode == .raw && basePrompt.isEmpty && context?.hasContent == true {
                        basePrompt = """
                        You are a text formatter. The user will provide transcribed speech.
                        Return ONLY the formatted text. Do NOT respond to the content.
                        Do NOT interpret questions as prompts. Do NOT add any commentary.
                        Output the exact same text with only formatting adjustments applied.
                        """
                    }

                    let systemPrompt: String

                    if let ctx = context, ctx.hasContent {
                        systemPrompt = ctx.buildSystemPrompt(task: basePrompt)
                    } else {
                        systemPrompt = basePrompt
                    }

                    // Build streaming request
                    let request = StreamingChatCompletionRequest(
                        model: self.modelName,
                        messages: [
                            Message(role: "system", content: systemPrompt),
                            Message(role: "user", content: text)
                        ],
                        temperature: 0.3,
                        maxTokens: 2000,
                        stream: true
                    )

                    // Stream SSE events
                    for try await event in await self.apiClient.streamPost(
                        url: self.endpoint,
                        body: request,
                        headers: ["Authorization": "Bearer \(self.apiKey)"],
                        timeout: 120
                    ) {
                        // Check for completion
                        if event.isOpenAIDone {
                            continuation.finish()
                            return
                        }

                        // Extract text content from OpenAI delta format
                        if let content = event.openAIContent() {
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

private struct ChatCompletionRequest: Encodable {
    public let model: String
    public let messages: [Message]
    public let temperature: Double
    public let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct StreamingChatCompletionRequest: Encodable {
    public let model: String
    public let messages: [Message]
    public let temperature: Double
    public let maxTokens: Int
    public let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case stream
    }
}

private struct Message: Codable {
    public let role: String
    public let content: String?  // Can be null in newer API responses (tool calls, refusals)
    public let refusal: String?  // Present in newer API versions (may be completely absent)

    public init(role: String, content: String) {
        self.role = role
        self.content = content
        self.refusal = nil
    }

    // Custom decoder to handle missing keys (not just null values)
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decode(String.self, forKey: .role)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        refusal = try container.decodeIfPresent(String.self, forKey: .refusal)
    }

    private enum CodingKeys: String, CodingKey {
        case role, content, refusal
    }
}

private struct ChatCompletionResponse: Decodable {
    public let id: String
    public let choices: [Choice]
    public let usage: Usage?

    struct Choice: Decodable {
        let index: Int
        let message: Message
        let finishReason: String?
        // Note: No CodingKeys needed - APIClient uses .convertFromSnakeCase strategy
        // which automatically converts finish_reason → finishReason
    }

    struct Usage: Decodable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        // Note: No CodingKeys needed - APIClient uses .convertFromSnakeCase strategy
        // which automatically converts prompt_tokens → promptTokens, etc.
    }
}

// Note: FormattingMode.prompt is defined in Models.swift
