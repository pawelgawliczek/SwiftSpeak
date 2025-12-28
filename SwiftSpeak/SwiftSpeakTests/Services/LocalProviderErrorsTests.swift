//
//  LocalProviderErrorsTests.swift
//  SwiftSpeakTests
//
//  Phase 10f: Tests for LocalProviderError
//

import Testing
import Foundation
@testable import SwiftSpeak

@MainActor
struct LocalProviderErrorsTests {

    // MARK: - WhisperKit Errors

    @Test("WhisperKit model not downloaded error")
    func testWhisperKitModelNotDownloaded() {
        let error = LocalProviderError.whisperKitModelNotDownloaded(model: "large-v3")

        #expect(error.errorDescription?.contains("large-v3") == true)
        #expect(error.errorDescription?.contains("not downloaded") == true)
        #expect(error.isUserRecoverable == true)
        #expect(error.iconName == "arrow.down.circle")
        #expect(error.recoverySuggestion != nil)
    }

    @Test("WhisperKit initialization failed error")
    func testWhisperKitInitializationFailed() {
        let reason = "Memory allocation failed"
        let error = LocalProviderError.whisperKitInitializationFailed(reason: reason)

        #expect(error.errorDescription?.contains(reason) == true)
        #expect(error.isUserRecoverable == false)
        #expect(error.iconName == "exclamationmark.triangle")
    }

    @Test("WhisperKit transcription failed error")
    func testWhisperKitTranscriptionFailed() {
        let reason = "Audio format not supported"
        let error = LocalProviderError.whisperKitTranscriptionFailed(reason: reason)

        #expect(error.errorDescription?.contains(reason) == true)
        #expect(error.iconName == "exclamationmark.circle")
    }

    @Test("WhisperKit model load failed error")
    func testWhisperKitModelLoadFailed() {
        let model = "tiny"
        let error = LocalProviderError.whisperKitModelLoadFailed(model: model)

        #expect(error.errorDescription?.contains(model) == true)
        #expect(error.iconName == "exclamationmark.triangle")
    }

    // MARK: - Apple Translation Errors

    @Test("Apple Translation not available error")
    func testAppleTranslationNotAvailable() {
        let error = LocalProviderError.appleTranslationNotAvailable

        #expect(error.errorDescription?.contains("17.4") == true)
        #expect(error.isUserRecoverable == false)
        #expect(error.iconName == "globe")
    }

    @Test("Apple Translation language not installed error")
    func testAppleTranslationLanguageNotInstalled() {
        let language = "Japanese"
        let error = LocalProviderError.appleTranslationLanguageNotInstalled(language: language)

        #expect(error.errorDescription?.contains(language) == true)
        #expect(error.isUserRecoverable == true)
        #expect(error.recoverySuggestion != nil)
    }

    @Test("Apple Translation pair not supported error")
    func testAppleTranslationPairNotSupported() {
        let error = LocalProviderError.appleTranslationPairNotSupported(from: "English", to: "Klingon")

        #expect(error.errorDescription?.contains("English") == true)
        #expect(error.errorDescription?.contains("Klingon") == true)
    }

    @Test("Apple Translation failed error")
    func testAppleTranslationFailed() {
        let reason = "Network timeout"
        let error = LocalProviderError.appleTranslationFailed(reason: reason)

        #expect(error.errorDescription?.contains(reason) == true)
    }

    // MARK: - Apple Intelligence Errors

    @Test("Apple Intelligence not available error")
    func testAppleIntelligenceNotAvailable() {
        let reason = "Device not eligible"
        let error = LocalProviderError.appleIntelligenceNotAvailable(reason: reason)

        #expect(error.errorDescription?.contains(reason) == true)
        #expect(error.isUserRecoverable == false)
        #expect(error.iconName == "brain.head.profile")
    }

    @Test("Apple Intelligence not enabled error")
    func testAppleIntelligenceNotEnabled() {
        let error = LocalProviderError.appleIntelligenceNotEnabled

        #expect(error.errorDescription?.contains("not enabled") == true)
        #expect(error.isUserRecoverable == true)
        #expect(error.recoverySuggestion?.contains("Settings") == true)
    }

    @Test("Apple Intelligence model not ready error")
    func testAppleIntelligenceModelNotReady() {
        let error = LocalProviderError.appleIntelligenceModelNotReady

        #expect(error.errorDescription?.contains("not ready") == true)
        #expect(error.isUserRecoverable == true)
    }

    @Test("Apple Intelligence generation failed error")
    func testAppleIntelligenceGenerationFailed() {
        let reason = "Context too long"
        let error = LocalProviderError.appleIntelligenceGenerationFailed(reason: reason)

        #expect(error.errorDescription?.contains(reason) == true)
    }

    // MARK: - General Errors

    @Test("Device not supported error")
    func testDeviceNotSupported() {
        let requirement = "Requires A17 Pro or later"
        let error = LocalProviderError.deviceNotSupported(requirement: requirement)

        #expect(error.errorDescription?.contains(requirement) == true)
        #expect(error.isUserRecoverable == false)
        #expect(error.iconName == "iphone.slash")
    }

    @Test("Insufficient memory error")
    func testInsufficientMemory() {
        let error = LocalProviderError.insufficientMemory(required: 4096, available: 2048)

        #expect(error.errorDescription?.contains("4096") == true)
        #expect(error.errorDescription?.contains("2048") == true)
        #expect(error.isUserRecoverable == true)
        #expect(error.iconName == "memorychip")
    }

    @Test("Model download failed error")
    func testModelDownloadFailed() {
        let reason = "Connection timed out"
        let error = LocalProviderError.modelDownloadFailed(reason: reason)

        #expect(error.errorDescription?.contains(reason) == true)
        #expect(error.iconName == "arrow.down.circle")
    }

    @Test("Model corrupted error")
    func testModelCorrupted() {
        let model = "medium"
        let error = LocalProviderError.modelCorrupted(model: model)

        #expect(error.errorDescription?.contains(model) == true)
        #expect(error.errorDescription?.contains("corrupted") == true)
    }

    // MARK: - Error Conversion Tests

    @Test("WhisperKit error converts to TranscriptionError")
    func testWhisperKitToTranscriptionError() {
        let error = LocalProviderError.whisperKitModelNotDownloaded(model: "large-v3")
        let transcriptionError = error.asTranscriptionError()

        if case .modelNotSupported(let model) = transcriptionError {
            #expect(model == "large-v3")
        } else {
            Issue.record("Expected modelNotSupported error")
        }
    }

    @Test("Apple Intelligence error converts to TranscriptionError")
    func testAppleIntelligenceToTranscriptionError() {
        let error = LocalProviderError.appleIntelligenceNotEnabled
        let transcriptionError = error.asTranscriptionError()

        if case .providerNotConfigured = transcriptionError {
            // Expected
        } else {
            Issue.record("Expected providerNotConfigured error")
        }
    }

    @Test("Translation language error converts to TranscriptionError")
    func testTranslationLanguageToTranscriptionError() {
        let error = LocalProviderError.appleTranslationLanguageNotInstalled(language: "German")
        let transcriptionError = error.asTranscriptionError()

        if case .languageNotSupported(let language) = transcriptionError {
            #expect(language == "German")
        } else {
            Issue.record("Expected languageNotSupported error")
        }
    }

    // MARK: - Equatable Tests

    @Test("Same errors are equal")
    func testErrorEquality() {
        let error1 = LocalProviderError.whisperKitModelNotDownloaded(model: "large")
        let error2 = LocalProviderError.whisperKitModelNotDownloaded(model: "large")

        #expect(error1 == error2)
    }

    @Test("Different errors are not equal")
    func testErrorInequality() {
        let error1 = LocalProviderError.whisperKitModelNotDownloaded(model: "large")
        let error2 = LocalProviderError.whisperKitModelNotDownloaded(model: "tiny")

        #expect(error1 != error2)
    }
}
