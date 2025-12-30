//
//  Logging.swift
//  SwiftSpeak
//
//  Provides structured logging for the app using os.log framework.
//  All log messages go through LogSanitizer to protect user privacy.
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation
import os.log

// MARK: - Logger Extensions

extension Logger {
    /// Subsystem identifier for all SwiftSpeak logs
    private static let subsystem = "pawelgawliczek.SwiftSpeak"

    // MARK: - App Loggers (Main App)

    /// Logs for subscription-related events
    static let subscription = Logger(subsystem: subsystem, category: "Subscription")

    /// Logs for audio recording and session management
    static let audio = Logger(subsystem: subsystem, category: "Audio")

    /// Logs for transcription orchestration
    static let transcription = Logger(subsystem: subsystem, category: "Transcription")

    /// Logs for Power Mode execution
    static let powerMode = Logger(subsystem: subsystem, category: "PowerMode")

    /// Logs for RAG (knowledge base) operations
    static let rag = Logger(subsystem: subsystem, category: "RAG")

    /// Logs for data management (settings, history, retention)
    static let data = Logger(subsystem: subsystem, category: "Data")

    /// Logs for URL scheme handling and app navigation
    static let navigation = Logger(subsystem: subsystem, category: "Navigation")

    /// Logs for provider operations (API calls)
    static let provider = Logger(subsystem: subsystem, category: "Provider")

    // MARK: - Keyboard Logger

    /// Logs for keyboard extension events
    static let keyboard = Logger(subsystem: "pawelgawliczek.SwiftSpeak.SwiftSpeakKeyboard", category: "Keyboard")
}

// MARK: - Log Level Helpers

/// Convenience methods for consistent log formatting
extension Logger {

    /// Log an info message with sanitization
    func info(sanitized message: String) {
        self.info("\(LogSanitizer.sanitize(message), privacy: .public)")
    }

    /// Log a debug message with sanitization
    func debug(sanitized message: String) {
        self.debug("\(LogSanitizer.sanitize(message), privacy: .public)")
    }

    /// Log an error with sanitization
    func error(sanitized message: String) {
        self.error("\(LogSanitizer.sanitize(message), privacy: .public)")
    }

    /// Log a warning with sanitization
    func warning(sanitized message: String) {
        self.warning("\(LogSanitizer.sanitize(message), privacy: .public)")
    }
}
