//
//  PredictionFeedback.swift
//  SwiftSpeakKeyboard
//
//  Learning system that tracks prediction acceptance/rejection
//  Improves predictions over time based on user behavior
//

import Foundation

/// Tracks prediction feedback to improve accuracy over time
actor PredictionFeedback {
    static let shared = PredictionFeedback()

    private let appGroupID = "group.pawelgawliczek.swiftspeak"
    private let feedbackKey = "predictionFeedback"
    private let maxFeedbackItems = 500

    // Accepted predictions: word -> (acceptance count, last context)
    private var acceptedPredictions: [String: AcceptedPrediction] = [:]

    // Rejected predictions: word -> (rejection count, what user actually typed)
    private var rejectedPredictions: [String: RejectedPrediction] = [:]

    // Personal word boost: words user frequently accepts
    private var personalBoost: [String: Double] = [:]

    // Context-specific predictions: "previousWord_nextWord" -> count
    private var contextualPairs: [String: Int] = [:]

    private var isInitialized = false

    private init() {}

    // MARK: - Initialization

    func initialize() async {
        guard !isInitialized else { return }

        loadFeedback()
        isInitialized = true
        keyboardLog("PredictionFeedback initialized with \(acceptedPredictions.count) accepted patterns", category: "Prediction")
    }

    // MARK: - Recording Feedback

    /// Record when user accepts a prediction
    /// - Parameters:
    ///   - prediction: The predicted word that was tapped
    ///   - previousWord: The word before the prediction
    func recordAccepted(prediction: String, previousWord: String?) {
        let lowercased = prediction.lowercased()

        // Update accepted predictions
        var accepted = acceptedPredictions[lowercased] ?? AcceptedPrediction()
        accepted.count += 1
        accepted.lastUsed = Date()
        if let prev = previousWord?.lowercased() {
            accepted.contexts.insert(prev)
        }
        acceptedPredictions[lowercased] = accepted

        // Update personal boost
        personalBoost[lowercased] = min((personalBoost[lowercased] ?? 0) + 0.1, 2.0)

        // Update contextual pairs
        if let prev = previousWord?.lowercased() {
            let key = "\(prev)_\(lowercased)"
            contextualPairs[key, default: 0] += 1
        }

        // Remove from rejected if it was there
        rejectedPredictions.removeValue(forKey: lowercased)

        saveFeedbackDebounced()
    }

    /// Record when user rejects predictions (types something different)
    /// - Parameters:
    ///   - predictions: The predictions that were shown but not selected
    ///   - actuallyTyped: What the user actually typed
    ///   - previousWord: The word before
    func recordRejected(predictions: [String], actuallyTyped: String, previousWord: String?) {
        let typedLower = actuallyTyped.lowercased()

        for prediction in predictions {
            let predLower = prediction.lowercased()
            guard predLower != typedLower else { continue }

            // Update rejected predictions
            var rejected = rejectedPredictions[predLower] ?? RejectedPrediction()
            rejected.count += 1
            rejected.alternatives.insert(typedLower)
            rejectedPredictions[predLower] = rejected

            // Decrease boost for rejected word
            if let boost = personalBoost[predLower] {
                personalBoost[predLower] = max(boost - 0.05, -0.5)
            }
        }

        // Boost what user actually typed
        if typedLower.count >= 2 {
            personalBoost[typedLower] = min((personalBoost[typedLower] ?? 0) + 0.15, 2.0)

            // Record contextual pair
            if let prev = previousWord?.lowercased() {
                let key = "\(prev)_\(typedLower)"
                contextualPairs[key, default: 0] += 1
            }
        }

        saveFeedbackDebounced()
    }

    // MARK: - Getting Boost Values

    /// Get boost multiplier for a word based on user history
    func getBoost(for word: String) -> Double {
        let lowercased = word.lowercased()

        var boost = 1.0

        // Apply personal boost
        if let personalMultiplier = personalBoost[lowercased] {
            boost += personalMultiplier
        }

        // Apply acceptance frequency boost
        if let accepted = acceptedPredictions[lowercased] {
            let recencyBonus = min(Double(accepted.count) * 0.05, 0.5)
            boost += recencyBonus
        }

        // Apply rejection penalty
        if let rejected = rejectedPredictions[lowercased] {
            let penalty = min(Double(rejected.count) * 0.1, 0.8)
            boost -= penalty
        }

        return max(boost, 0.1)  // Never go below 0.1
    }

    /// Get contextual boost for a word following another word
    func getContextualBoost(for word: String, after previousWord: String) -> Double {
        let key = "\(previousWord.lowercased())_\(word.lowercased())"

        if let count = contextualPairs[key] {
            return min(1.0 + Double(count) * 0.2, 3.0)  // Up to 3x boost
        }

        return 1.0
    }

    /// Get words that user frequently types after a given word
    func getLearnedFollowWords(after previousWord: String, maxResults: Int = 5) -> [String] {
        let prefix = "\(previousWord.lowercased())_"

        let matches = contextualPairs
            .filter { $0.key.hasPrefix(prefix) }
            .sorted { $0.value > $1.value }
            .prefix(maxResults)
            .compactMap { key, _ -> String? in
                let parts = key.split(separator: "_")
                guard parts.count == 2 else { return nil }
                return String(parts[1]).capitalized
            }

        return Array(matches)
    }

    /// Get user's most frequently accepted words
    func getTopAcceptedWords(maxResults: Int = 20) -> [String] {
        return acceptedPredictions
            .sorted { $0.value.count > $1.value.count }
            .prefix(maxResults)
            .map { $0.key.capitalized }
    }

    // MARK: - Persistence

    private var savePending = false

    private func saveFeedbackDebounced() {
        guard !savePending else { return }
        savePending = true

        Task {
            try? await Task.sleep(for: .seconds(2))
            saveFeedback()
            savePending = false
        }
    }

    private func saveFeedback() {
        let data = FeedbackData(
            accepted: acceptedPredictions,
            rejected: rejectedPredictions,
            boost: personalBoost,
            contextual: contextualPairs
        )

        guard let encoded = try? JSONEncoder().encode(data),
              let defaults = UserDefaults(suiteName: appGroupID) else { return }

        defaults.set(encoded, forKey: feedbackKey)
    }

    private func loadFeedback() {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: feedbackKey),
              let decoded = try? JSONDecoder().decode(FeedbackData.self, from: data) else { return }

        acceptedPredictions = decoded.accepted
        rejectedPredictions = decoded.rejected
        personalBoost = decoded.boost
        contextualPairs = decoded.contextual

        // Prune old data
        pruneOldData()
    }

    private func pruneOldData() {
        // Remove accepted predictions older than 30 days
        let cutoffDate = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        acceptedPredictions = acceptedPredictions.filter { $0.value.lastUsed > cutoffDate }

        // Limit contextual pairs
        if contextualPairs.count > maxFeedbackItems {
            let sorted = contextualPairs.sorted { $0.value > $1.value }
            contextualPairs = Dictionary(uniqueKeysWithValues: sorted.prefix(maxFeedbackItems).map { ($0.key, $0.value) })
        }
    }
}

// MARK: - Data Models

private struct AcceptedPrediction: Codable {
    var count: Int = 0
    var lastUsed: Date = Date()
    var contexts: Set<String> = []  // Previous words that led to this prediction
}

private struct RejectedPrediction: Codable {
    var count: Int = 0
    var alternatives: Set<String> = []  // What user typed instead
}

private struct FeedbackData: Codable {
    var accepted: [String: AcceptedPrediction]
    var rejected: [String: RejectedPrediction]
    var boost: [String: Double]
    var contextual: [String: Int]
}
