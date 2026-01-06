//
//  OpenAITranslationService.swift
//  SwiftSpeakCore
//
//  Shared OpenAI GPT translation service
//

import Foundation

/// OpenAI GPT translation service
public final class OpenAITranslationService: TranslationProvider {

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
        true
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

        let systemPrompt: String
        if let ctx = context, ctx.hasContent {
            systemPrompt = ctx.buildTranslationPrompt(to: targetLanguage, from: sourceLanguage)
        } else {
            systemPrompt = buildTranslationPrompt(
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                formality: formality
            )
        }

        let request = TranslationRequest(
            model: modelName,
            messages: [
                TranslationMessage(role: "system", content: systemPrompt),
                TranslationMessage(role: "user", content: text)
            ],
            temperature: 0.3,
            maxTokens: 4000
        )

        let response: TranslationResponse = try await httpClient.post(
            url: endpoint,
            body: request,
            headers: ["Authorization": "Bearer \(apiKey)"],
            timeout: 30
        )

        guard let translated = response.choices.first?.message.content,
              !translated.isEmpty
        else {
            throw TranscriptionError.emptyResponse
        }

        return translated.trimmingCharacters(in: .whitespacesAndNewlines)
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

private struct TranslationRequest: Encodable {
    let model: String
    let messages: [TranslationMessage]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

private struct TranslationMessage: Codable {
    let role: String
    let content: String?

    init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

private struct TranslationResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: TranslationMessage
    }
}
