//
//  Knowledge.swift
//  SwiftSpeak
//
//  Knowledge base document models for RAG
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

// MARK: - Knowledge Document (Phase 4 RAG)

/// Document types for the knowledge base
enum KnowledgeDocumentType: String, Codable {
    case localFile = "local"      // PDF, TXT, MD uploaded
    case remoteURL = "remote"     // Web page fetched

    // File format types (used by DocumentParser)
    case pdf = "pdf"
    case text = "text"
    case markdown = "markdown"
}

/// Auto-update interval for remote documents
enum UpdateInterval: String, Codable, CaseIterable {
    case never = "never"
    case daily = "daily"
    case weekly = "weekly"
    case always = "always"        // Check before each query

    var displayName: String {
        switch self {
        case .never: return "Never"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .always: return "Always"
        }
    }
}

/// A document in the knowledge base for RAG
struct KnowledgeDocument: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var type: KnowledgeDocumentType
    var sourceURL: URL?           // For remote documents
    var localPath: String?        // For uploaded files
    var contentHash: String       // For update detection
    var chunkCount: Int
    var fileSizeBytes: Int
    var isIndexed: Bool
    var lastUpdated: Date
    var autoUpdateInterval: UpdateInterval?
    var lastChecked: Date?

    init(
        id: UUID = UUID(),
        name: String,
        type: KnowledgeDocumentType,
        sourceURL: URL? = nil,
        localPath: String? = nil,
        contentHash: String = "",
        chunkCount: Int = 0,
        fileSizeBytes: Int = 0,
        isIndexed: Bool = false,
        lastUpdated: Date = Date(),
        autoUpdateInterval: UpdateInterval? = nil,
        lastChecked: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.sourceURL = sourceURL
        self.localPath = localPath
        self.contentHash = contentHash
        self.chunkCount = chunkCount
        self.fileSizeBytes = fileSizeBytes
        self.isIndexed = isIndexed
        self.lastUpdated = lastUpdated
        self.autoUpdateInterval = autoUpdateInterval
        self.lastChecked = lastChecked
    }

    var fileSizeFormatted: String {
        let bytes = Double(fileSizeBytes)
        if bytes < 1024 {
            return "\(fileSizeBytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        }
    }

    /// Sample documents for previews
    static var samples: [KnowledgeDocument] {
        [
            KnowledgeDocument(
                name: "API Documentation.pdf",
                type: .localFile,
                localPath: "/documents/api_docs.pdf",
                chunkCount: 156,
                fileSizeBytes: 2_400_000,
                isIndexed: true,
                lastUpdated: Date().addingTimeInterval(-86400)
            ),
            KnowledgeDocument(
                name: "Project Wiki",
                type: .remoteURL,
                sourceURL: URL(string: "https://wiki.example.com/project"),
                chunkCount: 89,
                fileSizeBytes: 450_000,
                isIndexed: true,
                lastUpdated: Date().addingTimeInterval(-172800),
                autoUpdateInterval: .weekly,
                lastChecked: Date().addingTimeInterval(-172800)
            ),
            KnowledgeDocument(
                name: "Style Guide.md",
                type: .localFile,
                localPath: "/documents/style_guide.md",
                chunkCount: 12,
                fileSizeBytes: 45_000,
                isIndexed: true,
                lastUpdated: Date().addingTimeInterval(-604800)
            )
        ]
    }
}
