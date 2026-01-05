//
//  ObsidianNote.swift
//  SwiftSpeakCore
//
//  Models for creating and managing Obsidian notes
//

import Foundation

// MARK: - Pending Note

/// A note waiting to be written to a vault (used when iOS can't write directly)
public struct PendingObsidianNote: Codable, Identifiable, Sendable {
    public let id: UUID
    public let vaultId: UUID
    public let action: NoteAction
    public let targetPath: String          // Relative path in vault (e.g., "Daily Notes/2025-01-05.md")
    public let content: String
    public let createdAt: Date
    public var processedAt: Date?

    public init(
        id: UUID = UUID(),
        vaultId: UUID,
        action: NoteAction,
        targetPath: String,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.vaultId = vaultId
        self.action = action
        self.targetPath = targetPath
        self.content = content
        self.createdAt = createdAt
    }
}

// MARK: - Note Action

public enum NoteAction: String, Codable, CaseIterable, Sendable {
    case create          // Create new note (fail if exists)
    case append          // Append to existing note (create if not exists)
    case appendToDaily   // Append to daily note (uses vault.dailyNotePath)

    public var displayName: String {
        switch self {
        case .create: return "Create New Note"
        case .append: return "Append to Note"
        case .appendToDaily: return "Add to Daily Note"
        }
    }

    public var icon: String {
        switch self {
        case .create: return "doc.badge.plus"
        case .append: return "doc.text.below.ecg"
        case .appendToDaily: return "calendar.badge.plus"
        }
    }
}

// MARK: - Note Template

/// Format for appended content
public struct NoteAppendFormat {
    /// Separator before new content
    public static func separator(timestamp: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\n\n---\n*Added via SwiftSpeak at \(formatter.string(from: timestamp))*\n\n"
    }

    /// Format content for appending
    public static func format(content: String, timestamp: Date = Date()) -> String {
        return separator(timestamp: timestamp) + content
    }
}
