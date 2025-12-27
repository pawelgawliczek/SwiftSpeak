//
//  DocumentChunk.swift
//  SwiftSpeak
//
//  Model for document chunks with embeddings
//  Used for vector similarity search in RAG pipeline
//

import Foundation

// MARK: - Document Chunk

/// A chunk of document content with its embedding vector
struct DocumentChunk: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let documentId: UUID
    let index: Int
    let content: String
    let startOffset: Int
    let endOffset: Int
    let metadata: ChunkMetadata
    var embedding: [Float]?
    let createdAt: Date

    init(
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
    var estimatedTokens: Int {
        content.count / 4
    }

    /// Check if chunk has been embedded
    var isEmbedded: Bool {
        embedding != nil && !(embedding?.isEmpty ?? true)
    }
}

// MARK: - Chunk Metadata

/// Additional metadata about a document chunk
struct ChunkMetadata: Codable, Equatable, Sendable {
    /// Section or heading this chunk belongs to
    var section: String?

    /// Page number (for PDFs)
    var pageNumber: Int?

    /// Line numbers in source document
    var startLine: Int?
    var endLine: Int?

    /// Whether this is a header/title chunk
    var isHeader: Bool

    /// Semantic type of content
    var contentType: ChunkContentType

    init(
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
enum ChunkContentType: String, Codable, CaseIterable, Sendable {
    case paragraph
    case header
    case listItem
    case codeBlock
    case quote
    case table
    case footnote

    var icon: String {
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
struct SimilarityResult: Identifiable {
    let id: UUID
    let chunk: DocumentChunk
    let score: Float
    let documentName: String

    /// Human-readable similarity percentage
    var similarityPercentage: Int {
        Int(score * 100)
    }
}

// MARK: - Document Source

/// Source of a knowledge document
enum DocumentSource: Codable, Equatable {
    case local(URL)
    case remote(URL, lastFetched: Date?)

    var isRemote: Bool {
        if case .remote = self { return true }
        return false
    }

    var url: URL {
        switch self {
        case .local(let url): return url
        case .remote(let url, _): return url
        }
    }

    var displayName: String {
        switch self {
        case .local:
            return "Local File"
        case .remote(let url, _):
            return url.host ?? "Remote"
        }
    }
}

// Note: ChunkingStrategy and EmbeddingModel types are defined in Models.swift
// as RAGChunkingStrategy and RAGEmbeddingModel for use across the app
