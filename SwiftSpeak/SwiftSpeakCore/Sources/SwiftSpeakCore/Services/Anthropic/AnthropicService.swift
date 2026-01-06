//
//  AnthropicService.swift
//  SwiftSpeakCore
//
//  Shared Anthropic Claude formatting service with streaming
//

import Foundation

/// Anthropic Claude formatting service with streaming support
public final class AnthropicService: FormattingProvider, StreamingFormattingProvider {

    public let providerId: AIProvider = .anthropic
    public var isConfigured: Bool { !apiKey.isEmpty }
    public var model: String { modelName }

    private let apiKey: String
    private let modelName: String
    private let httpClient: HTTPClient
    private let endpoint = URL(string: Constants.API.anthropic)!

    public init(apiKey: String, model: String = "claude-sonnet-4-20250514", httpClient: HTTPClient = .shared) {
        self.apiKey = apiKey
        self.modelName = model
        self.httpClient = httpClient
    }

    public convenience init?(config: AIProviderConfig) {
        guard config.provider == .anthropic, !config.apiKey.isEmpty else { return nil }
        self.init(apiKey: config.apiKey, model: config.powerModeModel ?? "claude-sonnet-4-20250514")
    }

    public func format(text: String, mode: FormattingMode, customPrompt: String?, context: PromptContext?) async throws -> String {
        guard isConfigured else { throw TranscriptionError.apiKeyMissing }

        if mode == .raw && customPrompt == nil && (context == nil || !context!.hasContent) {
            return text
        }

        let basePrompt = customPrompt ?? mode.prompt
        let systemPrompt = context?.hasContent == true ? context!.buildSystemPrompt(task: basePrompt) : basePrompt

        let request = AnthropicRequest(
            model: modelName,
            maxTokens: 4096,
            system: systemPrompt,
            messages: [AnthropicMessage(role: "user", content: text)]
        )

        let response: AnthropicResponse = try await httpClient.post(
            url: endpoint,
            body: request,
            headers: ["x-api-key": apiKey, "anthropic-version": "2023-06-01"],
            timeout: 30
        )

        guard let content = response.content.first, content.type == "text", !content.text.isEmpty else {
            throw TranscriptionError.emptyResponse
        }

        return content.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var supportsStreaming: Bool { true }

    public func formatStreaming(text: String, mode: FormattingMode, customPrompt: String?, context: PromptContext?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard self.isConfigured else { throw TranscriptionError.apiKeyMissing }

                    if mode == .raw && customPrompt == nil && (context == nil || !context!.hasContent) {
                        continuation.yield(text)
                        continuation.finish()
                        return
                    }

                    let basePrompt = customPrompt ?? mode.prompt
                    let systemPrompt = context?.hasContent == true ? context!.buildSystemPrompt(task: basePrompt) : basePrompt

                    let request = AnthropicStreamingRequest(
                        model: self.modelName,
                        maxTokens: 4096,
                        system: systemPrompt,
                        messages: [AnthropicMessage(role: "user", content: text)],
                        stream: true
                    )

                    for try await event in await self.httpClient.streamPost(
                        url: self.endpoint,
                        body: request,
                        headers: ["x-api-key": self.apiKey, "anthropic-version": "2023-06-01"],
                        timeout: 120
                    ) {
                        if event.isAnthropicDone {
                            continuation.finish()
                            return
                        }
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

private struct AnthropicRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [AnthropicMessage]

    enum CodingKeys: String, CodingKey {
        case model, system, messages
        case maxTokens = "max_tokens"
    }
}

private struct AnthropicStreamingRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [AnthropicMessage]
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model, system, messages, stream
        case maxTokens = "max_tokens"
    }
}

private struct AnthropicMessage: Codable {
    let role: String
    let content: String
}

private struct AnthropicResponse: Decodable {
    let content: [AnthropicContent]
}

private struct AnthropicContent: Decodable {
    let type: String
    let text: String
}
