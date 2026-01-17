//
//  SymSpell.swift
//  SwiftSpeakKeyboard
//
//  Lightweight SymSpell implementation for keyboard extensions
//  Uses symmetric delete approach for O(1) spell checking
//

import Foundation

// MARK: - Suggestion

/// A spelling suggestion with edit distance and frequency
struct SymSpellSuggestion: Comparable {
    let word: String
    let distance: Int
    let frequency: Int

    static func < (lhs: SymSpellSuggestion, rhs: SymSpellSuggestion) -> Bool {
        // Sort by distance first, then by frequency (higher is better)
        if lhs.distance != rhs.distance {
            return lhs.distance < rhs.distance
        }
        return lhs.frequency > rhs.frequency
    }
}

// MARK: - SymSpell

/// Lightweight SymSpell implementation optimized for keyboard extensions
/// Uses symmetric delete approach for fast spell checking
final class SymSpell {

    // MARK: - Configuration

    /// Maximum edit distance for corrections (1 or 2 recommended)
    let maxEditDistance: Int

    /// Prefix length for optimization (7 is standard)
    let prefixLength: Int

    // MARK: - Data Structures

    /// Dictionary of words with their frequencies
    private var words: [String: Int] = [:]

    /// Deletion dictionary: maps deletions to original words
    private var deletions: [String: [String]] = [:]

    /// Whether the dictionary is loaded
    private(set) var isLoaded: Bool = false

    /// Number of words in dictionary
    var wordCount: Int { words.count }

    // MARK: - Initialization

    init(maxEditDistance: Int = 2, prefixLength: Int = 7) {
        self.maxEditDistance = maxEditDistance
        self.prefixLength = prefixLength
    }

    // MARK: - Loading

    /// Load dictionary from frequency data (format: "word frequency\n")
    func load(from data: Data) {
        guard let content = String(data: data, encoding: .utf8) else {
            keyboardLog("SymSpell: Failed to decode dictionary data", category: "SymSpell")
            return
        }

        load(from: content)
    }

    /// Load dictionary from frequency string
    func load(from content: String) {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Clear existing data
        words.removeAll()
        deletions.removeAll()

        // Parse lines
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let parts = line.split(separator: " ", maxSplits: 1)
            guard parts.count >= 1 else { continue }

            let word = String(parts[0]).lowercased()
            let frequency = parts.count > 1 ? Int(parts[1]) ?? 1 : 1

            // Skip empty or very long words
            guard word.count >= 2 && word.count <= 50 else { continue }

            // Add to dictionary
            words[word] = frequency

            // Generate deletions for this word
            let wordDeletions = generateDeletions(word, maxDistance: maxEditDistance)
            for deletion in wordDeletions {
                if deletions[deletion] == nil {
                    deletions[deletion] = [word]
                } else {
                    deletions[deletion]?.append(word)
                }
            }
        }

        isLoaded = true

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        keyboardLog("SymSpell: Loaded \(words.count) words, \(deletions.count) deletions in \(String(format: "%.2f", elapsed))s", category: "SymSpell")
    }

    /// Unload dictionary to free memory
    func unload() {
        words.removeAll()
        deletions.removeAll()
        isLoaded = false
        keyboardLog("SymSpell: Dictionary unloaded", category: "SymSpell")
    }

    // MARK: - Lookup

    /// Look up suggestions for a word
    func lookup(_ input: String, maxResults: Int = 3) -> [SymSpellSuggestion] {
        guard isLoaded else { return [] }

        let word = input.lowercased()

        // If word is in dictionary, it's correctly spelled
        if words[word] != nil {
            return []
        }

        var suggestions: [SymSpellSuggestion] = []
        var seen: Set<String> = []

        // Check the input word's deletions against our deletion dictionary
        let inputDeletions = generateDeletions(word, maxDistance: maxEditDistance)

        for deletion in inputDeletions {
            guard let candidates = deletions[deletion] else { continue }

            for candidate in candidates {
                guard !seen.contains(candidate) else { continue }
                seen.insert(candidate)

                let distance = editDistance(word, candidate)
                guard distance <= maxEditDistance else { continue }

                let frequency = words[candidate] ?? 0
                suggestions.append(SymSpellSuggestion(word: candidate, distance: distance, frequency: frequency))
            }
        }

        // Also check direct deletions of input (for insertions)
        for deletion in inputDeletions {
            if let frequency = words[deletion], !seen.contains(deletion) {
                seen.insert(deletion)
                let distance = editDistance(word, deletion)
                if distance <= maxEditDistance {
                    suggestions.append(SymSpellSuggestion(word: deletion, distance: distance, frequency: frequency))
                }
            }
        }

        // Sort and limit results
        suggestions.sort()
        return Array(suggestions.prefix(maxResults))
    }

    /// Check if a word is in the dictionary
    func isKnownWord(_ word: String) -> Bool {
        return words[word.lowercased()] != nil
    }

    // MARK: - Deletions Generation

    /// Generate all deletions within max edit distance
    private func generateDeletions(_ word: String, maxDistance: Int) -> Set<String> {
        var result: Set<String> = [word]

        // Use prefix for optimization
        let workingWord = word.count > prefixLength ? String(word.prefix(prefixLength)) : word

        var queue: [String] = [workingWord]
        var processed: Set<String> = [workingWord]

        for _ in 0..<maxDistance {
            var nextQueue: [String] = []

            for current in queue {
                guard current.count > 1 else { continue }

                for i in current.indices {
                    var deletion = current
                    deletion.remove(at: i)

                    if !processed.contains(deletion) {
                        processed.insert(deletion)
                        result.insert(deletion)
                        nextQueue.append(deletion)
                    }
                }
            }

            queue = nextQueue
        }

        return result
    }

    // MARK: - Edit Distance

    /// Calculate Damerau-Levenshtein edit distance
    private func editDistance(_ s1: String, _ s2: String) -> Int {
        let m = s1.count
        let n = s2.count

        // Quick checks
        if m == 0 { return n }
        if n == 0 { return m }
        if s1 == s2 { return 0 }

        // Early termination if difference is too large
        if abs(m - n) > maxEditDistance { return maxEditDistance + 1 }

        let s1Array = Array(s1)
        let s2Array = Array(s2)

        // Use single row for memory efficiency
        var prev = Array(0...n)
        var curr = Array(repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i

            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,      // deletion
                    curr[j - 1] + 1,  // insertion
                    prev[j - 1] + cost // substitution
                )

                // Transposition (Damerau)
                if i > 1 && j > 1 &&
                   s1Array[i - 1] == s2Array[j - 2] &&
                   s1Array[i - 2] == s2Array[j - 1] {
                    curr[j] = min(curr[j], prev[j - 1] + cost)
                }
            }

            swap(&prev, &curr)
        }

        return prev[n]
    }
}
