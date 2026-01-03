//
//  RAG.swift
//  SwiftSpeak
//
//  RAG (Retrieval-Augmented Generation) configuration models
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

// MARK: - RAG Configuration
/// User-configurable settings for RAG (per Power Mode)
public struct RAGConfiguration: Codable, Equatable, Hashable, Sendable {
    /// Chunking strategy for splitting documents
    public var chunkingStrategy: RAGChunkingStrategy

    /// Target chunk size in tokens
    public var maxChunkTokens: Int

    /// Overlap between chunks in tokens
    public var overlapTokens: Int

    /// Number of top chunks to include in context
    public var maxContextChunks: Int

    /// Minimum similarity score (0.0 - 1.0) for chunk retrieval
    public var similarityThreshold: Float

    /// Embedding model to use
    public var embeddingModel: RAGEmbeddingModel

    public static var `default`: RAGConfiguration {
        RAGConfiguration(
            chunkingStrategy: .semantic,
            maxChunkTokens: 500,
            overlapTokens: 50,
            maxContextChunks: 5,
            similarityThreshold: 0.7,
            embeddingModel: .openAISmall
        )
    }
}

/// Chunking strategy options
public enum RAGChunkingStrategy: String, Codable, CaseIterable, Hashable, Sendable {
    case semantic     // Split by paragraphs/sections
    case fixedSize    // Split by token count
    case sentence     // Split by sentences

    public var displayName: String {
        switch self {
        case .semantic: return "Semantic"
        case .fixedSize: return "Fixed Size"
        case .sentence: return "Sentence"
        }
    }

    public var description: String {
        switch self {
        case .semantic:
            return "Split by paragraphs and sections (recommended)"
        case .fixedSize:
            return "Split into fixed-size chunks"
        case .sentence:
            return "Split by individual sentences"
        }
    }
}

/// Embedding model options
public enum RAGEmbeddingModel: String, Codable, CaseIterable, Hashable, Sendable {
    case openAISmall = "text-embedding-3-small"
    case openAILarge = "text-embedding-3-large"

    public var displayName: String {
        switch self {
        case .openAISmall: return "OpenAI Small (Recommended)"
        case .openAILarge: return "OpenAI Large (Higher Quality)"
        }
    }

    public var dimensions: Int {
        switch self {
        case .openAISmall: return 1536
        case .openAILarge: return 3072
        }
    }

    public var costPer1MTokens: Double {
        switch self {
        case .openAISmall: return 0.02
        case .openAILarge: return 0.13
        }
    }
}
