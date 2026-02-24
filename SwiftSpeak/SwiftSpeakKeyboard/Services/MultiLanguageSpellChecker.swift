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

    // MARK: - Polish Diacritics Dictionary (lazy loaded from file)

    private static var _polishDiacriticsDict: [String: String]?
    private static var polishDiacriticsDict: [String: String] {
        if _polishDiacriticsDict == nil {
            _polishDiacriticsDict = loadPolishDiacriticsDictionary()
        }
        return _polishDiacriticsDict!
    }

    /// Load Polish ASCII -> diacritics mapping from pl_diacritics.txt (20k entries from NKJP corpus)
    private static func loadPolishDiacriticsDictionary() -> [String: String] {
        guard let bundlePath = Bundle.main.path(forResource: "pl_diacritics", ofType: "txt", inDirectory: "Dictionaries") else {
            keyboardLog("Polish diacritics dictionary not found", category: "SpellCheck")
            return [:]
        }

        do {
            let content = try String(contentsOfFile: bundlePath, encoding: .utf8)
            var dict: [String: String] = [:]
            dict.reserveCapacity(20000)

            for line in content.components(separatedBy: .newlines) {
                let parts = line.split(separator: " ", maxSplits: 1)
                if parts.count == 2 {
                    let ascii = String(parts[0])
                    let proper = String(parts[1])
                    dict[ascii] = proper
                }
            }

            keyboardLog("Loaded \(dict.count) Polish diacritics corrections", category: "SpellCheck")
            return dict
        } catch {
            keyboardLog("Failed to load Polish diacritics: \(error)", category: "SpellCheck")
            return [:]
        }
    }

    // MARK: - Public API

    /// Correct a potentially misspelled word in the given language
    static func correctWord(_ word: String, language languageCode: String) -> String? {
        let startTime = CFAbsoluteTimeGetCurrent()
        keyboardLog("SpellCheck START: '\(word)' lang=\(languageCode)", category: "SpellDebug")

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
            keyboardLog("SpellCheck: '\(word)' in ignore list", category: "SpellDebug")
            return nil
        }

        // 1. Check language-specific priority corrections first (fast dictionary lookup)
        keyboardLog("SpellCheck: checking priority corrections...", category: "SpellDebug")
        if let correction = getPriorityCorrection(lowercased, language: languageCode) {
            keyboardLog("SpellCheck: priority correction found '\(correction)' in \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - startTime))s", category: "SpellDebug")
            return preserveCase(original: word, corrected: correction)
        }

        // 2. Use SymSpell for edit-distance based correction (50k word dictionaries)
        // TEMPORARILY DISABLED FOR DEBUGGING
        /*
        keyboardLog("SpellCheck: checking SymSpell...", category: "SpellDebug")
        let symSpellStart = CFAbsoluteTimeGetCurrent()
        if let correction = checkWithSymSpell(word, language: languageCode) {
            keyboardLog("SpellCheck: SymSpell found '\(correction)' in \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - symSpellStart))s", category: "SpellDebug")
            return preserveCase(original: word, corrected: correction)
        }
        keyboardLog("SpellCheck: SymSpell done in \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - symSpellStart))s", category: "SpellDebug")
        */

        // 3. Use UITextChecker as fallback (Apple's dictionary)
        keyboardLog("SpellCheck: checking UITextChecker...", category: "SpellDebug")
        let uiTextStart = CFAbsoluteTimeGetCurrent()
        if let locale = getLanguageMap()[languageCode],
           let correction = checkWithUITextChecker(word, language: locale) {
            keyboardLog("SpellCheck: UITextChecker found '\(correction)' in \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - uiTextStart))s", category: "SpellDebug")
            return preserveCase(original: word, corrected: correction)
        }
        keyboardLog("SpellCheck: UITextChecker done in \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - uiTextStart))s", category: "SpellDebug")

        keyboardLog("SpellCheck END: no correction, total \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - startTime))s", category: "SpellDebug")
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

    // MARK: - Multiple Suggestions

    /// Get multiple spelling suggestions for a word (up to maxSuggestions)
    static func getSuggestions(_ word: String, language languageCode: String, maxSuggestions: Int = 3) -> [String] {
        guard !word.isEmpty, word.count >= 2, word.count <= 50 else { return [] }
        guard !word.contains("/") && !word.contains("@") && !word.contains(":") else { return [] }

        let lowercased = word.lowercased()

        // Skip ignored words
        if shouldIgnoreWord(lowercased, language: languageCode) {
            return []
        }

        var suggestions: [String] = []

        // 1. Check priority corrections first
        if let correction = getPriorityCorrection(lowercased, language: languageCode) {
            suggestions.append(preserveCase(original: word, corrected: correction))
        }

        // 2. Get UITextChecker suggestions
        if let locale = getLanguageMap()[languageCode] {
            let uiSuggestions = getUITextCheckerSuggestions(word, language: locale, max: maxSuggestions)
            for suggestion in uiSuggestions {
                let cased = preserveCase(original: word, corrected: suggestion)
                if !suggestions.contains(cased) && cased.lowercased() != word.lowercased() {
                    suggestions.append(cased)
                }
            }
        }

        return Array(suggestions.prefix(maxSuggestions))
    }

    /// Get multiple suggestions from UITextChecker
    private static func getUITextCheckerSuggestions(_ word: String, language locale: String, max: Int) -> [String] {
        guard !locale.isEmpty, !word.isEmpty, word.utf16.count > 0 else { return [] }

        let langPrefix = String(locale.prefix(2))
        let isDirectMatch = availableLanguages.contains(locale)
        let isPrefixMatch = availableLanguages.contains(where: { $0.hasPrefix(langPrefix) })

        guard isDirectMatch || isPrefixMatch else { return [] }

        let actualLocale: String
        if isDirectMatch {
            actualLocale = locale
        } else if let prefixMatch = availableLanguages.first(where: { $0.hasPrefix(langPrefix) }) {
            actualLocale = prefixMatch
        } else {
            return []
        }

        let range = NSRange(location: 0, length: word.utf16.count)
        let misspelledRange = textChecker.rangeOfMisspelledWord(
            in: word,
            range: range,
            startingAt: 0,
            wrap: false,
            language: actualLocale
        )

        guard misspelledRange.location != NSNotFound else { return [] }

        let guesses = textChecker.guesses(
            forWordRange: misspelledRange,
            in: word,
            language: actualLocale
        ) ?? []

        return Array(guesses.prefix(max))
    }

    // MARK: - User Vocabulary (Learned Words)

    /// Learn a word so it won't be flagged as misspelled
    static func learnWord(_ word: String) {
        guard !word.isEmpty else { return }
        UITextChecker.learnWord(word)
    }

    /// Check if a word has been learned
    static func hasLearnedWord(_ word: String) -> Bool {
        guard !word.isEmpty else { return false }
        return UITextChecker.hasLearnedWord(word)
    }

    /// Unlearn a previously learned word
    static func unlearnWord(_ word: String) {
        guard !word.isEmpty else { return }
        UITextChecker.unlearnWord(word)
    }

    /// Ignore a word for the current session only
    static func ignoreWord(_ word: String) {
        guard !word.isEmpty else { return }
        textChecker.ignoreWord(word)
    }

    // MARK: - Private Helpers

    private static func shouldIgnoreWord(_ word: String, language: String) -> Bool {
        return getIgnoreWords()[language]?.contains(word) ?? false
    }

    private static func getPriorityCorrection(_ word: String, language: String) -> String? {
        // First check hardcoded priority corrections
        if let correction = getPriorityCorrections()[language]?[word] {
            return correction
        }

        // For Polish, also check the 20k diacritics dictionary loaded from file
        if language == "pl" {
            return polishDiacriticsDict[word]
        }

        return nil
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

    // MARK: - SymSpell Integration

    /// Check word using SymSpell edit-distance algorithm
    private static func checkWithSymSpell(_ word: String, language languageCode: String) -> String? {
        // Check if SymSpell supports this language
        guard SymSpellDictionary.isSupported(languageCode) else { return nil }

        // Normalize word for Arabic languages
        let normalizedWord: String
        if SymSpellDictionary.isArabicLanguage(languageCode) {
            normalizedWord = SymSpellDictionary.normalizeArabic(word)
        } else {
            normalizedWord = word.lowercased()
        }

        // Get SymSpell instance (lazy loads dictionary)
        guard let symSpell = SymSpellDictionary.getInstance(for: languageCode) else {
            return nil
        }

        // Skip if word is known (correctly spelled)
        if symSpell.isKnownWord(normalizedWord) {
            return nil
        }

        // Lookup suggestions
        let suggestions = symSpell.lookup(normalizedWord, maxResults: 1)

        // Return best suggestion if within edit distance 2
        if let best = suggestions.first, best.distance <= 2 {
            return best.word
        }

        return nil
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

        // Return first VALID suggestion (verify it's a real word)
        for guess in guesses ?? [] {
            guard !guess.isEmpty, guess.lowercased() != word.lowercased() else { continue }

            // Verify the suggestion is itself a valid word (not garbage like "dornig")
            let guessRange = NSRange(location: 0, length: guess.utf16.count)
            let guessCheck = textChecker.rangeOfMisspelledWord(
                in: guess,
                range: guessRange,
                startingAt: 0,
                wrap: false,
                language: actualLocale
            )

            // If suggestion is NOT misspelled (valid word), use it
            if guessCheck.location == NSNotFound {
                return guess
            }
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
                "hoe": "how", "hwo": "how",  // Common "how" typos
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
                // być (to be) - extremely common
                "bedzie": "będzie", "bede": "będę", "bedziemy": "będziemy",
                "bedziecie": "będziecie", "beda": "będą",
                // reflexive & common particles
                "sie": "się", "juz": "już", "tez": "też", "wiec": "więc",
                // other common words
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
            "ar": [
                // Alef variations (أ إ آ ا) - normalize to proper form
                "اذا": "إذا",      // if (hamza below)
                "انا": "أنا",      // I (hamza above)
                "انت": "أنت",      // you (hamza above)
                "انتم": "أنتم",    // you (plural)
                "اخ": "أخ",        // brother
                "اخت": "أخت",      // sister
                "امس": "أمس",      // yesterday
                "اكل": "أكل",      // food/eating
                "امر": "أمر",      // matter/command
                "ابدا": "أبداً",   // never
                "ايضا": "أيضاً",   // also
                "اخر": "آخر",      // other/last
                "الان": "الآن",    // now

                // Taa marbuta (ة) vs Haa (ه) confusion
                "الجامعه": "الجامعة",  // university
                "المدرسه": "المدرسة",  // school
                "الحياه": "الحياة",    // life
                "الصلاه": "الصلاة",    // prayer
                "القاهره": "القاهرة",  // Cairo
                "اللغه": "اللغة",      // language
                "الكلمه": "الكلمة",    // word

                // Common typos - adjacent key swaps
                "شكار": "شكراً",    // thank you
                "مرحاب": "مرحباً",  // hello
                "السالم": "السلام", // peace
                "عيلك": "عليك",     // on you
                "معا": "معاً",      // together

                // Missing shadda/emphasis
                "الله": "اللّه",    // Allah (with shadda) - optional
                "محمد": "محمّد",    // Muhammad (with shadda) - optional
            ],
            "arz": [
                // Egyptian Arabic common corrections
                // Alef normalization (Egyptian often drops hamza)
                "انا": "أنا",      // I
                "انت": "إنت",      // you (Egyptian spelling with kasra)
                "انتي": "إنتي",    // you (feminine)
                "اية": "إيه",      // what (Egyptian)
                "ازيك": "إزيك",    // how are you (Egyptian)
                "ازاي": "إزاي",    // how (Egyptian)

                // Common Egyptian words with proper spelling
                "عايز": "عاوز",    // want (masc) - alternate form
                "كويس": "كويّس",   // good/fine
                "ماشي": "ماشي",    // ok/walking

                // Taa marbuta in Egyptian context
                "الجامعه": "الجامعة",
                "المدرسه": "المدرسة",
                "القاهره": "القاهرة",
                "اسكندريه": "إسكندرية", // Alexandria
            ],
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

    func getSuggestions(_ word: String, language languageCode: String, maxSuggestions: Int = 3) -> [String] {
        return SpellChecker.getSuggestions(word, language: languageCode, maxSuggestions: maxSuggestions)
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

    func learnWord(_ word: String) {
        SpellChecker.learnWord(word)
    }

    func hasLearnedWord(_ word: String) -> Bool {
        return SpellChecker.hasLearnedWord(word)
    }

    func unlearnWord(_ word: String) {
        SpellChecker.unlearnWord(word)
    }

    func ignoreWord(_ word: String) {
        SpellChecker.ignoreWord(word)
    }
}
