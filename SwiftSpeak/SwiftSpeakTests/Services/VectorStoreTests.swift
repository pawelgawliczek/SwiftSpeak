//
//  VectorStoreTests.swift
//  SwiftSpeakTests
//
//  Tests for VectorStore - SQLite-based vector storage for RAG
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

// MARK: - Database Lifecycle Tests

@Suite("VectorStore - Lifecycle")
struct VectorStoreLifecycleTests {

    @Test("Opens database successfully")
    @MainActor
    func opensDatabase() throws {
        let store = VectorStore()
        #expect(!store.isOpen)

        try store.open()
        #expect(store.isOpen)

        store.close()
        #expect(!store.isOpen)
    }

    @Test("Multiple open calls are safe")
    @MainActor
    func multipleOpensAreSafe() throws {
        let store = VectorStore()

        try store.open()
        try store.open() // Should not throw
        #expect(store.isOpen)

        store.close()
    }

    @Test("Multiple close calls are safe")
    @MainActor
    func multipleClosesAreSafe() throws {
        let store = VectorStore()

        try store.open()
        store.close()
        store.close() // Should not crash
        #expect(!store.isOpen)
    }
}

// MARK: - Document Operations Tests

@Suite("VectorStore - Documents")
struct VectorStoreDocumentTests {

    @Test("Stores and retrieves document")
    @MainActor
    func storesAndRetrievesDocument() throws {
        let store = VectorStore()
        try store.open()
        defer { store.close() }
        try store.clearAll()

        let powerModeId = UUID()
        let document = KnowledgeDocument(
            name: "Test Document",
            type: .text,
            contentHash: "abc123",
            chunkCount: 5,
            fileSizeBytes: 1024,
            isIndexed: true
        )

        try store.storeDocument(document, powerModeId: powerModeId)

        let documents = try store.getDocuments(forPowerMode: powerModeId)
        #expect(documents.count == 1)
        #expect(documents.first == document.id)
    }

    @Test("Gets documents for correct power mode only")
    @MainActor
    func getsDocumentsForCorrectPowerMode() throws {
        let store = VectorStore()
        try store.open()
        defer { store.close() }
        try store.clearAll()

        let powerModeId1 = UUID()
        let powerModeId2 = UUID()

        let doc1 = KnowledgeDocument(name: "Doc 1", type: .text, contentHash: "a")
        let doc2 = KnowledgeDocument(name: "Doc 2", type: .pdf, contentHash: "b")
        let doc3 = KnowledgeDocument(name: "Doc 3", type: .markdown, contentHash: "c")

        try store.storeDocument(doc1, powerModeId: powerModeId1)
        try store.storeDocument(doc2, powerModeId: powerModeId1)
        try store.storeDocument(doc3, powerModeId: powerModeId2)

        let docsForPM1 = try store.getDocuments(forPowerMode: powerModeId1)
        let docsForPM2 = try store.getDocuments(forPowerMode: powerModeId2)

        #expect(docsForPM1.count == 2)
        #expect(docsForPM2.count == 1)
        #expect(docsForPM2.first == doc3.id)
    }

    @Test("Deletes document")
    @MainActor
    func deletesDocument() throws {
        let store = VectorStore()
        try store.open()
        defer { store.close() }
        try store.clearAll()

        let powerModeId = UUID()
        let document = KnowledgeDocument(name: "To Delete", type: .text, contentHash: "x")

        try store.storeDocument(document, powerModeId: powerModeId)
        #expect(try store.getDocuments(forPowerMode: powerModeId).count == 1)

        try store.deleteDocument(document.id)
        #expect(try store.getDocuments(forPowerMode: powerModeId).count == 0)
    }

    @Test("Throws when database not open")
    @MainActor
    func throwsWhenDatabaseNotOpen() throws {
        let store = VectorStore()
        // Don't open the database

        let document = KnowledgeDocument(name: "Test", type: .text, contentHash: "x")

        #expect(throws: VectorStoreError.self) {
            try store.storeDocument(document, powerModeId: UUID())
        }

        #expect(throws: VectorStoreError.self) {
            _ = try store.getDocuments(forPowerMode: UUID())
        }
    }
}

// MARK: - Chunk Operations Tests

@Suite("VectorStore - Chunks")
struct VectorStoreChunkTests {

    @Test("Stores chunks")
    @MainActor
    func storesChunks() throws {
        let store = VectorStore()
        try store.open()
        defer { store.close() }
        try store.clearAll()

        let documentId = UUID()
        let powerModeId = UUID()

        // Store document first (required for foreign key)
        let document = KnowledgeDocument(id: documentId, name: "Test", type: .text, contentHash: "x")
        try store.storeDocument(document, powerModeId: powerModeId)

        let chunks = [
            DocumentChunk(documentId: documentId, index: 0, content: "First chunk", startOffset: 0, endOffset: 11),
            DocumentChunk(documentId: documentId, index: 1, content: "Second chunk", startOffset: 12, endOffset: 24),
            DocumentChunk(documentId: documentId, index: 2, content: "Third chunk", startOffset: 25, endOffset: 36)
        ]

        try store.storeChunks(chunks)

        let count = try store.getChunkCount(forDocument: documentId)
        #expect(count == 3)
    }

    @Test("Stores chunks with embeddings")
    @MainActor
    func storesChunksWithEmbeddings() throws {
        let store = VectorStore()
        try store.open()
        defer { store.close() }
        try store.clearAll()

        let documentId = UUID()
        let powerModeId = UUID()

        let document = KnowledgeDocument(id: documentId, name: "Test", type: .text, contentHash: "x")
        try store.storeDocument(document, powerModeId: powerModeId)

        // Create a chunk with an embedding (1536 dimensions for OpenAI small)
        let embedding = (0..<1536).map { _ in Float.random(in: -1...1) }
        let chunk = DocumentChunk(
            documentId: documentId,
            index: 0,
            content: "Chunk with embedding",
            startOffset: 0,
            endOffset: 20,
            embedding: embedding
        )

        try store.storeChunks([chunk])

        let count = try store.getChunkCount(forDocument: documentId)
        #expect(count == 1)
    }

    @Test("Stores chunks with metadata")
    @MainActor
    func storesChunksWithMetadata() throws {
        let store = VectorStore()
        try store.open()
        defer { store.close() }
        try store.clearAll()

        let documentId = UUID()
        let powerModeId = UUID()

        let document = KnowledgeDocument(id: documentId, name: "Test", type: .text, contentHash: "x")
        try store.storeDocument(document, powerModeId: powerModeId)

        let metadata = ChunkMetadata(
            section: "Introduction",
            pageNumber: 1,
            startLine: 10,
            endLine: 20,
            isHeader: true,
            contentType: .header
        )

        let chunk = DocumentChunk(
            documentId: documentId,
            index: 0,
            content: "# Introduction",
            startOffset: 0,
            endOffset: 14,
            metadata: metadata
        )

        try store.storeChunks([chunk])

        let count = try store.getChunkCount(forDocument: documentId)
        #expect(count == 1)
    }

    @Test("Deletes chunks for document")
    @MainActor
    func deletesChunksForDocument() throws {
        let store = VectorStore()
        try store.open()
        defer { store.close() }
        try store.clearAll()

        let documentId = UUID()
        let powerModeId = UUID()

        let document = KnowledgeDocument(id: documentId, name: "Test", type: .text, contentHash: "x")
        try store.storeDocument(document, powerModeId: powerModeId)

        let chunks = [
            DocumentChunk(documentId: documentId, index: 0, content: "Chunk 1", startOffset: 0, endOffset: 7),
            DocumentChunk(documentId: documentId, index: 1, content: "Chunk 2", startOffset: 8, endOffset: 15)
        ]

        try store.storeChunks(chunks)
        #expect(try store.getChunkCount(forDocument: documentId) == 2)

        try store.deleteChunks(forDocument: documentId)
        #expect(try store.getChunkCount(forDocument: documentId) == 0)
    }

    @Test("Gets total chunk count")
    @MainActor
    func getTotalChunkCount() throws {
        let store = VectorStore()
        try store.open()
        defer { store.close() }
        try store.clearAll()

        let documentId1 = UUID()
        let documentId2 = UUID()
        let powerModeId = UUID()

        let doc1 = KnowledgeDocument(id: documentId1, name: "Doc 1", type: .text, contentHash: "a")
        let doc2 = KnowledgeDocument(id: documentId2, name: "Doc 2", type: .text, contentHash: "b")
        try store.storeDocument(doc1, powerModeId: powerModeId)
        try store.storeDocument(doc2, powerModeId: powerModeId)

        let chunks1 = [
            DocumentChunk(documentId: documentId1, index: 0, content: "A", startOffset: 0, endOffset: 1),
            DocumentChunk(documentId: documentId1, index: 1, content: "B", startOffset: 2, endOffset: 3)
        ]
        let chunks2 = [
            DocumentChunk(documentId: documentId2, index: 0, content: "C", startOffset: 0, endOffset: 1)
        ]

        try store.storeChunks(chunks1)
        try store.storeChunks(chunks2)

        let total = try store.getTotalChunkCount()
        #expect(total == 3)
    }
}

// MARK: - Similarity Search Tests

@Suite("VectorStore - Similarity Search")
struct VectorStoreSimilaritySearchTests {

    @Test("Searches for similar chunks")
    @MainActor
    func searchesSimilarChunks() throws {
        let store = VectorStore()
        try store.open()
        defer { store.close() }
        try store.clearAll()

        let documentId = UUID()
        let powerModeId = UUID()

        let document = KnowledgeDocument(id: documentId, name: "Test Doc", type: .text, contentHash: "x")
        try store.storeDocument(document, powerModeId: powerModeId)

        // Create chunks with embeddings
        let embedding1 = createNormalizedEmbedding(base: 0.1, dimensions: 1536)
        let embedding2 = createNormalizedEmbedding(base: 0.5, dimensions: 1536)
        let embedding3 = createNormalizedEmbedding(base: 0.9, dimensions: 1536)

        let chunks = [
            DocumentChunk(documentId: documentId, index: 0, content: "Low similarity content", startOffset: 0, endOffset: 22, embedding: embedding1),
            DocumentChunk(documentId: documentId, index: 1, content: "Medium similarity content", startOffset: 23, endOffset: 48, embedding: embedding2),
            DocumentChunk(documentId: documentId, index: 2, content: "High similarity content", startOffset: 49, endOffset: 72, embedding: embedding3)
        ]

        try store.storeChunks(chunks)

        // Search with a query similar to embedding3
        let queryEmbedding = createNormalizedEmbedding(base: 0.85, dimensions: 1536)
        let results = try store.search(queryEmbedding: queryEmbedding, limit: 3)

        #expect(results.count == 3)
        // Results should be sorted by similarity (descending)
        #expect(results.first?.chunk.content == "High similarity content")
    }

    @Test("Respects result limit")
    @MainActor
    func respectsResultLimit() throws {
        let store = VectorStore()
        try store.open()
        defer { store.close() }
        try store.clearAll()

        let documentId = UUID()
        let powerModeId = UUID()

        let document = KnowledgeDocument(id: documentId, name: "Test Doc", type: .text, contentHash: "x")
        try store.storeDocument(document, powerModeId: powerModeId)

        // Create 10 chunks with embeddings
        var chunks: [DocumentChunk] = []
        for i in 0..<10 {
            let embedding = createNormalizedEmbedding(base: Float(i) / 10.0, dimensions: 1536)
            chunks.append(DocumentChunk(
                documentId: documentId,
                index: i,
                content: "Chunk \(i)",
                startOffset: i * 10,
                endOffset: (i + 1) * 10,
                embedding: embedding
            ))
        }

        try store.storeChunks(chunks)

        let queryEmbedding = createNormalizedEmbedding(base: 0.5, dimensions: 1536)
        let results = try store.search(queryEmbedding: queryEmbedding, limit: 3)

        #expect(results.count == 3)
    }

    @Test("Filters by document IDs")
    @MainActor
    func filtersByDocumentIds() throws {
        let store = VectorStore()
        try store.open()
        defer { store.close() }
        try store.clearAll()

        let documentId1 = UUID()
        let documentId2 = UUID()
        let powerModeId = UUID()

        let doc1 = KnowledgeDocument(id: documentId1, name: "Doc 1", type: .text, contentHash: "a")
        let doc2 = KnowledgeDocument(id: documentId2, name: "Doc 2", type: .text, contentHash: "b")
        try store.storeDocument(doc1, powerModeId: powerModeId)
        try store.storeDocument(doc2, powerModeId: powerModeId)

        let embedding = createNormalizedEmbedding(base: 0.5, dimensions: 1536)

        let chunks1 = [DocumentChunk(documentId: documentId1, index: 0, content: "Doc 1 content", startOffset: 0, endOffset: 13, embedding: embedding)]
        let chunks2 = [DocumentChunk(documentId: documentId2, index: 0, content: "Doc 2 content", startOffset: 0, endOffset: 13, embedding: embedding)]

        try store.storeChunks(chunks1)
        try store.storeChunks(chunks2)

        // Search only in doc1
        let results = try store.search(queryEmbedding: embedding, documentIds: [documentId1], limit: 10)

        #expect(results.count == 1)
        #expect(results.first?.chunk.documentId == documentId1)
    }

    @Test("Respects minimum similarity threshold")
    @MainActor
    func respectsMinimumSimilarity() throws {
        let store = VectorStore()
        try store.open()
        defer { store.close() }
        try store.clearAll()

        let documentId = UUID()
        let powerModeId = UUID()

        let document = KnowledgeDocument(id: documentId, name: "Test Doc", type: .text, contentHash: "x")
        try store.storeDocument(document, powerModeId: powerModeId)

        // Create chunks with very different embeddings
        let embeddingHigh = createNormalizedEmbedding(base: 0.9, dimensions: 1536)
        let embeddingLow = createNormalizedEmbedding(base: 0.1, dimensions: 1536)

        let chunks = [
            DocumentChunk(documentId: documentId, index: 0, content: "High match", startOffset: 0, endOffset: 10, embedding: embeddingHigh),
            DocumentChunk(documentId: documentId, index: 1, content: "Low match", startOffset: 11, endOffset: 20, embedding: embeddingLow)
        ]

        try store.storeChunks(chunks)

        let queryEmbedding = createNormalizedEmbedding(base: 0.9, dimensions: 1536)

        // With high minimum similarity, should filter out low match
        let results = try store.search(queryEmbedding: queryEmbedding, limit: 10, minSimilarity: 0.9)

        #expect(results.count <= 1)
        if let first = results.first {
            #expect(first.score >= 0.9)
        }
    }

    @Test("Throws on dimension mismatch")
    @MainActor
    func throwsOnDimensionMismatch() throws {
        let store = VectorStore()
        try store.open()
        defer { store.close() }
        try store.clearAll()

        // Query with wrong dimensions (expected 1536 for OpenAI small)
        let wrongSizedEmbedding = [Float](repeating: 0.5, count: 100)

        #expect(throws: VectorStoreError.self) {
            _ = try store.search(queryEmbedding: wrongSizedEmbedding, limit: 5)
        }
    }

    @Test("Returns document name in results")
    @MainActor
    func returnsDocumentNameInResults() throws {
        let store = VectorStore()
        try store.open()
        defer { store.close() }
        try store.clearAll()

        let documentId = UUID()
        let powerModeId = UUID()
        let documentName = "Important Research Paper"

        let document = KnowledgeDocument(id: documentId, name: documentName, type: .pdf, contentHash: "x")
        try store.storeDocument(document, powerModeId: powerModeId)

        let embedding = createNormalizedEmbedding(base: 0.5, dimensions: 1536)
        let chunk = DocumentChunk(documentId: documentId, index: 0, content: "Content", startOffset: 0, endOffset: 7, embedding: embedding)
        try store.storeChunks([chunk])

        let results = try store.search(queryEmbedding: embedding, limit: 1)

        #expect(results.first?.documentName == documentName)
    }
}

// MARK: - Clear Operations Tests

@Suite("VectorStore - Clear")
struct VectorStoreClearTests {

    @Test("Clears all data")
    @MainActor
    func clearsAllData() throws {
        let store = VectorStore()
        try store.open()
        defer { store.close() }

        let documentId = UUID()
        let powerModeId = UUID()

        let document = KnowledgeDocument(id: documentId, name: "Test", type: .text, contentHash: "x")
        try store.storeDocument(document, powerModeId: powerModeId)

        let chunks = [
            DocumentChunk(documentId: documentId, index: 0, content: "Chunk", startOffset: 0, endOffset: 5)
        ]
        try store.storeChunks(chunks)

        #expect(try store.getTotalChunkCount() == 1)
        #expect(try store.getDocuments(forPowerMode: powerModeId).count == 1)

        try store.clearAll()

        #expect(try store.getTotalChunkCount() == 0)
        #expect(try store.getDocuments(forPowerMode: powerModeId).count == 0)
    }
}

// MARK: - Cosine Similarity Tests

@Suite("VectorStore - Cosine Similarity")
struct VectorStoreCosineSimilarityTests {

    @Test("Identical vectors have similarity of 1")
    @MainActor
    func identicalVectorsHaveSimilarityOne() throws {
        let store = VectorStore()
        try store.open()
        defer { store.close() }
        try store.clearAll()

        let documentId = UUID()
        let powerModeId = UUID()

        let document = KnowledgeDocument(id: documentId, name: "Test", type: .text, contentHash: "x")
        try store.storeDocument(document, powerModeId: powerModeId)

        let embedding = createNormalizedEmbedding(base: 0.5, dimensions: 1536)
        let chunk = DocumentChunk(documentId: documentId, index: 0, content: "Test", startOffset: 0, endOffset: 4, embedding: embedding)
        try store.storeChunks([chunk])

        let results = try store.search(queryEmbedding: embedding, limit: 1)

        #expect(results.count == 1)
        // Identical vectors should have very high similarity (close to 1)
        #expect(results.first!.score > 0.99)
    }

    @Test("Similar vectors have high similarity")
    @MainActor
    func similarVectorsHaveHighSimilarity() throws {
        let store = VectorStore()
        try store.open()
        defer { store.close() }
        try store.clearAll()

        let documentId = UUID()
        let powerModeId = UUID()

        let document = KnowledgeDocument(id: documentId, name: "Test", type: .text, contentHash: "x")
        try store.storeDocument(document, powerModeId: powerModeId)

        // Create similar embeddings
        let embedding1 = createNormalizedEmbedding(base: 0.5, dimensions: 1536)
        let embedding2 = createNormalizedEmbedding(base: 0.52, dimensions: 1536)

        let chunk = DocumentChunk(documentId: documentId, index: 0, content: "Test", startOffset: 0, endOffset: 4, embedding: embedding1)
        try store.storeChunks([chunk])

        let results = try store.search(queryEmbedding: embedding2, limit: 1)

        // Similar embeddings should have high similarity
        #expect(results.first!.score > 0.9)
    }
}

// MARK: - Helper Functions

/// Creates a normalized embedding vector with values based on a base value
private func createNormalizedEmbedding(base: Float, dimensions: Int) -> [Float] {
    var embedding = (0..<dimensions).map { i -> Float in
        let variation = sin(Float(i) * 0.01) * 0.1
        return base + variation
    }

    // Normalize to unit vector
    let magnitude = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
    if magnitude > 0 {
        embedding = embedding.map { $0 / magnitude }
    }

    return embedding
}
