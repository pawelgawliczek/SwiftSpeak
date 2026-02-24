//
//  AIWordPredictionService.swift
//  SwiftSpeakKeyboard
//
//  Service for generating AI-powered word predictions.
//  Uses Darwin notifications + App Groups to communicate with main app for LLM calls.
//  Keyboard extensions cannot make network calls directly.
//

import Foundation

/// Service for generating AI-powered word predictions
/// Uses SwiftLink pattern: Darwin notifications + App Groups for IPC
actor AIWordPredictionService {

    // MARK: - Singleton

    static let shared = AIWordPredictionService()

    // MARK: - State

    private var pendingTask: Task<[String], Error>?
    private var lastRequestTime: Date?
    private var cachedPredictions: [String: (predictions: [String], timestamp: Date)] = [:]

    // MARK: - Configuration

    /// Debounce delay before triggering prediction (ms)
    private let debounceDelayMs: Int = 200

    /// Maximum time to wait for prediction result (seconds)
    private let maxWaitTime: TimeInterval = 3.0

    /// Cache duration (seconds) - predictions are cached to reduce API calls
    private let cacheDuration: TimeInterval = 30.0

    /// Maximum predictions to return
    private let maxPredictions: Int = 5

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Generate AI-powered word predictions
    /// - Parameters:
    ///   - prefix: Current word being typed (partial word)
    ///   - context: Full text context before the current word
    ///   - contextName: Optional active context name for styling
    ///   - language: Language code for predictions
    /// - Returns: Array of predicted words, or empty if cancelled/failed
    func getPredictions(
        prefix: String,
        context: String,
        contextName: String? = nil,
        language: String = "en"
    ) async -> [String] {
        // Check cache first
        let cacheKey = "\(context.suffix(100))|\(prefix)|\(language)"
        if let cached = cachedPredictions[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheDuration {
            keyboardLog("AI word prediction: using cache for '\(prefix)'", category: "AIPrediction")
            return cached.predictions
        }

        // Cancel any pending prediction
        pendingTask?.cancel()

        // Debounce check
        if let lastTime = lastRequestTime,
           Date().timeIntervalSince(lastTime) < Double(debounceDelayMs) / 1000.0 {
            do {
                try await Task.sleep(for: .milliseconds(debounceDelayMs))
            } catch {
                return []
            }
        }

        // Check if cancelled during debounce
        if Task.isCancelled { return [] }

        lastRequestTime = Date()

        // Create the prediction task
        let task = Task { () -> [String] in
            try await requestPrediction(
                prefix: prefix,
                context: context,
                contextName: contextName,
                language: language
            )
        }

        pendingTask = task

        do {
            let predictions = try await task.value

            // Cache successful predictions
            if !predictions.isEmpty {
                cachedPredictions[cacheKey] = (predictions, Date())

                // Clean old cache entries
                cleanCache()
            }

            return predictions
        } catch {
            keyboardLog("AI word prediction failed: \(error)", category: "AIPrediction", level: .error)
            return []
        }
    }

    /// Cancel any pending prediction request
    func cancel() {
        pendingTask?.cancel()
        pendingTask = nil

        // Clear processing state in App Groups
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        defaults?.set(false, forKey: Constants.Keys.aiWordPredictionIsProcessing)
        defaults?.removeObject(forKey: Constants.Keys.aiWordPredictionResults)
        defaults?.removeObject(forKey: Constants.Keys.aiWordPredictionError)
        defaults?.synchronize()
    }

    /// Clear the prediction cache
    func clearCache() {
        cachedPredictions.removeAll()
    }

    // MARK: - Private

    /// Request prediction via Darwin notification + App Groups
    private func requestPrediction(
        prefix: String,
        context: String,
        contextName: String?,
        language: String
    ) async throws -> [String] {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        // Write request to App Groups
        defaults?.set(prefix, forKey: Constants.Keys.aiWordPredictionPrefix)
        defaults?.set(context, forKey: Constants.Keys.aiWordPredictionContext)
        defaults?.set(language, forKey: Constants.Keys.aiWordPredictionLanguage)
        if let contextName = contextName {
            defaults?.set(contextName, forKey: Constants.Keys.aiWordPredictionContextName)
        } else {
            defaults?.removeObject(forKey: Constants.Keys.aiWordPredictionContextName)
        }
        defaults?.set(true, forKey: Constants.Keys.aiWordPredictionIsProcessing)
        defaults?.set(Date().timeIntervalSince1970, forKey: Constants.Keys.aiWordPredictionTimestamp)
        defaults?.removeObject(forKey: Constants.Keys.aiWordPredictionResults)
        defaults?.removeObject(forKey: Constants.Keys.aiWordPredictionError)
        defaults?.synchronize()

        // Post Darwin notification to trigger main app
        DarwinNotificationManager.shared.post(name: Constants.AIWordPredictionNotifications.requestPrediction)

        keyboardLog("AI word prediction requested: prefix='\(prefix)', context='\(context.suffix(30))...'", category: "AIPrediction")

        // Poll for result
        let startTime = Date()
        let pollInterval: TimeInterval = 0.05  // 50ms - faster polling for word predictions

        while Date().timeIntervalSince(startTime) < maxWaitTime {
            try Task.checkCancellation()

            try await Task.sleep(for: .milliseconds(Int(pollInterval * 1000)))

            defaults?.synchronize()

            // Check for result
            if let resultsData = defaults?.data(forKey: Constants.Keys.aiWordPredictionResults),
               let results = try? JSONDecoder().decode([String].self, from: resultsData) {
                keyboardLog("AI word prediction received: \(results.count) predictions", category: "AIPrediction")
                cleanupAppGroups(defaults: defaults)
                return results
            }

            // Check for error
            if let error = defaults?.string(forKey: Constants.Keys.aiWordPredictionError), !error.isEmpty {
                keyboardLog("AI word prediction error: \(error)", category: "AIPrediction", level: .error)
                cleanupAppGroups(defaults: defaults)
                throw AIWordPredictionError.predictionFailed(error)
            }

            // Check if processing is complete
            let isProcessing = defaults?.bool(forKey: Constants.Keys.aiWordPredictionIsProcessing) ?? true
            if !isProcessing {
                // Processing complete but no result - means no predictions
                keyboardLog("AI word prediction: no results", category: "AIPrediction")
                cleanupAppGroups(defaults: defaults)
                return []
            }
        }

        // Timeout
        keyboardLog("AI word prediction timeout", category: "AIPrediction", level: .warning)
        cleanupAppGroups(defaults: defaults)
        throw AIWordPredictionError.timeout
    }

    private func cleanupAppGroups(defaults: UserDefaults?) {
        defaults?.removeObject(forKey: Constants.Keys.aiWordPredictionPrefix)
        defaults?.removeObject(forKey: Constants.Keys.aiWordPredictionContext)
        defaults?.removeObject(forKey: Constants.Keys.aiWordPredictionContextName)
        defaults?.removeObject(forKey: Constants.Keys.aiWordPredictionLanguage)
        defaults?.removeObject(forKey: Constants.Keys.aiWordPredictionResults)
        defaults?.removeObject(forKey: Constants.Keys.aiWordPredictionError)
        defaults?.set(false, forKey: Constants.Keys.aiWordPredictionIsProcessing)
        defaults?.synchronize()
    }

    private func cleanCache() {
        let now = Date()
        cachedPredictions = cachedPredictions.filter { _, value in
            now.timeIntervalSince(value.timestamp) < cacheDuration
        }
    }
}

// MARK: - Errors

enum AIWordPredictionError: LocalizedError {
    case timeout
    case predictionFailed(String)
    case cancelled
    case noProvider

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Prediction timed out"
        case .predictionFailed(let message):
            return message
        case .cancelled:
            return "Prediction cancelled"
        case .noProvider:
            return "No AI provider configured"
        }
    }
}
