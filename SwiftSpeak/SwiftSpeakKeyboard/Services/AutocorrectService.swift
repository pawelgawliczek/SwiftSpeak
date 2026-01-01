//
//  AutocorrectService.swift
//  SwiftSpeakKeyboard
//
//  Autocorrect service using SymSpellSwift for spelling correction
//  MIT licensed, free for commercial use
//

import Foundation
// TODO: Add SymSpellSwift package: https://github.com/gdetari/SymSpellSwift.git
// import SymSpellSwift

/// Autocorrect service providing spelling correction
/// Uses SymSpell algorithm for fast, accurate corrections
actor AutocorrectService {
    // Singleton for shared access
    static let shared = AutocorrectService()

    // SymSpell instances per language
    // private var symSpellInstances: [String: SymSpell] = [:]

    private var isInitialized = false
    private var currentLanguage: String = "en"

    // Placeholder until SymSpellSwift is added
    private var mockDictionary: Set<String> = []

    private init() {}

    // MARK: - Initialization

    /// Initialize the autocorrect service with the specified language
    func initialize(language: String = "en") async {
        guard !isInitialized else { return }

        currentLanguage = language

        // TODO: Replace with actual SymSpell initialization
        // let symSpell = SymSpell(maxDictionaryEditDistance: 2, prefixLength: 7)
        // if let path = Bundle.main.url(forResource: "frequency_\(language)", withExtension: "txt") {
        //     try? symSpell.loadDictionary(from: path, termIndex: 0, countIndex: 1)
        // }
        // symSpellInstances[language] = symSpell

        // For now, load a basic word list for testing
        loadBasicDictionary()

        isInitialized = true
        keyboardLog("AutocorrectService initialized for language: \(language)", category: "Autocorrect")
    }

    // MARK: - Spelling Correction

    /// Check if a word is spelled correctly
    func isCorrectlySpelled(_ word: String) -> Bool {
        let lowercased = word.lowercased()

        // TODO: Replace with SymSpell lookup
        // guard let symSpell = symSpellInstances[currentLanguage] else { return true }
        // let results = symSpell.lookup(lowercased, verbosity: .closest)
        // return results.first?.term == lowercased

        return mockDictionary.contains(lowercased)
    }

    /// Get spelling suggestions for a word
    func getSuggestions(for word: String, maxResults: Int = 3) -> [String] {
        let lowercased = word.lowercased()

        // TODO: Replace with SymSpell lookup
        // guard let symSpell = symSpellInstances[currentLanguage] else { return [] }
        // let results = symSpell.lookup(lowercased, verbosity: .all, maxEditDistance: 2)
        // return results.prefix(maxResults).map { $0.term }

        // Simple edit distance-based suggestions for testing
        return getSimpleSuggestions(for: lowercased, maxResults: maxResults)
    }

    /// Get the best correction for a word (autocorrect)
    /// Only corrects when we're highly confident it's a typo
    func getCorrection(for word: String) -> String? {
        let lowercased = word.lowercased()

        // If correctly spelled, no correction needed
        if isCorrectlySpelled(lowercased) {
            return nil
        }

        // Skip very short words (2 chars) - too ambiguous
        guard lowercased.count >= 3 else {
            return nil
        }

        // Get suggestions with strict criteria
        let suggestions = getStrictSuggestions(for: lowercased)
        return suggestions.first
    }

    /// Get suggestions only when highly confident it's a typo
    private func getStrictSuggestions(for word: String) -> [String] {
        var suggestions: [(word: String, distance: Int, score: Int)] = []

        let inputFirst = word.first
        let inputLength = word.count

        for dictWord in mockDictionary {
            let distance = levenshteinDistance(word, dictWord)

            // STRICT criteria for autocorrect:
            // 1. Distance must be exactly 1 (single typo)
            // 2. Same first letter (typos rarely change first letter)
            // 3. Same length or off by 1 (transposition/substitution, not missing words)
            let sameFirstLetter = dictWord.first == inputFirst
            let similarLength = abs(dictWord.count - inputLength) <= 1

            if distance == 1 && sameFirstLetter && similarLength {
                var score = 0
                if dictWord.count == inputLength { score -= 2 }  // Prefer same length
                suggestions.append((dictWord, distance, score))
            }
        }

        // Sort by score
        suggestions.sort { $0.score < $1.score }

        return suggestions.map { $0.word }
    }

    // MARK: - Language Support

    /// Switch to a different language
    func switchLanguage(to language: String) async {
        guard language != currentLanguage else { return }
        currentLanguage = language

        // TODO: Load dictionary for new language if not already loaded
        // if symSpellInstances[language] == nil {
        //     await loadDictionary(for: language)
        // }

        keyboardLog("AutocorrectService switched to language: \(language)", category: "Autocorrect")
    }

    /// Get memory usage estimate
    var estimatedMemoryUsageMB: Double {
        // TODO: Calculate actual memory usage from SymSpell dictionaries
        // Each entry is roughly: term length + 8 bytes (frequency) + overhead
        return Double(mockDictionary.count * 20) / 1_000_000
    }

    // MARK: - Private Helpers

    private func loadBasicDictionary() {
        // Basic English words for testing
        // In production, load from frequency_dictionary file
        mockDictionary = Set([
            // Top 100 most common English words
            "the", "be", "to", "of", "and", "a", "in", "that", "have", "i",
            "it", "for", "not", "on", "with", "he", "as", "you", "do", "at",
            "this", "but", "his", "by", "from", "they", "we", "say", "her", "she",
            "or", "an", "will", "my", "one", "all", "would", "there", "their", "what",
            "so", "up", "out", "if", "about", "who", "get", "which", "go", "me",
            "when", "make", "can", "like", "time", "no", "just", "him", "know", "take",
            "people", "into", "year", "your", "good", "some", "could", "them", "see", "other",
            "than", "then", "now", "look", "only", "come", "its", "over", "think", "also",
            "back", "after", "use", "two", "how", "our", "work", "first", "well", "way",
            "even", "new", "want", "because", "any", "these", "give", "day", "most", "us",
            // Missing essential words
            "are", "is", "was", "were", "been", "being", "am", "has", "had", "does", "did",
            "here", "very", "more", "much", "such", "own", "same", "too", "where", "why",
            "let", "put", "say", "said", "tell", "told", "ask", "asked", "need", "feel",
            "try", "leave", "call", "keep", "last", "long", "great", "little", "own",
            "old", "right", "big", "high", "small", "large", "next", "early", "young",
            "few", "public", "bad", "same", "able", "man", "men", "woman", "women",
            "child", "children", "world", "life", "hand", "part", "place", "case", "week",
            "company", "system", "program", "thing", "point", "home", "water", "room",
            "mother", "area", "money", "story", "fact", "month", "lot", "study", "book",
            "eye", "job", "word", "business", "issue", "side", "kind", "head", "house",
            "service", "friend", "father", "power", "hour", "game", "line", "end", "member",
            "law", "car", "city", "name", "president", "team", "minute", "idea", "kid",
            "body", "information", "nothing", "ago", "lead", "social", "whether", "back",
            "watch", "together", "follow", "around", "parent", "stop", "face", "anything",
            "create", "real", "might", "must", "shall", "should", "may", "many", "each",
            "between", "through", "during", "before", "those", "both", "while", "another",
            "being", "under", "never", "always", "sometimes", "often", "still", "again",
            // Common misspelling targets
            "hello", "thank", "thanks", "please", "sorry", "okay",
            "meeting", "tomorrow", "today", "yesterday", "email", "phone", "message",
            "question", "answer", "problem", "solution", "important", "urgent",
            "available", "schedule", "confirm", "cancel", "update", "change",
            "understand", "remember", "forget", "believe", "receive", "achieve"
        ])
    }

    private func getSimpleSuggestions(for word: String, maxResults: Int) -> [String] {
        // Simple Levenshtein distance-based suggestions
        // This is a placeholder - SymSpell will be much faster
        var suggestions: [(word: String, distance: Int, score: Int)] = []

        let inputFirst = word.first
        let inputLength = word.count

        for dictWord in mockDictionary {
            let distance = levenshteinDistance(word, dictWord)
            if distance <= 2 && distance > 0 {
                // Calculate priority score (lower is better)
                var score = distance * 10  // Base score from distance

                // Bonus for same first letter (very important for typos)
                if dictWord.first == inputFirst {
                    score -= 5
                }

                // Bonus for same length
                if dictWord.count == inputLength {
                    score -= 2
                }

                // Small penalty for length difference
                score += abs(dictWord.count - inputLength)

                suggestions.append((dictWord, distance, score))
            }
        }

        // Sort by score (lower is better), then by distance, then alphabetically
        suggestions.sort {
            if $0.score != $1.score { return $0.score < $1.score }
            if $0.distance != $1.distance { return $0.distance < $1.distance }
            return $0.word < $1.word
        }

        return Array(suggestions.prefix(maxResults).map { $0.word })
    }

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count

        if m == 0 { return n }
        if n == 0 { return m }

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }

        return matrix[m][n]
    }
}

// MARK: - Autocorrect Integration for Keyboard

extension AutocorrectService {
    /// Process typed text and return correction if needed
    /// Call this when user types a space or punctuation
    func processWord(_ word: String) -> (original: String, correction: String?)? {
        guard !word.isEmpty else { return nil }

        // Preserve capitalization
        let isCapitalized = word.first?.isUppercase ?? false
        let isAllCaps = word == word.uppercased() && word.count > 1

        if let correction = getCorrection(for: word) {
            var corrected = correction
            if isAllCaps {
                corrected = correction.uppercased()
            } else if isCapitalized {
                corrected = correction.capitalized
            }
            return (word, corrected)
        }

        return nil
    }
}
