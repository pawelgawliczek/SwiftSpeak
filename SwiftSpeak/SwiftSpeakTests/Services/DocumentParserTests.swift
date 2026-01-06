//
//  DocumentParserTests.swift
//  SwiftSpeakTests
//
//  Tests for DocumentParser - PDF, TXT, MD document parsing
//

import Testing
import SwiftSpeakCore
import Foundation
import CoreGraphics
@testable import SwiftSpeak

// MARK: - Error Type Tests

@Suite("DocumentParser - Errors")
struct DocumentParserErrorTests {

    @Test("File not found error has description")
    func fileNotFoundError() {
        let error = DocumentParserError.fileNotFound
        #expect(error.errorDescription?.contains("not found") == true)
    }

    @Test("Unsupported format error includes extension")
    func unsupportedFormatError() {
        let error = DocumentParserError.unsupportedFormat("docx")
        #expect(error.errorDescription?.contains("docx") == true)
    }

    @Test("Parsing failed error includes reason")
    func parsingFailedError() {
        let error = DocumentParserError.parsingFailed("Corrupted file")
        #expect(error.errorDescription?.contains("Corrupted file") == true)
    }

    @Test("Empty content error has description")
    func emptyContentError() {
        let error = DocumentParserError.emptyContent
        #expect(error.errorDescription?.contains("no extractable text") == true)
    }
}

// MARK: - Parsed Document Tests

@Suite("DocumentParser - ParsedDocument")
struct ParsedDocumentTests {

    @Test("Character count returns content length")
    func characterCountReturnsContentLength() {
        let content = "Hello, world!"
        let doc = ParsedDocument(
            content: content,
            metadata: ParsedDocumentMetadata(),
            pages: nil
        )

        #expect(doc.characterCount == 13)
    }

    @Test("Estimated tokens is content length divided by 4")
    func estimatedTokensCalculation() {
        let content = String(repeating: "a", count: 100)
        let doc = ParsedDocument(
            content: content,
            metadata: ParsedDocumentMetadata(),
            pages: nil
        )

        #expect(doc.estimatedTokens == 25)
    }

    @Test("Empty content has zero counts")
    func emptyContentHasZeroCounts() {
        let doc = ParsedDocument(
            content: "",
            metadata: ParsedDocumentMetadata(),
            pages: nil
        )

        #expect(doc.characterCount == 0)
        #expect(doc.estimatedTokens == 0)
    }
}

// MARK: - Parsed Document Metadata Tests

@Suite("DocumentParser - Metadata")
struct ParsedDocumentMetadataTests {

    @Test("Default initialization")
    func defaultInitialization() {
        let metadata = ParsedDocumentMetadata()

        #expect(metadata.title == nil)
        #expect(metadata.author == nil)
        #expect(metadata.subject == nil)
        #expect(metadata.keywords.isEmpty)
        #expect(metadata.creationDate == nil)
        #expect(metadata.modificationDate == nil)
        #expect(metadata.pageCount == nil)
        #expect(metadata.fileType == .text)
    }

    @Test("Full initialization")
    func fullInitialization() {
        let date = Date()
        let metadata = ParsedDocumentMetadata(
            title: "Test Document",
            author: "Test Author",
            subject: "Testing",
            keywords: ["test", "sample"],
            creationDate: date,
            modificationDate: date,
            pageCount: 10,
            fileType: .pdf
        )

        #expect(metadata.title == "Test Document")
        #expect(metadata.author == "Test Author")
        #expect(metadata.subject == "Testing")
        #expect(metadata.keywords == ["test", "sample"])
        #expect(metadata.creationDate == date)
        #expect(metadata.modificationDate == date)
        #expect(metadata.pageCount == 10)
        #expect(metadata.fileType == .pdf)
    }
}

// MARK: - Parsed Page Tests

@Suite("DocumentParser - ParsedPage")
struct ParsedPageTests {

    @Test("Creates page with content")
    func createsPageWithContent() {
        let page = ParsedPage(
            pageNumber: 1,
            content: "Page content here",
            bounds: nil
        )

        #expect(page.pageNumber == 1)
        #expect(page.content == "Page content here")
        #expect(page.bounds == nil)
    }

    @Test("Creates page with bounds")
    func createsPageWithBounds() {
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let page = ParsedPage(
            pageNumber: 2,
            content: "Content",
            bounds: bounds
        )

        #expect(page.pageNumber == 2)
        #expect(page.bounds?.width == 612)
        #expect(page.bounds?.height == 792)
    }
}

// MARK: - File Type Detection Tests

@Suite("DocumentParser - File Type Detection")
struct DocumentParserFileTypeTests {

    @Test("Detects PDF file type")
    @MainActor
    func detectsPDFFileType() async throws {
        let parser = DocumentParser.shared
        let url = URL(fileURLWithPath: "/path/to/document.pdf")

        let type = parser.getFileType(from: url)

        #expect(type == .pdf)
    }

    @Test("Detects markdown file type (.md)")
    @MainActor
    func detectsMarkdownMd() async throws {
        let parser = DocumentParser.shared
        let url = URL(fileURLWithPath: "/path/to/readme.md")

        let type = parser.getFileType(from: url)

        #expect(type == .markdown)
    }

    @Test("Detects markdown file type (.markdown)")
    @MainActor
    func detectsMarkdownFull() async throws {
        let parser = DocumentParser.shared
        let url = URL(fileURLWithPath: "/path/to/file.markdown")

        let type = parser.getFileType(from: url)

        #expect(type == .markdown)
    }

    @Test("Detects text file type")
    @MainActor
    func detectsTextFileType() async throws {
        let parser = DocumentParser.shared
        let url = URL(fileURLWithPath: "/path/to/notes.txt")

        let type = parser.getFileType(from: url)

        #expect(type == .text)
    }

    @Test("Unknown extensions default to text")
    @MainActor
    func unknownExtensionsDefaultToText() async throws {
        let parser = DocumentParser.shared
        let url = URL(fileURLWithPath: "/path/to/document.docx")

        let type = parser.getFileType(from: url)

        #expect(type == .text)
    }

    @Test("Case insensitive extension detection")
    @MainActor
    func caseInsensitiveExtension() async throws {
        let parser = DocumentParser.shared

        let pdfUpper = URL(fileURLWithPath: "/path/to/document.PDF")
        let mdUpper = URL(fileURLWithPath: "/path/to/readme.MD")

        #expect(parser.getFileType(from: pdfUpper) == .pdf)
        #expect(parser.getFileType(from: mdUpper) == .markdown)
    }
}

// MARK: - Text File Parsing Tests

@Suite("DocumentParser - Text Parsing")
struct DocumentParserTextTests {

    @Test("Parses text file content")
    @MainActor
    func parsesTextFileContent() async throws {
        let parser = DocumentParser.shared
        let content = "This is a test document.\nWith multiple lines."
        let tempURL = createTempFile(content: content, extension: "txt")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let parsed = try await parser.parse(fileURL: tempURL)

        #expect(parsed.content.contains("test document"))
        #expect(parsed.metadata.fileType == .text)
    }

    @Test("Parses markdown file content")
    @MainActor
    func parsesMarkdownFileContent() async throws {
        let parser = DocumentParser.shared
        let content = "# My Title\n\nSome paragraph content."
        let tempURL = createTempFile(content: content, extension: "md")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let parsed = try await parser.parse(fileURL: tempURL)

        #expect(parsed.content.contains("My Title"))
        #expect(parsed.metadata.fileType == .markdown)
        #expect(parsed.metadata.title == "My Title")
    }

    @Test("Extracts title from markdown heading")
    @MainActor
    func extractsTitleFromMarkdownHeading() async throws {
        let parser = DocumentParser.shared
        let content = """
        # Getting Started

        This is the introduction.
        """
        let tempURL = createTempFile(content: content, extension: "md")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let parsed = try await parser.parse(fileURL: tempURL)

        #expect(parsed.metadata.title == "Getting Started")
    }

    @Test("Throws for file not found")
    @MainActor
    func throwsForFileNotFound() async throws {
        let parser = DocumentParser.shared
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/path/file.txt")

        await #expect(throws: DocumentParserError.self) {
            _ = try await parser.parse(fileURL: nonExistentURL)
        }
    }

    @Test("Throws for unsupported format")
    @MainActor
    func throwsForUnsupportedFormat() async throws {
        let parser = DocumentParser.shared
        let content = "Some content"
        let tempURL = createTempFile(content: content, extension: "docx")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        await #expect(throws: DocumentParserError.self) {
            _ = try await parser.parse(fileURL: tempURL)
        }
    }
}

// MARK: - Data Parsing Tests

@Suite("DocumentParser - Data Parsing")
struct DocumentParserDataTests {

    @Test("Parses text data")
    @MainActor
    func parsesTextData() async throws {
        let parser = DocumentParser.shared
        let content = "Hello from data parsing"
        let data = content.data(using: .utf8)!

        let parsed = try await parser.parse(data: data, filename: "test.txt")

        #expect(parsed.content.contains("Hello from data parsing"))
        #expect(parsed.metadata.fileType == .text)
    }

    @Test("Parses markdown data")
    @MainActor
    func parsesMarkdownData() async throws {
        let parser = DocumentParser.shared
        let content = "# Data Title\n\nContent here."
        let data = content.data(using: .utf8)!

        let parsed = try await parser.parse(data: data, filename: "readme.md")

        #expect(parsed.metadata.fileType == .markdown)
        #expect(parsed.metadata.title == "Data Title")
    }

    @Test("Throws for unsupported data format")
    @MainActor
    func throwsForUnsupportedDataFormat() async throws {
        let parser = DocumentParser.shared
        let data = Data()

        await #expect(throws: DocumentParserError.self) {
            _ = try await parser.parse(data: data, filename: "document.xlsx")
        }
    }
}

// MARK: - Remote Content Parsing Tests

@Suite("DocumentParser - Remote Content")
struct DocumentParserRemoteTests {

    @Test("Parses remote text content")
    @MainActor
    func parsesRemoteTextContent() async throws {
        let parser = DocumentParser.shared
        let content = "Remote content here"
        let url = URL(string: "https://example.com/document.txt")!

        let parsed = try await parser.parseRemoteContent(content, from: url)

        #expect(parsed.content == "Remote content here")
        #expect(parsed.metadata.title == "document.txt")
    }

    @Test("Parses remote markdown content")
    @MainActor
    func parsesRemoteMarkdownContent() async throws {
        let parser = DocumentParser.shared
        let content = "# Remote Doc\n\nContent"
        let url = URL(string: "https://example.com/readme.md")!

        let parsed = try await parser.parseRemoteContent(content, from: url)

        #expect(parsed.metadata.fileType == .markdown)
    }

    @Test("Throws for empty remote content")
    @MainActor
    func throwsForEmptyRemoteContent() async throws {
        let parser = DocumentParser.shared
        let url = URL(string: "https://example.com/empty.txt")!

        await #expect(throws: DocumentParserError.self) {
            _ = try await parser.parseRemoteContent("", from: url)
        }
    }

    @Test("Throws for whitespace only remote content")
    @MainActor
    func throwsForWhitespaceOnlyRemoteContent() async throws {
        let parser = DocumentParser.shared
        let url = URL(string: "https://example.com/whitespace.txt")!

        await #expect(throws: DocumentParserError.self) {
            _ = try await parser.parseRemoteContent("   \n\n   ", from: url)
        }
    }
}

// MARK: - Helper Functions

private func createTempFile(content: String, extension ext: String) -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    let fileName = UUID().uuidString + ".\(ext)"
    let fileURL = tempDir.appendingPathComponent(fileName)

    try? content.write(to: fileURL, atomically: true, encoding: .utf8)

    return fileURL
}
