//
//  MockFormattingProvider.swift
//  SwiftSpeak
//
//  Mock formatting provider for testing
//

import Foundation

/// Mock formatting provider for unit and UI testing
/// Allows configurable delays, results, and failures
final class MockFormattingProvider: FormattingProvider {

    // MARK: - FormattingProvider

    let providerId: AIProvider = .openAI

    var isConfigured: Bool {
        shouldSucceed
    }

    var model: String {
        "mock-gpt"
    }

    // MARK: - Configuration

    /// Whether formatting should succeed
    var shouldSucceed: Bool = true

    /// Custom result to return (if nil, applies simple formatting based on mode)
    var customResult: String?

    /// Simulated delay before returning result (seconds)
    var delay: TimeInterval = 0.3

    /// Error to throw when shouldSucceed is false
    var errorToThrow: TranscriptionError = .networkError("Mock network error")

    /// Number of times format was called
    private(set) var formatCallCount = 0

    /// Last text passed to format
    private(set) var lastInputText: String?

    /// Last mode passed to format
    private(set) var lastMode: FormattingMode?

    /// Last custom prompt passed to format
    private(set) var lastCustomPrompt: String?

    // MARK: - Initialization

    init(
        shouldSucceed: Bool = true,
        customResult: String? = nil,
        delay: TimeInterval = 0.3
    ) {
        self.shouldSucceed = shouldSucceed
        self.customResult = customResult
        self.delay = delay
    }

    // MARK: - FormattingProvider Methods

    func format(
        text: String,
        mode: FormattingMode,
        customPrompt: String?
    ) async throws -> String {
        formatCallCount += 1
        lastInputText = text
        lastMode = mode
        lastCustomPrompt = customPrompt

        // Simulate network delay
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldSucceed {
            // Return custom result if set, otherwise apply mock formatting
            if let customResult = customResult {
                return customResult
            }
            return applyMockFormatting(to: text, mode: mode)
        } else {
            throw errorToThrow
        }
    }

    // MARK: - Mock Formatting

    private func applyMockFormatting(to text: String, mode: FormattingMode) -> String {
        switch mode {
        case .raw:
            return text

        case .email:
            return """
            Hi,

            \(text)

            Best regards
            """

        case .formal:
            // Simple mock: capitalize first letter of each sentence
            return text.capitalized

        case .casual:
            // Simple mock: add friendly prefix
            return "Hey! \(text)"
        }
    }

    // MARK: - Test Helpers

    /// Reset all recorded state
    func reset() {
        formatCallCount = 0
        lastInputText = nil
        lastMode = nil
        lastCustomPrompt = nil
        shouldSucceed = true
        customResult = nil
        delay = 0.3
        errorToThrow = .networkError("Mock network error")
    }
}

// MARK: - Preset Configurations

extension MockFormattingProvider {
    /// Quick success with no delay (for fast tests)
    static var instant: MockFormattingProvider {
        MockFormattingProvider(shouldSucceed: true, delay: 0)
    }

    /// Simulates realistic network latency
    static var realistic: MockFormattingProvider {
        MockFormattingProvider(shouldSucceed: true, delay: 0.8)
    }

    /// Always fails with network error
    static var networkFailure: MockFormattingProvider {
        let provider = MockFormattingProvider(shouldSucceed: false, delay: 0.3)
        provider.errorToThrow = .networkError("Connection failed")
        return provider
    }

    /// Always fails with API key error
    static var authFailure: MockFormattingProvider {
        let provider = MockFormattingProvider(shouldSucceed: false, delay: 0.3)
        provider.errorToThrow = .apiKeyInvalid
        return provider
    }

    /// Always fails with rate limit error
    static var rateLimited: MockFormattingProvider {
        let provider = MockFormattingProvider(shouldSucceed: false, delay: 0.3)
        provider.errorToThrow = .rateLimited(retryAfterSeconds: 60)
        return provider
    }

    /// Returns a specific result regardless of input
    static func returning(_ result: String) -> MockFormattingProvider {
        MockFormattingProvider(shouldSucceed: true, customResult: result, delay: 0)
    }
}
