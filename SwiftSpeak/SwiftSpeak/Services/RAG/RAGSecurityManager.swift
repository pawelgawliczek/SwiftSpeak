//
//  RAGSecurityManager.swift
//  SwiftSpeak
//
//  Security layer for RAG document handling
//  Validates URLs, content, and enforces limits
//

import Foundation

// MARK: - Security Errors

enum RAGSecurityError: Error, LocalizedError {
    case domainNotWhitelisted(String)
    case documentTooLarge(Int64, maxAllowed: Int64)
    case unsupportedFileType(String)
    case maxDocumentsExceeded(Int, maxAllowed: Int)
    case invalidURL
    case contentSanitizationFailed
    case suspiciousContent(reason: String)

    var errorDescription: String? {
        switch self {
        case .domainNotWhitelisted(let domain):
            return "Domain '\(domain)' is not in the allowed list. Only trusted document sources are permitted."
        case .documentTooLarge(let size, let max):
            let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            let maxStr = ByteCountFormatter.string(fromByteCount: max, countStyle: .file)
            return "Document size (\(sizeStr)) exceeds maximum allowed (\(maxStr))."
        case .unsupportedFileType(let ext):
            return "File type '.\(ext)' is not supported. Allowed: PDF, TXT, MD."
        case .maxDocumentsExceeded(let count, let max):
            return "Cannot add more documents. You have \(count) of \(max) maximum allowed."
        case .invalidURL:
            return "The URL is invalid or malformed."
        case .contentSanitizationFailed:
            return "Document content could not be safely processed."
        case .suspiciousContent(let reason):
            return "Document contains suspicious content: \(reason)"
        }
    }

    var isRecoverable: Bool {
        switch self {
        case .domainNotWhitelisted, .documentTooLarge, .unsupportedFileType, .invalidURL:
            return false
        case .maxDocumentsExceeded:
            return true // User can delete other documents
        case .contentSanitizationFailed, .suspiciousContent:
            return false
        }
    }
}

// MARK: - Limits

struct RAGLimits {
    /// Maximum document size: 10 MB
    static let maxDocumentSize: Int64 = 10 * 1024 * 1024

    /// Maximum documents per Power Mode
    static let maxDocumentsPerPowerMode = 20

    /// Maximum total documents across all Power Modes
    static let maxTotalDocuments = 100

    /// Maximum chunk size in tokens (approximate)
    static let maxChunkTokens = 500

    /// Overlap between chunks in tokens
    static let chunkOverlapTokens = 50

    /// Maximum chunks to include in context
    static let maxContextChunks = 5

    /// Allowed file extensions
    static let allowedExtensions: Set<String> = ["pdf", "txt", "md", "markdown"]

    /// Maximum URL content size for remote documents
    static let maxRemoteContentSize: Int64 = 5 * 1024 * 1024 // 5 MB for remote
}

// MARK: - URL Whitelist

struct URLWhitelist {
    /// Domains allowed for remote document fetching
    /// Only well-known, trusted document sources
    static let allowedDomains: Set<String> = [
        // Cloud Storage
        "docs.google.com",
        "drive.google.com",
        "dropbox.com",
        "dl.dropboxusercontent.com",
        "onedrive.live.com",
        "1drv.ms",

        // Note Taking / Knowledge
        "notion.so",
        "notion.site",
        "evernote.com",
        "roamresearch.com",
        "obsidian.md",

        // Code Repositories
        "github.com",
        "raw.githubusercontent.com",
        "gist.github.com",
        "gitlab.com",
        "bitbucket.org",

        // Documentation
        "developer.apple.com",
        "docs.microsoft.com",
        "learn.microsoft.com",
        "developer.mozilla.org",
        "readthedocs.io",
        "gitbook.io",

        // Reference / Educational
        "wikipedia.org",
        "en.wikipedia.org",
        "medium.com",
        "arxiv.org",
        "stackoverflow.com",

        // Professional
        "confluence.atlassian.com",
        "sharepoint.com",
        "box.com"
    ]

    /// Check if a URL's domain is whitelisted
    static func isAllowed(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }

        // Check exact match
        if allowedDomains.contains(host) {
            return true
        }

        // Check if it's a subdomain of an allowed domain
        for domain in allowedDomains {
            if host.hasSuffix(".\(domain)") {
                return true
            }
        }

        return false
    }

    /// Get the blocked domain for error messages
    static func getDomain(from url: URL) -> String {
        url.host?.lowercased() ?? "unknown"
    }
}

// MARK: - Content Sanitizer

struct ContentSanitizer {
    /// Patterns that might indicate prompt injection attempts
    private static let suspiciousPatterns: [(pattern: String, reason: String)] = [
        // Direct instruction attempts
        ("ignore previous instructions", "Instruction override attempt"),
        ("ignore all previous", "Instruction override attempt"),
        ("disregard previous", "Instruction override attempt"),
        ("forget your instructions", "Instruction override attempt"),

        // Role manipulation
        ("you are now", "Role manipulation attempt"),
        ("act as if you", "Role manipulation attempt"),
        ("pretend you are", "Role manipulation attempt"),

        // System prompt extraction
        ("reveal your system prompt", "System prompt extraction"),
        ("show me your instructions", "System prompt extraction"),
        ("what are your instructions", "System prompt extraction"),

        // Code execution attempts (shouldn't be in documents)
        ("```javascript\\s*eval\\(", "Code execution attempt"),
        ("```python\\s*exec\\(", "Code execution attempt"),
        ("<script>", "Script injection attempt")
    ]

    /// Check content for suspicious patterns
    /// Returns nil if safe, or the reason if suspicious
    static func checkForSuspiciousContent(_ content: String) -> String? {
        let lowercased = content.lowercased()

        for (pattern, reason) in suspiciousPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(lowercased.startIndex..., in: lowercased)
                if regex.firstMatch(in: lowercased, options: [], range: range) != nil {
                    return reason
                }
            } else if lowercased.contains(pattern.lowercased()) {
                return reason
            }
        }

        return nil
    }

    /// Sanitize content by escaping potentially dangerous sequences
    static func sanitize(_ content: String) -> String {
        var sanitized = content

        // Escape triple backticks that might break out of markdown
        sanitized = sanitized.replacingOccurrences(of: "```", with: "'''")

        // Remove null bytes
        sanitized = sanitized.replacingOccurrences(of: "\0", with: "")

        // Normalize whitespace but preserve structure
        sanitized = sanitized.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")

        return sanitized
    }
}

// MARK: - RAG Security Manager

@MainActor
final class RAGSecurityManager {

    // MARK: - Singleton

    static let shared = RAGSecurityManager()

    private init() {}

    // MARK: - URL Validation

    /// Validate a URL for remote document fetching
    func validateURL(_ url: URL) throws {
        // Must be HTTPS
        guard url.scheme == "https" else {
            throw RAGSecurityError.invalidURL
        }

        // Must be from whitelisted domain
        guard URLWhitelist.isAllowed(url) else {
            throw RAGSecurityError.domainNotWhitelisted(URLWhitelist.getDomain(from: url))
        }
    }

    /// Validate URL string and return parsed URL if valid
    func validateURLString(_ urlString: String) throws -> URL {
        guard let url = URL(string: urlString) else {
            throw RAGSecurityError.invalidURL
        }
        try validateURL(url)
        return url
    }

    // MARK: - File Validation

    /// Validate a local file for document import
    func validateLocalFile(at url: URL) throws {
        // Check file extension
        let ext = url.pathExtension.lowercased()
        guard RAGLimits.allowedExtensions.contains(ext) else {
            throw RAGSecurityError.unsupportedFileType(ext)
        }

        // Check file size
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
        guard fileSize <= RAGLimits.maxDocumentSize else {
            throw RAGSecurityError.documentTooLarge(fileSize, maxAllowed: RAGLimits.maxDocumentSize)
        }
    }

    // MARK: - Content Validation

    /// Validate and sanitize document content
    func validateContent(_ content: String, fileSize: Int64? = nil) throws -> String {
        // Check size if provided
        if let size = fileSize, size > RAGLimits.maxDocumentSize {
            throw RAGSecurityError.documentTooLarge(size, maxAllowed: RAGLimits.maxDocumentSize)
        }

        // Check for suspicious content
        if let reason = ContentSanitizer.checkForSuspiciousContent(content) {
            throw RAGSecurityError.suspiciousContent(reason: reason)
        }

        // Sanitize and return
        return ContentSanitizer.sanitize(content)
    }

    // MARK: - Document Count Validation

    /// Check if adding a document would exceed limits
    func validateDocumentCount(
        currentPowerModeDocuments: Int,
        totalDocuments: Int
    ) throws {
        guard currentPowerModeDocuments < RAGLimits.maxDocumentsPerPowerMode else {
            throw RAGSecurityError.maxDocumentsExceeded(
                currentPowerModeDocuments,
                maxAllowed: RAGLimits.maxDocumentsPerPowerMode
            )
        }

        guard totalDocuments < RAGLimits.maxTotalDocuments else {
            throw RAGSecurityError.maxDocumentsExceeded(
                totalDocuments,
                maxAllowed: RAGLimits.maxTotalDocuments
            )
        }
    }

    // MARK: - Convenience

    /// Check if a domain is whitelisted (for UI display)
    func isDomainWhitelisted(_ domain: String) -> Bool {
        URLWhitelist.allowedDomains.contains(domain.lowercased()) ||
        URLWhitelist.allowedDomains.contains(where: { domain.lowercased().hasSuffix(".\($0)") })
    }

    /// Get list of whitelisted domains for UI display
    func getWhitelistedDomains() -> [String] {
        Array(URLWhitelist.allowedDomains).sorted()
    }
}
