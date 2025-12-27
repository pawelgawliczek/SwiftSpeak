//
//  VectorStore.swift
//  SwiftSpeak
//
//  SQLite-based vector store for document chunk embeddings
//  Supports cosine similarity search for RAG retrieval
//

import Foundation
import SQLite3

// MARK: - Vector Store Errors

enum VectorStoreError: Error, LocalizedError {
    case databaseNotOpen
    case databaseError(String)
    case documentNotFound(UUID)
    case chunkNotFound(UUID)
    case embeddingDimensionMismatch(expected: Int, got: Int)
    case serializationError

    var errorDescription: String? {
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

// MARK: - Vector Store

@MainActor
final class VectorStore {

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

        // Store in App Group container for sharing with keyboard
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.pawelgawliczek.swiftspeak"
        ) ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        self.dbPath = containerURL.appendingPathComponent("vector_store.db").path
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
            throw VectorStoreError.databaseError(lastErrorMessage)
        }

        try createTables()
    }

    func close() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }

    private func createTables() throws {
        let createDocumentsSQL = """
        CREATE TABLE IF NOT EXISTS documents (
            id TEXT PRIMARY KEY,
            power_mode_id TEXT NOT NULL,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            source_url TEXT,
            content_hash TEXT NOT NULL,
            chunk_count INTEGER NOT NULL,
            file_size_bytes INTEGER NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            UNIQUE(id)
        );
        CREATE INDEX IF NOT EXISTS idx_documents_power_mode ON documents(power_mode_id);
        """

        let createChunksSQL = """
        CREATE TABLE IF NOT EXISTS chunks (
            id TEXT PRIMARY KEY,
            document_id TEXT NOT NULL,
            chunk_index INTEGER NOT NULL,
            content TEXT NOT NULL,
            start_offset INTEGER NOT NULL,
            end_offset INTEGER NOT NULL,
            metadata TEXT NOT NULL,
            embedding BLOB,
            created_at REAL NOT NULL,
            FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_chunks_document ON chunks(document_id);
        """

        try execute(createDocumentsSQL)
        try execute(createChunksSQL)
    }

    // MARK: - Document Operations

    /// Store a document record
    func storeDocument(_ document: KnowledgeDocument, powerModeId: UUID) throws {
        guard db != nil else { throw VectorStoreError.databaseNotOpen }

        let sql = """
        INSERT OR REPLACE INTO documents
        (id, power_mode_id, name, type, source_url, content_hash, chunk_count, file_size_bytes, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseError(lastErrorMessage)
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, document.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, powerModeId.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, document.name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, document.type.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 5, document.sourceURL?.absoluteString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 6, document.contentHash, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 7, Int32(document.chunkCount))
        sqlite3_bind_int64(stmt, 8, Int64(document.fileSizeBytes))
        sqlite3_bind_double(stmt, 9, document.lastUpdated.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 10, Date().timeIntervalSince1970)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw VectorStoreError.databaseError(lastErrorMessage)
        }
    }

    /// Delete a document and all its chunks
    func deleteDocument(_ documentId: UUID) throws {
        guard db != nil else { throw VectorStoreError.databaseNotOpen }

        // Delete chunks first (foreign key cascade should handle this)
        try execute("DELETE FROM chunks WHERE document_id = '\(documentId.uuidString)'")
        try execute("DELETE FROM documents WHERE id = '\(documentId.uuidString)'")
    }

    /// Get all documents for a power mode
    func getDocuments(forPowerMode powerModeId: UUID) throws -> [UUID] {
        guard db != nil else { throw VectorStoreError.databaseNotOpen }

        let sql = "SELECT id FROM documents WHERE power_mode_id = ?"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseError(lastErrorMessage)
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, powerModeId.uuidString, -1, SQLITE_TRANSIENT)

        var documentIds: [UUID] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cString = sqlite3_column_text(stmt, 0),
               let uuid = UUID(uuidString: String(cString: cString)) {
                documentIds.append(uuid)
            }
        }

        return documentIds
    }

    // MARK: - Chunk Operations

    /// Store chunks with embeddings
    func storeChunks(_ chunks: [DocumentChunk]) throws {
        guard db != nil else { throw VectorStoreError.databaseNotOpen }

        let sql = """
        INSERT OR REPLACE INTO chunks
        (id, document_id, chunk_index, content, start_offset, end_offset, metadata, embedding, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        try execute("BEGIN TRANSACTION")

        do {
            for chunk in chunks {
                var stmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                    throw VectorStoreError.databaseError(lastErrorMessage)
                }
                defer { sqlite3_finalize(stmt) }

                sqlite3_bind_text(stmt, 1, chunk.id.uuidString, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, chunk.documentId.uuidString, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(stmt, 3, Int32(chunk.index))
                sqlite3_bind_text(stmt, 4, chunk.content, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(stmt, 5, Int32(chunk.startOffset))
                sqlite3_bind_int(stmt, 6, Int32(chunk.endOffset))

                // Serialize metadata as JSON
                let metadataData = try JSONEncoder().encode(chunk.metadata)
                let metadataString = String(data: metadataData, encoding: .utf8) ?? "{}"
                sqlite3_bind_text(stmt, 7, metadataString, -1, SQLITE_TRANSIENT)

                // Serialize embedding as blob
                if let embedding = chunk.embedding {
                    let embeddingData = embedding.withUnsafeBufferPointer { Data(buffer: $0) }
                    _ = embeddingData.withUnsafeBytes { bytes in
                        sqlite3_bind_blob(stmt, 8, bytes.baseAddress, Int32(embeddingData.count), SQLITE_TRANSIENT)
                    }
                } else {
                    sqlite3_bind_null(stmt, 8)
                }

                sqlite3_bind_double(stmt, 9, chunk.createdAt.timeIntervalSince1970)

                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw VectorStoreError.databaseError(lastErrorMessage)
                }
            }

            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    /// Delete all chunks for a document
    func deleteChunks(forDocument documentId: UUID) throws {
        guard db != nil else { throw VectorStoreError.databaseNotOpen }
        try execute("DELETE FROM chunks WHERE document_id = '\(documentId.uuidString)'")
    }

    // MARK: - Similarity Search

    /// Find most similar chunks to a query embedding
    func search(
        queryEmbedding: [Float],
        documentIds: [UUID]? = nil,
        limit: Int = 5,
        minSimilarity: Float = 0.0
    ) throws -> [SimilarityResult] {
        guard db != nil else { throw VectorStoreError.databaseNotOpen }

        // Validate embedding dimensions
        guard queryEmbedding.count == expectedDimensions else {
            throw VectorStoreError.embeddingDimensionMismatch(
                expected: expectedDimensions,
                got: queryEmbedding.count
            )
        }

        // Build query with optional document filter
        var sql = """
        SELECT c.id, c.document_id, c.chunk_index, c.content, c.start_offset, c.end_offset,
               c.metadata, c.embedding, c.created_at, d.name as document_name
        FROM chunks c
        JOIN documents d ON c.document_id = d.id
        WHERE c.embedding IS NOT NULL
        """

        if let docIds = documentIds, !docIds.isEmpty {
            let idList = docIds.map { "'\($0.uuidString)'" }.joined(separator: ",")
            sql += " AND c.document_id IN (\(idList))"
        }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseError(lastErrorMessage)
        }
        defer { sqlite3_finalize(stmt) }

        var results: [(chunk: DocumentChunk, documentName: String, similarity: Float)] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            // Parse chunk data
            guard let idString = sqlite3_column_text(stmt, 0),
                  let documentIdString = sqlite3_column_text(stmt, 1),
                  let contentText = sqlite3_column_text(stmt, 3),
                  let metadataText = sqlite3_column_text(stmt, 6),
                  let documentNameText = sqlite3_column_text(stmt, 9) else {
                continue
            }

            guard let id = UUID(uuidString: String(cString: idString)),
                  let documentId = UUID(uuidString: String(cString: documentIdString)) else {
                continue
            }

            let content = String(cString: contentText)
            let metadataString = String(cString: metadataText)
            let documentName = String(cString: documentNameText)

            // Parse metadata
            let metadata: ChunkMetadata
            if let metadataData = metadataString.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(ChunkMetadata.self, from: metadataData) {
                metadata = decoded
            } else {
                metadata = ChunkMetadata()
            }

            // Parse embedding
            let embeddingBlob = sqlite3_column_blob(stmt, 7)
            let embeddingSize = sqlite3_column_bytes(stmt, 7)

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
                    documentId: documentId,
                    index: Int(sqlite3_column_int(stmt, 2)),
                    content: content,
                    startOffset: Int(sqlite3_column_int(stmt, 4)),
                    endOffset: Int(sqlite3_column_int(stmt, 5)),
                    metadata: metadata,
                    embedding: embedding,
                    createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 8))
                )

                results.append((chunk, documentName, similarity))
            }
        }

        // Sort by similarity (descending) and take top results
        let sorted = results.sorted { $0.similarity > $1.similarity }
        let topResults = sorted.prefix(limit)

        return topResults.map { item in
            SimilarityResult(
                id: item.chunk.id,
                chunk: item.chunk,
                score: item.similarity,
                documentName: item.documentName
            )
        }
    }

    // MARK: - Utility

    /// Get total chunk count
    func getTotalChunkCount() throws -> Int {
        guard db != nil else { throw VectorStoreError.databaseNotOpen }

        let sql = "SELECT COUNT(*) FROM chunks"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseError(lastErrorMessage)
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }

        return 0
    }

    /// Get chunk count for a document
    func getChunkCount(forDocument documentId: UUID) throws -> Int {
        guard db != nil else { throw VectorStoreError.databaseNotOpen }

        let sql = "SELECT COUNT(*) FROM chunks WHERE document_id = ?"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseError(lastErrorMessage)
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, documentId.uuidString, -1, SQLITE_TRANSIENT)

        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }

        return 0
    }

    /// Clear all data
    func clearAll() throws {
        guard db != nil else { throw VectorStoreError.databaseNotOpen }
        try execute("DELETE FROM chunks")
        try execute("DELETE FROM documents")
    }

    // MARK: - Private Helpers

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseError(lastErrorMessage)
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

// MARK: - SQLite Constants

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
