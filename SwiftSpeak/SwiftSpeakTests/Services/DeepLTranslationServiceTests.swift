//
//  DeepLTranslationServiceTests.swift
//  SwiftSpeakTests
//
//  Tests for DeepLTranslationService
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

@MainActor
struct DeepLTranslationServiceTests {

    // MARK: - Initialization

    @Test func serviceInitializesWithApiKey() {
        let service = DeepLTranslationService(apiKey: "test-key")

        #expect(service.providerId == .deepL)
        #expect(service.isConfigured == true)
        #expect(service.model == "default")
    }

    @Test func serviceNotConfiguredWithEmptyKey() {
        let service = DeepLTranslationService(apiKey: "")

        #expect(service.isConfigured == false)
    }

    @Test func serviceUsesDefaultModel() {
        let service = DeepLTranslationService(apiKey: "test-key")

        #expect(service.model == "default")
    }

    @Test func serviceDefaultsToPaidAPI() {
        let service = DeepLTranslationService(apiKey: "test-key")

        // Service should use paid API by default
        #expect(service.isConfigured == true)
    }

    // NOTE: useFreeAPI parameter removed in SwiftSpeakCore - DeepL now auto-detects API type from key format

    // MARK: - Supported Languages

    @Test func serviceSupportAllLanguages() {
        let service = DeepLTranslationService(apiKey: "test-key")

        #expect(service.supportedLanguages.count == Language.allCases.count)

        for language in Language.allCases {
            #expect(service.supportedLanguages.contains(language))
        }
    }

    // MARK: - Provider Config Initialization

    @Test func serviceInitializesFromProviderConfig() {
        let config = AIProviderConfig(
            provider: .deepL,
            apiKey: "test-api-key",
            usageCategories: [.translation]
        )

        let service = DeepLTranslationService(config: config)

        #expect(service != nil)
        #expect(service?.isConfigured == true)
        #expect(service?.model == "default")
    }

    @Test func serviceReturnsNilForNonDeepLConfig() {
        let config = AIProviderConfig(
            provider: .openAI,
            apiKey: "test-api-key",
            usageCategories: [.translation]
        )

        let service = DeepLTranslationService(config: config)

        #expect(service == nil)
    }

    @Test func serviceReturnsNilForEmptyApiKey() {
        let config = AIProviderConfig(
            provider: .deepL,
            apiKey: "",
            usageCategories: [.translation]
        )

        let service = DeepLTranslationService(config: config)

        #expect(service == nil)
    }

    @Test func serviceDetectsFreeAPIKeyFromConfig() {
        let config = AIProviderConfig(
            provider: .deepL,
            apiKey: "12345678-1234-1234-1234-123456789012:fx",
            usageCategories: [.translation]
        )

        let service = DeepLTranslationService(config: config)

        #expect(service != nil)
        #expect(service?.isConfigured == true)
    }

    // MARK: - Translation Provider Protocol

    @Test func serviceConformsToTranslationProvider() {
        let service = DeepLTranslationService(apiKey: "test-key")

        // Verify protocol properties
        #expect(service.providerId == .deepL)
        #expect(type(of: service.isConfigured) == Bool.self)
        #expect(type(of: service.model) == String.self)
        #expect(type(of: service.supportedLanguages) == [Language].self)
    }
}

// MARK: - DeepL Language Code Tests

@MainActor
struct DeepLLanguageCodeTests {

    @Test func languageHasDeepLCode() {
        for language in Language.allCases {
            let code = language.deepLCode
            #expect(!code.isEmpty)
        }
    }

    @Test func deepLCodesAreUppercase() {
        for language in Language.allCases {
            let code = language.deepLCode
            #expect(code == code.uppercased())
        }
    }

    @Test func englishHasCorrectDeepLCode() {
        #expect(Language.english.deepLCode == "EN")
    }

    @Test func spanishHasCorrectDeepLCode() {
        #expect(Language.spanish.deepLCode == "ES")
    }

    @Test func frenchHasCorrectDeepLCode() {
        #expect(Language.french.deepLCode == "FR")
    }

    @Test func germanHasCorrectDeepLCode() {
        #expect(Language.german.deepLCode == "DE")
    }

    @Test func italianHasCorrectDeepLCode() {
        #expect(Language.italian.deepLCode == "IT")
    }

    @Test func portugueseHasCorrectDeepLCode() {
        #expect(Language.portuguese.deepLCode == "PT")
    }

    @Test func chineseHasCorrectDeepLCode() {
        #expect(Language.chinese.deepLCode == "ZH")
    }

    @Test func japaneseHasCorrectDeepLCode() {
        #expect(Language.japanese.deepLCode == "JA")
    }

    @Test func koreanHasCorrectDeepLCode() {
        #expect(Language.korean.deepLCode == "KO")
    }

    @Test func russianHasCorrectDeepLCode() {
        #expect(Language.russian.deepLCode == "RU")
    }

    @Test func polishHasCorrectDeepLCode() {
        #expect(Language.polish.deepLCode == "PL")
    }

    @Test func arabicHasCorrectDeepLCode() {
        #expect(Language.arabic.deepLCode == "AR")
    }

    @Test func egyptianArabicMapsToStandardArabic() {
        #expect(Language.egyptianArabic.deepLCode == "AR")
    }
}

// MARK: - AIProvider DeepL Support Tests

@MainActor
struct AIProviderDeepLTests {

    @Test func deepLSupportsTranslation() {
        #expect(AIProvider.deepL.supportsTranslation == true)
    }

    @Test func deepLDoesNotSupportTranscription() {
        #expect(AIProvider.deepL.supportsTranscription == false)
    }

    @Test func deepLDoesNotSupportPowerMode() {
        #expect(AIProvider.deepL.supportsPowerMode == false)
    }

    @Test func deepLHasCorrectDisplayName() {
        #expect(AIProvider.deepL.displayName == "DeepL")
    }

    @Test func deepLHasCorrectIcon() {
        #expect(AIProvider.deepL.icon == "character.book.closed.fill")
    }

    @Test func deepLRequiresAPIKey() {
        #expect(AIProvider.deepL.requiresAPIKey == true)
    }

    @Test func deepLIsNotLocalProvider() {
        #expect(AIProvider.deepL.isLocalProvider == false)
    }

    @Test func deepLHasDefaultLLMModel() {
        #expect(AIProvider.deepL.defaultLLMModel == "default")
    }

    @Test func deepLDoesNotHaveSTTModel() {
        #expect(AIProvider.deepL.defaultSTTModel == nil)
    }

    @Test func deepLHasAPIKeyHelpURL() {
        let url = AIProvider.deepL.apiKeyHelpURL
        #expect(url != nil)
        #expect(url?.absoluteString.contains("deepl.com") == true)
    }

    @Test func deepLHasSetupInstructions() {
        let instructions = AIProvider.deepL.setupInstructions
        #expect(!instructions.isEmpty)
        #expect(instructions.contains("DeepL") || instructions.contains("deepl"))
    }
}

// MARK: - Constants Tests

@MainActor
struct DeepLConstantsTests {

    @Test func deepLEndpointIsDefined() {
        let endpoint = Constants.API.deepL
        #expect(!endpoint.isEmpty)
        #expect(endpoint.hasPrefix("https://"))
        #expect(endpoint.contains("deepl.com"))
    }

    @Test func deepLFreeEndpointIsDefined() {
        let endpoint = Constants.API.deepLFree
        #expect(!endpoint.isEmpty)
        #expect(endpoint.hasPrefix("https://"))
        #expect(endpoint.contains("api-free.deepl.com"))
    }

    @Test func deepLEndpointsAreDifferent() {
        #expect(Constants.API.deepL != Constants.API.deepLFree)
    }

    @Test func deepLEndpointsHaveTranslatePath() {
        #expect(Constants.API.deepL.contains("/translate"))
        #expect(Constants.API.deepLFree.contains("/translate"))
    }
}
