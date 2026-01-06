//
//  LocalProviderErrors.swift
//  SwiftSpeak
//
//  Phase 10f: Error cases specific to local AI providers
//

import Foundation
import SwiftSpeakCore

/// Errors specific to local on-device AI providers
enum LocalProviderError: LocalizedError, Equatable {
    // MARK: - WhisperKit Errors
    case whisperKitModelNotDownloaded(model: String)
    case whisperKitInitializationFailed(reason: String)
    case whisperKitTranscriptionFailed(reason: String)
    case whisperKitModelLoadFailed(model: String)

    // MARK: - Apple Translation Errors
    case appleTranslationNotAvailable
    case appleTranslationLanguageNotInstalled(language: String)
    case appleTranslationPairNotSupported(from: String, to: String)
    case appleTranslationFailed(reason: String)

    // MARK: - Apple Intelligence Errors
    case appleIntelligenceNotAvailable(reason: String)
    case appleIntelligenceNotEnabled
    case appleIntelligenceModelNotReady
    case appleIntelligenceGenerationFailed(reason: String)

    // MARK: - General Local Provider Errors
    case deviceNotSupported(requirement: String)
    case insufficientMemory(required: Int, available: Int)
    case modelDownloadFailed(reason: String)
    case modelCorrupted(model: String)

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        // WhisperKit
        case .whisperKitModelNotDownloaded(let model):
            return "WhisperKit model '\(model)' is not downloaded. Please download it in Settings."
        case .whisperKitInitializationFailed(let reason):
            return "Failed to initialize WhisperKit: \(reason)"
        case .whisperKitTranscriptionFailed(let reason):
            return "WhisperKit transcription failed: \(reason)"
        case .whisperKitModelLoadFailed(let model):
            return "Failed to load WhisperKit model '\(model)'. Try re-downloading it."

        // Apple Translation
        case .appleTranslationNotAvailable:
            return "Apple Translation is not available. Requires iOS 17.4 or later."
        case .appleTranslationLanguageNotInstalled(let language):
            return "Translation language '\(language)' is not installed. Download it in Settings > General > Language & Region."
        case .appleTranslationPairNotSupported(let from, let to):
            return "Translation from \(from) to \(to) is not supported."
        case .appleTranslationFailed(let reason):
            return "Translation failed: \(reason)"

        // Apple Intelligence
        case .appleIntelligenceNotAvailable(let reason):
            return "Apple Intelligence is not available: \(reason)"
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is not enabled. Turn it on in Settings > Apple Intelligence & Siri."
        case .appleIntelligenceModelNotReady:
            return "Apple Intelligence model is not ready. Please wait for setup to complete."
        case .appleIntelligenceGenerationFailed(let reason):
            return "Text generation failed: \(reason)"

        // General
        case .deviceNotSupported(let requirement):
            return "This device does not support this feature. \(requirement)"
        case .insufficientMemory(let required, let available):
            return "Insufficient memory. Required: \(required)MB, Available: \(available)MB"
        case .modelDownloadFailed(let reason):
            return "Model download failed: \(reason)"
        case .modelCorrupted(let model):
            return "Model '\(model)' is corrupted. Please re-download it."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .whisperKitModelNotDownloaded:
            return "Go to Settings > Local Models > WhisperKit to download the model."
        case .whisperKitInitializationFailed, .whisperKitModelLoadFailed:
            return "Try restarting the app or re-downloading the model."
        case .appleTranslationLanguageNotInstalled:
            return "Go to Settings > General > Language & Region > Translation Languages."
        case .appleIntelligenceNotEnabled:
            return "Open Settings > Apple Intelligence & Siri and enable Apple Intelligence."
        case .appleIntelligenceModelNotReady:
            return "Apple Intelligence is still setting up. Please wait and try again."
        case .deviceNotSupported:
            return "This feature requires a newer device with Apple Silicon."
        case .insufficientMemory:
            return "Close other apps to free up memory."
        default:
            return nil
        }
    }

    /// Icon name for displaying this error
    var iconName: String {
        switch self {
        case .whisperKitModelNotDownloaded, .modelDownloadFailed:
            return "arrow.down.circle"
        case .whisperKitInitializationFailed, .whisperKitModelLoadFailed, .modelCorrupted:
            return "exclamationmark.triangle"
        case .appleTranslationNotAvailable, .appleTranslationLanguageNotInstalled:
            return "globe"
        case .appleIntelligenceNotAvailable, .appleIntelligenceNotEnabled, .appleIntelligenceModelNotReady:
            return "brain.head.profile"
        case .deviceNotSupported:
            return "iphone.slash"
        case .insufficientMemory:
            return "memorychip"
        default:
            return "exclamationmark.circle"
        }
    }

    /// Whether this error can be resolved by the user
    var isUserRecoverable: Bool {
        switch self {
        case .whisperKitModelNotDownloaded,
             .appleTranslationLanguageNotInstalled,
             .appleIntelligenceNotEnabled,
             .appleIntelligenceModelNotReady,
             .insufficientMemory:
            return true
        case .deviceNotSupported, .appleTranslationNotAvailable, .appleIntelligenceNotAvailable:
            return false
        default:
            return false
        }
    }
}

// MARK: - Conversion to TranscriptionError

extension LocalProviderError {
    /// Convert to a TranscriptionError for unified error handling
    func asTranscriptionError() -> TranscriptionError {
        switch self {
        case .whisperKitModelNotDownloaded(let model):
            return .modelNotSupported(model)
        case .whisperKitInitializationFailed(let reason),
             .whisperKitTranscriptionFailed(let reason):
            return .recordingFailed(reason)
        case .appleTranslationLanguageNotInstalled(let language):
            return .languageNotSupported(language)
        case .appleIntelligenceNotAvailable, .appleIntelligenceNotEnabled:
            return .providerNotConfigured
        default:
            return .unexpectedResponse(errorDescription ?? "Local provider error")
        }
    }
}
