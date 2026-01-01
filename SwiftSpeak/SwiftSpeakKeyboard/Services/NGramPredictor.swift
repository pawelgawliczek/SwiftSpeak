//
//  NGramPredictor.swift
//  SwiftSpeakKeyboard
//
//  N-gram based word prediction using bigram and trigram models
//  Predicts next word based on previous 1-2 words
//

import Foundation

/// N-gram based word prediction service
/// Uses statistical patterns from common English text to predict next words
actor NGramPredictor {
    static let shared = NGramPredictor()

    // Bigram: previous word -> [next word: count]
    private var bigrams: [String: [String: Int]] = [:]

    // Trigram: "word1_word2" -> [next word: count]
    private var trigrams: [String: [String: Int]] = [:]

    // Unigram frequencies for fallback
    private var unigrams: [String: Int] = [:]

    private var isInitialized = false

    private init() {}

    // MARK: - Initialization

    func initialize() async {
        guard !isInitialized else { return }

        loadBuiltInNGrams()
        isInitialized = true
        keyboardLog("NGramPredictor initialized: \(bigrams.count) bigrams, \(trigrams.count) trigrams", category: "Prediction")
    }

    /// Learn from user's text (call with transcription history)
    func learnFromText(_ text: String) {
        let words = tokenize(text)
        guard words.count >= 2 else { return }

        // Build unigrams
        for word in words {
            unigrams[word, default: 0] += 1
        }

        // Build bigrams
        for i in 0..<(words.count - 1) {
            let current = words[i]
            let next = words[i + 1]
            bigrams[current, default: [:]][next, default: 0] += 1
        }

        // Build trigrams
        if words.count >= 3 {
            for i in 0..<(words.count - 2) {
                let key = "\(words[i])_\(words[i + 1])"
                let next = words[i + 2]
                trigrams[key, default: [:]][next, default: 0] += 1
            }
        }
    }

    // MARK: - Prediction

    /// Predict next words based on previous words
    /// - Parameters:
    ///   - previousWords: Array of previous words (last 1-2 words)
    ///   - maxResults: Maximum number of predictions
    /// - Returns: Array of predicted words sorted by probability
    func predict(previousWords: [String], maxResults: Int = 5) -> [String] {
        let words = previousWords.map { $0.lowercased() }

        var predictions: [String: Double] = [:]

        // Try trigram first (most specific)
        if words.count >= 2 {
            let key = "\(words[words.count - 2])_\(words[words.count - 1])"
            if let nextWords = trigrams[key] {
                let total = Double(nextWords.values.reduce(0, +))
                for (word, count) in nextWords {
                    predictions[word, default: 0] += Double(count) / total * 3.0  // Higher weight for trigrams
                }
            }
        }

        // Try bigram
        if let lastWord = words.last, let nextWords = bigrams[lastWord] {
            let total = Double(nextWords.values.reduce(0, +))
            for (word, count) in nextWords {
                predictions[word, default: 0] += Double(count) / total * 2.0  // Medium weight for bigrams
            }
        }

        // Fallback to unigrams if no n-gram matches
        if predictions.isEmpty {
            let total = Double(unigrams.values.reduce(0, +))
            for (word, count) in unigrams.sorted(by: { $0.value > $1.value }).prefix(20) {
                predictions[word] = Double(count) / total
            }
        }

        // Sort by score and return top results
        let sorted = predictions.sorted { $0.value > $1.value }
        return sorted.prefix(maxResults).map { $0.key.capitalized }
    }

    /// Predict word completion based on prefix
    func predictCompletion(prefix: String, previousWords: [String], maxResults: Int = 5) -> [String] {
        let lowercasedPrefix = prefix.lowercased()
        guard !lowercasedPrefix.isEmpty else {
            return predict(previousWords: previousWords, maxResults: maxResults)
        }

        var predictions: [String: Double] = [:]

        // Get all words starting with prefix
        let matchingUnigrams = unigrams.filter { $0.key.hasPrefix(lowercasedPrefix) }

        // Use n-gram context to boost relevant completions
        let contextPredictions = Set(predict(previousWords: previousWords, maxResults: 20).map { $0.lowercased() })

        for (word, count) in matchingUnigrams {
            var score = Double(count)

            // Boost if word is in context predictions
            if contextPredictions.contains(word) {
                score *= 3.0
            }

            // Slight boost for shorter words (easier to complete)
            score /= Double(word.count - lowercasedPrefix.count + 1)

            predictions[word] = score
        }

        let sorted = predictions.sorted { $0.value > $1.value }
        return sorted.prefix(maxResults).map { $0.key.capitalized }
    }

    // MARK: - Helpers

    private func tokenize(_ text: String) -> [String] {
        let cleaned = text.lowercased()
            .replacingOccurrences(of: "[^a-z\\s']", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return cleaned.split(separator: " ").map(String.init).filter { $0.count >= 2 }
    }

    // MARK: - Built-in N-Grams

    private func loadBuiltInNGrams() {
        // Common English bigrams (word pairs)
        let commonBigrams: [(String, String, Int)] = [
            // Pronouns + verbs
            ("i", "am", 500), ("i", "have", 400), ("i", "will", 350), ("i", "would", 300),
            ("i", "think", 280), ("i", "want", 260), ("i", "know", 250), ("i", "need", 240),
            ("i", "can", 230), ("i", "don't", 220), ("i", "was", 200), ("i", "do", 180),

            ("you", "are", 450), ("you", "have", 350), ("you", "can", 300), ("you", "will", 280),
            ("you", "want", 250), ("you", "need", 240), ("you", "know", 230), ("you", "should", 200),

            ("we", "are", 350), ("we", "have", 300), ("we", "will", 280), ("we", "can", 260),
            ("we", "need", 220), ("we", "should", 200),

            ("they", "are", 320), ("they", "have", 280), ("they", "will", 250), ("they", "can", 230),

            ("he", "is", 350), ("he", "was", 300), ("he", "has", 250), ("he", "will", 200),
            ("she", "is", 340), ("she", "was", 290), ("she", "has", 240), ("she", "will", 190),
            ("it", "is", 500), ("it", "was", 400), ("it", "will", 300), ("it", "would", 250),

            // Common phrases
            ("thank", "you", 600), ("of", "the", 550), ("in", "the", 500), ("to", "the", 450),
            ("on", "the", 400), ("for", "the", 380), ("at", "the", 350), ("with", "the", 320),
            ("from", "the", 300), ("by", "the", 280), ("about", "the", 250),

            ("to", "be", 400), ("to", "do", 300), ("to", "have", 280), ("to", "make", 260),
            ("to", "get", 250), ("to", "go", 240), ("to", "see", 220), ("to", "know", 200),

            ("will", "be", 350), ("would", "be", 320), ("should", "be", 280), ("could", "be", 250),
            ("can", "be", 230), ("may", "be", 200), ("might", "be", 180),

            ("have", "been", 300), ("has", "been", 280), ("had", "been", 250),
            ("have", "to", 280), ("has", "to", 250), ("had", "to", 220),

            // Adjective + noun patterns
            ("good", "morning", 200), ("good", "afternoon", 150), ("good", "evening", 140),
            ("good", "night", 130), ("good", "luck", 120), ("good", "idea", 110),

            // Time expressions
            ("next", "week", 180), ("next", "month", 150), ("next", "year", 140),
            ("last", "week", 170), ("last", "month", 140), ("last", "year", 130),
            ("this", "week", 200), ("this", "month", 180), ("this", "year", 170),
            ("this", "morning", 160), ("this", "afternoon", 140), ("this", "evening", 130),

            // Common verb phrases
            ("going", "to", 400), ("want", "to", 350), ("need", "to", 320),
            ("have", "to", 300), ("trying", "to", 250), ("able", "to", 230),
            ("used", "to", 200), ("supposed", "to", 180),

            ("looking", "for", 220), ("waiting", "for", 200), ("asking", "for", 180),
            ("looking", "forward", 160), ("thinking", "about", 180), ("talking", "about", 170),

            // Question patterns
            ("how", "are", 250), ("how", "is", 220), ("how", "was", 200), ("how", "do", 180),
            ("what", "is", 280), ("what", "are", 250), ("what", "do", 230), ("what", "does", 200),
            ("where", "is", 200), ("where", "are", 180), ("where", "do", 160),
            ("when", "is", 180), ("when", "are", 160), ("when", "do", 140),
            ("why", "is", 170), ("why", "are", 150), ("why", "do", 140),

            // Business/email phrases
            ("please", "let", 180), ("let", "me", 220), ("let", "us", 180),
            ("could", "you", 200), ("would", "you", 190), ("can", "you", 250),
            ("if", "you", 220), ("as", "soon", 150),
        ]

        for (word1, word2, count) in commonBigrams {
            bigrams[word1, default: [:]][word2, default: 0] += count
            unigrams[word1, default: 0] += count
            unigrams[word2, default: 0] += count
        }

        // Common English trigrams
        let commonTrigrams: [(String, String, String, Int)] = [
            // Very common phrases
            ("i", "want", "to", 300), ("i", "need", "to", 280), ("i", "have", "to", 260),
            ("i", "would", "like", 240), ("i", "think", "that", 220), ("i", "don't", "know", 200),
            ("i", "don't", "think", 180), ("i", "am", "going", 170),

            ("thank", "you", "for", 350), ("thank", "you", "so", 200),
            ("looking", "forward", "to", 220),

            ("as", "soon", "as", 200), ("in", "order", "to", 180),
            ("one", "of", "the", 250), ("some", "of", "the", 200),
            ("a", "lot", "of", 280), ("a", "couple", "of", 150),

            ("at", "the", "end", 150), ("at", "the", "same", 140),
            ("in", "the", "morning", 160), ("in", "the", "afternoon", 140),
            ("in", "the", "evening", 130), ("on", "the", "other", 150),

            ("going", "to", "be", 300), ("want", "to", "be", 200),
            ("need", "to", "be", 180), ("have", "to", "be", 160),

            ("let", "me", "know", 250), ("please", "let", "me", 220),
            ("if", "you", "have", 200), ("if", "you", "need", 180),
            ("if", "you", "want", 170), ("if", "you", "can", 160),

            ("would", "be", "great", 180), ("would", "be", "nice", 150),
            ("would", "like", "to", 220), ("would", "love", "to", 180),

            ("how", "are", "you", 280), ("how", "do", "you", 220),
            ("what", "do", "you", 250), ("where", "do", "you", 180),

            ("it", "would", "be", 200), ("it", "will", "be", 220),
            ("there", "is", "a", 200), ("there", "are", "many", 150),
            ("this", "is", "a", 250), ("this", "is", "the", 220),
        ]

        for (word1, word2, word3, count) in commonTrigrams {
            let key = "\(word1)_\(word2)"
            trigrams[key, default: [:]][word3, default: 0] += count
        }
    }
}
