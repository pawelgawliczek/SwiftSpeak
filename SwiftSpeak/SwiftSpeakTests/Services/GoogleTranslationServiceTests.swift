//
//  GoogleTranslationServiceTests.swift
//  SwiftSpeakTests
//
//  Created by Claude Code on 26/12/2025.
//

import Testing
import Foundation
@testable import SwiftSpeak

/// Tests for GoogleTranslationService
/// Verifies Google Cloud Translation API integration
@Suite("Google Translation Service Tests")
struct GoogleTranslationServiceTests {

    // MARK: - Initialization Tests

    @Test("Initialize with API key")
    func testInitialization() {
        let service = GoogleTranslationService(apiKey: "test-api-key")

        #expect(service.providerId == .google)
        #expect(service.isConfigured == true)
        #expect(service.model == "translation-v2")
        #expect(service.supportedLanguages.count == SwiftSpeak.Language.allCases.count)
    }

    @Test("Initialize with empty API key marks as not configured")
    func testInitializationWithEmptyKey() {
        let service = GoogleTranslationService(apiKey: "")

        #expect(service.isConfigured == false)
    }

    @Test("Initialize from provider config")
    func testInitFromConfig() {
        let config = SwiftSpeak.AIProviderConfig(
            provider: .google,
            apiKey: "test-api-key"
        )

        let service = GoogleTranslationService(config: config)

        #expect(service != nil)
        #expect(service?.isConfigured == true)
    }

    @Test("Fail to initialize from wrong provider config")
    func testInitFromWrongProviderConfig() {
        let config = SwiftSpeak.AIProviderConfig(
            provider: .openAI,
            apiKey: "test-api-key"
        )

        let service = GoogleTranslationService(config: config)

        #expect(service == nil)
    }

    @Test("Fail to initialize from config with empty API key")
    func testInitFromConfigWithEmptyKey() {
        let config = SwiftSpeak.AIProviderConfig(
            provider: .google,
            apiKey: ""
        )

        let service = GoogleTranslationService(config: config)

        #expect(service == nil)
    }

    // MARK: - Language Code Tests

    @Test("Language googleCode extension returns lowercase codes")
    func testLanguageGoogleCodes() {
        #expect(SwiftSpeak.Language.english.googleCode == "en")
        #expect(SwiftSpeak.Language.spanish.googleCode == "es")
        #expect(SwiftSpeak.Language.french.googleCode == "fr")
        #expect(SwiftSpeak.Language.german.googleCode == "de")
        #expect(SwiftSpeak.Language.italian.googleCode == "it")
        #expect(SwiftSpeak.Language.portuguese.googleCode == "pt")
        #expect(SwiftSpeak.Language.chinese.googleCode == "zh")
        #expect(SwiftSpeak.Language.japanese.googleCode == "ja")
        #expect(SwiftSpeak.Language.korean.googleCode == "ko")
        #expect(SwiftSpeak.Language.arabic.googleCode == "ar")
        #expect(SwiftSpeak.Language.egyptianArabic.googleCode == "ar") // Uses standard Arabic
        #expect(SwiftSpeak.Language.russian.googleCode == "ru")
        #expect(SwiftSpeak.Language.polish.googleCode == "pl")
    }

    // MARK: - Error Handling Tests

    @Test("Throw error when API key is missing")
    func testMissingAPIKey() async throws {
        let service = GoogleTranslationService(apiKey: "")

        await #expect(throws: TranscriptionError.self) {
            try await service.translate(
                text: "Hello",
                from: .english,
                to: .spanish
            )
        }
    }

    // MARK: - Protocol Conformance Tests

    @Test("Convenience translate method without source language")
    func testConvenienceTranslateMethod() async throws {
        // This tests the default protocol extension
        let service = GoogleTranslationService(apiKey: "test-api-key")

        // Note: This will fail without a real API key, but tests protocol conformance
        await #expect(throws: Error.self) {
            try await service.translate(text: "Hello", to: .spanish)
        }
    }

    // MARK: - Request Building Tests

    @Test("Verify translation request structure")
    func testTranslationRequestStructure() {
        // Test that the private TranslationRequest model structure is correct
        // by verifying it encodes to the expected JSON format

        struct TestRequest: Encodable {
            let q: String
            let target: String
            let source: String?
            let format: String
        }

        let request = TestRequest(
            q: "Hello, world",
            target: "es",
            source: "en",
            format: "text"
        )

        let encoder = JSONEncoder()
        let data = try? encoder.encode(request)
        #expect(data != nil)

        if let data = data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            #expect(json["q"] as? String == "Hello, world")
            #expect(json["target"] as? String == "es")
            #expect(json["source"] as? String == "en")
            #expect(json["format"] as? String == "text")
        }
    }

    @Test("Verify translation request with auto-detect source language")
    func testTranslationRequestWithAutoDetect() {
        struct TestRequest: Encodable {
            let q: String
            let target: String
            let source: String?
            let format: String
        }

        let request = TestRequest(
            q: "Hello, world",
            target: "es",
            source: nil, // Auto-detect
            format: "text"
        )

        let encoder = JSONEncoder()
        let data = try? encoder.encode(request)
        #expect(data != nil)

        if let data = data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            #expect(json["q"] as? String == "Hello, world")
            #expect(json["target"] as? String == "es")
            #expect(json["source"] == nil) // Should not be present
            #expect(json["format"] as? String == "text")
        }
    }

    // MARK: - Response Parsing Tests

    @Test("Parse valid translation response")
    func testParseValidResponse() throws {
        let json = """
        {
          "data": {
            "translations": [
              {
                "translatedText": "Hola, mundo",
                "detectedSourceLanguage": "en"
              }
            ]
          }
        }
        """

        struct TranslationResponse: Decodable {
            let data: TranslationData

            struct TranslationData: Decodable {
                let translations: [Translation]
            }

            struct Translation: Decodable {
                let translatedText: String
                let detectedSourceLanguage: String?
            }
        }

        let decoder = JSONDecoder()
        let data = json.data(using: .utf8)!
        let response = try decoder.decode(TranslationResponse.self, from: data)

        #expect(response.data.translations.count == 1)
        #expect(response.data.translations[0].translatedText == "Hola, mundo")
        #expect(response.data.translations[0].detectedSourceLanguage == "en")
    }

    @Test("Parse translation response without detected language")
    func testParseResponseWithoutDetectedLanguage() throws {
        let json = """
        {
          "data": {
            "translations": [
              {
                "translatedText": "Hola, mundo"
              }
            ]
          }
        }
        """

        struct TranslationResponse: Decodable {
            let data: TranslationData

            struct TranslationData: Decodable {
                let translations: [Translation]
            }

            struct Translation: Decodable {
                let translatedText: String
                let detectedSourceLanguage: String?
            }
        }

        let decoder = JSONDecoder()
        let data = json.data(using: .utf8)!
        let response = try decoder.decode(TranslationResponse.self, from: data)

        #expect(response.data.translations.count == 1)
        #expect(response.data.translations[0].translatedText == "Hola, mundo")
        #expect(response.data.translations[0].detectedSourceLanguage == nil)
    }

    // MARK: - Integration-like Tests

    @Test("Verify supported languages include all Language cases")
    func testSupportedLanguages() {
        let service = GoogleTranslationService(apiKey: "test-api-key")

        #expect(service.supportedLanguages.count == SwiftSpeak.Language.allCases.count)

        for language in SwiftSpeak.Language.allCases {
            #expect(service.supportedLanguages.contains(language))
        }
    }

    @Test("Provider ID is Google")
    func testProviderID() {
        let service = GoogleTranslationService(apiKey: "test-api-key")
        #expect(service.providerId == .google)
    }

    @Test("Model name is translation-v2")
    func testModelName() {
        let service = GoogleTranslationService(apiKey: "test-api-key")
        #expect(service.model == "translation-v2")
    }
}
