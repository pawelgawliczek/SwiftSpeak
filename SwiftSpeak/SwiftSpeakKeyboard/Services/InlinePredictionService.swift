//
//  InlinePredictionService.swift
//  SwiftSpeakKeyboard
//
//  Service for generating inline AI predictions (ghost text).
//  Uses SwiftLink to communicate with main app for LLM calls.
//

import Foundation

/// Service for generating inline AI predictions
/// Keyboard extensions cannot make network calls directly, so this uses
/// SwiftLink (Darwin notifications + App Groups) to request predictions from main app
actor InlinePredictionService {

    // MARK: - Singleton

    static let shared = InlinePredictionService()

    // MARK: - State

    private var pendingTask: Task<String?, Error>?
    private var lastRequestTime: Date?

    // MARK: - Configuration

    /// Debounce delay before triggering prediction
    private let debounceDelay: TimeInterval = TimeInterval(Constants.InlinePrediction.debounceDelayMs) / 1000.0

    /// Maximum time to wait for prediction result
    private let maxWaitTime: TimeInterval = 5.0

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Generate a single sentence continuation
    /// - Parameters:
    ///   - typingContext: Current text being typed (before cursor)
    ///   - contextId: Optional active context ID
    ///   - contextName: Optional active context name
    /// - Returns: The predicted continuation text, or nil if cancelled/failed
    func generateContinuation(
        typingContext: String,
        contextId: UUID? = nil,
        contextName: String? = nil
    ) async throws -> String? {
        // Cancel any pending prediction
        pendingTask?.cancel()

        // Check debounce
        if let lastTime = lastRequestTime,
           Date().timeIntervalSince(lastTime) < debounceDelay {
            // Wait for debounce delay
            try await Task.sleep(for: .milliseconds(Int(debounceDelay * 1000)))
        }

        // Check if cancelled during debounce
        try Task.checkCancellation()

        lastRequestTime = Date()

        // Create the prediction task
        let task = Task { () -> String? in
            try await requestPrediction(
                typingContext: typingContext,
                contextId: contextId,
                contextName: contextName
            )
        }

        pendingTask = task

        return try await task.value
    }

    /// Cancel any pending prediction request
    func cancel() {
        pendingTask?.cancel()
        pendingTask = nil

        // Clear processing state in App Groups
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        defaults?.set(false, forKey: Constants.InlinePrediction.isProcessing)
        defaults?.removeObject(forKey: Constants.InlinePrediction.result)
        defaults?.removeObject(forKey: Constants.InlinePrediction.error)
        defaults?.synchronize()
    }

    // MARK: - Private

    /// Request prediction via SwiftLink
    private func requestPrediction(
        typingContext: String,
        contextId: UUID?,
        contextName: String?
    ) async throws -> String? {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        // Write request to App Groups
        defaults?.set(typingContext, forKey: Constants.InlinePrediction.context)
        defaults?.set(true, forKey: Constants.InlinePrediction.isProcessing)
        defaults?.removeObject(forKey: Constants.InlinePrediction.result)
        defaults?.removeObject(forKey: Constants.InlinePrediction.error)

        // Write context info if available
        if let contextId = contextId {
            defaults?.set(contextId.uuidString, forKey: Constants.SentencePrediction.activeContextId)
        }
        if let contextName = contextName {
            defaults?.set(contextName, forKey: Constants.SentencePrediction.activeContextName)
        }

        defaults?.synchronize()

        // Post Darwin notification to trigger main app
        DarwinNotificationManager.shared.post(name: Constants.InlinePredictionNotifications.requestPrediction)

        keyboardLog("Inline prediction requested: '\(typingContext.suffix(30))...'", category: "InlinePrediction")

        // Poll for result
        let startTime = Date()
        let pollInterval: TimeInterval = 0.1  // 100ms
        var processingCompletedAt: Date? = nil
        let postProcessingWaitTime: TimeInterval = 0.5  // Wait up to 500ms after processing completes for result to sync

        while Date().timeIntervalSince(startTime) < maxWaitTime {
            try Task.checkCancellation()

            try await Task.sleep(for: .milliseconds(Int(pollInterval * 1000)))

            defaults?.synchronize()

            // Check for result first (regardless of isProcessing flag)
            // This handles cases where result syncs before isProcessing flag
            if let result = defaults?.string(forKey: Constants.InlinePrediction.result), !result.isEmpty {
                keyboardLog("Inline prediction received: '\(result.prefix(50))...'", category: "InlinePrediction")

                // Clean up
                cleanupAppGroups(defaults: defaults)

                return result
            }

            // Check for error
            if let error = defaults?.string(forKey: Constants.InlinePrediction.error), !error.isEmpty {
                keyboardLog("Inline prediction error: \(error)", category: "InlinePrediction", level: .error)

                // Clean up
                cleanupAppGroups(defaults: defaults)

                throw InlinePredictionError.predictionFailed(error)
            }

            // Check if processing is complete
            let isProcessing = defaults?.bool(forKey: Constants.InlinePrediction.isProcessing) ?? true

            if !isProcessing {
                // Processing complete but no result yet - could be UserDefaults sync delay
                if processingCompletedAt == nil {
                    processingCompletedAt = Date()
                    keyboardLog("Processing complete, waiting for result to sync...", category: "InlinePrediction")
                } else if Date().timeIntervalSince(processingCompletedAt!) > postProcessingWaitTime {
                    // Waited long enough after processing completed - no result coming
                    keyboardLog("No result after waiting, treating as empty", category: "InlinePrediction")
                    cleanupAppGroups(defaults: defaults)
                    return nil
                }
                // Keep polling for the result
            }
        }

        // Timeout
        keyboardLog("Inline prediction timeout", category: "InlinePrediction", level: .warning)
        cleanupAppGroups(defaults: defaults)
        throw InlinePredictionError.timeout
    }

    private func cleanupAppGroups(defaults: UserDefaults?) {
        defaults?.removeObject(forKey: Constants.InlinePrediction.context)
        defaults?.removeObject(forKey: Constants.InlinePrediction.result)
        defaults?.removeObject(forKey: Constants.InlinePrediction.error)
        defaults?.set(false, forKey: Constants.InlinePrediction.isProcessing)
        defaults?.synchronize()
    }
}

// MARK: - Errors

enum InlinePredictionError: LocalizedError {
    case timeout
    case predictionFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Prediction timed out"
        case .predictionFailed(let message):
            return message
        case .cancelled:
            return "Prediction cancelled"
        }
    }
}
