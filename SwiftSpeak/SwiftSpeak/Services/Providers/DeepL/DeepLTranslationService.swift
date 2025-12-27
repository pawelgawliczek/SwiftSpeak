//
//  DeepLTranslationService.swift
//  SwiftSpeak
//
//  Created by Claude Code on 26/12/2025.
//

import Foundation

/// DeepL translation service
/// Uses DeepL API for high-quality neural machine translation
final class DeepLTranslationService: TranslationProvider {

    // MARK: - TranslationProvider

    let providerId: AIProvider = .deepL

    var isConfigured: Bool {
        !apiKey.isEmpty
    }

    var model: String {
        "default"
    }

    var supportedLanguages: [Language] {
        Language.allCases
    }

    // MARK: - Properties

    private let apiKey: String
    private let useFreeAPI: Bool
    private let apiClient: APIClient

    /// DeepL endpoint (paid or free)
    private var endpoint: URL {
        URL(string: useFreeAPI ? Constants.API.deepLFree : Constants.API.deepL)!
    }

    // MARK: - Initialization

    /// Initialize with API key
    /// - Parameters:
    ///   - apiKey: DeepL API key
    ///   - useFreeAPI: Whether to use the free API endpoint (default: false)
    ///   - apiClient: API client instance
    init(
        apiKey: String,
        useFreeAPI: Bool = false,
        apiClient: APIClient = .shared
    ) {
        self.apiKey = apiKey
        self.useFreeAPI = useFreeAPI
        self.apiClient = apiClient
    }

    /// Initialize from provider configuration
    /// - Parameter config: AI provider configuration
    convenience init?(config: AIProviderConfig) {
        guard config.provider == .deepL,
              !config.apiKey.isEmpty
        else { return nil }

        // Check if the API key is for the free tier (ends with ":fx")
        let isFreeKey = config.apiKey.hasSuffix(":fx")
        self.init(apiKey: config.apiKey, useFreeAPI: isFreeKey)
    }

    // MARK: - Translation

    func translate(
        text: String,
        from sourceLanguage: Language?,
        to targetLanguage: Language
    ) async throws -> String {
        guard isConfigured else {
            throw TranscriptionError.apiKeyMissing
        }

        // Build request
        let request = DeepLTranslateRequest(
            text: [text],
            targetLang: targetLanguage.deepLCode,
            sourceLang: sourceLanguage?.deepLCode
        )

        // Make API call
        let response: DeepLTranslateResponse = try await apiClient.post(
            url: endpoint,
            body: request,
            headers: [
                "Authorization": "DeepL-Auth-Key \(apiKey)"
            ],
            timeout: 30
        )

        // Extract translated text
        guard let translatedText = response.translations.first?.text,
              !translatedText.isEmpty
        else {
            throw TranscriptionError.emptyResponse
        }

        return translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Request/Response Models

private struct DeepLTranslateRequest: Encodable {
    let text: [String]
    let targetLang: String
    let sourceLang: String?

    enum CodingKeys: String, CodingKey {
        case text
        case targetLang = "target_lang"
        case sourceLang = "source_lang"
    }
}

private struct DeepLTranslateResponse: Decodable {
    let translations: [DeepLTranslation]

    struct DeepLTranslation: Decodable {
        let detectedSourceLanguage: String?
        let text: String

        enum CodingKeys: String, CodingKey {
            case detectedSourceLanguage = "detected_source_language"
            case text
        }
    }
}
