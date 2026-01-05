//
//  MacObsidianVectorStore.swift
//  SwiftSpeakMac
//
//  Local vector store for Obsidian embeddings on macOS
//  Saves embeddings to Application Support, syncs to iCloud Drive
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

    /// Search for similar chunks using cosine similarity
    func search(
        query embedding: [Float],
        vaultIds: [UUID],
        limit: Int = 5,
        minSimilarity: Float = 0.3
    ) throws -> [ObsidianSearchResult] {
        var allResults: [(chunk: ObsidianChunk, similarity: Float, vaultName: String)] = []

        for vaultId in vaultIds {
            let chunks = try load(vaultId: vaultId)
            guard !chunks.isEmpty else { continue }

            // Get vault name from settings
            let vaultName = MacSettings.shared.getObsidianVault(id: vaultId)?.name ?? "Unknown"

            for chunk in chunks {
                guard let chunkEmbedding = chunk.embedding else { continue }
                let similarity = cosineSimilarity(embedding, chunkEmbedding)
                if similarity >= minSimilarity {
                    allResults.append((chunk, similarity, vaultName))
                }
            }
        }

        // Sort by similarity descending
        allResults.sort { $0.similarity > $1.similarity }

        // Convert to search results
        return allResults.prefix(limit).map { item in
            ObsidianSearchResult(
                id: item.chunk.id,
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

    // MARK: - Helpers

    /// Cosine similarity between two vectors
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
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
