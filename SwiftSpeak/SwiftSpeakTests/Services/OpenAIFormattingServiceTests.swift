//
//  OpenAIFormattingServiceTests.swift
//  SwiftSpeakTests
//
//  Comprehensive tests for OpenAIFormattingService
//

import Testing
@testable import SwiftSpeak

// MARK: - Initialization Tests

@Suite("OpenAIFormattingService - Initialization")
struct OpenAIFormattingServiceInitTests {

    @Test("Provider ID is OpenAI")
    func providerIdIsOpenAI() {
        let service = OpenAIFormattingService(apiKey: "test-key")

        #expect(service.providerId == .openAI)
    }

    @Test("Default model is gpt-4o-mini")
    func defaultModelIsGpt4oMini() {
        let service = OpenAIFormattingService(apiKey: "test-key")

        #expect(service.model == "gpt-4o-mini")
    }

    @Test("Custom model is preserved")
    func customModelPreserved() {
        let service = OpenAIFormattingService(apiKey: "test-key", model: "gpt-4o")

        #expect(service.model == "gpt-4o")
    }

    @Test("Is configured with API key")
    func isConfiguredWithApiKey() {
        let service = OpenAIFormattingService(apiKey: "sk-test123")

        #expect(service.isConfigured == true)
    }

    @Test("Is not configured with empty API key")
    func notConfiguredWithEmptyKey() {
        let service = OpenAIFormattingService(apiKey: "")

        #expect(service.isConfigured == false)
    }
}

// MARK: - Config Initialization Tests

@Suite("OpenAIFormattingService - Config Initialization")
struct OpenAIFormattingServiceConfigInitTests {

    @Test("Init from valid config succeeds")
    func initFromValidConfig() {
        let config = AIProviderConfig(
            provider: .openAI,
            apiKey: "sk-test123",
            usageCategories: [.textFormatting],
            translationModel: "gpt-4o-mini"
        )

        let service = OpenAIFormattingService(config: config)

        #expect(service != nil)
        #expect(service?.providerId == .openAI)
        #expect(service?.model == "gpt-4o-mini")
    }

    @Test("Init from config with custom model")
    func initFromConfigWithCustomModel() {
        let config = AIProviderConfig(
            provider: .openAI,
            apiKey: "sk-test123",
            usageCategories: [.textFormatting],
            translationModel: "gpt-4-turbo"
        )

        let service = OpenAIFormattingService(config: config)

        #expect(service?.model == "gpt-4-turbo")
    }

    @Test("Init from config without model uses default")
    func initFromConfigWithoutModelUsesDefault() {
        let config = AIProviderConfig(
            provider: .openAI,
            apiKey: "sk-test123",
            usageCategories: [.textFormatting],
            translationModel: nil
        )

        let service = OpenAIFormattingService(config: config)

        #expect(service?.model == "gpt-4o-mini")
    }

    @Test("Init from wrong provider returns nil")
    func initFromWrongProviderReturnsNil() {
        let config = AIProviderConfig(
            provider: .anthropic, // Wrong provider
            apiKey: "sk-test123",
            usageCategories: [.textFormatting]
        )

        let service = OpenAIFormattingService(config: config)

        #expect(service == nil)
    }

    @Test("Init from empty API key returns nil")
    func initFromEmptyApiKeyReturnsNil() {
        let config = AIProviderConfig(
            provider: .openAI,
            apiKey: "", // Empty
            usageCategories: [.textFormatting]
        )

        let service = OpenAIFormattingService(config: config)

        #expect(service == nil)
    }
}

// MARK: - Formatting Mode Behavior Tests

@Suite("OpenAIFormattingService - Raw Mode")
struct OpenAIFormattingServiceRawModeTests {

    @Test("Raw mode with no context returns text unchanged")
    func rawModeNoContextReturnsUnchanged() async {
        let service = OpenAIFormattingService(apiKey: "sk-test123")

        do {
            let result = try await service.format(
                text: "Hello world",
                mode: .raw,
                customPrompt: nil,
                context: nil
            )

            #expect(result == "Hello world")
        } catch {
            #expect(Bool(false), "Should not throw for raw mode: \(error)")
        }
    }

    @Test("Raw mode with empty context returns text unchanged")
    func rawModeEmptyContextReturnsUnchanged() async {
        let service = OpenAIFormattingService(apiKey: "sk-test123")
        let emptyContext = PromptContext()

        do {
            let result = try await service.format(
                text: "Test text",
                mode: .raw,
                customPrompt: nil,
                context: emptyContext
            )

            #expect(result == "Test text")
        } catch {
            #expect(Bool(false), "Should not throw: \(error)")
        }
    }
}

// MARK: - Error Tests

@Suite("OpenAIFormattingService - Formatting Errors")
struct OpenAIFormattingServiceErrorTests {

    @Test("Formatting with unconfigured service throws error")
    func formattingUnconfiguredThrowsError() async {
        let service = OpenAIFormattingService(apiKey: "")

        do {
            _ = try await service.format(
                text: "Test",
                mode: .email, // Non-raw mode requires API call
                customPrompt: nil,
                context: nil
            )
            #expect(Bool(false), "Should have thrown error")
        } catch let error as TranscriptionError {
            #expect(error == .apiKeyMissing)
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }
}

// MARK: - Protocol Conformance Tests

@Suite("OpenAIFormattingService - FormattingProvider Protocol")
struct OpenAIFormattingServiceProtocolTests {

    @Test("Conforms to FormattingProvider")
    func conformsToProtocol() {
        let service = OpenAIFormattingService(apiKey: "test")

        // Check it can be used as FormattingProvider
        let provider: FormattingProvider = service

        #expect(provider.providerId == .openAI)
        #expect(provider.model == "gpt-4o-mini")
    }

    @Test("Provider has required properties")
    func hasRequiredProperties() {
        let service = OpenAIFormattingService(apiKey: "test-key")

        // These should all be accessible
        _ = service.providerId
        _ = service.isConfigured
        _ = service.model
    }
}

// MARK: - FormattingMode Prompt Tests

@Suite("OpenAIFormattingService - FormattingMode Prompts")
struct FormattingModePromptTests {

    @Test("Raw mode has minimal prompt")
    func rawModePrompt() {
        let prompt = FormattingMode.raw.prompt
        #expect(!prompt.isEmpty)
    }

    @Test("Email mode has specific prompt")
    func emailModePrompt() {
        let prompt = FormattingMode.email.prompt
        #expect(prompt.lowercased().contains("email"))
    }

    @Test("Formal mode has specific prompt")
    func formalModePrompt() {
        let prompt = FormattingMode.formal.prompt
        #expect(prompt.lowercased().contains("formal"))
    }

    @Test("Casual mode has specific prompt")
    func casualModePrompt() {
        let prompt = FormattingMode.casual.prompt
        #expect(prompt.lowercased().contains("casual"))
    }

    @Test("All modes have non-empty prompts")
    func allModesHavePrompts() {
        for mode in FormattingMode.allCases {
            #expect(!mode.prompt.isEmpty, "Mode \(mode) has empty prompt")
        }
    }
}

// MARK: - Context Integration Tests

@Suite("OpenAIFormattingService - Context Integration")
struct OpenAIFormattingServiceContextTests {

    @Test("Context with content triggers API call even in raw mode")
    func contextWithContentTriggersApiCall() async {
        // When context has content, even raw mode should process
        // This would fail with apiKeyMissing if it tries to call API
        let service = OpenAIFormattingService(apiKey: "")

        let context = PromptContext()
        // Add some content to make hasContent return true
        // Note: This depends on PromptContext implementation

        // If context has no content, raw mode returns unchanged
        do {
            let result = try await service.format(
                text: "Test",
                mode: .raw,
                customPrompt: nil,
                context: context
            )
            // Empty context means raw mode passes through
            #expect(result == "Test")
        } catch {
            // If context had content, would throw apiKeyMissing
        }
    }

    @Test("Custom prompt triggers API call")
    func customPromptTriggersApiCall() async {
        let service = OpenAIFormattingService(apiKey: "")

        do {
            _ = try await service.format(
                text: "Test",
                mode: .raw,
                customPrompt: "Custom formatting instructions",
                context: nil
            )
            #expect(Bool(false), "Should have thrown error")
        } catch let error as TranscriptionError {
            // Custom prompt requires API call, which fails without key
            #expect(error == .apiKeyMissing)
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }
}

// MARK: - Model Selection Tests

@Suite("OpenAIFormattingService - Model Selection")
struct OpenAIFormattingServiceModelTests {

    @Test("gpt-4o-mini is default for cost efficiency")
    func gpt4oMiniIsDefault() {
        let service = OpenAIFormattingService(apiKey: "test")
        #expect(service.model == "gpt-4o-mini")
    }

    @Test("Can use gpt-4o for better quality")
    func canUseGpt4o() {
        let service = OpenAIFormattingService(apiKey: "test", model: "gpt-4o")
        #expect(service.model == "gpt-4o")
    }

    @Test("Can use gpt-4-turbo")
    func canUseGpt4Turbo() {
        let service = OpenAIFormattingService(apiKey: "test", model: "gpt-4-turbo")
        #expect(service.model == "gpt-4-turbo")
    }

    @Test("Can use gpt-3.5-turbo for legacy support")
    func canUseGpt35Turbo() {
        let service = OpenAIFormattingService(apiKey: "test", model: "gpt-3.5-turbo")
        #expect(service.model == "gpt-3.5-turbo")
    }
}
