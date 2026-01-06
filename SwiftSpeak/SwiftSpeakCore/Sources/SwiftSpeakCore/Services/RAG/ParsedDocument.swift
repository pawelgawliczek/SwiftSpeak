//
//  ParsedDocument.swift
//  SwiftSpeakCore
//
//  Models for parsed document content
//
//  SHARED: Used by iOS RAG, iOS Obsidian, and macOS Obsidian
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Parsed Document

/// Result of parsing a document
public struct ParsedDocument: Sendable {
    public let content: String
    public let metadata: ParsedDocumentMetadata
    public let pages: [ParsedPage]?

    public init(content: String, metadata: ParsedDocumentMetadata, pages: [ParsedPage]? = nil) {
        self.content = content
        self.metadata = metadata
        self.pages = pages
    }

    /// Total character count
    public var characterCount: Int {
        content.count
    }

    /// Estimated token count
    public var estimatedTokens: Int {
        content.count / 4
    }
}

// MARK: - Parsed Document Metadata

/// Metadata extracted from parsed document
public struct ParsedDocumentMetadata: Sendable {
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

// MARK: - Parsed Page

/// A single page from a multi-page document
public struct ParsedPage: Sendable {
    public let pageNumber: Int
    public let content: String
    #if canImport(CoreGraphics)
    public let bounds: CGRect?

    public init(pageNumber: Int, content: String, bounds: CGRect? = nil) {
        self.pageNumber = pageNumber
        self.content = content
        self.bounds = bounds
    }
    #else
    public init(pageNumber: Int, content: String) {
        self.pageNumber = pageNumber
        self.content = content
    }
    #endif
}

// MARK: - Document Parser Error

/// Errors that can occur during document parsing
public enum DocumentParserError: Error, LocalizedError, Sendable {
    case fileNotFound
    case unsupportedFormat(String)
    case parsingFailed(String)
    case emptyContent
    case securityViolation(String)

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
        case .securityViolation(let message):
            return message
        }
    }
}
