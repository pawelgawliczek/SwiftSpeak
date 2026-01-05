//
//  ObsidianVault.swift
//  SwiftSpeak
//
//  Obsidian vault models for cross-device knowledge base
//
//  SHARED: This file is used by SwiftSpeak (macOS), SwiftSpeak (iOS), and SwiftSpeakKeyboard targets
//

import Foundation

// MARK: - Obsidian Vault

/// Represents an Obsidian vault that can be indexed and synced across devices
public struct ObsidianVault: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var localPath: String?              // Mac only - local folder path
    public var iCloudPath: String              // Relative path for iCloud sync (e.g., "vaults/MyVault/")
    public var iCloudDrivePath: String?        // If vault is in iCloud Drive, iOS can write directly
    public var lastIndexed: Date?
    public var noteCount: Int
    public var chunkCount: Int
    public var status: ObsidianVaultStatus
    public var autoRefreshEnabled: Bool
    public var dailyNotePath: String           // e.g., "Daily Notes/YYYY-MM-DD.md"
    public var newNotesFolder: String          // e.g., "Inbox"

    // MARK: - Chunking Settings
    public var chunkSize: Int                  // Target chunk size in characters (default 500)
    public var chunkOverlap: Int               // Overlap between chunks in characters (default 50)
    public var similarityThreshold: Float      // Minimum similarity score for queries (0.0-1.0, default 0.7)

    /// Whether iOS can write directly to this vault (vault is in iCloud Drive)
    public var isCloudVault: Bool {
        iCloudDrivePath != nil
    }

    public init(
        id: UUID = UUID(),
        name: String,
        localPath: String? = nil,
        iCloudPath: String,
        iCloudDrivePath: String? = nil,
        lastIndexed: Date? = nil,
        noteCount: Int = 0,
        chunkCount: Int = 0,
        status: ObsidianVaultStatus = .notConfigured,
        autoRefreshEnabled: Bool = true,
        dailyNotePath: String = "Daily Notes/{date}.md",
        newNotesFolder: String = "Inbox",
        chunkSize: Int = 500,
        chunkOverlap: Int = 50,
        similarityThreshold: Float = 0.7
    ) {
        self.id = id
        self.name = name
        self.localPath = localPath
        self.iCloudPath = iCloudPath
        self.iCloudDrivePath = iCloudDrivePath
        self.lastIndexed = lastIndexed
        self.noteCount = noteCount
        self.chunkCount = chunkCount
        self.status = status
        self.autoRefreshEnabled = autoRefreshEnabled
        self.dailyNotePath = dailyNotePath
        self.newNotesFolder = newNotesFolder
        self.chunkSize = chunkSize
        self.chunkOverlap = chunkOverlap
        self.similarityThreshold = similarityThreshold
    }

    /// Check if vault needs refresh (based on last indexed time)
    public var needsRefresh: Bool {
        guard let lastIndexed = lastIndexed else { return true }
        let timeSinceIndex = Date().timeIntervalSince(lastIndexed)
        return timeSinceIndex > 86400  // 24 hours
    }

    /// Human-readable status message
    public var statusMessage: String {
        switch status {
        case .notConfigured:
            return "Not configured"
        case .indexing:
            return "Indexing..."
        case .syncing:
            return "Syncing to iCloud..."
        case .synced:
            if let date = lastIndexed {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                return "Synced \(formatter.localizedString(for: date, relativeTo: Date()))"
            }
            return "Synced"
        case .needsRefresh:
            return "Needs refresh"
        case .downloading:
            return "Downloading from iCloud..."
        case .error:
            return "Error"
        }
    }

    /// Get today's daily note path
    public func dailyNotePath(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        return dailyNotePath.replacingOccurrences(of: "{date}", with: dateString)
    }

    /// Default chunk size for new vaults (characters)
    public static let defaultChunkSize = 500

    /// Default chunk overlap for new vaults (characters)
    public static let defaultChunkOverlap = 50

    /// Default similarity threshold for queries (0.0-1.0)
    public static let defaultSimilarityThreshold: Float = 0.7

    /// Sample vaults for previews
    public static var samples: [ObsidianVault] {
        [
            ObsidianVault(
                name: "Personal Vault",
                localPath: "/Users/john/Documents/PersonalVault",
                iCloudPath: "vaults/PersonalVault/",
                lastIndexed: Date().addingTimeInterval(-3600),
                noteCount: 234,
                chunkCount: 1567,
                status: .synced,
                autoRefreshEnabled: true,
                chunkSize: 500,
                chunkOverlap: 50
            ),
            ObsidianVault(
                name: "Work Notes",
                localPath: "/Users/john/Documents/WorkVault",
                iCloudPath: "vaults/WorkVault/",
                lastIndexed: Date().addingTimeInterval(-86400 * 2),
                noteCount: 89,
                chunkCount: 543,
                status: .needsRefresh,
                autoRefreshEnabled: true,
                chunkSize: 300,
                chunkOverlap: 30
            ),
            ObsidianVault(
                name: "Research",
                iCloudPath: "vaults/Research/",
                noteCount: 0,
                chunkCount: 0,
                status: .notConfigured,
                autoRefreshEnabled: false
            )
        ]
    }
}

// MARK: - Obsidian Vault Status

/// Status of an Obsidian vault
public enum ObsidianVaultStatus: String, Codable, CaseIterable, Sendable {
    case notConfigured      // Vault created but not yet indexed
    case indexing           // Currently indexing vault on Mac
    case syncing            // Uploading embeddings to iCloud
    case synced             // Fully synced and ready to use
    case needsRefresh       // Needs re-indexing (vault changed)
    case downloading        // iOS downloading embeddings from iCloud
    case error              // Error occurred during indexing/sync

    public var icon: String {
        switch self {
        case .notConfigured: return "questionmark.circle"
        case .indexing: return "arrow.triangle.2.circlepath"
        case .syncing: return "icloud.and.arrow.up"
        case .synced: return "checkmark.circle.fill"
        case .needsRefresh: return "arrow.clockwise.circle"
        case .downloading: return "icloud.and.arrow.down"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    public var color: String {
        switch self {
        case .notConfigured: return "gray"
        case .indexing: return "blue"
        case .syncing: return "blue"
        case .synced: return "green"
        case .needsRefresh: return "orange"
        case .downloading: return "blue"
        case .error: return "red"
        }
    }
}

// MARK: - Obsidian Vault Manifest

/// Manifest describing indexed vault contents (stored in iCloud alongside embeddings)
public struct ObsidianVaultManifest: Codable, Sendable {
    public let version: Int                     // Manifest format version
    public let vaultId: UUID                    // ID of vault this manifest describes
    public let indexedAt: Date                  // When indexing was performed
    public let embeddingModel: String           // Model used for embeddings
    public let noteCount: Int                   // Total notes indexed
    public let chunkCount: Int                  // Total chunks created
    public let embeddingBatchCount: Int         // Number of embedding batch files
    public let notes: [ObsidianNoteMetadata]    // Metadata for each note

    public init(
        version: Int = 1,
        vaultId: UUID,
        indexedAt: Date = Date(),
        embeddingModel: String,
        noteCount: Int,
        chunkCount: Int,
        embeddingBatchCount: Int,
        notes: [ObsidianNoteMetadata]
    ) {
        self.version = version
        self.vaultId = vaultId
        self.indexedAt = indexedAt
        self.embeddingModel = embeddingModel
        self.noteCount = noteCount
        self.chunkCount = chunkCount
        self.embeddingBatchCount = embeddingBatchCount
        self.notes = notes
    }
}

// MARK: - Obsidian Note Metadata

/// Metadata for a single note in the vault
public struct ObsidianNoteMetadata: Codable, Identifiable, Sendable {
    public let id: UUID                         // Note identifier
    public let relativePath: String             // Path relative to vault root
    public let title: String                    // Note title (from # heading or filename)
    public let contentHash: String              // MD5 hash for change detection
    public let lastModified: Date               // File modification date
    public let chunkCount: Int                  // Number of chunks in this note
    public let chunkStartIndex: Int             // Starting index in embedding batches

    public init(
        id: UUID = UUID(),
        relativePath: String,
        title: String,
        contentHash: String,
        lastModified: Date,
        chunkCount: Int,
        chunkStartIndex: Int
    ) {
        self.id = id
        self.relativePath = relativePath
        self.title = title
        self.contentHash = contentHash
        self.lastModified = lastModified
        self.chunkCount = chunkCount
        self.chunkStartIndex = chunkStartIndex
    }

    /// Extract filename from path
    public var filename: String {
        (relativePath as NSString).lastPathComponent
    }

    /// Extract folder from path
    public var folder: String? {
        let folder = (relativePath as NSString).deletingLastPathComponent
        return folder.isEmpty ? nil : folder
    }
}
