//
//  TranscriptionErrorTests.swift
//  SwiftSpeakTests
//
//  Tests for TranscriptionError enum
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

struct TranscriptionErrorTests {

    // MARK: - Error Descriptions

    @Test func allErrorsHaveDescriptions() {
        let errors: [TranscriptionError] = [
            .microphonePermissionDenied,
            .microphonePermissionNotDetermined,
            .audioSessionConfigurationFailed("test"),
            .recordingFailed("test"),
            .recordingInterrupted,
            .noAudioRecorded,
            .invalidAudioFile,
            .audioFileNotFound,
            .fileTooLarge(sizeMB: 30, maxSizeMB: 25),
            .networkUnavailable,
            .networkTimeout,
            .networkError("test"),
            .apiKeyMissing,
            .apiKeyInvalid,
            .apiKeyExpired,
            .rateLimited(retryAfterSeconds: 60),
            .quotaExceeded,
            .serverError(statusCode: 500, message: nil),
            .serviceUnavailable,
            .decodingError("test"),
            .emptyResponse,
            .unexpectedResponse("test"),
            .providerNotConfigured,
            .modelNotSupported("test"),
            .languageNotSupported("test"),
            .cancelled
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    // MARK: - User Recoverable

    @Test func permissionErrorIsUserRecoverable() {
        let error = TranscriptionError.microphonePermissionDenied
        #expect(error.isUserRecoverable)
    }

    @Test func apiKeyMissingIsUserRecoverable() {
        let error = TranscriptionError.apiKeyMissing
        #expect(error.isUserRecoverable)
    }

    @Test func apiKeyInvalidIsUserRecoverable() {
        let error = TranscriptionError.apiKeyInvalid
        #expect(error.isUserRecoverable)
    }

    @Test func providerNotConfiguredIsUserRecoverable() {
        let error = TranscriptionError.providerNotConfigured
        #expect(error.isUserRecoverable)
    }

    @Test func networkUnavailableIsUserRecoverable() {
        let error = TranscriptionError.networkUnavailable
        #expect(error.isUserRecoverable)
    }

    @Test func serverErrorIsNotUserRecoverable() {
        let error = TranscriptionError.serverError(statusCode: 500, message: nil)
        #expect(!error.isUserRecoverable)
    }

    // MARK: - Should Retry

    @Test func networkTimeoutShouldRetry() {
        let error = TranscriptionError.networkTimeout
        #expect(error.shouldRetry)
    }

    @Test func networkErrorShouldRetry() {
        let error = TranscriptionError.networkError("connection failed")
        #expect(error.shouldRetry)
    }

    @Test func serverErrorShouldRetry() {
        let error = TranscriptionError.serverError(statusCode: 503, message: nil)
        #expect(error.shouldRetry)
    }

    @Test func rateLimitedShouldRetry() {
        let error = TranscriptionError.rateLimited(retryAfterSeconds: 30)
        #expect(error.shouldRetry)
    }

    @Test func apiKeyInvalidShouldNotRetry() {
        let error = TranscriptionError.apiKeyInvalid
        #expect(!error.shouldRetry)
    }

    @Test func permissionDeniedShouldNotRetry() {
        let error = TranscriptionError.microphonePermissionDenied
        #expect(!error.shouldRetry)
    }

    @Test func quotaExceededShouldNotRetry() {
        let error = TranscriptionError.quotaExceeded
        #expect(!error.shouldRetry)
    }

    // MARK: - Icon Names

    @Test func allErrorsHaveIconNames() {
        let errors: [TranscriptionError] = [
            .microphonePermissionDenied,
            .networkUnavailable,
            .apiKeyMissing,
            .serverError(statusCode: 500, message: nil),
            .emptyResponse
        ]

        for error in errors {
            #expect(!error.iconName.isEmpty)
        }
    }

    @Test func networkErrorsHaveWifiIcon() {
        let networkErrors: [TranscriptionError] = [
            .networkUnavailable,
            .networkError("test"),
            .networkTimeout
        ]

        for error in networkErrors {
            #expect(error.iconName == "wifi.slash")
        }
    }

    @Test func serverErrorHasDefaultIcon() {
        let error = TranscriptionError.serverError(statusCode: 500, message: nil)
        #expect(error.iconName == "exclamationmark.triangle.fill")
    }

    @Test func keyErrorsHaveKeyIcon() {
        let keyErrors: [TranscriptionError] = [
            .apiKeyMissing,
            .apiKeyInvalid,
            .apiKeyExpired
        ]

        for error in keyErrors {
            #expect(error.iconName == "key.fill")
        }
    }

    // MARK: - Specific Error Properties

    @Test func rateLimitedContainsRetryTime() {
        let retrySeconds = 60
        let error = TranscriptionError.rateLimited(retryAfterSeconds: retrySeconds)

        if case .rateLimited(let seconds) = error {
            #expect(seconds == retrySeconds)
        } else {
            Issue.record("Expected rateLimited error")
        }
    }

    @Test func fileTooLargeContainsSize() {
        let sizeMB = 30.5
        let maxSizeMB = 25.0
        let error = TranscriptionError.fileTooLarge(sizeMB: sizeMB, maxSizeMB: maxSizeMB)

        if case .fileTooLarge(let size, let max) = error {
            #expect(size == sizeMB)
            #expect(max == maxSizeMB)
        } else {
            Issue.record("Expected fileTooLarge error")
        }
    }

    @Test func serverErrorContainsStatusCode() {
        let statusCode = 503
        let message = "Service unavailable"
        let error = TranscriptionError.serverError(statusCode: statusCode, message: message)

        if case .serverError(let code, let msg) = error {
            #expect(code == statusCode)
            #expect(msg == message)
        } else {
            Issue.record("Expected serverError")
        }
    }

    // MARK: - Microphone Errors

    @Test func microphonePermissionNotDeterminedError() {
        let error = TranscriptionError.microphonePermissionNotDetermined
        #expect(error.errorDescription != nil)
        // Not determined is not user recoverable - the system handles permission prompts
        #expect(!error.isUserRecoverable)
    }

    // MARK: - Recording Errors

    @Test func recordingFailedContainsReason() {
        let reason = "Hardware failure"
        let error = TranscriptionError.recordingFailed(reason)

        if case .recordingFailed(let r) = error {
            #expect(r == reason)
        } else {
            Issue.record("Expected recordingFailed error")
        }
    }

    @Test func recordingInterruptedError() {
        let error = TranscriptionError.recordingInterrupted
        #expect(error.errorDescription != nil)
    }

    // MARK: - Provider Errors

    @Test func modelNotSupportedContainsModel() {
        let model = "whisper-2"
        let error = TranscriptionError.modelNotSupported(model)

        if case .modelNotSupported(let m) = error {
            #expect(m == model)
        } else {
            Issue.record("Expected modelNotSupported error")
        }
    }

    @Test func languageNotSupportedContainsLanguage() {
        let language = "Klingon"
        let error = TranscriptionError.languageNotSupported(language)

        if case .languageNotSupported(let l) = error {
            #expect(l == language)
        } else {
            Issue.record("Expected languageNotSupported error")
        }
    }

    // MARK: - Cancelled

    @Test func cancelledErrorProperties() {
        let error = TranscriptionError.cancelled
        #expect(error.errorDescription != nil)
        #expect(!error.shouldRetry)
    }
}
