//
//  TranslationProvider.swift
//  SwiftSpeak
//
//  Created by Claude Code on 26/12/2025.
//

import Foundation

/// Protocol for text translation providers
/// Phase 2 implementation - interface defined now for architecture consistency
protocol TranslationProvider {
    /// The provider identifier
    var providerId: AIProvider { get }

    /// Whether the provider is properly configured
    var isConfigured: Bool { get }

    /// The model being used for translation
    var model: String { get }

    /// Languages supported by this provider
    var supportedLanguages: [Language] { get }

    /// Whether this provider supports formality control
    var supportsFormality: Bool { get }

    /// Translate text to the target language with optional context
    /// - Parameters:
    ///   - text: Text to translate
    ///   - from: Source language (nil for auto-detection)
    ///   - to: Target language
    ///   - formality: Desired formality level (formal, informal, neutral)
    ///   - context: Optional PromptContext for LLM-based providers
    /// - Returns: Translated text
    /// - Throws: TranscriptionError on failure
    func translate(
        text: String,
        from sourceLanguage: Language?,
        to targetLanguage: Language,
        formality: Formality?,
        context: PromptContext?
    ) async throws -> String
}

// MARK: - Default Implementation

extension TranslationProvider {
    /// Default: formality not supported
    var supportsFormality: Bool { false }

    /// Convenience method without formality or context
    func translate(
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
    func translate(text: String, to targetLanguage: Language) async throws -> String {
        try await translate(text: text, from: nil, to: targetLanguage, formality: nil, context: nil)
    }

    /// Convenience method with formality but no context
    func translate(
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
