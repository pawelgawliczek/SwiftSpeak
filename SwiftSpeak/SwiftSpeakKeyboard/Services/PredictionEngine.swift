//
//  PredictionEngine.swift
//  SwiftSpeakKeyboard
//
//  AI-powered prediction engine for smart word suggestions (Phase 13.6)
//  Combines N-gram models, personal dictionary, context awareness, and LLM predictions
//

import Foundation

// MARK: - Prediction Engine
actor PredictionEngine {
    private let appGroupID = "group.pawelgawliczek.swiftspeak"
    private var vocabulary: [String] = []
    private var recentWords: [String] = []
    private var frequentWords: [String: Int] = [:]
    private var lastLLMRequest: Date?
    private let llmCooldown: TimeInterval = 0.8  // Reduced cooldown for better responsiveness

    // Debouncing for LLM predictions
    private var pendingPredictionTask: Task<[String], Never>?
    private var lastPredictionContext: String = ""

    // Service initialization flags
    private var servicesInitialized = false

    // MARK: - Initialization

    init() {
        Task {
            await initializeServices()
            await loadVocabulary()
        }
    }

    /// Initialize all prediction services
    private func initializeServices() async {
        guard !servicesInitialized else { return }

        // Initialize N-gram predictor
        await NGramPredictor.shared.initialize()

        // Initialize personal dictionary
        await PersonalDictionary.shared.initialize()

        // Initialize context-aware predictions
        await ContextAwarePredictions.shared.initialize()

        // Initialize prediction feedback
        await PredictionFeedback.shared.initialize()

        servicesInitialized = true
        keyboardLog("PredictionEngine: All services initialized", category: "Prediction")
    }

    // MARK: - Load Vocabulary

    /// Load custom vocabulary and frequent words from App Groups
    func loadVocabulary() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            keyboardLog("PredictionEngine: Failed to access App Groups", category: "Prediction", level: .error)
            return
        }

        // Load custom vocabulary
        if let vocabData = defaults.data(forKey: Constants.Keys.vocabulary) {
            struct SimpleVocabulary: Codable {
                let word: String
            }

            if let vocabEntries = try? JSONDecoder().decode([SimpleVocabulary].self, from: vocabData) {
                vocabulary = vocabEntries.map { $0.word }
                keyboardLog("PredictionEngine: Loaded \(vocabulary.count) vocabulary words", category: "Prediction")
            }
        }

        // Load recent transcriptions to build frequent words and train N-gram model
        if let historyData = defaults.data(forKey: Constants.Keys.transcriptionHistory) {
            struct SimpleHistory: Codable {
                let text: String
            }

            if let history = try? JSONDecoder().decode([SimpleHistory].self, from: historyData) {
                // Extract words from recent transcriptions
                var wordCounts: [String: Int] = [:]
                for record in history.prefix(100) {  // Last 100 transcriptions
                    let words = record.text.split(separator: " ").map(String.init)
                    for word in words {
                        let normalized = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
                        if normalized.count > 2 {  // Skip very short words
                            wordCounts[normalized, default: 0] += 1
                        }
                    }

                    // Train N-gram model with transcription text
                    Task {
                        await NGramPredictor.shared.learnFromText(record.text)
                    }
                }

                // Keep top 200 most frequent words
                let topWords = wordCounts.sorted { $0.value > $1.value }
                    .prefix(200)
                frequentWords = Dictionary(uniqueKeysWithValues: topWords.map { ($0.key, $0.value) })

                keyboardLog("PredictionEngine: Loaded \(frequentWords.count) frequent words", category: "Prediction")
            }
        }
    }

    // MARK: - Local Predictions

    /// Get predictions based on local vocabulary, N-grams, and context
    func localPredictions(for context: PredictionContext, activeContext: String? = nil) async -> [String] {
        // Ensure services are initialized
        if !servicesInitialized {
            await initializeServices()
        }

        var predictions: [(text: String, score: Double)] = []

        let searchTerm = context.currentWord.lowercased()
        let previousWords = context.previousWords

        // Detect typing context
        let typingContext = await ContextAwarePredictions.shared.detectContext(
            text: context.fullText,
            activeContextName: activeContext
        )

        // If current word is empty, use N-gram and context-aware predictions
        if searchTerm.isEmpty {
            // 1. Get N-gram predictions based on previous words
            let ngramPredictions = await NGramPredictor.shared.predict(
                previousWords: previousWords,
                maxResults: 5
            )
            for (index, word) in ngramPredictions.enumerated() {
                let score = 100.0 - Double(index * 10)
                predictions.append((word, score))
            }

            // 2. Get learned follow words from feedback
            if let lastWord = previousWords.last {
                let learnedWords = await PredictionFeedback.shared.getLearnedFollowWords(
                    after: lastWord,
                    maxResults: 3
                )
                for word in learnedWords {
                    predictions.append((word, 90.0))  // High score for learned patterns
                }
            }

            // 3. Get context-aware starter predictions
            let contextPredictions = await ContextAwarePredictions.shared.getStarterPredictions(for: typingContext)
            for (index, word) in contextPredictions.prefix(3).enumerated() {
                predictions.append((word, 50.0 - Double(index * 5)))
            }

        } else {
            // Prefix-based predictions

            // 1. N-gram completions (context-aware prefix matching)
            let ngramCompletions = await NGramPredictor.shared.predictCompletion(
                prefix: searchTerm,
                previousWords: previousWords,
                maxResults: 5
            )
            for (index, word) in ngramCompletions.enumerated() {
                let score = 100.0 - Double(index * 10)
                predictions.append((word, score))
            }

            // 2. Personal dictionary matches
            let personalWords = await PersonalDictionary.shared.wordsWithPrefix(searchTerm, maxResults: 5)
            for word in personalWords {
                let freq = await PersonalDictionary.shared.frequency(of: word)
                let score = 80.0 + min(Double(freq) * 2, 20.0)
                predictions.append((word.capitalized, score))
            }

            // 3. Search custom vocabulary for prefix matches
            for word in vocabulary {
                if word.lowercased().hasPrefix(searchTerm) && word.lowercased() != searchTerm {
                    predictions.append((word, 70.0))
                }
            }

            // 4. Search frequent words for prefix matches
            for (word, count) in frequentWords {
                if word.hasPrefix(searchTerm) && word != searchTerm {
                    let score = 60.0 + min(Double(count), 20.0)
                    predictions.append((word.capitalized, score))
                }
            }

            // 5. Context-specific vocabulary
            let contextWords = await ContextAwarePredictions.shared.getPredictions(
                for: searchTerm,
                context: typingContext
            )
            for (index, word) in contextWords.prefix(3).enumerated() {
                predictions.append((word, 55.0 - Double(index * 5)))
            }
        }

        // Apply feedback boosts
        var boostedPredictions: [(String, Double)] = []
        for (text, baseScore) in predictions {
            let boost = await PredictionFeedback.shared.getBoost(for: text)

            // Also apply contextual boost if we have previous word
            var contextBoost = 1.0
            if let lastWord = previousWords.last {
                contextBoost = await PredictionFeedback.shared.getContextualBoost(for: text, after: lastWord)
            }

            let finalScore = baseScore * boost * contextBoost
            boostedPredictions.append((text, finalScore))
        }

        // Deduplicate, sort by score, and return top 3
        var seen = Set<String>()
        var uniquePredictions: [(String, Double)] = []
        for (text, score) in boostedPredictions {
            let normalized = text.lowercased()
            if seen.insert(normalized).inserted {
                uniquePredictions.append((text, score))
            }
        }

        uniquePredictions.sort { $0.1 > $1.1 }

        // Apply smart capitalization based on context
        let shouldCapitalize = shouldCapitalizeNextWord(context: context.fullText)
        return uniquePredictions.prefix(3).map { text, _ in
            applySmartCapitalization(text, shouldCapitalize: shouldCapitalize)
        }
    }

    // MARK: - Smart Capitalization

    /// Determine if next word should be capitalized based on context
    private func shouldCapitalizeNextWord(context: String) -> Bool {
        // Empty context = start of text
        if context.isEmpty {
            return true
        }

        let trimmed = context.trimmingCharacters(in: .whitespaces)

        // Empty after trimming = start of text
        if trimmed.isEmpty {
            return true
        }

        // After sentence-ending punctuation
        if trimmed.hasSuffix(".") || trimmed.hasSuffix("!") || trimmed.hasSuffix("?") {
            // Check for common abbreviations that don't end sentences
            let abbreviations = ["mr.", "mrs.", "ms.", "dr.", "prof.", "sr.", "jr.",
                               "etc.", "vs.", "e.g.", "i.e.", "fig.", "no.", "vol.",
                               "st.", "ave.", "blvd.", "rd.", "inc.", "corp.", "ltd."]
            let lowercased = trimmed.lowercased()
            for abbr in abbreviations {
                if lowercased.hasSuffix(abbr) {
                    return false
                }
            }
            return true
        }

        // After newline
        if context.hasSuffix("\n") {
            return true
        }

        return false
    }

    /// Apply capitalization to a word based on context
    private func applySmartCapitalization(_ word: String, shouldCapitalize: Bool) -> String {
        if shouldCapitalize {
            return word.capitalized
        }
        return word.lowercased()
    }

    /// Legacy sync wrapper
    func localPredictions(for context: PredictionContext) -> [String] {
        // For backward compatibility, return simple predictions
        let searchTerm = context.currentWord.lowercased()
        let shouldCapitalize = shouldCapitalizeNextWord(context: context.fullText)

        if searchTerm.isEmpty {
            return frequentWords
                .sorted { $0.value > $1.value }
                .prefix(3)
                .map { applySmartCapitalization($0.key, shouldCapitalize: shouldCapitalize) }
        }

        var predictions: [(String, Int)] = []

        for word in vocabulary {
            if word.lowercased().hasPrefix(searchTerm) && word.lowercased() != searchTerm {
                predictions.append((word.lowercased(), 100))
            }
        }

        for (word, count) in frequentWords {
            if word.hasPrefix(searchTerm) && word != searchTerm {
                predictions.append((word.lowercased(), count))
            }
        }

        return predictions
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { applySmartCapitalization($0.0, shouldCapitalize: shouldCapitalize) }
    }

    // MARK: - LLM Predictions

    /// Get predictions from configured AI provider with debouncing
    func llmPredictions(for context: PredictionContext, activeContext: String? = nil) async -> [String] {
        // Check cooldown to avoid too frequent API calls
        if let lastRequest = lastLLMRequest,
           Date().timeIntervalSince(lastRequest) < llmCooldown {
            keyboardLog("PredictionEngine: LLM cooldown active", category: "Prediction")
            return await localPredictions(for: context, activeContext: activeContext)
        }

        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return await localPredictions(for: context, activeContext: activeContext)
        }

        // Check for configured provider
        guard let apiKey = defaults.string(forKey: Constants.Keys.openAIAPIKey),
              !apiKey.isEmpty else {
            keyboardLog("PredictionEngine: No API key configured", category: "Prediction")
            return await localPredictions(for: context, activeContext: activeContext)
        }

        lastLLMRequest = Date()

        // Get last ~100 characters for context
        let contextText = String(context.fullText.suffix(100))

        do {
            let predictions = try await callOpenAIForPredictions(
                context: contextText,
                apiKey: apiKey
            )

            if predictions.isEmpty {
                return await localPredictions(for: context, activeContext: activeContext)
            }

            keyboardLog("PredictionEngine: LLM returned \(predictions.count) predictions", category: "Prediction")
            return predictions

        } catch {
            keyboardLog("PredictionEngine: LLM error - \(error.localizedDescription)", category: "Prediction", level: .error)
            return await localPredictions(for: context, activeContext: activeContext)
        }
    }

    /// Legacy wrapper
    func llmPredictions(for context: PredictionContext) async -> [String] {
        return await llmPredictions(for: context, activeContext: nil)
    }

    // MARK: - OpenAI API Call

    /// Call OpenAI API for next word predictions
    private func callOpenAIForPredictions(context: String, apiKey: String) async throws -> [String] {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        // Build prompt for predictions
        let systemPrompt = "You are a predictive text assistant. Given the user's current text, suggest 3 likely next words they might type. Return ONLY the 3 words separated by commas, nothing else."
        let userPrompt = "Current text: \"\(context)\"\n\nSuggest 3 next words:"

        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",  // Fast, cheap model for predictions
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 20,
            "temperature": 0.7
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 3.0  // Quick timeout for predictions

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PredictionError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            keyboardLog("PredictionEngine: OpenAI API error \(httpResponse.statusCode)", category: "Prediction", level: .error)
            throw PredictionError.apiError(statusCode: httpResponse.statusCode)
        }

        // Parse response
        struct OpenAIResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let apiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = apiResponse.choices.first?.message.content else {
            throw PredictionError.emptyResponse
        }

        // Parse comma-separated predictions
        let predictions = content
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)

        return Array(predictions)
    }

    // MARK: - Get Predictions

    /// Get predictions for the current typing context with debouncing
    func getPredictions(for context: PredictionContext, activeContext: String? = nil) async -> [String] {
        // Ensure services are initialized before making predictions
        if !servicesInitialized {
            await initializeServices()
        }

        // Cancel any pending prediction task if context changed significantly
        if context.fullText != lastPredictionContext {
            pendingPredictionTask?.cancel()
            lastPredictionContext = context.fullText
        }

        if context.shouldUseLLM {
            return await llmPredictions(for: context, activeContext: activeContext)
        }
        return await localPredictions(for: context, activeContext: activeContext)
    }

    /// Get predictions with debouncing (waits for typing to pause)
    func getDebouncedPredictions(for context: PredictionContext, activeContext: String? = nil, delayMs: Int = 150) async -> [String] {
        // Cancel previous pending task
        pendingPredictionTask?.cancel()

        // Create new debounced task
        let task = Task { () -> [String] in
            // Wait for debounce delay
            try? await Task.sleep(for: .milliseconds(delayMs))

            // Check if cancelled
            if Task.isCancelled {
                return []
            }

            // Get predictions
            return await getPredictions(for: context, activeContext: activeContext)
        }

        pendingPredictionTask = task
        return await task.value
    }

    /// Legacy wrapper
    func getPredictions(for context: PredictionContext) async -> [String] {
        return await getPredictions(for: context, activeContext: nil)
    }

    // MARK: - Feedback Recording

    /// Record that user accepted a prediction
    func recordPredictionAccepted(_ prediction: String, previousWord: String?) async {
        await PredictionFeedback.shared.recordAccepted(prediction: prediction, previousWord: previousWord)
    }

    /// Record that user rejected predictions and typed something else
    func recordPredictionsRejected(_ predictions: [String], actuallyTyped: String, previousWord: String?) async {
        await PredictionFeedback.shared.recordRejected(
            predictions: predictions,
            actuallyTyped: actuallyTyped,
            previousWord: previousWord
        )
    }
}

// MARK: - Prediction Error
enum PredictionError: Error {
    case invalidResponse
    case apiError(statusCode: Int)
    case emptyResponse
}
