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
    /// Comprehensive set matching Gboard/iOS keyboard support
    /// Ordered by frequency/commonality (most common first)
    static let accents: [String: [String]] = [
        // Uppercase vowels
        "A": ["Á", "À", "Â", "Ä", "Ã", "Å", "Ā", "Ą", "Æ"],
        "E": ["É", "È", "Ê", "Ë", "Ē", "Ę", "Ě", "Ė"],
        "I": ["Í", "Ì", "Î", "Ï", "Ī", "Į", "İ"],
        "O": ["Ó", "Ò", "Ô", "Ö", "Õ", "Ō", "Ø", "Œ", "Ő"],
        "U": ["Ú", "Ù", "Û", "Ü", "Ū", "Ų", "Ů", "Ű"],

        // Uppercase consonants
        "C": ["Ć", "Ç", "Č", "Ĉ"],
        "D": ["Ď", "Đ", "Ð"],
        "G": ["Ğ", "Ģ", "Ĝ"],
        "H": ["Ħ"],
        "K": ["Ķ"],
        "L": ["Ł", "Ľ", "Ļ", "Ĺ"],
        "N": ["Ń", "Ñ", "Ň", "Ņ"],
        "R": ["Ř", "Ŕ"],
        "S": ["Ś", "Š", "Ş", "Ș", "ẞ"],
        "T": ["Ť", "Ţ", "Ț", "Þ"],
        "W": ["Ẃ", "Ẁ", "Ŵ"],
        "Y": ["Ý", "Ÿ", "Ŷ"],
        "Z": ["Ź", "Ż", "Ž"],

        // Lowercase vowels
        "a": ["á", "à", "â", "ä", "ã", "å", "ā", "ą", "æ"],
        "e": ["é", "è", "ê", "ë", "ē", "ę", "ě", "ė"],
        "i": ["í", "ì", "î", "ï", "ī", "į", "ı"],
        "o": ["ó", "ò", "ô", "ö", "õ", "ō", "ø", "œ", "ő"],
        "u": ["ú", "ù", "û", "ü", "ū", "ų", "ů", "ű"],

        // Lowercase consonants
        "c": ["ć", "ç", "č", "ĉ"],
        "d": ["ď", "đ", "ð"],
        "g": ["ğ", "ģ", "ĝ"],
        "h": ["ħ"],
        "k": ["ķ"],
        "l": ["ł", "ľ", "ļ", "ĺ"],
        "n": ["ń", "ñ", "ň", "ņ"],
        "r": ["ř", "ŕ"],
        "s": ["ś", "š", "ş", "ș", "ß"],
        "t": ["ť", "ţ", "ț", "þ"],
        "w": ["ẃ", "ẁ", "ŵ"],
        "y": ["ý", "ÿ", "ŷ"],
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
