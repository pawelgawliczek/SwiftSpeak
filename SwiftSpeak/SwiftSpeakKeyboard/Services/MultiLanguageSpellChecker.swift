//
//  MultiLanguageSpellChecker.swift
//  SwiftSpeakKeyboard
//
//  Unified spell checking for all supported languages
//  Uses static functions to avoid singleton initialization hang
//

import Foundation
import UIKit

/// Multi-language spell checker using static functions (no singleton)
enum SpellChecker {

    // MARK: - Lazy UITextChecker (only created when needed)

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

    // MARK: - Public API

    /// Correct a potentially misspelled word in the given language
    static func correctWord(_ word: String, language languageCode: String) -> String? {
        // Safety: Skip empty words
        guard !word.isEmpty else { return nil }

        let lowercased = word.lowercased()

        // Skip single chars
        guard lowercased.count >= 2 else { return nil }

        // Safety: Skip very long words (likely garbage or URLs)
        guard lowercased.count <= 50 else { return nil }

        // Safety: Skip words with invalid characters (URLs, paths, etc.)
        guard !word.contains("/") && !word.contains("@") && !word.contains(":") else { return nil }

        // Skip words in language-specific ignore list
        if shouldIgnoreWord(lowercased, language: languageCode) {
            return nil
        }

        // 1. Check language-specific priority corrections first (fast dictionary lookup)
        if let correction = getPriorityCorrection(lowercased, language: languageCode) {
            return preserveCase(original: word, corrected: correction)
        }

        // 2. Use UITextChecker for this language
        if let locale = getLanguageMap()[languageCode],
           let correction = checkWithUITextChecker(word, language: locale) {
            return preserveCase(original: word, corrected: correction)
        }

        return nil
    }

    /// Check if spell checking is available for a language
    static func isLanguageSupported(_ languageCode: String) -> Bool {
        return getLanguageMap()[languageCode] != nil
    }

    /// Get all supported language codes
    static func supportedLanguages() -> [String] {
        return Array(getLanguageMap().keys)
    }

    // MARK: - Private Helpers

    private static func shouldIgnoreWord(_ word: String, language: String) -> Bool {
        return getIgnoreWords()[language]?.contains(word) ?? false
    }

    private static func getPriorityCorrection(_ word: String, language: String) -> String? {
        return getPriorityCorrections()[language]?[word]
    }

    private static func preserveCase(original: String, corrected: String) -> String {
        guard !original.isEmpty && !corrected.isEmpty else { return corrected }

        // All uppercase
        if original == original.uppercased() && original != original.lowercased() {
            return corrected.uppercased()
        }

        // First letter uppercase
        if original.first?.isUppercase == true {
            return corrected.prefix(1).uppercased() + corrected.dropFirst()
        }

        return corrected.lowercased()
    }

    // MARK: - UITextChecker Integration

    private static func checkWithUITextChecker(_ word: String, language locale: String) -> String? {
        // Safety: Validate inputs
        guard !locale.isEmpty, !word.isEmpty, word.utf16.count > 0 else { return nil }

        // Check if language is available (with prefix fallback)
        let langPrefix = String(locale.prefix(2))
        let isDirectMatch = availableLanguages.contains(locale)
        let isPrefixMatch = availableLanguages.contains(where: { $0.hasPrefix(langPrefix) })

        guard isDirectMatch || isPrefixMatch else { return nil }

        // Find the actual locale to use
        let actualLocale: String
        if isDirectMatch {
            actualLocale = locale
        } else if let prefixMatch = availableLanguages.first(where: { $0.hasPrefix(langPrefix) }) {
            actualLocale = prefixMatch
        } else {
            return nil
        }

        // Create the range for the full word
        let wordLength = word.utf16.count
        guard wordLength > 0 && wordLength <= 1000 else { return nil }

        let range = NSRange(location: 0, length: wordLength)

        // Check if word is misspelled
        let misspelledRange = textChecker.rangeOfMisspelledWord(
            in: word,
            range: range,
            startingAt: 0,
            wrap: false,
            language: actualLocale
        )

        // Word is correctly spelled
        guard misspelledRange.location != NSNotFound else { return nil }

        // Get suggestions
        let guesses = textChecker.guesses(
            forWordRange: misspelledRange,
            in: word,
            language: actualLocale
        )

        // Return top suggestion if available and different
        if let topGuess = guesses?.first,
           !topGuess.isEmpty,
           topGuess.lowercased() != word.lowercased() {
            return topGuess
        }

        return nil
    }

    // MARK: - Lazy-loaded Data

    private static func getLanguageMap() -> [String: String] {
        return [
            "en": "en_US",
            "es": "es_ES",
            "fr": "fr_FR",
            "de": "de_DE",
            "it": "it_IT",
            "pt": "pt_PT",
            "pl": "pl_PL",
            "ru": "ru_RU",
            "ar": "ar_SA",
            "arz": "ar_EG",
            "zh": "zh_Hans",
            "ja": "ja_JP",
            "ko": "ko_KR",
        ]
    }

    private static func getIgnoreWords() -> [String: Set<String>] {
        return [
            "en": ["its", "were", "well", "hell", "shell", "wed", "id", "ill", "wont", "cant"],
            "de": ["das", "dass"],
            "es": ["el", "si", "mas", "aun", "solo"],
            "fr": ["a", "ou", "la", "sa"],
        ]
    }

    private static func getPriorityCorrections() -> [String: [String: String]] {
        return [
            "en": [
                // Contractions
                "dont": "don't", "cant": "can't", "wont": "won't",
                "didnt": "didn't", "wasnt": "wasn't", "isnt": "isn't",
                "hasnt": "hasn't", "havent": "haven't", "wouldnt": "wouldn't",
                "couldnt": "couldn't", "shouldnt": "shouldn't",
                "youre": "you're", "theyre": "they're", "hes": "he's",
                "shes": "she's", "thats": "that's", "whats": "what's",
                "lets": "let's", "ive": "I've", "youve": "you've",
                "weve": "we've", "theyve": "they've", "im": "I'm",
                "youll": "you'll", "theyll": "they'll", "itll": "it'll",
                // Common typos
                "teh": "the", "hte": "the", "thw": "the", "tge": "the",
                "adn": "and", "nad": "and", "anf": "and",
                "taht": "that", "htat": "that", "tath": "that",
                "wiht": "with", "wtih": "with", "iwth": "with",
                "fro": "for", "fpr": "for", "ofr": "for",
                "yuo": "you", "oyu": "you", "uyo": "you",
                "aer": "are", "rae": "are", "ear": "are",
                "wsa": "was", "asw": "was", "aws": "was",
                "hsa": "has", "ahs": "has",
                "ahve": "have", "hvae": "have", "haev": "have",
                "jsut": "just", "jstu": "just", "ujst": "just",
                "nto": "not", "ont": "not",
                "thn": "than", "htan": "than",
                "htem": "them", "tehm": "them",
                "thsi": "this", "htis": "this", "tihs": "this",
                "fomr": "from", "rfom": "from",
                "cna": "can", "acn": "can",
                "wlil": "will", "iwll": "will", "willl": "will",
                "knwo": "know", "konw": "know", "nkow": "know",
                "abotu": "about", "baout": "about", "aobut": "about",
                "becuase": "because", "beacuse": "because", "becasue": "because",
                "seperate": "separate", "seperete": "separate",
                "definately": "definitely", "definatly": "definitely",
                "recieve": "receive", "recevie": "receive",
                "occured": "occurred",
                "untill": "until", "untl": "until",
                "realy": "really", "relaly": "really",
                "buisness": "business", "busines": "business",
                "goverment": "government", "govenment": "government",
                "enviroment": "environment", "enviornment": "environment",
            ],
            "de": [
                "fur": "für", "uber": "über", "konnen": "können",
                "mussen": "müssen", "wurde": "würde", "naturlich": "natürlich",
                "zuruck": "zurück", "grun": "grün", "schon": "schön",
                "gross": "groß", "strasse": "Straße", "weiss": "weiß",
                "udn": "und", "dsa": "das", "eni": "ein", "nciht": "nicht",
            ],
            "es": [
                "como": "cómo", "que": "qué", "esta": "está",
                "dias": "días", "tambien": "también", "mas": "más",
                "aqui": "aquí", "asi": "así", "numero": "número",
                "telefono": "teléfono", "ingles": "inglés",
                "espanol": "español", "ano": "año", "manana": "mañana",
                "nino": "niño", "senor": "señor",
            ],
            "fr": [
                "etre": "être", "tres": "très", "apres": "après",
                "deja": "déjà", "ou": "où", "ca": "ça", "francais": "français",
                "eleve": "élève", "etude": "étude", "cafe": "café",
                "hotel": "hôtel", "hopital": "hôpital",
                "cest": "c'est", "jai": "j'ai", "daccord": "d'accord",
            ],
            "it": [
                "citta": "città", "perche": "perché", "piu": "più",
                "gia": "già", "cosi": "così", "pero": "però",
                "verra": "verrà", "sara": "sarà", "puo": "può",
                "universita": "università", "caffe": "caffè",
            ],
            "pt": [
                "nao": "não", "sao": "são", "tambem": "também",
                "voce": "você", "esta": "está", "ate": "até",
                "ja": "já", "so": "só", "numero": "número",
                "informacao": "informação", "coracao": "coração",
            ],
            "pl": [
                "zolty": "żółty", "zrodlo": "źródło", "swiat": "świat",
                "dziekuje": "dziękuję", "prosze": "proszę", "czesc": "cześć",
                "szczescie": "szczęście", "zycze": "życzę",
                "dzien": "dzień", "slonce": "słońce", "piekny": "piękny",
                "moze": "może", "ze": "że", "rowniez": "również",
            ],
            "ru": [
                "еще": "ещё", "все": "всё", "ее": "её",
                "ежик": "ёжик", "елка": "ёлка",
            ],
            "ar": [:],
            "arz": [:],
            "zh": [:],
            "ja": [:],
            "ko": [:],
        ]
    }
}

// MARK: - Legacy Compatibility (for existing code that uses MultiLanguageSpellChecker.shared)

final class MultiLanguageSpellChecker {
    static let shared = MultiLanguageSpellChecker()
    private init() {}

    func correctWord(_ word: String, language languageCode: String) -> String? {
        return SpellChecker.correctWord(word, language: languageCode)
    }

    func isValidWord(_ word: String, language languageCode: String) -> Bool {
        return true // Disabled
    }

    func isLanguageSupported(_ languageCode: String) -> Bool {
        return SpellChecker.isLanguageSupported(languageCode)
    }

    func supportedLanguages() -> [String] {
        return SpellChecker.supportedLanguages()
    }
}
