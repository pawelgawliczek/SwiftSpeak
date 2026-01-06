//
//  MockFormattingProviderTests.swift
//  SwiftSpeakTests
//
//  Tests for MockFormattingProvider
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

@MainActor
struct MockFormattingProviderTests {

    // MARK: - Basic Properties

    @Test func providerHasCorrectId() {
        let provider = MockFormattingProvider()
        #expect(provider.providerId == .openAI)
    }

    @Test func providerHasModel() {
        let provider = MockFormattingProvider()
        #expect(provider.model == "mock-gpt")
    }

    @Test func configuredWhenShouldSucceed() {
        let provider = MockFormattingProvider(shouldSucceed: true)
        #expect(provider.isConfigured)
    }

    @Test func notConfiguredWhenShouldFail() {
        let provider = MockFormattingProvider(shouldSucceed: false)
        #expect(!provider.isConfigured)
    }

    // MARK: - Formatting with Custom Result

    @Test func formattingReturnsCustomResult() async throws {
        let expectedResult = "Custom formatted result"
        let provider = MockFormattingProvider(
            shouldSucceed: true,
            customResult: expectedResult,
            delay: 0
        )

        let result = try await provider.format(text: "input", mode: .email, customPrompt: nil)
        #expect(result == expectedResult)
    }

    // MARK: - Mock Formatting by Mode

    @Test func rawModeReturnsOriginalText() async throws {
        let provider = MockFormattingProvider.instant
        let input = "Hello world"

        let result = try await provider.format(text: input, mode: .raw, customPrompt: nil)
        #expect(result == input)
    }

    @Test func emailModeAddsGreetingAndSignoff() async throws {
        let provider = MockFormattingProvider.instant
        let input = "This is my message"

        let result = try await provider.format(text: input, mode: .email, customPrompt: nil)
        #expect(result.contains("Hi"))
        #expect(result.contains(input))
        #expect(result.contains("Best regards"))
    }

    @Test func casualModeAddsFriendlyPrefix() async throws {
        let provider = MockFormattingProvider.instant
        let input = "This is my message"

        let result = try await provider.format(text: input, mode: .casual, customPrompt: nil)
        #expect(result.contains("Hey!"))
        #expect(result.contains(input))
    }

    // MARK: - Recording State

    @Test func formattingRecordsCallCount() async throws {
        let provider = MockFormattingProvider.instant

        _ = try await provider.format(text: "test1", mode: .email, customPrompt: nil)
        _ = try await provider.format(text: "test2", mode: .formal, customPrompt: nil)

        #expect(provider.formatCallCount == 2)
    }

    @Test func formattingRecordsLastInputText() async throws {
        let provider = MockFormattingProvider.instant
        let input = "My input text"

        _ = try await provider.format(text: input, mode: .email, customPrompt: nil)

        #expect(provider.lastInputText == input)
    }

    @Test func formattingRecordsLastMode() async throws {
        let provider = MockFormattingProvider.instant

        _ = try await provider.format(text: "test", mode: .formal, customPrompt: nil)

        #expect(provider.lastMode == .formal)
    }

    @Test func formattingRecordsLastCustomPrompt() async throws {
        let provider = MockFormattingProvider.instant
        let prompt = "Custom formatting instructions"

        _ = try await provider.format(text: "test", mode: .raw, customPrompt: prompt)

        #expect(provider.lastCustomPrompt == prompt)
    }

    // MARK: - Error Handling

    @Test func formattingThrowsConfiguredError() async {
        let provider = MockFormattingProvider.networkFailure

        await #expect(throws: TranscriptionError.self) {
            _ = try await provider.format(text: "test", mode: .email, customPrompt: nil)
        }
    }

    // MARK: - Reset

    @Test func resetClearsState() async throws {
        let provider = MockFormattingProvider()
        provider.shouldSucceed = false
        provider.customResult = "changed"
        provider.delay = 5.0

        _ = try? await provider.format(text: "test", mode: .formal, customPrompt: "prompt")

        provider.reset()

        #expect(provider.shouldSucceed)
        #expect(provider.customResult == nil)
        #expect(provider.delay == 0.3)
        #expect(provider.formatCallCount == 0)
        #expect(provider.lastInputText == nil)
        #expect(provider.lastMode == nil)
        #expect(provider.lastCustomPrompt == nil)
    }

    // MARK: - Presets

    @Test func instantPresetHasNoDelay() {
        let provider = MockFormattingProvider.instant
        #expect(provider.delay == 0)
        #expect(provider.shouldSucceed)
    }

    @Test func realisticPresetHasDelay() {
        let provider = MockFormattingProvider.realistic
        #expect(provider.delay > 0)
        #expect(provider.shouldSucceed)
    }

    @Test func returningPresetReturnsSpecificResult() async throws {
        let expectedResult = "Specific result"
        let provider = MockFormattingProvider.returning(expectedResult)

        let result = try await provider.format(text: "input", mode: .email, customPrompt: nil)
        #expect(result == expectedResult)
    }
}
