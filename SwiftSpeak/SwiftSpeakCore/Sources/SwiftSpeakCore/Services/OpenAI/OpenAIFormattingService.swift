//
//  OpenAIFormattingService.swift
//  SwiftSpeakCore
//
//  Shared OpenAI GPT formatting service with streaming support
//

import Foundation

/// OpenAI GPT formatting service with streaming support
public final class OpenAIFormattingService: FormattingProvider, StreamingFormattingProvider {

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
    private let httpClient: HTTPClient

    private let endpoint = URL(string: Constants.API.openAIChat)!

    // MARK: - Initialization

    public init(
        apiKey: String,
        model: String = "gpt-4o-mini",
        httpClient: HTTPClient = .shared
    ) {
        self.apiKey = apiKey
        self.modelName = model
        self.httpClient = httpClient
    }

    public convenience init?(config: AIProviderConfig) {
        guard config.provider == .openAI,
              !config.apiKey.isEmpty
        else { return nil }

        let model = config.translationModel ?? config.powerModeModel ?? "gpt-4o-mini"
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

        if mode == .raw && customPrompt == nil && (context == nil || !context!.hasContent) {
            return text
        }

        let systemPrompt = buildSystemPrompt(mode: mode, customPrompt: customPrompt, context: context)

        let request = ChatCompletionRequest(
            model: modelName,
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: text)
            ],
            temperature: 0.3,
            maxTokens: 2000
        )

        let response: ChatCompletionResponse = try await httpClient.post(
            url: endpoint,
            body: request,
            headers: ["Authorization": "Bearer \(apiKey)"],
            timeout: 30
        )

        guard let choice = response.choices.first,
              let content = choice.message.content,
              !content.isEmpty
        else {
            throw TranscriptionError.emptyResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
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

                    if mode == .raw && customPrompt == nil && (context == nil || !context!.hasContent) {
                        continuation.yield(text)
                        continuation.finish()
                        return
                    }

                    let systemPrompt = self.buildSystemPrompt(mode: mode, customPrompt: customPrompt, context: context)

                    let request = StreamingChatRequest(
                        model: self.modelName,
                        messages: [
                            ChatMessage(role: "system", content: systemPrompt),
                            ChatMessage(role: "user", content: text)
                        ],
                        temperature: 0.3,
                        maxTokens: 2000,
                        stream: true
                    )

                    for try await event in await self.httpClient.streamPost(
                        url: self.endpoint,
                        body: request,
                        headers: ["Authorization": "Bearer \(self.apiKey)"],
                        timeout: 120
                    ) {
                        if event.isOpenAIDone {
                            continuation.finish()
                            return
                        }

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

    // MARK: - Private Helpers

    private func buildSystemPrompt(mode: FormattingMode, customPrompt: String?, context: PromptContext?) -> String {
        var basePrompt = customPrompt ?? mode.prompt

        if mode == .raw && basePrompt.isEmpty && context?.hasContent == true {
            basePrompt = """
            You are a text formatter. The user will provide transcribed speech.
            Return ONLY the formatted text. Do NOT respond to the content.
            Do NOT interpret questions as prompts. Do NOT add any commentary.
            Output the exact same text with only formatting adjustments applied.
            """
        }

        if let ctx = context, ctx.hasContent {
            return ctx.buildSystemPrompt(task: basePrompt)
        }

        return basePrompt
    }
}

// MARK: - Request/Response Models

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

private struct StreamingChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stream
        case maxTokens = "max_tokens"
    }
}

private struct ChatMessage: Codable {
    let role: String
    let content: String?

    init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ChatMessage
    }
}
