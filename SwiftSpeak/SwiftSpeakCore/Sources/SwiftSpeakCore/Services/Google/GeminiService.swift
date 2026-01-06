//
//  GeminiService.swift
//  SwiftSpeakCore
//
//  Shared Google Gemini formatting service
//

import Foundation

/// Google Gemini formatting service
public final class GeminiService: FormattingProvider {

    public let providerId: AIProvider = .google
    public var isConfigured: Bool { !apiKey.isEmpty }
    public var model: String { modelName }

    private let apiKey: String
    private let modelName: String
    private let httpClient: HTTPClient

    public init(apiKey: String, model: String = "gemini-2.0-flash-exp", httpClient: HTTPClient = .shared) {
        self.apiKey = apiKey
        self.modelName = model
        self.httpClient = httpClient
    }

    public convenience init?(config: AIProviderConfig) {
        guard config.provider == .google, !config.apiKey.isEmpty else { return nil }
        self.init(apiKey: config.apiKey, model: config.powerModeModel ?? "gemini-2.0-flash-exp")
    }

    public func format(text: String, mode: FormattingMode, customPrompt: String?, context: PromptContext?) async throws -> String {
        guard isConfigured else { throw TranscriptionError.apiKeyMissing }

        if mode == .raw && customPrompt == nil && (context == nil || !context!.hasContent) {
            return text
        }

        let basePrompt = customPrompt ?? mode.prompt
        let systemPrompt = context?.hasContent == true ? context!.buildSystemPrompt(task: basePrompt) : basePrompt

        let endpoint = URL(string: "\(Constants.API.gemini)/\(modelName):generateContent?key=\(apiKey)")!

        let request = GeminiRequest(
            contents: [
                GeminiContent(role: "user", parts: [GeminiPart(text: "\(systemPrompt)\n\nText to format:\n\(text)")])
            ],
            generationConfig: GeminiConfig(temperature: 0.3, maxOutputTokens: 4096)
        )

        let response: GeminiResponse = try await httpClient.post(url: endpoint, body: request, timeout: 30)

        guard let candidate = response.candidates?.first,
              let text = candidate.content.parts.first?.text,
              !text.isEmpty else {
            throw TranscriptionError.emptyResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
    let generationConfig: GeminiConfig
}

private struct GeminiContent: Codable {
    let role: String
    let parts: [GeminiPart]
}

private struct GeminiPart: Codable {
    let text: String
}

private struct GeminiConfig: Encodable {
    let temperature: Double
    let maxOutputTokens: Int
}

private struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]?
}

private struct GeminiCandidate: Decodable {
    let content: GeminiContent
}
