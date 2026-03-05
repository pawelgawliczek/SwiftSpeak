//
//  RemoteConfigTests.swift
//  SwiftSpeakTests
//
//  Tests for RemoteConfig data models and bundled config parsing
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

@MainActor
struct RemoteConfigTests {

    // MARK: - Bundled Config Tests

    @Test func bundledConfigFileExists() {
        let url = Bundle.main.url(forResource: "fallback-provider-config", withExtension: "json")
        #expect(url != nil, "Bundled fallback config should exist")
    }

    @Test func bundledConfigDecodesSuccessfully() async throws {
        guard let url = Bundle.main.url(forResource: "fallback-provider-config", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            Issue.record("Failed to load bundled config file")
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let config = try decoder.decode(RemoteProviderConfig.self, from: data)

        #expect(!config.version.isEmpty, "Config should have a version")
        #expect(config.schemaVersion >= 1, "Schema version should be at least 1")
        #expect(!config.providers.isEmpty, "Config should have providers")
    }

    @Test func bundledConfigHasRequiredProviders() async throws {
        let config = try loadBundledConfig()

        // Check required providers exist
        #expect(config.providers["openAI"] != nil, "OpenAI should be present")
        #expect(config.providers["anthropic"] != nil, "Anthropic should be present")
        #expect(config.providers["google"] != nil, "Google should be present")
        #expect(config.providers["deepgram"] != nil, "Deepgram should be present")
        #expect(config.providers["deepL"] != nil, "DeepL should be present")
        #expect(config.providers["local"] != nil, "Local should be present")
    }

    // MARK: - Provider Config Tests

    @Test func openAIProviderConfigIsComplete() async throws {
        let config = try loadBundledConfig()
        guard let openAI = config.providers["openAI"] else {
            Issue.record("OpenAI config not found")
            return
        }

        #expect(openAI.displayName == "OpenAI")
        #expect(openAI.status == .operational)
        #expect(openAI.transcription?.enabled == true)
        #expect(openAI.translation?.enabled == true)
        #expect(openAI.powerMode?.enabled == true)
        #expect(openAI.freeCredits != nil)
        #expect(openAI.apiKeyUrl != nil)
    }

    @Test func anthropicProviderConfigIsComplete() async throws {
        let config = try loadBundledConfig()
        guard let anthropic = config.providers["anthropic"] else {
            Issue.record("Anthropic config not found")
            return
        }

        #expect(anthropic.displayName == "Anthropic Claude")
        #expect(anthropic.status == .operational)
        #expect(anthropic.transcription?.enabled == false, "Anthropic doesn't support transcription")
        #expect(anthropic.translation?.enabled == true)
        #expect(anthropic.powerMode?.enabled == true)
    }

    @Test func localProviderHasZeroCost() async throws {
        let config = try loadBundledConfig()
        guard let local = config.providers["local"] else {
            Issue.record("Local config not found")
            return
        }

        #expect(local.displayName == "On-Device")

        // All local pricing should be free
        for (_, pricing) in local.pricing {
            if let cost = pricing.cost {
                #expect(cost == 0, "Local processing should be free")
            }
            if let input = pricing.inputPerMToken {
                #expect(input == 0, "Local LLM input should be free")
            }
            if let output = pricing.outputPerMToken {
                #expect(output == 0, "Local LLM output should be free")
            }
        }
    }

    // MARK: - Pricing Config Tests

    @Test func transcriptionPricingIsUnitBased() async throws {
        let config = try loadBundledConfig()
        guard let openAI = config.providers["openAI"],
              let whisperPricing = openAI.pricing["whisper-1"] else {
            Issue.record("Whisper pricing not found")
            return
        }

        #expect(whisperPricing.isUnitBased)
        #expect(!whisperPricing.isTokenBased)
        #expect(whisperPricing.unit == "minute")
        #expect(whisperPricing.cost == 0.006)
    }

    @Test func llmPricingIsTokenBased() async throws {
        let config = try loadBundledConfig()
        guard let openAI = config.providers["openAI"],
              let gpt4oPricing = openAI.pricing["gpt-4o"] else {
            Issue.record("GPT-4o pricing not found")
            return
        }

        #expect(gpt4oPricing.isTokenBased)
        #expect(!gpt4oPricing.isUnitBased)
        #expect(gpt4oPricing.inputPerMToken != nil)
        #expect(gpt4oPricing.outputPerMToken != nil)
    }

    @Test func pricingDisplayStringFormatsCorrectly() async throws {
        let config = try loadBundledConfig()
        guard let openAI = config.providers["openAI"],
              let whisperPricing = openAI.pricing["whisper-1"] else {
            Issue.record("Whisper pricing not found")
            return
        }

        let displayString = whisperPricing.displayString
        #expect(displayString.contains("$"), "Display string should contain dollar sign")
        #expect(displayString.contains("minute"), "Display string should contain unit")
    }

    // MARK: - Capability Config Tests

    @Test func capabilityHasModels() async throws {
        let config = try loadBundledConfig()
        guard let openAI = config.providers["openAI"],
              let transcription = openAI.transcription else {
            Issue.record("OpenAI transcription not found")
            return
        }

        #expect(transcription.models != nil)
        #expect(!transcription.models!.isEmpty)
    }

    @Test func capabilityHasDefaultModel() async throws {
        let config = try loadBundledConfig()
        guard let openAI = config.providers["openAI"],
              let transcription = openAI.transcription else {
            Issue.record("OpenAI transcription not found")
            return
        }

        let defaultModel = transcription.defaultModel
        #expect(defaultModel != nil)
        #expect(defaultModel?.isDefault == true)
    }

    @Test func capabilityHasLanguages() async throws {
        let config = try loadBundledConfig()
        guard let openAI = config.providers["openAI"],
              let transcription = openAI.transcription else {
            Issue.record("OpenAI transcription not found")
            return
        }

        #expect(transcription.languages != nil)
        #expect(transcription.languages!["en"] == "excellent")
    }

    @Test func languageSupportLevelParsesCorrectly() async throws {
        let config = try loadBundledConfig()
        guard let openAI = config.providers["openAI"],
              let transcription = openAI.transcription else {
            Issue.record("OpenAI transcription not found")
            return
        }

        let englishSupport = transcription.languageSupport(for: .english)
        #expect(englishSupport == .excellent)

        // Test language that returns limited (or check for existence)
        let polishSupport = transcription.languageSupport(for: .polish)
        #expect(polishSupport != .unsupported, "Polish should be supported")
    }

    // MARK: - Provider Status Tests

    @Test func providerStatusParses() async throws {
        let config = try loadBundledConfig()

        for (_, provider) in config.providers {
            // All providers in bundled config should be operational
            #expect(provider.status == .operational, "\(provider.displayName) should be operational")
        }
    }

    @Test func providerStatusEnumHasCorrectValues() {
        #expect(ProviderOperationalStatus.operational.isHealthy)
        #expect(!ProviderOperationalStatus.degraded.isHealthy)
        #expect(!ProviderOperationalStatus.down.isHealthy)
        #expect(!ProviderOperationalStatus.unknown.isHealthy)
    }

    // MARK: - Model Config Tests

    @Test func modelConfigParses() async throws {
        let config = try loadBundledConfig()
        guard let openAI = config.providers["openAI"],
              let transcription = openAI.transcription,
              let models = transcription.models else {
            Issue.record("OpenAI transcription models not found")
            return
        }

        let whisper = models.first { $0.id == "whisper-1" }
        #expect(whisper != nil)
        #expect(whisper?.name == "Whisper")
        #expect(whisper?.isDefault == true)
    }

    @Test func powerModeModelExists() async throws {
        let config = try loadBundledConfig()
        guard let openAI = config.providers["openAI"],
              let powerMode = openAI.powerMode,
              let models = powerMode.models else {
            Issue.record("OpenAI power mode models not found")
            return
        }

        let o1Model = models.first { $0.id == "o1" }
        #expect(o1Model != nil)
    }

    // MARK: - Provider Supports Tests

    @Test func providerSupportsCapability() async throws {
        let config = try loadBundledConfig()
        guard let openAI = config.providers["openAI"] else {
            Issue.record("OpenAI config not found")
            return
        }

        #expect(openAI.supports(.transcription))
        #expect(openAI.supports(.translation))
        #expect(openAI.supports(.powerMode))
    }

    @Test func anthropicDoesNotSupportTranscription() async throws {
        let config = try loadBundledConfig()
        guard let anthropic = config.providers["anthropic"] else {
            Issue.record("Anthropic config not found")
            return
        }

        #expect(!anthropic.supports(.transcription))
        #expect(anthropic.supports(.translation))
        #expect(anthropic.supports(.powerMode))
    }

    // MARK: - Helper Functions

    private func loadBundledConfig() throws -> RemoteProviderConfig {
        guard let url = Bundle.main.url(forResource: "fallback-provider-config", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            throw TestError.configNotFound
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(RemoteProviderConfig.self, from: data)
    }
}

// MARK: - Test Error

enum TestError: Error {
    case configNotFound
}
