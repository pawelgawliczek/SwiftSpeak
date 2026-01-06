//
//  AzureTranslatorService.swift
//  SwiftSpeakCore
//
//  Shared Azure Translator service
//

import Foundation

/// Azure Translator service
public final class AzureTranslatorService: TranslationProvider {

    public let providerId: AIProvider = .azure
    public var isConfigured: Bool { !apiKey.isEmpty && !region.isEmpty }
    public var model: String { "azure-translator" }
    public var supportedLanguages: [Language] { Language.allCases }
    public var supportsFormality: Bool { false }

    private let apiKey: String
    private let region: String
    private let httpClient: HTTPClient

    public init(apiKey: String, region: String, httpClient: HTTPClient = .shared) {
        self.apiKey = apiKey
        self.region = region
        self.httpClient = httpClient
    }

    public convenience init?(config: AIProviderConfig) {
        guard config.provider == .azure,
              !config.apiKey.isEmpty,
              let region = config.azureRegion,
              !region.isEmpty else { return nil }
        self.init(apiKey: config.apiKey, region: region)
    }

    public func translate(text: String, from sourceLanguage: Language?, to targetLanguage: Language, formality: Formality?, context: PromptContext?) async throws -> String {
        guard isConfigured else { throw TranscriptionError.apiKeyMissing }

        var urlString = "\(Constants.API.azureTranslator)?api-version=3.0&to=\(targetLanguage.azureCode ?? targetLanguage.rawValue)"
        if let source = sourceLanguage {
            urlString += "&from=\(source.azureCode ?? source.rawValue)"
        }

        guard let url = URL(string: urlString) else {
            throw TranscriptionError.networkError("Invalid URL")
        }

        let requestBody = [["Text": text]]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue(region, forHTTPHeaderField: "Ocp-Apim-Subscription-Region")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw TranscriptionError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500, message: nil)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = json.first,
              let translations = first["translations"] as? [[String: Any]],
              let translation = translations.first?["text"] as? String,
              !translation.isEmpty else {
            throw TranscriptionError.emptyResponse
        }

        return translation
    }
}
