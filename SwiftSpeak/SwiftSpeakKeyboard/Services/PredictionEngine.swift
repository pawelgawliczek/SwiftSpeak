//
//  PredictionEngine.swift
//  SwiftSpeakKeyboard
//
//  AI-powered prediction engine for smart word suggestions (Phase 13.6)
//  Combines local vocabulary matching with LLM-powered predictions
//

import Foundation

// MARK: - Prediction Engine
actor PredictionEngine {
    private let appGroupID = "group.pawelgawliczek.swiftspeak"
    private var vocabulary: [String] = []
    private var recentWords: [String] = []
    private var frequentWords: [String: Int] = [:]
    private var lastLLMRequest: Date?
    private let llmCooldown: TimeInterval = 1.0  // Minimum time between LLM requests

    // MARK: - Initialization

    init() {
        Task {
            await loadVocabulary()
        }
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

        // Load recent transcriptions to build frequent words
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

    /// Get predictions based on local vocabulary and frequent words
    func localPredictions(for context: PredictionContext) -> [String] {
        var predictions: [Prediction] = []

        let searchTerm = context.currentWord.lowercased()

        // If current word is empty, suggest most frequent words
        if searchTerm.isEmpty {
            let topFrequent = frequentWords
                .sorted { $0.value > $1.value }
                .prefix(3)
                .map { $0.key.capitalized }

            return topFrequent
        }

        // Search vocabulary for prefix matches
        for word in vocabulary {
            if word.lowercased().hasPrefix(searchTerm) && word.lowercased() != searchTerm {
                predictions.append(Prediction(
                    text: word,
                    source: .vocabulary,
                    confidence: 1.0
                ))
            }
        }

        // Search frequent words for prefix matches
        for (word, count) in frequentWords {
            if word.hasPrefix(searchTerm) && word != searchTerm {
                let confidence = Double(count) / 10.0  // Normalize by count
                predictions.append(Prediction(
                    text: word.capitalized,
                    source: .frequent,
                    confidence: min(confidence, 1.0)
                ))
            }
        }

        // Sort by confidence and return top 3
        let sorted = predictions
            .sorted { $0.confidence > $1.confidence }
            .prefix(3)
            .map { $0.text }

        return Array(sorted)
    }

    // MARK: - LLM Predictions

    /// Get predictions from configured AI provider
    func llmPredictions(for context: PredictionContext) async -> [String] {
        // Check cooldown to avoid too frequent API calls
        if let lastRequest = lastLLMRequest,
           Date().timeIntervalSince(lastRequest) < llmCooldown {
            keyboardLog("PredictionEngine: LLM cooldown active", category: "Prediction")
            return localPredictions(for: context)
        }

        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return localPredictions(for: context)
        }

        // Check for configured provider
        guard let apiKey = defaults.string(forKey: Constants.Keys.openAIAPIKey),
              !apiKey.isEmpty else {
            keyboardLog("PredictionEngine: No API key configured", category: "Prediction")
            return localPredictions(for: context)
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
                return localPredictions(for: context)
            }

            keyboardLog("PredictionEngine: LLM returned \(predictions.count) predictions", category: "Prediction")
            return predictions

        } catch {
            keyboardLog("PredictionEngine: LLM error - \(error.localizedDescription)", category: "Prediction", level: .error)
            return localPredictions(for: context)
        }
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

    /// Get predictions for the current typing context
    func getPredictions(for context: PredictionContext) async -> [String] {
        if context.shouldUseLLM {
            return await llmPredictions(for: context)
        }
        return localPredictions(for: context)
    }
}

// MARK: - Prediction Error
enum PredictionError: Error {
    case invalidResponse
    case apiError(statusCode: Int)
    case emptyResponse
}
