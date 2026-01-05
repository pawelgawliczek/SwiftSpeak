//
//  ObsidianSearch.swift
//  SwiftSpeakCore
//
//  Shared Obsidian search types for iOS and macOS
//
//  SHARED: This file is used by SwiftSpeak (iOS) and SwiftSpeakMac targets
//

import Foundation

// MARK: - Obsidian Search Result

/// Result from semantic search across Obsidian vaults
public struct ObsidianSearchResult: Identifiable, Sendable, Codable {
    public let id: UUID
    public let vaultId: UUID
    public let vaultName: String
    public let notePath: String
    public let noteTitle: String
    public let content: String
    public let similarity: Float

    public init(
        id: UUID = UUID(),
        vaultId: UUID,
        vaultName: String,
        notePath: String,
        noteTitle: String,
        content: String,
        similarity: Float
    ) {
        self.id = id
        self.vaultId = vaultId
        self.vaultName = vaultName
        self.notePath = notePath
        self.noteTitle = noteTitle
        self.content = content
        self.similarity = similarity
    }

    /// Similarity as percentage (0-100)
    public var similarityPercentage: Int {
        Int(similarity * 100)
    }
}

// MARK: - Obsidian Indexing Progress

/// Progress updates during vault indexing
public struct ObsidianIndexingProgress: Sendable {
    public let phase: Phase
    public let currentNote: String?
    public let notesProcessed: Int
    public let totalNotes: Int
    public let chunksGenerated: Int
    public let estimatedCost: Double

    public enum Phase: String, Sendable, CaseIterable {
        case scanning = "Scanning vault..."
        case parsing = "Parsing notes..."
        case chunking = "Chunking content..."
        case embedding = "Generating embeddings..."
        case complete = "Complete"
        case error = "Error"
    }

    public init(
        phase: Phase,
        currentNote: String? = nil,
        notesProcessed: Int = 0,
        totalNotes: Int = 0,
        chunksGenerated: Int = 0,
        estimatedCost: Double = 0
    ) {
        self.phase = phase
        self.currentNote = currentNote
        self.notesProcessed = notesProcessed
        self.totalNotes = totalNotes
        self.chunksGenerated = chunksGenerated
        self.estimatedCost = estimatedCost
    }

    /// Progress as fraction (0.0 - 1.0)
    public var progress: Double {
        guard totalNotes > 0 else { return 0 }
        return Double(notesProcessed) / Double(totalNotes)
    }
}

// MARK: - Obsidian Indexer Error

/// Errors that can occur during vault indexing
public enum ObsidianIndexerError: Error, LocalizedError, Sendable {
    case vaultNotFound(String)
    case notObsidianVault(String)
    case noMarkdownFiles
    case embeddingFailed(String)
    case apiError(String)
    case noEmbeddingProvider

    public var errorDescription: String? {
        switch self {
        case .vaultNotFound(let path):
            return "Vault folder not found: \(path)"
        case .notObsidianVault(let path):
            return "Not a valid Obsidian vault (missing .obsidian folder): \(path)"
        case .noMarkdownFiles:
            return "No markdown files found in vault"
        case .embeddingFailed(let message):
            return "Failed to generate embeddings: \(message)"
        case .apiError(let message):
            return "API error: \(message)"
        case .noEmbeddingProvider:
            return "No embedding provider configured. Add an OpenAI API key in Settings."
        }
    }
}

// MARK: - Obsidian Query Error

/// Errors that can occur during vault queries
public enum ObsidianQueryError: Error, LocalizedError, Sendable {
    case notConfigured
    case vaultNotFound(UUID)
    case queryFailed(String)
    case noVaultsSelected

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Obsidian query service is not configured."
        case .vaultNotFound(let id):
            return "Vault not found: \(id)"
        case .queryFailed(let reason):
            return "Query failed: \(reason)"
        case .noVaultsSelected:
            return "No vaults selected for query."
        }
    }
}

// MARK: - Obsidian Chunk

/// A chunk of text from an Obsidian note with its embedding
public struct ObsidianChunk: Identifiable, Sendable, Codable {
    public let id: UUID
    public let vaultId: UUID
    public let noteId: UUID
    public let notePath: String
    public let noteTitle: String
    public let content: String
    public let chunkIndex: Int
    public var embedding: [Float]?

    public init(
        id: UUID = UUID(),
        vaultId: UUID,
        noteId: UUID,
        notePath: String,
        noteTitle: String,
        content: String,
        chunkIndex: Int,
        embedding: [Float]? = nil
    ) {
        self.id = id
        self.vaultId = vaultId
        self.noteId = noteId
        self.notePath = notePath
        self.noteTitle = noteTitle
        self.content = content
        self.chunkIndex = chunkIndex
        self.embedding = embedding
    }
}
