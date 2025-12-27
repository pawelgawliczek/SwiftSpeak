//
//  AzureTranslatorService.swift
//  SwiftSpeak
//
//  Created by Claude Code on 26/12/2025.
//

import Foundation

/// Azure Translator service
/// Uses Microsoft Azure Cognitive Services Translator API
final class AzureTranslatorService: TranslationProvider {

    // MARK: - TranslationProvider

    let providerId: AIProvider = .azure

    var isConfigured: Bool {
        !apiKey.isEmpty && !region.isEmpty
    }

    var model: String {
        "default"
    }

    var supportedLanguages: [Language] {
        Language.allCases
    }

    // MARK: - Properties

    private let apiKey: String
    private let region: String
    private let apiClient: APIClient

    /// Azure Translator endpoint
    private let baseURL = Constants.API.azureTranslator

    // MARK: - Initialization

    /// Initialize with API key and region
    /// - Parameters:
    ///   - apiKey: Azure Translator subscription key
    ///   - region: Azure region (e.g., "eastus", "westeurope")
    ///   - apiClient: API client instance
    init(
        apiKey: String,
        region: String,
        apiClient: APIClient = .shared
    ) {
        self.apiKey = apiKey
        self.region = region
        self.apiClient = apiClient
    }

    /// Initialize from provider configuration
    /// - Parameter config: AI provider configuration
    convenience init?(config: AIProviderConfig) {
        guard config.provider == .azure,
              !config.apiKey.isEmpty,
              let region = config.azureRegion,
              !region.isEmpty
        else { return nil }

        self.init(apiKey: config.apiKey, region: region)
    }

    // MARK: - Translation

    func translate(
        text: String,
        from sourceLanguage: Language?,
        to targetLanguage: Language
    ) async throws -> String {
        guard isConfigured else {
            throw TranscriptionError.providerNotConfigured
        }

        // Build endpoint URL with query parameters
        var urlComponents = URLComponents(string: baseURL)!
        var queryItems = [
            URLQueryItem(name: "api-version", value: "3.0"),
            URLQueryItem(name: "to", value: targetLanguage.azureCode)
        ]

        // Add source language if specified
        if let sourceLanguage = sourceLanguage {
            queryItems.append(URLQueryItem(name: "from", value: sourceLanguage.azureCode))
        }

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw TranscriptionError.unexpectedResponse("Failed to construct URL")
        }

        // Build request body - Azure requires an ARRAY of text objects
        let request = AzureTranslationRequest(text: text)

        // Make API call with Azure-specific headers
        let response: [AzureTranslationResponse] = try await apiClient.post(
            url: url,
            body: [request],
            headers: [
                "Ocp-Apim-Subscription-Key": apiKey,
                "Ocp-Apim-Subscription-Region": region
            ],
            timeout: 30
        )

        // Extract translated text from response
        guard let firstResult = response.first,
              let firstTranslation = firstResult.translations.first,
              !firstTranslation.text.isEmpty
        else {
            throw TranscriptionError.emptyResponse
        }

        return firstTranslation.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Request/Response Models

/// Azure Translator request body (single text item)
private struct AzureTranslationRequest: Encodable {
    let text: String
}

/// Azure Translator response structure
private struct AzureTranslationResponse: Decodable {
    let translations: [Translation]
    let detectedLanguage: DetectedLanguage?

    struct Translation: Decodable {
        let text: String
        let to: String
    }

    struct DetectedLanguage: Decodable {
        let language: String
        let score: Double
    }
}
