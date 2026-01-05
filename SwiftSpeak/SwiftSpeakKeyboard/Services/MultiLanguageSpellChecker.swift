//
//  MultiLanguageSpellChecker.swift
//  SwiftSpeakKeyboard
//
//  Unified spell checking for all supported languages using UITextChecker
//  Combines Apple's spell checker with language-specific priority corrections
//

import Foundation
import UIKit

/// Multi-language spell checker using UITextChecker + priority corrections
final class MultiLanguageSpellChecker {

    // MARK: - Singleton

    static let shared = MultiLanguageSpellChecker()

    // MARK: - Properties

    /// Apple's built-in spell checker
    private let textChecker = UITextChecker()

    /// Available languages from UITextChecker
    private let availableLanguages: Set<String>

    /// Map our language codes to UITextChecker locale codes
    private let languageMap: [String: String] = [
        "en": "en_US",
        "es": "es_ES",
        "fr": "fr_FR",
        "de": "de_DE",
        "it": "it_IT",
        "pt": "pt_PT",
        "pl": "pl_PL",
        "ru": "ru_RU",
        "ar": "ar_SA",
        "arz": "ar_EG",  // Egyptian Arabic falls back to Arabic
        "zh": "zh_Hans", // Simplified Chinese
        "ja": "ja_JP",
        "ko": "ko_KR",
    ]

    /// Priority corrections per language (checked before UITextChecker)
    /// These handle common typos, contractions, and diacritics that UITextChecker might miss
    private let priorityCorrections: [String: [String: String]] = [
        "en": [
            // 2-letter typos
            "br": "be", "eb": "be", "nr": "no", "fo": "of", "ti": "it",
            "si": "is", "ro": "or", "ot": "to", "ta": "at", "fi": "if",
            "em": "me", "ew": "we", "od": "do", "os": "so", "pu": "up",
            "yb": "by", "sa": "as", "eh": "he", "ni": "in", "ym": "my",
            "og": "go", "su": "us",
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
            "form": "from", "fomr": "from", "rfom": "from",
            "cna": "can", "acn": "can",
            "wlil": "will", "iwll": "will", "willl": "will",
            "knwo": "know", "konw": "know", "nkow": "know",
            "abotu": "about", "baout": "about", "aobut": "about",
            "becuase": "because", "beacuse": "because", "becasue": "because",
            "seperate": "separate", "seperete": "separate",
            "definately": "definitely", "definatly": "definitely",
            "recieve": "receive", "recevie": "receive",
            "occured": "occurred", "occured": "occurred",
            "untill": "until", "untl": "until",
            "realy": "really", "relaly": "really",
            "buisness": "business", "busines": "business",
            "goverment": "government", "govenment": "government",
            "enviroment": "environment", "enviornment": "environment",
        ],
        "de": [
            // Umlaut restoration
            "fur": "für", "uber": "über", "konnen": "können",
            "mussen": "müssen", "wurde": "würde", "naturlich": "natürlich",
            "zuruck": "zurück", "grun": "grün", "schon": "schön",
            "gross": "groß", "strasse": "Straße", "weiss": "weiß",
            // Common typos
            "udn": "und", "dsa": "das", "eni": "ein", "nciht": "nicht",
        ],
        "es": [
            // Accent restoration
            "como": "cómo", "que": "qué", "esta": "está",
            "dias": "días", "tambien": "también", "mas": "más",
            "aqui": "aquí", "asi": "así", "numero": "número",
            "telefono": "teléfono", "ingles": "inglés",
            // ñ restoration
            "espanol": "español", "ano": "año", "manana": "mañana",
            "nino": "niño", "senor": "señor",
        ],
        "fr": [
            // Accent restoration
            "etre": "être", "tres": "très", "apres": "après",
            "deja": "déjà", "ou": "où", "ca": "ça", "francais": "français",
            "eleve": "élève", "etude": "étude", "cafe": "café",
            "hotel": "hôtel", "hopital": "hôpital",
            // Common contractions
            "cest": "c'est", "jai": "j'ai", "daccord": "d'accord",
        ],
        "it": [
            // Accent restoration
            "citta": "città", "perche": "perché", "piu": "più",
            "gia": "già", "cosi": "così", "pero": "però",
            "verra": "verrà", "sara": "sarà", "puo": "può",
            "universita": "università", "caffe": "caffè",
        ],
        "pt": [
            // Accent/tilde restoration
            "nao": "não", "sao": "são", "tambem": "também",
            "voce": "você", "esta": "está", "ate": "até",
            "ja": "já", "so": "só", "e": "é", "numero": "número",
            "informacao": "informação", "coracao": "coração",
        ],
        "pl": [
            // Diacritic restoration
            "zolty": "żółty", "zrodlo": "źródło", "swiat": "świat",
            "dziekuje": "dziękuję", "prosze": "proszę", "czesc": "cześć",
            "szczescie": "szczęście", "zycze": "życzę",
            "dzien": "dzień", "slonce": "słońce", "piekny": "piękny",
            // Common words
            "moze": "może", "ze": "że", "rowniez": "również",
        ],
        "ru": [
            // ё restoration (often typed as е)
            "еще": "ещё", "все": "всё", "ее": "её",
            "ежик": "ёжик", "елка": "ёлка",
            // Common typos
            "тоже": "тоже", "можно": "можно",
        ],
        "ar": [:],  // Arabic handled by language-specific service
        "arz": [:], // Egyptian Arabic handled by language-specific service
        "zh": [:],  // Chinese handled by UITextChecker + language service
        "ja": [:],  // Japanese handled by UITextChecker + language service
        "ko": [:],  // Korean handled by UITextChecker + language service
    ]

    /// Words to ignore per language (valid words that shouldn't be corrected)
    private let ignoreWords: [String: Set<String>] = [
        "en": ["its", "were", "well", "hell", "shell", "wed", "id", "ill", "wont", "cant"],
        "de": ["das", "dass"],
        "es": ["el", "si", "mas", "aun", "solo"],
        "fr": ["a", "ou", "la", "sa"],
    ]

    // MARK: - Initialization

    private init() {
        // Get available languages from UITextChecker
        availableLanguages = Set(UITextChecker.availableLanguages)
        keyboardLog("MultiLanguageSpellChecker initialized. Available: \(availableLanguages.count) languages", category: "SpellCheck")
    }

    // MARK: - Public API

    /// Correct a potentially misspelled word in the given language
    /// - Parameters:
    ///   - word: The word to check
    ///   - languageCode: Our language code (e.g., "en", "de", "es")
    /// - Returns: Corrected word if misspelled, nil if correct or no suggestion
    func correctWord(_ word: String, language languageCode: String) -> String? {
        let lowercased = word.lowercased()

        // Skip single chars
        guard lowercased.count >= 2 else { return nil }

        // Skip words in language-specific ignore list
        if let ignoreSet = ignoreWords[languageCode], ignoreSet.contains(lowercased) {
            return nil
        }

        // 1. Check language-specific priority corrections first
        if let corrections = priorityCorrections[languageCode],
           let correction = corrections[lowercased] {
            return preserveCase(original: word, corrected: correction)
        }

        // 2. Use UITextChecker for this language
        if let locale = languageMap[languageCode],
           let correction = checkWithUITextChecker(word, language: locale) {
            return preserveCase(original: word, corrected: correction)
        }

        return nil
    }

    /// Check if a word is valid in the given language
    func isValidWord(_ word: String, language languageCode: String) -> Bool {
        guard let locale = languageMap[languageCode] else { return true }

        let range = NSRange(location: 0, length: word.utf16.count)
        let misspelledRange = textChecker.rangeOfMisspelledWord(
            in: word,
            range: range,
            startingAt: 0,
            wrap: false,
            language: locale
        )
        return misspelledRange.location == NSNotFound
    }

    /// Check if spell checking is available for a language
    func isLanguageSupported(_ languageCode: String) -> Bool {
        guard let locale = languageMap[languageCode] else { return false }
        return availableLanguages.contains(locale) ||
               availableLanguages.contains(where: { $0.hasPrefix(languageCode) })
    }

    /// Get all supported language codes
    func supportedLanguages() -> [String] {
        return languageMap.keys.filter { isLanguageSupported($0) }
    }

    // MARK: - UITextChecker Integration

    private func checkWithUITextChecker(_ word: String, language locale: String) -> String? {
        // Check if language is available
        guard availableLanguages.contains(locale) ||
              availableLanguages.contains(where: { $0.hasPrefix(locale.prefix(2)) }) else {
            return nil
        }

        let actualLocale = availableLanguages.contains(locale) ? locale :
            availableLanguages.first(where: { $0.hasPrefix(locale.prefix(2)) }) ?? locale

        let range = NSRange(location: 0, length: word.utf16.count)

        // Check if word is misspelled
        let misspelledRange = textChecker.rangeOfMisspelledWord(
            in: word,
            range: range,
            startingAt: 0,
            wrap: false,
            language: actualLocale
        )

        // Word is correctly spelled
        guard misspelledRange.location != NSNotFound else {
            return nil
        }

        // Get suggestions
        let guesses = textChecker.guesses(
            forWordRange: misspelledRange,
            in: word,
            language: actualLocale
        )

        // Return top suggestion if available and different
        if let topGuess = guesses?.first,
           topGuess.lowercased() != word.lowercased() {
            return topGuess
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

        // First letter uppercase
        if original.first?.isUppercase == true {
            return corrected.prefix(1).uppercased() + corrected.dropFirst()
        }

        return corrected.lowercased()
    }
}
