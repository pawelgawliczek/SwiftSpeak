//
//  ObsidianNoteWriter.swift
//  SwiftSpeak
//
//  Service for writing to Obsidian notes (daily notes, specific notes, new notes)
//  Handles file creation, appending, and daily note path resolution
//
//  iOS: Writes to iCloud Drive if vault is there, otherwise creates pending note
//  macOS: Writes directly to vault path
//

import Foundation
import SwiftSpeakCore

// MARK: - Note Writer Errors

enum ObsidianNoteWriterError: Error, LocalizedError, Equatable {
    case vaultNotFound(UUID)
    case invalidPath(String)
    case fileWriteFailed(String)
    case dailyNoteTemplateInvalid(String)
    case iCloudNotAvailable
    case pendingNoteCreated  // Not an error, just indicates pending

    var errorDescription: String? {
        switch self {
        case .vaultNotFound(let id):
            return "Vault not found: \(id)"
        case .invalidPath(let path):
            return "Invalid file path: \(path)"
        case .fileWriteFailed(let message):
            return "Failed to write file: \(message)"
        case .dailyNoteTemplateInvalid(let template):
            return "Invalid daily note template: \(template)"
        case .iCloudNotAvailable:
            return "iCloud is not available"
        case .pendingNoteCreated:
            return "Note will be added when Mac app runs"
        }
    }
}

// MARK: - Write Result

/// Result of a write operation
enum ObsidianWriteResult: Sendable {
    case writtenDirectly(path: String)
    case pendingForMac(noteId: UUID)
    case failed(Error)

    var isSuccess: Bool {
        switch self {
        case .writtenDirectly, .pendingForMac: return true
        case .failed: return false
        }
    }

    var message: String {
        switch self {
        case .writtenDirectly(let path):
            return "Saved to \(path)"
        case .pendingForMac:
            return "Will be added when Mac syncs"
        case .failed(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Obsidian Note Writer

/// Service for creating and appending to Obsidian notes
actor ObsidianNoteWriter {

    #if os(iOS)
    /// iCloud Drive root for direct vault access
    private var iCloudDriveRoot: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .deletingLastPathComponent()
            .appendingPathComponent("com~apple~CloudDocs", isDirectory: true)
    }

    /// SwiftSpeak's iCloud container for pending notes
    private var pendingNotesDirectory: URL? {
        guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
        let dir = container.appendingPathComponent("Documents/Pending", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    #endif

    // MARK: - Dependencies

    private let fileManager = FileManager.default

    // MARK: - Public API

    // MARK: - Cross-Platform Write (iOS: iCloud/Pending, Mac: Direct)

    /// Write content to vault - handles iOS iCloud Drive and pending notes
    /// - Returns: Result indicating how the write was handled
    func write(
        content: String,
        to vault: ObsidianVault,
        action: NoteAction,
        noteName: String? = nil
    ) async -> ObsidianWriteResult {
        let targetPath = resolveTargetPath(vault: vault, action: action, noteName: noteName)

        #if os(iOS)
        // iOS: Try iCloud Drive first, fall back to pending
        if vault.isCloudVault, let iCloudPath = vault.iCloudDrivePath {
            do {
                try await writeToiCloudDrive(
                    content: content,
                    vaultPath: iCloudPath,
                    targetPath: targetPath,
                    action: action
                )
                return .writtenDirectly(path: targetPath)
            } catch {
                appLog("iCloud Drive write failed: \(error)", category: "Obsidian", level: .warning)
            }
        }

        // Create pending note for Mac to process
        do {
            let noteId = try await createPendingNote(
                content: content,
                vaultId: vault.id,
                targetPath: targetPath,
                action: action
            )
            return .pendingForMac(noteId: noteId)
        } catch {
            return .failed(error)
        }
        #else
        // macOS: Write directly
        do {
            switch action {
            case .appendToDaily:
                try await appendToDaily(content: content, vault: vault)
            case .append:
                try await appendToNote(content: content, notePath: targetPath, vault: vault, createIfNeeded: true)
            case .create:
                let name = noteName ?? "SwiftSpeak Note"
                _ = try await createNote(title: name, content: content, vault: vault)
            }
            return .writtenDirectly(path: targetPath)
        } catch {
            return .failed(error)
        }
        #endif
    }

    #if os(iOS)
    /// Write directly to iCloud Drive vault
    private func writeToiCloudDrive(
        content: String,
        vaultPath: String,
        targetPath: String,
        action: NoteAction
    ) async throws {
        guard let iCloudRoot = iCloudDriveRoot else {
            throw ObsidianNoteWriterError.iCloudNotAvailable
        }

        let noteURL = iCloudRoot
            .appendingPathComponent(vaultPath, isDirectory: true)
            .appendingPathComponent(targetPath)

        // Create parent directory if needed
        let parentDir = noteURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)

        let formattedContent = formatAppendedContent(content)

        if fileManager.fileExists(atPath: noteURL.path) {
            // Append to existing
            let existing = try String(contentsOf: noteURL, encoding: .utf8)
            let newContent = existing + formattedContent
            try newContent.write(to: noteURL, atomically: true, encoding: .utf8)
        } else {
            // Create new (with title for create action)
            if action == .create {
                let title = (targetPath as NSString).deletingPathExtension.components(separatedBy: "/").last ?? "Note"
                let fullContent = "# \(title)\n\n\(content)"
                try fullContent.write(to: noteURL, atomically: true, encoding: .utf8)
            } else {
                try content.write(to: noteURL, atomically: true, encoding: .utf8)
            }
        }

        appLog("Wrote to iCloud Drive: \(targetPath)", category: "Obsidian")
    }

    /// Create pending note for Mac to process
    private func createPendingNote(
        content: String,
        vaultId: UUID,
        targetPath: String,
        action: NoteAction
    ) async throws -> UUID {
        guard let pendingDir = pendingNotesDirectory else {
            throw ObsidianNoteWriterError.iCloudNotAvailable
        }

        let pendingNote = PendingObsidianNote(
            vaultId: vaultId,
            action: action,
            targetPath: targetPath,
            content: content
        )

        let noteFile = pendingDir.appendingPathComponent("\(pendingNote.id.uuidString).json")
        let data = try JSONEncoder().encode(pendingNote)
        try data.write(to: noteFile)

        appLog("Created pending note: \(pendingNote.id)", category: "Obsidian")
        return pendingNote.id
    }
    #endif

    /// Resolve target path based on action
    private func resolveTargetPath(vault: ObsidianVault, action: NoteAction, noteName: String?) -> String {
        switch action {
        case .appendToDaily:
            return dailyNotePath(for: vault)
        case .create, .append:
            let name = noteName ?? "SwiftSpeak Note"
            let folder = vault.newNotesFolder.isEmpty ? "" : vault.newNotesFolder + "/"
            return "\(folder)\(name).md"
        }
    }

    /// Format content for appending with timestamp
    private func formatAppendedContent(_ content: String) -> String {
        let timestamp = formatTimestamp(Date())
        return """

        ---
        *Added via SwiftSpeak at \(timestamp)*

        \(content)
        """
    }

    /// Append content to today's daily note
    /// - Parameters:
    ///   - content: The content to append
    ///   - vault: The vault containing the daily note
    /// - Throws: ObsidianNoteWriterError if operation fails
    func appendToDaily(
        content: String,
        vault: ObsidianVault
    ) async throws {
        guard let localPath = vault.localPath else {
            throw ObsidianNoteWriterError.vaultNotFound(vault.id)
        }

        let dailyPath = dailyNotePath(for: vault)

        appLog("Appending to daily note: \(dailyPath)", category: "Obsidian")

        try await appendToNote(
            content: content,
            notePath: dailyPath,
            vault: vault,
            createIfNeeded: true
        )
    }

    /// Append content to a specific note
    /// - Parameters:
    ///   - content: The content to append
    ///   - notePath: Relative path to the note (e.g., "Notes/MyNote.md")
    ///   - vault: The vault containing the note
    ///   - createIfNeeded: Whether to create the note if it doesn't exist (default: false)
    /// - Throws: ObsidianNoteWriterError if operation fails
    func appendToNote(
        content: String,
        notePath: String,
        vault: ObsidianVault,
        createIfNeeded: Bool = false
    ) async throws {
        guard let localPath = vault.localPath else {
            throw ObsidianNoteWriterError.vaultNotFound(vault.id)
        }

        let fullPath = (localPath as NSString).appendingPathComponent(notePath)
        let fileURL = URL(fileURLWithPath: fullPath)

        // Create directories if needed
        let directoryURL = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        // Format the appended content
        let timestamp = formatTimestamp(Date())
        let formattedContent = """

        ---
        *Added via SwiftSpeak at \(timestamp)*

        \(content)
        """

        // Read existing content or create new file
        var existingContent = ""
        if fileManager.fileExists(atPath: fileURL.path) {
            existingContent = try String(contentsOf: fileURL, encoding: .utf8)
        } else if createIfNeeded {
            // Create file with title header
            let title = (notePath as NSString).deletingPathExtension.components(separatedBy: "/").last ?? "Untitled"
            existingContent = "# \(title)\n"
        } else {
            throw ObsidianNoteWriterError.invalidPath(notePath)
        }

        // Append and write
        let newContent = existingContent + formattedContent

        do {
            try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
            appLog("Appended \(content.count) characters to \(notePath)", category: "Obsidian")
        } catch {
            throw ObsidianNoteWriterError.fileWriteFailed(error.localizedDescription)
        }
    }

    /// Create a new note with the given title and content
    /// - Parameters:
    ///   - title: The note title
    ///   - content: The note content
    ///   - vault: The vault to create the note in
    /// - Returns: The relative path to the created note
    /// - Throws: ObsidianNoteWriterError if operation fails
    func createNote(
        title: String,
        content: String,
        vault: ObsidianVault
    ) async throws -> String {
        guard let localPath = vault.localPath else {
            throw ObsidianNoteWriterError.vaultNotFound(vault.id)
        }

        // Sanitize filename
        let fileName = sanitizeFileName(title) + ".md"

        // Determine folder
        let folder = vault.newNotesFolder.isEmpty ? "" : vault.newNotesFolder + "/"
        let relativePath = folder + fileName

        // Full path
        let fullPath = (localPath as NSString).appendingPathComponent(relativePath)
        let fileURL = URL(fileURLWithPath: fullPath)

        // Create directory if needed
        let directoryURL = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        // Format note content
        let timestamp = formatTimestamp(Date())
        let fullContent = """
        # \(title)

        \(content)

        ---
        *Created via SwiftSpeak at \(timestamp)*
        """

        // Write file
        do {
            try fullContent.write(to: fileURL, atomically: true, encoding: .utf8)
            appLog("Created note: \(relativePath) (\(fullContent.count) characters)", category: "Obsidian")
            return relativePath
        } catch {
            throw ObsidianNoteWriterError.fileWriteFailed(error.localizedDescription)
        }
    }

    /// Get the daily note path for a given date
    /// - Parameters:
    ///   - vault: The vault
    ///   - date: The date (default: today)
    /// - Returns: The relative path to the daily note (e.g., "Daily Notes/2024-01-04.md")
    func dailyNotePath(for vault: ObsidianVault, date: Date = Date()) -> String {
        var path = vault.dailyNotePath

        // Replace date placeholders
        let formatter = DateFormatter()

        // YYYY
        formatter.dateFormat = "yyyy"
        path = path.replacingOccurrences(of: "YYYY", with: formatter.string(from: date))
        path = path.replacingOccurrences(of: "{YYYY}", with: formatter.string(from: date))

        // MM
        formatter.dateFormat = "MM"
        path = path.replacingOccurrences(of: "MM", with: formatter.string(from: date))
        path = path.replacingOccurrences(of: "{MM}", with: formatter.string(from: date))

        // DD
        formatter.dateFormat = "dd"
        path = path.replacingOccurrences(of: "DD", with: formatter.string(from: date))
        path = path.replacingOccurrences(of: "{DD}", with: formatter.string(from: date))

        // {date} replacement (YYYY-MM-DD format)
        if path.contains("{date}") {
            formatter.dateFormat = "yyyy-MM-dd"
            path = path.replacingOccurrences(of: "{date}", with: formatter.string(from: date))
        }

        return path
    }

    // MARK: - Private Helpers

    /// Sanitize filename by removing invalid characters
    private func sanitizeFileName(_ name: String) -> String {
        // Remove invalid filename characters
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let sanitized = name.components(separatedBy: invalidChars).joined(separator: "-")

        // Trim whitespace
        let trimmed = sanitized.trimmingCharacters(in: .whitespaces)

        // Limit length
        let maxLength = 200
        if trimmed.count > maxLength {
            return String(trimmed.prefix(maxLength))
        }

        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    /// Format timestamp for note footer
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
