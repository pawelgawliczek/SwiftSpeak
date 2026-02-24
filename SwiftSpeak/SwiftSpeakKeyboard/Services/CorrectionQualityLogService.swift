//
//  CorrectionQualityLogService.swift
//  SwiftSpeakKeyboard
//
//  Service for logging autocorrections with full context for quality review.
//  Stores corrections to a JSON file in App Group for main app access.
//

import Foundation

// MARK: - Quality Rating

enum CorrectionQualityRating: String, Codable, CaseIterable {
    case pending = "pending"
    case good = "good"
    case bad = "bad"
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

// MARK: - Quality Log Entry

struct CorrectionQualityEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let originalWord: String
    let correctedWord: String       // For skipped: the suggestion that wasn't applied
    let contextBefore: String       // ~5 words before the corrected word
    let contextAfter: String        // ~5 words after the corrected word
    let language: String
    let cursorPosition: Int
    let type: CorrectionType        // What kind of event this is
    let skipReason: CorrectionSkipReason?  // Why it was skipped (if type == .skipped)
    var rating: CorrectionQualityRating
    var comment: String?

    init(
        originalWord: String,
        correctedWord: String,
        contextBefore: String,
        contextAfter: String,
        language: String,
        cursorPosition: Int,
        type: CorrectionType = .autocorrected,
        skipReason: CorrectionSkipReason? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.originalWord = originalWord
        self.correctedWord = correctedWord
        self.contextBefore = contextBefore
        self.contextAfter = contextAfter
        self.language = language
        self.cursorPosition = cursorPosition
        self.type = type
        self.skipReason = skipReason
        self.rating = .pending
        self.comment = nil
    }

    /// Full context string for display: "...before [original→corrected] after..."
    var displayContext: String {
        let before = contextBefore.isEmpty ? "" : "...\(contextBefore) "
        let after = contextAfter.isEmpty ? "" : " \(contextAfter)..."
        return "\(before)[\(originalWord) → \(correctedWord)]\(after)"
    }
}

// MARK: - Quality Log Service

/// Service to log corrections with full context for quality review
/// Uses JSON file in App Group for persistence and main app access
final class CorrectionQualityLogService {
    static let shared = CorrectionQualityLogService()

    private let fileURL: URL
    private let maxEntries = 500  // Keep last 500 corrections
    private var entries: [CorrectionQualityEntry] = []
    private let queue = DispatchQueue(label: "com.swiftspeak.correctionqualitylog", qos: .utility)

    private init() {
        // Store in App Group for shared access
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier
        )!
        fileURL = containerURL.appendingPathComponent("correction_quality_log.json")

        loadEntries()
    }

    // MARK: - Logging (called from keyboard)

    /// Log an autocorrection with full context
    func logCorrection(
        original: String,
        corrected: String,
        fullTextBefore: String,
        language: String,
        cursorPosition: Int
    ) {
        logEntry(
            original: original,
            corrected: corrected,
            fullTextBefore: fullTextBefore,
            language: language,
            cursorPosition: cursorPosition,
            type: .autocorrected,
            skipReason: nil
        )

        keyboardLog(
            "Quality log [autocorrected]: '\(original)' → '\(corrected)' [lang: \(language)]",
            category: "CorrectionQuality"
        )
    }

    /// Log a skipped correction (system had suggestion but didn't apply)
    func logSkippedCorrection(
        original: String,
        suggestion: String,
        fullTextBefore: String,
        language: String,
        cursorPosition: Int,
        reason: CorrectionSkipReason
    ) {
        logEntry(
            original: original,
            corrected: suggestion,
            fullTextBefore: fullTextBefore,
            language: language,
            cursorPosition: cursorPosition,
            type: .skipped,
            skipReason: reason
        )

        keyboardLog(
            "Quality log [skipped]: '\(original)' (suggested: '\(suggestion)') reason: \(reason.rawValue) [lang: \(language)]",
            category: "CorrectionQuality"
        )
    }

    /// Log a user-reported missed correction
    func logReportedTypo(
        original: String,
        correctSpelling: String,
        fullTextBefore: String,
        language: String,
        cursorPosition: Int
    ) {
        logEntry(
            original: original,
            corrected: correctSpelling,
            fullTextBefore: fullTextBefore,
            language: language,
            cursorPosition: cursorPosition,
            type: .reported,
            skipReason: nil
        )

        keyboardLog(
            "Quality log [reported]: '\(original)' should be '\(correctSpelling)' [lang: \(language)]",
            category: "CorrectionQuality"
        )
    }

    /// Internal method to create and store an entry
    private func logEntry(
        original: String,
        corrected: String,
        fullTextBefore: String,
        language: String,
        cursorPosition: Int,
        type: CorrectionType,
        skipReason: CorrectionSkipReason?
    ) {
        // Extract context: ~5 words before the original word
        let contextBefore = extractContextBefore(from: fullTextBefore, excludingLastWord: original)

        // Context after is empty at time of correction (word was just typed)
        let contextAfter = ""

        let entry = CorrectionQualityEntry(
            originalWord: original,
            correctedWord: corrected,
            contextBefore: contextBefore,
            contextAfter: contextAfter,
            language: language,
            cursorPosition: cursorPosition,
            type: type,
            skipReason: skipReason
        )

        queue.async { [weak self] in
            self?.entries.append(entry)

            // Trim to max entries
            if let self = self, self.entries.count > self.maxEntries {
                self.entries = Array(self.entries.suffix(self.maxEntries))
            }

            self?.saveEntries()
        }
    }

    // MARK: - Context Extraction

    /// Extract ~5 words before the corrected word
    private func extractContextBefore(from text: String, excludingLastWord: String) -> String {
        // Remove the last word (the one being corrected) from the text
        var textWithoutWord = text
        if textWithoutWord.hasSuffix(excludingLastWord) {
            textWithoutWord = String(textWithoutWord.dropLast(excludingLastWord.count))
        }

        // Trim trailing whitespace
        textWithoutWord = textWithoutWord.trimmingCharacters(in: .whitespaces)

        // Split into words and take last 5
        let words = textWithoutWord.split(separator: " ", omittingEmptySubsequences: true)
        let contextWords = words.suffix(5)

        return contextWords.joined(separator: " ")
    }

    // MARK: - Persistence

    private func loadEntries() {
        queue.async { [weak self] in
            guard let self = self else { return }

            guard FileManager.default.fileExists(atPath: self.fileURL.path) else {
                self.entries = []
                return
            }

            do {
                let data = try Data(contentsOf: self.fileURL)
                self.entries = try JSONDecoder().decode([CorrectionQualityEntry].self, from: data)
                keyboardLog(
                    "Loaded \(self.entries.count) correction quality entries",
                    category: "CorrectionQuality"
                )
            } catch {
                keyboardLog(
                    "Failed to load correction quality log: \(error)",
                    category: "CorrectionQuality",
                    level: LogEntry.LogLevel.error
                )
                self.entries = []
            }
        }
    }

    private func saveEntries() {
        // Already on queue
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            keyboardLog(
                "Failed to save correction quality log: \(error)",
                category: "CorrectionQuality",
                level: LogEntry.LogLevel.error
            )
        }
    }

    // MARK: - Read Access (for main app via file URL)

    /// Get the file URL for main app to read
    static var logFileURL: URL {
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier
        )!
        return containerURL.appendingPathComponent("correction_quality_log.json")
    }
}
