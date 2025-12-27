//
//  AzureTranslatorServiceTests.swift
//  SwiftSpeakTests
//
//  Created by Claude Code on 26/12/2025.
//

import Testing
import Foundation
@testable import SwiftSpeak

/// Tests for Azure Translator service
struct AzureTranslatorServiceTests {

    // MARK: - Initialization Tests

    @Test("Initialize with API key and region")
    func initializeWithCredentials() {
        let service = AzureTranslatorService(
            apiKey: "test-key",
            region: "eastus"
        )

        #expect(service.providerId == .azure)
        #expect(service.isConfigured == true)
        #expect(service.model == "default")
        #expect(service.supportedLanguages.count > 0)
    }

    @Test("Initialize with empty credentials - not configured")
    func initializeWithEmptyCredentials() {
        let service = AzureTranslatorService(
            apiKey: "",
            region: ""
        )

        #expect(service.providerId == .azure)
        #expect(service.isConfigured == false)
    }

    @Test("Initialize with missing region - not configured")
    func initializeWithMissingRegion() {
        let service = AzureTranslatorService(
            apiKey: "test-key",
            region: ""
        )

        #expect(service.isConfigured == false)
    }

    @Test("Initialize from valid provider config")
    func initializeFromValidConfig() {
        let config = AIProviderConfig(
            provider: .azure,
            apiKey: "test-key",
            azureRegion: "westeurope"
        )

        let service = AzureTranslatorService(config: config)

        #expect(service != nil)
        #expect(service?.isConfigured == true)
        #expect(service?.providerId == .azure)
    }

    @Test("Initialize from config without region returns nil")
    func initializeFromConfigWithoutRegion() {
        let config = AIProviderConfig(
            provider: .azure,
            apiKey: "test-key",
            azureRegion: nil
        )

        let service = AzureTranslatorService(config: config)

        #expect(service == nil)
    }

    @Test("Initialize from wrong provider config returns nil")
    func initializeFromWrongProviderConfig() {
        let config = AIProviderConfig(
            provider: .openAI,
            apiKey: "test-key"
        )

        let service = AzureTranslatorService(config: config)

        #expect(service == nil)
    }

    @Test("Initialize from config with empty API key returns nil")
    func initializeFromConfigWithEmptyKey() {
        let config = AIProviderConfig(
            provider: .azure,
            apiKey: "",
            azureRegion: "eastus"
        )

        let service = AzureTranslatorService(config: config)

        #expect(service == nil)
    }

    // MARK: - Configuration Tests

    @Test("Supports all Language enum cases")
    func supportsAllLanguages() {
        let service = AzureTranslatorService(
            apiKey: "test-key",
            region: "eastus"
        )

        #expect(service.supportedLanguages == Language.allCases)
    }

    @Test("Model is always 'default'")
    func modelIsDefault() {
        let service = AzureTranslatorService(
            apiKey: "test-key",
            region: "eastus"
        )

        #expect(service.model == "default")
    }

    // MARK: - Translation Tests (Error Cases)

    @Test("Translate throws error when not configured")
    func translateThrowsWhenNotConfigured() async {
        let service = AzureTranslatorService(
            apiKey: "",
            region: ""
        )

        await #expect(throws: TranscriptionError.self) {
            try await service.translate(
                text: "Hello",
                from: .english,
                to: .spanish
            )
        }
    }

    @Test("Translate throws error when API key missing")
    func translateThrowsWhenAPIKeyMissing() async {
        let service = AzureTranslatorService(
            apiKey: "",
            region: "eastus"
        )

        await #expect(throws: TranscriptionError.self) {
            try await service.translate(
                text: "Hello",
                from: .english,
                to: .spanish
            )
        }
    }

    @Test("Translate throws error when region missing")
    func translateThrowsWhenRegionMissing() async {
        let service = AzureTranslatorService(
            apiKey: "test-key",
            region: ""
        )

        await #expect(throws: TranscriptionError.self) {
            try await service.translate(
                text: "Hello",
                from: .english,
                to: .spanish
            )
        }
    }

    // MARK: - Language Code Mapping Tests

    @Test("English maps to correct Azure code")
    func englishLanguageCode() {
        #expect(Language.english.azureCode == "en")
    }

    @Test("Spanish maps to correct Azure code")
    func spanishLanguageCode() {
        #expect(Language.spanish.azureCode == "es")
    }

    @Test("French maps to correct Azure code")
    func frenchLanguageCode() {
        #expect(Language.french.azureCode == "fr")
    }

    @Test("German maps to correct Azure code")
    func germanLanguageCode() {
        #expect(Language.german.azureCode == "de")
    }

    @Test("Italian maps to correct Azure code")
    func italianLanguageCode() {
        #expect(Language.italian.azureCode == "it")
    }

    @Test("Portuguese maps to correct Azure code")
    func portugueseLanguageCode() {
        #expect(Language.portuguese.azureCode == "pt")
    }

    @Test("Chinese maps to correct Azure code")
    func chineseLanguageCode() {
        #expect(Language.chinese.azureCode == "zh")
    }

    @Test("Japanese maps to correct Azure code")
    func japaneseLanguageCode() {
        #expect(Language.japanese.azureCode == "ja")
    }

    @Test("Korean maps to correct Azure code")
    func koreanLanguageCode() {
        #expect(Language.korean.azureCode == "ko")
    }

    @Test("Arabic maps to correct Azure code")
    func arabicLanguageCode() {
        #expect(Language.arabic.azureCode == "ar")
    }

    @Test("Russian maps to correct Azure code")
    func russianLanguageCode() {
        #expect(Language.russian.azureCode == "ru")
    }

    @Test("Polish maps to correct Azure code")
    func polishLanguageCode() {
        #expect(Language.polish.azureCode == "pl")
    }

    // MARK: - Provider Metadata Tests

    @Test("Azure provider has correct metadata")
    func azureProviderMetadata() {
        #expect(AIProvider.azure.displayName == "Azure Translator")
        #expect(AIProvider.azure.shortName == "Azure")
        #expect(AIProvider.azure.icon == "cloud.fill")
        #expect(AIProvider.azure.supportsTranslation == true)
        #expect(AIProvider.azure.supportsTranscription == false)
        #expect(AIProvider.azure.supportsPowerMode == false)
    }

    @Test("Azure region enum has correct cases")
    func azureRegionCases() {
        #expect(AzureRegion.eastUS.rawValue == "eastus")
        #expect(AzureRegion.eastUS2.rawValue == "eastus2")
        #expect(AzureRegion.westUS.rawValue == "westus")
        #expect(AzureRegion.westEurope.rawValue == "westeurope")
        #expect(AzureRegion.northEurope.rawValue == "northeurope")
        #expect(AzureRegion.global.rawValue == "global")
    }

    @Test("Azure region display names are formatted correctly")
    func azureRegionDisplayNames() {
        #expect(AzureRegion.eastUS.displayName == "East US")
        #expect(AzureRegion.westEurope.displayName == "West Europe")
        #expect(AzureRegion.southeastAsia.displayName == "Southeast Asia")
    }

    // MARK: - Constants Tests

    @Test("Azure Translator endpoint is configured")
    func azureEndpointConfigured() {
        #expect(!Constants.API.azureTranslator.isEmpty)
        #expect(Constants.API.azureTranslator.contains("api.cognitive.microsofttranslator.com"))
    }
}
