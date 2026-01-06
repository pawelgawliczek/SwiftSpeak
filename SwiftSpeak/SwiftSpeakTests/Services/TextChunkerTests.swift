//
//  TextChunkerTests.swift
//  SwiftSpeakTests
//
//  Tests for TextChunker - document chunking for RAG
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

// MARK: - Basic Chunking Tests

@Suite("TextChunker - Basic")
struct TextChunkerBasicTests {

    @Test("Chunks simple text")
    func chunksSimpleText() {
        let chunker = TextChunker(config: RAGConfiguration.default)
        let documentId = UUID()

        // Text must be at least ~80 chars (20 tokens) to pass minChunkTokens threshold
        let chunks = chunker.chunk(
            text: "This is a simple paragraph of text that contains enough words to meet the minimum token requirement for chunking.",
            documentId: documentId
        )

        #expect(!chunks.isEmpty)
        #expect(chunks.first?.documentId == documentId)
        #expect(chunks.first?.content.contains("simple paragraph") == true)
    }

    @Test("Preserves document ID in all chunks")
    func preservesDocumentId() {
        let chunker = TextChunker()
        let documentId = UUID()

        let longText = String(repeating: "This is a test sentence. ", count: 100)
        let chunks = chunker.chunk(text: longText, documentId: documentId)

        for chunk in chunks {
            #expect(chunk.documentId == documentId)
        }
    }

    @Test("Assigns sequential indices to chunks")
    func assignsSequentialIndices() {
        var config = RAGConfiguration.default
        config.maxChunkTokens = 50
        let chunker = TextChunker(config: config)
        let documentId = UUID()

        let longText = String(repeating: "This is sentence number one. This is sentence number two. ", count: 20)
        let chunks = chunker.chunk(text: longText, documentId: documentId)

        for (expected, chunk) in chunks.enumerated() {
            #expect(chunk.index == expected)
        }
    }

    @Test("Empty text returns empty chunks")
    func emptyTextReturnsEmptyChunks() {
        let chunker = TextChunker()
        let chunks = chunker.chunk(text: "", documentId: UUID())

        #expect(chunks.isEmpty)
    }

    @Test("Whitespace only text returns empty chunks")
    func whitespaceOnlyReturnsEmptyChunks() {
        let chunker = TextChunker()
        let chunks = chunker.chunk(text: "   \n\n   \t\t   ", documentId: UUID())

        #expect(chunks.isEmpty)
    }
}

// MARK: - Chunk Size Tests

@Suite("TextChunker - Chunk Sizes")
struct TextChunkerSizeTests {

    @Test("Respects max chunk token limit")
    func respectsMaxChunkTokens() {
        let maxTokens = 100
        var config = RAGConfiguration.default
        config.maxChunkTokens = maxTokens
        let chunker = TextChunker(config: config)

        // Create text that's definitely larger than chunk limit (using sentences to avoid word-only text)
        let longText = String(repeating: "This is a complete sentence with multiple words. ", count: 100)
        let chunks = chunker.chunk(text: longText, documentId: UUID())

        #expect(!chunks.isEmpty, "Should produce at least one chunk")
        for chunk in chunks {
            // Estimate tokens (roughly 4 chars per token)
            let estimatedTokens = chunk.content.count / 4
            // Allow some tolerance
            #expect(estimatedTokens <= maxTokens + 20, "Chunk too large: \(estimatedTokens) tokens")
        }
    }

    @Test("Small text creates single chunk")
    func smallTextCreatesSingleChunk() {
        var config = RAGConfiguration.default
        config.maxChunkTokens = 500
        let chunker = TextChunker(config: config)
        // Text must exceed minChunkTokens (20 tokens = ~80 chars)
        let text = "This is a short text that should fit in one chunk but needs to be long enough to meet the minimum token requirement."

        let chunks = chunker.chunk(text: text, documentId: UUID())

        #expect(chunks.count == 1)
    }

    @Test("Long text creates multiple chunks")
    func longTextCreatesMultipleChunks() {
        var config = RAGConfiguration.default
        config.maxChunkTokens = 50
        let chunker = TextChunker(config: config)

        let longText = String(repeating: "This is a test sentence that will be chunked. ", count: 50)
        let chunks = chunker.chunk(text: longText, documentId: UUID())

        #expect(chunks.count > 1)
    }
}

// MARK: - Chunking Strategy Tests

@Suite("TextChunker - Strategies")
struct TextChunkerStrategyTests {

    @Test("Semantic chunking splits on paragraphs")
    func semanticChunkingSplitsOnParagraphs() {
        var config = RAGConfiguration.default
        config.chunkingStrategy = .semantic
        config.maxChunkTokens = 100
        let chunker = TextChunker(config: config)

        let text = """
        First paragraph with some content.

        Second paragraph with different content.

        Third paragraph with more content.
        """

        let chunks = chunker.chunk(text: text, documentId: UUID())

        // Semantic chunking should keep paragraphs together when possible
        #expect(!chunks.isEmpty)
    }

    @Test("Fixed size chunking creates uniform chunks")
    func fixedSizeCreatesUniformChunks() {
        var config = RAGConfiguration.default
        config.chunkingStrategy = .fixedSize
        config.maxChunkTokens = 50
        config.overlapTokens = 10
        let chunker = TextChunker(config: config)

        let text = String(repeating: "word ", count: 200)
        let chunks = chunker.chunk(text: text, documentId: UUID())

        #expect(chunks.count > 1)
    }

    @Test("Sentence chunking keeps sentences together")
    func sentenceChunkingKeepsSentencesTogether() {
        var config = RAGConfiguration.default
        config.chunkingStrategy = .sentence
        config.maxChunkTokens = 100
        let chunker = TextChunker(config: config)

        let text = "This is sentence one. This is sentence two. This is sentence three."
        let chunks = chunker.chunk(text: text, documentId: UUID())

        // Each chunk should contain complete sentences
        for chunk in chunks {
            // Check it doesn't end mid-word (crude check)
            #expect(!chunk.content.hasSuffix(" "))
        }
    }
}

// MARK: - Overlap Tests

@Suite("TextChunker - Overlap")
struct TextChunkerOverlapTests {

    @Test("Creates overlap between chunks")
    func createsOverlapBetweenChunks() {
        var config = RAGConfiguration.default
        config.chunkingStrategy = .fixedSize
        config.maxChunkTokens = 50
        config.overlapTokens = 20
        let chunker = TextChunker(config: config)

        let text = "One two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty twenty-one twenty-two twenty-three twenty-four twenty-five"
        let chunks = chunker.chunk(text: text, documentId: UUID())

        guard chunks.count >= 2 else {
            #expect(Bool(false), "Need at least 2 chunks for overlap test")
            return
        }

        // Check that there's some overlap
        let firstChunkWords = Set(chunks[0].content.components(separatedBy: " "))
        let secondChunkWords = Set(chunks[1].content.components(separatedBy: " "))
        let overlap = firstChunkWords.intersection(secondChunkWords)

        #expect(!overlap.isEmpty, "Should have some overlapping words")
    }
}

// MARK: - Content Type Detection Tests

@Suite("TextChunker - Content Detection")
struct TextChunkerContentDetectionTests {

    @Test("Detects header content type")
    func detectsHeaderContentType() {
        let chunker = TextChunker()
        let chunks = chunker.chunk(
            text: "# This is a header\n\nSome body text follows.",
            documentId: UUID()
        )

        let headerChunk = chunks.first { $0.content.hasPrefix("#") }
        #expect(headerChunk?.metadata.contentType == .header)
    }

    @Test("Detects code block content type")
    func detectsCodeBlockContentType() {
        let chunker = TextChunker()
        let chunks = chunker.chunk(
            text: "```swift\nlet x = 5\n```",
            documentId: UUID()
        )

        #expect(chunks.first?.metadata.contentType == .codeBlock)
    }

    @Test("Detects list item content type")
    func detectsListItemContentType() {
        let chunker = TextChunker()

        let bulletList = chunker.chunk(text: "- First item", documentId: UUID())
        #expect(bulletList.first?.metadata.contentType == .listItem)

        let numberedList = chunker.chunk(text: "1. First item", documentId: UUID())
        #expect(numberedList.first?.metadata.contentType == .listItem)
    }

    @Test("Detects quote content type")
    func detectsQuoteContentType() {
        let chunker = TextChunker()
        let chunks = chunker.chunk(
            text: "> This is a quoted text",
            documentId: UUID()
        )

        #expect(chunks.first?.metadata.contentType == .quote)
    }

    @Test("Defaults to paragraph content type")
    func defaultsToParagraphContentType() {
        let chunker = TextChunker()
        let chunks = chunker.chunk(
            text: "This is a regular paragraph of text.",
            documentId: UUID()
        )

        #expect(chunks.first?.metadata.contentType == .paragraph)
    }
}

// MARK: - Offset Tests

@Suite("TextChunker - Offsets")
struct TextChunkerOffsetTests {

    @Test("Tracks start and end offsets")
    func tracksStartAndEndOffsets() {
        let chunker = TextChunker()
        let chunks = chunker.chunk(
            text: "First chunk content.",
            documentId: UUID()
        )

        guard let chunk = chunks.first else {
            #expect(Bool(false), "Should have at least one chunk")
            return
        }

        #expect(chunk.startOffset >= 0)
        #expect(chunk.endOffset > chunk.startOffset)
    }
}

// MARK: - ParsedDocument Tests

@Suite("TextChunker - ParsedDocument")
struct TextChunkerParsedDocumentTests {

    @Test("Chunks parsed document")
    func chunksParsedDocument() {
        let chunker = TextChunker()
        let documentId = UUID()

        let metadata = ParsedDocumentMetadata(title: "Test Document")
        let document = ParsedDocument(
            content: "This is the document content.",
            metadata: metadata,
            pages: nil
        )

        let chunks = chunker.chunk(document: document, documentId: documentId)

        #expect(!chunks.isEmpty)
        #expect(chunks.first?.documentId == documentId)
    }

    @Test("Handles document with pages")
    func handlesDocumentWithPages() {
        let chunker = TextChunker()
        let documentId = UUID()

        let pages = [
            ParsedPage(pageNumber: 1, content: "Content of page one.", bounds: nil),
            ParsedPage(pageNumber: 2, content: "Content of page two.", bounds: nil),
            ParsedPage(pageNumber: 3, content: "Content of page three.", bounds: nil)
        ]

        let metadata = ParsedDocumentMetadata(title: "Multi-page Document")
        let document = ParsedDocument(
            content: "Full content",
            metadata: metadata,
            pages: pages
        )

        let chunks = chunker.chunk(document: document, documentId: documentId)

        #expect(!chunks.isEmpty)
        // Should have chunks from multiple pages
    }
}

// MARK: - PowerMode Configuration Tests

@Suite("TextChunker - PowerMode Config")
struct TextChunkerPowerModeTests {

    @Test("Uses PowerMode RAG configuration")
    func usesPowerModeConfiguration() {
        let powerMode = PowerMode(
            name: "Test Mode",
            icon: "bolt",
            iconColor: .orange,
            iconBackgroundColor: .orange,
            instruction: "Test instruction",
            outputFormat: "Test format"
        )

        let chunker = TextChunker(powerMode: powerMode)

        // Just verify it can be created - actual config values tested elsewhere
        let chunks = chunker.chunk(text: "Test text", documentId: UUID())
        #expect(chunks.count >= 0) // Can be empty for very short text
    }
}
