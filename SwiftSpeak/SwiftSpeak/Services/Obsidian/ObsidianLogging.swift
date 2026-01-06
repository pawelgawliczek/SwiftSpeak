//
//  ObsidianLogging.swift
//  SwiftSpeak
//
//  Cross-platform logging for Obsidian services
//  Works on both iOS (using appLog) and macOS (using print/NSLog)
//

import Foundation
import SwiftSpeakCore

#if os(macOS)

// MARK: - LogEntry Shim for macOS

/// Shim LogEntry type for macOS compatibility
enum LogEntry {
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
    }
}

// MARK: - appLog Shim for macOS

/// Shim for appLog on macOS - maps to print/NSLog
func appLog(_ message: String, category: String, level: LogEntry.LogLevel = .info) {
    let msg = "[Obsidian/\(category)] [\(level.rawValue)] \(message)"
    print(msg)
    NSLog("%@", msg)
}

#endif
