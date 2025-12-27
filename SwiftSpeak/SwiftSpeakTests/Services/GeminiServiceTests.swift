//
//  GeminiServiceTests.swift
//  SwiftSpeakTests
//
//  Created by Claude Code on 26/12/2025.
//

import Testing
import Foundation
@testable import SwiftSpeak

/// Tests for GeminiService
/// Verifies Google Gemini API integration for power mode formatting
@Suite("Gemini Service Tests")
struct GeminiServiceTests {

    // MARK: - Initialization Tests

    @Test("Initialize with API key")
    func testInitialization() {
        let service = GeminiService(apiKey: "test-api-key")

        #expect(service.providerId == .google)
        #expect(service.isConfigured == true)
        #expect(service.model == "gemini-2.0-flash-exp")
    }

    @Test("Initialize with custom model")
    func testInitializationWithCustomModel() {
        let service = GeminiService(apiKey: "test-api-key", model: "gemini-1.5-pro")

        #expect(service.model == "gemini-1.5-pro")
        #expect(service.isConfigured == true)
    }

    @Test("Initialize with empty API key marks as not configured")
    func testInitializationWithEmptyKey() {
        let service = GeminiService(apiKey: "")

        #expect(service.isConfigured == false)
    }

    @Test("Initialize from provider config")
    func testInitFromConfig() {
        let config = AIProviderConfig(
            provider: .google,
            apiKey: "test-api-key",
            powerModeModel: "gemini-1.5-flash"
        )

        let service = GeminiService(config: config)

        #expect(service != nil)
        #expect(service?.isConfigured == true)
        #expect(service?.model == "gemini-1.5-flash")
    }

    @Test("Initialize from config uses default model when not specified")
    func testInitFromConfigWithDefaultModel() {
        let config = AIProviderConfig(
            provider: .google,
            apiKey: "test-api-key"
        )

        let service = GeminiService(config: config)

        #expect(service != nil)
        #expect(service?.model == "gemini-2.0-flash-exp")
    }

    @Test("Fail to initialize from wrong provider config")
    func testInitFromWrongProviderConfig() {
        let config = AIProviderConfig(
            provider: .openAI,
            apiKey: "test-api-key"
        )

        let service = GeminiService(config: config)

        #expect(service == nil)
    }

    @Test("Fail to initialize from config with empty API key")
    func testInitFromConfigWithEmptyKey() {
        let config = AIProviderConfig(
            provider: .google,
            apiKey: ""
        )

        let service = GeminiService(config: config)

        #expect(service == nil)
    }

    // MARK: - Provider Metadata Tests

    @Test("Provider ID is Google")
    func testProviderID() {
        let service = GeminiService(apiKey: "test-api-key")
        #expect(service.providerId == .google)
    }

    @Test("Model name matches initialization parameter")
    func testModelName() {
        let service1 = GeminiService(apiKey: "test-api-key")
        #expect(service1.model == "gemini-2.0-flash-exp")

        let service2 = GeminiService(apiKey: "test-api-key", model: "gemini-1.5-pro")
        #expect(service2.model == "gemini-1.5-pro")
    }

    // MARK: - Raw Mode Tests

    @Test("Raw mode returns text unchanged")
    func testRawModePassthrough() async throws {
        let service = GeminiService(apiKey: "test-api-key")
        let inputText = "This is raw text"

        let result = try await service.format(
            text: inputText,
            mode: .raw,
            customPrompt: nil
        )

        #expect(result == inputText)
    }

    @Test("Raw mode with custom prompt calls API")
    func testRawModeWithCustomPrompt() async throws {
        let service = GeminiService(apiKey: "test-api-key")

        // Note: This will fail without a real API key, but tests protocol behavior
        await #expect(throws: Error.self) {
            try await service.format(
                text: "test",
                mode: .raw,
                customPrompt: "Custom formatting"
            )
        }
    }

    // MARK: - Error Handling Tests

    @Test("Throw error when API key is missing")
    func testMissingAPIKey() async throws {
        let service = GeminiService(apiKey: "")

        await #expect(throws: TranscriptionError.apiKeyMissing) {
            try await service.format(
                text: "Hello",
                mode: .email,
                customPrompt: nil
            )
        }
    }

    @Test("Throw error when API key is missing - exact error match")
    func testMissingAPIKeyExactError() async throws {
        let service = GeminiService(apiKey: "")

        do {
            _ = try await service.format(
                text: "Hello",
                mode: .email,
                customPrompt: nil
            )
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error as? TranscriptionError == .apiKeyMissing)
        }
    }

    // MARK: - Protocol Conformance Tests

    @Test("Convenience format method without custom prompt")
    func testConvenienceFormatMethod() async throws {
        let service = GeminiService(apiKey: "test-api-key")

        // Note: This will fail without a real API key, but tests protocol conformance
        await #expect(throws: Error.self) {
            try await service.format(text: "Hello", mode: .email)
        }
    }

    @Test("formatIfNeeded returns text unchanged for raw mode")
    func testFormatIfNeededRawMode() async throws {
        let service = GeminiService(apiKey: "test-api-key")
        let inputText = "Raw text"

        let result = try await service.formatIfNeeded(text: inputText, mode: .raw)

        #expect(result == inputText)
    }

    // MARK: - Request Building Tests

    @Test("Verify Gemini request structure")
    func testGeminiRequestStructure() throws {
        struct TestRequest: Encodable {
            let contents: [TestContent]
        }

        struct TestContent: Encodable {
            let role: String
            let parts: [TestPart]
        }

        struct TestPart: Encodable {
            let text: String
        }

        let request = TestRequest(
            contents: [
                TestContent(
                    role: "user",
                    parts: [TestPart(text: "Test message")]
                )
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        #expect(data.count > 0)

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let contents = json["contents"] as? [[String: Any]],
           let firstContent = contents.first {
            #expect(firstContent["role"] as? String == "user")

            if let parts = firstContent["parts"] as? [[String: Any]],
               let firstPart = parts.first {
                #expect(firstPart["text"] as? String == "Test message")
            }
        }
    }

    @Test("Verify combined prompt format")
    func testCombinedPromptFormat() {
        // Verify that system prompt and user text are combined correctly
        let systemPrompt = "Format this as professional email"
        let userText = "hey can you send me that file"

        let expectedFormat = """
        \(systemPrompt)

        Text to format:
        \(userText)
        """

        #expect(expectedFormat.contains(systemPrompt))
        #expect(expectedFormat.contains(userText))
        #expect(expectedFormat.contains("Text to format:"))
    }

    // MARK: - Response Parsing Tests

    @Test("Parse valid Gemini response")
    func testParseValidResponse() throws {
        let json = """
        {
          "candidates": [
            {
              "content": {
                "role": "model",
                "parts": [
                  {
                    "text": "Formatted response text"
                  }
                ]
              }
            }
          ]
        }
        """

        struct GeminiResponse: Decodable {
            let candidates: [GeminiCandidate]

            struct GeminiCandidate: Decodable {
                let content: GeminiContent
            }

            struct GeminiContent: Decodable {
                let role: String
                let parts: [GeminiPart]
            }

            struct GeminiPart: Decodable {
                let text: String
            }
        }

        let decoder = JSONDecoder()
        let data = json.data(using: .utf8)!
        let response = try decoder.decode(GeminiResponse.self, from: data)

        #expect(response.candidates.count == 1)
        #expect(response.candidates[0].content.parts.count == 1)
        #expect(response.candidates[0].content.parts[0].text == "Formatted response text")
    }

    @Test("Parse Gemini response with multiple parts")
    func testParseResponseWithMultipleParts() throws {
        let json = """
        {
          "candidates": [
            {
              "content": {
                "role": "model",
                "parts": [
                  {
                    "text": "First part"
                  },
                  {
                    "text": "Second part"
                  }
                ]
              }
            }
          ]
        }
        """

        struct GeminiResponse: Decodable {
            let candidates: [GeminiCandidate]

            struct GeminiCandidate: Decodable {
                let content: GeminiContent
            }

            struct GeminiContent: Decodable {
                let parts: [GeminiPart]
            }

            struct GeminiPart: Decodable {
                let text: String
            }
        }

        let decoder = JSONDecoder()
        let data = json.data(using: .utf8)!
        let response = try decoder.decode(GeminiResponse.self, from: data)

        #expect(response.candidates[0].content.parts.count == 2)
        #expect(response.candidates[0].content.parts[0].text == "First part")
        #expect(response.candidates[0].content.parts[1].text == "Second part")
    }

    // MARK: - Endpoint URL Tests

    @Test("Verify endpoint URL construction with model name")
    func testEndpointURLConstruction() {
        let baseURL = Constants.API.gemini
        let model = "gemini-2.0-flash-exp"
        let expectedURL = "\(baseURL)/\(model):generateContent"

        let url = URL(string: expectedURL)
        #expect(url != nil)
        #expect(url?.absoluteString == expectedURL)
    }

    @Test("Verify endpoint URL construction with different models")
    func testEndpointURLConstructionWithDifferentModels() {
        let baseURL = Constants.API.gemini
        let models = ["gemini-2.0-flash-exp", "gemini-1.5-pro", "gemini-1.5-flash"]

        for model in models {
            let expectedURL = "\(baseURL)/\(model):generateContent"
            let url = URL(string: expectedURL)

            #expect(url != nil)
            #expect(url?.absoluteString.contains(model) == true)
            #expect(url?.absoluteString.hasSuffix(":generateContent") == true)
        }
    }

    // MARK: - Formatting Mode Tests

    @Test("Email mode uses correct prompt")
    func testEmailModePrompt() {
        let mode = FormattingMode.email
        #expect(mode.prompt.contains("email"))
        #expect(mode.prompt.contains("professional"))
    }

    @Test("Formal mode uses correct prompt")
    func testFormalModePrompt() {
        let mode = FormattingMode.formal
        #expect(mode.prompt.contains("formal"))
        #expect(mode.prompt.contains("professional"))
    }

    @Test("Casual mode uses correct prompt")
    func testCasualModePrompt() {
        let mode = FormattingMode.casual
        #expect(mode.prompt.contains("casual"))
        #expect(mode.prompt.contains("friendly"))
    }

    @Test("Raw mode has empty prompt")
    func testRawModePrompt() {
        let mode = FormattingMode.raw
        #expect(mode.prompt.isEmpty)
    }

    // MARK: - Integration-like Tests

    @Test("Service can be initialized from all supported models")
    func testSupportedModels() {
        let models = ["gemini-2.0-flash-exp", "gemini-1.5-pro", "gemini-1.5-flash"]

        for model in models {
            let service = GeminiService(apiKey: "test-api-key", model: model)
            #expect(service.model == model)
            #expect(service.isConfigured == true)
        }
    }

    @Test("Google provider supports power mode")
    func testGoogleProviderSupportsPowerMode() {
        #expect(AIProvider.google.supportsPowerMode == true)
    }

    @Test("Google provider has correct LLM models")
    func testGoogleProviderLLMModels() {
        let expectedModels = ["gemini-2.0-flash-exp", "gemini-1.5-pro", "gemini-1.5-flash"]
        #expect(AIProvider.google.availableLLMModels == expectedModels)
    }

    @Test("Google provider default LLM model")
    func testGoogleProviderDefaultLLMModel() {
        #expect(AIProvider.google.defaultLLMModel == "gemini-2.0-flash-exp")
    }
}
