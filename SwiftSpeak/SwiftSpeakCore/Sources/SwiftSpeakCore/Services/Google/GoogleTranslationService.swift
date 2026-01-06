//
//  GoogleTranslationService.swift
//  SwiftSpeakCore
//
//  Shared Google Cloud Translation service
//

import Foundation

/// Google Cloud Translation service
public final class GoogleTranslationService: TranslationProvider {

    public let providerId: AIProvider = .google
    public var isConfigured: Bool { !apiKey.isEmpty }
    public var model: String { "nmt" }
    public var supportedLanguages: [Language] { Language.allCases }
    public var supportsFormality: Bool { false }

    private let apiKey: String
    private let httpClient: HTTPClient

    public init(apiKey: String, httpClient: HTTPClient = .shared) {
        self.apiKey = apiKey
        self.httpClient = httpClient
    }

    public convenience init?(config: AIProviderConfig) {
        guard config.provider == .google, !config.apiKey.isEmpty else { return nil }
        self.init(apiKey: config.apiKey)
    }

    public func translate(text: String, from sourceLanguage: Language?, to targetLanguage: Language, formality: Formality?, context: PromptContext?) async throws -> String {
        guard isConfigured else { throw TranscriptionError.apiKeyMissing }

        let endpoint = URL(string: "\(Constants.API.googleTranslation)?key=\(apiKey)")!

        var requestBody: [String: Any] = [
            "q": text,
            "target": targetLanguage.googleCode ?? targetLanguage.rawValue,
            "format": "text"
        ]

        if let source = sourceLanguage {
            requestBody["source"] = source.googleCode ?? source.rawValue
        }

        let request = GoogleTranslateRequest(
            q: text,
            target: targetLanguage.googleCode ?? targetLanguage.rawValue,
            source: sourceLanguage?.googleCode ?? sourceLanguage?.rawValue
        )

        let response: GoogleTranslateResponse = try await httpClient.post(
            url: endpoint,
            body: request,
            timeout: 30
        )

        guard let translation = response.data.translations.first?.translatedText, !translation.isEmpty else {
            throw TranscriptionError.emptyResponse
        }

        return translation
    }
}

private struct GoogleTranslateRequest: Encodable {
    let q: String
    let target: String
    let source: String?
    let format: String = "text"
}

private struct GoogleTranslateResponse: Decodable {
    let data: GoogleTranslateData
}

private struct GoogleTranslateData: Decodable {
    let translations: [GoogleTranslation]
}

private struct GoogleTranslation: Decodable {
    let translatedText: String
}
