//
//  ObsidianVectorStore.swift
//  SwiftSpeak
//
//  Separate SQLite database for Obsidian vault embeddings
//  Does not mix with Power Mode documents - dedicated to Obsidian notes
//

import Foundation
import SQLite3
import SwiftSpeakCore

// MARK: - Obsidian Vector Store Errors

enum ObsidianVectorStoreError: Error, LocalizedError {
    case databaseNotOpen
    case databaseError(String)
    case vaultNotFound(UUID)
    case noteNotFound(UUID)
    case embeddingDimensionMismatch(expected: Int, got: Int)
    case serializationError

    var errorDescription: String? {
        switch self {
        case .databaseNotOpen:
            return "Obsidian vector store database is not open."
        case .databaseError(let message):
            return "Database error: \(message)"
        case .vaultNotFound(let id):
            return "Vault not found: \(id)"
        case .noteNotFound(let id):
            return "Note not found: \(id)"
        case .embeddingDimensionMismatch(let expected, let got):
            return "Embedding dimension mismatch: expected \(expected), got \(got)"
        case .serializationError:
            return "Failed to serialize/deserialize data."
        }
    }
}

// MARK: - Obsidian Vector Store

@MainActor
final class ObsidianVectorStore {

    // MARK: - Properties

    private var db: OpaquePointer?
    private let dbPath: String
    private let expectedDimensions: Int

    /// Whether the database is open
    var isOpen: Bool {
        db != nil
    }

    // MARK: - Initialization

    init(embeddingModel: RAGEmbeddingModel = .openAISmall) {
        self.expectedDimensions = embeddingModel.dimensions

        // Store in App Group container for sharing with iOS
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.pawelgawliczek.swiftspeak"
        ) ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        self.dbPath = containerURL.appendingPathComponent("obsidian_vector_store.db").path
        appLog("Obsidian vector store path: \(dbPath)", category: "Obsidian")
    }

    deinit {
        // Direct SQLite close call - safe since deinit runs when no references exist
        if db != nil {
            sqlite3_close(db)
        }
    }

    // MARK: - Database Lifecycle

    func open() throws {
        guard db == nil else { return }

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            throw ObsidianVectorStoreError.databaseError(lastErrorMessage)
        }

        try createTables()
        appLog("Obsidian vector store opened", category: "Obsidian")
    }

    func close() {
        if db != nil {
            sqlite3_close(db)
            db = nil
            appLog("Obsidian vector store closed", category: "Obsidian")
        }
    }

    private func createTables() throws {
        let createVaultsSQL = """
        CREATE TABLE IF NOT EXISTS vaults (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            icloud_path TEXT NOT NULL,
            last_indexed REAL,
            note_count INTEGER NOT NULL,
            chunk_count INTEGER NOT NULL,
            embedding_model TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            UNIQUE(id)
        );
        CREATE INDEX IF NOT EXISTS idx_vaults_name ON vaults(name);
        """

        let createNotesSQL = """
        CREATE TABLE IF NOT EXISTS notes (
            id TEXT PRIMARY KEY,
            vault_id TEXT NOT NULL,
            relative_path TEXT NOT NULL,
            title TEXT NOT NULL,
            content_hash TEXT NOT NULL,
            last_modified REAL NOT NULL,
            chunk_count INTEGER NOT NULL,
            chunk_start_index INTEGER NOT NULL,
            created_at REAL NOT NULL,
            FOREIGN KEY (vault_id) REFERENCES vaults(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_notes_vault ON notes(vault_id);
        CREATE INDEX IF NOT EXISTS idx_notes_path ON notes(vault_id, relative_path);
        """

        let createChunksSQL = """
        CREATE TABLE IF NOT EXISTS chunks (
            id TEXT PRIMARY KEY,
            note_id TEXT NOT NULL,
            vault_id TEXT NOT NULL,
            chunk_index INTEGER NOT NULL,
            content TEXT NOT NULL,
            start_offset INTEGER NOT NULL,
            end_offset INTEGER NOT NULL,
            metadata TEXT NOT NULL,
            embedding BLOB,
            created_at REAL NOT NULL,
            FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE,
            FOREIGN KEY (vault_id) REFERENCES vaults(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_chunks_note ON chunks(note_id);
        CREATE INDEX IF NOT EXISTS idx_chunks_vault ON chunks(vault_id);
        """

        try execute(createVaultsSQL)
        try execute(createNotesSQL)
        try execute(createChunksSQL)
    }

    // MARK: - Vault Operations

    /// Store or update vault metadata
    func storeVault(_ vault: ObsidianVault, embeddingModel: RAGEmbeddingModel) throws {
        guard db != nil else { throw ObsidianVectorStoreError.databaseNotOpen }

        let sql = """
        INSERT OR REPLACE INTO vaults
        (id, name, icloud_path, last_indexed, note_count, chunk_count, embedding_model, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ObsidianVectorStoreError.databaseError(lastErrorMessage)
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, vault.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, vault.name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, vault.iCloudPath, -1, SQLITE_TRANSIENT)

        if let lastIndexed = vault.lastIndexed {
            sqlite3_bind_double(stmt, 4, lastIndexed.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(stmt, 4)
        }

        sqlite3_bind_int(stmt, 5, Int32(vault.noteCount))
        sqlite3_bind_int(stmt, 6, Int32(vault.chunkCount))
        sqlite3_bind_text(stmt, 7, embeddingModel.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 8, Date().timeIntervalSince1970)
        sqlite3_bind_double(stmt, 9, Date().timeIntervalSince1970)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw ObsidianVectorStoreError.databaseError(lastErrorMessage)
        }

        appLog("Stored vault: \(vault.name) (\(vault.noteCount) notes, \(vault.chunkCount) chunks)", category: "Obsidian")
    }

    /// Delete vault and all its data
    func deleteVault(_ vaultId: UUID) throws {
        guard db != nil else { throw ObsidianVectorStoreError.databaseNotOpen }

        try execute("DELETE FROM chunks WHERE vault_id = '\(vaultId.uuidString)'")
        try execute("DELETE FROM notes WHERE vault_id = '\(vaultId.uuidString)'")
        try execute("DELETE FROM vaults WHERE id = '\(vaultId.uuidString)'")

        appLog("Deleted vault: \(vaultId)", category: "Obsidian")
    }

    /// Get all vaults
    func getAllVaults() throws -> [UUID] {
        guard db != nil else { throw ObsidianVectorStoreError.databaseNotOpen }

        let sql = "SELECT id FROM vaults ORDER BY name"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ObsidianVectorStoreError.databaseError(lastErrorMessage)
        }
        defer { sqlite3_finalize(stmt) }

        var vaultIds: [UUID] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cString = sqlite3_column_text(stmt, 0),
               let uuid = UUID(uuidString: String(cString: cString)) {
                vaultIds.append(uuid)
            }
        }

        return vaultIds
    }

    // MARK: - Note Operations

    /// Store note metadata
    func storeNote(_ note: ObsidianNoteMetadata, vaultId: UUID) throws {
        guard db != nil else { throw ObsidianVectorStoreError.databaseNotOpen }

        let sql = """
        INSERT OR REPLACE INTO notes
        (id, vault_id, relative_path, title, content_hash, last_modified, chunk_count, chunk_start_index, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ObsidianVectorStoreError.databaseError(lastErrorMessage)
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, note.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, vaultId.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, note.relativePath, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, note.title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 5, note.contentHash, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 6, note.lastModified.timeIntervalSince1970)
        sqlite3_bind_int(stmt, 7, Int32(note.chunkCount))
        sqlite3_bind_int(stmt, 8, Int32(note.chunkStartIndex))
        sqlite3_bind_double(stmt, 9, Date().timeIntervalSince1970)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw ObsidianVectorStoreError.databaseError(lastErrorMessage)
        }
    }

    /// Store multiple notes in a transaction
    func storeNotes(_ notes: [ObsidianNoteMetadata], vaultId: UUID) throws {
        guard db != nil else { throw ObsidianVectorStoreError.databaseNotOpen }

        try execute("BEGIN TRANSACTION")

        do {
            for note in notes {
                try storeNote(note, vaultId: vaultId)
            }
            try execute("COMMIT")
            appLog("Stored \(notes.count) notes for vault \(vaultId)", category: "Obsidian")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    // MARK: - Chunk Operations

    /// Store chunks with embeddings for a vault
    func storeChunks(_ chunks: [DocumentChunk], vaultId: UUID, noteId: UUID) throws {
        guard db != nil else { throw ObsidianVectorStoreError.databaseNotOpen }

        let sql = """
        INSERT OR REPLACE INTO chunks
        (id, note_id, vault_id, chunk_index, content, start_offset, end_offset, metadata, embedding, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        try execute("BEGIN TRANSACTION")

        do {
            for chunk in chunks {
                var stmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                    throw ObsidianVectorStoreError.databaseError(lastErrorMessage)
                }
                defer { sqlite3_finalize(stmt) }

                sqlite3_bind_text(stmt, 1, chunk.id.uuidString, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, noteId.uuidString, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 3, vaultId.uuidString, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(stmt, 4, Int32(chunk.index))
                sqlite3_bind_text(stmt, 5, chunk.content, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(stmt, 6, Int32(chunk.startOffset))
                sqlite3_bind_int(stmt, 7, Int32(chunk.endOffset))

                // Serialize metadata as JSON
                let metadataData = try JSONEncoder().encode(chunk.metadata)
                let metadataString = String(data: metadataData, encoding: .utf8) ?? "{}"
                sqlite3_bind_text(stmt, 8, metadataString, -1, SQLITE_TRANSIENT)

                // Serialize embedding as blob
                if let embedding = chunk.embedding {
                    let embeddingData = embedding.withUnsafeBufferPointer { Data(buffer: $0) }
                    _ = embeddingData.withUnsafeBytes { bytes in
                        sqlite3_bind_blob(stmt, 9, bytes.baseAddress, Int32(embeddingData.count), SQLITE_TRANSIENT)
                    }
                } else {
                    sqlite3_bind_null(stmt, 9)
                }

                sqlite3_bind_double(stmt, 10, chunk.createdAt.timeIntervalSince1970)

                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw ObsidianVectorStoreError.databaseError(lastErrorMessage)
                }
            }

            try execute("COMMIT")
            appLog("Stored \(chunks.count) chunks for note \(noteId)", category: "Obsidian")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    // MARK: - Similarity Search

    /// Search across all vaults or specific vaults
    func search(
        queryEmbedding: [Float],
        vaultIds: [UUID]? = nil,
        limit: Int = 5,
        minSimilarity: Float = 0.0
    ) throws -> [VectorStoreSearchResult] {
        guard db != nil else { throw ObsidianVectorStoreError.databaseNotOpen }

        // Validate embedding dimensions
        guard queryEmbedding.count == expectedDimensions else {
            throw ObsidianVectorStoreError.embeddingDimensionMismatch(
                expected: expectedDimensions,
                got: queryEmbedding.count
            )
        }

        // Build query with optional vault filter
        var sql = """
        SELECT c.id, c.note_id, c.vault_id, c.chunk_index, c.content, c.start_offset, c.end_offset,
               c.metadata, c.embedding, c.created_at, n.title as note_title, n.relative_path,
               v.name as vault_name
        FROM chunks c
        JOIN notes n ON c.note_id = n.id
        JOIN vaults v ON c.vault_id = v.id
        WHERE c.embedding IS NOT NULL
        """

        if let vaultIds = vaultIds, !vaultIds.isEmpty {
            let idList = vaultIds.map { "'\($0.uuidString)'" }.joined(separator: ",")
            sql += " AND c.vault_id IN (\(idList))"
        }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ObsidianVectorStoreError.databaseError(lastErrorMessage)
        }
        defer { sqlite3_finalize(stmt) }

        var results: [(chunk: DocumentChunk, noteTitle: String, notePath: String, vaultName: String, similarity: Float)] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            // Parse chunk data
            guard let idString = sqlite3_column_text(stmt, 0),
                  let noteIdString = sqlite3_column_text(stmt, 1),
                  let vaultIdString = sqlite3_column_text(stmt, 2),
                  let contentText = sqlite3_column_text(stmt, 4),
                  let metadataText = sqlite3_column_text(stmt, 7),
                  let noteTitleText = sqlite3_column_text(stmt, 10),
                  let notePathText = sqlite3_column_text(stmt, 11),
                  let vaultNameText = sqlite3_column_text(stmt, 12) else {
                continue
            }

            guard let id = UUID(uuidString: String(cString: idString)),
                  let noteId = UUID(uuidString: String(cString: noteIdString)),
                  let vaultId = UUID(uuidString: String(cString: vaultIdString)) else {
                continue
            }

            let content = String(cString: contentText)
            let metadataString = String(cString: metadataText)
            let noteTitle = String(cString: noteTitleText)
            let notePath = String(cString: notePathText)
            let vaultName = String(cString: vaultNameText)

            // Parse metadata
            let metadata: ChunkMetadata
            if let metadataData = metadataString.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(ChunkMetadata.self, from: metadataData) {
                metadata = decoded
            } else {
                metadata = ChunkMetadata()
            }

            // Parse embedding
            let embeddingBlob = sqlite3_column_blob(stmt, 8)
            let embeddingSize = sqlite3_column_bytes(stmt, 8)

            guard embeddingSize > 0, let blob = embeddingBlob else {
                continue
            }

            let floatCount = Int(embeddingSize) / MemoryLayout<Float>.size
            let embedding = Array(UnsafeBufferPointer(
                start: blob.assumingMemoryBound(to: Float.self),
                count: floatCount
            ))

            // Calculate cosine similarity
            let similarity = cosineSimilarity(queryEmbedding, embedding)

            if similarity >= minSimilarity {
                let chunk = DocumentChunk(
                    id: id,
                    documentId: noteId,
                    index: Int(sqlite3_column_int(stmt, 3)),
                    content: content,
                    startOffset: Int(sqlite3_column_int(stmt, 5)),
                    endOffset: Int(sqlite3_column_int(stmt, 6)),
                    metadata: metadata,
                    embedding: embedding,
                    createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 9))
                )

                results.append((chunk, noteTitle, notePath, vaultName, similarity))
            }
        }

        // Sort by similarity (descending) and take top results
        let sorted = results.sorted { $0.similarity > $1.similarity }
        let topResults = sorted.prefix(limit)

        return topResults.map { item in
            VectorStoreSearchResult(
                chunk: item.chunk,
                score: item.similarity,
                noteTitle: item.noteTitle,
                notePath: item.notePath,
                vaultName: item.vaultName
            )
        }
    }

    // MARK: - Utility

    /// Get total chunk count for a vault
    func getChunkCount(forVault vaultId: UUID) throws -> Int {
        guard db != nil else { throw ObsidianVectorStoreError.databaseNotOpen }

        let sql = "SELECT COUNT(*) FROM chunks WHERE vault_id = ?"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ObsidianVectorStoreError.databaseError(lastErrorMessage)
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, vaultId.uuidString, -1, SQLITE_TRANSIENT)

        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }

        return 0
    }

    /// Clear all data
    func clearAll() throws {
        guard db != nil else { throw ObsidianVectorStoreError.databaseNotOpen }
        try execute("DELETE FROM chunks")
        try execute("DELETE FROM notes")
        try execute("DELETE FROM vaults")
        appLog("Cleared all Obsidian vault data", category: "Obsidian")
    }

    /// Load all chunks for a vault (for uploading to iCloud)
    func getAllChunks(forVault vaultId: UUID) throws -> [(id: UUID, noteId: UUID, content: String, startOffset: Int, endOffset: Int, embedding: [Float])] {
        guard db != nil else { throw ObsidianVectorStoreError.databaseNotOpen }

        let sql = """
        SELECT id, note_id, content, start_offset, end_offset, embedding
        FROM chunks
        WHERE vault_id = ?
        ORDER BY note_id, chunk_index
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ObsidianVectorStoreError.databaseError(lastErrorMessage)
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, vaultId.uuidString, -1, SQLITE_TRANSIENT)

        var results: [(UUID, UUID, String, Int, Int, [Float])] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let idString = sqlite3_column_text(stmt, 0),
                  let noteIdString = sqlite3_column_text(stmt, 1),
                  let contentText = sqlite3_column_text(stmt, 2) else {
                continue
            }

            guard let id = UUID(uuidString: String(cString: idString)),
                  let noteId = UUID(uuidString: String(cString: noteIdString)) else {
                continue
            }

            let content = String(cString: contentText)
            let startOffset = Int(sqlite3_column_int(stmt, 3))
            let endOffset = Int(sqlite3_column_int(stmt, 4))

            // Parse embedding
            let embeddingBlob = sqlite3_column_blob(stmt, 5)
            let embeddingSize = sqlite3_column_bytes(stmt, 5)

            guard embeddingSize > 0, let blob = embeddingBlob else {
                continue
            }

            let floatCount = Int(embeddingSize) / MemoryLayout<Float>.size
            let embedding = Array(UnsafeBufferPointer(
                start: blob.assumingMemoryBound(to: Float.self),
                count: floatCount
            ))

            results.append((id, noteId, content, startOffset, endOffset, embedding))
        }

        return results
    }

    // MARK: - Private Helpers

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw ObsidianVectorStoreError.databaseError(lastErrorMessage)
        }
    }

    private var lastErrorMessage: String {
        if let errorPointer = sqlite3_errmsg(db) {
            return String(cString: errorPointer)
        }
        return "Unknown database error"
    }

    /// Calculate cosine similarity between two vectors
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

// MARK: - Vector Store Search Result

/// Internal result type for vector store searches (used by ObsidianQueryService)
struct VectorStoreSearchResult: Identifiable {
    let id = UUID()
    let chunk: DocumentChunk
    let score: Float
    let noteTitle: String
    let notePath: String
    let vaultName: String

    /// Human-readable similarity percentage
    var similarityPercentage: Int {
        Int(score * 100)
    }
}

// MARK: - Browse All Chunks

extension ObsidianVectorStore {

    /// Get all chunks from specified vaults without similarity filtering (for browsing)
    func getAllChunks(
        vaultIds: [UUID],
        limit: Int = 50
    ) throws -> [VectorStoreSearchResult] {
        guard db != nil else { throw ObsidianVectorStoreError.databaseNotOpen }
        guard !vaultIds.isEmpty else { return [] }

        // Build SQL with vault filter
        let vaultPlaceholders = vaultIds.map { _ in "?" }.joined(separator: ", ")
        let sql = """
        SELECT c.id, c.note_id, c.vault_id, c.chunk_index, c.content, c.start_offset, c.end_offset,
               c.metadata, c.created_at, n.title as note_title, n.relative_path,
               v.name as vault_name
        FROM chunks c
        JOIN notes n ON c.note_id = n.id
        JOIN vaults v ON c.vault_id = v.id
        WHERE c.vault_id IN (\(vaultPlaceholders))
        GROUP BY n.id
        ORDER BY n.title ASC
        LIMIT ?
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ObsidianVectorStoreError.databaseError(lastErrorMessage)
        }
        defer { sqlite3_finalize(stmt) }

        // Bind vault IDs
        for (index, vaultId) in vaultIds.enumerated() {
            sqlite3_bind_text(stmt, Int32(index + 1), vaultId.uuidString, -1, SQLITE_TRANSIENT)
        }

        // Bind limit
        sqlite3_bind_int(stmt, Int32(vaultIds.count + 1), Int32(limit))

        var results: [VectorStoreSearchResult] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let idString = sqlite3_column_text(stmt, 0),
                  let noteIdString = sqlite3_column_text(stmt, 1),
                  let vaultIdString = sqlite3_column_text(stmt, 2),
                  let contentText = sqlite3_column_text(stmt, 4) else {
                continue
            }

            guard let chunkId = UUID(uuidString: String(cString: idString)),
                  let noteId = UUID(uuidString: String(cString: noteIdString)),
                  let vaultId = UUID(uuidString: String(cString: vaultIdString)) else {
                continue
            }

            let chunkIndex = Int(sqlite3_column_int(stmt, 3))
            let content = String(cString: contentText)
            let startOffset = Int(sqlite3_column_int(stmt, 5))
            let endOffset = Int(sqlite3_column_int(stmt, 6))

            // Parse metadata if present
            var metadata: [String: String] = [:]
            if let metadataText = sqlite3_column_text(stmt, 7) {
                let metadataJson = String(cString: metadataText)
                if let data = metadataJson.data(using: .utf8),
                   let parsed = try? JSONDecoder().decode([String: String].self, from: data) {
                    metadata = parsed
                }
            }

            let noteTitle = sqlite3_column_text(stmt, 9).map { String(cString: $0) } ?? "Untitled"
            let notePath = sqlite3_column_text(stmt, 10).map { String(cString: $0) } ?? ""
            let vaultName = sqlite3_column_text(stmt, 11).map { String(cString: $0) } ?? "Unknown"

            // Build ChunkMetadata from parsed metadata dictionary
            let chunkMetadata = ChunkMetadata(
                section: metadata["section"],
                pageNumber: nil,
                startLine: nil,
                endLine: nil,
                isHeader: false,
                contentType: .paragraph
            )

            let chunk = DocumentChunk(
                id: chunkId,
                documentId: noteId,
                index: chunkIndex,
                content: content,
                startOffset: startOffset,
                endOffset: endOffset,
                metadata: chunkMetadata
            )

            let result = VectorStoreSearchResult(
                chunk: chunk,
                score: 1.0, // No similarity filtering
                noteTitle: noteTitle,
                notePath: notePath,
                vaultName: vaultName
            )

            results.append(result)
        }

        return results
    }
}

// MARK: - SQLite Constants

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
