//
//  GoogleSTTServiceTests.swift
//  SwiftSpeakTests
//
//  Tests for GoogleSTTService
//

import Testing
import Foundation
@testable import SwiftSpeak

struct GoogleSTTServiceTests {

    // MARK: - Initialization

    @Test func serviceInitializesWithApiKeyAndProjectId() {
        let service = GoogleSTTService(
            apiKey: "test-api-key",
            projectId: "test-project-id",
            model: "long"
        )

        #expect(service.providerId == .google)
        #expect(service.isConfigured == true)
        #expect(service.model == "long")
    }

    @Test func serviceNotConfiguredWithEmptyApiKey() {
        let service = GoogleSTTService(
            apiKey: "",
            projectId: "test-project-id",
            model: "long"
        )

        #expect(service.isConfigured == false)
    }

    @Test func serviceNotConfiguredWithEmptyProjectId() {
        let service = GoogleSTTService(
            apiKey: "test-api-key",
            projectId: "",
            model: "long"
        )

        #expect(service.isConfigured == false)
    }

    @Test func serviceNotConfiguredWithBothEmpty() {
        let service = GoogleSTTService(
            apiKey: "",
            projectId: "",
            model: "long"
        )

        #expect(service.isConfigured == false)
    }

    @Test func serviceDefaultsToLongModel() {
        let service = GoogleSTTService(
            apiKey: "test-api-key",
            projectId: "test-project-id"
        )

        #expect(service.model == "long")
    }

    @Test func serviceAcceptsCustomModel() {
        let models = ["short", "long", "telephony", "medical_dictation", "medical_conversation"]

        for modelName in models {
            let service = GoogleSTTService(
                apiKey: "test-api-key",
                projectId: "test-project-id",
                model: modelName
            )

            #expect(service.model == modelName)
        }
    }

    // MARK: - Provider Config Initialization

    @Test func serviceInitializesFromProviderConfig() {
        let config = SwiftSpeak.AIProviderConfig(
            provider: .google,
            apiKey: "test-api-key",
            usageCategories: [.transcription],
            transcriptionModel: "medical_dictation",
            googleProjectId: "test-project-123"
        )

        let service = GoogleSTTService(config: config)

        #expect(service != nil)
        #expect(service?.isConfigured == true)
        #expect(service?.model == "medical_dictation")
    }

    @Test func serviceReturnsNilForNonGoogleConfig() {
        let config = SwiftSpeak.AIProviderConfig(
            provider: .openAI,
            apiKey: "test-api-key",
            usageCategories: [.transcription],
            googleProjectId: "test-project-123"
        )

        let service = GoogleSTTService(config: config)

        #expect(service == nil)
    }

    @Test func serviceReturnsNilForEmptyApiKey() {
        let config = SwiftSpeak.AIProviderConfig(
            provider: .google,
            apiKey: "",
            usageCategories: [.transcription],
            googleProjectId: "test-project-123"
        )

        let service = GoogleSTTService(config: config)

        #expect(service == nil)
    }

    @Test func serviceReturnsNilForMissingProjectId() {
        let config = SwiftSpeak.AIProviderConfig(
            provider: .google,
            apiKey: "test-api-key",
            usageCategories: [.transcription],
            googleProjectId: nil
        )

        let service = GoogleSTTService(config: config)

        #expect(service == nil)
    }

    @Test func serviceReturnsNilForEmptyProjectId() {
        let config = SwiftSpeak.AIProviderConfig(
            provider: .google,
            apiKey: "test-api-key",
            usageCategories: [.transcription],
            googleProjectId: ""
        )

        let service = GoogleSTTService(config: config)

        #expect(service == nil)
    }

    @Test func serviceUsesDefaultModelWhenNotSpecified() {
        let config = SwiftSpeak.AIProviderConfig(
            provider: .google,
            apiKey: "test-api-key",
            usageCategories: [.transcription],
            transcriptionModel: nil,
            googleProjectId: "test-project-123"
        )

        let service = GoogleSTTService(config: config)

        #expect(service != nil)
        #expect(service?.model == "long")
    }

    // MARK: - TranscriptionProvider Protocol

    @Test func serviceConformsToTranscriptionProvider() {
        let service = GoogleSTTService(
            apiKey: "test-api-key",
            projectId: "test-project-id"
        )

        // Verify protocol properties
        #expect(service.providerId == .google)
        #expect(type(of: service.isConfigured) == Bool.self)
        #expect(type(of: service.model) == String.self)
    }

    // MARK: - Configuration Validation

    @Test func isConfiguredRequiresBothApiKeyAndProjectId() {
        // Both present
        let configured = GoogleSTTService(
            apiKey: "key",
            projectId: "project"
        )
        #expect(configured.isConfigured == true)

        // Missing API key
        let noKey = GoogleSTTService(
            apiKey: "",
            projectId: "project"
        )
        #expect(noKey.isConfigured == false)

        // Missing project ID
        let noProject = GoogleSTTService(
            apiKey: "key",
            projectId: ""
        )
        #expect(noProject.isConfigured == false)

        // Both missing
        let noBoth = GoogleSTTService(
            apiKey: "",
            projectId: ""
        )
        #expect(noBoth.isConfigured == false)
    }
}

// MARK: - Language Code Tests

struct GoogleSTTLanguageCodeTests {

    @Test func allLanguagesHaveGoogleSTTCodes() {
        for language in SwiftSpeak.Language.allCases {
            let code = language.googleSTTCode
            #expect(!code.isEmpty)
        }
    }

    @Test func languageCodesFollowBCP47Format() {
        // BCP-47 codes should be in format "xx-YY" (language-REGION)
        for language in SwiftSpeak.Language.allCases {
            let code = language.googleSTTCode
            let components = code.split(separator: "-")

            #expect(components.count == 2, "Language code should have language-region format")

            if components.count == 2 {
                #expect(components[0].count == 2, "Language code should be 2 characters")
                #expect(components[1].count == 2, "Region code should be 2 characters")
            }
        }
    }

    @Test func specificLanguageCodesAreCorrect() {
        #expect(SwiftSpeak.Language.english.googleSTTCode == "en-US")
        #expect(SwiftSpeak.Language.spanish.googleSTTCode == "es-ES")
        #expect(SwiftSpeak.Language.french.googleSTTCode == "fr-FR")
        #expect(SwiftSpeak.Language.german.googleSTTCode == "de-DE")
        #expect(SwiftSpeak.Language.italian.googleSTTCode == "it-IT")
        #expect(SwiftSpeak.Language.portuguese.googleSTTCode == "pt-BR")
        #expect(SwiftSpeak.Language.chinese.googleSTTCode == "zh-CN")
        #expect(SwiftSpeak.Language.japanese.googleSTTCode == "ja-JP")
        #expect(SwiftSpeak.Language.korean.googleSTTCode == "ko-KR")
        #expect(SwiftSpeak.Language.arabic.googleSTTCode == "ar-SA")
        #expect(SwiftSpeak.Language.egyptianArabic.googleSTTCode == "ar-EG")
        #expect(SwiftSpeak.Language.russian.googleSTTCode == "ru-RU")
        #expect(SwiftSpeak.Language.polish.googleSTTCode == "pl-PL")
    }

    @Test func egyptianArabicHasUniqueCode() {
        // Egyptian Arabic should have its own code (ar-EG), not just ar-SA
        let arabicCode = SwiftSpeak.Language.arabic.googleSTTCode
        let egyptianCode = SwiftSpeak.Language.egyptianArabic.googleSTTCode

        #expect(arabicCode != egyptianCode)
        #expect(egyptianCode == "ar-EG")
    }
}

// MARK: - Model Support Tests

struct GoogleSTTModelTests {

    @Test func availableModelsIncludesAllExpectedModels() {
        let expectedModels = ["long", "short", "telephony", "medical_dictation", "medical_conversation"]
        let availableModels = SwiftSpeak.AIProvider.google.availableSTTModels

        for model in expectedModels {
            #expect(availableModels.contains(model), "Missing model: \(model)")
        }
    }

    @Test func defaultModelIsLong() {
        let defaultModel = SwiftSpeak.AIProvider.google.defaultSTTModel

        #expect(defaultModel == "long")
    }

    @Test func googleSupportsTranscription() {
        #expect(SwiftSpeak.AIProvider.google.supportsTranscription == true)
    }
}

// MARK: - Error Handling Tests

struct GoogleSTTErrorTests {

    @Test func throwsProviderNotConfiguredWhenNotConfigured() async {
        let service = GoogleSTTService(
            apiKey: "",
            projectId: "",
            model: "long"
        )

        // Create a temporary test file
        let testURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-audio.m4a")

        // Create empty file
        FileManager.default.createFile(
            atPath: testURL.path,
            contents: Data(),
            attributes: nil
        )

        defer {
            try? FileManager.default.removeItem(at: testURL)
        }

        do {
            _ = try await service.transcribe(audioURL: testURL, language: nil)
            Issue.record("Expected providerNotConfigured error")
        } catch {
            if let transcriptionError = error as? TranscriptionError {
                #expect(transcriptionError == .providerNotConfigured)
            } else {
                Issue.record("Expected TranscriptionError.providerNotConfigured, got \(error)")
            }
        }
    }

    @Test func throwsAudioFileNotFoundWhenFileMissing() async {
        let service = GoogleSTTService(
            apiKey: "test-key",
            projectId: "test-project",
            model: "long"
        )

        let nonExistentURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("non-existent-\(UUID().uuidString).m4a")

        do {
            _ = try await service.transcribe(audioURL: nonExistentURL, language: nil)
            Issue.record("Expected audioFileNotFound error")
        } catch {
            if let transcriptionError = error as? TranscriptionError {
                #expect(transcriptionError == .audioFileNotFound)
            } else {
                Issue.record("Expected TranscriptionError.audioFileNotFound, got \(error)")
            }
        }
    }
}

// MARK: - Integration Tests (Conceptual - would require real API)

struct GoogleSTTIntegrationTests {

    @Test func transcriptionRequiresValidConfiguration() async {
        // This test demonstrates what a successful transcription would look like
        // In a real integration test, you would:
        // 1. Create a real audio file
        // 2. Use real API credentials
        // 3. Make actual API call
        // 4. Verify response

        let service = GoogleSTTService(
            apiKey: "real-api-key",
            projectId: "real-project-id",
            model: "long"
        )

        #expect(service.isConfigured == true)
        #expect(service.providerId == .google)
        #expect(service.model == "long")
    }

    @Test func transcriptionSupportsMultipleLanguages() {
        let service = GoogleSTTService(
            apiKey: "test-key",
            projectId: "test-project"
        )

        // Verify service can be created with different language hints
        let languages: [SwiftSpeak.Language] = [
            .english, .spanish, .french, .german,
            .italian, .portuguese, .chinese, .japanese
        ]

        for language in languages {
            // Each language should have a valid Google STT code
            #expect(!language.googleSTTCode.isEmpty)
        }
    }

    @Test func transcriptionSupportsMultipleModels() {
        let models = ["long", "short", "telephony", "medical_dictation"]

        for model in models {
            let service = GoogleSTTService(
                apiKey: "test-key",
                projectId: "test-project",
                model: model
            )

            #expect(service.model == model)
            #expect(service.isConfigured == true)
        }
    }
}

// MARK: - Base64 Encoding Tests (Conceptual)

struct GoogleSTTBase64Tests {

    @Test func audioDataShouldBeBase64Encoded() {
        // This test verifies the concept that audio data needs to be base64 encoded
        // The actual encoding happens in the transcribe method

        let testData = "Hello, World!".data(using: .utf8)!
        let base64 = testData.base64EncodedString()

        #expect(!base64.isEmpty)
        // Base64 uses alphanumerics, +, /, and = for padding
        let validBase64Chars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "+/="))
        #expect(base64.unicodeScalars.allSatisfy(validBase64Chars.contains))

        // Verify it can be decoded back
        let decoded = Data(base64Encoded: base64)
        #expect(decoded == testData)
    }

    @Test func emptyAudioDataCreatesValidBase64() {
        let emptyData = Data()
        let base64 = emptyData.base64EncodedString()

        #expect(base64.isEmpty)
    }

    @Test func largeAudioDataCanBeBase64Encoded() {
        // Simulate a 1MB audio file
        let largeData = Data(count: 1024 * 1024)
        let base64 = largeData.base64EncodedString()

        #expect(!base64.isEmpty)
        #expect(base64.count > 0)
    }
}
