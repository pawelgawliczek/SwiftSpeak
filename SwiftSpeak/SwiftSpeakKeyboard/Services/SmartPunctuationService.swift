//
//  SmartPunctuationService.swift
//  SwiftSpeakKeyboard
//
//  Provides smart punctuation transformations
//  - Straight quotes to curly quotes
//  - Double space to period
//  - Auto-spacing after punctuation
//

import Foundation

/// Smart punctuation service for automatic text transformations
enum SmartPunctuationService {

    // MARK: - Quote Conversion

    /// Convert straight quotes to smart/curly quotes based on context
    static func smartQuote(for character: String, contextBefore: String?) -> String {
        let before = contextBefore ?? ""
        let lastChar = before.last

        switch character {
        case "\"":
            // Opening quote: after space, start of text, or opening bracket
            if before.isEmpty || lastChar == " " || lastChar == "\n" ||
               lastChar == "(" || lastChar == "[" || lastChar == "{" {
                return "\u{201C}"  // Left double quote "
            } else {
                return "\u{201D}"  // Right double quote "
            }

        case "'":
            // Check for common contractions (don't, won't, etc.)
            let contractionPrefixes = ["n", "t", "s", "d", "m", "l", "v", "r"]
            if let last = before.last, contractionPrefixes.contains(String(last).lowercased()) {
                return "\u{2019}"  // Apostrophe for contractions '
            }
            // Opening quote: after space, start of text, or opening bracket
            if before.isEmpty || lastChar == " " || lastChar == "\n" ||
               lastChar == "(" || lastChar == "[" || lastChar == "{" {
                return "\u{2018}"  // Left single quote '
            } else {
                return "\u{2019}"  // Right single quote / apostrophe '
            }

        default:
            return character
        }
    }

    // MARK: - Double Space to Period

    /// Check if we should convert double space to period
    /// Returns the text to insert (". " or " ") and whether deletion is needed
    static func handleDoubleSpace(contextBefore: String?) -> (text: String, shouldDeleteSpace: Bool)? {
        guard let before = contextBefore else { return nil }

        // Check if last character is a space
        guard before.hasSuffix(" ") else { return nil }

        // Get the text before the space
        let trimmed = before.dropLast()
        guard let lastChar = trimmed.last else { return nil }

        // Don't add period if already punctuated
        if lastChar == "." || lastChar == "!" || lastChar == "?" ||
           lastChar == "," || lastChar == ":" || lastChar == ";" {
            return nil
        }

        // Don't add period after numbers (could be decimal)
        if lastChar.isNumber {
            return nil
        }

        // Check if last character is a letter (word ending)
        if lastChar.isLetter {
            return (". ", true)  // Delete space, insert period + space
        }

        return nil
    }

    // MARK: - Auto-Capitalization After Punctuation

    /// Check if auto-capitalization should occur
    static func shouldAutoCapitalize(contextBefore: String?) -> Bool {
        guard let before = contextBefore else { return true }  // Start of text

        let trimmed = before.trimmingCharacters(in: .whitespaces)

        // Capitalize at start
        if trimmed.isEmpty { return true }

        // Capitalize after sentence-ending punctuation
        if trimmed.hasSuffix(".") || trimmed.hasSuffix("!") || trimmed.hasSuffix("?") {
            return true
        }

        return false
    }

    // MARK: - Auto-Space After Punctuation

    /// Check if we need to add a space after punctuation
    static func needsSpaceAfter(punctuation: String, nextChar: String?) -> Bool {
        let spacingPunctuation = [".", ",", "!", "?", ":", ";"]

        guard spacingPunctuation.contains(punctuation) else { return false }
        guard let next = nextChar else { return false }

        // Don't add space if next is already a space or punctuation
        if next == " " || spacingPunctuation.contains(next) {
            return false
        }

        // Add space before letters
        if next.first?.isLetter == true {
            return true
        }

        return false
    }

    // MARK: - Dash Conversion

    /// Convert double hyphen to em dash
    static func handleDash(contextBefore: String?) -> (text: String, deleteCount: Int)? {
        guard let before = contextBefore else { return nil }

        // Check for double hyphen
        if before.hasSuffix("-") {
            return ("—", 1)  // Delete one hyphen, insert em dash
        }

        return nil
    }

    // MARK: - Ellipsis Conversion

    /// Convert three periods to ellipsis
    static func handleEllipsis(contextBefore: String?) -> (text: String, deleteCount: Int)? {
        guard let before = contextBefore else { return nil }

        // Check for two periods already typed
        if before.hasSuffix("..") {
            return ("…", 2)  // Delete two periods, insert ellipsis character
        }

        return nil
    }
}
