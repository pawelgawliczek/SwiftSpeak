//
//  ContextProviderManager.swift
//  SwiftSpeak
//
//  Protocol for context-aware provider selection
//  Shared between iOS and macOS
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakMac targets
//

import Foundation

// MARK: - Context Provider Manager Protocol

/// Protocol for managing context-aware provider selection
/// Both iOS SharedSettings and macOS MacSharedSettings conform to this
public protocol ContextProviderManager: AnyObject {
    /// All available conversation contexts
    var contexts: [ConversationContext] { get }

    /// Currently active context ID
    var activeContextId: UUID? { get set }

    /// Whether streaming transcription is enabled
    /// When true, transcription provider overrides are ignored
    var transcriptionStreamingEnabled: Bool { get }

    // Global default providers
    var selectedTranscriptionProvider: AIProvider { get }
    var selectedTranslationProvider: AIProvider { get }
    var selectedPowerModeProvider: AIProvider { get }
}

// MARK: - Default Implementation

public extension ContextProviderManager {
    /// Get the currently active context
    var activeContext: ConversationContext? {
        guard let id = activeContextId else { return nil }
        return contexts.first { $0.id == id }
    }

    /// Returns effective transcription provider (context override or global)
    /// Note: If streaming enabled, always returns global (no context override)
    var effectiveTranscriptionProvider: ProviderSelection {
        // Streaming mode ignores context overrides due to audio format requirements
        if transcriptionStreamingEnabled {
            return ProviderSelection(providerType: .cloud(selectedTranscriptionProvider))
        }
        return activeContext?.transcriptionProviderOverride ?? ProviderSelection(providerType: .cloud(selectedTranscriptionProvider))
    }

    /// Returns effective translation provider (context override or global)
    var effectiveTranslationProvider: ProviderSelection {
        return activeContext?.translationProviderOverride ?? ProviderSelection(providerType: .cloud(selectedTranslationProvider))
    }

    /// Returns effective AI/LLM provider for Power Mode (context override or global)
    var effectiveAIProvider: ProviderSelection {
        return activeContext?.aiProviderOverride ?? ProviderSelection(providerType: .cloud(selectedPowerModeProvider))
    }
}
