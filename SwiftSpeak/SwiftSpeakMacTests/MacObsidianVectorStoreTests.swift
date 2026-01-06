//
//  MacObsidianVectorStoreTests.swift
//  SwiftSpeakMacTests
//
//  Tests for MacObsidianVectorStore - Obsidian search and storage
//

import Testing
import Foundation
@testable import SwiftSpeakMac
import SwiftSpeakCore

@MainActor
@Suite("MacObsidianVectorStore Tests")
struct MacObsidianVectorStoreTests {

    // MARK: - Cosine Similarity Tests

    @Test("Identical vectors have similarity 1.0")
    func testIdenticalVectorsSimilarity() {
        let vectorA = [Float](repeating: 0.5, count: 1536)
        let vectorB = [Float](repeating: 0.5, count: 1536)

        let similarity = cosineSimilarity(vectorA, vectorB)
        #expect(abs(similarity - 1.0) < 0.0001, "Identical vectors should have similarity ~1.0")
    }

    @Test("Opposite vectors have similarity -1.0")
    func testOppositeVectorsSimilarity() {
        var vectorA = [Float](repeating: 0.5, count: 1536)
        var vectorB = [Float](repeating: -0.5, count: 1536)

        let similarity = cosineSimilarity(vectorA, vectorB)
        #expect(abs(similarity - (-1.0)) < 0.0001, "Opposite vectors should have similarity ~-1.0")
    }

    @Test("Orthogonal vectors have similarity 0.0")
    func testOrthogonalVectorsSimilarity() {
        // Create two orthogonal vectors
        var vectorA = [Float](repeating: 0, count: 1536)
        var vectorB = [Float](repeating: 0, count: 1536)

        // First half of A is 1, second half is 0
        for i in 0..<768 { vectorA[i] = 1.0 }
        // First half of B is 0, second half is 1
        for i in 768..<1536 { vectorB[i] = 1.0 }

        let similarity = cosineSimilarity(vectorA, vectorB)
        #expect(abs(similarity) < 0.0001, "Orthogonal vectors should have similarity ~0.0")
    }

    @Test("Similar vectors have high similarity")
    func testSimilarVectorsSimilarity() {
        var vectorA = [Float](repeating: 0.5, count: 1536)
        var vectorB = [Float](repeating: 0.5, count: 1536)

        // Slightly modify B
        for i in 0..<100 {
            vectorB[i] = 0.6
        }

        let similarity = cosineSimilarity(vectorA, vectorB)
        #expect(similarity > 0.95, "Similar vectors should have high similarity (>0.95)")
    }

    @Test("Empty vectors have similarity 0.0")
    func testEmptyVectorsSimilarity() {
        let vectorA: [Float] = []
        let vectorB: [Float] = []

        let similarity = cosineSimilarity(vectorA, vectorB)
        #expect(similarity == 0, "Empty vectors should have similarity 0")
    }

    @Test("Different length vectors have similarity 0.0")
    func testDifferentLengthVectorsSimilarity() {
        let vectorA = [Float](repeating: 0.5, count: 100)
        let vectorB = [Float](repeating: 0.5, count: 200)

        let similarity = cosineSimilarity(vectorA, vectorB)
        #expect(similarity == 0, "Different length vectors should have similarity 0")
    }

    // MARK: - Search Tests

    @Test("Search returns results sorted by similarity")
    func testSearchReturnsSortedResults() throws {
        let store = MacObsidianVectorStore()
        let vaultId = UUID()

        // Create chunks with known similarities to query [1,1,1,...]
        let queryEmbedding = [Float](repeating: 1.0, count: 1536)

        // Chunk 1: Very similar (0.9, 0.9, ...)
        let highSimilarityEmbedding = [Float](repeating: 0.9, count: 1536)
        // Chunk 2: Somewhat similar (0.5, 0.5, ...)
        let mediumSimilarityEmbedding = [Float](repeating: 0.5, count: 1536)
        // Chunk 3: Less similar (0.3, 0.3, ...)
        let lowSimilarityEmbedding = [Float](repeating: 0.3, count: 1536)

        let chunks = [
            ObsidianChunk(
                vaultId: vaultId,
                noteId: UUID(),
                notePath: "low.md",
                noteTitle: "Low",
                content: "Low similarity content",
                chunkIndex: 0,
                embedding: lowSimilarityEmbedding
            ),
            ObsidianChunk(
                vaultId: vaultId,
                noteId: UUID(),
                notePath: "high.md",
                noteTitle: "High",
                content: "High similarity content",
                chunkIndex: 0,
                embedding: highSimilarityEmbedding
            ),
            ObsidianChunk(
                vaultId: vaultId,
                noteId: UUID(),
                notePath: "medium.md",
                noteTitle: "Medium",
                content: "Medium similarity content",
                chunkIndex: 0,
                embedding: mediumSimilarityEmbedding
            )
        ]

        // Save and search
        try store.save(chunks: chunks, for: vaultId)

        let results = try store.search(
            query: queryEmbedding,
            vaultIds: [vaultId],
            limit: 10,
            minSimilarity: 0.0
        )

        #expect(results.count == 3, "Should return all 3 chunks")
        #expect(results[0].noteTitle == "High", "First result should be highest similarity")
        #expect(results[1].noteTitle == "Medium", "Second result should be medium similarity")
        #expect(results[2].noteTitle == "Low", "Third result should be lowest similarity")

        // Clean up
        try store.delete(vaultId: vaultId)
    }

    @Test("Search respects minSimilarity threshold")
    func testSearchRespectsMinSimilarity() throws {
        let store = MacObsidianVectorStore()
        let vaultId = UUID()

        let queryEmbedding = [Float](repeating: 1.0, count: 1536)

        // Create chunks with different similarities
        let highSimilarityEmbedding = [Float](repeating: 0.95, count: 1536)  // ~1.0 similarity
        let lowSimilarityEmbedding = [Float](repeating: 0.1, count: 1536)    // ~0.1 similarity

        let chunks = [
            ObsidianChunk(
                vaultId: vaultId,
                noteId: UUID(),
                notePath: "high.md",
                noteTitle: "High",
                content: "High similarity",
                chunkIndex: 0,
                embedding: highSimilarityEmbedding
            ),
            ObsidianChunk(
                vaultId: vaultId,
                noteId: UUID(),
                notePath: "low.md",
                noteTitle: "Low",
                content: "Low similarity",
                chunkIndex: 0,
                embedding: lowSimilarityEmbedding
            )
        ]

        try store.save(chunks: chunks, for: vaultId)

        // Search with high threshold - should only return high similarity chunk
        let results = try store.search(
            query: queryEmbedding,
            vaultIds: [vaultId],
            limit: 10,
            minSimilarity: 0.5
        )

        #expect(results.count == 1, "Should only return chunks above minSimilarity")
        #expect(results[0].noteTitle == "High", "Should return high similarity chunk")

        // Clean up
        try store.delete(vaultId: vaultId)
    }

    @Test("Search deduplicates by notePath")
    func testSearchDeduplicatesByNotePath() throws {
        let store = MacObsidianVectorStore()
        let vaultId = UUID()

        let queryEmbedding = [Float](repeating: 1.0, count: 1536)
        let noteId = UUID()

        // Same note, multiple chunks with different similarities
        let chunks = [
            ObsidianChunk(
                vaultId: vaultId,
                noteId: noteId,
                notePath: "note.md",
                noteTitle: "Note",
                content: "Chunk 1 - high similarity",
                chunkIndex: 0,
                embedding: [Float](repeating: 0.9, count: 1536)
            ),
            ObsidianChunk(
                vaultId: vaultId,
                noteId: noteId,
                notePath: "note.md",
                noteTitle: "Note",
                content: "Chunk 2 - low similarity",
                chunkIndex: 1,
                embedding: [Float](repeating: 0.3, count: 1536)
            )
        ]

        try store.save(chunks: chunks, for: vaultId)

        let results = try store.search(
            query: queryEmbedding,
            vaultIds: [vaultId],
            limit: 10,
            minSimilarity: 0.0
        )

        #expect(results.count == 1, "Should deduplicate to 1 result per note")
        #expect(results[0].content.contains("Chunk 1"), "Should keep best matching chunk")

        // Clean up
        try store.delete(vaultId: vaultId)
    }

    @Test("Search respects limit parameter")
    func testSearchRespectsLimit() throws {
        let store = MacObsidianVectorStore()
        let vaultId = UUID()

        let queryEmbedding = [Float](repeating: 1.0, count: 1536)

        // Create 5 chunks
        var chunks: [ObsidianChunk] = []
        for i in 0..<5 {
            chunks.append(ObsidianChunk(
                vaultId: vaultId,
                noteId: UUID(),
                notePath: "note\(i).md",
                noteTitle: "Note \(i)",
                content: "Content \(i)",
                chunkIndex: 0,
                embedding: [Float](repeating: Float(0.5 + Double(i) * 0.1), count: 1536)
            ))
        }

        try store.save(chunks: chunks, for: vaultId)

        let results = try store.search(
            query: queryEmbedding,
            vaultIds: [vaultId],
            limit: 2,
            minSimilarity: 0.0
        )

        #expect(results.count == 2, "Should respect limit of 2")

        // Clean up
        try store.delete(vaultId: vaultId)
    }

    @Test("Search filters by vault IDs")
    func testSearchFiltersByVaultIds() throws {
        let store = MacObsidianVectorStore()
        let vault1Id = UUID()
        let vault2Id = UUID()

        let queryEmbedding = [Float](repeating: 1.0, count: 1536)
        let embedding = [Float](repeating: 0.8, count: 1536)

        // Save chunks to different vaults
        let chunk1 = ObsidianChunk(
            vaultId: vault1Id,
            noteId: UUID(),
            notePath: "vault1_note.md",
            noteTitle: "Vault 1 Note",
            content: "Content in vault 1",
            chunkIndex: 0,
            embedding: embedding
        )

        let chunk2 = ObsidianChunk(
            vaultId: vault2Id,
            noteId: UUID(),
            notePath: "vault2_note.md",
            noteTitle: "Vault 2 Note",
            content: "Content in vault 2",
            chunkIndex: 0,
            embedding: embedding
        )

        try store.save(chunks: [chunk1], for: vault1Id)
        try store.save(chunks: [chunk2], for: vault2Id)

        // Search only vault 1
        let results = try store.search(
            query: queryEmbedding,
            vaultIds: [vault1Id],
            limit: 10,
            minSimilarity: 0.0
        )

        #expect(results.count == 1, "Should only search specified vault")
        #expect(results[0].noteTitle == "Vault 1 Note", "Should return vault 1 note")

        // Clean up
        try store.delete(vaultId: vault1Id)
        try store.delete(vaultId: vault2Id)
    }

    // MARK: - Keyword Boosting Tests

    @Test("Search boosts results with query term in title")
    func testKeywordBoostingInTitle() throws {
        let store = MacObsidianVectorStore()
        let vaultId = UUID()

        // Both have same embedding similarity, but one has "welcome" in title
        let embedding = [Float](repeating: 0.5, count: 1536)
        let queryEmbedding = [Float](repeating: 0.5, count: 1536)

        let chunks = [
            ObsidianChunk(
                vaultId: vaultId,
                noteId: UUID(),
                notePath: "other.md",
                noteTitle: "Other Note",
                content: "Some other content",
                chunkIndex: 0,
                embedding: embedding
            ),
            ObsidianChunk(
                vaultId: vaultId,
                noteId: UUID(),
                notePath: "welcome.md",
                noteTitle: "Welcome",
                content: "This is your vault",
                chunkIndex: 0,
                embedding: embedding
            )
        ]

        try store.save(chunks: chunks, for: vaultId)

        // Search with query text "welcome"
        let results = try store.search(
            query: queryEmbedding,
            queryText: "welcome",
            vaultIds: [vaultId],
            limit: 10,
            minSimilarity: 0.0
        )

        #expect(results.count == 2, "Should return both chunks")
        #expect(results[0].noteTitle == "Welcome", "Title match should be ranked first")
        #expect(results[0].similarity > results[1].similarity, "Title match should have higher similarity")

        // Clean up
        try store.delete(vaultId: vaultId)
    }

    @Test("Search boosts results with query term in content")
    func testKeywordBoostingInContent() throws {
        let store = MacObsidianVectorStore()
        let vaultId = UUID()

        let embedding = [Float](repeating: 0.5, count: 1536)
        let queryEmbedding = [Float](repeating: 0.5, count: 1536)

        let chunks = [
            ObsidianChunk(
                vaultId: vaultId,
                noteId: UUID(),
                notePath: "other.md",
                noteTitle: "Other",
                content: "No matching terms here",
                chunkIndex: 0,
                embedding: embedding
            ),
            ObsidianChunk(
                vaultId: vaultId,
                noteId: UUID(),
                notePath: "vault.md",
                noteTitle: "My Note",
                content: "This is about vault management",
                chunkIndex: 0,
                embedding: embedding
            )
        ]

        try store.save(chunks: chunks, for: vaultId)

        // Search with query text "vault"
        let results = try store.search(
            query: queryEmbedding,
            queryText: "vault",
            vaultIds: [vaultId],
            limit: 10,
            minSimilarity: 0.0
        )

        #expect(results.count == 2, "Should return both chunks")
        #expect(results[0].noteTitle == "My Note", "Content match should be ranked first")

        // Clean up
        try store.delete(vaultId: vaultId)
    }

    @Test("Title match boosted higher than content match")
    func testTitleBoostHigherThanContent() throws {
        let store = MacObsidianVectorStore()
        let vaultId = UUID()

        let embedding = [Float](repeating: 0.5, count: 1536)
        let queryEmbedding = [Float](repeating: 0.5, count: 1536)

        let chunks = [
            ObsidianChunk(
                vaultId: vaultId,
                noteId: UUID(),
                notePath: "content.md",
                noteTitle: "Other",
                content: "This content mentions welcome",
                chunkIndex: 0,
                embedding: embedding
            ),
            ObsidianChunk(
                vaultId: vaultId,
                noteId: UUID(),
                notePath: "title.md",
                noteTitle: "Welcome",
                content: "Different content here",
                chunkIndex: 0,
                embedding: embedding
            )
        ]

        try store.save(chunks: chunks, for: vaultId)

        // Search with query text "welcome"
        let results = try store.search(
            query: queryEmbedding,
            queryText: "welcome",
            vaultIds: [vaultId],
            limit: 10,
            minSimilarity: 0.0
        )

        #expect(results.count == 2, "Should return both chunks")
        #expect(results[0].noteTitle == "Welcome", "Title match should rank higher than content match")

        // Clean up
        try store.delete(vaultId: vaultId)
    }

    // MARK: - getAllChunks Tests

    @Test("getAllChunks returns all notes sorted by title")
    func testGetAllChunksSortsByTitle() throws {
        let store = MacObsidianVectorStore()
        let vaultId = UUID()

        let chunks = [
            ObsidianChunk(
                vaultId: vaultId,
                noteId: UUID(),
                notePath: "zebra.md",
                noteTitle: "Zebra",
                content: "Zebra content",
                chunkIndex: 0,
                embedding: [Float](repeating: 0.5, count: 1536)
            ),
            ObsidianChunk(
                vaultId: vaultId,
                noteId: UUID(),
                notePath: "apple.md",
                noteTitle: "Apple",
                content: "Apple content",
                chunkIndex: 0,
                embedding: [Float](repeating: 0.5, count: 1536)
            )
        ]

        try store.save(chunks: chunks, for: vaultId)

        let results = try store.getAllChunks(vaultIds: [vaultId], limit: 10)

        #expect(results.count == 2, "Should return all chunks")
        #expect(results[0].noteTitle == "Apple", "Should be sorted alphabetically")
        #expect(results[1].noteTitle == "Zebra", "Should be sorted alphabetically")

        // Clean up
        try store.delete(vaultId: vaultId)
    }

    // MARK: - Helper Functions

    /// Cosine similarity calculation (mirrors the implementation in MacObsidianVectorStore)
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
