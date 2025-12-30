//
//  LogSanitizer.swift
//  SwiftSpeak
//
//  Sanitizes log messages to remove sensitive data before logging.
//  CRITICAL: Never log user content, API keys, or PII.
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

/// Sanitizes log messages to ensure no sensitive data is logged.
/// Use this before any logging operation to protect user privacy.
enum LogSanitizer {

    // MARK: - API Key Patterns

    /// Patterns that indicate API keys (case insensitive)
    private static let apiKeyPatterns: [String] = [
        "sk-",           // OpenAI
        "sk-proj-",      // OpenAI project keys
        "sk-ant-",       // Anthropic
        "AIza",          // Google
        "key-",          // Generic
        "api_key",       // Generic
        "apikey",        // Generic
        "secret",        // Generic secrets
        "password",      // Passwords
        "token",         // Tokens
        "bearer",        // Bearer tokens
    ]

    // MARK: - Content Sanitization

    /// Sanitizes text content to show only character count
    /// - Parameter text: The text content (transcription, prompt, etc.)
    /// - Returns: Sanitized string like "[text: 42 chars]"
    static func sanitizeContent(_ text: String?) -> String {
        guard let text = text, !text.isEmpty else {
            return "[empty]"
        }
        return "[text: \(text.count) chars]"
    }

    /// Sanitizes audio information to show only duration
    /// - Parameter duration: Duration in seconds
    /// - Returns: Sanitized string like "[audio: 30.2s]"
    static func sanitizeAudio(duration: TimeInterval) -> String {
        return "[audio: \(String(format: "%.1f", duration))s]"
    }

    /// Sanitizes file information to show only filename
    /// - Parameter url: File URL
    /// - Returns: Sanitized string like "[file: document.pdf]"
    static func sanitizeFile(url: URL?) -> String {
        guard let url = url else {
            return "[file: unknown]"
        }
        return "[file: \(url.lastPathComponent)]"
    }

    // MARK: - API Key Sanitization

    /// Sanitizes an API key to hide the actual value
    /// - Parameter key: The API key
    /// - Returns: Masked key like "sk-***" or "configured"
    static func sanitizeAPIKey(_ key: String?) -> String {
        guard let key = key, !key.isEmpty else {
            return "not configured"
        }

        // Show first 3 characters if it looks like a known pattern
        for pattern in apiKeyPatterns {
            if key.lowercased().hasPrefix(pattern.lowercased()) {
                let prefix = String(key.prefix(min(pattern.count, 6)))
                return "\(prefix)***"
            }
        }

        return "configured"
    }

    // MARK: - Error Sanitization

    /// Sanitizes an error message to remove any embedded user content
    /// - Parameter error: The error
    /// - Returns: Safe error description
    static func sanitizeError(_ error: Error) -> String {
        let description = error.localizedDescription

        // If the error description is very long, it might contain user content
        if description.count > 200 {
            return "[\(type(of: error)): message truncated for privacy]"
        }

        // Check for common patterns that might indicate content leakage
        let suspiciousPatterns = ["transcription", "text:", "content:", "message:", "prompt:"]
        for pattern in suspiciousPatterns {
            if description.lowercased().contains(pattern) && description.count > 100 {
                return "[\(type(of: error)): \(pattern) error - details hidden]"
            }
        }

        return description
    }

    // MARK: - Generic Message Sanitization

    /// Sanitizes a generic log message, checking for potential sensitive data
    /// - Parameter message: The log message
    /// - Returns: Sanitized message
    static func sanitize(_ message: String) -> String {
        var sanitized = message

        // Redact anything that looks like an API key
        for pattern in apiKeyPatterns {
            if let range = sanitized.lowercased().range(of: pattern) {
                // Find the end of the potential key (next space or end of string)
                let startIndex = sanitized.index(range.lowerBound, offsetBy: 0, limitedBy: sanitized.endIndex) ?? range.lowerBound
                let endIndex = sanitized[startIndex...].firstIndex(of: " ") ?? sanitized.endIndex
                let keyRange = startIndex..<endIndex

                // Only redact if there's content after the pattern
                let keyRangeLength = sanitized.distance(from: keyRange.lowerBound, to: keyRange.upperBound)
                if keyRangeLength > pattern.count {
                    let prefix = String(sanitized[keyRange].prefix(min(6, pattern.count)))
                    sanitized.replaceSubrange(keyRange, with: "\(prefix)***")
                }
            }
        }

        return sanitized
    }

    // MARK: - Webhook Sanitization

    /// Sanitizes webhook information
    /// - Parameter name: Webhook name
    /// - Returns: Sanitized string
    static func sanitizeWebhook(name: String?) -> String {
        guard let name = name, !name.isEmpty else {
            return "[webhook: unnamed]"
        }
        return "[webhook: \(name)]"
    }

    // MARK: - Memory/Context Sanitization

    /// Sanitizes memory content
    /// - Parameter memory: Memory text
    /// - Returns: Sanitized string
    static func sanitizeMemory(_ memory: String?) -> String {
        guard let memory = memory, !memory.isEmpty else {
            return "[memory: empty]"
        }
        return "[memory: \(memory.count) chars]"
    }

    /// Sanitizes context name (name is safe, content is not)
    /// - Parameter name: Context name
    /// - Returns: Context name or placeholder
    static func sanitizeContext(name: String?) -> String {
        guard let name = name, !name.isEmpty else {
            return "[context: none]"
        }
        return name
    }

    // MARK: - Template Sanitization

    /// Sanitizes template information
    /// - Parameter name: Template name
    /// - Returns: Sanitized string
    static func sanitizeTemplate(name: String?) -> String {
        guard let name = name, !name.isEmpty else {
            return "[template: default]"
        }
        return "[template: \(name)]"
    }
}
