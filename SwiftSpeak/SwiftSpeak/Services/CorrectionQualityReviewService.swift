//
//  CorrectionQualityReviewService.swift
//  SwiftSpeak
//
//  Service for reading and updating correction quality logs from main app.
//  Reads/writes the same JSON file used by keyboard extension.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Quality Rating (duplicate from keyboard, needed for decoding)

enum CorrectionQualityRating: String, Codable, CaseIterable {
    case pending = "pending"
    case good = "good"
    case bad = "bad"

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .good: return "Good"
        case .bad: return "Bad"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "circle"
        case .good: return "checkmark.circle.fill"
        case .bad: return "xmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .pending: return "gray"
        case .good: return "green"
        case .bad: return "red"
        }
    }
}

// MARK: - Correction Type

/// Type of correction event being logged
enum CorrectionType: String, Codable, CaseIterable {
    /// System automatically corrected the word
    case autocorrected = "autocorrected"
    /// System had a suggestion but didn't apply it (skipped)
    case skipped = "skipped"
    /// User manually reported a missed correction
    case reported = "reported"

    var displayName: String {
        switch self {
        case .autocorrected: return "Auto-corrected"
        case .skipped: return "Skipped"
        case .reported: return "Reported"
        }
    }

    var icon: String {
        switch self {
        case .autocorrected: return "arrow.right.circle.fill"
        case .skipped: return "hand.raised.fill"
        case .reported: return "flag.fill"
        }
    }

    var color: Color {
        switch self {
        case .autocorrected: return .blue
        case .skipped: return .orange
        case .reported: return .purple
        }
    }
}

// MARK: - Skip Reason

/// Reason why a correction was skipped
enum CorrectionSkipReason: String, Codable {
    case personalDictionary = "personal_dictionary"
    case ignoredCorrection = "ignored_correction"
    case noSuggestion = "no_suggestion"
    case other = "other"

    var displayName: String {
        switch self {
        case .personalDictionary: return "In personal dictionary"
        case .ignoredCorrection: return "Previously ignored"
        case .noSuggestion: return "No suggestion available"
        case .other: return "Other"
        }
    }
}

// MARK: - Quality Log Entry (duplicate from keyboard, needed for decoding)

struct CorrectionQualityEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let originalWord: String
    let correctedWord: String       // For skipped: the suggestion that wasn't applied
    let contextBefore: String
    let contextAfter: String
    let language: String
    let cursorPosition: Int
    let type: CorrectionType?       // Optional for backwards compatibility
    let skipReason: CorrectionSkipReason?  // Why it was skipped (if type == .skipped)
    var rating: CorrectionQualityRating
    var comment: String?

    /// Effective type (defaults to .autocorrected for old entries without type field)
    var effectiveType: CorrectionType {
        type ?? .autocorrected
    }

    /// Full context string for display: "...before [original→corrected] after..."
    var displayContext: String {
        let before = contextBefore.isEmpty ? "" : "...\(contextBefore) "
        let after = contextAfter.isEmpty ? "" : " \(contextAfter)..."
        return "\(before)[\(originalWord) → \(correctedWord)]\(after)"
    }

    /// Short display: "original → corrected"
    var shortDisplay: String {
        "\(originalWord) → \(correctedWord)"
    }
}

// MARK: - Review Service

@MainActor
class CorrectionQualityReviewService: ObservableObject {
    static let shared = CorrectionQualityReviewService()

    @Published var entries: [CorrectionQualityEntry] = []
    @Published var isLoading = false

    private let fileURL: URL

    private init() {
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.pawelgawliczek.swiftspeak"
        )!
        fileURL = containerURL.appendingPathComponent("correction_quality_log.json")
    }

    // MARK: - Loading

    func loadEntries() {
        isLoading = true
        defer { isLoading = false }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            entries = []
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            entries = try JSONDecoder().decode([CorrectionQualityEntry].self, from: data)
            // Sort by timestamp descending (most recent first)
            entries.sort { $0.timestamp > $1.timestamp }
            appLog("Loaded \(entries.count) correction quality entries", category: "CorrectionQuality")
        } catch {
            appLog("Failed to load correction quality log: \(error)", category: "CorrectionQuality", level: LogEntry.LogLevel.error)
            entries = []
        }
    }

    // MARK: - Updating

    func updateEntry(_ entry: CorrectionQualityEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            saveEntries()
        }
    }

    func setRating(_ rating: CorrectionQualityRating, for entryId: UUID) {
        if let index = entries.firstIndex(where: { $0.id == entryId }) {
            entries[index].rating = rating
            saveEntries()
        }
    }

    func setComment(_ comment: String?, for entryId: UUID) {
        if let index = entries.firstIndex(where: { $0.id == entryId }) {
            entries[index].comment = comment
            saveEntries()
        }
    }

    func clearAllEntries() {
        entries = []
        saveEntries()
    }

    // MARK: - Persistence

    private func saveEntries() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: .atomic)
            appLog("Saved \(entries.count) correction quality entries", category: "CorrectionQuality")
        } catch {
            appLog("Failed to save correction quality log: \(error)", category: "CorrectionQuality", level: LogEntry.LogLevel.error)
        }
    }

    // MARK: - Statistics

    var totalCount: Int { entries.count }
    var goodCount: Int { entries.filter { $0.rating == .good }.count }
    var badCount: Int { entries.filter { $0.rating == .bad }.count }
    var pendingCount: Int { entries.filter { $0.rating == .pending }.count }

    // Type-based statistics
    var autocorrectedCount: Int { entries.filter { $0.effectiveType == .autocorrected }.count }
    var skippedCount: Int { entries.filter { $0.effectiveType == .skipped }.count }
    var reportedCount: Int { entries.filter { $0.effectiveType == .reported }.count }

    var goodPercentage: Double {
        let rated = goodCount + badCount
        return rated > 0 ? Double(goodCount) / Double(rated) * 100 : 0
    }

    /// Filter entries by type
    func entries(ofType type: CorrectionType?) -> [CorrectionQualityEntry] {
        guard let type = type else { return entries }
        return entries.filter { $0.effectiveType == type }
    }

    // MARK: - Export

    /// Export entries as JSON string for sharing with Claude
    func exportAsJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(entries)
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            return "[]"
        }
    }

    /// Export only rated entries (good/bad) for focused review
    func exportRatedEntriesAsJSON() -> String {
        let rated = entries.filter { $0.rating != .pending }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(rated)
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            return "[]"
        }
    }
}
