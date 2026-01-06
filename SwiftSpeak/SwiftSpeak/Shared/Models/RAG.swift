//
//  RAG.swift
//  SwiftSpeak
//
//  RAG (Retrieval-Augmented Generation) configuration models
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation
import SwiftSpeakCore

// MARK: - RAG Configuration
/// User-configurable settings for RAG (per Power Mode)
struct RAGConfiguration: Codable, Equatable, Hashable, Sendable {
    /// Chunking strategy for splitting documents
    var chunkingStrategy: RAGChunkingStrategy

    /// Target chunk size in tokens
    var maxChunkTokens: Int

    /// Overlap between chunks in tokens
    var overlapTokens: Int

    /// Number of top chunks to include in context
    var maxContextChunks: Int

    /// Minimum similarity score (0.0 - 1.0) for chunk retrieval
    var similarityThreshold: Float

    /// Embedding model to use
    var embeddingModel: RAGEmbeddingModel

    static var `default`: RAGConfiguration {
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
enum RAGChunkingStrategy: String, Codable, CaseIterable, Hashable, Sendable {
    case semantic     // Split by paragraphs/sections
    case fixedSize    // Split by token count
    case sentence     // Split by sentences

    var displayName: String {
        switch self {
        case .semantic: return "Semantic"
        case .fixedSize: return "Fixed Size"
        case .sentence: return "Sentence"
        }
    }

    var description: String {
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
enum RAGEmbeddingModel: String, Codable, CaseIterable, Hashable, Sendable {
    case openAISmall = "text-embedding-3-small"
    case openAILarge = "text-embedding-3-large"

    var displayName: String {
        switch self {
        case .openAISmall: return "OpenAI Small (Recommended)"
        case .openAILarge: return "OpenAI Large (Higher Quality)"
        }
    }

    var dimensions: Int {
        switch self {
        case .openAISmall: return 1536
        case .openAILarge: return 3072
        }
    }

    var costPer1MTokens: Double {
        switch self {
        case .openAISmall: return 0.02
        case .openAILarge: return 0.13
        }
    }
}
