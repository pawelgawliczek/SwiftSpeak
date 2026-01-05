//
//  MacSharedLogManager.swift
//  SwiftSpeakMac
//
//  Provides unified file-based logging for macOS app.
//  Mirrors iOS SharedLogManager functionality for consistency.
//

import Foundation
import Combine
import os.log

// MARK: - Log Entry (mirrors iOS)

struct MacLogEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let source: String
    let category: String
    let level: MacLogLevel
    let message: String

    init(timestamp: Date = Date(), source: String = "macOS", category: String, level: MacLogLevel, message: String) {
        self.id = UUID()
        self.timestamp = timestamp
        self.source = source
        self.category = category
        self.level = level
        self.message = message
    }

    /// Formats the entry for display
    var formatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let time = formatter.string(from: timestamp)
        return "[\(time)] [\(level.rawValue)] [\(category)] \(message)"
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}

enum MacLogLevel: String, Codable, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"

    var color: String {
        switch self {
        case .debug: return "gray"
        case .info: return "primary"
        case .warning: return "orange"
        case .error: return "red"
        }
    }
}

// MARK: - Mac Shared Log Manager

@MainActor
final class MacSharedLogManager: ObservableObject {
    /// Singleton instance
    static let shared = MacSharedLogManager()

    /// Maximum number of log entries to keep
    private let maxEntries = 1000

    /// Maximum age of log entries (48 hours)
    private let maxAge: TimeInterval = 48 * 60 * 60

    /// Log file name
    private let logFileName = "swiftspeak_mac_logs.jsonl"

    /// Published logs for UI binding
    @Published private(set) var logs: [MacLogEntry] = []

    /// Last update time
    @Published private(set) var lastUpdate: Date?

    /// File URL for the log file
    private var logFileURL: URL? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let supportDir = appSupport?.appendingPathComponent("SwiftSpeakMac", isDirectory: true) else {
            return nil
        }

        // Create directory if needed
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)

        return supportDir.appendingPathComponent(logFileName)
    }

    private init() {
        loadLogs()
    }

    // MARK: - Logging Methods

    /// Log a debug message
    func debug(_ message: String, category: String) {
        log(message, category: category, level: .debug)
    }

    /// Log an info message
    func info(_ message: String, category: String) {
        log(message, category: category, level: .info)
    }

    /// Log a warning message
    func warning(_ message: String, category: String) {
        log(message, category: category, level: .warning)
    }

    /// Log an error message
    func error(_ message: String, category: String) {
        log(message, category: category, level: .error)
    }

    /// Log with specified level
    func log(_ message: String, category: String, level: MacLogLevel) {
        let entry = MacLogEntry(
            category: category,
            level: level,
            message: message
        )

        // Add to in-memory logs
        logs.append(entry)

        // Keep only recent logs in memory
        if logs.count > maxEntries {
            logs = Array(logs.suffix(maxEntries))
        }

        lastUpdate = Date()

        // Append to file
        appendEntry(entry)

        // Also log to os_log for Console.app visibility
        let osLog = OSLog(subsystem: "pawelgawliczek.SwiftSpeakMac", category: category)
        switch level {
        case .debug:
            os_log(.debug, log: osLog, "%{public}@", message)
        case .info:
            os_log(.info, log: osLog, "%{public}@", message)
        case .warning:
            os_log(.error, log: osLog, "[WARN] %{public}@", message)
        case .error:
            os_log(.fault, log: osLog, "[ERROR] %{public}@", message)
        }

        // Also print to stdout for Xcode console
        print("[\(category)] [\(level.rawValue)] \(message)")
    }

    // MARK: - File Operations

    /// Append an entry to the log file
    private func appendEntry(_ entry: MacLogEntry) {
        guard let url = logFileURL else { return }

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(entry)

            // Append as a single JSON line
            var lineData = data
            lineData.append(contentsOf: "\n".utf8)

            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
                try handle.write(contentsOf: lineData)
                try handle.close()
            } else {
                try lineData.write(to: url)
            }
        } catch {
            // Can't log the error (would cause infinite recursion)
            print("[LogManager] Failed to write log: \(error)")
        }
    }

    /// Load logs from file
    func loadLogs() {
        guard let url = logFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let lines = data.split(separator: UInt8(ascii: "\n"))
            let decoder = JSONDecoder()

            var entries: [MacLogEntry] = []
            for line in lines {
                if let entry = try? decoder.decode(MacLogEntry.self, from: Data(line)) {
                    entries.append(entry)
                }
            }

            logs = entries.sorted { $0.timestamp < $1.timestamp }
            lastUpdate = Date()
        } catch {
            print("[LogManager] Failed to load logs: \(error)")
        }
    }

    /// Get entries filtered by level
    func filteredLogs(minLevel: MacLogLevel, searchText: String = "", category: String? = nil) -> [MacLogEntry] {
        let levelOrder: [MacLogLevel] = [.debug, .info, .warning, .error]
        guard let minIndex = levelOrder.firstIndex(of: minLevel) else {
            return logs
        }
        let allowedLevels = Set(levelOrder[minIndex...])

        return logs.filter { entry in
            // Level filter
            guard allowedLevels.contains(entry.level) else { return false }

            // Category filter
            if let cat = category, !cat.isEmpty, entry.category != cat {
                return false
            }

            // Search filter
            if !searchText.isEmpty {
                return entry.message.localizedCaseInsensitiveContains(searchText) ||
                       entry.category.localizedCaseInsensitiveContains(searchText)
            }

            return true
        }
    }

    /// Get unique categories
    var categories: [String] {
        Array(Set(logs.map { $0.category })).sorted()
    }

    /// Clear all logs
    func clearLogs() {
        logs.removeAll()
        guard let url = logFileURL else { return }
        try? FileManager.default.removeItem(at: url)
        lastUpdate = Date()
    }

    /// Get the log file size in bytes
    func logFileSize() -> Int64 {
        guard let url = logFileURL,
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return 0
        }
        return size
    }

    /// Export logs as text
    func exportLogs() -> String {
        logs.map { $0.formatted }.joined(separator: "\n")
    }
}

// MARK: - Convenience Global Function for macOS

/// Log from the macOS app - use this instead of print() or NSLog()
func macLog(_ message: String, category: String, level: MacLogLevel = .info) {
    Task { @MainActor in
        MacSharedLogManager.shared.log(message, category: category, level: level)
    }
}
