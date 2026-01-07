//
//  SessionRecencyTracker.swift
//  SwiftSpeakKeyboard
//
//  Tracks recently typed words in the current keyboard session
//  Provides recency boost for predictions - words typed recently score higher
//

import Foundation

/// Tracks words typed in the current keyboard session for recency boosting
actor SessionRecencyTracker {
    static let shared = SessionRecencyTracker()

    /// Recent words with timestamps (word -> last typed time)
    private var recentWords: [String: Date] = [:]

    /// Maximum words to track
    private let maxTrackedWords = 100

    /// How long words remain "recent" (5 minutes)
    private let recencyWindow: TimeInterval = 300

    private init() {}

    // MARK: - Recording

    /// Record that a word was typed
    func recordWord(_ word: String) {
        let normalized = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
        guard normalized.count >= 2 else { return }

        recentWords[normalized] = Date()

        // Prune old entries if exceeding max
        if recentWords.count > maxTrackedWords {
            pruneOldEntries()
        }
    }

    /// Record multiple words from inserted text
    func recordText(_ text: String) {
        let words = text.split(separator: " ").map(String.init)
        for word in words {
            recordWord(word)
        }
    }

    // MARK: - Boosting

    /// Get recency boost multiplier for a word (1.0 = no boost, up to 2.0 for very recent)
    func getRecencyBoost(for word: String) -> Double {
        let normalized = word.lowercased().trimmingCharacters(in: .punctuationCharacters)

        guard let lastTyped = recentWords[normalized] else {
            return 1.0  // No boost for unknown words
        }

        let age = Date().timeIntervalSince(lastTyped)

        // If older than recency window, no boost
        guard age < recencyWindow else {
            return 1.0
        }

        // Linear decay: 2.0x boost for just typed, 1.0x at recency window edge
        // boost = 2.0 - (age / recencyWindow)
        let boost = 2.0 - (age / recencyWindow)
        return max(1.0, boost)
    }

    /// Get recently typed words that match a prefix
    func getRecentWordsWithPrefix(_ prefix: String, maxResults: Int = 5) -> [String] {
        let normalizedPrefix = prefix.lowercased()
        let now = Date()

        // Filter recent words that match prefix and are within window
        let matching = recentWords
            .filter { word, lastTyped in
                word.hasPrefix(normalizedPrefix) &&
                word != normalizedPrefix &&
                now.timeIntervalSince(lastTyped) < recencyWindow
            }
            .sorted { $0.value > $1.value }  // Most recent first
            .prefix(maxResults)
            .map { $0.key }

        return Array(matching)
    }

    /// Get most recently typed words (for empty prefix predictions)
    func getMostRecentWords(maxResults: Int = 5) -> [String] {
        let now = Date()

        return recentWords
            .filter { now.timeIntervalSince($0.value) < recencyWindow }
            .sorted { $0.value > $1.value }
            .prefix(maxResults)
            .map { $0.key }
    }

    // MARK: - Session Management

    /// Clear session data (call when keyboard is dismissed)
    func clearSession() {
        recentWords.removeAll()
    }

    /// Prune entries older than recency window
    private func pruneOldEntries() {
        let now = Date()
        recentWords = recentWords.filter { now.timeIntervalSince($0.value) < recencyWindow }

        // If still over limit, remove oldest
        if recentWords.count > maxTrackedWords {
            let sorted = recentWords.sorted { $0.value > $1.value }
            recentWords = Dictionary(uniqueKeysWithValues: sorted.prefix(maxTrackedWords).map { ($0.key, $0.value) })
        }
    }
}
