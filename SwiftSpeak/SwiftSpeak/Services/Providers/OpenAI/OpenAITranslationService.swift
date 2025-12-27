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

    let providerId: AIProvider = .openAI

    var isConfigured: Bool {
        !apiKey.isEmpty
    }

    var model: String {
        modelName
    }

    var supportedLanguages: [Language] {
        Language.allCases
    }

    var supportsFormality: Bool {
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

    // MARK: - Translation

    func translate(
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
    let model: String
    let messages: [TranslationMessage]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct TranslationMessage: Codable {
    let role: String
    let content: String
}

private struct TranslationChatResponse: Decodable {
    let id: String
    let choices: [TranslationChoice]
    let usage: TranslationUsage?

    struct TranslationChoice: Decodable {
        let index: Int
        let message: TranslationMessage
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }

    struct TranslationUsage: Decodable {
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
