//
//  SharedContent.swift
//  SwiftSpeakCore
//
//  Unified model for content shared from other apps via Share Extension
//  Supports: Audio, Text, Images (OCR), URLs, PDFs
//

import Foundation

// MARK: - Shared Content Type

/// Types of content that can be shared to SwiftSpeak for processing
public enum SharedContentType: String, Codable, CaseIterable, Sendable {
    case audio  // Audio files for transcription
    case text   // Plain text, rich text
    case image  // Images for OCR extraction
    case url    // URLs for web content fetching
    case pdf    // PDF documents for text extraction

    /// SF Symbol icon for this content type
    public var icon: String {
        switch self {
        case .audio: return "waveform"
        case .text: return "doc.text.fill"
        case .image: return "photo.fill"
        case .url: return "link"
        case .pdf: return "doc.richtext.fill"
        }
    }

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .audio: return "Audio"
        case .text: return "Text"
        case .image: return "Image"
        case .url: return "Web Link"
        case .pdf: return "PDF"
        }
    }

    /// Description of how this content type is processed
    public var processingDescription: String {
        switch self {
        case .audio: return "Transcribe audio to text"
        case .text: return "Process text directly"
        case .image: return "Extract text via OCR"
        case .url: return "Fetch and extract web content"
        case .pdf: return "Extract text from PDF"
        }
    }

    /// Whether this content type requires file storage (vs inline text)
    public var requiresFileStorage: Bool {
        switch self {
        case .audio, .image, .pdf: return true
        case .text, .url: return false
        }
    }
}

// MARK: - Shared Content

/// Represents content shared from another app for Power Mode processing
public struct SharedContent: Codable, Identifiable, Sendable {
    public let id: UUID
    public let type: SharedContentType
    public let originalFilename: String?
    public let timestamp: Date
    public let sourceApp: String?

    // Content storage - one of these will be populated based on type
    public var textContent: String?       // For text type, or extracted text from other types
    public var fileId: String?            // Reference to file in app group (audio, image, pdf)
    public var sourceURL: URL?            // Original URL for url type
    public var imageData: Data?           // Image data for OCR (when not using file)

    // Extraction metadata
    public var extractedTitle: String?
    public var extractionDuration: TimeInterval?
    public var pageCount: Int?            // For PDFs
    public var wordCount: Int?            // Estimated word count

    public init(
        id: UUID = UUID(),
        type: SharedContentType,
        originalFilename: String? = nil,
        timestamp: Date = Date(),
        sourceApp: String? = nil,
        textContent: String? = nil,
        fileId: String? = nil,
        sourceURL: URL? = nil,
        imageData: Data? = nil,
        extractedTitle: String? = nil,
        extractionDuration: TimeInterval? = nil,
        pageCount: Int? = nil,
        wordCount: Int? = nil
    ) {
        self.id = id
        self.type = type
        self.originalFilename = originalFilename
        self.timestamp = timestamp
        self.sourceApp = sourceApp
        self.textContent = textContent
        self.fileId = fileId
        self.sourceURL = sourceURL
        self.imageData = imageData
        self.extractedTitle = extractedTitle
        self.extractionDuration = extractionDuration
        self.pageCount = pageCount
        self.wordCount = wordCount
    }

    /// Whether this content has been processed/extracted
    public var isProcessed: Bool {
        textContent != nil && !textContent!.isEmpty
    }

    /// Display name for the content (filename or URL host or type)
    public var displayName: String {
        if let filename = originalFilename {
            return filename
        }
        if let url = sourceURL {
            return url.host ?? url.absoluteString
        }
        return type.displayName
    }

    /// Preview text (first ~200 chars of content)
    public var previewText: String? {
        guard let text = textContent, !text.isEmpty else { return nil }
        if text.count <= 200 {
            return text
        }
        return String(text.prefix(200)) + "..."
    }
}

// MARK: - Share Content Constants

/// Constants for multi-content sharing
public enum ShareContentConstants {
    /// Directory for shared files in App Group container
    public static let sharedContentDirectory = "shared_content"

    /// UserDefaults key for pending share content ID
    public static let pendingShareKey = "pendingShareContentId"

    /// UserDefaults key for share content type
    public static let contentTypeKey = "shareContentType"

    /// UserDefaults key for original filename
    public static let originalFilenameKey = "shareOriginalFilename"

    /// UserDefaults key for share timestamp
    public static let timestampKey = "shareTimestamp"

    /// UserDefaults key for source URL (for url type)
    public static let sourceURLKey = "shareSourceURL"

    /// UserDefaults key for text content (for small inline text)
    public static let textContentKey = "shareTextContent"
}
