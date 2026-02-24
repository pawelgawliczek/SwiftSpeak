// ============================================================================
// LEGACY: NOT USED - Kept for reference only
// Replaced by: MultiLanguageSpellChecker.swift (SpellChecker enum)
// The actual autocorrect uses SpellChecker.correctWord() which has its own
// getPriorityCorrections() dictionary. DO NOT add typo fixes here.
// ============================================================================
//
//  EnglishSymSpellService.swift
//  SwiftSpeakKeyboard
//
//  Hybrid spelling correction using:
//  1. Hardcoded common typos (instant)
//  2. UITextChecker (Apple's optimized spell checker)
//

import Foundation
import UIKit

/// Hybrid English spelling correction service
/// Uses hardcoded typos + Apple's UITextChecker for robust, memory-efficient correction
final class EnglishSymSpellService {

    // MARK: - Singleton

    static let shared = EnglishSymSpellService()

    // MARK: - Properties

    /// Apple's built-in spell checker (optimized, low memory)
    private let textChecker = UITextChecker()

    /// Language for spell checking
    private let language = "en_US"

    /// Common typos that UITextChecker might miss or get wrong
    /// These take priority over UITextChecker suggestions
    private let priorityTypos: [String: String] = [
        // 2-letter typos (UITextChecker often struggles with these)
        "br": "be", "eb": "be", "nr": "no", "fo": "of", "ti": "it",
        "si": "is", "ro": "or", "ot": "to", "ta": "at", "fi": "if",
        "em": "me", "ew": "we", "od": "do", "os": "so", "pu": "up",
        "yb": "by", "sa": "as", "eh": "he", "ni": "in", "ym": "my",
        "og": "go", "su": "us",

        // Common contractions without apostrophes
        "dont": "don't", "cant": "can't", "wont": "won't",
        "didnt": "didn't", "wasnt": "wasn't", "isnt": "isn't",
        "hasnt": "hasn't", "havent": "haven't", "wouldnt": "wouldn't",
        "couldnt": "couldn't", "shouldnt": "shouldn't",
        "youre": "you're", "theyre": "they're", "were": "we're",
        "hes": "he's", "shes": "she's", "its": "it's",
        "thats": "that's", "whats": "what's", "whos": "who's",
        "lets": "let's", "heres": "here's", "theres": "there's",
        "ive": "I've", "youve": "you've", "weve": "we've", "theyve": "they've",
        "shouldve": "should've", "wouldve": "would've", "couldve": "could've",
        "im": "I'm", "ill": "I'll", "id": "I'd",
        "youll": "you'll", "theyll": "they'll", "well": "we'll",
        "itll": "it'll", "thatll": "that'll",

        // Very common typos
        "teh": "the", "hte": "the", "thw": "the",
        "adn": "and", "nad": "and",
        "taht": "that", "htat": "that",
        "wiht": "with", "wtih": "with",
        "fro": "for", "fpr": "for",
        "yuo": "you", "oyu": "you",
        "jsut": "just", "juts": "just",
        "hwo": "how", "whn": "when", "waht": "what",
        "whre": "where", "wich": "which", "thn": "then",
        "thne": "then", "fomr": "from",
        "abotu": "about", "baout": "about",
        "thier": "their", "tehy": "they",
        "becuase": "because", "beacuse": "because",
        "beleive": "believe", "recieve": "receive",
        "untill": "until", "occured": "occurred",
        "seperate": "separate", "definately": "definitely",
        "accomodate": "accommodate", "occassion": "occasion",
        "neccessary": "necessary", "goverment": "government",
    ]

    /// Words that should NOT be autocorrected (valid words often flagged)
    private let ignoreWords: Set<String> = [
        "its", "were", "well", "hell", "shell", "wed", "id",
        "ill", "wont", "cant", // These have valid non-contraction meanings
    ]

    // MARK: - Initialization

    private init() {
        keyboardLog("EnglishSymSpellService initialized with UITextChecker", category: "SymSpell")
    }

    // MARK: - Public API

    /// Correct a potentially misspelled word
    func correctWord(_ word: String) -> String? {
        let lowercased = word.lowercased()

        // Skip single chars
        guard lowercased.count >= 2 else { return nil }

        // Skip words in ignore list
        if ignoreWords.contains(lowercased) {
            return nil
        }

        // 1. Check priority typos first (instant, handles contractions + common mistakes)
        if let correction = priorityTypos[lowercased] {
            return preserveCase(original: word, corrected: correction)
        }

        // 2. Use UITextChecker for everything else
        if let correction = checkWithUITextChecker(word) {
            return preserveCase(original: word, corrected: correction)
        }

        return nil
    }

    /// Check if a word is valid (correctly spelled)
    func isValidWord(_ word: String) -> Bool {
        let range = NSRange(location: 0, length: word.utf16.count)
        let misspelledRange = textChecker.rangeOfMisspelledWord(
            in: word,
            range: range,
            startingAt: 0,
            wrap: false,
            language: language
        )
        return misspelledRange.location == NSNotFound
    }

    // MARK: - UITextChecker Integration

    /// Get correction from Apple's spell checker
    private func checkWithUITextChecker(_ word: String) -> String? {
        let range = NSRange(location: 0, length: word.utf16.count)

        // First check if word is misspelled
        let misspelledRange = textChecker.rangeOfMisspelledWord(
            in: word,
            range: range,
            startingAt: 0,
            wrap: false,
            language: language
        )

        // Word is correctly spelled
        guard misspelledRange.location != NSNotFound else {
            return nil
        }

        // Get suggestions
        let guesses = textChecker.guesses(
            forWordRange: misspelledRange,
            in: word,
            language: language
        )

        // Return top suggestion if available
        if let topGuess = guesses?.first {
            // Verify it's actually different
            if topGuess.lowercased() != word.lowercased() {
                return topGuess
            }
        }

        return nil
    }

    // MARK: - Case Preservation

    private func preserveCase(original: String, corrected: String) -> String {
        guard !original.isEmpty && !corrected.isEmpty else { return corrected }

        // All uppercase
        if original == original.uppercased() && original != original.lowercased() {
            return corrected.uppercased()
        }

        // First letter uppercase (title case)
        if original.first?.isUppercase == true {
            return corrected.prefix(1).uppercased() + corrected.dropFirst()
        }

        // All lowercase
        return corrected.lowercased()
    }
}
