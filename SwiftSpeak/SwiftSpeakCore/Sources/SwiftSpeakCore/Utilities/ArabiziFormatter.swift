//
//  ArabiziFormatter.swift
//  SwiftSpeakCore
//
//  Converts Arabic script to Arabizi (Franco-Arabic) format
//  Uses Latin alphabet with number substitutions for Arabic-specific sounds
//
//  Standard Arabizi mappings:
//  - 3 = ع (ayn)
//  - 7 = ح (haa)
//  - 2 = ء (hamza)
//  - 5 = خ (kha)
//  - 6 = ط (taa emphatic)
//  - 9 = ص (sad)
//  - 4 = ذ (thal)
//  - 3' = غ (ghayn)
//

import Foundation

/// Converts Arabic script text to Arabizi (Franco-Arabic) format
/// Also known as "chat Arabic" or "Arabish"
public enum ArabiziFormatter {

    // MARK: - Public API

    /// Convert Arabic script to Arabizi (Franco-Arabic)
    /// - Parameter text: Arabic text to convert
    /// - Returns: Text in Arabizi format with Latin letters and number substitutions
    public static func toArabizi(_ text: String) -> String {
        var result = text

        // Apply mappings in order (complex patterns first)
        for (arabic, arabizi) in orderedMappings {
            result = result.replacingOccurrences(of: arabic, with: arabizi)
        }

        // Clean up any remaining Arabic diacritics
        for diacritic in arabicDiacritics {
            result = result.replacingOccurrences(of: diacritic, with: "")
        }

        return result
    }

    /// Check if text contains Arabic script
    /// - Parameter text: Text to check
    /// - Returns: True if text contains Arabic characters
    public static func containsArabic(_ text: String) -> Bool {
        // Arabic Unicode range: U+0600 to U+06FF (Arabic), U+0750 to U+077F (Arabic Supplement)
        let arabicRange = CharacterSet(charactersIn: "\u{0600}"..."\u{06FF}")
            .union(CharacterSet(charactersIn: "\u{0750}"..."\u{077F}"))

        for scalar in text.unicodeScalars {
            if arabicRange.contains(scalar) {
                return true
            }
        }
        return false
    }

    // MARK: - Private Mappings

    /// Ordered mappings from Arabic to Arabizi
    /// Order matters - complex patterns should come first
    private static let orderedMappings: [(String, String)] = [
        // Special letter combinations (Egyptian Arabic specific)
        ("الله", "allah"),         // Allah - special case
        ("لله", "lillah"),         // for Allah

        // Letters with number substitutions (most distinctive)
        ("ع", "3"),                // ayn
        ("ح", "7"),                // haa
        ("ء", "2"),                // hamza (standalone)
        ("ئ", "2"),                // hamza on ya carrier
        ("ؤ", "2"),                // hamza on waw carrier
        ("أ", "2a"),               // hamza on alif (above)
        ("إ", "2e"),               // hamza on alif (below)
        ("آ", "2a"),               // alif madda
        ("خ", "5"),                // kha
        ("ق", "2"),                // qaf - Egyptian Arabic uses glottal stop (like hamza)
        ("ص", "9"),                // sad
        ("ط", "6"),                // taa emphatic
        ("ض", "9'"),               // dad
        ("ذ", "4"),                // thal
        ("غ", "3'"),               // ghayn
        ("ظ", "6'"),               // zaa emphatic

        // Two-letter combinations
        ("ث", "th"),               // tha
        ("ش", "sh"),               // shin

        // Egyptian Arabic specific: ج = g (not j)
        ("ج", "g"),                // jim - Egyptian pronunciation

        // Basic letters
        ("ا", "a"),                // alif
        ("ب", "b"),                // ba
        ("ت", "t"),                // ta
        ("ن", "n"),                // nun
        ("ي", "y"),                // ya (consonant)
        ("ى", "a"),                // alif maqsura
        ("ة", "a"),                // ta marbuta (word ending)
        ("د", "d"),                // dal
        ("ر", "r"),                // ra
        ("ز", "z"),                // zay
        ("س", "s"),                // sin
        ("ف", "f"),                // fa
        ("ك", "k"),                // kaf
        ("ل", "l"),                // lam
        ("م", "m"),                // mim
        ("ه", "h"),                // ha
        ("و", "w"),                // waw (consonant)

        // Arabic-Indic numerals to Western numerals
        ("٠", "0"),
        ("١", "1"),
        ("٢", "2"),
        ("٣", "3"),
        ("٤", "4"),
        ("٥", "5"),
        ("٦", "6"),
        ("٧", "7"),
        ("٨", "8"),
        ("٩", "9"),

        // Punctuation
        ("،", ","),                // Arabic comma
        ("؛", ";"),                // Arabic semicolon
        ("؟", "?"),                // Arabic question mark
    ]

    /// Arabic diacritics to remove
    private static let arabicDiacritics: [String] = [
        "َ",   // fatha (a)
        "ُ",   // damma (u)
        "ِ",   // kasra (i)
        "ّ",   // shadda (gemination)
        "ْ",   // sukun (no vowel)
        "ً",   // tanwin fatha
        "ٌ",   // tanwin damma
        "ٍ",   // tanwin kasra
        "ٰ",   // superscript alif
        "ـ",   // tatweel (kashida)
    ]
}

// MARK: - Convenience Extensions

public extension String {
    /// Convert Arabic text to Arabizi format
    var arabizi: String {
        ArabiziFormatter.toArabizi(self)
    }

    /// Check if string contains Arabic script
    var containsArabic: Bool {
        ArabiziFormatter.containsArabic(self)
    }
}
