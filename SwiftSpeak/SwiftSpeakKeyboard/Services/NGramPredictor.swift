//
//  NGramPredictor.swift
//  SwiftSpeakKeyboard
//
//  N-gram based word prediction using bigram and trigram models
//  Predicts next word based on previous 1-2 words
//

import Foundation

/// N-gram data for a specific language
struct NGramData {
    var bigrams: [String: [String: Int]] = [:]
    var trigrams: [String: [String: Int]] = [:]
    var unigrams: [String: Int] = [:]
}

/// N-gram based word prediction service
/// Uses statistical patterns from common text to predict next words
/// Supports multiple languages with per-language n-gram models
actor NGramPredictor {
    static let shared = NGramPredictor()

    // N-gram data organized by language code (e.g., "en", "pl")
    private var ngramsByLanguage: [String: NGramData] = [:]

    private var isInitialized = false

    private init() {}

    // MARK: - Initialization

    func initialize() async {
        guard !isInitialized else { return }

        loadBuiltInNGrams(for: "en")
        loadBuiltInNGrams(for: "pl")
        loadBuiltInNGrams(for: "es")
        loadBuiltInNGrams(for: "fr")
        loadBuiltInNGrams(for: "de")
        isInitialized = true

        let totalBigrams = ngramsByLanguage.values.reduce(0) { $0 + $1.bigrams.count }
        let totalTrigrams = ngramsByLanguage.values.reduce(0) { $0 + $1.trigrams.count }
        keyboardLog("NGramPredictor initialized: \(ngramsByLanguage.count) languages, \(totalBigrams) bigrams, \(totalTrigrams) trigrams", category: "Prediction")
    }

    /// Learn from user's text (call with transcription history)
    /// - Parameters:
    ///   - text: Text to learn from
    ///   - language: Language code (defaults to "en")
    func learnFromText(_ text: String, language: String = "en") {
        let words = tokenize(text)
        guard words.count >= 2 else { return }

        // Get or create n-gram data for this language
        var data = ngramsByLanguage[language] ?? NGramData()

        // Build unigrams
        for word in words {
            data.unigrams[word, default: 0] += 1
        }

        // Build bigrams
        for i in 0..<(words.count - 1) {
            let current = words[i]
            let next = words[i + 1]
            data.bigrams[current, default: [:]][next, default: 0] += 1
        }

        // Build trigrams
        if words.count >= 3 {
            for i in 0..<(words.count - 2) {
                let key = "\(words[i])_\(words[i + 1])"
                let next = words[i + 2]
                data.trigrams[key, default: [:]][next, default: 0] += 1
            }
        }

        ngramsByLanguage[language] = data
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

    // MARK: - Built-in N-Grams

    private func loadBuiltInNGrams(for language: String) {
        var data = NGramData()

        if language == "en" {
            loadEnglishNGrams(into: &data)
        } else if language == "pl" {
            loadPolishNGrams(into: &data)
        } else if language == "es" {
            loadSpanishNGrams(into: &data)
        } else if language == "fr" {
            loadFrenchNGrams(into: &data)
        } else if language == "de" {
            loadGermanNGrams(into: &data)
        }

        ngramsByLanguage[language] = data
    }

    private func loadEnglishNGrams(into data: inout NGramData) {
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
            data.bigrams[word1, default: [:]][word2, default: 0] += count
            data.unigrams[word1, default: 0] += count
            data.unigrams[word2, default: 0] += count
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
            data.trigrams[key, default: [:]][word3, default: 0] += count
        }
    }

    private func loadPolishNGrams(into data: inout NGramData) {
        // Common Polish bigrams (word pairs)
        let commonBigrams: [(String, String, Int)] = [
            // Pronouns + verbs (być - to be)
            ("ja", "jestem", 500), ("ja", "mam", 400), ("ja", "będę", 300), ("ja", "byłem", 280),
            ("ja", "chcę", 350), ("ja", "mogę", 320), ("ja", "muszę", 300), ("ja", "wiem", 280),
            ("ty", "jesteś", 400), ("ty", "masz", 350), ("ty", "możesz", 300), ("ty", "musisz", 250),
            ("on", "jest", 450), ("on", "ma", 380), ("on", "będzie", 320), ("on", "był", 300),
            ("ona", "jest", 440), ("ona", "ma", 370), ("ona", "będzie", 310), ("ona", "była", 290),
            ("my", "jesteśmy", 350), ("my", "mamy", 320), ("my", "będziemy", 280), ("my", "możemy", 300),
            ("wy", "jesteście", 300), ("wy", "macie", 280), ("wy", "możecie", 250),
            ("oni", "są", 400), ("oni", "mają", 350), ("oni", "byli", 280), ("oni", "będą", 300),
            ("one", "są", 380), ("one", "mają", 340), ("one", "były", 270), ("one", "będą", 290),

            // Common phrases and greetings
            ("dziękuję", "bardzo", 600), ("proszę", "bardzo", 550), ("do", "widzenia", 500),
            ("na", "razie", 450), ("co", "słychać", 400), ("dzień", "dobry", 550),
            ("dobry", "wieczór", 450), ("dobranoc", "kochanie", 200),
            ("cześć", "jak", 380), ("jak", "się", 500), ("się", "masz", 450),
            ("miłego", "dnia", 300), ("wszystkiego", "najlepszego", 280),

            // Preposition patterns
            ("w", "domu", 450), ("w", "pracy", 400), ("w", "szkole", 350), ("w", "mieście", 300),
            ("w", "porządku", 500), ("na", "zewnątrz", 350), ("na", "pewno", 400),
            ("po", "prostu", 480), ("po", "południu", 300), ("z", "tobą", 350),
            ("do", "domu", 400), ("do", "pracy", 350), ("do", "zobaczenia", 380),
            ("od", "razu", 300), ("za", "chwilę", 320), ("przez", "internet", 250),

            // Verb phrases (infinitive constructions)
            ("chcę", "powiedzieć", 350), ("chcę", "wiedzieć", 320), ("chcę", "zobaczyć", 300),
            ("muszę", "iść", 400), ("muszę", "zrobić", 380), ("muszę", "pomyśleć", 280),
            ("mogę", "pomóc", 380), ("mogę", "zrobić", 350), ("mogę", "przyjść", 300),
            ("będę", "mógł", 300), ("będę", "miał", 280), ("będę", "czekał", 250),
            ("chciałbym", "wiedzieć", 280), ("chciałbym", "zapytać", 250),

            // Common adjective + noun
            ("dobry", "pomysł", 250), ("dobra", "robota", 200), ("miły", "dzień", 220),
            ("świetny", "pomysł", 200), ("nowy", "telefon", 180), ("stary", "przyjaciel", 170),

            // Time expressions
            ("w", "weekend", 280), ("w", "niedzielę", 250), ("w", "poniedziałek", 240),
            ("jutro", "rano", 280), ("dziś", "wieczorem", 260), ("wczoraj", "wieczorem", 240),
            ("za", "tydzień", 250), ("za", "miesiąc", 230), ("za", "rok", 220),
            ("w", "zeszłym", 200), ("zeszłym", "tygodniu", 280), ("zeszłym", "roku", 250),
            ("w", "przyszłym", 180), ("przyszłym", "tygodniu", 260), ("przyszłym", "roku", 230),

            // Question patterns
            ("co", "robisz", 350), ("co", "dziś", 300), ("co", "tam", 280),
            ("jak", "leci", 300), ("jak", "minął", 250), ("gdzie", "jesteś", 280),
            ("kiedy", "przyjdziesz", 220), ("dlaczego", "nie", 300),
            ("czy", "możesz", 280), ("czy", "jesteś", 260), ("czy", "masz", 250),

            // Business/polite phrases
            ("proszę", "o", 350), ("bardzo", "proszę", 300), ("mogę", "prosić", 250),
            ("czy", "mogę", 280), ("czy", "mógłbym", 220), ("jeśli", "możesz", 200),
            ("jak", "najszybciej", 240), ("z", "góry", 180), ("góry", "dziękuję", 200),
        ]

        for (word1, word2, count) in commonBigrams {
            data.bigrams[word1, default: [:]][word2, default: 0] += count
            data.unigrams[word1, default: 0] += count
            data.unigrams[word2, default: 0] += count
        }

        // Common Polish trigrams
        let commonTrigrams: [(String, String, String, Int)] = [
            // Very common phrases
            ("jak", "się", "masz", 450), ("co", "się", "dzieje", 350),
            ("wszystko", "w", "porządku", 300), ("w", "porządku", "dzięki", 250),
            ("bardzo", "się", "cieszę", 280), ("nie", "ma", "sprawy", 320),

            // Pronouns + verb phrases
            ("ja", "chcę", "powiedzieć", 300), ("ja", "muszę", "iść", 280),
            ("ja", "mogę", "pomóc", 260), ("ja", "nie", "wiem", 350),
            ("ja", "nie", "mam", 320), ("ja", "też", "tak", 250),

            ("czy", "mogę", "prosić", 250), ("czy", "mógłbym", "zapytać", 200),
            ("czy", "możesz", "mi", 240), ("co", "u", "ciebie", 280),

            // Politeness phrases
            ("dziękuję", "bardzo", "za", 300), ("proszę", "bardzo", "się", 200),
            ("z", "góry", "dziękuję", 220), ("wszystkiego", "najlepszego", "z", 200),
            ("miłego", "dnia", "życzę", 180),

            // Time expressions
            ("w", "zeszłym", "tygodniu", 250), ("w", "zeszłym", "roku", 220),
            ("w", "przyszłym", "tygodniu", 230), ("w", "przyszłym", "roku", 200),
            ("za", "kilka", "dni", 200), ("za", "kilka", "minut", 180),

            // Verb constructions
            ("chcę", "ci", "powiedzieć", 220), ("muszę", "ci", "powiedzieć", 200),
            ("mogę", "ci", "pomóc", 240), ("będę", "mógł", "pomóc", 180),
            ("chciałbym", "cię", "zapytać", 160),

            // Common sentence patterns
            ("nie", "ma", "problemu", 280), ("to", "jest", "dobre", 220),
            ("to", "jest", "świetne", 200), ("jak", "to", "możliwe", 180),
            ("co", "za", "niespodzianka", 150), ("nie", "mogę", "uwierzyć", 190),

            // Questions
            ("co", "robisz", "dziś", 240), ("co", "tam", "słychać", 260),
            ("jak", "minął", "dzień", 220), ("gdzie", "się", "spotykamy", 180),
            ("kiedy", "się", "spotkamy", 200),

            // Transitional phrases
            ("w", "każdym", "razie", 200), ("na", "przykład", "jak", 180),
            ("tak", "czy", "inaczej", 170), ("w", "takim", "razie", 220),
            ("jeśli", "chodzi", "o", 190), ("o", "ile", "wiem", 160),
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
}

