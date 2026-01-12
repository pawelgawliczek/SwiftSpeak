//
//  TranscriptionPostProcessor.swift
//  SwiftSpeakCore
//
//  Post-processing utilities for transcription output
//  Handles repetition detection and cleanup for Whisper hallucinations
//

import Foundation

/// Post-processor for transcription output
/// Detects and removes common Whisper hallucination patterns like repetition
public struct TranscriptionPostProcessor {

    // MARK: - Configuration

    /// Minimum length of repeated segment to detect (characters)
    private static let minRepetitionLength = 20

    /// Minimum similarity ratio for fuzzy matching
    private static let similarityThreshold = 0.85

    // MARK: - Main Processing

    /// Clean transcription by removing detected repetitions
    /// - Parameter text: Raw transcription text
    /// - Returns: Cleaned text with repetitions removed
    public static func removeRepetitions(from text: String) -> String {
        var result = text

        // Step 1: Remove exact large chunk duplications (most common hallucination)
        result = removeLargeChunkRepetitions(from: result)

        // Step 2: Remove repeated sentences
        result = removeRepeatedSentences(from: result)

        // Step 3: Remove trailing partial repetitions
        result = removeTrailingPartialRepetition(from: result)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Large Chunk Repetition Detection

    /// Detects and removes cases where a large portion of text is repeated
    /// E.g., "Hello world. How are you?Hello world. How are you?"
    private static func removeLargeChunkRepetitions(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minRepetitionLength * 2 else { return text }

        // Try to find a repeated chunk by checking various split points
        for splitRatio in stride(from: 0.4, through: 0.6, by: 0.05) {
            let splitPoint = Int(Double(trimmed.count) * splitRatio)
            let firstHalf = String(trimmed.prefix(splitPoint))
            let secondHalf = String(trimmed.suffix(trimmed.count - splitPoint))

            // Check if second half starts with a repetition of the first half
            if secondHalf.hasPrefix(firstHalf) || similarity(firstHalf, String(secondHalf.prefix(firstHalf.count))) >= similarityThreshold {
                // Found repetition - return just the first part
                // But check if there's meaningful content after the repetition
                let afterRepetition = String(secondHalf.dropFirst(firstHalf.count))
                if afterRepetition.count < minRepetitionLength {
                    return firstHalf
                }
            }
        }

        // Also check for 3x repetitions (text repeated 3 times)
        let thirdLength = trimmed.count / 3
        if thirdLength >= minRepetitionLength {
            let first = String(trimmed.prefix(thirdLength))
            let second = String(trimmed.dropFirst(thirdLength).prefix(thirdLength))
            let third = String(trimmed.suffix(thirdLength))

            if similarity(first, second) >= similarityThreshold && similarity(first, third) >= similarityThreshold {
                return first
            }
        }

        return text
    }

    // MARK: - Sentence-Level Repetition

    /// Removes repeated sentences while preserving unique content
    private static func removeRepeatedSentences(from text: String) -> String {
        // Split into sentences
        let sentences = splitIntoSentences(text)
        guard sentences.count > 1 else { return text }

        var seen = Set<String>()
        var result: [String] = []

        for sentence in sentences {
            let normalized = normalizeForComparison(sentence)

            // Skip very short sentences (might be legitimate repetition like "Yes. Yes.")
            if normalized.count < 10 {
                result.append(sentence)
                continue
            }

            // Check if we've seen a very similar sentence
            var isDuplicate = false
            for seenSentence in seen {
                if similarity(normalized, seenSentence) >= similarityThreshold {
                    isDuplicate = true
                    break
                }
            }

            if !isDuplicate {
                seen.insert(normalized)
                result.append(sentence)
            }
        }

        return result.joined(separator: " ")
    }

    /// Split text into sentences (handling emojis and various punctuation)
    private static func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        var i = text.startIndex

        while i < text.endIndex {
            let char = text[i]
            current.append(char)

            // Check for sentence boundaries
            if char == "." || char == "!" || char == "?" {
                let nextIndex = text.index(after: i)

                // Look ahead - if followed by space or emoji or end, it's a sentence boundary
                if nextIndex >= text.endIndex {
                    // End of text
                    let trimmed = current.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        sentences.append(trimmed)
                    }
                    current = ""
                } else {
                    let nextChar = text[nextIndex]
                    if nextChar.isWhitespace || nextChar.isEmoji {
                        let trimmed = current.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            sentences.append(trimmed)
                        }
                        current = ""
                    }
                }
            }

            i = text.index(after: i)
        }

        // Add any remaining text
        let trimmed = current.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            sentences.append(trimmed)
        }

        return sentences
    }

    // MARK: - Trailing Repetition

    /// Removes cases where the text ends with a partial repetition of the beginning
    /// E.g., "Good morning, how are you? Hope you're well.Good morning, how"
    private static func removeTrailingPartialRepetition(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minRepetitionLength * 2 else { return text }

        // Check various potential repetition start points in the second half
        let searchStart = trimmed.count / 2

        for offset in 0..<(trimmed.count - searchStart) {
            let potentialStart = trimmed.index(trimmed.startIndex, offsetBy: searchStart + offset)
            let suffix = String(trimmed[potentialStart...])

            // Check if this suffix matches the beginning of the text
            let prefixToCompare = String(trimmed.prefix(suffix.count))

            if suffix.count >= minRepetitionLength && similarity(suffix, prefixToCompare) >= similarityThreshold {
                // Found a trailing repetition - remove it
                return String(trimmed.prefix(searchStart + offset)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return text
    }

    // MARK: - Utility Functions

    /// Normalize text for comparison (lowercase, remove extra whitespace)
    private static func normalizeForComparison(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Calculate similarity ratio between two strings (0.0 - 1.0)
    /// Uses Levenshtein distance
    private static func similarity(_ a: String, _ b: String) -> Double {
        guard !a.isEmpty && !b.isEmpty else { return 0 }

        let aChars = Array(a)
        let bChars = Array(b)
        let aCount = aChars.count
        let bCount = bChars.count

        // Quick check for exact match
        if a == b { return 1.0 }

        // Use simplified comparison for very long strings (performance)
        if aCount > 500 || bCount > 500 {
            return simplifiedSimilarity(a, b)
        }

        // Levenshtein distance
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: bCount + 1), count: aCount + 1)

        for i in 0...aCount { matrix[i][0] = i }
        for j in 0...bCount { matrix[0][j] = j }

        for i in 1...aCount {
            for j in 1...bCount {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }

        let distance = matrix[aCount][bCount]
        let maxLen = max(aCount, bCount)
        return 1.0 - (Double(distance) / Double(maxLen))
    }

    /// Simplified similarity for long strings (compare word overlap)
    private static func simplifiedSimilarity(_ a: String, _ b: String) -> Double {
        let aWords = Set(a.lowercased().split(separator: " ").map(String.init))
        let bWords = Set(b.lowercased().split(separator: " ").map(String.init))

        guard !aWords.isEmpty && !bWords.isEmpty else { return 0 }

        let intersection = aWords.intersection(bWords).count
        let union = aWords.union(bWords).count

        return Double(intersection) / Double(union)
    }
}

// MARK: - Character Extension

private extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.value > 0x238C || unicodeScalars.count > 1)
    }
}
