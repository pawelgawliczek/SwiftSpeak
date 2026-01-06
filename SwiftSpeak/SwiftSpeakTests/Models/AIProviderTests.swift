//
//  AIProviderTests.swift
//  SwiftSpeakTests
//
//  Tests for AIProvider enum
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

struct AIProviderTests {

    // MARK: - Provider Capabilities

    @Test func openAISupportsAllCapabilities() {
        let provider = AIProvider.openAI
        #expect(provider.supportsTranscription)
        #expect(provider.supportsTranslation)
        #expect(provider.supportsPowerMode)
    }

    @Test func anthropicSupportsTranslationAndPowerMode() {
        let provider = AIProvider.anthropic
        #expect(!provider.supportsTranscription)
        #expect(provider.supportsTranslation)
        #expect(provider.supportsPowerMode)
    }

    @Test func elevenLabsSupportsOnlyTranscription() {
        let provider = AIProvider.elevenLabs
        #expect(provider.supportsTranscription)
        #expect(!provider.supportsTranslation)
        #expect(!provider.supportsPowerMode)
    }

    @Test func deepgramSupportsOnlyTranscription() {
        let provider = AIProvider.deepgram
        #expect(provider.supportsTranscription)
        #expect(!provider.supportsTranslation)
        #expect(!provider.supportsPowerMode)
    }

    @Test func googleSupportsAllCapabilities() {
        let provider = AIProvider.google
        #expect(provider.supportsTranscription)  // Google STT
        #expect(provider.supportsTranslation)
        #expect(provider.supportsPowerMode)
    }

    @Test func localProviderSupportsAllCapabilities() {
        let provider = AIProvider.local
        #expect(provider.supportsTranscription)
        #expect(provider.supportsTranslation)
        #expect(provider.supportsPowerMode)
    }

    // MARK: - Display Names

    @Test func providersHaveDisplayNames() {
        for provider in AIProvider.allCases {
            #expect(!provider.displayName.isEmpty)
        }
    }

    @Test func providersHaveShortNames() {
        for provider in AIProvider.allCases {
            #expect(!provider.shortName.isEmpty)
        }
    }

    @Test func providersHaveDescriptions() {
        for provider in AIProvider.allCases {
            #expect(!provider.description.isEmpty)
        }
    }

    @Test func providersHaveIcons() {
        for provider in AIProvider.allCases {
            #expect(!provider.icon.isEmpty)
        }
    }

    // MARK: - Model Lists

    @Test func openAIHasSTTModels() {
        let models = AIProvider.openAI.availableSTTModels
        #expect(!models.isEmpty)
        #expect(models.contains("whisper-1"))
    }

    @Test func openAIHasLLMModels() {
        let models = AIProvider.openAI.availableLLMModels
        #expect(!models.isEmpty)
        #expect(models.contains("gpt-4o-mini"))
    }

    // MARK: - API Key Requirements

    @Test func cloudProvidersRequireAPIKey() {
        let cloudProviders: [AIProvider] = [.openAI, .anthropic, .google, .elevenLabs, .deepgram]
        for provider in cloudProviders {
            #expect(provider.requiresAPIKey)
        }
    }

    @Test func localProviderDoesNotRequireAPIKey() {
        #expect(!AIProvider.local.requiresAPIKey)
    }

    @Test func localProviderIsLocal() {
        #expect(AIProvider.local.isLocalProvider)
    }

    @Test func cloudProvidersAreNotLocal() {
        let cloudProviders: [AIProvider] = [.openAI, .anthropic, .google, .elevenLabs, .deepgram]
        for provider in cloudProviders {
            #expect(!provider.isLocalProvider)
        }
    }

    // MARK: - Codable

    @Test func providerEncodesAndDecodes() throws {
        let provider = AIProvider.openAI
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(provider)
        let decoded = try decoder.decode(AIProvider.self, from: data)

        #expect(decoded == provider)
    }

    @Test func allProvidersAreEncodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for provider in AIProvider.allCases {
            let data = try encoder.encode(provider)
            let decoded = try decoder.decode(AIProvider.self, from: data)
            #expect(decoded == provider)
        }
    }

    // MARK: - Identifiable

    @Test func providersHaveUniqueIds() {
        let ids = AIProvider.allCases.map { $0.id }
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count)
    }

    // MARK: - Supported Categories

    @Test func supportedCategoriesMatchCapabilities() {
        for provider in AIProvider.allCases {
            let categories = provider.supportedCategories

            if provider.supportsTranscription {
                #expect(categories.contains(.transcription))
            }
            if provider.supportsTranslation {
                #expect(categories.contains(.translation))
            }
            if provider.supportsPowerMode {
                #expect(categories.contains(.powerMode))
            }
        }
    }
}
