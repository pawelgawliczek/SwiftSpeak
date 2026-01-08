//
//  ProviderFactoryProtocol.swift
//  SwiftSpeak
//
//  Protocol for provider factory to enable testing
//

import Foundation
import SwiftSpeakCore

/// Protocol for creating provider instances
/// Enables dependency injection and testing
@MainActor
protocol ProviderFactoryProtocol {
    /// Create the currently selected transcription provider
    func createSelectedTranscriptionProvider() -> TranscriptionProvider?

    /// Create the currently selected formatting/text provider
    func createSelectedTextFormattingProvider() -> FormattingProvider?

    /// Create transcription provider using effective provider (respects context overrides)
    func createEffectiveTranscriptionProvider() -> TranscriptionProvider?

    /// Create translation provider using effective provider (respects context overrides)
    func createEffectiveTranslationProvider() -> TranslationProvider?

    /// Create formatting provider using effective provider (respects context overrides)
    func createEffectiveFormattingProvider() -> FormattingProvider?
}

// MARK: - ProviderFactory Conformance

extension ProviderFactory: ProviderFactoryProtocol {}
