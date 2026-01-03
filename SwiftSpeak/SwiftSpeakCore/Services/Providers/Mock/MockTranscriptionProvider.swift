//
//  MockTranscriptionProvider.swift
//  SwiftSpeak
//
//  Mock transcription provider for testing
//

import Foundation

/// Mock transcription provider for unit and UI testing
/// Allows configurable delays, results, and failures
final class MockTranscriptionProvider: TranscriptionProvider {

    // MARK: - TranscriptionProvider

    public let providerId: AIProvider = .openAI

    public var isConfigured: Bool {
        shouldSucceed
    }

    public var model: String {
        "mock-whisper"
    }

    // MARK: - Configuration

    /// Whether transcription should succeed
    public var shouldSucceed: Bool = true

    /// The text to return on successful transcription
    public var mockResult: String = "This is a mock transcription result."

    /// Simulated delay before returning result (seconds)
    public var delay: TimeInterval = 0.5

    /// Error to throw when shouldSucceed is false
    public var errorToThrow: TranscriptionError = .networkError("Mock network error")

    /// Number of times transcribe was called
    private(set) var transcribeCallCount = 0

    /// Last audio URL passed to transcribe
    private(set) var lastAudioURL: URL?

    /// Last language passed to transcribe
    private(set) var lastLanguage: Language?

    /// Last prompt hint passed to transcribe
    private(set) var lastPromptHint: String?

    // MARK: - Initialization

    public init(
        shouldSucceed: Bool = true,
        mockResult: String = "This is a mock transcription result.",
        delay: TimeInterval = 0.5
    ) {
        self.shouldSucceed = shouldSucceed
        self.mockResult = mockResult
        self.delay = delay
    }

    // MARK: - TranscriptionProvider Methods

    public func transcribe(audioURL: URL, language: Language?, promptHint: String?) async throws -> String {
        transcribeCallCount += 1
        lastAudioURL = audioURL
        lastLanguage = language
        lastPromptHint = promptHint

        // Simulate network delay
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldSucceed {
            return mockResult
        } else {
            throw errorToThrow
        }
    }

    public func validateAPIKey(_ key: String) async -> Bool {
        // Simulate validation delay
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        return !key.isEmpty && key.count >= 10
    }

    // MARK: - Test Helpers

    /// Reset all recorded state
    public func reset() {
        transcribeCallCount = 0
        lastAudioURL = nil
        lastLanguage = nil
        lastPromptHint = nil
        shouldSucceed = true
        mockResult = "This is a mock transcription result."
        delay = 0.5
        errorToThrow = .networkError("Mock network error")
    }
}

// MARK: - Preset Configurations

public extension MockTranscriptionProvider {
    /// Quick success with no delay (for fast tests)
    public static var instant: MockTranscriptionProvider {
        MockTranscriptionProvider(shouldSucceed: true, delay: 0)
    }

    /// Simulates realistic network latency
    public static var realistic: MockTranscriptionProvider {
        MockTranscriptionProvider(shouldSucceed: true, delay: 1.5)
    }

    /// Always fails with network error
    public static var networkFailure: MockTranscriptionProvider {
        let provider = MockTranscriptionProvider(shouldSucceed: false, delay: 0.5)
        provider.errorToThrow = .networkError("Connection failed")
        return provider
    }

    /// Always fails with API key error
    public static var authFailure: MockTranscriptionProvider {
        let provider = MockTranscriptionProvider(shouldSucceed: false, delay: 0.5)
        provider.errorToThrow = .apiKeyInvalid
        return provider
    }

    /// Always fails with rate limit error
    public static var rateLimited: MockTranscriptionProvider {
        let provider = MockTranscriptionProvider(shouldSucceed: false, delay: 0.5)
        provider.errorToThrow = .rateLimited(retryAfterSeconds: 60)
        return provider
    }
}
