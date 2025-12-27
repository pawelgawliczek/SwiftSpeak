//
//  OpenAITranscriptionServiceTests.swift
//  SwiftSpeakTests
//
//  Comprehensive tests for OpenAITranscriptionService
//

import Testing
@testable import SwiftSpeak

// MARK: - Initialization Tests

@Suite("OpenAITranscriptionService - Initialization")
struct OpenAITranscriptionServiceInitTests {

    @Test("Provider ID is OpenAI")
    func providerIdIsOpenAI() {
        let service = OpenAITranscriptionService(apiKey: "test-key")

        #expect(service.providerId == .openAI)
    }

    @Test("Default model is whisper-1")
    func defaultModelIsWhisper1() {
        let service = OpenAITranscriptionService(apiKey: "test-key")

        #expect(service.model == "whisper-1")
    }

    @Test("Custom model is preserved")
    func customModelPreserved() {
        let service = OpenAITranscriptionService(apiKey: "test-key", model: "whisper-large-v3")

        #expect(service.model == "whisper-large-v3")
    }

    @Test("Is configured with API key")
    func isConfiguredWithApiKey() {
        let service = OpenAITranscriptionService(apiKey: "sk-test123")

        #expect(service.isConfigured == true)
    }

    @Test("Is not configured with empty API key")
    func notConfiguredWithEmptyKey() {
        let service = OpenAITranscriptionService(apiKey: "")

        #expect(service.isConfigured == false)
    }
}

// MARK: - Config Initialization Tests

@Suite("OpenAITranscriptionService - Config Initialization")
struct OpenAITranscriptionServiceConfigInitTests {

    @Test("Init from valid config succeeds")
    func initFromValidConfig() {
        let config = AIProviderConfig(
            provider: .openAI,
            apiKey: "sk-test123",
            usageCategories: [.transcription],
            transcriptionModel: "whisper-1"
        )

        let service = OpenAITranscriptionService(config: config)

        #expect(service != nil)
        #expect(service?.providerId == .openAI)
        #expect(service?.model == "whisper-1")
    }

    @Test("Init from config with custom model")
    func initFromConfigWithCustomModel() {
        let config = AIProviderConfig(
            provider: .openAI,
            apiKey: "sk-test123",
            usageCategories: [.transcription],
            transcriptionModel: "whisper-large"
        )

        let service = OpenAITranscriptionService(config: config)

        #expect(service?.model == "whisper-large")
    }

    @Test("Init from config without model uses default")
    func initFromConfigWithoutModelUsesDefault() {
        let config = AIProviderConfig(
            provider: .openAI,
            apiKey: "sk-test123",
            usageCategories: [.transcription],
            transcriptionModel: nil
        )

        let service = OpenAITranscriptionService(config: config)

        #expect(service?.model == "whisper-1")
    }

    @Test("Init from wrong provider returns nil")
    func initFromWrongProviderReturnsNil() {
        let config = AIProviderConfig(
            provider: .anthropic, // Wrong provider
            apiKey: "sk-test123",
            usageCategories: [.transcription]
        )

        let service = OpenAITranscriptionService(config: config)

        #expect(service == nil)
    }

    @Test("Init from empty API key returns nil")
    func initFromEmptyApiKeyReturnsNil() {
        let config = AIProviderConfig(
            provider: .openAI,
            apiKey: "", // Empty
            usageCategories: [.transcription]
        )

        let service = OpenAITranscriptionService(config: config)

        #expect(service == nil)
    }
}

// MARK: - Transcription Error Tests

@Suite("OpenAITranscriptionService - Transcription Errors")
struct OpenAITranscriptionServiceErrorTests {

    @Test("Transcription with unconfigured service throws error")
    func transcriptionUnconfiguredThrowsError() async {
        let service = OpenAITranscriptionService(apiKey: "")
        let fakeURL = URL(fileURLWithPath: "/tmp/test.m4a")

        do {
            _ = try await service.transcribe(audioURL: fakeURL, language: nil, promptHint: nil)
            #expect(Bool(false), "Should have thrown error")
        } catch let error as TranscriptionError {
            #expect(error == .apiKeyMissing)
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    @Test("Transcription with nonexistent file throws error")
    func transcriptionNonexistentFileThrowsError() async {
        let service = OpenAITranscriptionService(apiKey: "sk-test123")
        let fakeURL = URL(fileURLWithPath: "/nonexistent/path/audio.m4a")

        do {
            _ = try await service.transcribe(audioURL: fakeURL, language: nil, promptHint: nil)
            #expect(Bool(false), "Should have thrown error")
        } catch let error as TranscriptionError {
            #expect(error == .audioFileNotFound)
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }
}

// MARK: - Language Extension Tests

@Suite("OpenAITranscriptionService - Language Whisper Codes")
struct LanguageWhisperCodeTests {

    @Test("English whisper code is en")
    func englishCode() {
        #expect(Language.english.whisperCode == "en")
    }

    @Test("Spanish whisper code is es")
    func spanishCode() {
        #expect(Language.spanish.whisperCode == "es")
    }

    @Test("French whisper code is fr")
    func frenchCode() {
        #expect(Language.french.whisperCode == "fr")
    }

    @Test("German whisper code is de")
    func germanCode() {
        #expect(Language.german.whisperCode == "de")
    }

    @Test("Italian whisper code is it")
    func italianCode() {
        #expect(Language.italian.whisperCode == "it")
    }

    @Test("Portuguese whisper code is pt")
    func portugueseCode() {
        #expect(Language.portuguese.whisperCode == "pt")
    }

    @Test("Russian whisper code is ru")
    func russianCode() {
        #expect(Language.russian.whisperCode == "ru")
    }

    @Test("Japanese whisper code is ja")
    func japaneseCode() {
        #expect(Language.japanese.whisperCode == "ja")
    }

    @Test("Korean whisper code is ko")
    func koreanCode() {
        #expect(Language.korean.whisperCode == "ko")
    }

    @Test("Chinese whisper code is zh")
    func chineseCode() {
        #expect(Language.chinese.whisperCode == "zh")
    }

    @Test("Arabic whisper code is ar")
    func arabicCode() {
        #expect(Language.arabic.whisperCode == "ar")
    }

    @Test("Egyptian Arabic whisper code is ar")
    func egyptianArabicCode() {
        #expect(Language.egyptianArabic.whisperCode == "ar")
    }

    @Test("Polish whisper code is pl")
    func polishCode() {
        #expect(Language.polish.whisperCode == "pl")
    }

    @Test("All languages have non-empty whisper codes")
    func allLanguagesHaveNonEmptyCodes() {
        for language in Language.allCases {
            #expect(!language.whisperCode.isEmpty, "Language \(language) has empty whisper code")
        }
    }

    @Test("All whisper codes are 2 characters")
    func allCodesAreTwoCharacters() {
        for language in Language.allCases {
            #expect(language.whisperCode.count == 2, "Language \(language) code is not 2 chars")
        }
    }
}

// MARK: - API Key Validation Tests

@Suite("OpenAITranscriptionService - API Key Validation")
struct OpenAITranscriptionServiceValidationTests {

    @Test("Empty key validation returns false")
    func emptyKeyValidationReturnsFalse() async {
        let service = OpenAITranscriptionService(apiKey: "test")

        let isValid = await service.validateAPIKey("")

        #expect(isValid == false)
    }

    @Test("Invalid key format validation returns false eventually")
    func invalidKeyValidationReturnsFalse() async {
        let service = OpenAITranscriptionService(apiKey: "test")

        // This will make a real network call that should fail with invalid key
        // In a real test environment, this would be mocked
        let isValid = await service.validateAPIKey("obviously-invalid-key")

        #expect(isValid == false)
    }
}

// MARK: - Protocol Conformance Tests

@Suite("OpenAITranscriptionService - TranscriptionProvider Protocol")
struct OpenAITranscriptionServiceProtocolTests {

    @Test("Conforms to TranscriptionProvider")
    func conformsToProtocol() {
        let service = OpenAITranscriptionService(apiKey: "test")

        // Check it can be used as TranscriptionProvider
        let provider: TranscriptionProvider = service

        #expect(provider.providerId == .openAI)
        #expect(provider.model == "whisper-1")
    }

    @Test("Provider has required properties")
    func hasRequiredProperties() {
        let service = OpenAITranscriptionService(apiKey: "test-key")

        // These should all be accessible
        _ = service.providerId
        _ = service.isConfigured
        _ = service.model
    }
}
