//
//  MockTranscriptionProviderTests.swift
//  SwiftSpeakTests
//
//  Tests for MockTranscriptionProvider
//

import Testing
import Foundation
@testable import SwiftSpeak

@MainActor
struct MockTranscriptionProviderTests {

    // MARK: - Basic Properties

    @Test func providerHasCorrectId() {
        let provider = MockTranscriptionProvider()
        #expect(provider.providerId == .openAI)
    }

    @Test func providerHasModel() {
        let provider = MockTranscriptionProvider()
        #expect(provider.model == "mock-whisper")
    }

    @Test func configuredWhenShouldSucceed() {
        let provider = MockTranscriptionProvider(shouldSucceed: true)
        #expect(provider.isConfigured)
    }

    @Test func notConfiguredWhenShouldFail() {
        let provider = MockTranscriptionProvider(shouldSucceed: false)
        #expect(!provider.isConfigured)
    }

    // MARK: - Transcription

    @Test func transcriptionReturnsConfiguredResult() async throws {
        let expectedResult = "Custom transcription result"
        let provider = MockTranscriptionProvider(
            shouldSucceed: true,
            mockResult: expectedResult,
            delay: 0
        )

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.m4a")
        let result = try await provider.transcribe(audioURL: tempURL, language: nil)

        #expect(result == expectedResult)
    }

    @Test func transcriptionRecordsCallCount() async throws {
        let provider = MockTranscriptionProvider.instant

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.m4a")
        _ = try await provider.transcribe(audioURL: tempURL, language: nil)
        _ = try await provider.transcribe(audioURL: tempURL, language: .english)

        #expect(provider.transcribeCallCount == 2)
    }

    @Test func transcriptionRecordsLastAudioURL() async throws {
        let provider = MockTranscriptionProvider.instant

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.m4a")
        _ = try await provider.transcribe(audioURL: tempURL, language: nil)

        #expect(provider.lastAudioURL == tempURL)
    }

    @Test func transcriptionRecordsLastLanguage() async throws {
        let provider = MockTranscriptionProvider.instant

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.m4a")
        _ = try await provider.transcribe(audioURL: tempURL, language: .spanish)

        #expect(provider.lastLanguage == .spanish)
    }

    @Test func transcriptionThrowsConfiguredError() async {
        let provider = MockTranscriptionProvider.networkFailure

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.m4a")

        await #expect(throws: TranscriptionError.self) {
            _ = try await provider.transcribe(audioURL: tempURL, language: nil)
        }
    }

    // MARK: - API Key Validation

    @Test func validatesNonEmptyKeyWithMinLength() async {
        let provider = MockTranscriptionProvider()

        let isValid = await provider.validateAPIKey("sk-test-key-12345")
        #expect(isValid)
    }

    @Test func rejectsEmptyKey() async {
        let provider = MockTranscriptionProvider()

        let isValid = await provider.validateAPIKey("")
        #expect(!isValid)
    }

    @Test func rejectsShortKey() async {
        let provider = MockTranscriptionProvider()

        let isValid = await provider.validateAPIKey("short")
        #expect(!isValid)
    }

    // MARK: - Reset

    @Test func resetClearsState() async throws {
        let provider = MockTranscriptionProvider()
        provider.shouldSucceed = false
        provider.mockResult = "changed"
        provider.delay = 5.0

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.m4a")
        _ = try? await provider.transcribe(audioURL: tempURL, language: .french)

        provider.reset()

        #expect(provider.shouldSucceed)
        #expect(provider.mockResult == "This is a mock transcription result.")
        #expect(provider.delay == 0.5)
        #expect(provider.transcribeCallCount == 0)
        #expect(provider.lastAudioURL == nil)
        #expect(provider.lastLanguage == nil)
    }

    // MARK: - Presets

    @Test func instantPresetHasNoDelay() {
        let provider = MockTranscriptionProvider.instant
        #expect(provider.delay == 0)
        #expect(provider.shouldSucceed)
    }

    @Test func realisticPresetHasDelay() {
        let provider = MockTranscriptionProvider.realistic
        #expect(provider.delay > 0)
        #expect(provider.shouldSucceed)
    }

    @Test func networkFailurePresetFails() {
        let provider = MockTranscriptionProvider.networkFailure
        #expect(!provider.shouldSucceed)
    }

    @Test func authFailurePresetFails() {
        let provider = MockTranscriptionProvider.authFailure
        #expect(!provider.shouldSucceed)
    }

    @Test func rateLimitedPresetFails() {
        let provider = MockTranscriptionProvider.rateLimited
        #expect(!provider.shouldSucceed)
    }
}
