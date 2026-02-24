//
//  LocalModelSettingsProvider.swift
//  SwiftSpeak
//
//  Protocol for local model settings, shared between iOS and macOS
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakMac targets
//

import Foundation
import Combine

/// Protocol for objects that provide local model settings
/// Implemented by SharedSettings (iOS) and MacSettings (macOS)
public protocol LocalModelSettingsProvider: ObservableObject {
    /// WhisperKit on-device transcription configuration
    var whisperKitConfig: WhisperKitSettings { get set }

    /// Apple Intelligence on-device formatting configuration
    var appleIntelligenceConfig: AppleIntelligenceConfig { get set }

    /// Apple Translation on-device translation configuration
    var appleTranslationConfig: AppleTranslationConfig { get set }

    /// Parakeet MLX on-device transcription configuration (macOS only)
    var parakeetMLXConfig: ParakeetMLXSettings { get set }

    /// Self-hosted LLM configuration (Ollama, LM Studio)
    /// Returns the LocalProviderConfig if configured, nil otherwise
    var selfHostedLLMConfig: LocalProviderConfig? { get }

    /// Whether WhisperKit is ready for transcription
    var isWhisperKitReady: Bool { get }

    /// Whether Parakeet MLX is ready for transcription
    var isParakeetMLXReady: Bool { get }

    /// Whether Apple Intelligence is ready for formatting
    var isAppleIntelligenceReady: Bool { get }

    /// Whether Apple Translation is ready for translation
    var hasLocalTranslation: Bool { get }

    /// Total storage used by local models in bytes
    var localModelStorageBytes: Int { get }

    /// Formatted string of storage used
    var localModelStorageFormatted: String { get }
}

// MARK: - Default Implementations

public extension LocalModelSettingsProvider {
    /// Formatted storage string (e.g., "856 MB")
    var localModelStorageFormatted: String {
        let bytes = localModelStorageBytes
        let mb = Double(bytes) / (1024 * 1024)
        if mb >= 1000 {
            return String(format: "%.1f GB", mb / 1024)
        } else if mb >= 1 {
            return String(format: "%.0f MB", mb)
        } else {
            return "< 1 MB"
        }
    }
}
