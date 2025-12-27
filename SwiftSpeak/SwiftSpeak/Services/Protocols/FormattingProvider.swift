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

    /// Format transcribed text according to the specified mode with optional context
    /// - Parameters:
    ///   - text: Raw transcribed text to format
    ///   - mode: Formatting mode (raw, email, formal, casual)
    ///   - customPrompt: Optional custom template prompt (overrides mode prompt)
    ///   - context: Optional PromptContext for memory, tone, and instructions injection
    /// - Returns: Formatted text
    /// - Throws: TranscriptionError on failure
    func format(
        text: String,
        mode: FormattingMode,
        customPrompt: String?,
        context: PromptContext?
    ) async throws -> String
}

// MARK: - Default Implementation

extension FormattingProvider {
    /// Convenience method without context
    func format(
        text: String,
        mode: FormattingMode,
        customPrompt: String?
    ) async throws -> String {
        try await format(text: text, mode: mode, customPrompt: customPrompt, context: nil)
    }

    /// Convenience method without custom prompt or context
    func format(text: String, mode: FormattingMode) async throws -> String {
        try await format(text: text, mode: mode, customPrompt: nil, context: nil)
    }

    /// Raw mode returns text unchanged
    func formatIfNeeded(text: String, mode: FormattingMode) async throws -> String {
        if mode == .raw {
            return text
        }
        return try await format(text: text, mode: mode, customPrompt: nil, context: nil)
    }

    /// Format with context but no custom prompt
    func format(
        text: String,
        mode: FormattingMode,
        context: PromptContext?
    ) async throws -> String {
        try await format(text: text, mode: mode, customPrompt: nil, context: context)
    }
}
