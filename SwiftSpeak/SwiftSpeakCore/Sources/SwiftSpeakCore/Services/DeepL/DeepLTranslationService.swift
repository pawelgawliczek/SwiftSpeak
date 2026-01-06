//
//  DeepLTranslationService.swift
//  SwiftSpeakCore
//
//  Shared DeepL translation service
//

import Foundation

/// DeepL translation service
public final class DeepLTranslationService: TranslationProvider {

    public let providerId: AIProvider = .deepL
    public var isConfigured: Bool { !apiKey.isEmpty }
    public var model: String { "deepl" }
    public var supportedLanguages: [Language] { Language.allCases }
    public var supportsFormality: Bool { true }

    private let apiKey: String
    private let httpClient: HTTPClient
    private var endpoint: URL {
        // Free keys use free-api subdomain
        let baseURL = apiKey.hasSuffix(":fx") ? Constants.API.deepLFree : Constants.API.deepL
        return URL(string: baseURL)!
    }

    public init(apiKey: String, httpClient: HTTPClient = .shared) {
        self.apiKey = apiKey
        self.httpClient = httpClient
    }

    public convenience init?(config: AIProviderConfig) {
        guard config.provider == .deepL, !config.apiKey.isEmpty else { return nil }
        self.init(apiKey: config.apiKey)
    }

    public func translate(text: String, from sourceLanguage: Language?, to targetLanguage: Language, formality: Formality?, context: PromptContext?) async throws -> String {
        guard isConfigured else { throw TranscriptionError.apiKeyMissing }

        var request = DeepLRequest(
            text: [text],
            targetLang: targetLanguage.deepLCode ?? targetLanguage.rawValue.uppercased(),
            sourceLang: sourceLanguage?.deepLCode ?? sourceLanguage?.rawValue.uppercased()
        )

        // Add formality if supported for target language
        if let formality = formality, targetLanguage.supportsFormality {
            switch formality {
            case .formal: request.formality = "more"
            case .informal: request.formality = "less"
            case .neutral: break
            }
        }

        let response: DeepLResponse = try await httpClient.post(
            url: endpoint,
            body: request,
            headers: ["Authorization": "DeepL-Auth-Key \(apiKey)"],
            timeout: 30
        )

        guard let translation = response.translations.first?.text, !translation.isEmpty else {
            throw TranscriptionError.emptyResponse
        }

        return translation
    }
}

private struct DeepLRequest: Encodable {
    let text: [String]
    let targetLang: String
    var sourceLang: String?
    var formality: String?

    enum CodingKeys: String, CodingKey {
        case text
        case targetLang = "target_lang"
        case sourceLang = "source_lang"
        case formality
    }
}

private struct DeepLResponse: Decodable {
    let translations: [DeepLTranslation]
}

private struct DeepLTranslation: Decodable {
    let text: String
}

extension Language {
    var supportsFormality: Bool {
        switch self {
        case .german, .french, .italian, .spanish, .portuguese, .russian, .polish:
            return true
        default:
            return false
        }
    }
}
