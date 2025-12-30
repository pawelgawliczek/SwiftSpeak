//
//  PromptSanitizer.swift
//  SwiftSpeak
//
//  Phase 11a: Prompt Injection Protection
//  Sanitizes user-controlled data before injecting into LLM prompts
//

import Foundation

/// Sanitizes user input to prevent prompt injection attacks
/// Apply at all injection points: vocabulary, context instructions, webhook data, RAG chunks
struct PromptSanitizer {

    // MARK: - Configuration

    /// Maximum length for different input types (in characters)
    struct Limits {
        static let vocabularyEntry = 100
        static let contextInstruction = 2000
        static let webhookData = 4000
        static let ragChunk = 8000
        static let userTranscription = 10000
        static let customTemplate = 2000
    }

    // MARK: - Injection Detection Patterns

    /// Patterns that indicate potential prompt injection attempts
    private static let injectionPatterns: [String] = [
        // XML/HTML tag manipulation
        "</context>", "</system>", "</user>", "</assistant>",
        "<system>", "<user>", "<assistant>",
        "<!--", "-->",

        // Instruction override attempts
        "ignore previous", "ignore all", "ignore above",
        "disregard previous", "disregard all", "disregard above",
        "forget previous", "forget all", "forget above",
        "override previous", "override all", "override above",

        // Role manipulation
        "you are now", "act as", "pretend to be",
        "from now on", "new instructions",
        "your new role", "your real purpose",

        // Prompt markers (various LLM formats)
        "[inst]", "[/inst]",
        "<<sys>>", "<</sys>>",
        "### instruction", "### system",
        "```system", "```instruction",

        // Jailbreak attempts
        "do anything now", "dan mode", "developer mode",
        "no restrictions", "bypass", "unlock",

        // Data extraction attempts
        "repeat after me", "echo back", "reveal your",
        "show me your", "print your", "output your",
        "what are your instructions", "what is your system prompt"
    ]

    /// Suspicious unicode that could be used for obfuscation
    private static let suspiciousUnicodeRanges: [ClosedRange<UInt32>] = [
        0x200B...0x200F,  // Zero-width characters
        0x2028...0x2029,  // Line/paragraph separators
        0xFEFF...0xFEFF,  // Byte order mark
        0x2060...0x206F,  // Invisible operators
        0xE0000...0xE007F // Tag characters
    ]

    // MARK: - Main Sanitization Methods

    /// Full sanitization pipeline for user input
    /// - Parameters:
    ///   - text: The text to sanitize
    ///   - maxLength: Maximum allowed length (uses type-specific default if nil)
    /// - Returns: Sanitized text safe for prompt injection
    static func sanitize(_ text: String, maxLength: Int? = nil) -> String {
        var result = text

        // 1. Normalize unicode (remove invisible characters, normalize forms)
        result = normalizeUnicode(result)

        // 2. Escape XML special characters
        result = escapeXML(result)

        // 3. Remove/neutralize injection patterns
        result = neutralizeInjectionPatterns(result)

        // 4. Truncate to max length
        if let maxLength = maxLength {
            result = truncate(result, maxLength: maxLength)
        }

        return result
    }

    /// Sanitize vocabulary replacement entries
    static func sanitizeVocabulary(_ text: String) -> String {
        sanitize(text, maxLength: Limits.vocabularyEntry)
    }

    /// Sanitize context custom instructions
    static func sanitizeContextInstruction(_ text: String) -> String {
        sanitize(text, maxLength: Limits.contextInstruction)
    }

    /// Sanitize webhook response data
    static func sanitizeWebhookData(_ text: String) -> String {
        sanitize(text, maxLength: Limits.webhookData)
    }

    /// Sanitize RAG document chunks
    static func sanitizeRAGChunk(_ text: String) -> String {
        sanitize(text, maxLength: Limits.ragChunk)
    }

    /// Sanitize custom template prompts
    static func sanitizeCustomTemplate(_ text: String) -> String {
        sanitize(text, maxLength: Limits.customTemplate)
    }

    // MARK: - XML Escaping

    /// Escape XML special characters to prevent tag injection
    static func escapeXML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    /// Unescape XML characters (for display, not for re-injection)
    static func unescapeXML(_ text: String) -> String {
        text.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }

    // MARK: - Injection Detection

    /// Detect potential prompt injection patterns in text
    /// - Parameter text: Text to analyze
    /// - Returns: True if injection patterns detected
    static func detectInjection(_ text: String) -> Bool {
        let lowercased = text.lowercased()

        // Check for known injection patterns
        for pattern in injectionPatterns {
            if lowercased.contains(pattern.lowercased()) {
                return true
            }
        }

        // Check for suspicious unicode
        if containsSuspiciousUnicode(text) {
            return true
        }

        // Check for excessive special characters (potential obfuscation)
        if hasExcessiveSpecialCharacters(text) {
            return true
        }

        return false
    }

    /// Get detailed injection analysis
    static func analyzeForInjection(_ text: String) -> InjectionAnalysis {
        var detectedPatterns: [String] = []
        var suspiciousElements: [String] = []

        let lowercased = text.lowercased()

        // Check patterns
        for pattern in injectionPatterns {
            if lowercased.contains(pattern.lowercased()) {
                detectedPatterns.append(pattern)
            }
        }

        // Check unicode
        if containsSuspiciousUnicode(text) {
            suspiciousElements.append("Invisible/control unicode characters")
        }

        // Check special characters
        if hasExcessiveSpecialCharacters(text) {
            suspiciousElements.append("Excessive special characters")
        }

        // Check for nested quotes/brackets
        if hasExcessiveNesting(text) {
            suspiciousElements.append("Excessive nesting of quotes/brackets")
        }

        return InjectionAnalysis(
            isClean: detectedPatterns.isEmpty && suspiciousElements.isEmpty,
            detectedPatterns: detectedPatterns,
            suspiciousElements: suspiciousElements,
            riskLevel: calculateRiskLevel(patterns: detectedPatterns.count, elements: suspiciousElements.count)
        )
    }

    // MARK: - Unicode Normalization

    /// Normalize unicode and remove invisible/control characters
    static func normalizeUnicode(_ text: String) -> String {
        var result = text

        // Normalize to NFC form
        result = result.precomposedStringWithCanonicalMapping

        // Remove suspicious unicode characters
        result = String(result.unicodeScalars.filter { scalar in
            !isSuspiciousUnicode(scalar)
        })

        // Collapse multiple whitespace into single space
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Truncation

    /// Truncate text to maximum length with ellipsis
    static func truncate(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }

        let truncated = String(text.prefix(maxLength - 3))
        return truncated + "..."
    }

    /// Truncate to approximate token count (4 chars ≈ 1 token)
    static func truncateToTokens(_ text: String, maxTokens: Int) -> String {
        let maxChars = maxTokens * 4
        return truncate(text, maxLength: maxChars)
    }

    // MARK: - Private Helpers

    /// Neutralize injection patterns by adding escape markers
    private static func neutralizeInjectionPatterns(_ text: String) -> String {
        var result = text

        // Add zero-width spaces to break up injection patterns
        // This preserves readability while breaking pattern matching
        for pattern in injectionPatterns {
            // Case-insensitive replacement with visible marker
            if let range = result.range(of: pattern, options: .caseInsensitive) {
                let matched = String(result[range])
                // Insert a visible marker to break the pattern
                let neutralized = matched.replacingOccurrences(of: " ", with: " [sanitized] ")
                result = result.replacingCharacters(in: range, with: neutralized)
            }
        }

        return result
    }

    /// Check if unicode scalar is suspicious
    private static func isSuspiciousUnicode(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        for range in suspiciousUnicodeRanges {
            if range.contains(value) {
                return true
            }
        }
        return false
    }

    /// Check if text contains suspicious unicode
    private static func containsSuspiciousUnicode(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if isSuspiciousUnicode(scalar) {
                return true
            }
        }
        return false
    }

    /// Check for excessive special characters (potential obfuscation)
    private static func hasExcessiveSpecialCharacters(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }

        let specialCharacters = text.filter { char in
            !char.isLetter && !char.isNumber && !char.isWhitespace && char != "." && char != "," && char != "!" && char != "?"
        }

        let ratio = Double(specialCharacters.count) / Double(text.count)
        return ratio > 0.3 // More than 30% special characters is suspicious
    }

    /// Check for excessive nesting of quotes/brackets
    private static func hasExcessiveNesting(_ text: String) -> Bool {
        var depth = 0
        var maxDepth = 0

        for char in text {
            switch char {
            case "(", "[", "{", "<":
                depth += 1
                maxDepth = max(maxDepth, depth)
            case ")", "]", "}", ">":
                depth = max(0, depth - 1)
            default:
                break
            }
        }

        return maxDepth > 5
    }

    /// Calculate risk level based on findings
    private static func calculateRiskLevel(patterns: Int, elements: Int) -> InjectionRiskLevel {
        let total = patterns + elements
        switch total {
        case 0:
            return .none
        case 1...2:
            return .low
        case 3...4:
            return .medium
        default:
            return .high
        }
    }
}

// MARK: - Supporting Types

/// Result of injection analysis
struct InjectionAnalysis {
    let isClean: Bool
    let detectedPatterns: [String]
    let suspiciousElements: [String]
    let riskLevel: InjectionRiskLevel

    var summary: String {
        if isClean {
            return "No injection patterns detected"
        }

        var parts: [String] = []
        if !detectedPatterns.isEmpty {
            parts.append("Patterns: \(detectedPatterns.joined(separator: ", "))")
        }
        if !suspiciousElements.isEmpty {
            parts.append("Suspicious: \(suspiciousElements.joined(separator: ", "))")
        }
        return parts.joined(separator: "; ")
    }
}

/// Risk level for injection attempts
enum InjectionRiskLevel: String, Codable {
    case none = "none"
    case low = "low"
    case medium = "medium"
    case high = "high"

    var displayName: String {
        switch self {
        case .none: return "Clean"
        case .low: return "Low Risk"
        case .medium: return "Medium Risk"
        case .high: return "High Risk"
        }
    }
}

// MARK: - Convenience Extensions

extension String {
    /// Sanitize this string for safe prompt injection
    var sanitizedForPrompt: String {
        PromptSanitizer.sanitize(self)
    }

    /// Check if this string contains injection patterns
    var containsInjectionPatterns: Bool {
        PromptSanitizer.detectInjection(self)
    }
}
