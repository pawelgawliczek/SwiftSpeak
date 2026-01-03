//
//  OpenAITranslationService.swift
//  SwiftSpeak
//
//  Created by Claude Code on 26/12/2025.
//

import Foundation

/// OpenAI GPT translation service
/// Uses GPT to translate text between languages
final class OpenAITranslationService: TranslationProvider {

    // MARK: - TranslationProvider

    public let providerId: AIProvider = .openAI

    public var isConfigured: Bool {
        !apiKey.isEmpty
    }

    public var model: String {
        modelName
    }

    public var supportedLanguages: [Language] {
        Language.allCases
    }

    public var supportsFormality: Bool {
        true // LLM can understand formality through context
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

    // MARK: - Translation

    public func translate(
        text: String,
        from sourceLanguage: Language?,
        to targetLanguage: Language,
        formality: Formality?,
        context: PromptContext?
    ) async throws -> String {
        guard isConfigured else {
            throw TranscriptionError.apiKeyMissing
        }

        // Build the system prompt for translation
        let systemPrompt: String
        if let ctx = context, ctx.hasContent {
            // Use PromptContext to build enriched translation prompt
            systemPrompt = ctx.buildTranslationPrompt(to: targetLanguage, from: sourceLanguage)
        } else {
            // Fall back to basic translation prompt
            systemPrompt = buildTranslationPrompt(
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                formality: formality
            )
        }

        // Build request
        let request = TranslationChatRequest(
            model: modelName,
            messages: [
                TranslationMessage(role: "system", content: systemPrompt),
                TranslationMessage(role: "user", content: text)
            ],
            temperature: 0.3, // Lower temperature for more consistent translation
            maxTokens: 4000
        )

        // Make API call
        let response: TranslationChatResponse = try await apiClient.post(
            url: endpoint,
            body: request,
            headers: [
                "Authorization": "Bearer \(apiKey)"
            ],
            timeout: 30
        )

        // Extract translated text
        guard let translatedText = response.choices.first?.message.content,
              !translatedText.isEmpty
        else {
            throw TranscriptionError.emptyResponse
        }

        return translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private Helpers

    private func buildTranslationPrompt(
        sourceLanguage: Language?,
        targetLanguage: Language,
        formality: Formality?
    ) -> String {
        let formalityGuideline: String
        if let f = formality {
            switch f {
            case .formal:
                formalityGuideline = "\n- Use formal language and polite forms of address"
            case .informal:
                formalityGuideline = "\n- Use casual, informal language"
            case .neutral:
                formalityGuideline = ""
            }
        } else {
            formalityGuideline = ""
        }

        if let source = sourceLanguage {
            return """
            You are a professional translator. Translate the following text from \(source.displayName) to \(targetLanguage.displayName).

            Guidelines:
            - Preserve the original meaning and tone
            - Maintain proper grammar and punctuation in the target language
            - Keep formatting (paragraphs, lists) intact\(formalityGuideline)
            - Do not add any explanations or notes
            - Return only the translated text
            """
        } else {
            return """
            You are a professional translator. Detect the source language and translate the following text to \(targetLanguage.displayName).

            Guidelines:
            - Preserve the original meaning and tone
            - Maintain proper grammar and punctuation in the target language
            - Keep formatting (paragraphs, lists) intact\(formalityGuideline)
            - Do not add any explanations or notes
            - Return only the translated text
            """
        }
    }
}

// MARK: - Request/Response Models

private struct TranslationChatRequest: Encodable {
    public let model: String
    public let messages: [TranslationMessage]
    public let temperature: Double
    public let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct TranslationMessage: Codable {
    public let role: String
    public let content: String?  // Content can be null in some API responses

    // Use manual coding keys to ignore extra fields
    enum CodingKeys: String, CodingKey {
        case role
        case content
    }

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

private struct TranslationChatResponse: Decodable {
    public let choices: [TranslationChoice]

    // Only decode what we need, ignore other fields
    enum CodingKeys: String, CodingKey {
        case choices
    }

    struct TranslationChoice: Decodable {
        let message: TranslationMessage

        // Only decode message, ignore index and finish_reason
        enum CodingKeys: String, CodingKey {
            case message
        }
    }
}
