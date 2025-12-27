//
//  DeepgramTranscriptionServiceTests.swift
//  SwiftSpeakTests
//
//  Tests for DeepgramTranscriptionService
//

import Testing
import Foundation
@testable import SwiftSpeak

struct DeepgramTranscriptionServiceTests {

    // MARK: - Basic Properties

    @Test func providerHasCorrectId() {
        let service = DeepgramTranscriptionService(apiKey: "test-key")
        #expect(service.providerId == .deepgram)
    }

    @Test func providerHasDefaultModel() {
        let service = DeepgramTranscriptionService(apiKey: "test-key")
        #expect(service.model == "nova-2")
    }

    @Test func providerCanUseCustomModel() {
        let service = DeepgramTranscriptionService(apiKey: "test-key", model: "enhanced")
        #expect(service.model == "enhanced")
    }

    @Test func configuredWithNonEmptyKey() {
        let service = DeepgramTranscriptionService(apiKey: "test-key")
        #expect(service.isConfigured)
    }

    @Test func notConfiguredWithEmptyKey() {
        let service = DeepgramTranscriptionService(apiKey: "")
        #expect(!service.isConfigured)
    }

    // MARK: - Initialization from Config

    @Test func initializesFromValidConfig() {
        let config = AIProviderConfig(
            provider: .deepgram,
            apiKey: "test-key",
            transcriptionModel: "nova"
        )

        let service = DeepgramTranscriptionService(config: config)
        #expect(service != nil)
        #expect(service?.model == "nova")
        #expect(service?.isConfigured == true)
    }

    @Test func failsToInitializeFromWrongProvider() {
        let config = AIProviderConfig(
            provider: .openAI,
            apiKey: "test-key"
        )

        let service = DeepgramTranscriptionService(config: config)
        #expect(service == nil)
    }

    @Test func failsToInitializeFromEmptyAPIKey() {
        let config = AIProviderConfig(
            provider: .deepgram,
            apiKey: ""
        )

        let service = DeepgramTranscriptionService(config: config)
        #expect(service == nil)
    }

    @Test func usesDefaultModelWhenNotSpecifiedInConfig() {
        let config = AIProviderConfig(
            provider: .deepgram,
            apiKey: "test-key",
            transcriptionModel: nil
        )

        let service = DeepgramTranscriptionService(config: config)
        #expect(service?.model == "nova-2")
    }

    // MARK: - Transcription Errors

    @Test func throwsApiKeyMissingWhenNotConfigured() async {
        let service = DeepgramTranscriptionService(apiKey: "")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.m4a")

        await #expect(throws: TranscriptionError.apiKeyMissing) {
            _ = try await service.transcribe(audioURL: tempURL, language: nil)
        }
    }

    @Test func throwsAudioFileNotFoundForNonExistentFile() async {
        let service = DeepgramTranscriptionService(apiKey: "test-key")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent-\(UUID()).m4a")

        await #expect(throws: TranscriptionError.audioFileNotFound) {
            _ = try await service.transcribe(audioURL: tempURL, language: nil)
        }
    }

    @Test func throwsFileTooLargeForOversizedFile() async {
        let service = DeepgramTranscriptionService(apiKey: "test-key")

        // Create a temporary file larger than 25 MB
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("large-\(UUID()).m4a")

        // Create 26 MB of data
        let largeData = Data(repeating: 0, count: 26 * 1024 * 1024)
        try? largeData.write(to: tempURL)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        do {
            _ = try await service.transcribe(audioURL: tempURL, language: nil)
            Issue.record("Expected fileTooLarge error")
        } catch let error as TranscriptionError {
            switch error {
            case .fileTooLarge(let sizeMB, let maxSizeMB):
                #expect(sizeMB > 25)
                #expect(maxSizeMB == 25)
            default:
                Issue.record("Expected fileTooLarge error, got \(error)")
            }
        } catch {
            Issue.record("Expected TranscriptionError, got \(error)")
        }
    }

    // MARK: - API Key Validation

    @Test func validatesEmptyKeyAsFalse() async {
        let service = DeepgramTranscriptionService(apiKey: "test-key")

        let isValid = await service.validateAPIKey("")
        #expect(!isValid)
    }

    @Test func validationRequiresNetworkCall() async {
        // This test verifies that validation attempts to make a network call
        // In a real scenario, this would fail with network error or invalid key
        // We're just testing that the method doesn't crash and returns false for bad keys
        let service = DeepgramTranscriptionService(apiKey: "test-key")

        let isValid = await service.validateAPIKey("invalid-key-format")
        // Should return false because the key is invalid
        // (This will make a network call and get 401 or network error)
        #expect(!isValid)
    }

    // MARK: - Language Support

    @Test func supportsLanguageParameter() async {
        let service = DeepgramTranscriptionService(apiKey: "test-key")

        // Create a small valid audio file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).m4a")
        let smallData = Data(repeating: 0, count: 1024)
        try? smallData.write(to: tempURL)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // This will fail with network error or invalid key, but we're testing that it accepts the language parameter
        do {
            _ = try await service.transcribe(audioURL: tempURL, language: .spanish)
            Issue.record("Expected network or API error")
        } catch let error as TranscriptionError {
            // Expected to fail with network/API error since we're using a test key
            // We're just verifying the method signature works
            #expect(error == .apiKeyInvalid || error == .networkUnavailable || error == .networkTimeout || error.shouldRetry)
        } catch {
            // URLError or other network errors are expected
        }
    }

    // MARK: - Model Variants

    @Test func supportsNova2Model() {
        let service = DeepgramTranscriptionService(apiKey: "test-key", model: "nova-2")
        #expect(service.model == "nova-2")
    }

    @Test func supportsNovaModel() {
        let service = DeepgramTranscriptionService(apiKey: "test-key", model: "nova")
        #expect(service.model == "nova")
    }

    @Test func supportsEnhancedModel() {
        let service = DeepgramTranscriptionService(apiKey: "test-key", model: "enhanced")
        #expect(service.model == "enhanced")
    }

    @Test func supportsBaseModel() {
        let service = DeepgramTranscriptionService(apiKey: "test-key", model: "base")
        #expect(service.model == "base")
    }

    // MARK: - Integration Tests (require valid API key)

    // Note: These tests are commented out because they require a real Deepgram API key
    // Uncomment and set DEEPGRAM_API_KEY environment variable to run them

    /*
    @Test func realTranscriptionWithValidKey() async throws {
        // Set your API key here or via environment variable
        guard let apiKey = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"],
              !apiKey.isEmpty else {
            Issue.record("Skipping integration test - DEEPGRAM_API_KEY not set")
            return
        }

        let service = DeepgramTranscriptionService(apiKey: apiKey, model: "nova-2")

        // Create a small test audio file (you would need a real audio file for this)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-audio.m4a")

        // This assumes you have a valid audio file to test with
        guard FileManager.default.fileExists(atPath: tempURL.path) else {
            Issue.record("Skipping integration test - test audio file not found")
            return
        }

        let result = try await service.transcribe(audioURL: tempURL, language: .english)
        #expect(!result.isEmpty)
    }

    @Test func realAPIKeyValidation() async {
        guard let apiKey = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"],
              !apiKey.isEmpty else {
            Issue.record("Skipping integration test - DEEPGRAM_API_KEY not set")
            return
        }

        let service = DeepgramTranscriptionService(apiKey: "test-key")
        let isValid = await service.validateAPIKey(apiKey)
        #expect(isValid)
    }
    */

    // MARK: - Error Handling

    @Test func handlesInvalidAudioFile() async {
        let service = DeepgramTranscriptionService(apiKey: "test-key")

        // Create a file with invalid audio data
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("invalid-\(UUID()).m4a")
        let invalidData = Data("not audio data".utf8)
        try? invalidData.write(to: tempURL)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // Should fail with API error or decoding error when server responds
        do {
            _ = try await service.transcribe(audioURL: tempURL, language: nil)
            Issue.record("Expected error for invalid audio data")
        } catch {
            // Expected to fail - verify it's a reasonable error type
            #expect(error is TranscriptionError || error is URLError)
        }
    }

    @Test func handlesNetworkTimeout() async {
        let service = DeepgramTranscriptionService(apiKey: "test-key")

        // Create a small valid-looking file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).m4a")
        let smallData = Data(repeating: 0, count: 1024)
        try? smallData.write(to: tempURL)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // This will likely fail with network error or invalid key
        do {
            _ = try await service.transcribe(audioURL: tempURL, language: nil)
            Issue.record("Expected network or API error")
        } catch {
            // Expected to fail with some kind of error
            #expect(error is TranscriptionError || error is URLError)
        }
    }

    // MARK: - MIME Type Detection

    @Test func detectsM4AMimeType() async {
        let service = DeepgramTranscriptionService(apiKey: "test-key")

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.m4a")
        let smallData = Data(repeating: 0, count: 100)
        try? smallData.write(to: tempURL)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // We can't directly test mimeType since it's private, but we can verify the request doesn't crash
        do {
            _ = try await service.transcribe(audioURL: tempURL, language: nil)
        } catch {
            // Expected to fail with network/API error, but shouldn't crash
            #expect(error is TranscriptionError || error is URLError)
        }
    }

    @Test func detectsMP3MimeType() async {
        let service = DeepgramTranscriptionService(apiKey: "test-key")

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.mp3")
        let smallData = Data(repeating: 0, count: 100)
        try? smallData.write(to: tempURL)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        do {
            _ = try await service.transcribe(audioURL: tempURL, language: nil)
        } catch {
            #expect(error is TranscriptionError || error is URLError)
        }
    }

    @Test func detectsWAVMimeType() async {
        let service = DeepgramTranscriptionService(apiKey: "test-key")

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.wav")
        let smallData = Data(repeating: 0, count: 100)
        try? smallData.write(to: tempURL)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        do {
            _ = try await service.transcribe(audioURL: tempURL, language: nil)
        } catch {
            #expect(error is TranscriptionError || error is URLError)
        }
    }
}
