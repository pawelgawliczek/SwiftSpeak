//
//  DocumentChunk.swift
//  SwiftSpeakCore
//
//  Model for document chunks with embeddings
//  Used for vector similarity search in RAG pipeline
//
//  SHARED: Used by iOS RAG, iOS Obsidian, and macOS Obsidian
//

import Foundation

// MARK: - Document Chunk

/// A chunk of document content with its embedding vector
public struct DocumentChunk: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let documentId: UUID
    public let index: Int
    public let content: String
    public let startOffset: Int
    public let endOffset: Int
    public let metadata: ChunkMetadata
    public var embedding: [Float]?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        documentId: UUID,
        index: Int,
        content: String,
        startOffset: Int,
        endOffset: Int,
        metadata: ChunkMetadata = ChunkMetadata(),
        embedding: [Float]? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.documentId = documentId
        self.index = index
        self.content = content
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.metadata = metadata
        self.embedding = embedding
        self.createdAt = createdAt
    }

    /// Approximate token count (rough estimate: 4 chars per token)
    public var estimatedTokens: Int {
        content.count / 4
    }

    /// Check if chunk has been embedded
    public var isEmbedded: Bool {
        embedding != nil && !(embedding?.isEmpty ?? true)
    }
}

// MARK: - Chunk Metadata

/// Additional metadata about a document chunk
public struct ChunkMetadata: Codable, Equatable, Sendable {
    /// Section or heading this chunk belongs to
    public var section: String?

    /// Page number (for PDFs)
    public var pageNumber: Int?

    /// Line numbers in source document
    public var startLine: Int?
    public var endLine: Int?

    /// Whether this is a header/title chunk
    public var isHeader: Bool

    /// Semantic type of content
    public var contentType: ChunkContentType

    public init(
        section: String? = nil,
        pageNumber: Int? = nil,
        startLine: Int? = nil,
        endLine: Int? = nil,
        isHeader: Bool = false,
        contentType: ChunkContentType = .paragraph
    ) {
        self.section = section
        self.pageNumber = pageNumber
        self.startLine = startLine
        self.endLine = endLine
        self.isHeader = isHeader
        self.contentType = contentType
    }
}

// MARK: - Chunk Content Type

/// Type of content in a chunk
public enum ChunkContentType: String, Codable, CaseIterable, Sendable {
    case paragraph
    case header
    case listItem
    case codeBlock
    case quote
    case table
    case footnote

    public var icon: String {
        switch self {
        case .paragraph: return "text.alignleft"
        case .header: return "textformat.size"
        case .listItem: return "list.bullet"
        case .codeBlock: return "chevron.left.forwardslash.chevron.right"
        case .quote: return "quote.opening"
        case .table: return "tablecells"
        case .footnote: return "note.text"
        }
    }
}

// MARK: - Similarity Result

/// Result of a similarity search
public struct SimilarityResult: Identifiable, Sendable {
    public let id: UUID
    public let chunk: DocumentChunk
    public let score: Float
    public let documentName: String

    public init(id: UUID = UUID(), chunk: DocumentChunk, score: Float, documentName: String) {
        self.id = id
        self.chunk = chunk
        self.score = score
        self.documentName = documentName
    }

    /// Human-readable similarity percentage
    public var similarityPercentage: Int {
        Int(score * 100)
    }
}

// MARK: - Document Source

/// Source of a knowledge document
public enum DocumentSource: Codable, Equatable, Sendable {
    case local(URL)
    case remote(URL, lastFetched: Date?)

    public var isRemote: Bool {
        if case .remote = self { return true }
        return false
    }

    public var url: URL {
        switch self {
        case .local(let url): return url
        case .remote(let url, _): return url
        }
    }

    public var displayName: String {
        switch self {
        case .local:
            return "Local File"
        case .remote(let url, _):
            return url.host ?? "Remote"
        }
    }
}

// MARK: - Embedding Error

/// Errors that can occur during embedding generation
public enum EmbeddingError: Error, LocalizedError, Sendable {
    case apiKeyMissing
    case invalidResponse
    case networkError(String)
    case apiError(String)
    case batchTooLarge(Int, maxAllowed: Int)
    case emptyInput

    public var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "OpenAI API key is not configured."
        case .invalidResponse:
            return "Invalid response from embedding API."
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let message):
            return "API error: \(message)"
        case .batchTooLarge(let count, let max):
            return "Batch size (\(count)) exceeds maximum (\(max))."
        case .emptyInput:
            return "Cannot generate embeddings for empty input."
        }
    }
}

// MARK: - Vector Store Error

/// Errors that can occur in vector store operations
public enum VectorStoreError: Error, LocalizedError, Sendable {
    case databaseNotOpen
    case databaseError(String)
    case documentNotFound(UUID)
    case chunkNotFound(UUID)
    case embeddingDimensionMismatch(expected: Int, got: Int)
    case serializationError

    public var errorDescription: String? {
        switch self {
        case .databaseNotOpen:
            return "Vector store database is not open."
        case .databaseError(let message):
            return "Database error: \(message)"
        case .documentNotFound(let id):
            return "Document not found: \(id)"
        case .chunkNotFound(let id):
            return "Chunk not found: \(id)"
        case .embeddingDimensionMismatch(let expected, let got):
            return "Embedding dimension mismatch: expected \(expected), got \(got)"
        case .serializationError:
            return "Failed to serialize/deserialize data."
        }
    }
}
