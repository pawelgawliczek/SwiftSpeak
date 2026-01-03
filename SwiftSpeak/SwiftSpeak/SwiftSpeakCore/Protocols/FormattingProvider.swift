//
//  FormattingProvider.swift
//  SwiftSpeak
//
//  Created by Claude Code on 26/12/2025.
//

import Foundation

/// Protocol for text formatting providers using LLMs
/// Formats transcribed text according to templates (Email, Formal, Casual)
public protocol FormattingProvider {
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

public extension FormattingProvider {
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

// MARK: - Streaming Formatting Provider

/// Optional streaming capability for formatting providers (Power Mode only)
///
/// Providers that support streaming can yield text chunks progressively as the LLM
/// generates the response. This provides a more responsive user experience in Power Mode.
///
/// Note: This is specifically for Power Mode text generation, NOT for transcription or translation.
public protocol StreamingFormattingProvider: FormattingProvider {
    /// Whether this provider supports streaming responses
    var supportsStreaming: Bool { get }

    /// Stream formatted text chunks progressively
    /// - Parameters:
    ///   - text: Raw transcribed text to format
    ///   - mode: Formatting mode (raw, email, formal, casual)
    ///   - customPrompt: Optional custom template prompt (overrides mode prompt)
    ///   - context: Optional PromptContext for memory, tone, and instructions injection
    /// - Returns: AsyncThrowingStream that yields text chunks as they arrive
    func formatStreaming(
        text: String,
        mode: FormattingMode,
        customPrompt: String?,
        context: PromptContext?
    ) -> AsyncThrowingStream<String, Error>
}

// MARK: - Default Streaming Implementation

public extension StreamingFormattingProvider {
    /// Default: streaming not supported (fallback to blocking)
    var supportsStreaming: Bool { false }

    /// Default implementation wraps blocking format() in a stream
    /// Providers that support streaming should override this
    func formatStreaming(
        text: String,
        mode: FormattingMode,
        customPrompt: String?,
        context: PromptContext?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await format(
                        text: text,
                        mode: mode,
                        customPrompt: customPrompt,
                        context: context
                    )
                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Convenience method without context
    func formatStreaming(
        text: String,
        mode: FormattingMode,
        customPrompt: String?
    ) -> AsyncThrowingStream<String, Error> {
        formatStreaming(text: text, mode: mode, customPrompt: customPrompt, context: nil)
    }

    /// Convenience method without custom prompt
    func formatStreaming(
        text: String,
        mode: FormattingMode,
        context: PromptContext?
    ) -> AsyncThrowingStream<String, Error> {
        formatStreaming(text: text, mode: mode, customPrompt: nil, context: context)
    }
}
