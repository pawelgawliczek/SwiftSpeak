//
//  PDFTextExtractor.swift
//  SwiftSpeakCore
//
//  Extracts text content from PDF documents using PDFKit
//  Shared between iOS and macOS
//

import Foundation
#if canImport(PDFKit)
import PDFKit
#endif

// MARK: - PDF Extraction Error

public enum PDFExtractionError: Error, LocalizedError {
    case fileNotFound
    case invalidPDF
    case noTextContent
    case extractionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "PDF file not found"
        case .invalidPDF:
            return "Invalid or corrupted PDF file"
        case .noTextContent:
            return "PDF contains no extractable text"
        case .extractionFailed(let message):
            return "PDF extraction failed: \(message)"
        }
    }
}

// MARK: - PDF Text Extractor

/// Extracts text content from PDF documents
/// Works on both iOS and macOS via PDFKit
public final class PDFTextExtractor: Sendable {

    public init() {}

    // MARK: - Public Methods

    /// Extract text from a PDF file at the given URL
    /// - Parameter url: File URL to the PDF
    /// - Returns: Extracted text content
    public func extractText(from url: URL) throws -> String {
        #if canImport(PDFKit)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PDFExtractionError.fileNotFound
        }

        guard let document = PDFDocument(url: url) else {
            throw PDFExtractionError.invalidPDF
        }

        return try extractText(from: document)
        #else
        throw PDFExtractionError.extractionFailed("PDFKit not available")
        #endif
    }

    /// Extract text from PDF data
    /// - Parameter data: Raw PDF data
    /// - Returns: Extracted text content
    public func extractText(from data: Data) throws -> String {
        #if canImport(PDFKit)
        guard let document = PDFDocument(data: data) else {
            throw PDFExtractionError.invalidPDF
        }

        return try extractText(from: document)
        #else
        throw PDFExtractionError.extractionFailed("PDFKit not available")
        #endif
    }

    /// Get page count from a PDF
    /// - Parameter url: File URL to the PDF
    /// - Returns: Number of pages
    public func pageCount(from url: URL) -> Int? {
        #if canImport(PDFKit)
        guard let document = PDFDocument(url: url) else { return nil }
        return document.pageCount
        #else
        return nil
        #endif
    }

    /// Get PDF metadata
    /// - Parameter url: File URL to the PDF
    /// - Returns: Tuple of (title, author, pageCount)
    public func metadata(from url: URL) -> (title: String?, author: String?, pageCount: Int)? {
        #if canImport(PDFKit)
        guard let document = PDFDocument(url: url) else { return nil }

        let title = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String
        let author = document.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String

        return (title, author, document.pageCount)
        #else
        return nil
        #endif
    }

    // MARK: - Private Methods

    #if canImport(PDFKit)
    private func extractText(from document: PDFDocument) throws -> String {
        var allText = ""

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }

            if let pageText = page.string {
                if !allText.isEmpty {
                    allText += "\n\n"
                }
                allText += pageText
            }
        }

        // Clean up the extracted text
        let cleanedText = cleanExtractedText(allText)

        if cleanedText.isEmpty {
            throw PDFExtractionError.noTextContent
        }

        return cleanedText
    }
    #endif

    private func cleanExtractedText(_ text: String) -> String {
        // Remove excessive whitespace
        var cleaned = text

        // Replace multiple newlines with double newline
        let multipleNewlines = try? NSRegularExpression(pattern: "\n{3,}", options: [])
        cleaned = multipleNewlines?.stringByReplacingMatches(
            in: cleaned,
            options: [],
            range: NSRange(cleaned.startIndex..., in: cleaned),
            withTemplate: "\n\n"
        ) ?? cleaned

        // Replace multiple spaces with single space
        let multipleSpaces = try? NSRegularExpression(pattern: " {2,}", options: [])
        cleaned = multipleSpaces?.stringByReplacingMatches(
            in: cleaned,
            options: [],
            range: NSRange(cleaned.startIndex..., in: cleaned),
            withTemplate: " "
        ) ?? cleaned

        // Trim whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }
}

// MARK: - Static Convenience Methods

public extension PDFTextExtractor {
    /// Static convenience method to extract text from URL
    static func extractText(from url: URL) throws -> String {
        try PDFTextExtractor().extractText(from: url)
    }

    /// Static convenience method to extract text from data
    static func extractText(from data: Data) throws -> String {
        try PDFTextExtractor().extractText(from: data)
    }
}
