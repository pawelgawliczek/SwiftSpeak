//
//  LogExporter.swift
//  SwiftSpeak
//
//  Exports logs from SharedLogManager into a shareable text file.
//  Includes device info header and privacy notice.
//

import Foundation
import SwiftSpeakCore
import UIKit

/// Exports logs for customer support
enum LogExporter {

    /// Time range options for export
    enum TimeRange {
        case currentSession
        case last1Hour
        case last24Hours
        case allTime

        var description: String {
            switch self {
            case .currentSession: return "Current Session"
            case .last1Hour: return "Last Hour"
            case .last24Hours: return "Last 24 Hours"
            case .allTime: return "All Time"
            }
        }

        var cutoffDate: Date? {
            switch self {
            case .currentSession: return nil // Will use app launch time
            case .last1Hour: return Date().addingTimeInterval(-3600)
            case .last24Hours: return Date().addingTimeInterval(-86400)
            case .allTime: return nil
            }
        }
    }

    /// Minimum log level for export
    enum MinLevel {
        case all
        case infoAndAbove
        case warningsAndErrors
        case errorsOnly

        var description: String {
            switch self {
            case .all: return "All Levels"
            case .infoAndAbove: return "Info & Above"
            case .warningsAndErrors: return "Warnings & Errors"
            case .errorsOnly: return "Errors Only"
            }
        }

        var logLevel: LogEntry.LogLevel? {
            switch self {
            case .all: return nil
            case .infoAndAbove: return .info
            case .warningsAndErrors: return .warning
            case .errorsOnly: return .error
            }
        }
    }

    // MARK: - Export

    /// Export logs to a temporary file and return the URL
    /// - Parameters:
    ///   - timeRange: Time range to include
    ///   - minLevel: Minimum log level
    /// - Returns: URL to the exported file, or nil if export failed
    static func exportLogs(
        timeRange: TimeRange = .last24Hours,
        minLevel: MinLevel = .all
    ) async -> URL? {
        let entries = await fetchEntries(timeRange: timeRange, minLevel: minLevel)
        let content = formatExport(entries: entries, timeRange: timeRange, minLevel: minLevel)

        // Create temporary file
        let fileName = "SwiftSpeak_Logs_\(formatDateForFilename(Date())).txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            return nil
        }
    }

    // MARK: - Private Methods

    private static func fetchEntries(
        timeRange: TimeRange,
        minLevel: MinLevel
    ) async -> [LogEntry] {
        var entries = await SharedLogManager.shared.readEntries()

        // Filter by time
        if let cutoff = timeRange.cutoffDate {
            entries = entries.filter { $0.timestamp >= cutoff }
        }

        // Filter by level
        if let minLogLevel = minLevel.logLevel {
            let levelOrder: [LogEntry.LogLevel] = [.debug, .info, .warning, .error]
            if let minIndex = levelOrder.firstIndex(of: minLogLevel) {
                let allowedLevels = Set(levelOrder[minIndex...])
                entries = entries.filter { allowedLevels.contains($0.level) }
            }
        }

        return entries.sorted { $0.timestamp < $1.timestamp }
    }

    private static func formatExport(
        entries: [LogEntry],
        timeRange: TimeRange,
        minLevel: MinLevel
    ) -> String {
        var lines: [String] = []

        // Header
        lines.append("═══════════════════════════════════════════════════════════")
        lines.append("                    SwiftSpeak Diagnostics                  ")
        lines.append("═══════════════════════════════════════════════════════════")
        lines.append("")

        // Metadata
        lines.append("Exported: \(formatDate(Date()))")
        lines.append("App Version: \(appVersion())")
        lines.append("iOS Version: \(UIDevice.current.systemVersion)")
        lines.append("Device: \(deviceModel())")
        lines.append("Time Range: \(timeRange.description)")
        lines.append("Log Level: \(minLevel.description)")
        lines.append("Entries: \(entries.count)")
        lines.append("")

        // Privacy Notice
        lines.append("───────────────────────────────────────────────────────────")
        lines.append("PRIVACY NOTICE: These logs contain only metadata.")
        lines.append("No dictation content, API keys, or personal information")
        lines.append("is recorded in these logs.")
        lines.append("───────────────────────────────────────────────────────────")
        lines.append("")

        // Log entries
        lines.append("═══════════════════════════════════════════════════════════")
        lines.append("                       Activity Log                         ")
        lines.append("═══════════════════════════════════════════════════════════")
        lines.append("")

        if entries.isEmpty {
            lines.append("(No log entries in the selected time range)")
        } else {
            for entry in entries {
                lines.append(entry.formatted)
            }
        }

        lines.append("")
        lines.append("═══════════════════════════════════════════════════════════")
        lines.append("                      End of Log File                       ")
        lines.append("═══════════════════════════════════════════════════════════")

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private static func formatDateForFilename(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }

    private static func appVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private static func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }

        // Map common model codes to names
        let modelMap: [String: String] = [
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone17,1": "iPhone 16 Pro",
            "iPhone17,2": "iPhone 16 Pro Max",
            "x86_64": "Simulator",
            "arm64": "Simulator (Apple Silicon)"
        ]

        if let code = modelCode, let name = modelMap[code] {
            return name
        }

        return modelCode ?? UIDevice.current.model
    }
}
