//
//  TextCheckerCompletions.swift
//  SwiftSpeakKeyboard
//
//  Uses UITextChecker to provide word completions and spelling corrections
//  Integrates Apple's built-in dictionary for high-quality predictions
//

import UIKit

/// Provides word completions using UITextChecker
enum TextCheckerCompletions {

    // MARK: - Lazy UITextChecker

    private static var _textChecker: UITextChecker?
    private static var textChecker: UITextChecker {
        if _textChecker == nil {
            _textChecker = UITextChecker()
        }
        return _textChecker!
    }

    private static var _availableLanguages: Set<String>?
    private static var availableLanguages: Set<String> {
        if _availableLanguages == nil {
            _availableLanguages = Set(UITextChecker.availableLanguages)
        }
        return _availableLanguages!
    }

    // Language code mapping
    private static let languageMap: [String: String] = [
        "en": "en_US",
        "es": "es_ES",
        "fr": "fr_FR",
        "de": "de_DE",
        "it": "it_IT",
        "pt": "pt_PT",
        "pl": "pl_PL",
        "ru": "ru_RU",
        "ar": "ar_SA",
        "zh": "zh_Hans",
        "ja": "ja_JP",
        "ko": "ko_KR",
    ]

    // MARK: - Word Completions

    /// Get word completions for a partial word
    /// Uses UITextChecker.completions(forPartialWordRange:in:language:)
    static func getCompletions(for prefix: String, language: String, maxResults: Int = 5) -> [String] {
        guard !prefix.isEmpty, prefix.count >= 2 else { return [] }

        // Get locale for language
        guard let locale = getActualLocale(for: language) else { return [] }

        // UITextChecker.completions expects the partial word in a string
        let range = NSRange(location: 0, length: prefix.utf16.count)

        guard let completions = textChecker.completions(
            forPartialWordRange: range,
            in: prefix,
            language: locale
        ) else {
            return []
        }

        // Filter and limit results
        return completions
            .filter { $0.lowercased() != prefix.lowercased() }
            .prefix(maxResults)
            .map { $0 }
    }

    // MARK: - Spelling Correction for Predictions

    /// Get spelling correction if the prefix appears to be misspelled
    /// Returns the correction that should appear in predictions
    static func getSpellingCorrection(for word: String, language: String) -> String? {
        guard !word.isEmpty, word.count >= 2 else { return nil }

        // Use SpellChecker's correction
        return SpellChecker.correctWord(word, language: language)
    }

    /// Get multiple spelling suggestions for predictions
    static func getSpellingSuggestions(for word: String, language: String, maxResults: Int = 3) -> [String] {
        guard !word.isEmpty, word.count >= 2 else { return [] }

        return SpellChecker.getSuggestions(word, language: language, maxSuggestions: maxResults)
    }

    // MARK: - Combined Predictions

    /// Get combined completions and corrections for a prefix
    /// Returns completions if word is valid, corrections if it appears misspelled
    static func getPredictions(for prefix: String, language: String, maxResults: Int = 5) -> [String] {
        guard !prefix.isEmpty, prefix.count >= 2 else { return [] }

        var predictions: [String] = []

        // 1. First check if this might be a misspelling - add corrections first
        let corrections = getSpellingSuggestions(for: prefix, language: language, maxResults: 2)
        predictions.append(contentsOf: corrections)

        // 2. Get word completions
        let completions = getCompletions(for: prefix, language: language, maxResults: maxResults)
        for completion in completions {
            if !predictions.contains(where: { $0.lowercased() == completion.lowercased() }) {
                predictions.append(completion)
            }
        }

        return Array(predictions.prefix(maxResults))
    }

    // MARK: - Helpers

    private static func getActualLocale(for language: String) -> String? {
        guard let mapped = languageMap[language] else { return nil }

        // Check if directly available
        if availableLanguages.contains(mapped) {
            return mapped
        }

        // Try prefix match
        let prefix = String(mapped.prefix(2))
        if let prefixMatch = availableLanguages.first(where: { $0.hasPrefix(prefix) }) {
            return prefixMatch
        }

        return nil
    }
}
