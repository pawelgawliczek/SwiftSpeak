//
//  PersonalDictionary.swift
//  SwiftSpeakKeyboard
//
//  Builds a personal dictionary from user's transcription history
//  Provides domain-specific and personal vocabulary for predictions
//

import Foundation

/// Personal dictionary built from user's transcription history
actor PersonalDictionary {
    static let shared = PersonalDictionary()

    private let appGroupID = "group.pawelgawliczek.swiftspeak"
    private let cacheKey = "personalDictionaryCache"

    // Word -> (frequency, last seen date)
    private var words: [String: WordEntry] = [:]

    // Domain-specific words detected from patterns
    private var domainWords: Set<String> = []

    // Names and proper nouns
    private var properNouns: Set<String> = []

    private var isInitialized = false
    private var lastBuildDate: Date?

    private init() {}

    // MARK: - Initialization

    func initialize() async {
        guard !isInitialized else { return }

        // Load cached dictionary
        loadCache()

        // Rebuild if cache is stale (older than 1 hour)
        if lastBuildDate == nil || Date().timeIntervalSince(lastBuildDate!) > 3600 {
            await buildFromHistory()
        }

        isInitialized = true
        keyboardLog("PersonalDictionary initialized with \(words.count) words", category: "Prediction")
    }

    /// Force rebuild from transcription history
    func rebuild() async {
        await buildFromHistory()
    }

    // MARK: - Word Lookup

    /// Check if word exists in personal dictionary
    func contains(_ word: String) -> Bool {
        return words[word.lowercased()] != nil
    }

    /// Get frequency of a word
    func frequency(of word: String) -> Int {
        return words[word.lowercased()]?.frequency ?? 0
    }

    /// Get all words with given prefix
    func wordsWithPrefix(_ prefix: String, maxResults: Int = 10) -> [String] {
        let lowercased = prefix.lowercased()

        return words
            .filter { $0.key.hasPrefix(lowercased) }
            .sorted { $0.value.frequency > $1.value.frequency }
            .prefix(maxResults)
            .map { $0.key }
    }

    /// Get top frequent words
    func topWords(maxResults: Int = 50) -> [String] {
        return words
            .sorted { $0.value.frequency > $1.value.frequency }
            .prefix(maxResults)
            .map { $0.key }
    }

    /// Get all words as array for SymSpell integration
    func allWords() -> [(String, Int)] {
        return words.map { ($0.key, $0.value.frequency) }
    }

    /// Check if word is a proper noun (capitalized in history)
    func isProperNoun(_ word: String) -> Bool {
        return properNouns.contains(word.lowercased())
    }

    /// Get domain-specific words (technical terms, etc.)
    func getDomainWords() -> [String] {
        return Array(domainWords)
    }

    // MARK: - Building Dictionary

    private func buildFromHistory() async {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let historyData = defaults.data(forKey: Constants.Keys.transcriptionHistory) else {
            return
        }

        struct HistoryRecord: Codable {
            let text: String
            let timestamp: Date
        }

        guard let history = try? JSONDecoder().decode([HistoryRecord].self, from: historyData) else {
            return
        }

        var newWords: [String: WordEntry] = [:]
        var newProperNouns: Set<String> = []
        var newDomainWords: Set<String> = []

        // Common English words to exclude from personal dictionary
        let commonWords: Set<String> = [
            "the", "be", "to", "of", "and", "a", "in", "that", "have", "i",
            "it", "for", "not", "on", "with", "he", "as", "you", "do", "at",
            "this", "but", "his", "by", "from", "they", "we", "say", "her", "she",
            "or", "an", "will", "my", "one", "all", "would", "there", "their", "what",
            "is", "are", "was", "were", "been", "being", "has", "had", "does", "did",
            "so", "up", "out", "if", "about", "who", "get", "which", "go", "me",
            "when", "make", "can", "like", "time", "no", "just", "him", "know", "take"
        ]

        for record in history.prefix(200) {  // Last 200 transcriptions
            let words = extractWords(from: record.text)

            for word in words {
                let lowercased = word.lowercased()

                // Skip very short words and common words
                guard lowercased.count >= 3 && !commonWords.contains(lowercased) else { continue }

                // Track word
                var entry = newWords[lowercased] ?? WordEntry()
                entry.frequency += 1
                entry.lastSeen = max(entry.lastSeen, record.timestamp)
                newWords[lowercased] = entry

                // Detect proper nouns (consistently capitalized, not at start of sentence)
                if word.first?.isUppercase == true && word != word.uppercased() {
                    // Check if previous character was not sentence-ending
                    newProperNouns.insert(lowercased)
                }

                // Detect domain words (uncommon patterns like camelCase, technical terms)
                if isDomainWord(word) {
                    newDomainWords.insert(lowercased)
                }
            }
        }

        // Also add custom vocabulary
        if let vocabData = defaults.data(forKey: Constants.Keys.vocabulary) {
            struct VocabEntry: Codable { let word: String }
            if let vocab = try? JSONDecoder().decode([VocabEntry].self, from: vocabData) {
                for entry in vocab {
                    let lowercased = entry.word.lowercased()
                    var wordEntry = newWords[lowercased] ?? WordEntry()
                    wordEntry.frequency += 10  // Boost custom vocabulary
                    newWords[lowercased] = wordEntry
                }
            }
        }

        words = newWords
        properNouns = newProperNouns
        domainWords = newDomainWords
        lastBuildDate = Date()

        saveCache()
    }

    private func extractWords(from text: String) -> [String] {
        // Split on whitespace and punctuation, preserving original case
        let pattern = "[a-zA-Z]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        return matches.compactMap { match -> String? in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }

    private func isDomainWord(_ word: String) -> Bool {
        // Check for camelCase
        let hasMixedCase = word.contains(where: { $0.isUppercase }) &&
                          word.contains(where: { $0.isLowercase }) &&
                          !word.allSatisfy { $0.isUppercase || !$0.isLetter }

        // Check for technical patterns (contains numbers mixed with letters)
        let hasNumbers = word.contains(where: { $0.isNumber })

        // Check for uncommon character sequences (likely technical terms)
        let technicalPatterns = ["api", "http", "json", "xml", "sql", "html", "css", "js", "ios", "sdk"]
        let containsTechnical = technicalPatterns.contains { word.lowercased().contains($0) }

        return hasMixedCase || hasNumbers || containsTechnical
    }

    // MARK: - Persistence

    private func saveCache() {
        let cache = DictionaryCache(
            words: words,
            properNouns: Array(properNouns),
            domainWords: Array(domainWords),
            buildDate: lastBuildDate ?? Date()
        )

        guard let data = try? JSONEncoder().encode(cache),
              let defaults = UserDefaults(suiteName: appGroupID) else { return }

        defaults.set(data, forKey: cacheKey)
    }

    private func loadCache() {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: cacheKey),
              let cache = try? JSONDecoder().decode(DictionaryCache.self, from: data) else { return }

        words = cache.words
        properNouns = Set(cache.properNouns)
        domainWords = Set(cache.domainWords)
        lastBuildDate = cache.buildDate
    }
}

// MARK: - Data Models

private struct WordEntry: Codable {
    var frequency: Int = 0
    var lastSeen: Date = Date()
}

private struct DictionaryCache: Codable {
    var words: [String: WordEntry]
    var properNouns: [String]
    var domainWords: [String]
    var buildDate: Date
}
