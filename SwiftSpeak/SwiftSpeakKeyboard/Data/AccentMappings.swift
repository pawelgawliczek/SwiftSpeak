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

    // MARK: - Punctuation Popup (long-press period)
    static let punctuation: [String] = [".", ",", "?", "!", ";", ":", "'", "\"", "-", "/", "(", ")"]

    // MARK: - Number Fractions (long-press numbers)
    static let fractions: [String: [String]] = [
        "1": ["¹", "½", "⅓", "¼", "⅕", "⅙", "⅛"],
        "2": ["²", "⅔", "⅖"],
        "3": ["³", "¾", "⅗", "⅜"],
        "4": ["⁴", "⅘"],
        "5": ["⁵", "⅝", "⅚"],
        "6": ["⁶"],
        "7": ["⁷", "⅞"],
        "8": ["⁸"],
        "9": ["⁹"],
        "0": ["⁰", "∅", "°"]
    ]

    // MARK: - Currency Symbols (long-press $)
    static let currencies: [String] = ["$", "€", "£", "¥", "₹", "₽", "₩", "¢"]

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

    /// Get fraction variations for a number
    static func fractionsFor(_ number: String) -> [String]? {
        return fractions[number]
    }

    /// Check if a number has fractions
    static func hasFractions(_ number: String) -> Bool {
        return fractions[number] != nil
    }

    /// Check if key has any popup (accent, fraction, punctuation, currency)
    static func hasPopup(_ key: String) -> Bool {
        return accents[key] != nil ||
               fractions[key] != nil ||
               key == "." ||
               key == "$"
    }

    /// Get popup options for any key
    static func popupFor(_ key: String) -> [String]? {
        if let acc = accents[key] { return acc }
        if let frac = fractions[key] { return frac }
        if key == "." { return punctuation }
        if key == "$" { return currencies }
        return nil
    }
}
