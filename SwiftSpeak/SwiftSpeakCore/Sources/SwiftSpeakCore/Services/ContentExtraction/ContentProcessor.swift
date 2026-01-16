//
//  ContentProcessor.swift
//  SwiftSpeakCore
//
//  Unified content processing entry point
//  Handles all content types: text, images, URLs, PDFs
//  Shared between iOS and macOS
//

import Foundation
import CoreGraphics

// MARK: - Content Processing Error

public enum ContentProcessingError: Error, LocalizedError {
    case unsupportedType(SharedContentType)
    case noContent
    case extractionFailed(String)
    case fileAccessFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedType(let type):
            return "Unsupported content type: \(type.displayName)"
        case .noContent:
            return "No content available to process"
        case .extractionFailed(let message):
            return "Content extraction failed: \(message)"
        case .fileAccessFailed(let message):
            return "File access failed: \(message)"
        }
    }
}

// MARK: - Content Processing Result

/// Result of content processing
public struct ContentProcessingResult: Sendable {
    public let text: String
    public let title: String?
    public let wordCount: Int
    public let processingDuration: TimeInterval
    public let sourceType: SharedContentType

    public init(
        text: String,
        title: String? = nil,
        processingDuration: TimeInterval = 0,
        sourceType: SharedContentType
    ) {
        self.text = text
        self.title = title
        self.wordCount = text.split(separator: " ").count
        self.processingDuration = processingDuration
        self.sourceType = sourceType
    }
}

// MARK: - Content Processor

/// Unified content processing entry point
/// Handles extraction/conversion of all supported content types to text
public final class ContentProcessor: Sendable {

    private let ocrLanguages: [ImageOCRService.RecognitionLanguage]

    public init(ocrLanguages: [ImageOCRService.RecognitionLanguage] = [.english]) {
        self.ocrLanguages = ocrLanguages
    }

    // MARK: - Main Processing Method

    /// Process shared content and extract text
    /// - Parameter content: The shared content to process
    /// - Returns: Processing result with extracted text
    /// - Note: Audio content returns empty result - handle transcription separately
    public func processToText(_ content: SharedContent) async throws -> ContentProcessingResult {
        let startTime = Date()

        let (text, title): (String, String?)

        switch content.type {
        case .audio:
            // Audio requires transcription - handled separately
            // Return existing text content if already transcribed
            if let existingText = content.textContent, !existingText.isEmpty {
                return ContentProcessingResult(
                    text: existingText,
                    title: content.extractedTitle,
                    processingDuration: Date().timeIntervalSince(startTime),
                    sourceType: content.type
                )
            }
            // Return empty - caller should use transcription service
            return ContentProcessingResult(
                text: "",
                title: nil,
                processingDuration: 0,
                sourceType: .audio
            )

        case .text:
            // Direct pass-through for text content
            guard let textContent = content.textContent, !textContent.isEmpty else {
                throw ContentProcessingError.noContent
            }
            text = textContent
            title = content.extractedTitle

        case .image:
            // OCR extraction from image
            (text, title) = try await processImage(content)

        case .url:
            // Web content fetching
            (text, title) = try await processURL(content)

        case .pdf:
            // PDF text extraction
            (text, title) = try await processPDF(content)
        }

        let duration = Date().timeIntervalSince(startTime)

        return ContentProcessingResult(
            text: text,
            title: title ?? content.extractedTitle,
            processingDuration: duration,
            sourceType: content.type
        )
    }

    /// Process content and update the SharedContent object with extracted text
    /// - Parameter content: The shared content to process (mutated in place)
    /// - Returns: Processing result
    public func processAndUpdate(_ content: inout SharedContent) async throws -> ContentProcessingResult {
        let result = try await processToText(content)

        content.textContent = result.text
        content.extractedTitle = result.title
        content.extractionDuration = result.processingDuration
        content.wordCount = result.wordCount

        return result
    }

    // MARK: - Type-Specific Processing

    private func processImage(_ content: SharedContent) async throws -> (String, String?) {
        let ocrService = ImageOCRService(languages: ocrLanguages)

        // Try image data first
        if let imageData = content.imageData {
            let text = try await ocrService.extractText(from: imageData)
            return (text, nil)
        }

        // Try file reference
        if let fileId = content.fileId {
            let url = fileURL(for: fileId, type: .image)
            let text = try await ocrService.extractText(from: url)
            return (text, nil)
        }

        throw ContentProcessingError.noContent
    }

    private func processURL(_ content: SharedContent) async throws -> (String, String?) {
        guard let sourceURL = content.sourceURL else {
            // Check if URL was stored as text content
            if let urlString = content.textContent,
               let url = URL(string: urlString) {
                let fetcher = URLContentFetcher()
                return try await fetcher.fetchContent(from: url)
            }
            throw ContentProcessingError.noContent
        }

        let fetcher = URLContentFetcher()
        return try await fetcher.fetchContent(from: sourceURL)
    }

    private func processPDF(_ content: SharedContent) async throws -> (String, String?) {
        let extractor = PDFTextExtractor()

        // Try file reference
        if let fileId = content.fileId {
            let url = fileURL(for: fileId, type: .pdf)
            let text = try extractor.extractText(from: url)
            let metadata = extractor.metadata(from: url)
            return (text, metadata?.title)
        }

        throw ContentProcessingError.noContent
    }

    // MARK: - File Helpers

    private func fileURL(for fileId: String, type: SharedContentType) -> URL {
        // Get App Group container URL
        let containerURL: URL
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.pawelgawliczek.swiftspeak"
        ) {
            containerURL = groupURL
        } else {
            // Fallback to documents directory
            containerURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        }

        let sharedDir = containerURL.appendingPathComponent(ShareContentConstants.sharedContentDirectory)
        return sharedDir.appendingPathComponent(fileId)
    }
}

// MARK: - Static Convenience Methods

public extension ContentProcessor {
    /// Static convenience method to process content
    static func processToText(_ content: SharedContent) async throws -> ContentProcessingResult {
        try await ContentProcessor().processToText(content)
    }

    /// Quick check if content type requires external processing (transcription)
    static func requiresExternalProcessing(_ type: SharedContentType) -> Bool {
        type == .audio
    }

    /// Get estimated processing time for content type
    static func estimatedProcessingTime(for type: SharedContentType) -> TimeInterval {
        switch type {
        case .audio: return 0  // Depends on transcription service
        case .text: return 0.1
        case .image: return 2.0  // OCR takes time
        case .url: return 3.0  // Network request
        case .pdf: return 1.0  // Local processing
        }
    }
}

// MARK: - Batch Processing

public extension ContentProcessor {
    /// Process multiple content items in parallel
    /// - Parameter contents: Array of shared content to process
    /// - Returns: Array of processing results (maintains order)
    func processMultiple(_ contents: [SharedContent]) async throws -> [ContentProcessingResult] {
        try await withThrowingTaskGroup(of: (Int, ContentProcessingResult).self) { group in
            for (index, content) in contents.enumerated() {
                group.addTask {
                    let result = try await self.processToText(content)
                    return (index, result)
                }
            }

            var results = [(Int, ContentProcessingResult)]()
            for try await result in group {
                results.append(result)
            }

            // Sort by original index
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
}
