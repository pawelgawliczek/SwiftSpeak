//
//  StreamingFormattingProviderTests.swift
//  SwiftSpeakTests
//
//  Tests for StreamingFormattingProvider protocol and implementations
//

import Testing
import Foundation
@testable import SwiftSpeak

// MARK: - Mock Streaming Provider

/// A mock provider that supports streaming for testing
@MainActor
private class MockStreamingProvider: StreamingFormattingProvider {
    var providerId: AIProvider { .openAI }
    var isConfigured: Bool { true }
    var model: String { "test-model" }
    var supportsStreaming: Bool { _supportsStreaming }

    private var _supportsStreaming: Bool
    private var formatResult: String
    private var streamChunks: [String]
    private var shouldThrow: Bool

    init(
        supportsStreaming: Bool = true,
        formatResult: String = "formatted text",
        streamChunks: [String] = ["chunk1", "chunk2", "chunk3"],
        shouldThrow: Bool = false
    ) {
        self._supportsStreaming = supportsStreaming
        self.formatResult = formatResult
        self.streamChunks = streamChunks
        self.shouldThrow = shouldThrow
    }

    func format(
        text: String,
        mode: FormattingMode,
        customPrompt: String?,
        context: PromptContext?
    ) async throws -> String {
        if shouldThrow {
            throw TranscriptionError.apiKeyMissing
        }
        return formatResult
    }

    func formatStreaming(
        text: String,
        mode: FormattingMode,
        customPrompt: String?,
        context: PromptContext?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                if self.shouldThrow {
                    continuation.finish(throwing: TranscriptionError.apiKeyMissing)
                    return
                }

                for chunk in self.streamChunks {
                    continuation.yield(chunk)
                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
                continuation.finish()
            }
        }
    }
}

/// A mock provider that does NOT support streaming (uses default implementation)
@MainActor
private class MockNonStreamingProvider: StreamingFormattingProvider {
    var providerId: AIProvider { .openAI }
    var isConfigured: Bool { true }
    var model: String { "test-model" }

    private var formatResult: String
    private var shouldThrow: Bool

    init(formatResult: String = "formatted text", shouldThrow: Bool = false) {
        self.formatResult = formatResult
        self.shouldThrow = shouldThrow
    }

    func format(
        text: String,
        mode: FormattingMode,
        customPrompt: String?,
        context: PromptContext?
    ) async throws -> String {
        if shouldThrow {
            throw TranscriptionError.apiKeyMissing
        }
        return formatResult
    }
    // Uses default formatStreaming implementation from protocol extension
}

// MARK: - Streaming Support Tests

@Suite("StreamingFormattingProvider - Streaming Support")
@MainActor
struct StreamingFormattingProviderSupportTests {

    @Test("Provider declares streaming support")
    func providerDeclaresStreamingSupport() {
        let streamingProvider = MockStreamingProvider(supportsStreaming: true)
        let nonStreamingProvider = MockNonStreamingProvider()

        #expect(streamingProvider.supportsStreaming == true)
        #expect(nonStreamingProvider.supportsStreaming == false)
    }
}

// MARK: - Streaming Output Tests

@Suite("StreamingFormattingProvider - Streaming Output")
@MainActor
struct StreamingFormattingProviderOutputTests {

    @Test("Streaming provider yields chunks progressively")
    func streamingProviderYieldsChunks() async throws {
        let provider = MockStreamingProvider(
            streamChunks: ["Hello", " ", "World", "!"]
        )

        let stream = provider.formatStreaming(
            text: "test",
            mode: .formal,
            customPrompt: nil,
            context: nil
        )

        var chunks: [String] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }

        #expect(chunks == ["Hello", " ", "World", "!"])
    }

    @Test("Streaming provider handles empty chunks array")
    func streamingProviderHandlesEmptyChunks() async throws {
        let provider = MockStreamingProvider(streamChunks: [])

        let stream = provider.formatStreaming(
            text: "test",
            mode: .formal,
            customPrompt: nil,
            context: nil
        )

        var chunks: [String] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }

        #expect(chunks.isEmpty)
    }

    @Test("Streaming provider propagates errors")
    func streamingProviderPropagatesErrors() async throws {
        let provider = MockStreamingProvider(shouldThrow: true)

        let stream = provider.formatStreaming(
            text: "test",
            mode: .formal,
            customPrompt: nil,
            context: nil
        )

        do {
            for try await _ in stream {
                // Should not reach here
            }
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(error is TranscriptionError)
        }
    }
}

// MARK: - Default Implementation Tests

@Suite("StreamingFormattingProvider - Default Implementation")
@MainActor
struct StreamingFormattingProviderDefaultTests {

    @Test("Default implementation yields single result")
    func defaultImplementationYieldsSingleResult() async throws {
        let provider = MockNonStreamingProvider(formatResult: "complete result")

        let stream = provider.formatStreaming(
            text: "test",
            mode: .formal,
            customPrompt: nil,
            context: nil
        )

        var results: [String] = []
        for try await chunk in stream {
            results.append(chunk)
        }

        #expect(results.count == 1)
        #expect(results.first == "complete result")
    }

    @Test("Default implementation propagates format errors")
    func defaultImplementationPropagatesErrors() async throws {
        let provider = MockNonStreamingProvider(shouldThrow: true)

        let stream = provider.formatStreaming(
            text: "test",
            mode: .formal,
            customPrompt: nil,
            context: nil
        )

        do {
            for try await _ in stream {
                // Should not reach here
            }
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(error is TranscriptionError)
        }
    }

    @Test("Default supportsStreaming is false")
    func defaultSupportsStreamingIsFalse() {
        let provider = MockNonStreamingProvider()
        #expect(provider.supportsStreaming == false)
    }
}

// MARK: - Convenience Method Tests

@Suite("StreamingFormattingProvider - Convenience Methods")
@MainActor
struct StreamingFormattingProviderConvenienceTests {

    @Test("Convenience method without context")
    func convenienceMethodWithoutContext() async throws {
        let provider = MockStreamingProvider(streamChunks: ["result"])

        let stream = provider.formatStreaming(
            text: "test",
            mode: .casual,
            customPrompt: "custom"
        )

        var results: [String] = []
        for try await chunk in stream {
            results.append(chunk)
        }

        #expect(results.count == 1)
    }

    @Test("Convenience method without custom prompt")
    func convenienceMethodWithoutCustomPrompt() async throws {
        let provider = MockStreamingProvider(streamChunks: ["result"])

        let stream = provider.formatStreaming(
            text: "test",
            mode: .email,
            context: nil
        )

        var results: [String] = []
        for try await chunk in stream {
            results.append(chunk)
        }

        #expect(results.count == 1)
    }
}

// MARK: - FormattingProvider Base Tests

@Suite("FormattingProvider - Base Protocol")
@MainActor
struct FormattingProviderBaseTests {

    @Test("Convenience format without context")
    func convenienceFormatWithoutContext() async throws {
        let provider = MockNonStreamingProvider(formatResult: "formatted")

        let result = try await provider.format(
            text: "test",
            mode: .formal,
            customPrompt: nil
        )

        #expect(result == "formatted")
    }

    @Test("Convenience format without custom prompt or context")
    func convenienceFormatWithoutCustomPromptOrContext() async throws {
        let provider = MockNonStreamingProvider(formatResult: "formatted")

        let result = try await provider.format(
            text: "test",
            mode: .formal
        )

        #expect(result == "formatted")
    }

    @Test("Format with context convenience")
    func formatWithContextConvenience() async throws {
        let provider = MockNonStreamingProvider(formatResult: "formatted")

        let result = try await provider.format(
            text: "test",
            mode: .formal,
            context: nil
        )

        #expect(result == "formatted")
    }

    @Test("Raw mode returns unchanged in formatIfNeeded")
    func rawModeReturnsUnchanged() async throws {
        let provider = MockNonStreamingProvider(formatResult: "should not be this")

        let result = try await provider.formatIfNeeded(
            text: "original text",
            mode: .raw
        )

        #expect(result == "original text")
    }

    @Test("Non-raw mode formats in formatIfNeeded")
    func nonRawModeFormats() async throws {
        let provider = MockNonStreamingProvider(formatResult: "formatted text")

        let result = try await provider.formatIfNeeded(
            text: "original text",
            mode: .formal
        )

        #expect(result == "formatted text")
    }
}

// MARK: - Combined Results Tests

@Suite("StreamingFormattingProvider - Combined Results")
@MainActor
struct StreamingFormattingProviderCombinedTests {

    @Test("Can collect all chunks into single string")
    func canCollectAllChunksIntoSingleString() async throws {
        let provider = MockStreamingProvider(
            streamChunks: ["The ", "quick ", "brown ", "fox"]
        )

        let stream = provider.formatStreaming(
            text: "test",
            mode: .formal,
            customPrompt: nil,
            context: nil
        )

        var result = ""
        for try await chunk in stream {
            result += chunk
        }

        #expect(result == "The quick brown fox")
    }

    @Test("Stream can be cancelled")
    func streamCanBeCancelled() async throws {
        let provider = MockStreamingProvider(
            streamChunks: ["1", "2", "3", "4", "5"]
        )

        let stream = provider.formatStreaming(
            text: "test",
            mode: .formal,
            customPrompt: nil,
            context: nil
        )

        var count = 0
        for try await _ in stream {
            count += 1
            if count >= 2 {
                break // Cancel early
            }
        }

        #expect(count == 2)
    }
}
