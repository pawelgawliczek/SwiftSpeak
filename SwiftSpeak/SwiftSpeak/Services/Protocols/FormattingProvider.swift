//
//  FormattingProvider.swift
//  SwiftSpeak
//
//  Created by Claude Code on 26/12/2025.
//

import Foundation

/// Protocol for text formatting providers using LLMs
/// Formats transcribed text according to templates (Email, Formal, Casual)
protocol FormattingProvider {
    /// The provider identifier
    var providerId: AIProvider { get }

    /// Whether the provider is properly configured
    var isConfigured: Bool { get }

    /// The model being used for formatting
    var model: String { get }

    /// Format transcribed text according to the specified mode
    /// - Parameters:
    ///   - text: Raw transcribed text to format
    ///   - mode: Formatting mode (raw, email, formal, casual)
    ///   - customPrompt: Optional custom template prompt (overrides mode prompt)
    /// - Returns: Formatted text
    /// - Throws: TranscriptionError on failure
    func format(
        text: String,
        mode: FormattingMode,
        customPrompt: String?
    ) async throws -> String
}

// MARK: - Default Implementation

extension FormattingProvider {
    /// Convenience method without custom prompt
    func format(text: String, mode: FormattingMode) async throws -> String {
        try await format(text: text, mode: mode, customPrompt: nil)
    }

    /// Raw mode returns text unchanged
    func formatIfNeeded(text: String, mode: FormattingMode) async throws -> String {
        if mode == .raw {
            return text
        }
        return try await format(text: text, mode: mode, customPrompt: nil)
    }
}
