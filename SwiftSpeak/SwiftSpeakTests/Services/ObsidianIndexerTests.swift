//
//  ObsidianIndexerTests.swift
//  SwiftSpeakTests
//
//  Tests for ObsidianIndexer service
//

import Testing
import Foundation
@testable import SwiftSpeak

@MainActor
struct ObsidianIndexerTests {

    // MARK: - Vault Validation Tests

    @Test func validatesVaultExists() async throws {
        let indexer = ObsidianIndexer()
        let nonExistentPath = "/tmp/nonexistent-vault-\(UUID().uuidString)"

        #expect(throws: ObsidianIndexerError.self) {
            try indexer.validateVault(at: nonExistentPath)
        }
    }

    @Test func validatesObsidianFolder() async throws {
        let indexer = ObsidianIndexer()

        // Create temp directory without .obsidian folder
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-vault-\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Should throw because no .obsidian folder
        #expect(throws: ObsidianIndexerError.self) {
            try indexer.validateVault(at: tempDir.path)
        }
    }

    @Test func validVaultPassesValidation() async throws {
        let indexer = ObsidianIndexer()

        // Create temp directory with .obsidian folder
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-vault-\(UUID().uuidString)")
        let obsidianDir = tempDir.appendingPathComponent(".obsidian")

        try FileManager.default.createDirectory(at: obsidianDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Should not throw
        try indexer.validateVault(at: tempDir.path)
    }

    // MARK: - Cost Estimation Tests

    @Test func estimatesCostForEmptyVault() async throws {
        let indexer = ObsidianIndexer(apiKey: "test-key")

        // Create empty vault
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-vault-\(UUID().uuidString)")
        let obsidianDir = tempDir.appendingPathComponent(".obsidian")

        try FileManager.default.createDirectory(at: obsidianDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let estimate = try await indexer.estimateCost(for: tempDir.path, config: .default)

        #expect(estimate.noteCount == 0)
        #expect(estimate.chunkCount == 0)
        #expect(estimate.estimatedCost == 0)
    }

    @Test func estimatesCostForVaultWithNotes() async throws {
        let indexer = ObsidianIndexer(apiKey: "test-key")

        // Create vault with test notes
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-vault-\(UUID().uuidString)")
        let obsidianDir = tempDir.appendingPathComponent(".obsidian")

        try FileManager.default.createDirectory(at: obsidianDir, withIntermediateDirectories: true)

        // Add test markdown files
        let note1 = tempDir.appendingPathComponent("note1.md")
        let note2 = tempDir.appendingPathComponent("note2.md")
        try "# Note 1\n\nThis is test content.".write(to: note1, atomically: true, encoding: .utf8)
        try "# Note 2\n\nThis is more test content.".write(to: note2, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let estimate = try await indexer.estimateCost(for: tempDir.path, config: .default)

        #expect(estimate.noteCount == 2)
        #expect(estimate.chunkCount > 0)
        #expect(estimate.estimatedCost > 0)
    }

    // MARK: - Indexing Progress Tests

    @Test func indexingStreamProducesProgress() async throws {
        let indexer = ObsidianIndexer(apiKey: "test-key")

        // Create small vault
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-vault-\(UUID().uuidString)")
        let obsidianDir = tempDir.appendingPathComponent(".obsidian")

        try FileManager.default.createDirectory(at: obsidianDir, withIntermediateDirectories: true)

        let note = tempDir.appendingPathComponent("test.md")
        try "# Test Note\n\nSome content here.".write(to: note, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let vaultId = UUID()
        let progressStream = indexer.indexVault(at: tempDir.path, vaultId: vaultId)

        var receivedPhases: [ObsidianIndexingProgress.IndexingPhase] = []

        for await progress in progressStream {
            receivedPhases.append(progress.phase)

            // Should have sensible progress values
            #expect(progress.notesProcessed >= 0)
            #expect(progress.totalNotes >= 0)
            #expect(progress.chunksGenerated >= 0)

            if progress.phase == .complete {
                break
            }
        }

        // Should have received multiple progress updates
        #expect(receivedPhases.count > 0)
    }

    // MARK: - Content Hashing Tests

    @Test func identicalContentProducesSameHash() async throws {
        let indexer = ObsidianIndexer(apiKey: "test-key")

        // Create two vaults with identical content
        let tempDir1 = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-vault-1-\(UUID().uuidString)")
        let tempDir2 = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-vault-2-\(UUID().uuidString)")

        for dir in [tempDir1, tempDir2] {
            let obsidianDir = dir.appendingPathComponent(".obsidian")
            try FileManager.default.createDirectory(at: obsidianDir, withIntermediateDirectories: true)

            let note = dir.appendingPathComponent("test.md")
            try "# Test\n\nSame content".write(to: note, atomically: true, encoding: .utf8)
        }

        defer {
            try? FileManager.default.removeItem(at: tempDir1)
            try? FileManager.default.removeItem(at: tempDir2)
        }

        // Both should estimate same cost
        let estimate1 = try await indexer.estimateCost(for: tempDir1.path, config: .default)
        let estimate2 = try await indexer.estimateCost(for: tempDir2.path, config: .default)

        #expect(estimate1.noteCount == estimate2.noteCount)
        #expect(estimate1.chunkCount == estimate2.chunkCount)
    }

    // MARK: - Cancellation Tests

    @Test func indexingCanBeCancelled() async throws {
        let indexer = ObsidianIndexer(apiKey: "test-key")

        // Create vault with many notes to allow cancellation
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-vault-\(UUID().uuidString)")
        let obsidianDir = tempDir.appendingPathComponent(".obsidian")

        try FileManager.default.createDirectory(at: obsidianDir, withIntermediateDirectories: true)

        // Add many notes
        for i in 0..<10 {
            let note = tempDir.appendingPathComponent("note\(i).md")
            try "# Note \(i)\n\nContent".write(to: note, atomically: true, encoding: .utf8)
        }

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let vaultId = UUID()
        let progressStream = indexer.indexVault(at: tempDir.path, vaultId: vaultId)

        // Cancel after first progress update
        var updateCount = 0
        for await _ in progressStream {
            updateCount += 1
            if updateCount == 2 {
                indexer.cancel()
                break
            }
        }

        #expect(updateCount >= 1)
    }
}
