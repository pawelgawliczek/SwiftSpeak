//
//  DocumentParser.swift
//  SwiftSpeak
//
//  Parses PDF, TXT, and MD documents into text content
//

import Foundation
import PDFKit

// MARK: - Parser Errors

public enum DocumentParserError: Error, LocalizedError {
    case fileNotFound
    case unsupportedFormat(String)
    case parsingFailed(String)
    case emptyContent
    case securityViolation(RAGSecurityError)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Document file not found."
        case .unsupportedFormat(let ext):
            return "Unsupported document format: .\(ext)"
        case .parsingFailed(let reason):
            return "Failed to parse document: \(reason)"
        case .emptyContent:
            return "Document contains no extractable text."
        case .securityViolation(let error):
            return error.errorDescription
        }
    }
}

// MARK: - Parsed Document

/// Result of parsing a document
public struct ParsedDocument {
    public let content: String
    public let metadata: ParsedDocumentMetadata
    public let pages: [ParsedPage]?

    /// Total character count
    public var characterCount: Int {
        content.count
    }

    /// Estimated token count
    public var estimatedTokens: Int {
        content.count / 4
    }
}

/// Metadata extracted from parsed document
public struct ParsedDocumentMetadata {
    public var title: String?
    public var author: String?
    public var subject: String?
    public var keywords: [String]
    public var creationDate: Date?
    public var modificationDate: Date?
    public var pageCount: Int?
    public var fileType: KnowledgeDocumentType

    public init(
        title: String? = nil,
        author: String? = nil,
        subject: String? = nil,
        keywords: [String] = [],
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        pageCount: Int? = nil,
        fileType: KnowledgeDocumentType = .text
    ) {
        self.title = title
        self.author = author
        self.subject = subject
        self.keywords = keywords
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.pageCount = pageCount
        self.fileType = fileType
    }
}

/// A single page from a multi-page document
public struct ParsedPage {
    public let pageNumber: Int
    public let content: String
    public let bounds: CGRect?
}

// MARK: - Document Parser

@MainActor
final class DocumentParser {

    // MARK: - Singleton

    public static let shared = DocumentParser()

    private let securityManager = RAGSecurityManager.shared

    private init() {}

    // MARK: - Public API

    /// Parse a document from a local file URL
    public func parse(fileURL: URL) async throws -> ParsedDocument {
        // Validate file security
        try securityManager.validateLocalFile(at: fileURL)

        // Check file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw DocumentParserError.fileNotFound
        }

        // Parse based on file type
        let ext = fileURL.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return try await parsePDF(at: fileURL)
        case "txt":
            return try await parseText(at: fileURL, type: .text)
        case "md", "markdown":
            return try await parseText(at: fileURL, type: .markdown)
        default:
            throw DocumentParserError.unsupportedFormat(ext)
        }
    }

    /// Parse document content from raw data
    public func parse(data: Data, filename: String) async throws -> ParsedDocument {
        let ext = (filename as NSString).pathExtension.lowercased()

        switch ext {
        case "pdf":
            return try await parsePDFData(data)
        case "txt":
            return try parseTextData(data, type: .text)
        case "md", "markdown":
            return try parseTextData(data, type: .markdown)
        default:
            throw DocumentParserError.unsupportedFormat(ext)
        }
    }

    /// Parse content fetched from a remote URL
    public func parseRemoteContent(_ content: String, from url: URL) async throws -> ParsedDocument {
        // Validate and sanitize content
        let sanitized = try securityManager.validateContent(
            content,
            fileSize: Int64(content.utf8.count)
        )

        guard !sanitized.isEmpty else {
            throw DocumentParserError.emptyContent
        }

        // Determine type from URL path
        let ext = url.pathExtension.lowercased()
        let type: KnowledgeDocumentType = ext == "md" || ext == "markdown" ? .markdown : .text

        let metadata = ParsedDocumentMetadata(
            title: url.lastPathComponent,
            fileType: type
        )

        return ParsedDocument(
            content: sanitized,
            metadata: metadata,
            pages: nil
        )
    }

    // MARK: - PDF Parsing

    private func parsePDF(at url: URL) async throws -> ParsedDocument {
        guard let document = PDFDocument(url: url) else {
            throw DocumentParserError.parsingFailed("Could not open PDF document")
        }

        return try await parsePDFDocument(document, filename: url.lastPathComponent)
    }

    private func parsePDFData(_ data: Data) async throws -> ParsedDocument {
        guard let document = PDFDocument(data: data) else {
            throw DocumentParserError.parsingFailed("Could not parse PDF data")
        }

        return try await parsePDFDocument(document, filename: nil)
    }

    private func parsePDFDocument(_ document: PDFDocument, filename: String?) async throws -> ParsedDocument {
        let pageCount = document.pageCount

        guard pageCount > 0 else {
            throw DocumentParserError.emptyContent
        }

        var allContent = ""
        var pages: [ParsedPage] = []

        for i in 0..<pageCount {
            guard let page = document.page(at: i) else { continue }

            let pageContent = page.string ?? ""
            let bounds = page.bounds(for: .mediaBox)

            pages.append(ParsedPage(
                pageNumber: i + 1,
                content: pageContent,
                bounds: bounds
            ))

            allContent += pageContent
            if i < pageCount - 1 {
                allContent += "\n\n"
            }
        }

        // Sanitize content
        let sanitized = try securityManager.validateContent(allContent)

        guard !sanitized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DocumentParserError.emptyContent
        }

        // Extract PDF metadata
        var metadata = ParsedDocumentMetadata(
            pageCount: pageCount,
            fileType: .pdf
        )

        if let attrs = document.documentAttributes {
            metadata.title = attrs[PDFDocumentAttribute.titleAttribute] as? String ?? filename
            metadata.author = attrs[PDFDocumentAttribute.authorAttribute] as? String
            metadata.subject = attrs[PDFDocumentAttribute.subjectAttribute] as? String

            if let keywordsString = attrs[PDFDocumentAttribute.keywordsAttribute] as? String {
                metadata.keywords = keywordsString.components(separatedBy: ",").map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
            }

            metadata.creationDate = attrs[PDFDocumentAttribute.creationDateAttribute] as? Date
            metadata.modificationDate = attrs[PDFDocumentAttribute.modificationDateAttribute] as? Date
        }

        return ParsedDocument(
            content: sanitized,
            metadata: metadata,
            pages: pages
        )
    }

    // MARK: - Text/Markdown Parsing

    private func parseText(at url: URL, type: KnowledgeDocumentType) async throws -> ParsedDocument {
        let content = try String(contentsOf: url, encoding: .utf8)

        // Sanitize content
        let sanitized = try securityManager.validateContent(content)

        guard !sanitized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DocumentParserError.emptyContent
        }

        // Extract title from first line if markdown
        var title: String? = url.deletingPathExtension().lastPathComponent
        if type == .markdown {
            title = extractMarkdownTitle(from: sanitized) ?? title
        }

        let metadata = ParsedDocumentMetadata(
            title: title,
            fileType: type
        )

        return ParsedDocument(
            content: sanitized,
            metadata: metadata,
            pages: nil
        )
    }

    private func parseTextData(_ data: Data, type: KnowledgeDocumentType) throws -> ParsedDocument {
        guard let content = String(data: data, encoding: .utf8) else {
            throw DocumentParserError.parsingFailed("Could not decode text content")
        }

        // Sanitize content
        let sanitized = try securityManager.validateContent(content)

        guard !sanitized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DocumentParserError.emptyContent
        }

        // Extract title from first line if markdown
        var title: String?
        if type == .markdown {
            title = extractMarkdownTitle(from: sanitized)
        }

        let metadata = ParsedDocumentMetadata(
            title: title,
            fileType: type
        )

        return ParsedDocument(
            content: sanitized,
            metadata: metadata,
            pages: nil
        )
    }

    // MARK: - Helpers

    /// Extract title from markdown content (first # heading)
    private func extractMarkdownTitle(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }

        return nil
    }

    /// Get file type from extension
    public func getFileType(from url: URL) -> KnowledgeDocumentType {
        switch url.pathExtension.lowercased() {
        case "pdf": return .pdf
        case "md", "markdown": return .markdown
        default: return .text
        }
    }
}
