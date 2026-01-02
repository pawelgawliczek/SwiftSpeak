//
//  AutocorrectHistoryService.swift
//  SwiftSpeakKeyboard
//
//  Tracks recent autocorrections for undo functionality
//  and maintains a personal dictionary of user-approved words
//

import Foundation

/// Represents a recent autocorrection that can be undone
struct AutocorrectEntry: Codable, Equatable {
    let originalWord: String      // What the user typed
    let correctedWord: String     // What it was corrected to
    let timestamp: Date           // When it was corrected
    let position: Int             // Character position in text (approximate)

    /// Check if this entry is recent (within last 30 seconds)
    var isRecent: Bool {
        Date().timeIntervalSince(timestamp) < 30
    }
}

/// Service to track autocorrections and manage personal dictionary
actor AutocorrectHistoryService {
    static let shared = AutocorrectHistoryService()

    /// Recent autocorrections (max 10, oldest first)
    private var recentCorrections: [AutocorrectEntry] = []
    private let maxRecentCorrections = 10

    /// Personal dictionary - words the user has marked as correct
    private var personalDictionary: Set<String> = []

    /// Words the user has explicitly rejected corrections for
    private var ignoredCorrections: [String: String] = [:] // original -> (don't correct to this)

    private init() {
        loadPersonalDictionary()
    }

    // MARK: - Recent Corrections (for Undo)

    /// Record a new autocorrection
    func recordCorrection(original: String, corrected: String, atPosition position: Int) {
        let entry = AutocorrectEntry(
            originalWord: original,
            correctedWord: corrected,
            timestamp: Date(),
            position: position
        )

        recentCorrections.append(entry)

        // Keep only recent entries
        if recentCorrections.count > maxRecentCorrections {
            recentCorrections.removeFirst()
        }

        // Remove old entries (older than 30 seconds)
        recentCorrections.removeAll { !$0.isRecent }

        keyboardLog("Recorded correction: '\(original)' → '\(corrected)'", category: "Autocorrect")
    }

    /// Get the most recent correction for a word at cursor position
    /// Returns the original word if found (so it can be shown in predictions)
    func getRecentCorrectionForUndo(correctedWord: String) -> String? {
        // Find most recent correction where the corrected word matches
        for entry in recentCorrections.reversed() {
            if entry.correctedWord.lowercased() == correctedWord.lowercased() && entry.isRecent {
                return entry.originalWord
            }
        }
        return nil
    }

    /// Clear a specific correction from history (after undo)
    func clearCorrection(original: String) {
        recentCorrections.removeAll { $0.originalWord.lowercased() == original.lowercased() }
    }

    /// Clear all recent corrections
    func clearAllCorrections() {
        recentCorrections.removeAll()
    }

    // MARK: - Personal Dictionary

    /// Add a word to personal dictionary (user approved it)
    func addToPersonalDictionary(_ word: String) {
        let lowercased = word.lowercased()
        personalDictionary.insert(lowercased)
        savePersonalDictionary()
        keyboardLog("Added '\(word)' to personal dictionary", category: "Autocorrect")
    }

    /// Check if a word is in personal dictionary
    func isInPersonalDictionary(_ word: String) -> Bool {
        personalDictionary.contains(word.lowercased())
    }

    /// Remove a word from personal dictionary
    func removeFromPersonalDictionary(_ word: String) {
        personalDictionary.remove(word.lowercased())
        savePersonalDictionary()
    }

    /// Get all personal dictionary words
    func allPersonalWords() -> Set<String> {
        return personalDictionary
    }

    // MARK: - Ignored Corrections

    /// Mark that a specific correction should be ignored
    /// (user typed "original" and we corrected to "corrected", but user wants "original")
    func ignoreCorrection(original: String, correctedTo: String) {
        ignoredCorrections[original.lowercased()] = correctedTo.lowercased()
        savePersonalDictionary()
        keyboardLog("Ignoring correction: '\(original)' should not become '\(correctedTo)'", category: "Autocorrect")
    }

    /// Check if a correction should be ignored
    func shouldIgnoreCorrection(original: String, correctedTo: String) -> Bool {
        guard let ignored = ignoredCorrections[original.lowercased()] else {
            return false
        }
        return ignored == correctedTo.lowercased()
    }

    // MARK: - Persistence

    private func loadPersonalDictionary() {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        // Load personal dictionary
        if let words = defaults?.stringArray(forKey: "personalDictionaryWords") {
            personalDictionary = Set(words)
        }

        // Load ignored corrections
        if let data = defaults?.data(forKey: "ignoredCorrections"),
           let ignored = try? JSONDecoder().decode([String: String].self, from: data) {
            ignoredCorrections = ignored
        }

        keyboardLog("Loaded personal dictionary: \(personalDictionary.count) words, \(ignoredCorrections.count) ignored corrections", category: "Autocorrect")
    }

    private func savePersonalDictionary() {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        // Save personal dictionary
        defaults?.set(Array(personalDictionary), forKey: "personalDictionaryWords")

        // Save ignored corrections
        if let data = try? JSONEncoder().encode(ignoredCorrections) {
            defaults?.set(data, forKey: "ignoredCorrections")
        }

        defaults?.synchronize()
    }
}
