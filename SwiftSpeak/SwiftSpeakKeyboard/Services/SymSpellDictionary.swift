//
//  SymSpellDictionary.swift
//  SwiftSpeakKeyboard
//
//  Manages per-language SymSpell dictionaries with lazy loading
//  Only loads one language at a time to conserve memory
//

import Foundation

// MARK: - SymSpellDictionary

/// Manages per-language SymSpell dictionaries with lazy loading
enum SymSpellDictionary {

    // MARK: - Supported Languages

    /// Languages with SymSpell dictionaries available
    /// Based on Hermit Dave's FrequencyWords (OpenSubtitles 2018)
    static let supportedLanguages: Set<String> = [
        "en",   // English
        "pl",   // Polish
        "ar",   // Arabic
        "arz",  // Egyptian Arabic (uses ar dictionary)
        "es",   // Spanish
        "fr",   // French
        "de",   // German
        "it",   // Italian
        "pt",   // Portuguese
        "ru",   // Russian
        "zh",   // Chinese
        "ja",   // Japanese
        "ko",   // Korean
    ]

    // MARK: - State

    /// Currently loaded language
    private static var currentLanguage: String?

    /// The active SymSpell instance
    private static var symSpell: SymSpell?

    /// Loading state
    private static var isLoading: Bool = false

    /// Queue for background loading
    private static let loadingQueue = DispatchQueue(label: "com.swiftspeak.symspell.loading", qos: .userInitiated)

    // MARK: - Public API

    /// Get SymSpell instance for a language (returns nil if not yet loaded, triggers background load)
    static func getInstance(for language: String) -> SymSpell? {
        keyboardLog("SymSpellDict: getInstance(\(language)) called, current=\(currentLanguage ?? "nil"), isLoading=\(isLoading)", category: "SpellDebug")

        // Check if already loaded for this language
        if currentLanguage == language, let instance = symSpell, instance.isLoaded {
            keyboardLog("SymSpellDict: returning cached instance with \(instance.wordCount) words", category: "SpellDebug")
            return instance
        }

        // Check if language is supported
        guard supportedLanguages.contains(language) else {
            keyboardLog("SymSpellDict: language \(language) not supported", category: "SpellDebug")
            return nil
        }

        // If not loading, trigger background load
        if !isLoading {
            keyboardLog("SymSpellDict: triggering background load for \(language)", category: "SpellDebug")
            triggerBackgroundLoad(for: language)
        } else {
            keyboardLog("SymSpellDict: already loading, skipping", category: "SpellDebug")
        }

        // Return nil - SymSpell not ready yet, caller should fall back to UITextChecker
        keyboardLog("SymSpellDict: returning nil (not loaded yet)", category: "SpellDebug")
        return nil
    }

    /// Trigger background loading (non-blocking)
    private static func triggerBackgroundLoad(for language: String) {
        guard !isLoading else { return }
        isLoading = true

        keyboardLog("SymSpellDict: background load starting for \(language)", category: "SpellDebug")
        let startTime = CFAbsoluteTimeGetCurrent()

        loadingQueue.async {
            keyboardLog("SymSpellDict: background thread started", category: "SpellDebug")

            // Unload previous language if different
            if currentLanguage != nil && currentLanguage != language {
                symSpell?.unload()
                symSpell = nil
                currentLanguage = nil
            }

            // Load new dictionary
            _ = loadDictionarySync(for: language)
            isLoading = false

            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            keyboardLog("SymSpellDict: background load completed in \(String(format: "%.2f", elapsed))s", category: "SpellDebug")
        }
    }

    /// Check if a language is supported
    static func isSupported(_ language: String) -> Bool {
        return supportedLanguages.contains(language)
    }

    /// Get currently loaded language
    static func getLoadedLanguage() -> String? {
        return currentLanguage
    }

    /// Check if any dictionary is loaded
    static func hasLoadedDictionary() -> Bool {
        return symSpell?.isLoaded ?? false
    }

    /// Unload current dictionary to free memory
    static func unloadCurrent() {
        symSpell?.unload()
        symSpell = nil
        currentLanguage = nil
        keyboardLog("SymSpellDictionary: Unloaded current dictionary", category: "SymSpell")
    }

    // MARK: - Private Loading

    /// Load dictionary for a specific language (synchronous - call from background thread)
    private static func loadDictionarySync(for language: String) -> SymSpell? {
        // Map language code to dictionary filename
        let filename = dictionaryFilename(for: language)

        // Try to load from bundle
        guard let url = Bundle.main.url(forResource: filename, withExtension: "txt"),
              let data = try? Data(contentsOf: url) else {
            keyboardLog("SymSpellDictionary: Failed to load \(filename).txt", category: "SymSpell")
            return nil
        }

        // Create and load SymSpell
        let instance = SymSpell(maxEditDistance: 2, prefixLength: 7)
        instance.load(from: data)

        if instance.isLoaded {
            symSpell = instance
            currentLanguage = language
            keyboardLog("SymSpellDictionary: Loaded \(language) with \(instance.wordCount) words", category: "SymSpell")
            return instance
        }

        return nil
    }

    /// Map language code to dictionary filename
    private static func dictionaryFilename(for language: String) -> String {
        switch language {
        case "arz":
            return "ar_symspell"  // Egyptian Arabic uses Arabic dictionary
        default:
            return "\(language)_symspell"
        }
    }
}

// MARK: - Arabic Normalization

extension SymSpellDictionary {

    /// Normalize Arabic text for spell checking
    /// Handles alef variants, taa marbuta, and diacritics
    static func normalizeArabic(_ word: String) -> String {
        var result = word

        // Normalize alef variants (أ إ آ ا) → ا
        result = result.replacingOccurrences(of: "أ", with: "ا")
        result = result.replacingOccurrences(of: "إ", with: "ا")
        result = result.replacingOccurrences(of: "آ", with: "ا")
        result = result.replacingOccurrences(of: "ٱ", with: "ا")

        // Normalize alef maksura (ى) → ي
        result = result.replacingOccurrences(of: "ى", with: "ي")

        // Remove Arabic diacritics (harakat)
        let diacritics: [Character] = [
            "\u{064B}", // fathatan
            "\u{064C}", // dammatan
            "\u{064D}", // kasratan
            "\u{064E}", // fatha
            "\u{064F}", // damma
            "\u{0650}", // kasra
            "\u{0651}", // shadda
            "\u{0652}", // sukun
            "\u{0653}", // maddah
            "\u{0654}", // hamza above
            "\u{0655}", // hamza below
            "\u{0670}", // superscript alef
        ]
        result = String(result.filter { !diacritics.contains($0) })

        return result
    }

    /// Check if a language uses Arabic script
    static func isArabicLanguage(_ language: String) -> Bool {
        return language == "ar" || language == "arz"
    }
}

// MARK: - Polish Normalization

extension SymSpellDictionary {

    /// Normalize Polish text for spell checking
    /// Maps ASCII to Polish diacritics when appropriate
    static func normalizePolish(_ word: String) -> String {
        // Polish doesn't need normalization in the same way
        // The SymSpell dictionary handles both forms
        return word.lowercased()
    }
}
