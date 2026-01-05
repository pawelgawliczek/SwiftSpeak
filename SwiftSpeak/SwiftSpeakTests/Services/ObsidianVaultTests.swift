//
//  ObsidianVaultTests.swift
//  SwiftSpeakTests
//
//  Tests for ObsidianVault models
//

import Testing
import Foundation
@testable import SwiftSpeak
import SwiftSpeakCore

// Use typealias to disambiguate
private typealias Vault = SwiftSpeakCore.ObsidianVault
private typealias VaultStatus = SwiftSpeakCore.ObsidianVaultStatus
private typealias VaultManifest = SwiftSpeakCore.ObsidianVaultManifest
private typealias NoteMetadata = SwiftSpeakCore.ObsidianNoteMetadata

struct ObsidianVaultTests {

    // MARK: - ObsidianVault Model Tests

    @Test func vaultHasRequiredProperties() {
        let vault = Vault(
            name: "Test Vault",
            localPath: "/Users/test/vault",
            iCloudPath: "vaults/TestVault/"
        )

        #expect(vault.name == "Test Vault")
        #expect(vault.localPath == "/Users/test/vault")
        #expect(vault.iCloudPath == "vaults/TestVault/")
        #expect(vault.noteCount == 0)
        #expect(vault.chunkCount == 0)
        #expect(vault.status == .notConfigured)
    }

    @Test func vaultEncodesAndDecodes() throws {
        let vault = Vault(
            name: "Test Vault",
            localPath: "/Users/test/vault",
            iCloudPath: "vaults/TestVault/",
            lastIndexed: Date(),
            noteCount: 10,
            chunkCount: 50,
            status: .synced,
            autoRefreshEnabled: true,
            dailyNotePath: "Daily/{date}.md",
            newNotesFolder: "Inbox"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(vault)
        let decoded = try decoder.decode(Vault.self, from: data)

        #expect(decoded.id == vault.id)
        #expect(decoded.name == vault.name)
        #expect(decoded.localPath == vault.localPath)
        #expect(decoded.noteCount == vault.noteCount)
        #expect(decoded.status == vault.status)
    }

    @Test func vaultNeedsRefreshAfter24Hours() {
        var vault = Vault(
            name: "Test Vault",
            iCloudPath: "vaults/Test/"
        )

        // New vault needs refresh
        #expect(vault.needsRefresh == true)

        // Just indexed - doesn't need refresh
        vault.lastIndexed = Date()
        #expect(vault.needsRefresh == false)

        // 25 hours ago - needs refresh
        vault.lastIndexed = Date().addingTimeInterval(-90000) // 25 hours
        #expect(vault.needsRefresh == true)
    }

    @Test func vaultStatusDisplays() {
        for status in VaultStatus.allCases {
            #expect(!status.icon.isEmpty)
            #expect(!status.color.isEmpty)
        }
    }

    @Test func dailyNotePathSubstitution() {
        let vault = Vault(
            name: "Test",
            iCloudPath: "vaults/Test/",
            dailyNotePath: "Daily Notes/{date}.md"
        )

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        let path = vault.dailyNotePath()
        #expect(path.contains(today))
        #expect(path.hasPrefix("Daily Notes/"))
        #expect(path.hasSuffix(".md"))
    }

    // MARK: - ObsidianVaultManifest Tests

    @Test func manifestEncodesAndDecodes() throws {
        let noteMetadata = NoteMetadata(
            relativePath: "notes/test.md",
            title: "Test Note",
            contentHash: "abc123",
            lastModified: Date(),
            chunkCount: 5,
            chunkStartIndex: 0
        )

        let manifest = VaultManifest(
            vaultId: UUID(),
            embeddingModel: "text-embedding-3-small",
            noteCount: 1,
            chunkCount: 5,
            embeddingBatchCount: 1,
            notes: [noteMetadata]
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(manifest)
        let decoded = try decoder.decode(VaultManifest.self, from: data)

        #expect(decoded.version == manifest.version)
        #expect(decoded.vaultId == manifest.vaultId)
        #expect(decoded.noteCount == manifest.noteCount)
        #expect(decoded.notes.count == 1)
        #expect(decoded.notes[0].title == "Test Note")
    }

    // MARK: - ObsidianNoteMetadata Tests

    @Test func noteMetadataExtractsFilename() {
        let note = NoteMetadata(
            relativePath: "folder/subfolder/test.md",
            title: "Test",
            contentHash: "abc",
            lastModified: Date(),
            chunkCount: 1,
            chunkStartIndex: 0
        )

        #expect(note.filename == "test.md")
    }

    @Test func noteMetadataExtractsFolder() {
        let note = NoteMetadata(
            relativePath: "folder/subfolder/test.md",
            title: "Test",
            contentHash: "abc",
            lastModified: Date(),
            chunkCount: 1,
            chunkStartIndex: 0
        )

        #expect(note.folder == "folder/subfolder")
    }

    @Test func noteMetadataRootFileHasNoFolder() {
        let note = NoteMetadata(
            relativePath: "test.md",
            title: "Test",
            contentHash: "abc",
            lastModified: Date(),
            chunkCount: 1,
            chunkStartIndex: 0
        )

        #expect(note.folder == nil)
    }

    @Test func noteMetadataEncodesAndDecodes() throws {
        let note = NoteMetadata(
            relativePath: "notes/test.md",
            title: "Test Note",
            contentHash: "abc123",
            lastModified: Date(),
            chunkCount: 5,
            chunkStartIndex: 10
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(note)
        let decoded = try decoder.decode(NoteMetadata.self, from: data)

        #expect(decoded.id == note.id)
        #expect(decoded.relativePath == note.relativePath)
        #expect(decoded.title == note.title)
        #expect(decoded.contentHash == note.contentHash)
        #expect(decoded.chunkCount == note.chunkCount)
    }

    // MARK: - Chunking Settings Tests

    @Test func vaultHasDefaultChunkSettings() {
        let vault = Vault(
            name: "Test Vault",
            iCloudPath: "vaults/Test/"
        )

        #expect(vault.chunkSize == Vault.defaultChunkSize)
        #expect(vault.chunkOverlap == Vault.defaultChunkOverlap)
        #expect(vault.similarityThreshold == Vault.defaultSimilarityThreshold)
    }

    @Test func vaultDefaultChunkSizeIs500() {
        #expect(Vault.defaultChunkSize == 500)
    }

    @Test func vaultDefaultChunkOverlapIs50() {
        #expect(Vault.defaultChunkOverlap == 50)
    }

    @Test func vaultDefaultSimilarityThresholdIs0Point7() {
        #expect(Vault.defaultSimilarityThreshold == 0.7)
    }

    @Test func vaultAcceptsCustomChunkSettings() {
        let vault = Vault(
            name: "Custom Vault",
            iCloudPath: "vaults/Custom/",
            chunkSize: 300,
            chunkOverlap: 100,
            similarityThreshold: 0.85
        )

        #expect(vault.chunkSize == 300)
        #expect(vault.chunkOverlap == 100)
        #expect(vault.similarityThreshold == 0.85)
    }

    @Test func vaultChunkSettingsEncodeAndDecode() throws {
        let vault = Vault(
            name: "Test Vault",
            iCloudPath: "vaults/Test/",
            chunkSize: 750,
            chunkOverlap: 75,
            similarityThreshold: 0.6
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(vault)
        let decoded = try decoder.decode(Vault.self, from: data)

        #expect(decoded.chunkSize == 750)
        #expect(decoded.chunkOverlap == 75)
        #expect(decoded.similarityThreshold == 0.6)
    }

    @Test func sampleVaultsHaveChunkSettings() {
        let samples = Vault.samples

        for vault in samples {
            #expect(vault.chunkSize >= 200)
            #expect(vault.chunkSize <= 1000)
            #expect(vault.chunkOverlap >= 0)
            #expect(vault.chunkOverlap <= 200)
            #expect(vault.similarityThreshold >= 0.5)
            #expect(vault.similarityThreshold <= 0.95)
        }
    }
}
