//
//  TranscriptionSettingsProtocol.swift
//  SwiftSpeakCore
//
//  Protocol for settings access to enable cross-platform code sharing
//  Both iOS SharedSettings and macOS MacSettings conform to this protocol
//

import Foundation

/// Protocol for settings access in the transcription workflow
/// Abstracts settings to enable code sharing between iOS and macOS
@MainActor
protocol TranscriptionSettingsProtocol: AnyObject {

    // MARK: - Provider Selection

    /// Currently selected transcription provider
    var selectedTranscriptionProvider: AIProvider { get }

    /// Currently selected translation/formatting provider
    var selectedTranslationProvider: AIProvider { get }

    /// Currently selected power mode provider
    var selectedPowerModeProvider: AIProvider { get }

    /// Get the configuration for a specific provider
    func getAIProviderConfig(for provider: AIProvider) -> AIProviderConfig?

    // MARK: - Privacy Mode

    /// Whether privacy mode is enabled (blocks cloud providers)
    var forcePrivacyMode: Bool { get }

    // MARK: - Memory Settings

    /// Whether global memory is enabled
    var globalMemoryEnabled: Bool { get }

    /// Global memory content (if any)
    var globalMemory: String? { get }

    // MARK: - Vocabulary

    /// User's vocabulary entries for text replacement
    var vocabularyEntries: [VocabularyEntry] { get }

    /// Apply vocabulary replacements to text
    func applyVocabulary(to text: String) -> String

    // MARK: - Contexts

    /// Available conversation contexts
    var contexts: [ConversationContext] { get }

    /// Active context ID (if any)
    var activeContextId: UUID? { get }

    /// Set active context by ID
    func setActiveContext(_ context: ConversationContext?)

    // MARK: - Power Modes

    /// Available power modes
    var powerModes: [PowerMode] { get }

    // MARK: - History

    /// Transcription history
    var transcriptionHistory: [TranscriptionRecord] { get }

    /// Add a transcription record to history
    func addTranscription(_ record: TranscriptionRecord)

    // MARK: - Keyboard Communication (iOS-specific, optional)

    /// Last transcription result for keyboard access
    var lastTranscription: String? { get set }

    /// Processing status for keyboard UI updates
    var processingStatus: ProcessingStatus { get set }

    // MARK: - Local Provider Readiness (optional)

    /// Whether WhisperKit is ready for use
    var isWhisperKitReady: Bool { get }

    /// Whether local translation is available
    var hasLocalTranslation: Bool { get }

    /// Whether Apple Intelligence is ready
    var isAppleIntelligenceReady: Bool { get }

    /// WhisperKit configuration
    var whisperKitConfig: WhisperKitSettings { get }

    /// Apple Translation configuration
    var appleTranslationConfig: AppleTranslationConfig { get }

    /// Apple Intelligence configuration
    var appleIntelligenceConfig: AppleIntelligenceConfig { get }
}

// MARK: - Default Implementations

extension TranscriptionSettingsProtocol {
    /// Apply vocabulary replacements to text
    func applyVocabulary(to text: String) -> String {
        var result = text
        for entry in vocabularyEntries where entry.isEnabled {
            // Case-insensitive replacement
            result = result.replacingOccurrences(
                of: entry.recognizedWord,
                with: entry.replacementWord,
                options: .caseInsensitive
            )
        }
        return result
    }

    // MARK: - Optional Properties with Defaults

    // These properties may not be available on all platforms
    // Provide sensible defaults

    var activeContextId: UUID? { nil }
    func setActiveContext(_ context: ConversationContext?) {}

    var lastTranscription: String? {
        get { nil }
        set { }
    }

    var processingStatus: ProcessingStatus {
        get { .idle }
        set { }
    }

    var isWhisperKitReady: Bool { false }
    var hasLocalTranslation: Bool { false }
    var isAppleIntelligenceReady: Bool { false }

    var whisperKitConfig: WhisperKitSettings { WhisperKitSettings() }
    var appleTranslationConfig: AppleTranslationConfig { AppleTranslationConfig() }
    var appleIntelligenceConfig: AppleIntelligenceConfig { AppleIntelligenceConfig() }
}

// MARK: - Minimal Settings Protocol

/// Minimal settings protocol for simpler use cases
/// Subset of TranscriptionSettingsProtocol for basic transcription
@MainActor
protocol MinimalTranscriptionSettingsProtocol: AnyObject {
    /// Currently selected transcription provider
    var selectedTranscriptionProvider: AIProvider { get }

    /// Currently selected translation provider
    var selectedTranslationProvider: AIProvider { get }

    /// Get provider configuration
    func getAIProviderConfig(for provider: AIProvider) -> AIProviderConfig?

    /// Vocabulary entries
    var vocabularyEntries: [VocabularyEntry] { get }

    /// Add transcription to history
    func addTranscription(_ record: TranscriptionRecord)
}
