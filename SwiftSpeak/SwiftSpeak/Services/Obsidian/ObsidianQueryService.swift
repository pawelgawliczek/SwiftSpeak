//
//  ObsidianQueryService.swift
//  SwiftSpeak
//
//  Query service for searching across Obsidian vaults
//  Phase 3: Enables voice queries against indexed vault contents
//

import Foundation
import SwiftSpeakCore

// MARK: - Query Service Errors

enum ObsidianQueryError: Error, LocalizedError {
    case notConfigured
    case vaultNotFound(UUID)
    case queryFailed(String)
    case noVaultsSelected

    var errorDescription: String? {
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

// MARK: - Obsidian Search Result

/// Result of an Obsidian vault search with full metadata
struct ObsidianSearchResult: Sendable, Identifiable {
    let id: UUID
    let vaultId: UUID
    let vaultName: String
    let noteId: UUID
    let notePath: String
    let noteTitle: String
    let chunkContent: String
    let similarity: Float

    /// Human-readable similarity percentage
    var similarityPercentage: Int {
        Int(similarity * 100)
    }

    init(
        id: UUID = UUID(),
        vaultId: UUID,
        vaultName: String,
        noteId: UUID,
        notePath: String,
        noteTitle: String,
        chunkContent: String,
        similarity: Float
    ) {
        self.id = id
        self.vaultId = vaultId
        self.vaultName = vaultName
        self.noteId = noteId
        self.notePath = notePath
        self.noteTitle = noteTitle
        self.chunkContent = chunkContent
        self.similarity = similarity
    }
}

// MARK: - Obsidian Query Service

/// Service for querying Obsidian vaults with semantic search
actor ObsidianQueryService {

    // MARK: - Dependencies

    private let vectorStore: ObsidianVectorStore
    private let embeddingService: EmbeddingService

    /// Whether the service is configured and ready
    var isConfigured: Bool {
        embeddingService != nil
    }

    // MARK: - Initialization

    init(vectorStore: ObsidianVectorStore, embeddingService: EmbeddingService) {
        self.vectorStore = vectorStore
        self.embeddingService = embeddingService
    }

    #if !os(macOS)
    /// Create from SharedSettings (convenience initializer) - iOS only
    @MainActor
    static func create(from settings: SharedSettings) async throws -> ObsidianQueryService? {
        guard let openAIKey = settings.openAIAPIKey, !openAIKey.isEmpty else {
            return nil
        }

        let vectorStore = ObsidianVectorStore()
        try await vectorStore.open()

        let embeddingService = await EmbeddingService(apiKey: openAIKey)

        return ObsidianQueryService(vectorStore: vectorStore, embeddingService: embeddingService)
    }
    #endif

    // MARK: - Query Methods

    /// Query specific vaults
    func query(
        text: String,
        vaultIds: [UUID],
        maxChunks: Int = 5,
        minSimilarity: Float = 0.3
    ) async throws -> [ObsidianSearchResult] {
        guard !vaultIds.isEmpty else {
            throw ObsidianQueryError.noVaultsSelected
        }

        appLog("Querying Obsidian vaults: \(vaultIds.count) vaults, query length: \(text.count)", category: "Obsidian")

        do {
            // Generate query embedding
            let queryEmbedding = try await embeddingService.embed(text: text)

            // Search vector store
            let storeResults = try await vectorStore.search(
                queryEmbedding: queryEmbedding,
                vaultIds: vaultIds,
                limit: maxChunks,
                minSimilarity: minSimilarity
            )

            // Convert VectorStoreSearchResult to ObsidianSearchResult
            let results = storeResults.map { storeResult -> ObsidianSearchResult in
                ObsidianSearchResult(
                    vaultId: storeResult.chunk.documentId, // Note: Using documentId as temporary vaultId
                    vaultName: storeResult.vaultName,
                    noteId: storeResult.chunk.documentId,
                    notePath: storeResult.notePath,
                    noteTitle: storeResult.noteTitle,
                    chunkContent: storeResult.chunk.content,
                    similarity: storeResult.score
                )
            }

            appLog("Found \(results.count) Obsidian chunks (min similarity: \(Int(minSimilarity * 100))%)", category: "Obsidian")
            return results

        } catch {
            appLog("Obsidian query failed: \(LogSanitizer.sanitizeError(error))", category: "Obsidian", level: .error)
            throw ObsidianQueryError.queryFailed(error.localizedDescription)
        }
    }

    /// Query all available vaults
    func queryAll(
        text: String,
        maxChunks: Int = 5,
        minSimilarity: Float = 0.3
    ) async throws -> [ObsidianSearchResult] {
        // Get all vault IDs from vector store
        let allVaultIds = try await vectorStore.getAllVaults()

        guard !allVaultIds.isEmpty else {
            appLog("No Obsidian vaults available for query", category: "Obsidian", level: .warning)
            return []
        }

        return try await query(
            text: text,
            vaultIds: allVaultIds,
            maxChunks: maxChunks,
            minSimilarity: minSimilarity
        )
    }
}
