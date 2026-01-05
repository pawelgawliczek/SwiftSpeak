//
//  MacObsidianNoteWriter.swift
//  SwiftSpeakMac
//
//  macOS version of Obsidian note writer
//  Writes directly to vault using security-scoped bookmarks
//

import Foundation
import SwiftSpeakCore

// MARK: - Note Writer Errors

enum MacObsidianNoteWriterError: Error, LocalizedError {
    case vaultNotFound(UUID)
    case invalidPath(String)
    case fileWriteFailed(String)
    case noLocalPath

    var errorDescription: String? {
        switch self {
        case .vaultNotFound(let id):
            return "Vault not found: \(id)"
        case .invalidPath(let path):
            return "Invalid file path: \(path)"
        case .fileWriteFailed(let message):
            return "Failed to write file: \(message)"
        case .noLocalPath:
            return "Vault has no local path configured"
        }
    }
}

// MARK: - Write Result

/// Result of a write operation
enum MacObsidianWriteResult: Sendable {
    case writtenDirectly(path: String)
    case failed(Error)

    var isSuccess: Bool {
        switch self {
        case .writtenDirectly: return true
        case .failed: return false
        }
    }

    var message: String {
        switch self {
        case .writtenDirectly(let path):
            return "Saved to \(path)"
        case .failed(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Mac Obsidian Note Writer

/// macOS-specific service for writing to Obsidian vaults
actor MacObsidianNoteWriter {

    private let fileManager = FileManager.default

    // MARK: - Public API

    /// Write content to vault using appropriate action
    /// Note: Caller is responsible for ensuring security-scoped access to the vault folder
    func write(
        content: String,
        to vault: ObsidianVault,
        action: NoteAction,
        noteName: String? = nil
    ) async -> MacObsidianWriteResult {
        guard let localPath = vault.localPath else {
            return .failed(MacObsidianNoteWriterError.noLocalPath)
        }

        do {
            switch action {
            case .appendToDaily:
                try await appendToDaily(content: content, vault: vault)
            case .append:
                let targetPath = resolveTargetPath(vault: vault, action: action, noteName: noteName)
                try await appendToNote(content: content, notePath: targetPath, vault: vault, createIfNeeded: true)
            case .create:
                let name = noteName ?? "SwiftSpeak Note"
                _ = try await createNote(title: name, content: content, vault: vault)
            }

            let targetPath = resolveTargetPath(vault: vault, action: action, noteName: noteName)
            return .writtenDirectly(path: targetPath)
        } catch {
            return .failed(error)
        }
    }

    // MARK: - Private Methods

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

    /// Append content to today's daily note
    func appendToDaily(content: String, vault: ObsidianVault) async throws {
        guard let localPath = vault.localPath else {
            throw MacObsidianNoteWriterError.vaultNotFound(vault.id)
        }

        let dailyPath = dailyNotePath(for: vault)
        macLog("Appending to daily note: \(dailyPath)", category: "Obsidian")

        try await appendToNote(
            content: content,
            notePath: dailyPath,
            vault: vault,
            createIfNeeded: true
        )
    }

    /// Append content to a specific note
    func appendToNote(
        content: String,
        notePath: String,
        vault: ObsidianVault,
        createIfNeeded: Bool = false
    ) async throws {
        guard let localPath = vault.localPath else {
            throw MacObsidianNoteWriterError.vaultNotFound(vault.id)
        }

        let fullPath = (localPath as NSString).appendingPathComponent(notePath)
        let fileURL = URL(fileURLWithPath: fullPath)

        // Create directories if needed
        let directoryURL = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        // Format the appended content
        let formattedContent = formatAppendedContent(content)

        // Read existing content or create new file
        var existingContent = ""
        if fileManager.fileExists(atPath: fileURL.path) {
            existingContent = try String(contentsOf: fileURL, encoding: .utf8)
        } else if createIfNeeded {
            // Create file with title header
            let title = (notePath as NSString).deletingPathExtension.components(separatedBy: "/").last ?? "Untitled"
            existingContent = "# \(title)\n"
        } else {
            throw MacObsidianNoteWriterError.invalidPath(notePath)
        }

        // Append and write
        let newContent = existingContent + formattedContent

        do {
            try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
            macLog("Appended \(content.count) characters to \(notePath)", category: "Obsidian")
        } catch {
            throw MacObsidianNoteWriterError.fileWriteFailed(error.localizedDescription)
        }
    }

    /// Create a new note
    func createNote(
        title: String,
        content: String,
        vault: ObsidianVault
    ) async throws -> String {
        guard let localPath = vault.localPath else {
            throw MacObsidianNoteWriterError.vaultNotFound(vault.id)
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
            macLog("Created note: \(relativePath) (\(fullContent.count) characters)", category: "Obsidian")
            return relativePath
        } catch {
            throw MacObsidianNoteWriterError.fileWriteFailed(error.localizedDescription)
        }
    }

    /// Get the daily note path for a given date
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

    /// Format content for appending with timestamp
    private func formatAppendedContent(_ content: String) -> String {
        let timestamp = formatTimestamp(Date())
        return """

        ---
        *Added via SwiftSpeak at \(timestamp)*

        \(content)
        """
    }

    /// Sanitize filename by removing invalid characters
    private func sanitizeFileName(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let sanitized = name.components(separatedBy: invalidChars).joined(separator: "-")
        let trimmed = sanitized.trimmingCharacters(in: .whitespaces)

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
