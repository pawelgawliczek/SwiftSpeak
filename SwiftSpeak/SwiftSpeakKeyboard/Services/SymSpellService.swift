//
//  SymSpellService.swift
//  SwiftSpeakKeyboard
//
//  High-performance spelling correction using SymSpell algorithm
//  Provides O(1) lookup for edit distance corrections
//

import Foundation

/// SymSpell-inspired spelling correction service
/// Uses pre-computed delete variants for fast correction lookup
actor SymSpellService {
    static let shared = SymSpellService()

    // Configuration
    private let maxEditDistance: Int = 2
    private let prefixLength: Int = 7

    // Dictionary storage
    private var dictionary: [String: Int] = [:]  // word -> frequency
    private var deletes: [String: Set<String>] = [:]  // delete variant -> original words
    private var maxWordLength: Int = 0

    private var isInitialized = false

    private init() {}

    // MARK: - Initialization

    /// Initialize with default English dictionary
    func initialize() async {
        guard !isInitialized else { return }

        // Load built-in frequency dictionary
        loadFrequencyDictionary()

        isInitialized = true
        keyboardLog("SymSpellService initialized with \(dictionary.count) words", category: "Autocorrect")
    }

    /// Add a word to the dictionary with frequency
    func addWord(_ word: String, frequency: Int = 1) {
        let lowercased = word.lowercased()
        guard lowercased.count >= 2 else { return }

        // Add to dictionary
        dictionary[lowercased] = (dictionary[lowercased] ?? 0) + frequency
        maxWordLength = max(maxWordLength, lowercased.count)

        // Generate and store delete variants
        let deleteVariants = generateDeletes(word: lowercased, maxDistance: maxEditDistance)
        for variant in deleteVariants {
            deletes[variant, default: []].insert(lowercased)
        }
    }

    /// Add multiple words from personal vocabulary
    func addPersonalWords(_ words: [String]) {
        for word in words {
            addWord(word, frequency: 10)  // Personal words get higher frequency
        }
        keyboardLog("SymSpellService added \(words.count) personal words", category: "Autocorrect")
    }

    // MARK: - Spell Checking

    /// Check if a word is correctly spelled
    func isCorrect(_ word: String) -> Bool {
        let lowercased = word.lowercased()
        return dictionary[lowercased] != nil
    }

    /// Get spelling suggestions for a word
    /// Returns array of (word, editDistance, frequency) sorted by relevance
    func lookup(_ input: String, maxDistance: Int? = nil, maxResults: Int = 5) -> [(word: String, distance: Int, frequency: Int)] {
        let lowercased = input.lowercased()
        let maxDist = min(maxDistance ?? maxEditDistance, maxEditDistance)

        // Quick check for exact match
        if let freq = dictionary[lowercased] {
            return [(lowercased, 0, freq)]
        }

        var suggestions: [(word: String, distance: Int, frequency: Int)] = []
        var seenWords = Set<String>()

        // Generate delete variants of input and look up candidates
        let inputDeletes = generateDeletes(word: lowercased, maxDistance: maxDist)
        var candidateWords = Set<String>()

        // Check input directly (for distance 0)
        if let words = deletes[lowercased] {
            candidateWords.formUnion(words)
        }

        // Check all delete variants
        for variant in inputDeletes {
            if let words = deletes[variant] {
                candidateWords.formUnion(words)
            }
        }

        // Calculate actual edit distance for each candidate
        for candidate in candidateWords {
            guard !seenWords.contains(candidate) else { continue }
            seenWords.insert(candidate)

            let distance = damerauLevenshteinDistance(lowercased, candidate)
            if distance <= maxDist {
                let freq = dictionary[candidate] ?? 0
                suggestions.append((candidate, distance, freq))
            }
        }

        // Sort by: distance (ascending), then frequency (descending)
        suggestions.sort { a, b in
            if a.distance != b.distance {
                return a.distance < b.distance
            }
            return a.frequency > b.frequency
        }

        return Array(suggestions.prefix(maxResults))
    }

    /// Get the best correction for a word (for autocorrect)
    /// Only returns a correction when confident it's a typo
    func getCorrection(_ word: String) -> String? {
        let lowercased = word.lowercased()

        // Don't correct if already in dictionary
        if dictionary[lowercased] != nil {
            return nil
        }

        // Skip very short words
        guard lowercased.count >= 3 else { return nil }

        // Get suggestions
        let suggestions = lookup(lowercased, maxDistance: 2, maxResults: 3)

        // Only autocorrect with high confidence
        guard let best = suggestions.first else { return nil }

        // Strict criteria for automatic correction:
        // 1. Edit distance must be 1 (single typo) or 2 if word is longer
        let maxAllowedDistance = lowercased.count >= 6 ? 2 : 1
        guard best.distance <= maxAllowedDistance else { return nil }

        // 2. Same first letter (typos rarely change first letter)
        guard best.word.first == lowercased.first else { return nil }

        // 3. Similar length
        guard abs(best.word.count - lowercased.count) <= 1 else { return nil }

        // 4. High frequency (common words are more likely to be the target)
        guard best.frequency >= 100 else { return nil }

        return best.word
    }

    // MARK: - Delete Variant Generation

    /// Generate all delete variants within max edit distance
    private func generateDeletes(word: String, maxDistance: Int) -> Set<String> {
        var deletes = Set<String>()
        var queue = [word]

        for _ in 0..<maxDistance {
            var temp: [String] = []
            for queuedWord in queue {
                if queuedWord.count > 1 {
                    for i in queuedWord.indices {
                        var variant = queuedWord
                        variant.remove(at: i)
                        if !deletes.contains(variant) {
                            deletes.insert(variant)
                            temp.append(variant)
                        }
                    }
                }
            }
            queue = temp
        }

        return deletes
    }

    // MARK: - Edit Distance

    /// Damerau-Levenshtein distance (handles transpositions)
    private func damerauLevenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        let m = a.count
        let n = b.count

        if m == 0 { return n }
        if n == 0 { return m }

        // Quick check for identical strings
        if s1 == s2 { return 0 }

        // Use 2D array for full Damerau-Levenshtein
        var d = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { d[i][0] = i }
        for j in 0...n { d[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1

                d[i][j] = min(
                    d[i - 1][j] + 1,      // deletion
                    d[i][j - 1] + 1,      // insertion
                    d[i - 1][j - 1] + cost // substitution
                )

                // Transposition
                if i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1] {
                    d[i][j] = min(d[i][j], d[i - 2][j - 2] + cost)
                }
            }
        }

        return d[m][n]
    }

    // MARK: - Dictionary Loading

    /// Load frequency dictionary with common English words
    private func loadFrequencyDictionary() {
        // Top frequency English words (frequency values based on corpus data)
        // Format: word, approximate frequency per million words
        let frequencyData: [(String, Int)] = [
            // Top 100 most common words (very high frequency)
            ("the", 69971), ("be", 37715), ("to", 28453), ("of", 27004), ("and", 26366),
            ("a", 21332), ("in", 20047), ("that", 12581), ("have", 12458), ("i", 11167),
            ("it", 10875), ("for", 9538), ("not", 9124), ("on", 8631), ("with", 7735),
            ("he", 7526), ("as", 7158), ("you", 7025), ("do", 6666), ("at", 6335),
            ("this", 5883), ("but", 5711), ("his", 5234), ("by", 4938), ("from", 4804),
            ("they", 4475), ("we", 4422), ("say", 4125), ("her", 3951), ("she", 3850),
            ("or", 3832), ("an", 3633), ("will", 3608), ("my", 3384), ("one", 3231),
            ("all", 3189), ("would", 3062), ("there", 2909), ("their", 2883), ("what", 2833),
            ("so", 2677), ("up", 2529), ("out", 2453), ("if", 2438), ("about", 2370),
            ("who", 2298), ("get", 2176), ("which", 2161), ("go", 2141), ("me", 2055),
            ("when", 2014), ("make", 1950), ("can", 1939), ("like", 1864), ("time", 1820),
            ("no", 1790), ("just", 1782), ("him", 1710), ("know", 1698), ("take", 1608),
            ("people", 1533), ("into", 1509), ("year", 1506), ("your", 1492), ("good", 1476),
            ("some", 1474), ("could", 1434), ("them", 1418), ("see", 1415), ("other", 1404),
            ("than", 1360), ("then", 1331), ("now", 1313), ("look", 1291), ("only", 1250),
            ("come", 1245), ("its", 1231), ("over", 1192), ("think", 1184), ("also", 1154),
            ("back", 1130), ("after", 1102), ("use", 1074), ("two", 1061), ("how", 1057),
            ("our", 1055), ("work", 1040), ("first", 1018), ("well", 1016), ("way", 1012),
            ("even", 983), ("new", 976), ("want", 968), ("because", 961), ("any", 933),
            ("these", 921), ("give", 909), ("day", 893), ("most", 883), ("us", 860),

            // Common verbs
            ("are", 8500), ("is", 8100), ("was", 6200), ("were", 3500), ("been", 2800),
            ("being", 1800), ("am", 1500), ("has", 4200), ("had", 3800), ("does", 2100),
            ("did", 2500), ("done", 1200), ("doing", 900), ("made", 1500), ("making", 800),
            ("here", 2400), ("very", 2200), ("more", 2600), ("much", 1700), ("such", 1200),
            ("own", 1100), ("same", 1000), ("too", 1400), ("where", 1300), ("why", 1100),
            ("let", 800), ("put", 900), ("said", 2500), ("tell", 800), ("told", 700),
            ("ask", 600), ("asked", 500), ("need", 1100), ("feel", 700), ("try", 600),
            ("leave", 500), ("call", 800), ("keep", 700), ("last", 900), ("long", 1000),
            ("great", 1100), ("little", 1000), ("right", 1400), ("big", 700), ("high", 800),
            ("small", 600), ("large", 500), ("next", 700), ("early", 400), ("young", 500),
            ("few", 600), ("old", 800), ("able", 700), ("man", 1200), ("men", 700),
            ("woman", 500), ("women", 400), ("child", 500), ("children", 400),

            // Common nouns
            ("world", 1100), ("life", 1000), ("hand", 800), ("part", 700), ("place", 700),
            ("case", 600), ("week", 500), ("company", 600), ("system", 500), ("program", 400),
            ("thing", 900), ("point", 600), ("home", 700), ("water", 400), ("room", 400),
            ("mother", 400), ("area", 400), ("money", 600), ("story", 400), ("fact", 500),
            ("month", 400), ("lot", 600), ("study", 300), ("book", 400), ("eye", 400),
            ("job", 500), ("word", 500), ("business", 500), ("issue", 400), ("side", 400),
            ("kind", 500), ("head", 500), ("house", 500), ("service", 400), ("friend", 400),
            ("father", 300), ("power", 500), ("hour", 400), ("game", 400), ("line", 400),
            ("end", 600), ("member", 300), ("law", 400), ("car", 400), ("city", 400),
            ("name", 600), ("president", 300), ("team", 400), ("minute", 300), ("idea", 400),
            ("kid", 300), ("body", 400), ("information", 300), ("nothing", 400), ("ago", 400),
            ("lead", 300), ("social", 300), ("whether", 300), ("watch", 300), ("together", 400),
            ("follow", 300), ("around", 500), ("parent", 200), ("stop", 400), ("face", 400),
            ("anything", 400), ("create", 300), ("real", 500), ("might", 800), ("must", 700),
            ("shall", 200), ("should", 900), ("may", 700), ("many", 900), ("each", 500),
            ("between", 500), ("through", 600), ("during", 300), ("before", 600), ("those", 600),
            ("both", 500), ("while", 500), ("another", 500), ("under", 400), ("never", 500),
            ("always", 400), ("sometimes", 200), ("often", 300), ("still", 600), ("again", 500),

            // Communication words
            ("hello", 150), ("hi", 200), ("hey", 100), ("thanks", 300), ("thank", 400),
            ("please", 300), ("sorry", 200), ("okay", 300), ("ok", 400), ("yes", 500),
            ("yeah", 200), ("no", 1790), ("maybe", 200), ("sure", 300),

            // Business/Work words
            ("meeting", 200), ("email", 250), ("message", 200), ("phone", 300),
            ("tomorrow", 200), ("today", 400), ("yesterday", 150), ("monday", 100),
            ("tuesday", 80), ("wednesday", 70), ("thursday", 80), ("friday", 100),
            ("saturday", 80), ("sunday", 90), ("morning", 300), ("afternoon", 150),
            ("evening", 150), ("night", 300), ("question", 200), ("answer", 200),
            ("problem", 300), ("solution", 100), ("important", 300), ("urgent", 100),
            ("available", 150), ("schedule", 100), ("confirm", 80), ("cancel", 80),
            ("update", 150), ("change", 300), ("project", 200), ("report", 150),
            ("document", 100), ("file", 150), ("folder", 50), ("computer", 200),
            ("internet", 150), ("website", 100), ("online", 150), ("data", 200),

            // Common adjectives
            ("best", 400), ("better", 400), ("bad", 300), ("worse", 100), ("worst", 80),
            ("different", 300), ("same", 1000), ("important", 300), ("possible", 200),
            ("available", 150), ("free", 300), ("full", 300), ("special", 200),
            ("happy", 200), ("sad", 100), ("easy", 200), ("hard", 300), ("difficult", 150),
            ("simple", 150), ("clear", 200), ("sure", 300), ("true", 300), ("false", 100),

            // Technology words
            ("app", 150), ("application", 100), ("software", 100), ("device", 100),
            ("mobile", 100), ("screen", 100), ("button", 80), ("click", 100),
            ("download", 80), ("upload", 50), ("install", 50), ("account", 150),
            ("password", 100), ("username", 50), ("login", 80), ("logout", 30),
            ("settings", 80), ("notification", 50), ("search", 150), ("find", 300),

            // Common misspelling targets (added with high frequency)
            ("receive", 200), ("believe", 200), ("achieve", 100), ("weird", 100),
            ("their", 2883), ("there", 2909), ("they're", 100), ("your", 1492),
            ("you're", 200), ("its", 1231), ("it's", 300), ("whose", 100), ("who's", 80),
            ("definitely", 100), ("separate", 80), ("occurrence", 50), ("accommodate", 50),
            ("necessary", 100), ("beginning", 80), ("environment", 80), ("government", 150),
            ("restaurant", 80), ("wednesday", 70), ("February", 50), ("calendar", 80),
            ("experience", 150), ("immediately", 80), ("professional", 100),
            ("particularly", 80), ("unfortunately", 60), ("approximately", 50),
            ("successful", 100), ("beautiful", 150), ("interesting", 150),
        ]

        for (word, frequency) in frequencyData {
            addWord(word, frequency: frequency)
        }
    }
}
