//
//  MacObsidianVectorStore.swift
//  SwiftSpeakMac
//
//  Local vector store for Obsidian embeddings on macOS
//  Saves embeddings to Application Support, syncs to iCloud Drive
//
//  NOTE: Uses shared RAG infrastructure from SwiftSpeakCore
//

import Foundation
import SwiftSpeakCore

// MARK: - Vector Store

@MainActor
final class MacObsidianVectorStore {

    // MARK: - Storage Paths

    private let fileManager = FileManager.default

    /// Base directory for all Obsidian data
    private var baseDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let obsidianDir = appSupport.appendingPathComponent("SwiftSpeak/Obsidian", isDirectory: true)
        try? fileManager.createDirectory(at: obsidianDir, withIntermediateDirectories: true)
        return obsidianDir
    }

    /// Directory for a specific vault
    private func vaultDirectory(for vaultId: UUID) -> URL {
        let dir = baseDirectory.appendingPathComponent(vaultId.uuidString, isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Path to chunks JSON file
    private func chunksPath(for vaultId: UUID) -> URL {
        vaultDirectory(for: vaultId).appendingPathComponent("chunks.json")
    }

    /// Path to embeddings binary file
    private func embeddingsPath(for vaultId: UUID) -> URL {
        vaultDirectory(for: vaultId).appendingPathComponent("embeddings.bin")
    }

    /// Path to manifest file
    private func manifestPath(for vaultId: UUID) -> URL {
        vaultDirectory(for: vaultId).appendingPathComponent("manifest.json")
    }

    // MARK: - Save Operations

    /// Save indexed chunks and embeddings for a vault
    func save(chunks: [ObsidianChunk], for vaultId: UUID) throws {
        let vaultDir = vaultDirectory(for: vaultId)
        macLog("Saving \(chunks.count) chunks to \(vaultDir.path)", category: "VectorStore")

        // Save chunks metadata (without embeddings to keep JSON small)
        let chunksForJSON = chunks.map { chunk -> ChunkMetadata in
            ChunkMetadata(
                id: chunk.id,
                vaultId: chunk.vaultId,
                noteId: chunk.noteId,
                notePath: chunk.notePath,
                noteTitle: chunk.noteTitle,
                content: chunk.content,
                chunkIndex: chunk.chunkIndex
            )
        }

        let chunksData = try JSONEncoder().encode(chunksForJSON)
        try chunksData.write(to: chunksPath(for: vaultId))
        macLog("Saved chunks metadata: \(chunksData.count) bytes", category: "VectorStore")

        // Save embeddings as binary (Float32 array)
        let embeddingDimension = chunks.first?.embedding?.count ?? 1536
        var allEmbeddings: [Float] = []
        for chunk in chunks {
            if let embedding = chunk.embedding {
                allEmbeddings.append(contentsOf: embedding)
            } else {
                // Pad with zeros if missing
                allEmbeddings.append(contentsOf: [Float](repeating: 0, count: embeddingDimension))
            }
        }

        let embeddingsData = allEmbeddings.withUnsafeBytes { Data($0) }
        try embeddingsData.write(to: embeddingsPath(for: vaultId))
        macLog("Saved embeddings: \(embeddingsData.count) bytes (\(chunks.count) × \(embeddingDimension) dimensions)", category: "VectorStore")

        // Save manifest
        let manifest = VaultManifest(
            vaultId: vaultId,
            chunkCount: chunks.count,
            embeddingDimension: embeddingDimension,
            embeddingModel: "text-embedding-3-small",
            indexedAt: Date()
        )
        let manifestData = try JSONEncoder().encode(manifest)
        try manifestData.write(to: manifestPath(for: vaultId))
        macLog("Saved manifest", category: "VectorStore")
    }

    // MARK: - Load Operations

    /// Load chunks with embeddings for a vault
    func load(vaultId: UUID) throws -> [ObsidianChunk] {
        let chunksURL = chunksPath(for: vaultId)
        let embeddingsURL = embeddingsPath(for: vaultId)

        guard fileManager.fileExists(atPath: chunksURL.path),
              fileManager.fileExists(atPath: embeddingsURL.path) else {
            macLog("No stored data for vault \(vaultId)", category: "VectorStore")
            return []
        }

        // Load chunks metadata
        let chunksData = try Data(contentsOf: chunksURL)
        let chunksMetadata = try JSONDecoder().decode([ChunkMetadata].self, from: chunksData)
        macLog("Loaded \(chunksMetadata.count) chunks metadata", category: "VectorStore")

        // Load embeddings
        let embeddingsData = try Data(contentsOf: embeddingsURL)
        let manifest = try loadManifest(vaultId: vaultId)
        let embeddingDimension = manifest?.embeddingDimension ?? 1536

        let floatCount = embeddingsData.count / MemoryLayout<Float>.size
        var embeddings: [Float] = Array(repeating: 0, count: floatCount)
        _ = embeddings.withUnsafeMutableBytes { embeddingsData.copyBytes(to: $0) }

        macLog("Loaded \(floatCount) floats (\(floatCount / embeddingDimension) embeddings)", category: "VectorStore")

        // Combine chunks with embeddings
        var chunks: [ObsidianChunk] = []
        for (index, meta) in chunksMetadata.enumerated() {
            let startIdx = index * embeddingDimension
            let endIdx = min(startIdx + embeddingDimension, embeddings.count)
            let embedding = Array(embeddings[startIdx..<endIdx])

            chunks.append(ObsidianChunk(
                id: meta.id,
                vaultId: meta.vaultId,
                noteId: meta.noteId,
                notePath: meta.notePath,
                noteTitle: meta.noteTitle,
                content: meta.content,
                chunkIndex: meta.chunkIndex,
                embedding: embedding
            ))
        }

        return chunks
    }

    /// Load manifest for a vault
    func loadManifest(vaultId: UUID) throws -> VaultManifest? {
        let manifestURL = manifestPath(for: vaultId)
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: manifestURL)
        return try JSONDecoder().decode(VaultManifest.self, from: data)
    }

    // MARK: - Query Operations

    /// Search for similar chunks using cosine similarity + keyword boosting
    /// Returns unique notes (deduplicated by noteId, keeping best matching chunk per note)
    /// - Parameters:
    ///   - embedding: Query embedding vector
    ///   - queryText: Original query text for keyword boosting (optional)
    ///   - vaultIds: Vault IDs to search
    ///   - limit: Max results
    ///   - minSimilarity: Minimum similarity threshold
    func search(
        query embedding: [Float],
        queryText: String? = nil,
        vaultIds: [UUID],
        limit: Int = 5,
        minSimilarity: Float = 0.3
    ) throws -> [ObsidianSearchResult] {
        var allResults: [(chunk: ObsidianChunk, similarity: Float, vaultName: String)] = []

        // Prepare query terms for keyword boosting
        let queryTerms = queryText?.lowercased().components(separatedBy: .whitespaces).filter { !$0.isEmpty } ?? []

        for vaultId in vaultIds {
            let chunks = try load(vaultId: vaultId)
            guard !chunks.isEmpty else { continue }

            // Get vault name from settings
            let vaultName = MacSettings.shared.getObsidianVault(id: vaultId)?.name ?? "Unknown"

            for chunk in chunks {
                guard let chunkEmbedding = chunk.embedding else { continue }
                var similarity = VectorMath.cosineSimilarity(embedding, chunkEmbedding)

                // Keyword boosting: boost score if query terms appear in title or content
                if !queryTerms.isEmpty {
                    let titleLower = chunk.noteTitle.lowercased()
                    let contentLower = chunk.content.lowercased()

                    for term in queryTerms {
                        // Strong boost for title match (adds up to 0.4)
                        if titleLower.contains(term) {
                            similarity += 0.4
                        }
                        // Moderate boost for content match (adds up to 0.2)
                        else if contentLower.contains(term) {
                            similarity += 0.2
                        }
                    }

                    // Cap at 1.0
                    similarity = min(similarity, 1.0)
                }

                if similarity >= minSimilarity {
                    allResults.append((chunk, similarity, vaultName))
                }
            }
        }

        // Sort by similarity descending
        allResults.sort { $0.similarity > $1.similarity }

        // Deduplicate by notePath - keep only the best matching chunk per note
        // Dedup across all vaults to handle duplicate vaults
        var seenNotePaths: Set<String> = []
        var uniqueResults: [(chunk: ObsidianChunk, similarity: Float, vaultName: String)] = []

        for item in allResults {
            guard !seenNotePaths.contains(item.chunk.notePath) else { continue }
            seenNotePaths.insert(item.chunk.notePath)
            uniqueResults.append(item)
            if uniqueResults.count >= limit { break }
        }

        // Convert to search results
        return uniqueResults.map { item in
            ObsidianSearchResult(
                id: item.chunk.id,
                noteId: item.chunk.noteId,
                vaultId: item.chunk.vaultId,
                vaultName: item.vaultName,
                notePath: item.chunk.notePath,
                noteTitle: item.chunk.noteTitle,
                content: item.chunk.content,
                similarity: item.similarity
            )
        }
    }

    // MARK: - Delete Operations

    /// Delete all data for a vault
    func delete(vaultId: UUID) throws {
        let dir = vaultDirectory(for: vaultId)
        if fileManager.fileExists(atPath: dir.path) {
            try fileManager.removeItem(at: dir)
            macLog("Deleted vault data: \(vaultId)", category: "VectorStore")
        }
    }

    // MARK: - Browse All

    /// Get all chunks from specified vaults without similarity filtering (for browsing)
    /// Returns unique notes (deduplicated by notePath)
    func getAllChunks(
        vaultIds: [UUID],
        limit: Int = 50
    ) throws -> [ObsidianSearchResult] {
        var allResults: [ObsidianSearchResult] = []
        var seenNotePaths: Set<String> = []

        for vaultId in vaultIds {
            let chunks = try load(vaultId: vaultId)
            guard !chunks.isEmpty else { continue }

            // Get unique note paths for debug
            let uniquePaths = Set(chunks.map { $0.notePath })
            macLog("getAllChunks: vault \(vaultId) has \(chunks.count) chunks from \(uniquePaths.count) unique notes: \(uniquePaths)", category: "VectorStore")

            // Get vault name from settings
            let vaultName = MacSettings.shared.getObsidianVault(id: vaultId)?.name ?? "Unknown"

            // Group by note and take first chunk for each note
            // Deduplicate by notePath only (across all vaults) to handle duplicate vaults
            for chunk in chunks {
                guard !seenNotePaths.contains(chunk.notePath) else { continue }
                seenNotePaths.insert(chunk.notePath)

                let result = ObsidianSearchResult(
                    id: chunk.id,
                    noteId: chunk.noteId,
                    vaultId: chunk.vaultId,
                    vaultName: vaultName,
                    notePath: chunk.notePath,
                    noteTitle: chunk.noteTitle,
                    content: chunk.content,
                    similarity: 1.0 // No filtering applied
                )
                allResults.append(result)

                if allResults.count >= limit { break }
            }

            if allResults.count >= limit { break }
        }

        // Sort by title
        allResults.sort { $0.noteTitle.localizedCaseInsensitiveCompare($1.noteTitle) == .orderedAscending }

        macLog("getAllChunks: Returning \(allResults.count) unique notes (from \(seenNotePaths.count) paths)", category: "VectorStore")
        return Array(allResults.prefix(limit))
    }

}

// MARK: - Supporting Types

private struct ChunkMetadata: Codable {
    let id: UUID
    let vaultId: UUID
    let noteId: UUID
    let notePath: String
    let noteTitle: String
    let content: String
    let chunkIndex: Int
}

struct VaultManifest: Codable {
    let vaultId: UUID
    let chunkCount: Int
    let embeddingDimension: Int
    let embeddingModel: String
    let indexedAt: Date
}
