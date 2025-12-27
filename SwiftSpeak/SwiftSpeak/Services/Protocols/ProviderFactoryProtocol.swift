//
//  ProviderFactoryProtocol.swift
//  SwiftSpeak
//
//  Protocol for provider factory to enable testing
//

import Foundation

/// Protocol for creating provider instances
/// Enables dependency injection and testing
@MainActor
protocol ProviderFactoryProtocol {
    /// Create the currently selected transcription provider
    func createSelectedTranscriptionProvider() -> TranscriptionProvider?

    /// Create the currently selected formatting/text provider
    func createSelectedTextFormattingProvider() -> FormattingProvider?
}

// MARK: - ProviderFactory Conformance

extension ProviderFactory: ProviderFactoryProtocol {}
