//
//  NGramPredictor.swift
//  SwiftSpeakKeyboard
//
//  N-gram based word prediction using bigram and trigram models
//  Predicts next word based on previous 1-2 words
//

import Foundation
import SwiftSpeakCore

/// N-gram data for a specific language
struct NGramData {
    var bigrams: [String: [String: Int]] = [:]
    var trigrams: [String: [String: Int]] = [:]
    var unigrams: [String: Int] = [:]
}

/// Persisted n-gram data structure for saving to App Groups
struct PersistedNGramData: Codable {
    var bigramsByLanguage: [String: [String: [String: Int]]]
    var trigramsByLanguage: [String: [String: [String: Int]]]
    var unigramsByLanguage: [String: [String: Int]]

    init() {
        bigramsByLanguage = [:]
        trigramsByLanguage = [:]
        unigramsByLanguage = [:]
    }

    init(from ngramsByLanguage: [String: NGramData]) {
        bigramsByLanguage = [:]
        trigramsByLanguage = [:]
        unigramsByLanguage = [:]

        for (language, data) in ngramsByLanguage {
            bigramsByLanguage[language] = data.bigrams
            trigramsByLanguage[language] = data.trigrams
            unigramsByLanguage[language] = data.unigrams
        }
    }

    func toNGramsByLanguage() -> [String: NGramData] {
        var result: [String: NGramData] = [:]

        // Get all languages from any of the dictionaries
        let allLanguages = Set(bigramsByLanguage.keys)
            .union(trigramsByLanguage.keys)
            .union(unigramsByLanguage.keys)

        for language in allLanguages {
            var data = NGramData()
            data.bigrams = bigramsByLanguage[language] ?? [:]
            data.trigrams = trigramsByLanguage[language] ?? [:]
            data.unigrams = unigramsByLanguage[language] ?? [:]
            result[language] = data
        }

        return result
    }
}

/// N-gram based word prediction service
/// Uses statistical patterns from common text to predict next words
/// Supports multiple languages with per-language n-gram models
actor NGramPredictor {
    static let shared = NGramPredictor()

    // App Groups persistence
    private let appGroupID = "group.pawelgawliczek.swiftspeak"
    private let learnedNGramsKey = "learnedNGrams"

    // N-gram data organized by language code (e.g., "en", "pl")
    // This contains both built-in and learned n-grams merged together
    private var ngramsByLanguage: [String: NGramData] = [:]

    // Separate storage for learned n-grams only (for persistence)
    private var learnedNgramsByLanguage: [String: NGramData] = [:]

    private var isInitialized = false

    // Debounce save operations to avoid excessive writes
    private var pendingSaveTask: Task<Void, Never>?
    private var hasPendingChanges = false

    private init() {}

    // MARK: - Initialization

    func initialize() async {
        guard !isInitialized else { return }

        keyboardLog("NGramPredictor: Starting init", category: "Prediction")

        // LAZY LOADING: Only load English by default
        // Other languages are loaded on-demand when predict() or predictCompletion() is called
        keyboardLog("NGramPredictor: Loading English n-grams...", category: "Prediction")
        loadBuiltInNGrams(for: "en")
        keyboardLog("NGramPredictor: English n-grams loaded", category: "Prediction")

        // Load persisted learned n-grams and merge with built-in
        keyboardLog("NGramPredictor: Loading learned n-grams...", category: "Prediction")
        loadLearnedNGrams()
        keyboardLog("NGramPredictor: Learned n-grams loaded", category: "Prediction")

        isInitialized = true

        keyboardLog("NGramPredictor initialized with lazy loading (en loaded, others on-demand)", category: "Prediction")
    }

    /// Ensure language data is loaded (lazy loading)
    /// Call this before accessing n-gram data for a specific language
    private func ensureLanguageLoaded(_ language: String) {
        // Skip if already loaded
        guard ngramsByLanguage[language] == nil else { return }

        // Load built-in n-grams for this language
        loadBuiltInNGrams(for: language)

        // Merge any learned data for this language
        if let learnedData = learnedNgramsByLanguage[language] {
            var combinedData = ngramsByLanguage[language] ?? NGramData()

            for (word, count) in learnedData.unigrams {
                combinedData.unigrams[word, default: 0] += count
            }
            for (key, nextWords) in learnedData.bigrams {
                for (nextWord, count) in nextWords {
                    combinedData.bigrams[key, default: [:]][nextWord, default: 0] += count
                }
            }
            for (key, nextWords) in learnedData.trigrams {
                for (nextWord, count) in nextWords {
                    combinedData.trigrams[key, default: [:]][nextWord, default: 0] += count
                }
            }

            ngramsByLanguage[language] = combinedData
        }

        let data = ngramsByLanguage[language] ?? NGramData()
        keyboardLog("NGramPredictor: Lazy-loaded \(language) (\(data.bigrams.count) bigrams, \(data.trigrams.count) trigrams)", category: "Prediction")
    }

    /// Learn from user's text (call with transcription history)
    /// - Parameters:
    ///   - text: Text to learn from
    ///   - language: Language code (defaults to "en")
    func learnFromText(_ text: String, language: String = "en") {
        let words = tokenize(text)
        guard words.count >= 2 else { return }

        // Get or create n-gram data for combined (built-in + learned)
        var combinedData = ngramsByLanguage[language] ?? NGramData()

        // Get or create n-gram data for learned only (for persistence)
        var learnedData = learnedNgramsByLanguage[language] ?? NGramData()

        // Build unigrams
        for word in words {
            combinedData.unigrams[word, default: 0] += 1
            learnedData.unigrams[word, default: 0] += 1
        }

        // Build bigrams
        for i in 0..<(words.count - 1) {
            let current = words[i]
            let next = words[i + 1]
            combinedData.bigrams[current, default: [:]][next, default: 0] += 1
            learnedData.bigrams[current, default: [:]][next, default: 0] += 1
        }

        // Build trigrams
        if words.count >= 3 {
            for i in 0..<(words.count - 2) {
                let key = "\(words[i])_\(words[i + 1])"
                let next = words[i + 2]
                combinedData.trigrams[key, default: [:]][next, default: 0] += 1
                learnedData.trigrams[key, default: [:]][next, default: 0] += 1
            }
        }

        ngramsByLanguage[language] = combinedData
        learnedNgramsByLanguage[language] = learnedData

        // Schedule a debounced save
        scheduleSave()
    }

    // MARK: - Prediction

    /// Predict next words based on previous words
    /// - Parameters:
    ///   - previousWords: Array of previous words (last 1-2 words)
    ///   - maxResults: Maximum number of predictions
    ///   - language: Language code (e.g., "pl", "es") for multi-language support (defaults to "en")
    /// - Returns: Array of predicted words sorted by probability
    func predict(previousWords: [String], maxResults: Int = 5, language: String? = nil) async -> [String] {
        // Ensure initialized before predicting
        if !isInitialized {
            await initialize()
        }

        let words = previousWords.map { $0.lowercased() }

        // Use specified language or fallback to English
        let lang = language ?? "en"

        // Lazy-load language data if not already loaded (English always available)
        if lang != "en" {
            ensureLanguageLoaded(lang)
        }

        guard let data = ngramsByLanguage[lang] ?? ngramsByLanguage["en"] else {
            return []
        }

        var predictions: [String: Double] = [:]

        // Try trigram first (most specific)
        if words.count >= 2 {
            let key = "\(words[words.count - 2])_\(words[words.count - 1])"
            if let nextWords = data.trigrams[key] {
                let total = Double(nextWords.values.reduce(0, +))
                for (word, count) in nextWords {
                    predictions[word, default: 0] += Double(count) / total * 3.0  // Higher weight for trigrams
                }
            }
        }

        // Try bigram
        if let lastWord = words.last, let nextWords = data.bigrams[lastWord] {
            let total = Double(nextWords.values.reduce(0, +))
            for (word, count) in nextWords {
                predictions[word, default: 0] += Double(count) / total * 2.0  // Medium weight for bigrams
            }
        }

        // Fallback to unigrams if no n-gram matches
        if predictions.isEmpty {
            let total = Double(data.unigrams.values.reduce(0, +))
            for (word, count) in data.unigrams.sorted(by: { $0.value > $1.value }).prefix(20) {
                predictions[word] = Double(count) / total
            }
        }

        // Sort by score and return top results (lowercase - caller handles capitalization)
        let sorted = predictions.sorted { $0.value > $1.value }
        return sorted.prefix(maxResults).map { $0.key }
    }

    /// Predict word completion based on prefix
    /// - Parameters:
    ///   - prefix: The partial word to complete
    ///   - previousWords: Array of previous words for context
    ///   - maxResults: Maximum number of completions
    ///   - language: Language code (e.g., "pl", "es") for multi-language support (defaults to "en")
    /// - Returns: Array of word completions sorted by probability
    func predictCompletion(prefix: String, previousWords: [String], maxResults: Int = 5, language: String? = nil) async -> [String] {
        // Ensure initialized before predicting
        if !isInitialized {
            await initialize()
        }

        let lowercasedPrefix = prefix.lowercased()
        guard !lowercasedPrefix.isEmpty else {
            return await predict(previousWords: previousWords, maxResults: maxResults, language: language)
        }

        // Use specified language or fallback to English
        let lang = language ?? "en"

        // Lazy-load language data if not already loaded (English always available)
        if lang != "en" {
            ensureLanguageLoaded(lang)
        }

        guard let data = ngramsByLanguage[lang] ?? ngramsByLanguage["en"] else {
            return []
        }

        var predictions: [String: Double] = [:]

        // Get all words starting with prefix
        let matchingUnigrams = data.unigrams.filter { $0.key.hasPrefix(lowercasedPrefix) }

        // Use n-gram context to boost relevant completions
        let contextPredictions = Set(await predict(previousWords: previousWords, maxResults: 20, language: language).map { $0.lowercased() })

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
        return sorted.prefix(maxResults).map { $0.key }
    }

    // MARK: - Helpers

    private func tokenize(_ text: String) -> [String] {
        // Use Unicode letter class \p{L} to support all languages (Polish, Spanish, French, etc.)
        let cleaned = text.lowercased()
            .replacingOccurrences(of: "[^\\p{L}\\s']", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return cleaned.split(separator: " ").map(String.init).filter { $0.count >= 2 }
    }

    // MARK: - Persistence

    /// Load learned n-grams from App Groups UserDefaults and merge with built-in
    private func loadLearnedNGrams() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            keyboardLog("NGramPredictor: Failed to access App Groups for loading", category: "Prediction", level: .error)
            return
        }

        guard let data = defaults.data(forKey: learnedNGramsKey) else {
            // No learned data yet - this is normal for first launch
            keyboardLog("NGramPredictor: No persisted n-grams found (first launch)", category: "Prediction")
            return
        }

        do {
            let persistedData = try JSONDecoder().decode(PersistedNGramData.self, from: data)
            learnedNgramsByLanguage = persistedData.toNGramsByLanguage()

            // Merge learned data into combined n-grams
            for (language, learnedData) in learnedNgramsByLanguage {
                var combinedData = ngramsByLanguage[language] ?? NGramData()

                // Merge unigrams
                for (word, count) in learnedData.unigrams {
                    combinedData.unigrams[word, default: 0] += count
                }

                // Merge bigrams
                for (key, nextWords) in learnedData.bigrams {
                    for (nextWord, count) in nextWords {
                        combinedData.bigrams[key, default: [:]][nextWord, default: 0] += count
                    }
                }

                // Merge trigrams
                for (key, nextWords) in learnedData.trigrams {
                    for (nextWord, count) in nextWords {
                        combinedData.trigrams[key, default: [:]][nextWord, default: 0] += count
                    }
                }

                ngramsByLanguage[language] = combinedData
            }

            let learnedCount = learnedNgramsByLanguage.values.reduce(0) { $0 + $1.bigrams.count + $1.trigrams.count }
            keyboardLog("NGramPredictor: Loaded \(learnedCount) learned n-gram patterns", category: "Prediction")
        } catch {
            keyboardLog("NGramPredictor: Failed to decode persisted n-grams: \(error.localizedDescription)", category: "Prediction", level: .error)
        }
    }

    /// Save learned n-grams to App Groups UserDefaults
    private func saveLearnedNGrams() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            keyboardLog("NGramPredictor: Failed to access App Groups for saving", category: "Prediction", level: .error)
            return
        }

        // Only save if there's learned data
        guard !learnedNgramsByLanguage.isEmpty else { return }

        do {
            let persistedData = PersistedNGramData(from: learnedNgramsByLanguage)
            let data = try JSONEncoder().encode(persistedData)
            defaults.set(data, forKey: learnedNGramsKey)

            let savedCount = learnedNgramsByLanguage.values.reduce(0) { $0 + $1.bigrams.count + $1.trigrams.count }
            keyboardLog("NGramPredictor: Saved \(savedCount) learned n-gram patterns", category: "Prediction")
        } catch {
            keyboardLog("NGramPredictor: Failed to encode n-grams for saving: \(error.localizedDescription)", category: "Prediction", level: .error)
        }
    }

    /// Schedule a debounced save operation (waits 2 seconds before saving)
    private func scheduleSave() {
        hasPendingChanges = true

        // Cancel any pending save task
        pendingSaveTask?.cancel()

        // Schedule new save with 2 second delay
        pendingSaveTask = Task {
            do {
                try await Task.sleep(for: .seconds(2))

                // Check if cancelled
                if Task.isCancelled { return }

                // Perform save if we still have pending changes
                if hasPendingChanges {
                    saveLearnedNGrams()
                    hasPendingChanges = false
                }
            } catch {
                // Task was cancelled - that's OK
            }
        }
    }

    /// Force an immediate save (call when app is about to terminate)
    func forceSave() {
        pendingSaveTask?.cancel()
        if hasPendingChanges {
            saveLearnedNGrams()
            hasPendingChanges = false
        }
    }

    // MARK: - Built-in N-Grams

    private func loadBuiltInNGrams(for language: String) {
        keyboardLog("loadBuiltInNGrams: Starting for \(language)", category: "Prediction")
        var data = NGramData()

        switch language {
        case "en":
            keyboardLog("loadBuiltInNGrams: Calling loadEnglishNGrams", category: "Prediction")
            loadEnglishNGrams(into: &data)
            keyboardLog("loadBuiltInNGrams: loadEnglishNGrams returned", category: "Prediction")
        case "pl":
            loadPolishNGrams(into: &data)
        case "es":
            loadSpanishNGrams(into: &data)
        case "fr":
            loadFrenchNGrams(into: &data)
        case "de":
            loadGermanNGrams(into: &data)
        case "it":
            loadItalianNGrams(into: &data)
        case "pt":
            loadPortugueseNGrams(into: &data)
        case "ru":
            loadRussianNGrams(into: &data)
        case "ar":
            loadArabicNGrams(into: &data)
        case "arz":
            loadEgyptianArabicNGrams(into: &data)
        case "zh":
            loadChineseNGrams(into: &data)
        case "ja":
            loadJapaneseNGrams(into: &data)
        case "ko":
            loadKoreanNGrams(into: &data)
        default:
            // Fallback to English for unsupported languages
            loadEnglishNGrams(into: &data)
        }

        ngramsByLanguage[language] = data
    }

    private func loadEnglishNGrams(into data: inout NGramData) {
        keyboardLog("loadEnglishNGrams: ENTERED", category: "Prediction")
        // Common English bigrams (word pairs)
        keyboardLog("loadEnglishNGrams: Creating commonBigrams array...", category: "Prediction")
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

            // Question continuations (verb → pronoun for questions)
            ("are", "you", 550), ("are", "we", 300), ("are", "they", 280),
            ("is", "it", 400), ("is", "there", 350), ("is", "this", 320), ("is", "that", 300),
            ("do", "you", 500), ("does", "it", 350), ("did", "you", 400),
            ("have", "you", 400), ("has", "it", 300),
            ("will", "you", 350), ("would", "you", 380), ("could", "you", 360), ("can", "you", 400),

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

            // Common responses and reactions
            ("sounds", "good", 280), ("sounds", "great", 250), ("sounds", "like", 220),
            ("no", "problem", 260), ("no", "worries", 240), ("no", "way", 180),
            ("of", "course", 280), ("all", "right", 220), ("all", "good", 200),
            ("got", "it", 250), ("makes", "sense", 220), ("fair", "enough", 180),
            ("same", "here", 160), ("me", "too", 200), ("me", "neither", 140),

            // More casual phrases
            ("right", "now", 220), ("just", "now", 180), ("for", "now", 200),
            ("so", "far", 180), ("so", "much", 200), ("so", "good", 170),
            ("too", "much", 180), ("too", "bad", 150), ("too", "late", 140),
            ("not", "sure", 250), ("not", "yet", 220), ("not", "really", 200),
            ("kind", "of", 220), ("sort", "of", 180), ("a", "bit", 200),

            // Action phrases
            ("talk", "to", 180), ("talk", "about", 160), ("talk", "later", 200),
            ("see", "you", 250), ("catch", "up", 180), ("hang", "out", 160),
            ("work", "on", 180), ("work", "out", 160), ("figure", "out", 180),
            ("find", "out", 170), ("check", "out", 180), ("come", "back", 200),
            ("get", "back", 220), ("get", "home", 180), ("get", "there", 160),

            // Feeling expressions
            ("feel", "like", 220), ("feel", "better", 180), ("feel", "good", 160),
            ("look", "like", 200), ("look", "good", 170), ("look", "forward", 180),
            ("really", "good", 180), ("really", "nice", 160), ("really", "appreciate", 200),

            // Time casual
            ("in", "a", 300), ("a", "minute", 180), ("a", "second", 160),
            ("a", "while", 180), ("a", "few", 200), ("few", "minutes", 180),
            ("couple", "of", 180), ("of", "days", 160), ("of", "weeks", 140),

            // Messaging common
            ("on", "my", 200), ("my", "way", 220), ("be", "there", 200),
            ("be", "back", 180), ("be", "right", 160), ("running", "late", 180),
            ("almost", "there", 160), ("just", "got", 180), ("just", "finished", 160),
        ]

        keyboardLog("loadEnglishNGrams: commonBigrams created, processing \(commonBigrams.count) entries", category: "Prediction")
        for (word1, word2, count) in commonBigrams {
            data.bigrams[word1, default: [:]][word2, default: 0] += count
            data.unigrams[word1, default: 0] += count
            data.unigrams[word2, default: 0] += count
        }
        keyboardLog("loadEnglishNGrams: bigrams processed", category: "Prediction")

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

            // Common responses
            ("sounds", "good", "to", 180), ("sounds", "like", "a", 160),
            ("no", "problem", "at", 140), ("of", "course", "i", 160),
            ("i", "got", "it", 180), ("makes", "sense", "to", 140),

            // Casual messaging
            ("on", "my", "way", 280), ("be", "there", "soon", 200),
            ("be", "right", "back", 180), ("see", "you", "soon", 220),
            ("see", "you", "later", 200), ("see", "you", "there", 180),
            ("talk", "to", "you", 200), ("catch", "up", "later", 160),

            // Time expressions
            ("in", "a", "minute", 180), ("in", "a", "bit", 200),
            ("in", "a", "few", 160), ("a", "few", "minutes", 180),
            ("a", "couple", "of", 170), ("couple", "of", "days", 150),

            // Feelings/reactions
            ("i", "feel", "like", 180), ("i", "really", "appreciate", 200),
            ("that", "sounds", "good", 180), ("that", "makes", "sense", 160),
            ("i", "really", "like", 160), ("i", "really", "think", 140),

            // Questions extended
            ("do", "you", "want", 220), ("do", "you", "have", 250),
            ("do", "you", "know", 230), ("do", "you", "think", 200),
            ("can", "you", "please", 180), ("could", "you", "please", 170),
            ("are", "you", "going", 180), ("are", "you", "sure", 200),

            // More business
            ("i", "look", "forward", 180), ("look", "forward", "to", 220),
            ("please", "let", "me", 200), ("get", "back", "to", 180),
            ("as", "soon", "as", 200), ("reach", "out", "to", 150),
        ]

        for (word1, word2, word3, count) in commonTrigrams {
            let key = "\(word1)_\(word2)"
            data.trigrams[key, default: [:]][word3, default: 0] += count
        }
    }

    private func loadPolishNGrams(into data: inout NGramData) {
        // COMPREHENSIVE Polish bigrams - one of the strongest languages (~200 bigrams)
        let commonBigrams: [(String, String, Int)] = [
            // ===== PRONOUNS + VERBS (byc - to be) =====
            ("ja", "jestem", 500), ("ja", "mam", 400), ("ja", "bede", 300), ("ja", "bylem", 280),
            ("ja", "chce", 350), ("ja", "moge", 320), ("ja", "musze", 300), ("ja", "wiem", 280),
            ("ty", "jestes", 400), ("ty", "masz", 350), ("ty", "mozesz", 300), ("ty", "musisz", 250),
            ("on", "jest", 450), ("on", "ma", 380), ("on", "bedzie", 320), ("on", "byl", 300),
            ("ona", "jest", 440), ("ona", "ma", 370), ("ona", "bedzie", 310), ("ona", "byla", 290),
            ("my", "jestesmy", 350), ("my", "mamy", 320), ("my", "bedziemy", 280), ("my", "mozemy", 300),
            ("wy", "jestescie", 300), ("wy", "macie", 280), ("wy", "mozecie", 250),
            ("oni", "sa", 400), ("oni", "maja", 350), ("oni", "byli", 280), ("oni", "beda", 300),
            ("one", "sa", 380), ("one", "maja", 340), ("one", "byly", 270), ("one", "beda", 290),

            // ===== NEGATION PATTERNS (nie + verb) - ~30 =====
            ("nie", "wiem", 550), ("nie", "mam", 530), ("nie", "moge", 510), ("nie", "chce", 490),
            ("nie", "rozumiem", 450), ("nie", "widze", 400), ("nie", "slyszę", 350), ("nie", "pamietam", 380),
            ("nie", "mysle", 320), ("nie", "sadze", 300), ("nie", "jestem", 470), ("nie", "bede", 400),
            ("nie", "bylo", 380), ("nie", "ma", 520), ("nie", "masz", 420), ("nie", "musisz", 350),
            ("nie", "mozesz", 380), ("nie", "wolno", 300), ("nie", "trzeba", 350), ("nie", "warto", 320),
            ("nie", "lubie", 340), ("nie", "kocham", 200), ("nie", "znosze", 220), ("nie", "cierpie", 180),
            ("nie", "przeszkadza", 250), ("nie", "dziwie", 200), ("nie", "spodziewalem", 220),
            ("nie", "wiedzialem", 350), ("nie", "zauwazylem", 280), ("nie", "zdazylem", 250),

            // ===== REFLEXIVE VERB PATTERNS (sie + context) - ~25 =====
            ("ciesze", "sie", 450), ("martwię", "sie", 400), ("boje", "sie", 380), ("wstydze", "sie", 280),
            ("denerwuje", "sie", 320), ("stresuje", "sie", 280), ("nudze", "sie", 250), ("spiesze", "sie", 300),
            ("ucze", "sie", 350), ("staram", "sie", 380), ("modle", "sie", 200), ("zastanawiam", "sie", 350),
            ("dziwie", "sie", 280), ("zgadzam", "sie", 320), ("spotykam", "sie", 300), ("widze", "sie", 280),
            ("slyszę", "sie", 200), ("czuje", "sie", 400), ("mam", "sie", 380), ("masz", "sie", 350),
            ("sie", "dobrze", 420), ("sie", "zle", 320), ("sie", "swietnie", 280), ("sie", "fatalnie", 200),
            ("sie", "stalo", 400), ("sie", "dzieje", 450), ("sie", "zdarzylo", 300), ("sie", "okazalo", 280),

            // ===== MODAL VERB PATTERNS - ~20 =====
            ("musze", "isc", 450), ("musze", "zrobic", 420), ("musze", "powiedziec", 380), ("musze", "przyznac", 300),
            ("moge", "pomoc", 400), ("moge", "zapytac", 350), ("moge", "prosic", 320), ("moge", "przyjsc", 280),
            ("chce", "powiedziec", 380), ("chce", "wiedziec", 350), ("chce", "zobaczyc", 300), ("chce", "kupic", 280),
            ("powinienem", "byl", 250), ("powinienem", "isc", 280), ("powinnąs", "wiedziec", 240),
            ("trzeba", "bylo", 350), ("trzeba", "bedzie", 300), ("trzeba", "zrobic", 320),
            ("warto", "sprobowac", 280), ("warto", "zobaczyc", 260),

            // ===== CONJUNCTION PATTERNS - ~22 =====
            ("ale", "nie", 450), ("ale", "tak", 380), ("ale", "jednak", 300), ("ale", "tez", 280),
            ("i", "tak", 400), ("i", "nie", 350), ("i", "dlatego", 280), ("i", "wtedy", 250),
            ("bo", "nie", 380), ("bo", "to", 350), ("bo", "ja", 300), ("bo", "mam", 280),
            ("wiec", "co", 300), ("wiec", "jak", 280), ("wiec", "moze", 260),
            ("albo", "nie", 250), ("albo", "tak", 220), ("czy", "tez", 280),
            ("zeby", "nie", 320), ("zeby", "moc", 280), ("ze", "to", 400), ("ze", "nie", 450),

            // ===== QUESTION EXPANSIONS - ~23 =====
            ("co", "robisz", 400), ("co", "dzis", 350), ("co", "tam", 320), ("co", "slychac", 450),
            ("co", "myslisz", 320), ("co", "powiesz", 280), ("co", "sadzisz", 260), ("co", "planujesz", 240),
            ("jak", "sie", 500), ("jak", "leci", 350), ("jak", "minal", 300), ("jak", "idzie", 280),
            ("jak", "mozna", 260), ("jak", "to", 400), ("gdzie", "jestes", 320), ("gdzie", "idziesz", 280),
            ("gdzie", "byles", 260), ("kiedy", "przyjdziesz", 280), ("kiedy", "wrocisz", 250),
            ("kiedy", "bedziesz", 240), ("dlaczego", "nie", 350), ("dlaczego", "tak", 280),
            ("po", "co", 300),

            // ===== TIME EXPRESSIONS EXPANDED - ~25 =====
            ("w", "weekend", 300), ("w", "niedziele", 270), ("w", "poniedzialek", 260), ("w", "sobote", 280),
            ("w", "piatek", 270), ("w", "srode", 240), ("w", "czwartek", 240), ("we", "wtorek", 240),
            ("jutro", "rano", 300), ("dzis", "wieczorem", 280), ("wczoraj", "wieczorem", 260),
            ("za", "tydzien", 280), ("za", "miesiac", 260), ("za", "rok", 240), ("za", "chwile", 350),
            ("za", "moment", 300), ("za", "godzine", 280), ("w", "zeszlym", 220), ("zeszlym", "tygodniu", 300),
            ("zeszlym", "roku", 270), ("w", "przyszlym", 200), ("przyszlym", "tygodniu", 280),
            ("przyszlym", "roku", 250), ("od", "rana", 240), ("do", "wieczora", 220),

            // ===== EVERYDAY PHRASES - ~26 =====
            ("dziekuje", "bardzo", 600), ("prosze", "bardzo", 550), ("do", "widzenia", 500),
            ("na", "razie", 480), ("dzien", "dobry", 580), ("dobry", "wieczor", 480),
            ("dobranoc", "kochanie", 220), ("czesc", "jak", 400), ("jak", "sie", 520),
            ("sie", "masz", 480), ("milego", "dnia", 320), ("wszystkiego", "najlepszego", 300),
            ("w", "porzadku", 520), ("na", "pewno", 450), ("po", "prostu", 500),
            ("od", "razu", 350), ("w", "domu", 480), ("w", "pracy", 420), ("w", "szkole", 380),
            ("do", "domu", 450), ("do", "pracy", 380), ("do", "zobaczenia", 400),
            ("z", "toba", 380), ("dla", "ciebie", 350), ("przy", "okazji", 280), ("na", "przyklad", 350),

            // ===== FORMAL/BUSINESS PHRASES - ~15 =====
            ("prosze", "o", 380), ("bardzo", "prosze", 350), ("moge", "prosic", 280),
            ("czy", "moge", 320), ("czy", "moglbym", 260), ("jesli", "mozesz", 240),
            ("jak", "najszybciej", 280), ("z", "gory", 220), ("gory", "dziekuje", 240),
            ("uprzejmie", "prosze", 220), ("z", "powazaniem", 200), ("serdecznie", "zapraszam", 180),
            ("w", "zalaczeniu", 200), ("w", "odpowiedzi", 220), ("z", "przyjemnoscia", 240),

            // ===== COLLOQUIAL/SLANG - ~27 =====
            ("no", "tak", 400), ("no", "nie", 380), ("no", "wiesz", 350), ("no", "co", 320),
            ("no", "dobra", 350), ("no", "wlasnie", 300), ("no", "jasne", 280),
            ("spoko", "luzik", 180), ("luz", "blues", 150), ("git", "majonez", 120),
            ("daj", "spokoj", 300), ("daj", "znac", 320), ("nie", "gadaj", 220),
            ("bez", "kitu", 200), ("bez", "jaj", 180), ("serio", "mowie", 220),
            ("zartujesz", "sobie", 200), ("chyba", "zartujesz", 220), ("nie", "wierze", 280),
            ("stary", "ale", 200), ("koles", "ale", 150), ("ziomek", "daj", 120),
            ("wez", "przestan", 220), ("wez", "zobacz", 200), ("ej", "sluchaj", 250),
            ("hej", "co", 280), ("hej", "jak", 260),

            // ===== COMMON EXPRESSIONS - ~24 =====
            ("to", "jest", 500), ("to", "bylo", 400), ("to", "bedzie", 380), ("to", "znaczy", 350),
            ("co", "to", 400), ("jak", "to", 420), ("po", "co", 320), ("za", "co", 280),
            ("nie", "wiem", 550), ("nie", "ma", 530), ("tak", "jest", 380), ("tak", "samo", 300),
            ("tez", "tak", 280), ("ani", "troche", 200), ("mimo", "wszystko", 280),
            ("w", "koncu", 320), ("na", "koniec", 280), ("od", "poczatku", 250),
            ("w", "sumie", 300), ("w", "ogole", 350), ("tak", "naprawde", 320),
            ("oczywiscie", "ze", 280), ("niestety", "nie", 300), ("na", "szczescie", 280),

            // ===== HIGH-FREQUENCY PATTERNS - ~23 =====
            ("chcialbym", "wiedziec", 300), ("chcialbym", "zapytac", 280), ("chcialbym", "prosic", 260),
            ("bede", "mogl", 320), ("bede", "mial", 300), ("bede", "czekal", 280),
            ("przez", "internet", 280), ("na", "zewnatrz", 380), ("na", "gorze", 280),
            ("na", "dole", 260), ("obok", "ciebie", 220), ("kolo", "mnie", 200),
            ("razem", "z", 300), ("sam", "na", 250), ("kazdy", "z", 220),
            ("jeden", "z", 280), ("zaden", "z", 200), ("niektorzy", "z", 180),
            ("ktos", "inny", 220), ("cos", "innego", 240), ("nikt", "nie", 350),
            ("nic", "nie", 380), ("wszystko", "jest", 320),
        ]

        for (word1, word2, count) in commonBigrams {
            data.bigrams[word1, default: [:]][word2, default: 0] += count
            data.unigrams[word1, default: 0] += count
            data.unigrams[word2, default: 0] += count
        }

        // COMPREHENSIVE Polish trigrams (~90 trigrams)
        let commonTrigrams: [(String, String, String, Int)] = [
            // ===== VERY COMMON PHRASES =====
            ("jak", "sie", "masz", 500), ("co", "sie", "dzieje", 400), ("co", "sie", "stalo", 380),
            ("wszystko", "w", "porzadku", 350), ("w", "porzadku", "dzieki", 280),
            ("bardzo", "sie", "ciesze", 320), ("nie", "ma", "sprawy", 380),
            ("nie", "ma", "problemu", 350), ("nie", "ma", "za", 300),

            // ===== PRONOUNS + VERB PHRASES =====
            ("ja", "chce", "powiedziec", 340), ("ja", "musze", "isc", 320),
            ("ja", "moge", "pomoc", 300), ("ja", "nie", "wiem", 400),
            ("ja", "nie", "mam", 380), ("ja", "tez", "tak", 280),
            ("ja", "tez", "nie", 300), ("ja", "tez", "chce", 260),

            // ===== NEGATION TRIGRAMS =====
            ("nie", "wiem", "co", 350), ("nie", "wiem", "jak", 330), ("nie", "wiem", "czy", 310),
            ("nie", "mam", "czasu", 300), ("nie", "mam", "pojecia", 280), ("nie", "mam", "ochoty", 260),
            ("nie", "moge", "uwierzyc", 280), ("nie", "moge", "sie", 300), ("nie", "moge", "znalezc", 260),
            ("nie", "chce", "zeby", 250), ("nie", "chce", "wiedziec", 230),
            ("nie", "jestem", "pewien", 280), ("nie", "jestem", "pewna", 270),

            // ===== REFLEXIVE VERB TRIGRAMS =====
            ("ciesze", "sie", "ze", 300), ("ciesze", "sie", "bardzo", 280),
            ("martwię", "sie", "o", 280), ("martwię", "sie", "ze", 260),
            ("boje", "sie", "ze", 260), ("boje", "sie", "o", 240),
            ("czuje", "sie", "dobrze", 300), ("czuje", "sie", "zle", 250),
            ("czuje", "sie", "swietnie", 220), ("mam", "sie", "dobrze", 350),

            // ===== QUESTION TRIGRAMS =====
            ("czy", "moge", "prosic", 290), ("czy", "moglbym", "zapytac", 240),
            ("czy", "mozesz", "mi", 280), ("co", "u", "ciebie", 320),
            ("co", "robisz", "dzis", 280), ("co", "robisz", "jutro", 260),
            ("co", "tam", "slychac", 300), ("jak", "minal", "dzien", 260),
            ("jak", "leci", "stary", 220), ("gdzie", "sie", "spotykamy", 220),
            ("kiedy", "sie", "spotkamy", 240), ("kiedy", "bedziesz", "wolny", 200),
            ("dlaczego", "nie", "mozesz", 220), ("po", "co", "ci", 200),

            // ===== POLITENESS PHRASES =====
            ("dziekuje", "bardzo", "za", 340), ("prosze", "bardzo", "sie", 240),
            ("z", "gory", "dziekuje", 260), ("wszystkiego", "najlepszego", "z", 240),
            ("milego", "dnia", "zycze", 220), ("serdecznie", "zapraszam", "na", 180),
            ("uprzejmie", "prosze", "o", 200),

            // ===== TIME EXPRESSION TRIGRAMS =====
            ("w", "zeszlym", "tygodniu", 290), ("w", "zeszlym", "roku", 260),
            ("w", "przyszlym", "tygodniu", 270), ("w", "przyszlym", "roku", 240),
            ("za", "kilka", "dni", 240), ("za", "kilka", "minut", 220),
            ("za", "kilka", "godzin", 200), ("od", "samego", "rana", 180),
            ("do", "pozna", "w", 170), ("przez", "caly", "dzien", 200),
            ("przez", "caly", "czas", 220),

            // ===== MODAL VERB TRIGRAMS =====
            ("chce", "ci", "powiedziec", 260), ("musze", "ci", "powiedziec", 240),
            ("moge", "ci", "pomoc", 280), ("bede", "mogl", "pomoc", 220),
            ("chcialbym", "cie", "zapytac", 200), ("chcialbym", "ci", "podziekowac", 180),
            ("powinienem", "byl", "wiedziec", 180), ("trzeba", "bylo", "wczesniej", 170),

            // ===== COMMON SENTENCE PATTERNS =====
            ("to", "jest", "dobre", 260), ("to", "jest", "swietne", 240),
            ("to", "jest", "super", 220), ("to", "jest", "problem", 200),
            ("to", "bylo", "super", 200), ("to", "bylo", "swietne", 190),
            ("jak", "to", "mozliwe", 220), ("co", "za", "niespodzianka", 180),

            // ===== TRANSITIONAL/CONNECTING =====
            ("w", "kazdym", "razie", 240), ("na", "przyklad", "jak", 220),
            ("tak", "czy", "inaczej", 210), ("w", "takim", "razie", 260),
            ("jesli", "chodzi", "o", 230), ("o", "ile", "wiem", 200),
            ("z", "tego", "co", 220), ("mimo", "wszystko", "to", 180),
            ("w", "sumie", "to", 200), ("tak", "naprawde", "to", 220),

            // ===== COLLOQUIAL/EVERYDAY TRIGRAMS =====
            ("no", "nie", "wiem", 280), ("no", "tak", "wlasnie", 220),
            ("no", "dobra", "to", 200), ("daj", "mi", "znac", 250),
            ("daj", "mi", "spokoj", 220), ("wez", "to", "zobacz", 180),
            ("ej", "sluchaj", "mam", 170), ("hej", "co", "tam", 220),
            ("serio", "mowie", "ci", 180), ("zartujesz", "sobie", "ze", 160),

            // ===== HIGH-FREQUENCY PATTERNS =====
            ("tak", "jak", "mowilem", 200), ("tak", "jak", "myslalem", 190),
            ("nie", "tak", "jak", 220), ("razem", "z", "toba", 200),
            ("kazdy", "z", "nas", 180), ("jeden", "z", "nich", 200),
            ("zaden", "z", "nich", 170), ("nikt", "nie", "wie", 220),
            ("nic", "nie", "wiem", 240), ("wszystko", "jest", "dobrze", 260),
        ]

        for (word1, word2, word3, count) in commonTrigrams {
            let key = "\(word1)_\(word2)"
            data.trigrams[key, default: [:]][word3, default: 0] += count
        }
    }

    private func loadSpanishNGrams(into data: inout NGramData) {
        // Common Spanish bigrams (word pairs)
        let commonBigrams: [(String, String, Int)] = [
            // Pronouns + verbs (ser/estar - to be)
            ("yo", "soy", 500), ("yo", "tengo", 400), ("yo", "estoy", 350), ("yo", "quiero", 320),
            ("yo", "voy", 300), ("yo", "puedo", 280), ("yo", "necesito", 260), ("yo", "sé", 250),

            ("tú", "eres", 450), ("tú", "tienes", 380), ("tú", "estás", 350), ("tú", "quieres", 300),
            ("tú", "vas", 280), ("tú", "puedes", 270), ("tú", "sabes", 250),

            ("él", "es", 480), ("él", "tiene", 400), ("él", "está", 370), ("él", "va", 320),
            ("ella", "es", 470), ("ella", "tiene", 390), ("ella", "está", 360), ("ella", "va", 310),

            ("nosotros", "somos", 350), ("nosotros", "tenemos", 320), ("nosotros", "estamos", 300),
            ("nosotros", "vamos", 280), ("nosotros", "podemos", 260),

            ("ellos", "son", 400), ("ellos", "tienen", 350), ("ellos", "están", 320), ("ellos", "van", 290),
            ("ellas", "son", 390), ("ellas", "tienen", 340), ("ellas", "están", 310),

            // Common phrases and greetings
            ("muchas", "gracias", 600), ("de", "nada", 550), ("por", "favor", 580),
            ("buenos", "días", 520), ("buenas", "tardes", 480), ("buenas", "noches", 500),
            ("hasta", "luego", 450), ("hasta", "pronto", 350), ("hasta", "mañana", 380),
            ("qué", "tal", 500), ("cómo", "estás", 480), ("muy", "bien", 450),
            ("lo", "siento", 400), ("con", "permiso", 320), ("me", "alegro", 300),

            // Preposition patterns
            ("en", "casa", 450), ("en", "la", 500), ("a", "la", 480), ("de", "la", 470),
            ("con", "el", 400), ("por", "la", 380), ("para", "el", 360),
            ("de", "acuerdo", 420), ("por", "supuesto", 390), ("sin", "duda", 350),

            // Verb phrases
            ("quiero", "decir", 400), ("tengo", "que", 450), ("voy", "a", 480),
            ("puedo", "ayudar", 320), ("necesito", "saber", 300), ("vamos", "a", 420),
            ("hay", "que", 380), ("me", "gustaría", 350), ("me", "gusta", 450),
            ("está", "bien", 400), ("es", "importante", 320), ("es", "necesario", 300),

            // Question patterns
            ("qué", "pasa", 350), ("qué", "haces", 320), ("cómo", "te", 380),
            ("dónde", "está", 340), ("dónde", "estás", 320), ("cuándo", "vas", 280),
            ("por", "qué", 400), ("quién", "es", 300),

            // Time expressions
            ("esta", "mañana", 280), ("esta", "tarde", 260), ("esta", "noche", 270),
            ("el", "lunes", 220), ("el", "martes", 210), ("el", "fin", 250),
            ("fin", "de", 280), ("de", "semana", 300), ("la", "semana", 280),
        ]

        for (word1, word2, count) in commonBigrams {
            data.bigrams[word1, default: [:]][word2, default: 0] += count
            data.unigrams[word1, default: 0] += count
            data.unigrams[word2, default: 0] += count
        }

        // Common Spanish trigrams
        let commonTrigrams: [(String, String, String, Int)] = [
            // Very common phrases
            ("muchas", "gracias", "por", 350), ("de", "nada", "adiós", 200),
            ("por", "favor", "gracias", 250), ("cómo", "estás", "hoy", 300),
            ("muy", "bien", "gracias", 320), ("qué", "tal", "todo", 280),

            // Verb constructions
            ("yo", "quiero", "decir", 280), ("yo", "tengo", "que", 300),
            ("yo", "voy", "a", 320), ("yo", "necesito", "saber", 240),
            ("tú", "tienes", "que", 260), ("él", "va", "a", 280),

            // Questions
            ("qué", "pasa", "aquí", 250), ("cómo", "te", "llamas", 280),
            ("dónde", "está", "el", 260), ("cuándo", "vas", "a", 220),

            // Politeness
            ("por", "favor", "ayúdame", 200), ("me", "gustaría", "saber", 240),
            ("si", "puedes", "ayudar", 220),

            // Time expressions
            ("fin", "de", "semana", 300), ("esta", "mañana", "temprano", 180),
            ("el", "año", "pasado", 200), ("la", "semana", "próxima", 220),
        ]

        for (word1, word2, word3, count) in commonTrigrams {
            let key = "\(word1)_\(word2)"
            data.trigrams[key, default: [:]][word3, default: 0] += count
        }
    }

    private func loadFrenchNGrams(into data: inout NGramData) {
        // Common French bigrams (word pairs)
        let commonBigrams: [(String, String, Int)] = [
            // Pronouns + verbs (être/avoir - to be/to have)
            ("je", "suis", 500), ("j'ai", "besoin", 400), ("je", "vais", 350), ("je", "peux", 320),
            ("je", "veux", 380), ("je", "dois", 340), ("je", "sais", 300), ("je", "fais", 280),

            ("tu", "es", 450), ("tu", "as", 380), ("tu", "vas", 340), ("tu", "peux", 310),
            ("tu", "veux", 350), ("tu", "dois", 300), ("tu", "sais", 280),

            ("il", "est", 480), ("il", "a", 400), ("il", "va", 350), ("il", "peut", 320),
            ("elle", "est", 470), ("elle", "a", 390), ("elle", "va", 340), ("elle", "peut", 310),

            ("nous", "sommes", 380), ("nous", "avons", 350), ("nous", "allons", 340),
            ("nous", "pouvons", 300), ("nous", "devons", 280),

            ("ils", "sont", 420), ("ils", "ont", 380), ("ils", "vont", 350),
            ("elles", "sont", 410), ("elles", "ont", 370), ("elles", "vont", 340),

            // Common phrases and greetings
            ("merci", "beaucoup", 600), ("de", "rien", 550), ("s'il", "vous", 520),
            ("vous", "plaît", 580), ("bonjour", "madame", 480), ("bonjour", "monsieur", 470),
            ("bonne", "journée", 450), ("bonne", "nuit", 420), ("bonne", "soirée", 400),
            ("à", "bientôt", 500), ("à", "demain", 450), ("au", "revoir", 480),
            ("ça", "va", 520), ("comment", "allez", 400), ("enchanté", "de", 350),

            // Preposition patterns
            ("à", "la", 500), ("de", "la", 480), ("dans", "la", 450),
            ("à", "maison", 380), ("la", "maison", 420), ("d'accord", "merci", 350),
            ("bien", "sûr", 400), ("en", "fait", 380), ("tout", "à", 360),

            // Verb phrases
            ("je", "veux", 400), ("je", "dois", 350), ("je", "peux", 380),
            ("je", "voudrais", 420), ("il", "faut", 450), ("c'est", "bon", 380),
            ("c'est", "bien", 400), ("c'est", "possible", 320), ("je", "pense", 350),

            // Question patterns
            ("comment", "ça", 380), ("qu'est", "ce", 420), ("où", "est", 350),
            ("quand", "est", 300), ("pourquoi", "pas", 340), ("qui", "est", 320),

            // Time expressions
            ("ce", "matin", 280), ("cet", "après-midi", 250), ("ce", "soir", 300),
            ("la", "semaine", 280), ("semaine", "prochaine", 320), ("le", "mois", 240),
        ]

        for (word1, word2, count) in commonBigrams {
            data.bigrams[word1, default: [:]][word2, default: 0] += count
            data.unigrams[word1, default: 0] += count
            data.unigrams[word2, default: 0] += count
        }

        // Common French trigrams
        let commonTrigrams: [(String, String, String, Int)] = [
            // Very common phrases
            ("merci", "beaucoup", "madame", 280), ("de", "rien", "au", 200),
            ("s'il", "vous", "plaît", 450), ("comment", "allez", "vous", 320),
            ("ça", "va", "bien", 350), ("très", "bien", "merci", 300),

            // Verb constructions
            ("je", "veux", "dire", 280), ("je", "dois", "aller", 260),
            ("je", "peux", "aider", 250), ("je", "voudrais", "savoir", 290),
            ("il", "faut", "que", 320), ("c'est", "à", "dire", 280),

            // Questions
            ("qu'est", "ce", "que", 400), ("où", "est", "la", 280),
            ("comment", "ça", "va", 350), ("quand", "est", "ce", 240),

            // Politeness
            ("s'il", "te", "plaît", 300), ("je", "vous", "remercie", 240),
            ("enchanté", "de", "vous", 220),

            // Time expressions
            ("la", "semaine", "prochaine", 280), ("ce", "week-end", "prochain", 200),
            ("l'année", "dernière", "nous", 180), ("dans", "quelques", "jours", 220),
        ]

        for (word1, word2, word3, count) in commonTrigrams {
            let key = "\(word1)_\(word2)"
            data.trigrams[key, default: [:]][word3, default: 0] += count
        }
    }

    private func loadGermanNGrams(into data: inout NGramData) {
        // Common German bigrams (word pairs)
        let commonBigrams: [(String, String, Int)] = [
            // Pronouns + verbs (sein/haben - to be/to have)
            ("ich", "bin", 500), ("ich", "habe", 450), ("ich", "kann", 400), ("ich", "will", 380),
            ("ich", "muss", 360), ("ich", "möchte", 420), ("ich", "gehe", 320), ("ich", "weiß", 340),

            ("du", "bist", 450), ("du", "hast", 400), ("du", "kannst", 360), ("du", "willst", 340),
            ("du", "musst", 320), ("du", "möchtest", 380), ("du", "gehst", 300),

            ("er", "ist", 480), ("er", "hat", 420), ("er", "kann", 380), ("er", "geht", 340),
            ("sie", "ist", 470), ("sie", "hat", 410), ("sie", "kann", 370), ("sie", "geht", 330),

            ("wir", "sind", 400), ("wir", "haben", 370), ("wir", "können", 350),
            ("wir", "müssen", 320), ("wir", "gehen", 300),

            ("sie", "sind", 420), ("sie", "haben", 380), ("sie", "können", 360),

            // Common phrases and greetings
            ("vielen", "dank", 580), ("bitte", "schön", 520), ("gern", "geschehen", 450),
            ("guten", "morgen", 500), ("guten", "tag", 480), ("guten", "abend", 460),
            ("gute", "nacht", 440), ("auf", "wiedersehen", 520), ("bis", "bald", 400),
            ("bis", "später", 380), ("wie", "geht's", 480), ("es", "geht", 450),
            ("sehr", "gut", 420), ("alles", "klar", 400),

            // Preposition patterns
            ("zu", "hause", 480), ("im", "haus", 380), ("in", "der", 450),
            ("auf", "dem", 400), ("mit", "dem", 380), ("von", "der", 360),
            ("in", "ordnung", 440), ("bitte", "sehr", 420), ("kein", "problem", 390),

            // Verb phrases
            ("ich", "muss", 400), ("ich", "kann", 420), ("ich", "möchte", 450),
            ("ich", "will", 380), ("ich", "würde", 360), ("es", "gibt", 440),
            ("das", "ist", 480), ("das", "war", 400), ("kann", "ich", 380),

            // Question patterns
            ("wie", "geht", 420), ("wo", "ist", 380), ("wer", "ist", 340),
            ("was", "ist", 400), ("wann", "kommst", 300), ("warum", "nicht", 350),

            // Time expressions
            ("heute", "morgen", 280), ("gestern", "abend", 260), ("morgen", "früh", 240),
            ("nächste", "woche", 300), ("letztes", "jahr", 250), ("diese", "woche", 320),
        ]

        for (word1, word2, count) in commonBigrams {
            data.bigrams[word1, default: [:]][word2, default: 0] += count
            data.unigrams[word1, default: 0] += count
            data.unigrams[word2, default: 0] += count
        }

        // Common German trigrams
        let commonTrigrams: [(String, String, String, Int)] = [
            // Very common phrases
            ("vielen", "dank", "für", 320), ("bitte", "schön", "gern", 240),
            ("wie", "geht", "es", 380), ("wie", "geht's", "dir", 350),
            ("es", "geht", "mir", 340), ("sehr", "gut", "danke", 300),

            // Verb constructions
            ("ich", "muss", "gehen", 280), ("ich", "kann", "helfen", 300),
            ("ich", "möchte", "fragen", 260), ("ich", "würde", "gern", 280),
            ("das", "ist", "gut", 320), ("das", "war", "toll", 240),

            // Questions
            ("wie", "heißt", "du", 300), ("wo", "ist", "das", 280),
            ("was", "ist", "das", 320), ("wann", "kommst", "du", 240),

            // Politeness
            ("bitte", "helfen", "sie", 220), ("können", "sie", "mir", 280),
            ("würden", "sie", "bitte", 240),

            // Time expressions
            ("nächste", "woche", "montag", 200), ("letzten", "monat", "war", 180),
            ("in", "ein", "paar", 220), ("vor", "zwei", "tagen", 200),
        ]

        for (word1, word2, word3, count) in commonTrigrams {
            let key = "\(word1)_\(word2)"
            data.trigrams[key, default: [:]][word3, default: 0] += count
        }
    }

    func loadItalianNGrams(into data: inout NGramData) {
        // Common Italian bigrams (word pairs)
        let commonBigrams: [(String, String, Int)] = [
            // Pronouns + verbs (essere/avere - to be/to have)
            ("io", "sono", 500), ("io", "ho", 450), ("io", "voglio", 400), ("io", "posso", 380),
            ("io", "devo", 360), ("io", "vado", 340), ("io", "faccio", 320), ("io", "so", 300),

            ("tu", "sei", 480), ("tu", "hai", 420), ("tu", "vuoi", 380), ("tu", "puoi", 360),
            ("tu", "devi", 340), ("tu", "vai", 320), ("tu", "fai", 300), ("tu", "sai", 280),

            ("lui", "è", 500), ("lui", "ha", 450), ("lui", "vuole", 380), ("lui", "può", 360),
            ("lei", "è", 490), ("lei", "ha", 440), ("lei", "vuole", 370), ("lei", "può", 350),

            ("noi", "siamo", 400), ("noi", "abbiamo", 380), ("noi", "vogliamo", 340),
            ("noi", "possiamo", 320), ("noi", "dobbiamo", 300), ("noi", "andiamo", 280),

            ("voi", "siete", 350), ("voi", "avete", 330), ("voi", "volete", 300),
            ("voi", "potete", 280), ("voi", "dovete", 260),

            ("loro", "sono", 420), ("loro", "hanno", 400), ("loro", "vogliono", 340),
            ("loro", "possono", 320), ("loro", "devono", 300),

            // Common phrases and greetings
            ("grazie", "mille", 600), ("prego", "di", 400), ("per", "favore", 580),
            ("mi", "scusi", 500), ("mi", "dispiace", 450), ("buon", "giorno", 550),
            ("buona", "sera", 500), ("buona", "notte", 480), ("a", "presto", 450),
            ("a", "dopo", 420), ("arrivederci", "e", 380), ("ciao", "come", 500),

            // Common question patterns
            ("come", "stai", 520), ("come", "va", 500), ("come", "ti", 400),
            ("cosa", "fai", 380), ("cosa", "vuoi", 350), ("cosa", "pensi", 300),
            ("dove", "sei", 350), ("dove", "vai", 340), ("dove", "abiti", 280),
            ("quando", "arrivi", 280), ("quando", "parti", 260), ("perché", "non", 350),
            ("chi", "è", 320), ("che", "cosa", 450), ("cosa", "succede", 300),

            // Preposition patterns
            ("a", "casa", 450), ("a", "scuola", 350), ("a", "lavoro", 380),
            ("in", "ufficio", 380), ("in", "città", 350), ("in", "italia", 320),
            ("con", "te", 400), ("con", "me", 420), ("con", "lui", 350),
            ("per", "me", 420), ("per", "te", 400), ("per", "favore", 500),
            ("da", "me", 350), ("da", "te", 340), ("da", "lui", 300),
            ("di", "più", 380), ("di", "meno", 320), ("di", "nuovo", 350),

            // Verb phrases (infinitive constructions)
            ("voglio", "dire", 380), ("voglio", "fare", 350), ("voglio", "andare", 340),
            ("posso", "aiutare", 380), ("posso", "fare", 350), ("posso", "venire", 320),
            ("devo", "andare", 400), ("devo", "fare", 380), ("devo", "dire", 320),
            ("vorrei", "sapere", 350), ("vorrei", "chiedere", 320), ("vorrei", "fare", 300),

            // Common adjective + noun
            ("buon", "appetito", 400), ("buona", "fortuna", 380), ("buona", "giornata", 420),
            ("bella", "giornata", 350), ("bel", "lavoro", 280), ("nuovo", "lavoro", 250),

            // Time expressions
            ("questa", "sera", 320), ("questa", "mattina", 350), ("questa", "settimana", 300),
            ("la", "prossima", 350), ("prossima", "settimana", 380), ("prossimo", "mese", 280),
            ("la", "scorsa", 300), ("scorsa", "settimana", 350), ("scorso", "anno", 280),
            ("ogni", "giorno", 300), ("tutti", "i", 350), ("i", "giorni", 320),

            // Business/polite phrases
            ("la", "ringrazio", 350), ("le", "chiedo", 300), ("mi", "permetta", 280),
            ("potrebbe", "dirmi", 280), ("potrebbe", "aiutarmi", 260),
            ("sarebbe", "possibile", 300), ("in", "attesa", 280), ("distinti", "saluti", 350),
            ("cordiali", "saluti", 400), ("in", "allegato", 320),

            // Expressions
            ("va", "bene", 500), ("non", "c'è", 450), ("c'è", "problema", 350),
            ("tutto", "bene", 420), ("tutto", "ok", 380), ("d'accordo", "va", 300),
            ("mi", "piace", 450), ("ti", "piace", 400), ("non", "so", 380),
            ("lo", "so", 350), ("penso", "che", 380), ("credo", "che", 360),
            ("sembra", "che", 320), ("è", "vero", 350), ("non", "è", 400),
            ("ce", "l'ho", 300), ("l'ho", "fatto", 280), ("l'ho", "visto", 260),
        ]

        for (word1, word2, count) in commonBigrams {
            data.bigrams[word1, default: [:]][word2, default: 0] += count
            data.unigrams[word1, default: 0] += count
            data.unigrams[word2, default: 0] += count
        }

        // Common Italian trigrams
        let commonTrigrams: [(String, String, String, Int)] = [
            // Very common phrases
            ("come", "stai", "tu", 400), ("come", "va", "oggi", 350),
            ("che", "cosa", "fai", 380), ("che", "cosa", "vuoi", 320),
            ("non", "lo", "so", 450), ("non", "c'è", "problema", 400),

            // Greetings and politeness
            ("grazie", "mille", "per", 350), ("per", "favore", "puoi", 280),
            ("mi", "fa", "piacere", 320), ("piacere", "di", "conoscerti", 280),
            ("è", "un", "piacere", 300), ("mi", "scusi", "per", 280),

            // Pronouns + verb phrases
            ("io", "voglio", "dire", 300), ("io", "devo", "andare", 320),
            ("io", "posso", "aiutare", 280), ("io", "non", "so", 350),
            ("io", "non", "posso", 320), ("io", "non", "voglio", 280),
            ("tu", "puoi", "fare", 280), ("tu", "devi", "fare", 260),

            // Questions
            ("come", "ti", "chiami", 350), ("dove", "sei", "stato", 280),
            ("cosa", "stai", "facendo", 300), ("quando", "ci", "vediamo", 280),
            ("perché", "non", "vieni", 260), ("chi", "è", "questo", 250),

            // Time expressions
            ("la", "prossima", "settimana", 320), ("la", "scorsa", "settimana", 280),
            ("tutti", "i", "giorni", 300), ("una", "volta", "alla", 220),
            ("volta", "alla", "settimana", 250), ("il", "prossimo", "mese", 240),

            // Common sentence patterns
            ("va", "tutto", "bene", 380), ("è", "tutto", "ok", 320),
            ("non", "è", "vero", 300), ("penso", "che", "sia", 280),
            ("credo", "che", "tu", 260), ("sembra", "che", "sia", 240),
            ("è", "possibile", "che", 280), ("bisogna", "che", "tu", 220),

            // Business/formal
            ("in", "attesa", "di", 280), ("attesa", "di", "riscontro", 260),
            ("cordiali", "saluti", "e", 300), ("distinti", "saluti", "e", 280),
            ("la", "ringrazio", "per", 280), ("in", "allegato", "troverà", 220),

            // Expressions
            ("mi", "piace", "molto", 350), ("ti", "voglio", "bene", 400),
            ("ce", "l'ho", "fatta", 280), ("non", "ne", "ho", 260),
            ("me", "lo", "dici", 220), ("te", "lo", "dico", 220),
            ("ci", "vediamo", "dopo", 300), ("ci", "sentiamo", "presto", 280),
        ]

        for (word1, word2, word3, count) in commonTrigrams {
            let key = "\(word1)_\(word2)"
            data.trigrams[key, default: [:]][word3, default: 0] += count
        }
    }

    // MARK: - Chinese N-Grams

    /// Load Chinese character n-grams
    /// NOTE: Chinese uses character-based n-grams (each character is like a "word")
    /// No spaces between characters - patterns are based on character sequences
    func loadChineseNGrams(into data: inout NGramData) {
        // Common Chinese bigrams (character pairs)
        // These are high-frequency two-character combinations
        let commonBigrams: [(String, String, Int)] = [
            // Pronouns + verbs
            ("我", "是", 600), ("我", "要", 550), ("我", "想", 520), ("我", "会", 480),
            ("我", "能", 460), ("我", "可", 440), ("我", "在", 500), ("我", "有", 480),
            ("我", "没", 420), ("我", "不", 550), ("我", "去", 400), ("我", "来", 380),
            ("我", "看", 360), ("我", "说", 380), ("我", "知", 400), ("我", "觉", 380),
            ("我", "喜", 350), ("我", "爱", 340),

            ("你", "好", 700), ("你", "是", 550), ("你", "要", 450), ("你", "想", 430),
            ("你", "能", 400), ("你", "可", 420), ("你", "在", 440), ("你", "有", 420),
            ("你", "去", 350), ("你", "来", 340), ("你", "看", 330), ("你", "说", 340),
            ("你", "知", 360), ("你", "觉", 340),

            ("他", "是", 500), ("他", "要", 400), ("他", "会", 380), ("他", "在", 420),
            ("他", "有", 400), ("他", "说", 380), ("他", "们", 550),
            ("她", "是", 490), ("她", "要", 390), ("她", "会", 370), ("她", "在", 410),
            ("她", "有", 390), ("她", "说", 370), ("她", "们", 450),

            ("我", "们", 600), ("你", "们", 500), ("这", "个", 580), ("那", "个", 520),

            // Common greetings and phrases
            ("谢", "谢", 650), ("对", "不", 500), ("不", "起", 480),
            ("没", "关", 450), ("关", "系", 480), ("不", "客", 420), ("客", "气", 450),
            ("请", "问", 480), ("再", "见", 550), ("早", "上", 400),
            ("晚", "上", 420), ("中", "午", 380),

            // Question words
            ("什", "么", 600), ("怎", "么", 580), ("为", "什", 500),
            ("哪", "里", 480), ("哪", "个", 450), ("多", "少", 440),
            ("什", "时", 420), ("时", "候", 480),

            // Common verbs and verb phrases
            ("可", "以", 600), ("不", "是", 550), ("不", "要", 480), ("不", "能", 460),
            ("不", "会", 450), ("不", "知", 420), ("不", "想", 400),
            ("会", "不", 380), ("是", "不", 400), ("能", "不", 360),
            ("知", "道", 580), ("觉", "得", 520), ("喜", "欢", 500), ("需", "要", 480),
            ("应", "该", 460), ("可", "能", 450), ("已", "经", 480),
            ("正", "在", 450), ("一", "起", 440), ("一", "下", 460),
            ("出", "来", 400), ("进", "去", 380), ("回", "来", 420), ("回", "去", 400),

            // Common nouns and noun phrases
            ("时", "间", 500), ("地", "方", 480), ("东", "西", 450), ("事", "情", 480),
            ("问", "题", 500), ("工", "作", 520), ("学", "习", 480), ("生", "活", 460),
            ("朋", "友", 500), ("家", "人", 450), ("公", "司", 480), ("学", "校", 460),
            ("医", "院", 400), ("电", "话", 480), ("手", "机", 520), ("电", "脑", 450),
            ("网", "络", 420), ("中", "国", 550), ("今", "天", 520), ("明", "天", 500),
            ("昨", "天", 480),

            // Numbers and time
            ("一", "个", 550), ("两", "个", 480), ("三", "个", 400),
            ("几", "个", 420), ("这", "些", 450), ("那", "些", 400),
            ("现", "在", 550), ("以", "后", 480), ("以", "前", 460),

            // Conjunctions and connectors
            ("但", "是", 500), ("因", "为", 520), ("所", "以", 500),
            ("如", "果", 480), ("虽", "然", 420), ("而", "且", 400),
            ("还", "是", 480), ("或", "者", 420), ("然", "后", 480),

            // Prepositions and particles
            ("对", "于", 400), ("关", "于", 420), ("为", "了", 480),
            ("比", "较", 400), ("非", "常", 450), ("特", "别", 420),
        ]

        for (char1, char2, count) in commonBigrams {
            data.bigrams[char1, default: [:]][char2, default: 0] += count
            data.unigrams[char1, default: 0] += count
            data.unigrams[char2, default: 0] += count
        }

        // Common Chinese trigrams (three-character combinations)
        let commonTrigrams: [(String, String, String, Int)] = [
            // Greetings and polite phrases
            ("你", "好", "吗", 500), ("谢", "谢", "你", 480), ("不", "客", "气", 450),
            ("对", "不", "起", 480), ("没", "关", "系", 460), ("没", "问", "题", 440),

            // Question patterns
            ("什", "么", "时", 400), ("么", "时", "候", 420),
            ("怎", "么", "样", 450), ("怎", "么", "办", 380),
            ("为", "什", "么", 500), ("在", "哪", "里", 380),
            ("是", "什", "么", 420), ("多", "少", "钱", 350),

            // Common phrases
            ("可", "以", "吗", 400), ("好", "不", "好", 380),
            ("是", "不", "是", 420), ("能", "不", "能", 380),
            ("会", "不", "会", 360), ("要", "不", "要", 340),

            // Verb phrases
            ("不", "知", "道", 450), ("我", "觉", "得", 420),
            ("我", "喜", "欢", 400), ("我", "需", "要", 380),
            ("我", "可", "以", 400), ("你", "可", "以", 380),
            ("我", "想", "要", 360), ("应", "该", "是", 340),

            // Time expressions
            ("现", "在", "是", 350), ("已", "经", "是", 320),
            ("以", "后", "会", 300), ("以", "前", "是", 280),
            ("明", "天", "会", 320), ("今", "天", "是", 340),

            // Common sentence patterns
            ("这", "个", "是", 380), ("那", "个", "是", 350),
            ("我", "们", "是", 360), ("你", "们", "是", 320),
            ("他", "们", "是", 340), ("她", "们", "是", 300),
        ]

        for (char1, char2, char3, count) in commonTrigrams {
            let key = "\(char1)_\(char2)"
            data.trigrams[key, default: [:]][char3, default: 0] += count
        }

        // Add common single character unigrams for fallback
        let commonUnigrams: [(String, Int)] = [
            ("的", 1000), ("是", 800), ("不", 750), ("我", 700), ("有", 650),
            ("他", 600), ("这", 580), ("中", 560), ("大", 540), ("来", 520),
            ("上", 500), ("个", 480), ("国", 460), ("和", 440), ("主", 420),
            ("说", 400), ("在", 600), ("地", 380), ("一", 550), ("要", 450),
            ("就", 420), ("出", 400), ("会", 500), ("可", 480), ("她", 450),
            ("你", 650), ("对", 380), ("生", 360), ("能", 450), ("子", 340),
            ("那", 400), ("得", 380), ("于", 320), ("着", 350), ("下", 340),
            ("自", 320), ("之", 300), ("年", 350), ("过", 330), ("发", 310),
            ("后", 340), ("作", 320), ("里", 300), ("用", 310), ("道", 290),
            ("行", 280), ("所", 280), ("然", 270), ("家", 320), ("种", 260),
            ("事", 300), ("成", 280), ("方", 290), ("多", 300), ("经", 270),
            ("么", 350), ("同", 250), ("现", 280), ("当", 260), ("没", 350),
            ("动", 240), ("面", 250), ("起", 260), ("看", 300), ("定", 230),
            ("天", 320), ("分", 240), ("还", 300), ("进", 230), ("好", 350),
            ("小", 280), ("部", 220), ("其", 210), ("些", 250), ("时", 350),
        ]

        for (char, count) in commonUnigrams {
            data.unigrams[char, default: 0] += count
        }
    }

    // MARK: - Egyptian Arabic N-Grams

    /// Load Egyptian Arabic (arz) n-grams for colloquial Egyptian dialect
    /// Call this method to add Egyptian Arabic support: loadEgyptianArabicNGrams(into: &data)
    /// Note: This is NOT automatically loaded in initialize() - call manually when needed
    func loadEgyptianArabicNGrams(into data: inout NGramData) {
        // Common Egyptian Arabic bigrams (word pairs) - COLLOQUIAL dialect
        let commonBigrams: [(String, String, Int)] = [
            // ==========================================
            // PRONOUNS + VERBS (Egyptian Forms)
            // ==========================================
            // أنا (I) patterns
            ("انا", "عايز", 500),      // I want (masc)
            ("انا", "عايزة", 480),     // I want (fem)
            ("انا", "عندي", 450),      // I have
            ("انا", "بحب", 420),       // I love
            ("انا", "مش", 400),        // I'm not
            ("انا", "رايح", 380),      // I'm going (masc)
            ("انا", "رايحة", 370),     // I'm going (fem)
            ("انا", "فاهم", 350),      // I understand (masc)
            ("انا", "فاهمة", 340),     // I understand (fem)
            ("انا", "كويس", 420),      // I'm fine (masc)
            ("انا", "كويسة", 410),     // I'm fine (fem)
            ("انا", "تعبان", 300),     // I'm tired (masc)
            ("انا", "تعبانة", 290),    // I'm tired (fem)
            ("انا", "جعان", 280),      // I'm hungry (masc)
            ("انا", "جعانة", 270),     // I'm hungry (fem)

            // انت/انتي (you) patterns
            ("انت", "عاوز", 450),      // you want (masc)
            ("انتي", "عايزة", 440),    // you want (fem)
            ("انت", "فين", 420),       // where are you (masc)
            ("انتي", "فين", 410),      // where are you (fem)
            ("انت", "رايح", 380),      // you're going (masc)
            ("انتي", "رايحة", 370),    // you're going (fem)
            ("انت", "عامل", 500),      // how are you doing (masc)
            ("انتي", "عاملة", 490),    // how are you doing (fem)
            ("انت", "كويس", 400),      // you're fine (masc)
            ("انتي", "كويسة", 390),    // you're fine (fem)

            // هو/هي (he/she) patterns
            ("هو", "بيحب", 400),       // he loves
            ("هو", "عايز", 380),       // he wants
            ("هو", "راح", 350),        // he went
            ("هو", "جه", 340),         // he came
            ("هو", "قال", 320),        // he said
            ("هي", "بتحب", 390),       // she loves
            ("هي", "عايزة", 370),      // she wants
            ("هي", "راحت", 340),       // she went
            ("هي", "جت", 330),         // she came
            ("هي", "قالت", 310),       // she said

            // احنا (we) patterns
            ("احنا", "عندنا", 400),    // we have
            ("احنا", "رايحين", 380),   // we're going
            ("احنا", "بنحب", 350),     // we love
            ("احنا", "عايزين", 340),   // we want
            ("احنا", "مستنيين", 300),  // we're waiting

            // هم (they) patterns
            ("هم", "بيحبوا", 350),     // they love
            ("هم", "راحوا", 320),      // they went
            ("هم", "عايزين", 310),     // they want
            ("هم", "جم", 300),         // they came

            // ==========================================
            // GREETINGS AND COMMON PHRASES
            // ==========================================
            ("ازيك", "عامل", 550),     // how are you, how are you doing
            ("ازيك", "انت", 480),      // how are you
            ("ازاي", "النهاردة", 350), // how's today
            ("عامل", "ايه", 600),      // how are you doing
            ("عاملة", "ايه", 580),     // how are you doing (fem)
            ("تمام", "الحمدلله", 500), // fine, praise God
            ("كويس", "الحمدلله", 480), // good, praise God
            ("الحمد", "لله", 550),     // praise be to God
            ("ان", "شاء", 520),        // God willing
            ("شاء", "الله", 510),      // God willing (continued)
            ("صباح", "الخير", 500),    // good morning
            ("صباح", "النور", 480),    // response to good morning
            ("مساء", "الخير", 490),    // good evening
            ("مساء", "النور", 470),    // response to good evening
            ("ليلة", "سعيدة", 400),    // good night
            ("تصبح", "على", 380),      // good night (lit: wake up to)

            // ==========================================
            // COMMON EXPRESSIONS
            // ==========================================
            ("يلا", "نروح", 450),      // let's go
            ("يلا", "بينا", 430),      // let's go (together)
            ("يلا", "بسرعة", 350),     // hurry up
            ("ماشي", "تمام", 400),     // okay, fine
            ("اوكي", "ماشي", 380),     // okay, alright
            ("مش", "فاهم", 420),       // I don't understand (masc)
            ("مش", "فاهمة", 410),      // I don't understand (fem)
            ("مش", "عارف", 400),       // I don't know (masc)
            ("مش", "عارفة", 390),      // I don't know (fem)
            ("مش", "كده", 350),        // not like this
            ("معلش", "اسف", 380),      // sorry, excuse me
            ("على", "فكرة", 420),      // by the way
            ("يا", "ريت", 400),        // I wish
            ("لو", "سمحت", 450),       // please/excuse me (masc)
            ("لو", "سمحتي", 440),      // please/excuse me (fem)
            ("شكرا", "جزيلا", 420),    // thank you very much
            ("شكرا", "ليك", 400),      // thank you (to masc)
            ("شكرا", "ليكي", 390),     // thank you (to fem)
            ("عفوا", "يا", 350),       // you're welcome
            ("الله", "يخليك", 380),    // may God keep you

            // ==========================================
            // DEMONSTRATIVES (Egyptian specific)
            // ==========================================
            ("ده", "ايه", 420),        // what is this
            ("ده", "حلو", 350),        // this is nice
            ("ده", "كويس", 340),       // this is good
            ("دي", "حاجة", 380),       // this is something
            ("دي", "حلوة", 340),       // this is nice (fem)
            ("دول", "ناس", 300),       // these are people
            ("كده", "صح", 350),        // like this, right?
            ("كده", "كويس", 340),      // like this is good

            // ==========================================
            // QUESTION PATTERNS
            // ==========================================
            ("فين", "ده", 400),        // where is this
            ("فين", "انت", 380),       // where are you
            ("امتى", "هتيجي", 350),    // when will you come
            ("امتى", "رايح", 320),     // when are you going
            ("ليه", "كده", 400),       // why like this
            ("ليه", "مش", 380),        // why not
            ("ازاي", "كده", 350),      // how so
            ("ازاي", "اعمل", 320),     // how do I do
            ("مين", "ده", 380),        // who is this
            ("مين", "معاك", 350),      // who's with you
            ("ايه", "ده", 450),        // what is this
            ("ايه", "رايك", 420),      // what's your opinion

            // ==========================================
            // TITLES AND ADDRESSES
            // ==========================================
            ("يا", "باشا", 450),       // ya basha (friendly)
            ("يا", "معلم", 430),       // ya m3alem (boss/master)
            ("يا", "ريس", 420),        // ya rayes (boss)
            ("يا", "عم", 400),         // ya 3am (uncle - respectful)
            ("يا", "ابني", 380),       // ya ebny (my son)
            ("يا", "بنتي", 370),       // ya benty (my daughter)
            ("يا", "حبيبي", 500),      // ya 7abibi (my love - masc)
            ("يا", "حبيبتي", 490),     // ya 7abibty (my love - fem)
            ("يا", "صاحبي", 380),      // ya sa7by (my friend)

            // ==========================================
            // LOCATION AND TIME
            // ==========================================
            ("في", "البيت", 450),      // at home
            ("في", "الشغل", 430),      // at work
            ("في", "المول", 350),      // at the mall
            ("من", "هنا", 400),        // from here
            ("لحد", "هنا", 380),       // until here
            ("النهاردة", "الصبح", 350),// today morning
            ("بكره", "الصبح", 340),    // tomorrow morning
            ("امبارح", "بليل", 320),   // yesterday night
            ("كل", "سنة", 450),        // every year (birthday wish)
            ("سنة", "وانت", 440),      // and you (birthday response)

            // ==========================================
            // INTERNET/MODERN SLANG
            // ==========================================
            ("ههه", "ايوة", 300),      // haha yes
            ("لول", "ده", 280),        // lol this
            ("حلو", "اوي", 400),       // very nice
            ("جامد", "جدا", 380),      // very cool
            ("تحفة", "اوي", 350),      // amazing
        ]

        for (word1, word2, count) in commonBigrams {
            data.bigrams[word1, default: [:]][word2, default: 0] += count
            data.unigrams[word1, default: 0] += count
            data.unigrams[word2, default: 0] += count
        }

        // Common Egyptian Arabic trigrams
        let commonTrigrams: [(String, String, String, Int)] = [
            // Very common greetings/phrases
            ("ازيك", "عامل", "ايه", 500),           // how are you doing
            ("انا", "كويس", "الحمدلله", 450),       // I'm fine, praise God
            ("تمام", "الحمد", "لله", 430),          // fine, praise be to God
            ("يلا", "نروح", "بقى", 380),            // let's go already
            ("على", "خير", "ان", 350),              // good, God willing
            ("ان", "شاء", "الله", 500),             // God willing

            // Pronouns + verb + object
            ("انا", "عايز", "اروح", 400),           // I want to go
            ("انا", "مش", "فاهم", 420),             // I don't understand
            ("انا", "مش", "عارف", 400),             // I don't know
            ("هو", "بيحب", "ده", 350),              // he loves this
            ("هي", "عايزة", "تروح", 340),           // she wants to go
            ("احنا", "رايحين", "فين", 320),         // where are we going

            // Questions
            ("ايه", "ده", "يا", 380),               // what is this, oh
            ("فين", "انت", "رايح", 360),            // where are you going
            ("امتى", "هتيجي", "هنا", 320),          // when will you come here
            ("ليه", "عملت", "كده", 340),            // why did you do this
            ("مين", "ده", "اللي", 300),             // who is this who

            // Common responses
            ("مفيش", "حاجة", "خالص", 350),          // nothing at all
            ("مش", "عارف", "والله", 340),           // I don't know, by God
            ("كله", "تمام", "الحمدلله", 380),       // everything's fine, praise God
            ("معلش", "مش", "قصدي", 320),            // sorry, I didn't mean it

            // Birthday/occasions
            ("كل", "سنة", "وانت", 450),             // every year and you (birthday)
            ("سنة", "وانت", "طيب", 440),            // and you well (birthday response)

            // Time expressions
            ("من", "شوية", "كده", 300),             // a little while ago
            ("بعد", "شوية", "كده", 290),            // in a little while
            ("من", "زمان", "اوي", 280),             // a very long time ago

            // Expressions
            ("يا", "ريت", "كنت", 350),              // I wish I was
            ("لو", "سمحت", "ممكن", 380),            // please, could you
            ("على", "فكرة", "انا", 340),            // by the way, I
            ("ربنا", "يخليك", "لي", 320),           // may God keep you for me
            ("الله", "يباركلك", "يا", 300),         // may God bless you

            // Modern/casual
            ("حلو", "اوي", "والله", 320),           // very nice, by God
            ("جامد", "جدا", "ده", 300),             // this is very cool
            ("تحفة", "بجد", "يعني", 280),           // really amazing, I mean
        ]

        for (word1, word2, word3, count) in commonTrigrams {
            let key = "\(word1)_\(word2)"
            data.trigrams[key, default: [:]][word3, default: 0] += count
        }
    }

    // MARK: - Portuguese N-Grams

    /// Load Portuguese n-grams into the provided NGramData structure
    /// Call this method to add Portuguese language support to the predictor
    func loadPortugueseNGrams(into data: inout NGramData) {
        // Common Portuguese bigrams (word pairs)
        let commonBigrams: [(String, String, Int)] = [
            // ==========================================
            // PRONOUNS + VERBS (ser/estar/ter - to be/to have)
            // ==========================================

            // eu (I)
            ("eu", "sou", 500), ("eu", "estou", 480), ("eu", "tenho", 450), ("eu", "vou", 420),
            ("eu", "quero", 400), ("eu", "posso", 380), ("eu", "preciso", 360), ("eu", "sei", 340),
            ("eu", "faço", 320), ("eu", "acho", 300), ("eu", "gosto", 350), ("eu", "amo", 280),
            ("eu", "estava", 260), ("eu", "fui", 250), ("eu", "tinha", 240),

            // você (you - informal/Brazilian)
            ("você", "é", 480), ("você", "está", 460), ("você", "tem", 440), ("você", "vai", 400),
            ("você", "quer", 380), ("você", "pode", 360), ("você", "sabe", 340), ("você", "faz", 320),
            ("você", "gosta", 300), ("você", "precisa", 280),

            // ele/ela (he/she)
            ("ele", "é", 450), ("ele", "está", 430), ("ele", "tem", 400), ("ele", "vai", 380),
            ("ele", "foi", 350), ("ele", "fez", 320), ("ele", "disse", 300), ("ele", "sabe", 280),
            ("ela", "é", 440), ("ela", "está", 420), ("ela", "tem", 390), ("ela", "vai", 370),
            ("ela", "foi", 340), ("ela", "fez", 310), ("ela", "disse", 290), ("ela", "sabe", 270),

            // nós (we)
            ("nós", "somos", 380), ("nós", "estamos", 360), ("nós", "temos", 340), ("nós", "vamos", 350),
            ("nós", "podemos", 300), ("nós", "precisamos", 280), ("nós", "queremos", 260),

            // eles/elas (they)
            ("eles", "são", 350), ("eles", "estão", 330), ("eles", "têm", 310), ("eles", "vão", 290),
            ("eles", "foram", 270), ("eles", "fizeram", 250),
            ("elas", "são", 340), ("elas", "estão", 320), ("elas", "têm", 300), ("elas", "vão", 280),

            // ==========================================
            // COMMON GREETINGS AND PHRASES
            // ==========================================

            ("muito", "obrigado", 600), ("muito", "obrigada", 580), ("muito", "bem", 550),
            ("muito", "bom", 500), ("muito", "legal", 400), ("muito", "prazer", 450),
            ("por", "favor", 580), ("de", "nada", 550), ("com", "licença", 500),
            ("bom", "dia", 550), ("boa", "tarde", 520), ("boa", "noite", 530),
            ("até", "logo", 480), ("até", "mais", 460), ("até", "amanhã", 440),
            ("tudo", "bem", 550), ("tudo", "bom", 400), ("tudo", "certo", 380),
            ("como", "vai", 480), ("como", "está", 500), ("como", "você", 450),
            ("oi", "tudo", 400), ("olá", "como", 380),

            // ==========================================
            // PREPOSITION PATTERNS
            // ==========================================

            ("em", "casa", 450), ("em", "frente", 350), ("em", "cima", 320),
            ("no", "trabalho", 420), ("no", "escritório", 380), ("no", "Brasil", 400),
            ("na", "escola", 380), ("na", "cidade", 360), ("na", "rua", 340),
            ("com", "você", 450), ("com", "ele", 380), ("com", "ela", 370),
            ("com", "certeza", 420), ("com", "prazer", 350),
            ("para", "mim", 400), ("para", "você", 450), ("para", "ele", 360),
            ("para", "ela", 350), ("para", "casa", 380), ("para", "cá", 320),
            ("de", "manhã", 350), ("de", "tarde", 330), ("de", "noite", 340),
            ("de", "novo", 380), ("de", "acordo", 420), ("de", "nada", 550),
            ("por", "isso", 400), ("por", "causa", 350), ("por", "quê", 380),

            // ==========================================
            // VERB PHRASES
            // ==========================================

            ("quero", "dizer", 380), ("quero", "saber", 350), ("quero", "ir", 340),
            ("posso", "ajudar", 400), ("posso", "fazer", 360), ("posso", "ir", 320),
            ("preciso", "de", 420), ("preciso", "ir", 380), ("preciso", "fazer", 340),
            ("tenho", "que", 450), ("tenho", "de", 380),
            ("vou", "fazer", 400), ("vou", "lá", 350), ("vou", "embora", 320),
            ("pode", "ser", 420), ("pode", "fazer", 350),
            ("tem", "que", 430), ("tem", "de", 350),
            ("está", "bem", 480), ("está", "tudo", 420), ("está", "certo", 380),
            ("é", "verdade", 380), ("é", "isso", 400), ("é", "mesmo", 350),
            ("foi", "bom", 320), ("foi", "ótimo", 300),

            // ==========================================
            // QUESTION PATTERNS
            // ==========================================

            ("o", "que", 500), ("o", "quê", 400),
            ("que", "horas", 380), ("que", "dia", 350),
            ("como", "assim", 350), ("como", "é", 380),
            ("onde", "está", 380), ("onde", "fica", 350), ("onde", "você", 320),
            ("quando", "você", 300), ("quando", "vai", 280),
            ("por", "que", 450), ("por", "quê", 400),
            ("quem", "é", 350), ("quem", "foi", 300),
            ("qual", "é", 400), ("qual", "foi", 320),
            ("você", "pode", 380), ("você", "quer", 400), ("você", "sabe", 350),

            // ==========================================
            // TIME EXPRESSIONS
            // ==========================================

            ("esta", "manhã", 300), ("esta", "tarde", 280), ("esta", "noite", 290),
            ("esta", "semana", 320), ("este", "mês", 280), ("este", "ano", 300),
            ("semana", "passada", 320), ("semana", "que", 350),
            ("mês", "passado", 280), ("ano", "passado", 300),
            ("próxima", "semana", 350), ("próximo", "mês", 300), ("próximo", "ano", 280),
            ("todos", "os", 350), ("os", "dias", 380),
            ("às", "vezes", 350), ("de", "vez", 300),

            // ==========================================
            // MESSAGING/INFORMAL
            // ==========================================

            ("tô", "aqui", 280), ("tô", "bem", 260),
            ("tá", "bom", 350), ("tá", "bem", 380), ("tá", "certo", 320),
            ("já", "sei", 300), ("já", "foi", 280), ("já", "está", 320),
            ("ainda", "não", 380), ("ainda", "está", 320),
            ("claro", "que", 350),

            // ==========================================
            // BUSINESS/FORMAL
            // ==========================================

            ("prezado", "senhor", 280), ("prezada", "senhora", 270),
            ("cordiais", "saudações", 250), ("atenciosamente", ".", 300),
            ("em", "anexo", 350), ("conforme", "solicitado", 280),
            ("segue", "em", 300), ("gostaria", "de", 350),
            ("venho", "por", 280),
        ]

        for (word1, word2, count) in commonBigrams {
            data.bigrams[word1, default: [:]][word2, default: 0] += count
            data.unigrams[word1, default: 0] += count
            data.unigrams[word2, default: 0] += count
        }

        // Common Portuguese trigrams
        let commonTrigrams: [(String, String, String, Int)] = [
            // ==========================================
            // VERY COMMON PHRASES
            // ==========================================

            ("como", "você", "está", 400), ("como", "você", "vai", 350),
            ("o", "que", "você", 380), ("o", "que", "aconteceu", 300),
            ("eu", "não", "sei", 380), ("eu", "não", "posso", 320),
            ("eu", "não", "quero", 300), ("eu", "não", "tenho", 280),
            ("muito", "prazer", "em", 350), ("muito", "obrigado", "por", 400),
            ("tudo", "bem", "com", 350), ("tudo", "bem", "obrigado", 300),
            ("de", "nada", "foi", 250),

            // ==========================================
            // VERB CONSTRUCTIONS
            // ==========================================

            ("eu", "vou", "fazer", 320), ("eu", "vou", "lá", 280),
            ("eu", "quero", "saber", 300), ("eu", "quero", "ir", 280),
            ("eu", "preciso", "de", 350), ("eu", "preciso", "ir", 300),
            ("eu", "tenho", "que", 380), ("eu", "tenho", "de", 300),
            ("eu", "posso", "ajudar", 320), ("eu", "posso", "fazer", 280),
            ("você", "pode", "me", 320), ("você", "pode", "fazer", 280),
            ("você", "quer", "ir", 260), ("você", "quer", "saber", 250),
            ("nós", "vamos", "fazer", 280), ("nós", "podemos", "ir", 250),

            // ==========================================
            // QUESTION PATTERNS
            // ==========================================

            ("o", "que", "é", 350), ("o", "que", "foi", 320),
            ("o", "que", "aconteceu", 300), ("o", "que", "houve", 250),
            ("por", "que", "você", 300), ("por", "que", "não", 320),
            ("onde", "você", "está", 280), ("onde", "você", "mora", 250),
            ("quando", "você", "vai", 260), ("quando", "você", "pode", 240),
            ("como", "foi", "o", 280), ("como", "foi", "seu", 250),
            ("você", "sabe", "onde", 250), ("você", "sabe", "quando", 230),

            // ==========================================
            // POLITENESS PHRASES
            // ==========================================

            ("por", "favor", "me", 300), ("por", "favor", "ajude", 250),
            ("muito", "obrigado", "pela", 350), ("muito", "obrigada", "pela", 340),
            ("com", "licença", "posso", 280),
            ("gostaria", "de", "saber", 300), ("gostaria", "de", "pedir", 250),

            // ==========================================
            // TIME EXPRESSIONS
            // ==========================================

            ("semana", "que", "vem", 350), ("mês", "que", "vem", 300),
            ("ano", "que", "vem", 280),
            ("todos", "os", "dias", 350),
            ("de", "vez", "em", 300), ("vez", "em", "quando", 280),
            ("ao", "mesmo", "tempo", 250),
            ("o", "mais", "rápido", 220),

            // ==========================================
            // COMMON SENTENCE PATTERNS
            // ==========================================

            ("é", "por", "isso", 300), ("foi", "por", "isso", 250),
            ("não", "é", "verdade", 280), ("é", "mesmo", "assim", 250),
            ("acho", "que", "sim", 280), ("acho", "que", "não", 300),
            ("pode", "ser", "que", 280),
            ("tem", "que", "ser", 300), ("tem", "que", "fazer", 280),
            ("está", "tudo", "bem", 350),

            // ==========================================
            // BUSINESS/FORMAL
            // ==========================================

            ("venho", "por", "meio", 280), ("por", "meio", "desta", 250),
            ("conforme", "combinado", "segue", 220),
            ("em", "anexo", "segue", 280), ("segue", "em", "anexo", 300),
            ("fico", "à", "disposição", 280), ("à", "disposição", "para", 250),
            ("agradeço", "desde", "já", 280),
        ]

        for (word1, word2, word3, count) in commonTrigrams {
            let key = "\(word1)_\(word2)"
            data.trigrams[key, default: [:]][word3, default: 0] += count
        }
    }

    // MARK: - Arabic N-Grams (MSA/فصحى)

    /// Load Arabic n-grams for Modern Standard Arabic (MSA/فصحى)
    /// Call this method to add MSA support: loadArabicNGrams(into: &data)
    /// Note: Arabic is RTL but Swift strings handle this automatically
    func loadArabicNGrams(into data: inout NGramData) {
        // Common Arabic bigrams (word pairs) - MSA formal register
        let commonBigrams: [(String, String, Int)] = [
            // ==========================================
            // PRONOUNS + VERBS
            // ==========================================

            // أنا (I) + verbs
            ("أنا", "أريد", 500),      // I want
            ("أنا", "أستطيع", 450),    // I can
            ("أنا", "أعرف", 400),      // I know
            ("أنا", "أفهم", 380),      // I understand
            ("أنا", "أحب", 360),       // I love
            ("أنا", "أعتقد", 340),     // I believe
            ("أنا", "سعيد", 300),      // I am happy
            ("أنا", "آسف", 280),       // I am sorry
            ("أنا", "هنا", 320),       // I am here
            ("أنا", "موافق", 260),     // I agree

            // أنت (you - masc) + verbs
            ("أنت", "تستطيع", 450),    // you can
            ("أنت", "تريد", 400),      // you want
            ("أنت", "تعرف", 350),      // you know
            ("أنت", "محق", 300),       // you are right

            // هو (he) + verbs
            ("هو", "يمكن", 420),       // he can
            ("هو", "يريد", 380),       // he wants
            ("هو", "يعرف", 340),       // he knows
            ("هو", "هنا", 300),        // he is here

            // هي (she) + verbs
            ("هي", "تستطيع", 400),     // she can
            ("هي", "تريد", 360),       // she wants
            ("هي", "جميلة", 280),      // she is beautiful

            // نحن (we) + verbs
            ("نحن", "نحتاج", 450),     // we need
            ("نحن", "نريد", 420),      // we want
            ("نحن", "نستطيع", 400),    // we can
            ("نحن", "سعداء", 300),     // we are happy
            ("نحن", "هنا", 320),       // we are here

            // هم (they) + verbs
            ("هم", "يريدون", 380),     // they want
            ("هم", "يستطيعون", 340),   // they can

            // ==========================================
            // COMMON PHRASES AND GREETINGS
            // ==========================================

            // Greetings
            ("شكراً", "جزيلاً", 600),   // thank you very much
            ("شكراً", "لك", 550),       // thank you (to you)
            ("من", "فضلك", 580),        // please
            ("عفواً", "لا", 300),       // excuse me, no
            ("مع", "السلامة", 500),     // goodbye

            // Common expressions
            ("كيف", "حالك", 550),       // how are you
            ("ما", "اسمك", 400),        // what is your name
            ("أين", "أنت", 350),        // where are you
            ("متى", "ستأتي", 300),      // when will you come
            ("لماذا", "لا", 320),       // why not

            // Religious phrases
            ("إن", "شاء", 500),         // God willing (part 1)
            ("شاء", "الله", 500),       // God willing (part 2)
            ("الحمد", "لله", 550),      // praise be to God
            ("ما", "شاء", 400),         // as God willed (part 1)
            ("بارك", "الله", 380),      // may God bless

            // ==========================================
            // PREPOSITION PATTERNS
            // ==========================================

            // في (in)
            ("في", "البيت", 450),       // at home
            ("في", "العمل", 420),       // at work
            ("في", "المدرسة", 380),     // at school
            ("في", "الجامعة", 340),     // at university
            ("في", "المكتب", 320),      // in the office
            ("في", "السيارة", 280),     // in the car
            ("في", "الصباح", 350),      // in the morning
            ("في", "المساء", 320),      // in the evening

            // إلى (to)
            ("إلى", "البيت", 420),      // to home
            ("إلى", "العمل", 400),      // to work
            ("إلى", "المدرسة", 350),    // to school
            ("إلى", "هناك", 300),       // to there

            // من (from)
            ("من", "البيت", 380),       // from home
            ("من", "العمل", 350),       // from work
            ("من", "هنا", 320),         // from here

            // مع (with)
            ("مع", "الأصدقاء", 400),    // with friends
            ("مع", "العائلة", 380),     // with family
            ("مع", "الأسف", 350),       // unfortunately

            // على (on)
            ("على", "الطاولة", 320),    // on the table
            ("على", "حق", 380),         // you're right
            ("على", "الرحب", 300),      // welcome (part 1)

            // ==========================================
            // VERB PHRASES
            // ==========================================

            // أريد أن (I want to)
            ("أريد", "أن", 500),        // I want to
            ("يجب", "أن", 480),         // must (impersonal)
            ("يمكن", "أن", 450),        // it's possible to
            ("أحتاج", "إلى", 420),      // I need to
            ("أستطيع", "أن", 400),      // I can

            // يمكنني (I can)
            ("يمكنني", "المساعدة", 380),  // I can help
            ("يمكنني", "القيام", 340),    // I can do
            ("يمكنك", "أن", 360),         // you can

            // ==========================================
            // QUESTION PATTERNS
            // ==========================================

            ("هل", "يمكنك", 400),       // can you?
            ("هل", "تستطيع", 380),      // can you?
            ("هل", "أنت", 350),         // are you?
            ("هل", "هذا", 320),         // is this?
            ("ما", "هذا", 380),         // what is this?
            ("ما", "رأيك", 340),        // what do you think?
            ("كم", "الساعة", 300),      // what time is it?
            ("أين", "يوجد", 320),       // where is?

            // ==========================================
            // TIME EXPRESSIONS
            // ==========================================

            ("هذا", "اليوم", 380),      // today
            ("هذا", "الأسبوع", 320),    // this week
            ("هذا", "الشهر", 280),      // this month
            ("الأسبوع", "القادم", 350),  // next week
            ("الشهر", "القادم", 300),    // next month
            ("السنة", "القادمة", 280),   // next year
            ("الأسبوع", "الماضي", 320),  // last week
            ("يوم", "الجمعة", 300),      // Friday
            ("يوم", "السبت", 280),       // Saturday

            // ==========================================
            // BUSINESS/FORMAL PHRASES
            // ==========================================

            ("سيادة", "الرئيس", 250),    // Your Excellency the President
            ("حضرة", "السيد", 280),      // Dear Mr.
            ("المحترم", "تحية", 240),    // respected, greetings
            ("تحية", "طيبة", 350),       // kind greetings
            ("خالص", "التحية", 300),     // sincere greetings
            ("مع", "خالص", 280),         // with sincere
            ("تفضلوا", "بقبول", 220),    // please accept
            ("فائق", "الاحترام", 250),   // highest respect
        ]

        for (word1, word2, count) in commonBigrams {
            data.bigrams[word1, default: [:]][word2, default: 0] += count
            data.unigrams[word1, default: 0] += count
            data.unigrams[word2, default: 0] += count
        }

        // Common Arabic trigrams - MSA formal register
        let commonTrigrams: [(String, String, String, Int)] = [
            // ==========================================
            // VERY COMMON PHRASES
            // ==========================================

            // Greetings
            ("كيف", "حالك", "اليوم", 350),       // how are you today
            ("شكراً", "جزيلاً", "لك", 400),      // thank you very much (to you)
            ("على", "الرحب", "والسعة", 320),     // you're welcome

            // Religious phrases
            ("إن", "شاء", "الله", 500),          // God willing
            ("ما", "شاء", "الله", 450),          // as God willed
            ("بارك", "الله", "فيك", 380),        // may God bless you

            // ==========================================
            // PRONOUN + VERB PHRASES
            // ==========================================

            ("أريد", "أن", "أقول", 350),         // I want to say
            ("أريد", "أن", "أعرف", 320),         // I want to know
            ("أريد", "أن", "أسأل", 300),         // I want to ask
            ("يمكنني", "أن", "أساعد", 280),      // I can help
            ("يجب", "أن", "نذهب", 260),          // we must go
            ("يجب", "أن", "أقول", 250),          // I must say
            ("أحتاج", "إلى", "مساعدة", 280),     // I need help
            ("لا", "أستطيع", "أن", 300),         // I cannot

            // ==========================================
            // QUESTION PATTERNS
            // ==========================================

            ("هل", "يمكنك", "أن", 320),          // can you (+ verb)
            ("هل", "يمكنني", "أن", 280),         // can I (+ verb)
            ("ما", "هو", "رأيك", 300),           // what is your opinion
            ("ما", "هي", "المشكلة", 260),        // what is the problem
            ("أين", "يمكنني", "أن", 240),        // where can I

            // ==========================================
            // FORMAL/BUSINESS PHRASES
            // ==========================================

            ("تحية", "طيبة", "وبعد", 300),       // kind greetings, and then
            ("مع", "خالص", "التحية", 280),       // with sincere greetings
            ("مع", "فائق", "الاحترام", 250),     // with highest respect
            ("تفضلوا", "بقبول", "فائق", 220),    // please accept highest
            ("في", "انتظار", "ردكم", 200),       // awaiting your response
            ("أرجو", "أن", "تكون", 240),         // I hope you are
            ("يسعدني", "أن", "أبلغكم", 200),     // I am pleased to inform you

            // ==========================================
            // TIME EXPRESSIONS
            // ==========================================

            ("في", "هذا", "اليوم", 280),         // on this day
            ("في", "هذا", "الوقت", 260),         // at this time
            ("في", "الوقت", "الحالي", 240),      // at the current time
            ("إلى", "اللقاء", "قريباً", 220),    // see you soon

            // ==========================================
            // COMMON SENTENCE PATTERNS
            // ==========================================

            ("هذا", "هو", "السبب", 250),         // this is the reason
            ("هذه", "هي", "المشكلة", 230),       // this is the problem
            ("كما", "تعلم", "أن", 200),          // as you know that
            ("من", "الممكن", "أن", 280),         // it is possible that
            ("من", "الضروري", "أن", 240),        // it is necessary that
            ("لا", "بد", "أن", 260),             // it must be that
        ]

        for (word1, word2, word3, count) in commonTrigrams {
            let key = "\(word1)_\(word2)"
            data.trigrams[key, default: [:]][word3, default: 0] += count
        }
    }

    // MARK: - Japanese N-Grams

    /// Load Japanese n-grams into the provided data structure
    /// Japanese n-grams are word/phrase based, not character-based
    /// Includes common particles, verbs, adjectives, and polite forms
    func loadJapaneseNGrams(into data: inout NGramData) {
        // Common Japanese bigrams (word pairs)
        // Japanese uses particles between words, so n-grams often span word+particle or particle+verb
        let commonBigrams: [(String, String, Int)] = [
            // Pronouns + topic particle は
            ("私", "は", 500), ("私", "が", 450), ("私", "も", 350), ("私", "の", 400),
            ("あなた", "は", 420), ("あなた", "が", 350), ("あなた", "の", 380),
            ("彼", "は", 400), ("彼", "が", 350), ("彼", "の", 380),
            ("彼女", "は", 390), ("彼女", "が", 340), ("彼女", "の", 370),
            ("これ", "は", 480), ("これ", "が", 380), ("これ", "を", 350),
            ("それ", "は", 470), ("それ", "が", 370), ("それ", "を", 340),
            ("あれ", "は", 400), ("あれ", "が", 320), ("あれ", "を", 300),
            ("何", "が", 350), ("何", "を", 380), ("何", "で", 300),
            ("誰", "が", 320), ("誰", "に", 280), ("誰", "と", 260),
            ("どこ", "に", 350), ("どこ", "へ", 300), ("どこ", "で", 280),
            ("いつ", "に", 280), ("いつ", "まで", 260), ("いつ", "から", 240),

            // Copula です/だ patterns
            ("です", "か", 550), ("です", "ね", 480), ("です", "よ", 450),
            ("だ", "と", 400), ("だ", "から", 350), ("だ", "けど", 320),
            ("でした", "か", 350), ("でした", "ね", 300),

            // Verb endings ます patterns
            ("ます", "か", 500), ("ます", "ね", 420), ("ます", "よ", 400),
            ("ません", "か", 450), ("ません", "でした", 380),
            ("ました", "か", 350), ("ました", "ね", 300),

            // Common verb patterns
            ("し", "ます", 450), ("し", "ました", 400), ("し", "ません", 350),
            ("でき", "ます", 420), ("でき", "ません", 380), ("でき", "る", 350),
            ("あり", "ます", 480), ("あり", "ません", 400), ("あり", "がとう", 550),
            ("い", "ます", 400), ("い", "ません", 350),
            ("き", "ます", 380), ("き", "ました", 320),
            ("み", "ます", 350), ("み", "ました", 300),
            ("たべ", "ます", 350), ("たべ", "ました", 300),
            ("のみ", "ます", 320), ("のみ", "ました", 280),
            ("よみ", "ます", 300), ("よみ", "ました", 260),
            ("かき", "ます", 280), ("かき", "ました", 240),
            ("いき", "ます", 350), ("いき", "ました", 300),

            // Common expressions and greetings
            ("ありがとう", "ございます", 600),
            ("おはよう", "ございます", 550),
            ("こんにち", "は", 520), ("こんばん", "は", 480),
            ("すみ", "ません", 500),
            ("ごめん", "なさい", 450), ("ごめん", "ね", 380),
            ("よろしく", "お願い", 520),
            ("お願い", "します", 500), ("お願い", "いたします", 420),
            ("お疲れ", "様", 480), ("お疲れ", "さま", 450),
            ("いただき", "ます", 420),
            ("ごちそう", "さま", 380), ("ごちそう", "さまでした", 350),
            ("お元気", "ですか", 400),
            ("お久しぶり", "です", 350),
            ("はじめ", "まして", 380),
            ("失礼", "します", 350), ("失礼", "しました", 320),

            // Polite prefixes
            ("お", "願い", 450), ("お", "待ち", 380), ("お", "電話", 350),
            ("お", "名前", 320), ("お", "時間", 300), ("お", "仕事", 280),
            ("ご", "連絡", 380), ("ご", "確認", 350), ("ご", "質問", 320),
            ("ご", "返信", 300), ("ご", "検討", 280), ("ご", "協力", 260),

            // Question patterns
            ("何", "ですか", 450), ("どこ", "ですか", 400), ("いつ", "ですか", 380),
            ("誰", "ですか", 350), ("どう", "ですか", 420), ("なぜ", "ですか", 300),
            ("どの", "ように", 280), ("どんな", "ことが", 260),

            // Time expressions
            ("今日", "は", 400), ("明日", "は", 380), ("昨日", "は", 350),
            ("今週", "は", 320), ("来週", "は", 300), ("先週", "は", 280),
            ("今月", "は", 280), ("来月", "は", 260), ("先月", "は", 240),
            ("今年", "は", 260), ("来年", "は", 240), ("去年", "は", 220),
            ("毎日", "が", 280), ("毎週", "の", 250), ("毎月", "の", 230),

            // Location/direction patterns
            ("ここ", "に", 350), ("ここ", "で", 320), ("ここ", "から", 280),
            ("そこ", "に", 340), ("そこ", "で", 310), ("そこ", "へ", 280),
            ("あそこ", "に", 300), ("あそこ", "で", 270), ("あそこ", "へ", 250),
            ("家", "に", 350), ("家", "へ", 300), ("家", "で", 280),
            ("会社", "に", 380), ("会社", "へ", 320), ("会社", "で", 350),
            ("学校", "に", 350), ("学校", "へ", 300), ("学校", "で", 320),
            ("駅", "に", 320), ("駅", "へ", 280), ("駅", "で", 260),

            // Connector patterns
            ("と", "思います", 450), ("と", "思う", 400),
            ("と", "言います", 350), ("と", "言う", 320),
            ("けど", "も", 280), ("けれど", "も", 260),
            ("ので", "す", 320), ("から", "です", 350),
            ("でも", "いい", 300), ("でも", "大丈夫", 280),

            // Adjective patterns (い-adjectives)
            ("大きい", "です", 320), ("小さい", "です", 300),
            ("高い", "です", 280), ("安い", "です", 260),
            ("新しい", "です", 270), ("古い", "です", 250),
            ("良い", "です", 350), ("悪い", "です", 280),
            ("おいしい", "です", 350), ("まずい", "です", 200),
            ("楽しい", "です", 320), ("嬉しい", "です", 300),
            ("忙しい", "です", 350), ("暇", "です", 280),

            // Adjective patterns (な-adjectives)
            ("元気", "です", 400), ("大丈夫", "です", 450),
            ("静か", "です", 280), ("にぎやか", "です", 250),
            ("便利", "です", 300), ("不便", "です", 220),
            ("簡単", "です", 320), ("難しい", "です", 300),
            ("必要", "です", 350), ("大切", "です", 320),
            ("有名", "です", 280), ("きれい", "です", 350),

            // Business/formal expressions
            ("お世話", "になって", 380), ("お世話", "になります", 350),
            ("ご確認", "ください", 400), ("ご検討", "ください", 350),
            ("ご連絡", "ください", 380), ("ご返信", "ください", 320),
            ("させて", "いただきます", 350), ("させて", "いただき", 320),
            ("申し", "ます", 300), ("申し上げ", "ます", 280),
            ("存じ", "ます", 260), ("存じ上げ", "ます", 240),
        ]

        for (word1, word2, count) in commonBigrams {
            data.bigrams[word1, default: [:]][word2, default: 0] += count
            data.unigrams[word1, default: 0] += count
            data.unigrams[word2, default: 0] += count
        }

        // Common Japanese trigrams
        let commonTrigrams: [(String, String, String, Int)] = [
            // Greetings and common phrases
            ("ありがとう", "ござい", "ます", 600),
            ("おはよう", "ござい", "ます", 550),
            ("よろしく", "お願い", "します", 550),
            ("よろしく", "お願い", "いたします", 480),
            ("お疲れ", "様", "です", 450),
            ("お疲れ", "様", "でした", 420),
            ("お元気", "です", "か", 400),
            ("お久しぶり", "です", "ね", 350),
            ("はじめ", "まして", "よろしく", 350),

            // Polite expressions
            ("すみ", "ません", "が", 450),
            ("申し訳", "ござい", "ません", 400),
            ("申し訳", "あり", "ません", 380),
            ("失礼", "し", "ます", 350),
            ("お手数", "です", "が", 320),
            ("恐れ入り", "ます", "が", 300),
            ("ご確認", "いただけ", "ますか", 350),
            ("ご返信", "いただけ", "ますか", 320),
            ("お時間", "いただけ", "ますか", 300),

            // Common sentence patterns
            ("と", "思い", "ます", 450),
            ("と", "思って", "います", 420),
            ("と", "言って", "いました", 350),
            ("こと", "が", "できます", 400),
            ("こと", "が", "あります", 380),
            ("こと", "に", "なります", 350),
            ("ように", "し", "ます", 320),
            ("ように", "なり", "ます", 300),
            ("ため", "に", "は", 350),
            ("について", "は", "どう", 280),

            // Questions
            ("どう", "です", "か", 450),
            ("いかが", "です", "か", 420),
            ("何", "です", "か", 400),
            ("どこ", "です", "か", 380),
            ("いつ", "です", "か", 350),
            ("どの", "くらい", "ですか", 320),
            ("どう", "すれば", "いいですか", 350),
            ("何", "を", "しますか", 300),

            // Time-related
            ("今日", "は", "何", 300),
            ("明日", "は", "どう", 280),
            ("今週", "の", "予定", 260),
            ("来週", "の", "月曜日", 240),

            // Business expressions
            ("お世話", "になって", "おります", 400),
            ("ご確認", "の", "ほど", 350),
            ("ご検討", "の", "ほど", 320),
            ("何卒", "よろしく", "お願い", 380),
            ("引き続き", "よろしく", "お願い", 350),
            ("ご不明", "な", "点", 300),
            ("ご質問", "が", "ございましたら", 320),
            ("させて", "いただき", "ます", 350),
            ("させて", "いただければ", "幸いです", 320),

            // Casual expressions
            ("じゃあ", "また", "ね", 350),
            ("また", "後で", "ね", 300),
            ("ちょっと", "待って", "ね", 320),
            ("大丈夫", "です", "よ", 380),
            ("心配", "しない", "で", 300),
            ("分かり", "まし", "た", 400),
            ("了解", "し", "ました", 350),

            // Verb + auxiliary patterns
            ("して", "い", "ます", 450),
            ("して", "い", "ました", 400),
            ("して", "いただけ", "ますか", 380),
            ("して", "ください", "ませ", 350),
            ("でき", "れば", "と", 300),
            ("いただけ", "れば", "幸いです", 350),
            ("お待ち", "して", "おります", 320),

            // Reason/cause patterns
            ("なので", "す", "が", 350),
            ("ですので", "ご", "了承", 300),
            ("ため", "です", "ので", 280),

            // Desire/intention
            ("たい", "と", "思います", 400),
            ("ほしい", "と", "思います", 350),
            ("つもり", "です", "が", 320),
            ("予定", "です", "が", 300),
        ]

        for (word1, word2, word3, count) in commonTrigrams {
            let key = "\(word1)_\(word2)"
            data.trigrams[key, default: [:]][word3, default: 0] += count
        }

        // Additional high-frequency unigrams for Japanese
        let additionalUnigrams: [(String, Int)] = [
            // Common particles
            ("は", 1000), ("が", 900), ("を", 850), ("に", 800), ("で", 750),
            ("と", 700), ("の", 950), ("も", 600), ("から", 500), ("まで", 450),
            ("へ", 400), ("より", 350), ("など", 300), ("か", 550), ("ね", 500),
            ("よ", 480), ("な", 450), ("け", 200), ("さ", 180),

            // Common verbs (dictionary form)
            ("する", 600), ("いる", 550), ("ある", 580), ("なる", 500),
            ("できる", 450), ("行く", 400), ("来る", 380), ("見る", 350),
            ("言う", 340), ("思う", 450), ("知る", 320), ("分かる", 400),

            // Common adjectives
            ("いい", 450), ("良い", 400), ("悪い", 280), ("大きい", 300),
            ("小さい", 280), ("新しい", 290), ("古い", 250), ("高い", 300),
            ("安い", 280), ("多い", 320), ("少ない", 280),

            // Common nouns
            ("人", 500), ("時", 450), ("事", 480), ("物", 350), ("所", 320),
            ("方", 400), ("今", 420), ("日", 400), ("年", 350), ("月", 320),
            ("週", 280), ("仕事", 350), ("会社", 320), ("家", 380), ("名前", 280),
        ]

        for (word, count) in additionalUnigrams {
            data.unigrams[word, default: 0] += count
        }
    }

    // MARK: - Korean N-Grams

    /// Load Korean n-grams into the provided data structure
    /// Korean uses Hangul syllable blocks - each block is a syllable
    /// N-grams are based on word/particle combinations common in Korean
    func loadKoreanNGrams(into data: inout NGramData) {
        // Common Korean bigrams (word/phrase pairs)
        let commonBigrams: [(String, String, Int)] = [
            // ==========================================
            // PRONOUNS + TOPIC/SUBJECT PARTICLES
            // ==========================================
            // Topic marker 는/은
            ("저는", "학생입니다", 400), ("저는", "한국", 350), ("저는", "괜찮아요", 320),
            ("저는", "좋아요", 300), ("저는", "먹어요", 280), ("저는", "가요", 260),
            ("나는", "좋아", 450), ("나는", "갈래", 380), ("나는", "알아", 350),
            ("나는", "싫어", 320), ("나는", "할게", 300), ("나는", "먹을래", 280),

            ("그는", "학생입니다", 300), ("그는", "한국인입니다", 280), ("그는", "의사입니다", 260),
            ("그녀는", "선생님입니다", 290), ("그녀는", "학생입니다", 270), ("그녀는", "예쁩니다", 250),

            ("우리는", "갑니다", 350), ("우리는", "먹습니다", 320), ("우리는", "합니다", 300),
            ("우리는", "친구입니다", 280), ("우리는", "한국인입니다", 260),

            ("그것은", "좋습니다", 320), ("그것은", "맞습니다", 280), ("그것은", "아닙니다", 260),
            ("이것은", "뭐예요", 350), ("이것은", "제", 320), ("이것은", "책입니다", 280),

            // Subject marker 이/가
            ("제가", "할게요", 380), ("제가", "갈게요", 350), ("제가", "드릴게요", 320),
            ("제가", "하겠습니다", 300), ("제가", "전화할게요", 280),

            ("뭐가", "필요해요", 300), ("뭐가", "있어요", 280), ("뭐가", "좋아요", 260),
            ("누가", "왔어요", 320), ("누가", "했어요", 280), ("누가", "전화했어요", 260),

            // ==========================================
            // COMMON VERB ENDINGS (POLITE FORMS)
            // ==========================================
            // -ㅂ니다/습니다 (formal polite)
            ("감사", "합니다", 600), ("안녕", "하세요", 580), ("죄송", "합니다", 550),
            ("반갑", "습니다", 480), ("축하", "합니다", 450), ("실례", "합니다", 420),
            ("수고", "하셨습니다", 400), ("감사", "드립니다", 450),

            // -아요/어요 (informal polite)
            ("괜찮", "아요", 400), ("좋", "아요", 380), ("있", "어요", 420),
            ("없", "어요", 380), ("알", "아요", 350), ("몰", "라요", 320),
            ("해", "요", 450), ("가", "요", 420), ("와", "요", 380),
            ("먹", "어요", 350), ("마", "셔요", 320), ("주", "세요", 450),

            // -았/었어요 (past tense)
            ("했", "어요", 400), ("갔", "어요", 350), ("왔", "어요", 380),
            ("먹", "었어요", 320), ("봤", "어요", 340), ("만났", "어요", 280),

            // -ㄹ게요/을게요 (future promise)
            ("할", "게요", 400), ("갈", "게요", 350), ("볼", "게요", 320),
            ("전화", "할게요", 380), ("연락", "할게요", 350), ("확인", "할게요", 320),

            // ==========================================
            // COMMON GREETINGS AND PHRASES
            // ==========================================
            ("안녕", "하세요", 600), ("안녕히", "가세요", 550), ("안녕히", "계세요", 530),
            ("처음", "뵙겠습니다", 450), ("잘", "부탁드립니다", 480),
            ("오래", "만이에요", 400), ("만나서", "반갑습니다", 450),
            ("고맙", "습니다", 420), ("미안", "합니다", 400), ("미안", "해요", 380),
            ("천만", "에요", 350), ("별말", "씀을요", 320),

            // Farewells
            ("잘", "가요", 450), ("잘", "있어요", 400), ("또", "봐요", 380),
            ("다음에", "봐요", 350), ("좋은", "하루", 380), ("하루", "보내세요", 350),
            ("조심히", "가세요", 400), ("내일", "봐요", 350),

            // ==========================================
            // COMMON QUESTION PATTERNS
            // ==========================================
            ("어디", "가요", 380), ("어디", "있어요", 350), ("어디", "살아요", 320),
            ("뭐", "해요", 420), ("뭐", "먹어요", 380), ("뭐", "할까요", 350),
            ("언제", "와요", 350), ("언제", "가요", 320), ("언제", "만나요", 300),
            ("어떻게", "해요", 380), ("어떻게", "지내세요", 350), ("어떻게", "가요", 320),
            ("왜", "그래요", 350), ("왜", "안", 320), ("왜", "그랬어요", 280),
            ("얼마", "예요", 400), ("얼마나", "걸려요", 350), ("얼마나", "멀어요", 300),
            ("누구", "예요", 350), ("누구", "세요", 320), ("누구", "랑", 280),

            // ==========================================
            // COMMON EXPRESSIONS
            // ==========================================
            ("그래", "요", 400), ("네", "알겠습니다", 450), ("네", "그래요", 380),
            ("아", "그래요", 350), ("맞", "아요", 380), ("아니", "요", 420),
            ("정말", "요", 380), ("진짜", "요", 350), ("정말", "감사합니다", 400),

            ("잠깐", "만요", 350), ("잠시", "만요", 320), ("잠깐", "기다려주세요", 300),
            ("다시", "한번", 350), ("한번", "더", 320), ("한번", "해볼게요", 280),

            // Agreement/disagreement
            ("그럼", "요", 350), ("당연", "하죠", 320), ("물론", "이죠", 300),
            ("안", "돼요", 350), ("안", "할래요", 300), ("못", "해요", 320),

            // ==========================================
            // TIME EXPRESSIONS
            // ==========================================
            ("오늘", "뭐", 350), ("오늘", "저녁", 320), ("오늘", "아침", 300),
            ("내일", "봐요", 380), ("내일", "만나요", 350), ("내일", "할게요", 320),
            ("어제", "뭐", 280), ("어제", "했어요", 300), ("어제", "갔어요", 270),
            ("지금", "뭐", 350), ("지금", "가요", 320), ("지금", "바빠요", 300),
            ("나중에", "연락할게요", 350), ("나중에", "봐요", 320), ("나중에", "해요", 300),
            ("이번", "주", 350), ("다음", "주", 320), ("지난", "주", 300),
            ("이번", "달", 300), ("다음", "달", 280), ("지난", "달", 260),

            // ==========================================
            // LOCATIONS AND PLACES
            // ==========================================
            ("여기", "있어요", 350), ("여기", "앉으세요", 300), ("여기", "예요", 280),
            ("거기", "있어요", 320), ("거기", "가요", 300), ("거기", "에서", 280),
            ("저기", "봐요", 280), ("저기", "있어요", 260), ("저기", "요", 240),
            ("집에", "가요", 380), ("집에", "있어요", 350), ("회사에", "가요", 320),
            ("학교에", "가요", 320), ("식당에", "가요", 300), ("병원에", "가요", 280),

            // ==========================================
            // FOOD AND DINING
            // ==========================================
            ("맛있", "어요", 400), ("맛없", "어요", 280), ("배고프", "아요", 320),
            ("배불", "러요", 300), ("뭐", "드실래요", 350), ("뭐", "마실래요", 320),
            ("커피", "마실래요", 350), ("밥", "먹었어요", 380), ("점심", "먹었어요", 350),
            ("저녁", "먹을래요", 320), ("아침", "먹었어요", 300),

            // ==========================================
            // WORK AND BUSINESS
            // ==========================================
            ("회의", "있어요", 320), ("회의", "시작합니다", 280), ("일", "끝났어요", 350),
            ("출근", "했어요", 300), ("퇴근", "해요", 280), ("휴가", "가요", 260),
            ("메일", "보냈어요", 320), ("전화", "왔어요", 340), ("연락", "주세요", 380),
            ("확인", "부탁드립니다", 350), ("검토", "부탁드립니다", 320),
        ]

        for (word1, word2, count) in commonBigrams {
            data.bigrams[word1, default: [:]][word2, default: 0] += count
            data.unigrams[word1, default: 0] += count
            data.unigrams[word2, default: 0] += count
        }

        // Common Korean trigrams
        let commonTrigrams: [(String, String, String, Int)] = [
            // ==========================================
            // COMMON GREETINGS AND PHRASES
            // ==========================================
            ("안녕", "하세요", "처음", 300), ("처음", "뵙겠습니다", "잘", 280),
            ("잘", "부탁", "드립니다", 350), ("만나서", "반갑", "습니다", 320),
            ("오래", "만이에요", "어떻게", 280), ("어떻게", "지내", "세요", 300),

            // Thank you patterns
            ("정말", "감사", "합니다", 400), ("진심으로", "감사", "드립니다", 280),
            ("도와주셔서", "감사", "합니다", 320), ("와주셔서", "감사", "합니다", 300),

            // Apology patterns
            ("정말", "죄송", "합니다", 350), ("너무", "미안", "해요", 300),
            ("늦어서", "죄송", "합니다", 280), ("실례", "지만", "여쭤봐도", 260),

            // ==========================================
            // QUESTION PATTERNS
            // ==========================================
            ("이거", "뭐", "예요", 350), ("저거", "뭐", "예요", 300),
            ("지금", "뭐", "해요", 320), ("오늘", "뭐", "해요", 300),
            ("내일", "뭐", "할까요", 280), ("주말에", "뭐", "해요", 260),

            ("어디", "가", "세요", 320), ("어디", "있", "어요", 300),
            ("언제", "시간", "돼요", 280), ("언제", "만나", "요", 260),

            ("얼마나", "걸려", "요", 300), ("얼마", "예", "요", 320),
            ("어떻게", "하면", "돼요", 280), ("어떻게", "생각", "하세요", 260),

            // ==========================================
            // AFFIRMATIVE RESPONSES
            // ==========================================
            ("네", "알겠", "습니다", 400), ("네", "그래", "요", 350),
            ("네", "맞아", "요", 320), ("네", "좋아", "요", 300),
            ("물론", "이", "죠", 280), ("당연", "하", "죠", 260),
            ("그럼", "요", "좋아요", 250), ("알겠", "어", "요", 280),

            // ==========================================
            // NEGATIVE RESPONSES
            // ==========================================
            ("아니", "요", "괜찮아요", 300), ("아니", "요", "감사합니다", 280),
            ("아직", "안", "했어요", 280), ("아직", "안", "왔어요", 260),
            ("못", "해", "요", 280), ("안", "해", "요", 260),
            ("잘", "모르", "겠어요", 300), ("잘", "안", "돼요", 280),

            // ==========================================
            // POLITE REQUESTS
            // ==========================================
            ("잠깐만", "기다려", "주세요", 320), ("좀", "도와", "주세요", 300),
            ("다시", "말씀해", "주세요", 280), ("천천히", "말씀해", "주세요", 260),
            ("이거", "주", "세요", 320), ("저거", "주", "세요", 280),
            ("물", "좀", "주세요", 300), ("메뉴", "좀", "주세요", 280),

            // ==========================================
            // TIME-RELATED
            // ==========================================
            ("오늘", "저녁", "뭐해요", 280), ("내일", "시간", "있어요", 300),
            ("이번", "주", "바빠요", 260), ("다음", "주", "만나요", 280),
            ("지난", "주에", "했어요", 240), ("나중에", "다시", "연락할게요", 280),

            // ==========================================
            // EXPRESSIONS OF FEELING
            // ==========================================
            ("너무", "좋", "아요", 320), ("정말", "좋", "아요", 300),
            ("너무", "맛있", "어요", 300), ("진짜", "맛있", "어요", 280),
            ("너무", "피곤", "해요", 260), ("좀", "힘들", "어요", 240),
            ("기분", "좋", "아요", 280), ("기분", "안", "좋아요", 260),

            // ==========================================
            // WORK/BUSINESS PHRASES
            // ==========================================
            ("확인", "부탁", "드립니다", 320), ("검토", "부탁", "드립니다", 280),
            ("회신", "부탁", "드립니다", 260), ("연락", "주시면", "감사하겠습니다", 280),
            ("수고", "하셨", "습니다", 350), ("좋은", "하루", "보내세요", 320),
            ("다음에", "또", "뵙겠습니다", 280), ("연락", "드리", "겠습니다", 300),
        ]

        for (word1, word2, word3, count) in commonTrigrams {
            let key = "\(word1)_\(word2)"
            data.trigrams[key, default: [:]][word3, default: 0] += count
        }
    }

    // MARK: - Russian N-Grams

    /// Load Russian word n-grams
    /// Call this method to add Russian language support: loadRussianNGrams(into: &data)
    func loadRussianNGrams(into data: inout NGramData) {
        // Common Russian bigrams (word pairs) - ~100 bigrams
        let commonBigrams: [(String, String, Int)] = [
            // ==========================================
            // PRONOUNS + VERBS (быть - to be, мочь - can, хотеть - want)
            // ==========================================

            // я (I) + verbs
            ("я", "есть", 400), ("я", "хочу", 500), ("я", "могу", 450), ("я", "буду", 420),
            ("я", "был", 380), ("я", "была", 370), ("я", "знаю", 400), ("я", "думаю", 380),
            ("я", "понимаю", 350), ("я", "иду", 320), ("я", "люблю", 380), ("я", "делаю", 340),
            ("я", "вижу", 300), ("я", "говорю", 320), ("я", "работаю", 300), ("я", "живу", 280),

            // ты (you informal) + verbs
            ("ты", "можешь", 450), ("ты", "хочешь", 420), ("ты", "будешь", 400), ("ты", "знаешь", 380),
            ("ты", "думаешь", 340), ("ты", "понимаешь", 320), ("ты", "идёшь", 300), ("ты", "любишь", 280),
            ("ты", "делаешь", 320), ("ты", "видишь", 280), ("ты", "говоришь", 260),

            // он (he) + verbs
            ("он", "будет", 480), ("он", "может", 450), ("он", "хочет", 420), ("он", "знает", 380),
            ("он", "думает", 340), ("он", "говорит", 360), ("он", "работает", 320), ("он", "живёт", 300),

            // она (she) + verbs
            ("она", "будет", 470), ("она", "может", 440), ("она", "хочет", 410), ("она", "знает", 370),
            ("она", "думает", 330), ("она", "говорит", 350), ("она", "работает", 310),

            // мы (we) + verbs
            ("мы", "должны", 450), ("мы", "можем", 420), ("мы", "будем", 400), ("мы", "хотим", 380),
            ("мы", "знаем", 340), ("мы", "думаем", 320), ("мы", "идём", 300), ("мы", "делаем", 280),

            // вы (you formal/plural) + verbs
            ("вы", "можете", 420), ("вы", "хотите", 380), ("вы", "будете", 360), ("вы", "знаете", 340),
            ("вы", "думаете", 300), ("вы", "понимаете", 280),

            // они (they) + verbs
            ("они", "будут", 400), ("они", "могут", 380), ("они", "хотят", 350), ("они", "знают", 320),
            ("они", "думают", 290), ("они", "говорят", 300), ("они", "работают", 270),

            // ==========================================
            // COMMON PHRASES AND GREETINGS
            // ==========================================

            ("спасибо", "большое", 600), ("большое", "спасибо", 580), ("пожалуйста", "помоги", 350),
            ("до", "свидания", 550), ("добрый", "день", 500), ("добрый", "вечер", 450),
            ("доброе", "утро", 480), ("доброй", "ночи", 420), ("привет", "как", 400),
            ("как", "дела", 550), ("всего", "хорошего", 350), ("всего", "доброго", 340),
            ("удачи", "тебе", 300), ("счастливого", "пути", 280),

            // ==========================================
            // PREPOSITION PATTERNS
            // ==========================================

            // в (in)
            ("в", "доме", 450), ("в", "городе", 400), ("в", "школе", 380), ("в", "офисе", 350),
            ("в", "магазине", 320), ("в", "парке", 300), ("в", "машине", 280), ("в", "интернете", 260),

            // на (on/at)
            ("на", "работе", 450), ("на", "улице", 400), ("на", "столе", 350), ("на", "месте", 320),
            ("на", "дороге", 280), ("на", "встрече", 260), ("на", "неделе", 300),

            // с (with)
            ("с", "тобой", 400), ("с", "ним", 380), ("с", "ней", 370), ("с", "нами", 350),
            ("с", "вами", 340), ("с", "ними", 330), ("с", "друзьями", 300), ("с", "семьёй", 280),

            // для (for)
            ("для", "меня", 380), ("для", "тебя", 360), ("для", "него", 340), ("для", "неё", 330),
            ("для", "нас", 320), ("для", "вас", 310), ("для", "них", 300),

            // у (at/by/possession)
            ("у", "меня", 400), ("у", "тебя", 380), ("у", "него", 350), ("у", "неё", 340),

            // ==========================================
            // VERB PHRASES
            // ==========================================

            ("хочу", "сказать", 400), ("хочу", "знать", 380), ("хочу", "спросить", 350),
            ("хочу", "попросить", 320), ("хочу", "поблагодарить", 280),

            ("могу", "помочь", 400), ("могу", "сделать", 380), ("могу", "сказать", 350),
            ("могу", "позвонить", 300), ("могу", "прийти", 280),

            ("должен", "идти", 380), ("должен", "сказать", 350), ("должен", "сделать", 340),
            ("должен", "быть", 400), ("должна", "быть", 390), ("должны", "быть", 380),

            ("надо", "сделать", 350), ("надо", "идти", 320), ("надо", "сказать", 300),
            ("нужно", "сделать", 380), ("нужно", "знать", 340), ("нужно", "идти", 320),

            ("буду", "ждать", 350), ("буду", "рад", 320), ("буду", "рада", 310),
            ("давай", "встретимся", 300), ("давай", "поговорим", 280), ("давай", "пойдём", 260),

            // ==========================================
            // TIME EXPRESSIONS
            // ==========================================

            ("вчера", "вечером", 350), ("вчера", "утром", 320), ("вчера", "днём", 280),
            ("сегодня", "вечером", 380), ("сегодня", "утром", 350), ("сегодня", "днём", 300),
            ("завтра", "утром", 380), ("завтра", "вечером", 340), ("завтра", "днём", 280),

            ("на", "следующей", 350), ("следующей", "неделе", 400), ("на", "этой", 340),
            ("этой", "неделе", 380),

            ("в", "понедельник", 300), ("в", "пятницу", 300),
            ("в", "субботу", 290), ("в", "воскресенье", 280), ("во", "вторник", 280),
            ("в", "среду", 270), ("в", "четверг", 260),

            ("через", "час", 300), ("через", "минуту", 280),
            ("через", "неделю", 260), ("через", "месяц", 240),

            // ==========================================
            // QUESTION PATTERNS
            // ==========================================

            ("как", "дела", 550), ("как", "ты", 450), ("как", "вы", 420), ("как", "это", 380),
            ("как", "сделать", 340), ("как", "можно", 320), ("как", "понять", 280),

            ("где", "ты", 400), ("где", "он", 350), ("где", "она", 340), ("где", "это", 320),
            ("где", "находится", 300), ("где", "можно", 280),

            ("когда", "ты", 380), ("когда", "придёшь", 350), ("когда", "будет", 340),
            ("когда", "можно", 300), ("когда", "начинается", 280),

            ("почему", "ты", 350), ("почему", "он", 300), ("почему", "она", 290),
            ("почему", "нет", 340), ("почему", "так", 280),

            ("что", "ты", 420), ("что", "это", 400), ("что", "делаешь", 350),
            ("что", "случилось", 340), ("что", "нового", 320), ("что", "там", 280),

            ("кто", "это", 350), ("кто", "там", 300), ("кто", "знает", 280),

            // ==========================================
            // NEGATION PATTERNS
            // ==========================================

            ("не", "знаю", 450), ("не", "могу", 430), ("не", "хочу", 400), ("не", "понимаю", 380),
            ("не", "надо", 350), ("не", "нужно", 340), ("не", "буду", 330), ("не", "было", 320),
            ("не", "будет", 310), ("не", "думаю", 300), ("не", "помню", 280),

            // ==========================================
            // AFFIRMATIVE RESPONSES
            // ==========================================

            ("да", "конечно", 400), ("да", "хорошо", 380), ("да", "пожалуйста", 350),
            ("нет", "спасибо", 380), ("нет", "проблем", 350), ("конечно", "да", 320),

            // ==========================================
            // BUSINESS/POLITE PHRASES
            // ==========================================

            ("можно", "вас", 350), ("извините", "пожалуйста", 380), ("простите", "пожалуйста", 350),
            ("будьте", "добры", 340), ("не", "могли", 320), ("могли", "бы", 380),
            ("хотел", "бы", 360), ("хотела", "бы", 350), ("было", "бы", 340),
        ]

        for (word1, word2, count) in commonBigrams {
            data.bigrams[word1, default: [:]][word2, default: 0] += count
            data.unigrams[word1, default: 0] += count
            data.unigrams[word2, default: 0] += count
        }

        // Common Russian trigrams - ~50 trigrams
        let commonTrigrams: [(String, String, String, Int)] = [
            // ==========================================
            // VERY COMMON PHRASES
            // ==========================================

            ("как", "у", "тебя", 400), ("у", "тебя", "дела", 380),
            ("как", "у", "вас", 350), ("у", "вас", "дела", 330),
            ("что", "ты", "делаешь", 380), ("что", "вы", "делаете", 340),
            ("я", "не", "знаю", 450), ("я", "не", "могу", 420), ("я", "не", "понимаю", 380),
            ("я", "не", "хочу", 360), ("я", "не", "буду", 340),
            ("мне", "нужно", "идти", 350), ("мне", "нужно", "сделать", 330),
            ("мне", "надо", "идти", 340), ("мне", "надо", "сделать", 320),

            // ==========================================
            // POLITENESS PHRASES
            // ==========================================

            ("спасибо", "большое", "за", 350), ("большое", "спасибо", "за", 340),
            ("очень", "приятно", "познакомиться", 300), ("рад", "вас", "видеть", 280),
            ("рада", "вас", "видеть", 270), ("всего", "вам", "хорошего", 260),

            // ==========================================
            // QUESTION PATTERNS
            // ==========================================

            ("как", "тебя", "зовут", 350), ("как", "вас", "зовут", 340),
            ("как", "это", "сделать", 320), ("где", "ты", "находишься", 280),
            ("когда", "ты", "придёшь", 300), ("что", "ты", "думаешь", 320),
            ("почему", "ты", "так", 280), ("кто", "это", "был", 260),

            // ==========================================
            // TIME EXPRESSIONS
            // ==========================================

            ("на", "следующей", "неделе", 350), ("на", "этой", "неделе", 340),
            ("в", "прошлом", "году", 300), ("в", "этом", "году", 320),
            ("в", "следующем", "году", 280), ("через", "пару", "часов", 260),
            ("через", "пару", "дней", 250), ("через", "несколько", "минут", 240),

            // ==========================================
            // VERB CONSTRUCTIONS
            // ==========================================

            ("я", "хочу", "сказать", 350), ("я", "хочу", "спросить", 320),
            ("я", "могу", "помочь", 340), ("я", "буду", "ждать", 300),
            ("ты", "можешь", "мне", 280), ("он", "должен", "быть", 290),
            ("мы", "должны", "идти", 270), ("нам", "нужно", "поговорить", 260),

            // ==========================================
            // COMMON SENTENCE PATTERNS
            // ==========================================

            ("не", "могу", "понять", 300), ("не", "знаю", "что", 320),
            ("не", "знаю", "как", 310), ("так", "и", "есть", 280),
            ("всё", "в", "порядке", 340), ("в", "порядке", "спасибо", 280),
            ("нет", "ничего", "страшного", 250), ("это", "не", "проблема", 260),
            ("без", "проблем", "конечно", 240), ("конечно", "без", "проблем", 230),

            // ==========================================
            // TRANSITIONAL PHRASES
            // ==========================================

            ("на", "самом", "деле", 300), ("по", "моему", "мнению", 280),
            ("в", "любом", "случае", 270), ("так", "или", "иначе", 250),
            ("в", "общем", "и", 240), ("между", "прочим", "я", 220),
            ("кстати", "говоря", "о", 210), ("если", "честно", "я", 230),
            ("честно", "говоря", "я", 220), ("по", "правде", "говоря", 210),

            // ==========================================
            // MODAL CONSTRUCTIONS
            // ==========================================

            ("можно", "ли", "мне", 280), ("могу", "ли", "я", 270),
            ("не", "мог", "бы", 290), ("не", "могла", "бы", 280),
            ("не", "могли", "бы", 300), ("хотел", "бы", "узнать", 260),
            ("хотела", "бы", "узнать", 250), ("было", "бы", "хорошо", 280),
            ("было", "бы", "неплохо", 260),
        ]

        for (word1, word2, word3, count) in commonTrigrams {
            let key = "\(word1)_\(word2)"
            data.trigrams[key, default: [:]][word3, default: 0] += count
        }
    }
}
