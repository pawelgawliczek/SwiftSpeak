//
//  OpenAITranslationServiceTests.swift
//  SwiftSpeakTests
//
//  Tests for OpenAITranslationService
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

@MainActor
struct OpenAITranslationServiceTests {

    // MARK: - Initialization

    @Test func serviceInitializesWithApiKey() {
        let service = OpenAITranslationService(apiKey: "test-key", model: "gpt-4o-mini")

        #expect(service.providerId == .openAI)
        #expect(service.isConfigured == true)
        #expect(service.model == "gpt-4o-mini")
    }

    @Test func serviceNotConfiguredWithEmptyKey() {
        let service = OpenAITranslationService(apiKey: "", model: "gpt-4o-mini")

        #expect(service.isConfigured == false)
    }

    @Test func serviceDefaultsToGpt4oMini() {
        let service = OpenAITranslationService(apiKey: "test-key")

        #expect(service.model == "gpt-4o-mini")
    }

    // MARK: - Supported Languages

    @Test func serviceSupportAllLanguages() {
        let service = OpenAITranslationService(apiKey: "test-key")

        #expect(service.supportedLanguages.count == Language.allCases.count)

        for language in Language.allCases {
            #expect(service.supportedLanguages.contains(language))
        }
    }

    // MARK: - Provider Config Initialization

    @Test func serviceInitializesFromProviderConfig() {
        let config = AIProviderConfig(
            provider: .openAI,
            apiKey: "test-api-key",
            usageCategories: [.translation],
            translationModel: "gpt-4o"
        )

        let service = OpenAITranslationService(config: config)

        #expect(service != nil)
        #expect(service?.isConfigured == true)
        #expect(service?.model == "gpt-4o")
    }

    @Test func serviceReturnsNilForNonOpenAIConfig() {
        let config = AIProviderConfig(
            provider: .anthropic,
            apiKey: "test-api-key",
            usageCategories: [.translation]
        )

        let service = OpenAITranslationService(config: config)

        #expect(service == nil)
    }

    @Test func serviceReturnsNilForEmptyApiKey() {
        let config = AIProviderConfig(
            provider: .openAI,
            apiKey: "",
            usageCategories: [.translation]
        )

        let service = OpenAITranslationService(config: config)

        #expect(service == nil)
    }

    // MARK: - Translation Provider Protocol

    @Test func serviceConformsToTranslationProvider() {
        let service = OpenAITranslationService(apiKey: "test-key")

        // Verify protocol properties
        #expect(service.providerId == .openAI)
        #expect(type(of: service.isConfigured) == Bool.self)
        #expect(type(of: service.model) == String.self)
        #expect(type(of: service.supportedLanguages) == [Language].self)
    }
}

// MARK: - Mock Translation Tests

@MainActor
struct MockTranslationTests {

    @Test func languageHasCorrectDisplayName() {
        #expect(Language.spanish.displayName == "Spanish")
        #expect(Language.french.displayName == "French")
        #expect(Language.german.displayName == "German")
    }

    @Test func languageHasFlag() {
        for language in Language.allCases {
            #expect(!language.flag.isEmpty)
        }
    }

    @Test func languageEncodesAndDecodes() throws {
        let language = Language.spanish

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(language)
        let decoded = try decoder.decode(Language.self, from: data)

        #expect(decoded == language)
    }

    @Test func allLanguagesHaveUniqueRawValues() {
        let rawValues = Language.allCases.map { $0.rawValue }
        let uniqueValues = Set(rawValues)

        #expect(rawValues.count == uniqueValues.count)
    }
}

// MARK: - Recording State Translation Tests

@MainActor
struct RecordingStateTranslationTests {

    @Test func translatingStateExists() {
        let state = RecordingState.translating

        #expect(state == .translating)
    }

    @Test func translatingStateHasStatusText() {
        let state = RecordingState.translating

        #expect(!state.statusText.isEmpty)
        #expect(state.statusText.lowercased().contains("translat"))
    }

    @Test func translatingStateIsNotComplete() {
        let state = RecordingState.translating

        if case .complete = state {
            Issue.record("Translating state should not be complete")
        }
    }

    @Test func translatingStateIsNotError() {
        let state = RecordingState.translating

        if case .error = state {
            Issue.record("Translating state should not be error")
        }
    }
}
