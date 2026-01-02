//
//  ArabicAutocorrectService.swift
//  SwiftSpeakKeyboard
//
//  Arabic language autocorrection service
//  Handles common diacritic patterns and ligatures
//

import Foundation

/// Arabic autocorrection service for intelligent Arabic text correction
enum ArabicAutocorrectService {

    // MARK: - Main Correction Method

    /// Fix Arabic word - handles common patterns
    /// Returns nil if no correction needed
    static func fixArabicWord(_ word: String) -> String? {
        // Skip if not Arabic script
        guard isArabicScript(word) else { return nil }

        let normalized = normalizeArabic(word)

        // Check for common corrections
        if let corrected = arabicCorrections[normalized] {
            return corrected
        }

        // Check for alef variants
        if let corrected = fixAlefVariants(word) {
            return corrected
        }

        return nil
    }

    // MARK: - Arabic Script Detection

    /// Check if text is in Arabic script
    static func isArabicScript(_ text: String) -> Bool {
        for char in text {
            // Arabic Unicode range: U+0600 to U+06FF
            if char >= "\u{0600}" && char <= "\u{06FF}" {
                return true
            }
            // Arabic Extended-A: U+08A0 to U+08FF
            if char >= "\u{08A0}" && char <= "\u{08FF}" {
                return true
            }
        }
        return false
    }

    // MARK: - Normalization

    /// Normalize Arabic text (remove diacritics for comparison)
    private static func normalizeArabic(_ text: String) -> String {
        var result = text

        // Remove tashkeel (diacritics)
        let diacritics: [Character] = [
            "\u{064B}",  // Fathatan
            "\u{064C}",  // Dammatan
            "\u{064D}",  // Kasratan
            "\u{064E}",  // Fatha
            "\u{064F}",  // Damma
            "\u{0650}",  // Kasra
            "\u{0651}",  // Shadda
            "\u{0652}",  // Sukun
        ]

        for diacritic in diacritics {
            result = result.replacingOccurrences(of: String(diacritic), with: "")
        }

        return result
    }

    /// Fix alef variants to standard form
    private static func fixAlefVariants(_ text: String) -> String? {
        var modified = text
        var wasModified = false

        // Alef variants that should be standardized
        let alefMappings: [(from: Character, to: Character)] = [
            ("\u{0622}", "\u{0627}"),  // Alef with madda -> Alef
            ("\u{0623}", "\u{0627}"),  // Alef with hamza above -> Alef
            ("\u{0625}", "\u{0627}"),  // Alef with hamza below -> Alef
            ("\u{0671}", "\u{0627}"),  // Alef wasla -> Alef
        ]

        for (from, to) in alefMappings {
            if modified.contains(from) {
                modified = modified.replacingOccurrences(of: String(from), with: String(to))
                wasModified = true
            }
        }

        return wasModified ? modified : nil
    }

    // MARK: - Common Corrections

    private static let arabicCorrections: [String: String] = [
        // Common greetings
        "السلام عليكم": "السلام عليكم",
        "مرحبا": "مرحبًا",

        // Common words with proper spelling
        "ان شاء الله": "إن شاء الله",
        "انشاء الله": "إن شاء الله",
        "انشاءالله": "إن شاء الله",
        "الحمدلله": "الحمد لله",
        "ماشاء الله": "ما شاء الله",
        "ماشاءالله": "ما شاء الله",

        // Common prepositions
        "فى": "في",
        "الى": "إلى",
        "على": "على",

        // Common conjunctions
        "لاكن": "لكن",
        "لاكنه": "لكنه",

        // Common verbs
        "اريد": "أريد",
        "اعرف": "أعرف",
        "افهم": "أفهم",
        "اقول": "أقول",
        "اعتقد": "أعتقد",
    ]

    // MARK: - RTL Handling

    /// Check if text needs RTL direction
    static func needsRTL(_ text: String) -> Bool {
        return isArabicScript(text)
    }

    /// Get text direction for display
    static func getTextDirection(_ text: String) -> String {
        return needsRTL(text) ? "rtl" : "ltr"
    }
}
