//
//  SharedLogManager.swift
//  SwiftSpeak
//
//  Provides unified file-based logging accessible by both main app and keyboard extension.
//  Uses App Groups to share logs between processes.
//  All log entries are sanitized before writing.
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation
import os.log

// MARK: - Log Entry

/// A single log entry with metadata
struct LogEntry: Codable {
    let timestamp: Date
    let source: LogSource
    let category: String
    let level: LogLevel
    let message: String

    enum LogSource: String, Codable {
        case app = "App"
        case keyboard = "Keyboard"
    }

    enum LogLevel: String, Codable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
    }

    /// Formats the entry for display
    var formatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let time = formatter.string(from: timestamp)
        return "[\(time)] [\(source.rawValue)] [\(category)] \(message)"
    }
}

// MARK: - Shared Log Manager

/// Thread-safe log manager that writes to App Groups shared storage
actor SharedLogManager {
    /// Singleton instance
    static let shared = SharedLogManager()

    /// Flag to skip logging during keyboard initialization
    /// Set to true after keyboard fully appears to prevent fire-and-forget Task crashes
    static var isInitialized = false

    /// Maximum number of log entries to keep
    private let maxEntries = 500

    /// Maximum age of log entries (24 hours)
    private let maxAge: TimeInterval = 24 * 60 * 60

    /// Log file name
    private let logFileName = "swiftspeak_logs.jsonl"

    /// Current source (set based on which target is running)
    private var source: LogEntry.LogSource = .app

    /// File URL for the log file
    private var logFileURL: URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier
        ) else {
            return nil
        }
        return containerURL.appendingPathComponent(logFileName)
    }

    private init() {}

    // MARK: - Configuration

    /// Set the source for log entries (call once at startup)
    func setSource(_ source: LogEntry.LogSource) {
        self.source = source
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
    private func log(_ message: String, category: String, level: LogEntry.LogLevel) {
        // Sanitize the message
        let sanitizedMessage = LogSanitizer.sanitize(message)

        let entry = LogEntry(
            timestamp: Date(),
            source: source,
            category: category,
            level: level,
            message: sanitizedMessage
        )

        appendEntry(entry)
    }

    // MARK: - File Operations

    /// Append an entry to the log file
    private func appendEntry(_ entry: LogEntry) {
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

            // Periodically prune old entries
            if Int.random(in: 0..<100) == 0 {
                Task {
                    await pruneOldEntries()
                }
            }
        } catch {
            // Can't log the error (would cause infinite recursion), just silently fail
        }
    }

    /// Read all log entries
    func readEntries() -> [LogEntry] {
        guard let url = logFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let lines = data.split(separator: UInt8(ascii: "\n"))
            let decoder = JSONDecoder()

            var entries: [LogEntry] = []
            for line in lines {
                if let entry = try? decoder.decode(LogEntry.self, from: Data(line)) {
                    entries.append(entry)
                }
            }

            return entries.sorted { $0.timestamp < $1.timestamp }
        } catch {
            return []
        }
    }

    /// Get entries filtered by time range
    func readEntries(since date: Date) -> [LogEntry] {
        return readEntries().filter { $0.timestamp >= date }
    }

    /// Get entries filtered by level
    func readEntries(minLevel: LogEntry.LogLevel) -> [LogEntry] {
        let levelOrder: [LogEntry.LogLevel] = [.debug, .info, .warning, .error]
        guard let minIndex = levelOrder.firstIndex(of: minLevel) else {
            return readEntries()
        }
        let allowedLevels = Set(levelOrder[minIndex...])
        return readEntries().filter { allowedLevels.contains($0.level) }
    }

    /// Prune old entries to maintain size limits
    private func pruneOldEntries() {
        guard let url = logFileURL else { return }

        var entries = readEntries()
        let cutoffDate = Date().addingTimeInterval(-maxAge)

        // Remove entries older than maxAge
        entries = entries.filter { $0.timestamp >= cutoffDate }

        // Keep only the last maxEntries
        if entries.count > maxEntries {
            entries = Array(entries.suffix(maxEntries))
        }

        // Rewrite the file
        do {
            let encoder = JSONEncoder()
            var data = Data()
            for entry in entries {
                if let entryData = try? encoder.encode(entry) {
                    data.append(entryData)
                    data.append(contentsOf: "\n".utf8)
                }
            }
            try data.write(to: url)
        } catch {
            // Silently fail
        }
    }

    /// Clear all logs
    func clearLogs() {
        guard let url = logFileURL else { return }
        try? FileManager.default.removeItem(at: url)
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
}

// MARK: - Convenience Global Functions

/// Log from the main app
func appLog(_ message: String, category: String, level: LogEntry.LogLevel = .info) {
    Task {
        await SharedLogManager.shared.setSource(.app)
        switch level {
        case .debug:
            await SharedLogManager.shared.debug(message, category: category)
        case .info:
            await SharedLogManager.shared.info(message, category: category)
        case .warning:
            await SharedLogManager.shared.warning(message, category: category)
        case .error:
            await SharedLogManager.shared.error(message, category: category)
        }
    }
}

/// TEMPORARY: Disable all keyboard logging to diagnose if logging is causing crashes
/// Set to false to enable logging for diagnosis
private let disableKeyboardLogging = false

/// Serial queue for async logging
private let keyboardLogQueue = DispatchQueue(label: "swiftspeak.keyboard.log", qos: .utility)

/// Log from the keyboard extension
/// TEMPORARILY DISABLED for crash diagnosis
func keyboardLog(_ message: String, category: String, level: LogEntry.LogLevel = .info) {
    // DIAGNOSTIC: Skip all logging to test if keyboard loads without it
    guard !disableKeyboardLogging else { return }

    // Use async to avoid blocking
    keyboardLogQueue.async {
        // Write directly to log file without actor isolation
        let sanitizedMessage = LogSanitizer.sanitize(message)

        let entry = LogEntry(
            timestamp: Date(),
            source: .keyboard,
            category: category,
            level: level,
            message: sanitizedMessage
        )

        // Format as JSONL and append to file
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier
        ) else { return }

        let logFileURL = containerURL.appendingPathComponent("swiftspeak_logs.jsonl")

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(entry)
            var lineData = data
            lineData.append(contentsOf: "\n".utf8)

            if FileManager.default.fileExists(atPath: logFileURL.path) {
                let handle = try FileHandle(forWritingTo: logFileURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: lineData)
                try handle.close()
            } else {
                try lineData.write(to: logFileURL)
            }
        } catch {
            // Silently fail - can't log errors from logging
        }
    }
}
