//
//  ObsidianSyncService.swift
//  SwiftSpeak
//
//  iCloud sync service for Obsidian vault embeddings
//  Mac uploads embeddings to iCloud Drive, iOS downloads and caches them
//

import Foundation
import SwiftSpeakCore

// MARK: - Sync Errors

enum ObsidianSyncError: Error, LocalizedError {
    case iCloudNotAvailable
    case vaultNotFound(UUID)
    case uploadFailed(String)
    case downloadFailed(String)
    case serializationError(String)
    case deserializationError(String)
    case iCloudPathNotAccessible(String)

    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud Drive is not available. Please sign in to iCloud."
        case .vaultNotFound(let id):
            return "Vault not found: \(id)"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .serializationError(let message):
            return "Failed to serialize data: \(message)"
        case .deserializationError(let message):
            return "Failed to deserialize data: \(message)"
        case .iCloudPathNotAccessible(let path):
            return "iCloud path not accessible: \(path)"
        }
    }
}

// MARK: - Sync Progress

/// Progress updates during sync operations
enum SyncProgress: Sendable {
    case starting
    case uploading(fileIndex: Int, totalFiles: Int, fileName: String)
    case downloading(fileIndex: Int, totalFiles: Int, fileName: String)
    case processing(message: String)
    case complete(vault: ObsidianVault)
    case error(Error)

    var progressPercentage: Double {
        switch self {
        case .starting:
            return 0
        case .uploading(let index, let total, _):
            return Double(index) / Double(max(total, 1))
        case .downloading(let index, let total, _):
            return Double(index) / Double(max(total, 1))
        case .processing:
            return 0.95
        case .complete:
            return 1.0
        case .error:
            return 0
        }
    }
}

// MARK: - Sync Service

/// Manages iCloud sync for Obsidian vault embeddings
actor ObsidianSyncService {

    // MARK: - Constants

    /// iCloud container identifier
    private static let iCloudContainerIdentifier = "iCloud.pawelgawliczek.SwiftSpeak"

    /// Base folder in iCloud for Obsidian data
    /// Must match Mac's path: Documents/Obsidian/
    private static let obsidianFolderPath = "Documents/Obsidian"

    /// Chunk batch size (number of chunks per binary file)
    private static let chunkBatchSize = 10000

    // MARK: - Properties

    /// iCloud container URL
    private var iCloudURL: URL? {
        FileManager.default.url(
            forUbiquityContainerIdentifier: Self.iCloudContainerIdentifier
        )?.appendingPathComponent(Self.obsidianFolderPath, isDirectory: true)
    }

    /// Check if iCloud is available
    var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil && iCloudURL != nil
    }

    // MARK: - API

    /// Upload vault embeddings to iCloud (Mac)
    func uploadVault(
        _ vault: ObsidianVault,
        from vectorStore: ObsidianVectorStore
    ) -> AsyncStream<SyncProgress> {
        AsyncStream { continuation in
            Task {
                do {
                    try await performUpload(vault, from: vectorStore, continuation: continuation)
                } catch {
                    appLog("Upload failed: \(error.localizedDescription)", category: "Obsidian", level: .error)
                    continuation.yield(.error(error))
                    continuation.finish()
                }
            }
        }
    }

    /// Download vault embeddings from iCloud (iOS)
    func downloadVault(
        _ vault: ObsidianVault,
        to vectorStore: ObsidianVectorStore
    ) -> AsyncStream<SyncProgress> {
        AsyncStream { continuation in
            Task {
                do {
                    try await performDownload(vault, to: vectorStore, continuation: continuation)
                } catch {
                    appLog("Download failed: \(error.localizedDescription)", category: "Obsidian", level: .error)
                    continuation.yield(.error(error))
                    continuation.finish()
                }
            }
        }
    }

    /// Get remote vault info without downloading
    func getRemoteVaultInfo(vaultId: UUID) async throws -> ObsidianVaultManifest? {
        guard isICloudAvailable else {
            throw ObsidianSyncError.iCloudNotAvailable
        }

        guard let iCloudURL = iCloudURL else {
            throw ObsidianSyncError.iCloudNotAvailable
        }

        let vaultURL = iCloudURL.appendingPathComponent(vaultId.uuidString)
        let manifestURL = vaultURL.appendingPathComponent("manifest.json")

        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(ObsidianVaultManifest.self, from: data)

        return manifest
    }

    /// List all available vaults in iCloud
    func listRemoteVaults() async throws -> [ObsidianVaultManifest] {
        guard isICloudAvailable else {
            appLog("listRemoteVaults: iCloud not available", category: "Obsidian", level: .error)
            throw ObsidianSyncError.iCloudNotAvailable
        }

        guard let iCloudURL = iCloudURL else {
            appLog("listRemoteVaults: iCloudURL is nil", category: "Obsidian", level: .error)
            throw ObsidianSyncError.iCloudNotAvailable
        }

        appLog("listRemoteVaults: checking path \(iCloudURL.path)", category: "Obsidian")

        // Create base folder if needed
        try FileManager.default.createDirectory(at: iCloudURL, withIntermediateDirectories: true)

        // Trigger iCloud download for the folder (start downloading cloud items)
        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: iCloudURL)
            appLog("listRemoteVaults: triggered iCloud download for folder", category: "Obsidian")
        } catch {
            appLog("listRemoteVaults: couldn't trigger iCloud download: \(error)", category: "Obsidian", level: .warning)
        }

        let contents = try FileManager.default.contentsOfDirectory(
            at: iCloudURL,
            includingPropertiesForKeys: [.isDirectoryKey, .ubiquitousItemDownloadingStatusKey]
        )

        appLog("listRemoteVaults: found \(contents.count) items in iCloud folder", category: "Obsidian")

        var manifests: [ObsidianVaultManifest] = []

        for url in contents {
            let itemName = url.lastPathComponent
            appLog("listRemoteVaults: checking \(itemName)", category: "Obsidian")

            // Skip .icloud placeholder files - these haven't downloaded yet
            if itemName.hasPrefix(".") && itemName.hasSuffix(".icloud") {
                // Extract real folder name and try to trigger download
                let realName = String(itemName.dropFirst().dropLast(7)) // Remove "." and ".icloud"
                appLog("listRemoteVaults: found iCloud placeholder for \(realName), triggering download", category: "Obsidian")
                let realURL = iCloudURL.appendingPathComponent(realName)
                try? FileManager.default.startDownloadingUbiquitousItem(at: realURL)
                continue
            }

            let manifestURL = url.appendingPathComponent("manifest.json")

            // Check for .icloud placeholder for manifest
            let manifestPlaceholder = url.appendingPathComponent(".manifest.json.icloud")
            if FileManager.default.fileExists(atPath: manifestPlaceholder.path) {
                appLog("listRemoteVaults: manifest is iCloud placeholder, triggering download", category: "Obsidian")
                try? FileManager.default.startDownloadingUbiquitousItem(at: manifestURL)
            }

            if FileManager.default.fileExists(atPath: manifestURL.path) {
                do {
                    let data = try Data(contentsOf: manifestURL)
                    let manifest = try JSONDecoder().decode(ObsidianVaultManifest.self, from: data)
                    manifests.append(manifest)
                    appLog("listRemoteVaults: found vault \(manifest.vaultId)", category: "Obsidian")
                } catch {
                    appLog("Failed to read manifest at \(manifestURL.path): \(error)", category: "Obsidian", level: .warning)
                }
            }
        }

        appLog("listRemoteVaults: returning \(manifests.count) vaults", category: "Obsidian")
        return manifests.sorted { $0.indexedAt > $1.indexedAt }
    }

    /// Delete remote vault data
    func deleteRemoteVault(vaultId: UUID) async throws {
        guard isICloudAvailable else {
            throw ObsidianSyncError.iCloudNotAvailable
        }

        guard let iCloudURL = iCloudURL else {
            throw ObsidianSyncError.iCloudNotAvailable
        }

        let vaultURL = iCloudURL.appendingPathComponent(vaultId.uuidString)

        if FileManager.default.fileExists(atPath: vaultURL.path) {
            try FileManager.default.removeItem(at: vaultURL)
            appLog("Deleted remote vault: \(vaultId)", category: "Obsidian")
        }
    }

    // MARK: - Upload Implementation

    private func performUpload(
        _ vault: ObsidianVault,
        from vectorStore: ObsidianVectorStore,
        continuation: AsyncStream<SyncProgress>.Continuation
    ) async throws {
        guard isICloudAvailable else {
            throw ObsidianSyncError.iCloudNotAvailable
        }

        guard let iCloudURL = iCloudURL else {
            throw ObsidianSyncError.iCloudNotAvailable
        }

        continuation.yield(.starting)

        // Create vault folder
        let vaultURL = iCloudURL.appendingPathComponent(vault.id.uuidString)
        try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)

        // Load all chunks from vector store
        continuation.yield(.processing(message: "Loading chunks from database..."))

        let chunks = try await loadAllChunks(from: vectorStore, vaultId: vault.id)

        guard !chunks.isEmpty else {
            throw ObsidianSyncError.uploadFailed("No chunks found in vector store")
        }

        // Serialize chunks into batches
        let batchCount = (chunks.count + Self.chunkBatchSize - 1) / Self.chunkBatchSize

        continuation.yield(.processing(message: "Preparing \(batchCount) batch files..."))

        // Upload embedding batches
        for batchIndex in 0..<batchCount {
            let startIdx = batchIndex * Self.chunkBatchSize
            let endIdx = min(startIdx + Self.chunkBatchSize, chunks.count)
            let batchChunks = Array(chunks[startIdx..<endIdx])

            let fileName = "embeddings_\(batchIndex).bin"
            let fileURL = vaultURL.appendingPathComponent(fileName)

            continuation.yield(.uploading(
                fileIndex: batchIndex + 1,
                totalFiles: batchCount + 2, // +2 for manifest and chunks_index
                fileName: fileName
            ))

            // Map to (id, embedding) tuples for serialization
            let embeddingsOnly = batchChunks.map { (id: $0.id, embedding: $0.embedding) }
            let data = try serializeEmbeddings(embeddingsOnly)
            try data.write(to: fileURL)

            appLog("Uploaded batch \(batchIndex + 1)/\(batchCount): \(batchChunks.count) chunks", category: "Obsidian")
        }

        // Upload chunks index (JSON)
        continuation.yield(.uploading(
            fileIndex: batchCount + 1,
            totalFiles: batchCount + 2,
            fileName: "chunks_index.json"
        ))

        let chunksIndexURL = vaultURL.appendingPathComponent("chunks_index.json")
        // Map to 5-element tuples for chunks index (excludes embedding)
        let chunksForIndex = chunks.map { (id: $0.id, noteId: $0.noteId, content: $0.content, startOffset: $0.startOffset, endOffset: $0.endOffset) }
        let chunksIndexData = try serializeChunksIndex(chunksForIndex)
        try chunksIndexData.write(to: chunksIndexURL)

        appLog("Uploaded chunks index: \(chunks.count) chunks", category: "Obsidian")

        // Create and upload manifest
        continuation.yield(.uploading(
            fileIndex: batchCount + 2,
            totalFiles: batchCount + 2,
            fileName: "manifest.json"
        ))

        let manifest = ObsidianVaultManifest(
            vaultId: vault.id,
            indexedAt: vault.lastIndexed ?? Date(),
            embeddingModel: "text-embedding-3-small", // TODO: Get from vector store
            noteCount: vault.noteCount,
            chunkCount: vault.chunkCount,
            embeddingBatchCount: batchCount,
            notes: [] // TODO: Load note metadata from vector store
        )

        let manifestURL = vaultURL.appendingPathComponent("manifest.json")
        let manifestData = try JSONEncoder().encode(manifest)
        try manifestData.write(to: manifestURL)

        appLog("Uploaded manifest for vault \(vault.name)", category: "Obsidian")

        continuation.yield(.complete(vault: vault))
        continuation.finish()
    }

    // MARK: - Download Implementation

    private func performDownload(
        _ vault: ObsidianVault,
        to vectorStore: ObsidianVectorStore,
        continuation: AsyncStream<SyncProgress>.Continuation
    ) async throws {
        guard isICloudAvailable else {
            throw ObsidianSyncError.iCloudNotAvailable
        }

        guard let iCloudURL = iCloudURL else {
            throw ObsidianSyncError.iCloudNotAvailable
        }

        continuation.yield(.starting)

        let vaultURL = iCloudURL.appendingPathComponent(vault.id.uuidString)
        let manifestURL = vaultURL.appendingPathComponent("manifest.json")

        // Download and parse manifest
        continuation.yield(.processing(message: "Reading manifest..."))

        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw ObsidianSyncError.vaultNotFound(vault.id)
        }

        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(ObsidianVaultManifest.self, from: manifestData)

        appLog("Downloading vault: \(manifest.noteCount) notes, \(manifest.chunkCount) chunks", category: "Obsidian")

        // Download chunks index
        continuation.yield(.downloading(
            fileIndex: 1,
            totalFiles: manifest.embeddingBatchCount + 1,
            fileName: "chunks_index.json"
        ))

        let chunksIndexURL = vaultURL.appendingPathComponent("chunks_index.json")
        let chunksIndexData = try Data(contentsOf: chunksIndexURL)
        let chunksIndex = try deserializeChunksIndex(chunksIndexData)

        appLog("Downloaded chunks index: \(chunksIndex.count) entries", category: "Obsidian")

        // Download embedding batches
        var allChunks: [(UUID, [Float])] = []

        for batchIndex in 0..<manifest.embeddingBatchCount {
            let fileName = "embeddings_\(batchIndex).bin"
            let fileURL = vaultURL.appendingPathComponent(fileName)

            continuation.yield(.downloading(
                fileIndex: batchIndex + 2,
                totalFiles: manifest.embeddingBatchCount + 1,
                fileName: fileName
            ))

            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                throw ObsidianSyncError.downloadFailed("Missing batch file: \(fileName)")
            }

            let data = try Data(contentsOf: fileURL)
            let batchEmbeddings = try deserializeEmbeddings(data)
            allChunks.append(contentsOf: batchEmbeddings)

            appLog("Downloaded batch \(batchIndex + 1)/\(manifest.embeddingBatchCount): \(batchEmbeddings.count) embeddings", category: "Obsidian")
        }

        // Store in local vector store
        continuation.yield(.processing(message: "Storing in local database..."))

        try await storeChunksInVectorStore(
            chunks: chunksIndex,
            embeddings: allChunks,
            manifest: manifest,
            vectorStore: vectorStore
        )

        appLog("Downloaded and stored vault: \(vault.name)", category: "Obsidian")

        continuation.yield(.complete(vault: vault))
        continuation.finish()
    }

    // MARK: - Serialization

    /// Serialize embeddings to binary format
    private func serializeEmbeddings(_ chunks: [(id: UUID, embedding: [Float])]) throws -> Data {
        var data = Data()

        // Write header: chunk count
        let count = UInt32(chunks.count)
        withUnsafeBytes(of: count) { bytes in
            data.append(contentsOf: bytes)
        }

        // Write each chunk
        for (id, embedding) in chunks {
            // Write UUID (16 bytes)
            var uuid = id.uuid
            withUnsafeBytes(of: &uuid) { bytes in
                data.append(contentsOf: bytes)
            }

            // Write embedding (dimensions * 4 bytes)
            for value in embedding {
                var float = value
                withUnsafeBytes(of: &float) { bytes in
                    data.append(contentsOf: bytes)
                }
            }
        }

        return data
    }

    /// Deserialize embeddings from binary format
    private func deserializeEmbeddings(_ data: Data) throws -> [(UUID, [Float])] {
        var offset = 0

        // Read header
        guard data.count >= 4 else {
            throw ObsidianSyncError.deserializationError("Invalid header")
        }

        let count = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: offset, as: UInt32.self)
        }
        offset += 4

        var results: [(UUID, [Float])] = []
        let dimensions = 1536 // text-embedding-3-small
        let embeddingSize = dimensions * 4
        let chunkSize = 16 + embeddingSize

        for _ in 0..<count {
            guard offset + chunkSize <= data.count else {
                throw ObsidianSyncError.deserializationError("Incomplete chunk data")
            }

            // Read UUID
            let uuidBytes = data.subdata(in: offset..<(offset + 16))
            let uuid = UUID(uuid: uuidBytes.withUnsafeBytes { $0.load(as: uuid_t.self) })
            offset += 16

            // Read embedding
            var embedding: [Float] = []
            for _ in 0..<dimensions {
                let value = data.withUnsafeBytes { bytes in
                    bytes.load(fromByteOffset: offset, as: Float.self)
                }
                embedding.append(value)
                offset += 4
            }

            results.append((uuid, embedding))
        }

        return results
    }

    /// Serialize chunks index to JSON
    private func serializeChunksIndex(_ chunks: [(id: UUID, noteId: UUID, content: String, startOffset: Int, endOffset: Int)]) throws -> Data {
        let items = chunks.map { chunk in
            ChunkIndexItem(
                id: chunk.id.uuidString,
                noteId: chunk.noteId.uuidString,
                content: chunk.content,
                startOffset: chunk.startOffset,
                endOffset: chunk.endOffset
            )
        }

        let index = ChunksIndex(chunks: items)
        return try JSONEncoder().encode(index)
    }

    /// Deserialize chunks index from JSON
    private func deserializeChunksIndex(_ data: Data) throws -> [(id: UUID, noteId: UUID, content: String, startOffset: Int, endOffset: Int)] {
        let index = try JSONDecoder().decode(ChunksIndex.self, from: data)

        return index.chunks.compactMap { item in
            guard let id = UUID(uuidString: item.id),
                  let noteId = UUID(uuidString: item.noteId) else {
                return nil
            }
            return (id, noteId, item.content, item.startOffset, item.endOffset)
        }
    }

    // MARK: - Vector Store Integration

    /// Load all chunks from vector store for upload
    private func loadAllChunks(
        from vectorStore: ObsidianVectorStore,
        vaultId: UUID
    ) async throws -> [(id: UUID, noteId: UUID, content: String, startOffset: Int, endOffset: Int, embedding: [Float])] {
        return try await MainActor.run {
            try vectorStore.getAllChunks(forVault: vaultId)
        }
    }

    /// Store downloaded chunks in vector store
    private func storeChunksInVectorStore(
        chunks: [(id: UUID, noteId: UUID, content: String, startOffset: Int, endOffset: Int)],
        embeddings: [(UUID, [Float])],
        manifest: ObsidianVaultManifest,
        vectorStore: ObsidianVectorStore
    ) async throws {
        // Create embedding lookup
        let embeddingMap = Dictionary(uniqueKeysWithValues: embeddings)

        // Group chunks by note
        var chunksByNote: [UUID: [DocumentChunk]] = [:]

        for chunk in chunks {
            guard let embedding = embeddingMap[chunk.id] else {
                continue
            }

            let documentChunk = DocumentChunk(
                id: chunk.id,
                documentId: chunk.noteId,
                index: 0, // Will be set correctly when grouping
                content: chunk.content,
                startOffset: chunk.startOffset,
                endOffset: chunk.endOffset,
                metadata: ChunkMetadata(),
                embedding: embedding,
                createdAt: Date()
            )

            chunksByNote[chunk.noteId, default: []].append(documentChunk)
        }

        // Store chunks in vector store
        for (noteId, noteChunks) in chunksByNote {
            // Sort by start offset and assign indices
            let sortedChunks = noteChunks.sorted { $0.startOffset < $1.startOffset }
            let indexedChunks = sortedChunks.enumerated().map { index, chunk in
                DocumentChunk(
                    id: chunk.id,
                    documentId: chunk.documentId,
                    index: index,
                    content: chunk.content,
                    startOffset: chunk.startOffset,
                    endOffset: chunk.endOffset,
                    metadata: chunk.metadata,
                    embedding: chunk.embedding,
                    createdAt: chunk.createdAt
                )
            }

            try await MainActor.run {
                try vectorStore.storeChunks(indexedChunks, vaultId: manifest.vaultId, noteId: noteId)
            }
        }

        appLog("Stored \(chunks.count) chunks for \(chunksByNote.count) notes", category: "Obsidian")
    }
}

// MARK: - Supporting Types

/// JSON structure for chunks index file
private struct ChunksIndex: Codable {
    let chunks: [ChunkIndexItem]
}

private struct ChunkIndexItem: Codable {
    let id: String
    let noteId: String
    let content: String
    let startOffset: Int
    let endOffset: Int
}
