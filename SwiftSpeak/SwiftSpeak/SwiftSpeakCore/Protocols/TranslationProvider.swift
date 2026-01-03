//
//  TranslationProvider.swift
//  SwiftSpeak
//
//  Created by Claude Code on 26/12/2025.
//

import Foundation

/// Protocol for text translation providers
/// Phase 2 implementation - interface defined now for architecture consistency
public protocol TranslationProvider {
    /// The provider identifier
    public var providerId: AIProvider { get }

    /// Whether the provider is properly configured
    public var isConfigured: Bool { get }

    /// The model being used for translation
    public var model: String { get }

    /// Languages supported by this provider
    public var supportedLanguages: [Language] { get }

    /// Whether this provider supports formality control
    public var supportsFormality: Bool { get }

    /// Translate text to the target language with optional context
    /// - Parameters:
    ///   - text: Text to translate
    ///   - from: Source language (nil for auto-detection)
    ///   - to: Target language
    ///   - formality: Desired formality level (formal, informal, neutral)
    ///   - context: Optional PromptContext for LLM-based providers
    /// - Returns: Translated text
    /// - Throws: TranscriptionError on failure
    public func translate(
        text: String,
        from sourceLanguage: Language?,
        to targetLanguage: Language,
        formality: Formality?,
        context: PromptContext?
    ) async throws -> String
}

// MARK: - Default Implementation

public extension TranslationProvider {
    /// Default: formality not supported
    public var supportsFormality: Bool { false }

    /// Convenience method without formality or context
    public func translate(
        text: String,
        from sourceLanguage: Language?,
        to targetLanguage: Language
    ) async throws -> String {
        try await translate(
            text: text,
            from: sourceLanguage,
            to: targetLanguage,
            formality: nil,
            context: nil
        )
    }

    /// Convenience method with auto-detection of source language
    public func translate(text: String, to targetLanguage: Language) async throws -> String {
        try await translate(text: text, from: nil, to: targetLanguage, formality: nil, context: nil)
    }

    /// Convenience method with formality but no context
    public func translate(
        text: String,
        from sourceLanguage: Language?,
        to targetLanguage: Language,
        formality: Formality?
    ) async throws -> String {
        try await translate(
            text: text,
            from: sourceLanguage,
            to: targetLanguage,
            formality: formality,
            context: nil
        )
    }
}
