//
//  ObsidianNoteWriterTests.swift
//  SwiftSpeakTests
//
//  Tests for ObsidianNoteWriter service
//

import Testing
import Foundation
@testable import SwiftSpeak
import SwiftSpeakCore

// Use typealias to disambiguate
private typealias Vault = SwiftSpeakCore.ObsidianVault

@MainActor
@Suite("ObsidianNoteWriter Tests")
struct ObsidianNoteWriterTests {

    // MARK: - Daily Note Path Tests

    @Test("Daily note path resolution with standard template")
    func testDailyNotePathResolution() async throws {
        let writer = ObsidianNoteWriter()

        let vault = Vault(
            name: "Test Vault",
            localPath: "/tmp/test_vault",
            iCloudPath: "vaults/test/",
            dailyNotePath: "Daily Notes/YYYY-MM-DD.md"
        )

        // Test with specific date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let testDate = dateFormatter.date(from: "2024-01-15")!

        let path = await writer.dailyNotePath(for: vault, date: testDate)

        #expect(path == "Daily Notes/2024-01-15.md")
    }

    @Test("Daily note path with {date} placeholder")
    func testDailyNotePathWithDatePlaceholder() async throws {
        let writer = ObsidianNoteWriter()

        let vault = Vault(
            name: "Test Vault",
            localPath: "/tmp/test_vault",
            iCloudPath: "vaults/test/",
            dailyNotePath: "Journal/{date}.md"
        )

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let testDate = dateFormatter.date(from: "2024-01-15")!

        let path = await writer.dailyNotePath(for: vault, date: testDate)

        #expect(path == "Journal/2024-01-15.md")
    }

    @Test("Daily note path with year folder structure")
    func testDailyNotePathWithYearStructure() async throws {
        let writer = ObsidianNoteWriter()

        let vault = Vault(
            name: "Test Vault",
            localPath: "/tmp/test_vault",
            iCloudPath: "vaults/test/",
            dailyNotePath: "YYYY/MM/DD.md"
        )

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let testDate = dateFormatter.date(from: "2024-01-15")!

        let path = await writer.dailyNotePath(for: vault, date: testDate)

        #expect(path == "2024/01/15.md")
    }

    // MARK: - File Name Sanitization Tests

    @Test("Sanitize filename with invalid characters")
    func testFilenameSanitization() async throws {
        let writer = ObsidianNoteWriter()

        var vault = Vault(
            name: "Test Vault",
            localPath: "/tmp/test_vault",
            iCloudPath: "vaults/test/",
            newNotesFolder: "Notes"
        )

        // Test with invalid characters
        let invalidTitle = "Test: Note / With * Invalid? Characters"

        // Create a temporary directory for testing
        let tempDir = FileManager.default.temporaryDirectory
        let testVaultPath = tempDir.appendingPathComponent("test_vault_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testVaultPath, withIntermediateDirectories: true)

        vault.localPath = testVaultPath.path

        defer {
            try? FileManager.default.removeItem(at: testVaultPath)
        }

        // Create note
        let createdPath = try await writer.createNote(
            title: invalidTitle,
            content: "Test content",
            vault: vault
        )

        // Verify the path doesn't contain invalid characters
        let fileName = (createdPath as NSString).lastPathComponent
        #expect(!fileName.contains(":"))
        #expect(!fileName.contains("/"))
        #expect(!fileName.contains("*"))
        #expect(!fileName.contains("?"))
        #expect(fileName.hasSuffix(".md"))
    }

    @Test("Sanitize very long filename")
    func testLongFilenameTruncation() async throws {
        let writer = ObsidianNoteWriter()

        var vault = Vault(
            name: "Test Vault",
            localPath: "/tmp/test_vault",
            iCloudPath: "vaults/test/",
            newNotesFolder: "Notes"
        )

        // Create a very long title
        let longTitle = String(repeating: "A", count: 300)

        let tempDir = FileManager.default.temporaryDirectory
        let testVaultPath = tempDir.appendingPathComponent("test_vault_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testVaultPath, withIntermediateDirectories: true)

        vault.localPath = testVaultPath.path

        defer {
            try? FileManager.default.removeItem(at: testVaultPath)
        }

        let createdPath = try await writer.createNote(
            title: longTitle,
            content: "Test content",
            vault: vault
        )

        let fileName = (createdPath as NSString).deletingPathExtension.components(separatedBy: "/").last ?? ""
        #expect(fileName.count <= 200)  // Max length
    }

    // MARK: - Note Creation Tests

    @Test("Create note in new notes folder")
    func testCreateNoteInFolder() async throws {
        let writer = ObsidianNoteWriter()

        let tempDir = FileManager.default.temporaryDirectory
        let testVaultPath = tempDir.appendingPathComponent("test_vault_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testVaultPath, withIntermediateDirectories: true)

        let vault = Vault(
            name: "Test Vault",
            localPath: testVaultPath.path,
            iCloudPath: "vaults/test/",
            newNotesFolder: "Inbox"
        )

        defer {
            try? FileManager.default.removeItem(at: testVaultPath)
        }

        let title = "Test Note"
        let content = "This is test content"

        let createdPath = try await writer.createNote(
            title: title,
            content: content,
            vault: vault
        )

        // Verify file was created
        let fullPath = testVaultPath.appendingPathComponent(createdPath)
        #expect(FileManager.default.fileExists(atPath: fullPath.path))

        // Verify content
        let fileContent = try String(contentsOf: fullPath, encoding: .utf8)
        #expect(fileContent.contains("# \(title)"))
        #expect(fileContent.contains(content))
        #expect(fileContent.contains("Created via SwiftSpeak"))
    }

    // MARK: - Error Handling Tests

    @Test("Create note fails with invalid vault")
    func testCreateNoteInvalidVault() async throws {
        let writer = ObsidianNoteWriter()

        // Vault without local path
        let vault = Vault(
            name: "Test Vault",
            localPath: nil,
            iCloudPath: "vaults/test/"
        )

        do {
            _ = try await writer.createNote(
                title: "Test",
                content: "Content",
                vault: vault
            )
            Issue.record("Should have thrown vaultNotFound error")
        } catch let error as ObsidianNoteWriterError {
            #expect(error == .vaultNotFound(vault.id))
        }
    }
}
