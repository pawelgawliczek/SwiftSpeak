//
//  ObsidianVectorStoreTests.swift
//  SwiftSpeakTests
//
//  Tests for ObsidianVectorStore SQLite database
//

import Testing
import Foundation
@testable import SwiftSpeak
import SwiftSpeakCore

// Use typealias to disambiguate
private typealias Vault = SwiftSpeakCore.ObsidianVault
private typealias NoteMetadata = SwiftSpeakCore.ObsidianNoteMetadata

@MainActor
struct ObsidianVectorStoreTests {

    // MARK: - Database Lifecycle Tests

    @Test func databaseOpensAndCloses() throws {
        let store = ObsidianVectorStore()

        #expect(store.isOpen == false)

        try store.open()
        #expect(store.isOpen == true)

        store.close()
        #expect(store.isOpen == false)
    }

    @Test func canOpenDatabaseMultipleTimes() throws {
        let store = ObsidianVectorStore()

        try store.open()
        try store.open() // Should not throw

        #expect(store.isOpen == true)

        store.close()
    }

    // MARK: - Vault Storage Tests

    @Test func storesAndRetrievesVaults() throws {
        let store = ObsidianVectorStore()
        try store.open()
        defer { store.close() }

        let vault = Vault(
            name: "Test Vault",
            iCloudPath: "vaults/Test/",
            noteCount: 10,
            chunkCount: 50
        )

        try store.storeVault(vault, embeddingModel: .openAISmall)

        let vaultIds = try store.getAllVaults()
        #expect(vaultIds.contains(vault.id))
    }

    @Test func deletesVaultAndAllData() throws {
        let store = ObsidianVectorStore()
        try store.open()
        defer { store.close() }

        let vault = Vault(
            name: "Test Vault",
            iCloudPath: "vaults/Test/"
        )

        // Store vault
        try store.storeVault(vault, embeddingModel: .openAISmall)

        // Add note
        let note = NoteMetadata(
            relativePath: "test.md",
            title: "Test",
            contentHash: "abc",
            lastModified: Date(),
            chunkCount: 1,
            chunkStartIndex: 0
        )
        try store.storeNote(note, vaultId: vault.id)

        // Delete vault
        try store.deleteVault(vault.id)

        // Should be gone
        let vaultIds = try store.getAllVaults()
        #expect(!vaultIds.contains(vault.id))
    }

    // MARK: - Note Storage Tests

    @Test func storesNotesInBatch() throws {
        let store = ObsidianVectorStore()
        try store.open()
        defer { store.close() }

        let vault = Vault(name: "Test", iCloudPath: "vaults/Test/")
        try store.storeVault(vault, embeddingModel: .openAISmall)

        let notes = [
            NoteMetadata(
                relativePath: "note1.md",
                title: "Note 1",
                contentHash: "abc",
                lastModified: Date(),
                chunkCount: 2,
                chunkStartIndex: 0
            ),
            NoteMetadata(
                relativePath: "note2.md",
                title: "Note 2",
                contentHash: "def",
                lastModified: Date(),
                chunkCount: 3,
                chunkStartIndex: 2
            )
        ]

        try store.storeNotes(notes, vaultId: vault.id)

        // Verify by getting chunk count
        let chunkCount = try store.getChunkCount(forVault: vault.id)
        #expect(chunkCount == 0) // No chunks stored yet, just notes
    }

    // MARK: - Chunk Storage Tests

    @Test func storesChunksWithEmbeddings() throws {
        let store = ObsidianVectorStore()
        try store.open()
        defer { store.close() }

        let vault = Vault(name: "Test", iCloudPath: "vaults/Test/")
        try store.storeVault(vault, embeddingModel: .openAISmall)

        let note = NoteMetadata(
            relativePath: "test.md",
            title: "Test",
            contentHash: "abc",
            lastModified: Date(),
            chunkCount: 2,
            chunkStartIndex: 0
        )
        try store.storeNote(note, vaultId: vault.id)

        // Create chunks with embeddings
        let chunks = [
            DocumentChunk(
                documentId: note.id,
                index: 0,
                content: "First chunk",
                startOffset: 0,
                endOffset: 11,
                embedding: Array(repeating: 0.5, count: 1536)
            ),
            DocumentChunk(
                documentId: note.id,
                index: 1,
                content: "Second chunk",
                startOffset: 12,
                endOffset: 24,
                embedding: Array(repeating: 0.3, count: 1536)
            )
        ]

        try store.storeChunks(chunks, vaultId: vault.id, noteId: note.id)

        let chunkCount = try store.getChunkCount(forVault: vault.id)
        #expect(chunkCount == 2)
    }

    // MARK: - Similarity Search Tests

    @Test func searchFindsRelevantChunks() throws {
        let store = ObsidianVectorStore()
        try store.open()
        defer { store.close() }

        let vault = Vault(name: "Test", iCloudPath: "vaults/Test/")
        try store.storeVault(vault, embeddingModel: .openAISmall)

        let note = NoteMetadata(
            relativePath: "test.md",
            title: "Test Note",
            contentHash: "abc",
            lastModified: Date(),
            chunkCount: 2,
            chunkStartIndex: 0
        )
        try store.storeNote(note, vaultId: vault.id)

        // Create chunks with different embeddings
        let queryEmbedding = Array(repeating: Float(1.0), count: 1536)
        let similarEmbedding = Array(repeating: Float(0.9), count: 1536)
        let differentEmbedding = Array(repeating: Float(0.1), count: 1536)

        let chunks = [
            DocumentChunk(
                documentId: note.id,
                index: 0,
                content: "Very similar content",
                startOffset: 0,
                endOffset: 20,
                embedding: similarEmbedding
            ),
            DocumentChunk(
                documentId: note.id,
                index: 1,
                content: "Very different content",
                startOffset: 21,
                endOffset: 43,
                embedding: differentEmbedding
            )
        ]

        try store.storeChunks(chunks, vaultId: vault.id, noteId: note.id)

        // Search with query embedding
        let results = try store.search(
            queryEmbedding: queryEmbedding,
            limit: 2,
            minSimilarity: 0.0
        )

        #expect(results.count == 2)
        // First result should be more similar
        #expect(results[0].score > results[1].score)
        #expect(results[0].chunk.content == "Very similar content")
    }

    @Test func searchFiltersbyVault() throws {
        let store = ObsidianVectorStore()
        try store.open()
        defer { store.close() }

        // Create two vaults
        let vault1 = Vault(name: "Vault 1", iCloudPath: "vaults/Vault1/")
        let vault2 = Vault(name: "Vault 2", iCloudPath: "vaults/Vault2/")

        try store.storeVault(vault1, embeddingModel: .openAISmall)
        try store.storeVault(vault2, embeddingModel: .openAISmall)

        // Add notes to both vaults
        for vault in [vault1, vault2] {
            let note = NoteMetadata(
                relativePath: "test.md",
                title: "Test",
                contentHash: "abc",
                lastModified: Date(),
                chunkCount: 1,
                chunkStartIndex: 0
            )
            try store.storeNote(note, vaultId: vault.id)

            let chunk = DocumentChunk(
                documentId: note.id,
                index: 0,
                content: "Content in \(vault.name)",
                startOffset: 0,
                endOffset: 20,
                embedding: Array(repeating: 0.5, count: 1536)
            )
            try store.storeChunks([chunk], vaultId: vault.id, noteId: note.id)
        }

        let queryEmbedding = Array(repeating: Float(0.5), count: 1536)

        // Search only vault1
        let results = try store.search(
            queryEmbedding: queryEmbedding,
            vaultIds: [vault1.id],
            limit: 10
        )

        #expect(results.count == 1)
        #expect(results[0].vaultName == "Vault 1")
    }

    @Test func searchRespectsMinSimilarity() throws {
        let store = ObsidianVectorStore()
        try store.open()
        defer { store.close() }

        let vault = Vault(name: "Test", iCloudPath: "vaults/Test/")
        try store.storeVault(vault, embeddingModel: .openAISmall)

        let note = NoteMetadata(
            relativePath: "test.md",
            title: "Test",
            contentHash: "abc",
            lastModified: Date(),
            chunkCount: 1,
            chunkStartIndex: 0
        )
        try store.storeNote(note, vaultId: vault.id)

        // Create chunk with low similarity
        let chunk = DocumentChunk(
            documentId: note.id,
            index: 0,
            content: "Test content",
            startOffset: 0,
            endOffset: 12,
            embedding: Array(repeating: 0.1, count: 1536) // Very different from query
        )
        try store.storeChunks([chunk], vaultId: vault.id, noteId: note.id)

        let queryEmbedding = Array(repeating: Float(1.0), count: 1536)

        // Search with high minimum similarity
        let results = try store.search(
            queryEmbedding: queryEmbedding,
            limit: 10,
            minSimilarity: 0.8 // Should filter out the low-similarity chunk
        )

        #expect(results.isEmpty)
    }

    // MARK: - Clear Data Tests

    @Test func clearAllRemovesAllData() throws {
        let store = ObsidianVectorStore()
        try store.open()
        defer { store.close() }

        // Add vault and data
        let vault = Vault(name: "Test", iCloudPath: "vaults/Test/")
        try store.storeVault(vault, embeddingModel: .openAISmall)

        let note = NoteMetadata(
            relativePath: "test.md",
            title: "Test",
            contentHash: "abc",
            lastModified: Date(),
            chunkCount: 1,
            chunkStartIndex: 0
        )
        try store.storeNote(note, vaultId: vault.id)

        // Clear all
        try store.clearAll()

        // Verify empty
        let vaultIds = try store.getAllVaults()
        #expect(vaultIds.isEmpty)

        let chunkCount = try store.getChunkCount(forVault: vault.id)
        #expect(chunkCount == 0)
    }

    // MARK: - Error Handling Tests

    @Test func throwsWhenDatabaseNotOpen() {
        let store = ObsidianVectorStore()

        #expect(throws: ObsidianVectorStoreError.self) {
            _ = try store.getAllVaults()
        }
    }

    @Test func throwsOnEmbeddingDimensionMismatch() throws {
        let store = ObsidianVectorStore(embeddingModel: .openAISmall) // 1536 dimensions
        try store.open()
        defer { store.close() }

        let wrongSizeEmbedding = Array(repeating: Float(0.5), count: 100) // Wrong size

        #expect(throws: ObsidianVectorStoreError.self) {
            _ = try store.search(queryEmbedding: wrongSizeEmbedding)
        }
    }
}
