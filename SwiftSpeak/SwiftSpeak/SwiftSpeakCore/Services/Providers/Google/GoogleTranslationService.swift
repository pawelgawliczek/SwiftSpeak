//
//  GoogleTranslationService.swift
//  SwiftSpeak
//
//  Created by Claude Code on 26/12/2025.
//

import Foundation

/// Google Cloud Translation API service
/// Uses Google Cloud Translation API v2 for text translation
final class GoogleTranslationService: TranslationProvider {

    // MARK: - TranslationProvider

    public let providerId: AIProvider = .google

    public var isConfigured: Bool {
        !apiKey.isEmpty
    }

    public var model: String {
        "translation-v2"
    }

    public var supportedLanguages: [Language] {
        Language.allCases
    }

    // MARK: - Properties

    private let apiKey: String
    private let apiClient: APIClient

    /// Google Cloud Translation API v2 endpoint
    private let endpoint = URL(string: Constants.API.googleTranslation)!

    // MARK: - Initialization

    /// Initialize with API key
    /// - Parameters:
    ///   - apiKey: Google Cloud API key
    ///   - apiClient: API client instance
    public init(
        apiKey: String,
        apiClient: APIClient = .shared
    ) {
        self.apiKey = apiKey
        self.apiClient = apiClient
    }

    /// Initialize from provider configuration
    /// - Parameter config: AI provider configuration
    convenience init?(config: AIProviderConfig) {
        guard config.provider == .google,
              !config.apiKey.isEmpty
        else { return nil }

        self.init(apiKey: config.apiKey)
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

        // Note: Google Translation API v2 does not support formality parameter natively
        // The formality and context parameters are accepted for protocol conformance
        // but are not used in the API call

        // Build request
        let request = TranslationRequest(
            q: text,
            target: targetLanguage.googleCode,
            source: sourceLanguage?.googleCode,
            format: "text"
        )

        // Make API call
        // Google Cloud uses x-goog-api-key header (NOT Bearer authorization)
        let response: TranslationResponse = try await apiClient.post(
            url: endpoint,
            body: request,
            headers: [
                "x-goog-api-key": apiKey
            ],
            timeout: 30
        )

        // Extract translated text
        guard let translation = response.data.translations.first,
              !translation.translatedText.isEmpty
        else {
            throw TranscriptionError.emptyResponse
        }

        return translation.translatedText
    }
}

// MARK: - Request/Response Models

private struct TranslationRequest: Encodable {
    public let q: String
    public let target: String
    public let source: String?
    public let format: String

    enum CodingKeys: String, CodingKey {
        case q
        case target
        case source
        case format
    }
}

private struct TranslationResponse: Decodable {
    public let data: TranslationData

    struct TranslationData: Decodable {
        let translations: [Translation]
    }

    struct Translation: Decodable {
        let translatedText: String
        let detectedSourceLanguage: String?
    }
}
