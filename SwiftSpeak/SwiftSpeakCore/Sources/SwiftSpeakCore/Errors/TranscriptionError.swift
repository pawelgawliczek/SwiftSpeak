//
//  TranscriptionError.swift
//  SwiftSpeakCore
//
//  Errors that can occur during transcription, formatting, or translation
//

import Foundation

/// Errors that can occur during transcription, formatting, or translation
public enum TranscriptionError: LocalizedError, Equatable, Sendable {
    // MARK: - Permission Errors
    case microphonePermissionDenied
    case microphonePermissionNotDetermined
    case speechRecognitionPermissionDenied
    case speechRecognitionNotAvailable

    // MARK: - Recording Errors
    case audioSessionConfigurationFailed(String)
    case recordingFailed(String)
    case recordingInterrupted
    case noAudioRecorded

    // MARK: - File Errors
    case invalidAudioFile
    case audioFileNotFound
    case fileTooLarge(sizeMB: Double, maxSizeMB: Double)

    // MARK: - Phase 11j: Audio Duration Errors
    case audioTooShort(duration: TimeInterval, minDuration: TimeInterval)
    case audioTooLong(duration: TimeInterval, maxDuration: TimeInterval)

    // MARK: - Network Errors
    case networkUnavailable
    case networkTimeout
    case networkError(String)

    // MARK: - API Key Errors
    case apiKeyMissing
    case apiKeyInvalid
    case apiKeyExpired

    // MARK: - Rate Limiting
    case rateLimited(retryAfterSeconds: Int)
    case quotaExceeded

    // MARK: - Server Errors
    case serverError(statusCode: Int, message: String?)
    case serviceUnavailable

    // MARK: - Response Errors
    case decodingError(String)
    case emptyResponse
    case unexpectedResponse(String)

    // MARK: - Configuration Errors
    case providerNotConfigured
    case modelNotSupported(String)
    case languageNotSupported(String)

    // MARK: - Cancelled
    case cancelled

    // MARK: - Privacy Mode
    case privacyModeBlocksCloudProvider(String)

    // MARK: - General Transcription Failure
    case transcriptionFailed(String)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required. Please enable it in Settings."
        case .microphonePermissionNotDetermined:
            return "Microphone permission has not been requested yet."
        case .speechRecognitionPermissionDenied:
            return "Speech recognition access is required. Please enable it in Settings."
        case .speechRecognitionNotAvailable:
            return "Speech recognition is not available on this device or for this language."

        case .audioSessionConfigurationFailed(let reason):
            return "Failed to configure audio: \(reason)"
        case .recordingFailed(let reason):
            return "Recording failed: \(reason)"
        case .recordingInterrupted:
            return "Recording was interrupted by another app."
        case .noAudioRecorded:
            return "No audio was recorded. Please try again."

        case .invalidAudioFile:
            return "The audio file format is not supported."
        case .audioFileNotFound:
            return "The recorded audio file could not be found."
        case .fileTooLarge(let sizeMB, let maxSizeMB):
            return String(format: "Audio file is too large (%.1f MB). Maximum size is %.0f MB.", sizeMB, maxSizeMB)

        case .audioTooShort(let duration, let minDuration):
            return String(format: "Recording too short (%.1fs). Minimum is %.1f seconds.", duration, minDuration)
        case .audioTooLong(let duration, let maxDuration):
            return String(format: "Recording too long (%.0fs). Maximum is %.0f seconds.", duration, maxDuration)

        case .networkUnavailable:
            return "No internet connection. Please check your network settings."
        case .networkTimeout:
            return "Request timed out. Please try again."
        case .networkError(let message):
            return "Network error: \(message)"

        case .apiKeyMissing:
            return "API key is not configured. Please add it in Settings."
        case .apiKeyInvalid:
            return "Your API key is invalid. Please check it in Settings."
        case .apiKeyExpired:
            return "Your API key has expired. Please update it in Settings."

        case .rateLimited(let seconds):
            return "Too many requests. Please wait \(seconds) seconds and try again."
        case .quotaExceeded:
            return "API quota exceeded. Please check your account limits."

        case .serverError(let statusCode, let message):
            if let message = message {
                return "Server error (\(statusCode)): \(message)"
            }
            return "Server error (code \(statusCode)). Please try again."
        case .serviceUnavailable:
            return "The service is temporarily unavailable. Please try again later."

        case .decodingError(let details):
            return "Failed to process response: \(details)"
        case .emptyResponse:
            return "No transcription was returned. Please try again."
        case .unexpectedResponse(let details):
            return "Unexpected response from server: \(details)"

        case .providerNotConfigured:
            return "No transcription provider is configured. Please set one up in Settings."
        case .modelNotSupported(let model):
            return "Model '\(model)' is not supported by this provider."
        case .languageNotSupported(let language):
            return "Language '\(language)' is not supported."

        case .cancelled:
            return "Operation was cancelled."

        case .privacyModeBlocksCloudProvider(let provider):
            return "Privacy Mode is on. \(provider) is blocked because it uses cloud processing."

        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Go to Settings > SwiftSpeak > Microphone and enable access."
        case .speechRecognitionPermissionDenied:
            return "Go to Settings > SwiftSpeak > Speech Recognition and enable access."
        case .speechRecognitionNotAvailable:
            return "Try a different language or use a cloud-based transcription provider."
        case .apiKeyMissing, .apiKeyInvalid, .apiKeyExpired:
            return "Open Settings in the app to configure your API key."
        case .providerNotConfigured:
            return "Open Settings to add a transcription provider."
        case .networkUnavailable:
            return "Check your Wi-Fi or cellular connection."
        case .rateLimited:
            return "Wait a moment before trying again."
        case .quotaExceeded:
            return "Check your API provider's dashboard for usage limits."
        default:
            return nil
        }
    }

    // MARK: - Equatable

    public static func == (lhs: TranscriptionError, rhs: TranscriptionError) -> Bool {
        switch (lhs, rhs) {
        case (.microphonePermissionDenied, .microphonePermissionDenied),
             (.microphonePermissionNotDetermined, .microphonePermissionNotDetermined),
             (.speechRecognitionPermissionDenied, .speechRecognitionPermissionDenied),
             (.speechRecognitionNotAvailable, .speechRecognitionNotAvailable),
             (.recordingInterrupted, .recordingInterrupted),
             (.noAudioRecorded, .noAudioRecorded),
             (.invalidAudioFile, .invalidAudioFile),
             (.audioFileNotFound, .audioFileNotFound),
             (.networkUnavailable, .networkUnavailable),
             (.networkTimeout, .networkTimeout),
             (.apiKeyMissing, .apiKeyMissing),
             (.apiKeyInvalid, .apiKeyInvalid),
             (.apiKeyExpired, .apiKeyExpired),
             (.quotaExceeded, .quotaExceeded),
             (.serviceUnavailable, .serviceUnavailable),
             (.emptyResponse, .emptyResponse),
             (.providerNotConfigured, .providerNotConfigured),
             (.cancelled, .cancelled):
            return true
        case (.audioSessionConfigurationFailed(let a), .audioSessionConfigurationFailed(let b)),
             (.recordingFailed(let a), .recordingFailed(let b)),
             (.networkError(let a), .networkError(let b)),
             (.decodingError(let a), .decodingError(let b)),
             (.unexpectedResponse(let a), .unexpectedResponse(let b)),
             (.modelNotSupported(let a), .modelNotSupported(let b)),
             (.languageNotSupported(let a), .languageNotSupported(let b)),
             (.privacyModeBlocksCloudProvider(let a), .privacyModeBlocksCloudProvider(let b)),
             (.transcriptionFailed(let a), .transcriptionFailed(let b)):
            return a == b
        case (.fileTooLarge(let a1, let a2), .fileTooLarge(let b1, let b2)):
            return a1 == b1 && a2 == b2
        case (.audioTooShort(let a1, let a2), .audioTooShort(let b1, let b2)):
            return a1 == b1 && a2 == b2
        case (.audioTooLong(let a1, let a2), .audioTooLong(let b1, let b2)):
            return a1 == b1 && a2 == b2
        case (.rateLimited(let a), .rateLimited(let b)):
            return a == b
        case (.serverError(let c1, let m1), .serverError(let c2, let m2)):
            return c1 == c2 && m1 == m2
        default:
            return false
        }
    }
}

// MARK: - Convenience Properties

extension TranscriptionError {
    /// Whether this error is recoverable by the user
    public var isUserRecoverable: Bool {
        switch self {
        case .microphonePermissionDenied,
             .speechRecognitionPermissionDenied,
             .apiKeyMissing,
             .apiKeyInvalid,
             .apiKeyExpired,
             .providerNotConfigured,
             .networkUnavailable:
            return true
        default:
            return false
        }
    }

    /// Whether this error should trigger a retry
    public var shouldRetry: Bool {
        switch self {
        case .networkTimeout,
             .networkError,
             .rateLimited,
             .serviceUnavailable:
            return true
        case .serverError(let code, _) where code >= 500:
            return true
        default:
            return false
        }
    }

    /// Icon name for displaying this error
    public var iconName: String {
        switch self {
        case .microphonePermissionDenied, .microphonePermissionNotDetermined:
            return "mic.slash.fill"
        case .speechRecognitionPermissionDenied, .speechRecognitionNotAvailable:
            return "waveform.slash"
        case .networkUnavailable, .networkTimeout, .networkError:
            return "wifi.slash"
        case .apiKeyMissing, .apiKeyInvalid, .apiKeyExpired:
            return "key.fill"
        case .rateLimited, .quotaExceeded:
            return "hourglass"
        case .cancelled:
            return "xmark.circle.fill"
        case .privacyModeBlocksCloudProvider:
            return "lock.shield.fill"
        default:
            return "exclamationmark.triangle.fill"
        }
    }
}
