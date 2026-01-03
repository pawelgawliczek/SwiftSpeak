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
public protocol ProviderFactoryProtocol {
    /// Create the currently selected transcription provider
    public func createSelectedTranscriptionProvider() -> TranscriptionProvider?

    /// Create the currently selected formatting/text provider
    public func createSelectedTextFormattingProvider() -> FormattingProvider?
}

// MARK: - ProviderFactory Conformance

public extension ProviderFactory: ProviderFactoryProtocol {}
