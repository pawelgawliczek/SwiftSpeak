//
//  AccentMappings.swift
//  SwiftSpeakKeyboard
//
//  Accent character mappings for long-press accent popup
//

import Foundation

// MARK: - Accent Mappings
struct AccentMappings {
    // MARK: - Accent Data

    /// Mapping of base letters to their accent variations
    /// Ordered by frequency/commonality (most common first)
    static let accents: [String: [String]] = [
        // Uppercase
        "A": ["Á", "À", "Â", "Ä", "Ã", "Å", "Ą", "Æ"],
        "C": ["Ć", "Ç", "Č", "Ĉ"],
        "E": ["É", "È", "Ê", "Ë", "Ę", "Ě", "Ė"],
        "I": ["Í", "Ì", "Î", "Ï", "Į", "İ"],
        "L": ["Ł"],
        "N": ["Ń", "Ñ", "Ň"],
        "O": ["Ó", "Ò", "Ô", "Ö", "Õ", "Ø", "Œ", "Ő"],
        "S": ["Ś", "Š", "Ş", "ẞ"],
        "U": ["Ú", "Ù", "Û", "Ü", "Ų", "Ů", "Ű"],
        "Y": ["Ý", "Ÿ"],
        "Z": ["Ź", "Ż", "Ž"],

        // Lowercase
        "a": ["á", "à", "â", "ä", "ã", "å", "ą", "æ"],
        "c": ["ć", "ç", "č", "ĉ"],
        "e": ["é", "è", "ê", "ë", "ę", "ě", "ė"],
        "i": ["í", "ì", "î", "ï", "į", "ı"],
        "l": ["ł"],
        "n": ["ń", "ñ", "ň"],
        "o": ["ó", "ò", "ô", "ö", "õ", "ø", "œ", "ő"],
        "s": ["ś", "š", "ş", "ß"],
        "u": ["ú", "ù", "û", "ü", "ų", "ů", "ű"],
        "y": ["ý", "ÿ"],
        "z": ["ź", "ż", "ž"]
    ]

    // MARK: - Helper Methods

    /// Get accent variations for a given letter
    /// - Parameter letter: The base letter (e.g., "a", "A", "e")
    /// - Returns: Array of accent variations, or nil if letter has no accents
    static func accentsFor(_ letter: String) -> [String]? {
        return accents[letter]
    }

    /// Check if a letter has accent variations
    /// - Parameter letter: The letter to check
    /// - Returns: True if the letter has accents available
    static func hasAccents(_ letter: String) -> Bool {
        return accents[letter] != nil
    }
}
