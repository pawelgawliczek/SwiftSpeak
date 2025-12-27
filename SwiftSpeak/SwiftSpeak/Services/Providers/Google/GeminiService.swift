//
//  GeminiService.swift
//  SwiftSpeak
//
//  Created by Claude Code on 26/12/2025.
//

import Foundation

/// Google Gemini formatting service for power mode
/// Uses Gemini API for text formatting according to templates
final class GeminiService: FormattingProvider {

    // MARK: - FormattingProvider

    let providerId: AIProvider = .google

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

    // MARK: - Initialization

    /// Initialize with API key and optional model
    /// - Parameters:
    ///   - apiKey: Google API key
    ///   - model: Gemini model to use (default: gemini-2.0-flash-exp)
    ///   - apiClient: API client instance
    init(
        apiKey: String,
        model: String = "gemini-2.0-flash-exp",
        apiClient: APIClient = .shared
    ) {
        self.apiKey = apiKey
        self.modelName = model
        self.apiClient = apiClient
    }

    /// Initialize from provider configuration
    /// - Parameter config: AI provider configuration
    convenience init?(config: AIProviderConfig) {
        guard config.provider == .google,
              !config.apiKey.isEmpty
        else { return nil }

        let model = config.powerModeModel ?? "gemini-2.0-flash-exp"
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

        // Gemini doesn't have separate system messages, so combine them
        let combinedPrompt = """
        \(systemPrompt)

        Text to format:
        \(text)
        """

        // Build request
        let request = GeminiRequest(
            contents: [
                GeminiContent(
                    role: "user",
                    parts: [GeminiPart(text: combinedPrompt)]
                )
            ]
        )

        // Build endpoint URL with model name
        let endpoint = URL(string: "\(Constants.API.gemini)/\(modelName):generateContent")!

        // Make API call
        // Google AI Studio uses x-goog-api-key header
        let response: GeminiResponse = try await apiClient.post(
            url: endpoint,
            body: request,
            headers: [
                "x-goog-api-key": apiKey
            ],
            timeout: 30
        )

        // Extract formatted text
        guard let candidate = response.candidates.first,
              let part = candidate.content.parts.first,
              !part.text.isEmpty
        else {
            throw TranscriptionError.emptyResponse
        }

        return part.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Request/Response Models

private struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
}

private struct GeminiContent: Codable {
    let role: String
    let parts: [GeminiPart]
}

private struct GeminiPart: Codable {
    let text: String
}

private struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]

    struct GeminiCandidate: Decodable {
        let content: GeminiContent
    }
}
