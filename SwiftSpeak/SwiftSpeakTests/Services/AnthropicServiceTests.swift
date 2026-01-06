//
//  AnthropicServiceTests.swift
//  SwiftSpeakTests
//
//  Tests for AnthropicService
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

@MainActor
struct AnthropicServiceTests {

    // MARK: - Basic Properties

    @Test func providerHasCorrectId() {
        let service = AnthropicService(apiKey: "test-key")
        #expect(service.providerId == .anthropic)
    }

    @Test func providerHasModel() {
        let service = AnthropicService(apiKey: "test-key")
        #expect(service.model == "claude-3-5-sonnet-latest")
    }

    @Test func providerUsesCustomModel() {
        let customModel = "claude-3-5-haiku-latest"
        let service = AnthropicService(apiKey: "test-key", model: customModel)
        #expect(service.model == customModel)
    }

    @Test func configuredWhenApiKeyProvided() {
        let service = AnthropicService(apiKey: "test-key")
        #expect(service.isConfigured)
    }

    @Test func notConfiguredWhenApiKeyEmpty() {
        let service = AnthropicService(apiKey: "")
        #expect(!service.isConfigured)
    }

    // MARK: - Initialization from Config

    @Test func initializesFromValidConfig() {
        let config = AIProviderConfig(
            provider: .anthropic,
            apiKey: "test-key",
            powerModeModel: "claude-3-opus-latest"
        )

        let service = AnthropicService(config: config)
        #expect(service != nil)
        #expect(service?.model == "claude-3-opus-latest")
    }

    @Test func failsToInitializeFromWrongProvider() {
        let config = AIProviderConfig(
            provider: .openAI,
            apiKey: "test-key"
        )

        let service = AnthropicService(config: config)
        #expect(service == nil)
    }

    @Test func failsToInitializeFromEmptyApiKey() {
        let config = AIProviderConfig(
            provider: .anthropic,
            apiKey: ""
        )

        let service = AnthropicService(config: config)
        #expect(service == nil)
    }

    @Test func usesDefaultModelWhenNotSpecifiedInConfig() {
        let config = AIProviderConfig(
            provider: .anthropic,
            apiKey: "test-key"
        )

        let service = AnthropicService(config: config)
        #expect(service?.model == "claude-3-5-sonnet-latest")
    }

    // MARK: - Raw Mode

    @Test func rawModeReturnsOriginalText() async throws {
        let service = AnthropicService(apiKey: "test-key")
        let input = "Hello world"

        let result = try await service.format(text: input, mode: .raw, customPrompt: nil)
        #expect(result == input)
    }

    @Test func rawModeWithWhitespaceReturnsOriginalText() async throws {
        let service = AnthropicService(apiKey: "test-key")
        let input = "  Hello world  \n"

        let result = try await service.format(text: input, mode: .raw, customPrompt: nil)
        #expect(result == input)
    }

    // MARK: - Error Handling

    @Test func throwsErrorWhenNotConfigured() async {
        let service = AnthropicService(apiKey: "")

        await #expect(throws: TranscriptionError.self) {
            _ = try await service.format(text: "test", mode: .email, customPrompt: nil)
        }
    }

    @Test func throwsApiKeyMissingWhenNotConfigured() async {
        let service = AnthropicService(apiKey: "")

        do {
            _ = try await service.format(text: "test", mode: .email, customPrompt: nil)
            Issue.record("Expected TranscriptionError.apiKeyMissing to be thrown")
        } catch let error as TranscriptionError {
            #expect(error == .apiKeyMissing)
        } catch {
            Issue.record("Expected TranscriptionError but got \(type(of: error))")
        }
    }

    // MARK: - Model Support

    @Test func supportsSonnetModel() {
        let service = AnthropicService(apiKey: "test-key", model: "claude-3-5-sonnet-latest")
        #expect(service.model == "claude-3-5-sonnet-latest")
    }

    @Test func supportsHaikuModel() {
        let service = AnthropicService(apiKey: "test-key", model: "claude-3-5-haiku-latest")
        #expect(service.model == "claude-3-5-haiku-latest")
    }

    @Test func supportsOpusModel() {
        let service = AnthropicService(apiKey: "test-key", model: "claude-3-opus-latest")
        #expect(service.model == "claude-3-opus-latest")
    }

    // MARK: - Integration Tests (would require mock APIClient or real API key)

    // These tests are commented out as they would require either:
    // 1. A mock APIClient that can be injected for testing
    // 2. A real Anthropic API key (not suitable for CI/CD)
    //
    // Future enhancement: Add APIClient protocol for dependency injection

    /*
    @Test func formatsEmailCorrectly() async throws {
        // Would need mock APIClient or real API key
        let service = AnthropicService(apiKey: "sk-ant-test")
        let input = "please send the report to john about the meeting"

        let result = try await service.format(text: input, mode: .email, customPrompt: nil)
        // Verify result contains email formatting
    }

    @Test func formatsFormalCorrectly() async throws {
        // Would need mock APIClient or real API key
        let service = AnthropicService(apiKey: "sk-ant-test")
        let input = "gonna need that done asap"

        let result = try await service.format(text: input, mode: .formal, customPrompt: nil)
        // Verify result uses formal language
    }

    @Test func usesCustomPrompt() async throws {
        // Would need mock APIClient or real API key
        let service = AnthropicService(apiKey: "sk-ant-test")
        let input = "test message"
        let customPrompt = "Convert this to ALL CAPS"

        let result = try await service.format(text: input, mode: .raw, customPrompt: customPrompt)
        #expect(result == "TEST MESSAGE")
    }

    @Test func throwsEmptyResponseError() async {
        // Would need mock APIClient that returns empty content
        let service = AnthropicService(apiKey: "test-key")

        await #expect(throws: TranscriptionError.emptyResponse) {
            _ = try await service.format(text: "test", mode: .email, customPrompt: nil)
        }
    }
    */
}
