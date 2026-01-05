//
//  ObsidianSyncServiceTests.swift
//  SwiftSpeakTests
//
//  Tests for Obsidian sync service (binary serialization, manifest encoding, etc.)
//

import Testing
import Foundation
@testable import SwiftSpeak
import SwiftSpeakCore

// Use typealias to disambiguate
private typealias VaultManifest = SwiftSpeakCore.ObsidianVaultManifest
private typealias NoteMetadata = SwiftSpeakCore.ObsidianNoteMetadata

struct ObsidianSyncServiceTests {

    // MARK: - Binary Embedding Serialization Tests

    @Test("Binary embedding serialization - single chunk")
    func testSerializeSingleEmbedding() async throws {
        let service = ObsidianSyncService()

        // Create test embedding (1536 dimensions for text-embedding-3-small)
        let testId = UUID()
        let testEmbedding = (0..<1536).map { _ in Float.random(in: -1...1) }
        let chunks = [(testId, testEmbedding)]

        // Serialize
        let data = try await service.serializeEmbeddings(chunks)

        // Verify header (4 bytes for count)
        #expect(data.count >= 4)
        let count = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        #expect(count == 1)

        // Verify total size: 4 (header) + 16 (UUID) + (1536 * 4) (embedding)
        let expectedSize = 4 + 16 + (1536 * 4)
        #expect(data.count == expectedSize)
    }

    @Test("Binary embedding deserialization - single chunk")
    func testDeserializeSingleEmbedding() async throws {
        let service = ObsidianSyncService()

        // Create test data
        let testId = UUID()
        let testEmbedding = (0..<1536).map { Float($0) / 1536.0 }
        let chunks = [(testId, testEmbedding)]

        // Serialize then deserialize
        let data = try await service.serializeEmbeddings(chunks)
        let deserialized = try await service.deserializeEmbeddings(data)

        // Verify
        #expect(deserialized.count == 1)
        #expect(deserialized[0].0 == testId)
        #expect(deserialized[0].1.count == 1536)

        // Check values (with small tolerance for float precision)
        for i in 0..<1536 {
            let expected = testEmbedding[i]
            let actual = deserialized[0].1[i]
            #expect(abs(expected - actual) < 0.0001)
        }
    }

    @Test("Binary embedding round-trip - multiple chunks")
    func testEmbeddingRoundTrip() async throws {
        let service = ObsidianSyncService()

        // Create multiple test embeddings
        let chunks = (0..<10).map { i in
            let id = UUID()
            let embedding = (0..<1536).map { Float($0 + i * 1536) / 15360.0 }
            return (id, embedding)
        }

        // Round-trip
        let data = try await service.serializeEmbeddings(chunks)
        let deserialized = try await service.deserializeEmbeddings(data)

        // Verify count
        #expect(deserialized.count == 10)

        // Verify each chunk
        for i in 0..<10 {
            #expect(deserialized[i].0 == chunks[i].0)
            #expect(deserialized[i].1.count == 1536)

            // Check a few sample values
            for j in [0, 500, 1000, 1535] {
                let expected = chunks[i].1[j]
                let actual = deserialized[i].1[j]
                #expect(abs(expected - actual) < 0.0001)
            }
        }
    }

    // MARK: - Chunks Index Serialization Tests

    @Test("Chunks index serialization")
    func testSerializeChunksIndex() async throws {
        let service = ObsidianSyncService()

        let chunks = [
            (
                id: UUID(),
                noteId: UUID(),
                content: "Test chunk 1",
                startOffset: 0,
                endOffset: 13
            ),
            (
                id: UUID(),
                noteId: UUID(),
                content: "Test chunk 2",
                startOffset: 13,
                endOffset: 26
            )
        ]

        let data = try await service.serializeChunksIndex(chunks)

        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json != nil)

        // Verify structure
        let chunksArray = json?["chunks"] as? [[String: Any]]
        #expect(chunksArray?.count == 2)

        // Verify first chunk
        let firstChunk = chunksArray?[0]
        #expect(firstChunk?["id"] as? String == chunks[0].id.uuidString)
        #expect(firstChunk?["content"] as? String == "Test chunk 1")
        #expect(firstChunk?["startOffset"] as? Int == 0)
        #expect(firstChunk?["endOffset"] as? Int == 13)
    }

    @Test("Chunks index deserialization")
    func testDeserializeChunksIndex() async throws {
        let service = ObsidianSyncService()

        let chunks = [
            (
                id: UUID(),
                noteId: UUID(),
                content: "Test chunk 1",
                startOffset: 0,
                endOffset: 13
            ),
            (
                id: UUID(),
                noteId: UUID(),
                content: "Test chunk 2",
                startOffset: 13,
                endOffset: 26
            )
        ]

        // Round-trip
        let data = try await service.serializeChunksIndex(chunks)
        let deserialized = try await service.deserializeChunksIndex(data)

        // Verify
        #expect(deserialized.count == 2)
        #expect(deserialized[0].id == chunks[0].id)
        #expect(deserialized[0].content == chunks[0].content)
        #expect(deserialized[0].startOffset == chunks[0].startOffset)
        #expect(deserialized[0].endOffset == chunks[0].endOffset)
    }

    // MARK: - Manifest Encoding Tests

    @Test("Manifest encoding and decoding")
    func testManifestCoding() throws {
        let manifest = VaultManifest(
            vaultId: UUID(),
            indexedAt: Date(),
            embeddingModel: "text-embedding-3-small",
            noteCount: 234,
            chunkCount: 1567,
            embeddingBatchCount: 2,
            notes: [
                NoteMetadata(
                    relativePath: "Notes/test.md",
                    title: "Test Note",
                    contentHash: "abc123",
                    lastModified: Date(),
                    chunkCount: 10,
                    chunkStartIndex: 0
                )
            ]
        )

        // Encode
        let data = try JSONEncoder().encode(manifest)

        // Decode
        let decoded = try JSONDecoder().decode(VaultManifest.self, from: data)

        // Verify
        #expect(decoded.vaultId == manifest.vaultId)
        #expect(decoded.embeddingModel == manifest.embeddingModel)
        #expect(decoded.noteCount == manifest.noteCount)
        #expect(decoded.chunkCount == manifest.chunkCount)
        #expect(decoded.embeddingBatchCount == manifest.embeddingBatchCount)
        #expect(decoded.notes.count == 1)
        #expect(decoded.notes[0].title == "Test Note")
    }

    // MARK: - Error Cases

    @Test("Deserialization fails with invalid data")
    func testDeserializationError() async throws {
        let service = ObsidianSyncService()

        // Create invalid data (too short)
        let invalidData = Data([0x01, 0x00])

        // Should throw
        await #expect(throws: ObsidianSyncError.self) {
            try await service.deserializeEmbeddings(invalidData)
        }
    }

    @Test("Deserialization fails with incomplete chunk data")
    func testIncompleteChunkError() async throws {
        let service = ObsidianSyncService()

        // Create data with header but incomplete chunk
        var data = Data()
        let count = UInt32(1)
        withUnsafeBytes(of: count) { bytes in
            data.append(contentsOf: bytes)
        }

        // Add partial UUID (only 8 bytes instead of 16)
        data.append(Data(count: 8))

        // Should throw
        await #expect(throws: ObsidianSyncError.self) {
            try await service.deserializeEmbeddings(data)
        }
    }

    // MARK: - Batch Size Tests

    @Test("Large batch serialization")
    func testLargeBatchSerialization() async throws {
        let service = ObsidianSyncService()

        // Create 10,000 chunks (typical batch size)
        let chunks = (0..<10_000).map { _ in
            (UUID(), (0..<1536).map { _ in Float.random(in: -1...1) })
        }

        // Serialize
        let data = try await service.serializeEmbeddings(chunks)

        // Verify size
        let expectedSize = 4 + (10_000 * (16 + 1536 * 4))
        #expect(data.count == expectedSize)

        // Deserialize and verify count
        let deserialized = try await service.deserializeEmbeddings(data)
        #expect(deserialized.count == 10_000)
    }
}

// MARK: - Helper Extensions

extension ObsidianSyncService {
    // Expose private methods for testing
    fileprivate func serializeEmbeddings(_ chunks: [(UUID, [Float])]) async throws -> Data {
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

    fileprivate func deserializeEmbeddings(_ data: Data) async throws -> [(UUID, [Float])] {
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
        let dimensions = 1536
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

    fileprivate func serializeChunksIndex(_ chunks: [(id: UUID, noteId: UUID, content: String, startOffset: Int, endOffset: Int)]) async throws -> Data {
        struct ChunksIndex: Codable {
            let chunks: [ChunkIndexItem]
        }

        struct ChunkIndexItem: Codable {
            let id: String
            let noteId: String
            let content: String
            let startOffset: Int
            let endOffset: Int
        }

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

    fileprivate func deserializeChunksIndex(_ data: Data) async throws -> [(id: UUID, noteId: UUID, content: String, startOffset: Int, endOffset: Int)] {
        struct ChunksIndex: Codable {
            let chunks: [ChunkIndexItem]
        }

        struct ChunkIndexItem: Codable {
            let id: String
            let noteId: String
            let content: String
            let startOffset: Int
            let endOffset: Int
        }

        let index = try JSONDecoder().decode(ChunksIndex.self, from: data)

        return index.chunks.compactMap { item in
            guard let id = UUID(uuidString: item.id),
                  let noteId = UUID(uuidString: item.noteId) else {
                return nil
            }
            return (id, noteId, item.content, item.startOffset, item.endOffset)
        }
    }
}
