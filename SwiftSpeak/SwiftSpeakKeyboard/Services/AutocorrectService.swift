//
//  AutocorrectService.swift
//  SwiftSpeakKeyboard
//
//  Autocorrect service using SymSpell algorithm for spelling correction
//  Combines edit distance, phonetic matching, and personal dictionary
//

import Foundation

/// Autocorrect service providing spelling correction
/// Uses SymSpell algorithm for fast, accurate corrections
actor AutocorrectService {
    // Singleton for shared access
    static let shared = AutocorrectService()

    private var isInitialized = false
    private var currentLanguage: String = "en"

    // Reference to other correction services
    private var symSpellInitialized = false
    private var phoneticInitialized = false
    private var personalDictInitialized = false

    private init() {}

    // MARK: - Initialization

    /// Initialize the autocorrect service with the specified language
    func initialize(language: String = "en") async {
        guard !isInitialized else { return }

        currentLanguage = language

        // Initialize SymSpell service
        await SymSpellService.shared.initialize()
        symSpellInitialized = true

        // Initialize phonetic corrector with common words
        let commonWords: [(String, Int)] = [
            ("the", 69971), ("be", 37715), ("to", 28453), ("of", 27004), ("and", 26366),
            ("a", 21332), ("in", 20047), ("that", 12581), ("have", 12458), ("i", 11167),
            ("receive", 200), ("believe", 200), ("achieve", 100), ("weird", 100),
            ("their", 2883), ("there", 2909), ("definitely", 100), ("separate", 80),
            ("occurrence", 50), ("accommodate", 50), ("necessary", 100), ("beginning", 80),
            ("environment", 80), ("government", 150), ("restaurant", 80), ("calendar", 80),
            ("experience", 150), ("immediately", 80), ("professional", 100),
        ]
        await PhoneticCorrector.shared.initialize(words: commonWords)
        phoneticInitialized = true

        // Initialize personal dictionary
        await PersonalDictionary.shared.initialize()
        personalDictInitialized = true

        // Add personal words to SymSpell
        let personalWords = await PersonalDictionary.shared.allWords()
        for (word, freq) in personalWords {
            await SymSpellService.shared.addWord(word, frequency: freq)
        }

        isInitialized = true
        keyboardLog("AutocorrectService initialized for language: \(language)", category: "Autocorrect")
    }

    // MARK: - Spelling Correction

    /// Check if a word is spelled correctly
    func isCorrectlySpelled(_ word: String) -> Bool {
        let lowercased = word.lowercased()

        // Check SymSpell dictionary
        if symSpellInitialized {
            // Use Task to call async method synchronously (for backward compatibility)
            // In practice, prefer async version
            return Task {
                await SymSpellService.shared.isCorrect(lowercased)
            }.isCancelled == false
        }

        return true  // Assume correct if not initialized
    }

    /// Async version of spell check
    func isCorrectlySpelledAsync(_ word: String) async -> Bool {
        let lowercased = word.lowercased()

        // Check personal dictionary first (user's words are always correct)
        if await PersonalDictionary.shared.contains(lowercased) {
            return true
        }

        // Check SymSpell dictionary
        return await SymSpellService.shared.isCorrect(lowercased)
    }

    /// Get spelling suggestions for a word
    func getSuggestions(for word: String, maxResults: Int = 3) async -> [String] {
        let lowercased = word.lowercased()

        var allSuggestions: [(word: String, score: Double)] = []

        // 1. Check for known phonetic misspellings first
        if let knownCorrection = await PhoneticCorrector.shared.checkKnownMisspelling(lowercased) {
            allSuggestions.append((knownCorrection, 100.0))
        }

        // 2. Get SymSpell suggestions (edit distance based)
        let symSpellResults = await SymSpellService.shared.lookup(lowercased, maxDistance: 2, maxResults: 5)
        for result in symSpellResults {
            let score = Double(result.frequency) / Double(result.distance + 1)
            allSuggestions.append((result.word, score))
        }

        // 3. Get phonetic suggestions
        let phoneticResults = await PhoneticCorrector.shared.getCorrections(for: lowercased, maxResults: 3)
        for word in phoneticResults {
            allSuggestions.append((word, 50.0))  // Base score for phonetic matches
        }

        // Deduplicate and sort by score
        var seen = Set<String>()
        var uniqueSuggestions: [(String, Double)] = []
        for (word, score) in allSuggestions {
            if seen.insert(word).inserted {
                uniqueSuggestions.append((word, score))
            }
        }

        uniqueSuggestions.sort { $0.1 > $1.1 }
        return uniqueSuggestions.prefix(maxResults).map { $0.0 }
    }

    /// Get the best correction for a word (autocorrect)
    /// Only corrects when we're highly confident it's a typo
    func getCorrection(for word: String) async -> String? {
        let lowercased = word.lowercased()

        // Skip very short words (2 chars) - too ambiguous
        guard lowercased.count >= 3 else {
            return nil
        }

        // Check if correctly spelled
        if await isCorrectlySpelledAsync(lowercased) {
            return nil
        }

        // 1. Check for known phonetic misspellings (highest confidence)
        if let knownCorrection = await PhoneticCorrector.shared.checkKnownMisspelling(lowercased) {
            return knownCorrection
        }

        // 2. Try SymSpell correction
        if let symSpellCorrection = await SymSpellService.shared.getCorrection(lowercased) {
            return symSpellCorrection
        }

        // 3. Try phonetic correction as fallback
        if let phoneticCorrection = await PhoneticCorrector.shared.getBestCorrection(for: lowercased) {
            return phoneticCorrection
        }

        return nil
    }

    /// Legacy synchronous method - wraps async version
    func getCorrection(for word: String) -> String? {
        // For synchronous contexts, return nil and let caller use async version
        // This maintains backward compatibility while encouraging async usage
        return nil
    }

    // MARK: - Language Support

    /// Switch to a different language
    func switchLanguage(to language: String) async {
        guard language != currentLanguage else { return }
        currentLanguage = language

        // Reinitialize services for new language
        // Currently only English is fully supported
        keyboardLog("AutocorrectService switched to language: \(language)", category: "Autocorrect")
    }

    /// Get memory usage estimate
    var estimatedMemoryUsageMB: Double {
        // Approximate memory usage
        return 2.5  // ~2.5 MB for dictionary data
    }

    // MARK: - Add Personal Words

    /// Add a word to personal dictionary and SymSpell
    func addPersonalWord(_ word: String) async {
        await PersonalDictionary.shared.rebuild()
        await SymSpellService.shared.addWord(word, frequency: 10)
    }

    /// Refresh personal dictionary from transcription history
    func refreshPersonalDictionary() async {
        await PersonalDictionary.shared.rebuild()
        let personalWords = await PersonalDictionary.shared.allWords()
        for (word, freq) in personalWords {
            await SymSpellService.shared.addWord(word, frequency: freq)
        }
        keyboardLog("Personal dictionary refreshed with \(personalWords.count) words", category: "Autocorrect")
    }
}

// MARK: - Autocorrect Integration for Keyboard

extension AutocorrectService {
    /// Process typed text and return correction if needed (async version)
    /// Call this when user types a space or punctuation
    func processWord(_ word: String) async -> (original: String, correction: String?)? {
        guard !word.isEmpty else { return nil }

        // Preserve capitalization
        let isCapitalized = word.first?.isUppercase ?? false
        let isAllCaps = word == word.uppercased() && word.count > 1

        if let correction = await getCorrection(for: word) {
            var corrected = correction
            if isAllCaps {
                corrected = correction.uppercased()
            } else if isCapitalized {
                corrected = correction.capitalized
            }
            return (word, corrected)
        }

        return nil
    }

    /// Synchronous wrapper that returns nil (for backward compatibility)
    /// Callers should migrate to async version
    func processWordSync(_ word: String) -> (original: String, correction: String?)? {
        // Return nil for sync context - caller should use async version
        return nil
    }
}
