//
//  TextChunker.swift
//  SwiftSpeak
//
//  Splits document content into overlapping chunks for embedding
//

import Foundation

// MARK: - Text Chunker

final class TextChunker: Sendable {

    // MARK: - Properties

    private let config: RAGConfiguration

    /// Minimum chunk size to keep (tokens)
    private let minChunkTokens = 20

    // MARK: - Initialization

    public init(config: RAGConfiguration = .default) {
        self.config = config
    }

    /// Create chunker from Power Mode's RAG configuration
    convenience init(powerMode: PowerMode) {
        self.init(config: powerMode.ragConfiguration)
    }

    // MARK: - Public API

    /// Split parsed document into chunks
    public func chunk(
        document: ParsedDocument,
        documentId: UUID
    ) -> [DocumentChunk] {
        switch config.chunkingStrategy {
        case .semantic:
            return chunkSemantically(document: document, documentId: documentId)
        case .fixedSize:
            return chunkByFixedSize(document: document, documentId: documentId)
        case .sentence:
            return chunkBySentence(document: document, documentId: documentId)
        }
    }

    /// Split raw text into chunks
    public func chunk(
        text: String,
        documentId: UUID,
        metadata: ChunkMetadata = ChunkMetadata()
    ) -> [DocumentChunk] {
        switch config.chunkingStrategy {
        case .semantic:
            return chunkTextSemantically(text: text, documentId: documentId, baseMetadata: metadata)
        case .fixedSize:
            return chunkTextByFixedSize(text: text, documentId: documentId, baseMetadata: metadata)
        case .sentence:
            return chunkTextBySentence(text: text, documentId: documentId, baseMetadata: metadata)
        }
    }

    // MARK: - Semantic Chunking

    private func chunkSemantically(
        document: ParsedDocument,
        documentId: UUID
    ) -> [DocumentChunk] {
        // If we have pages (PDF), chunk per page first
        if let pages = document.pages {
            return chunkPages(pages, documentId: documentId)
        }

        // Otherwise chunk the full content
        return chunkTextSemantically(
            text: document.content,
            documentId: documentId,
            baseMetadata: ChunkMetadata()
        )
    }

    private func chunkPages(
        _ pages: [ParsedPage],
        documentId: UUID
    ) -> [DocumentChunk] {
        var chunks: [DocumentChunk] = []
        var globalIndex = 0

        for page in pages {
            let pageChunks = chunkTextSemantically(
                text: page.content,
                documentId: documentId,
                baseMetadata: ChunkMetadata(pageNumber: page.pageNumber),
                startIndex: globalIndex
            )

            chunks.append(contentsOf: pageChunks)
            globalIndex += pageChunks.count
        }

        return chunks
    }

    private func chunkTextSemantically(
        text: String,
        documentId: UUID,
        baseMetadata: ChunkMetadata,
        startIndex: Int = 0
    ) -> [DocumentChunk] {
        let paragraphs = splitIntoParagraphs(text)
        var chunks: [DocumentChunk] = []
        var currentChunk = ""
        var currentOffset = 0
        var chunkStartOffset = 0
        var index = startIndex

        for paragraph in paragraphs {
            let paragraphTokens = estimateTokens(paragraph)
            let currentTokens = estimateTokens(currentChunk)

            // If this paragraph alone is too big, split it further
            if paragraphTokens > config.maxChunkTokens {
                // First, save current chunk if any
                if !currentChunk.isEmpty {
                    chunks.append(createChunk(
                        content: currentChunk,
                        documentId: documentId,
                        index: index,
                        startOffset: chunkStartOffset,
                        endOffset: currentOffset,
                        metadata: baseMetadata
                    ))
                    index += 1
                    currentChunk = ""
                }

                // Split the large paragraph by sentences
                let sentenceChunks = splitLargeParagraph(paragraph, documentId: documentId, startIndex: index, startOffset: currentOffset, metadata: baseMetadata)
                chunks.append(contentsOf: sentenceChunks)
                index += sentenceChunks.count
                currentOffset += paragraph.count
                chunkStartOffset = currentOffset
            }
            // If adding this paragraph exceeds limit, save current and start new
            else if currentTokens + paragraphTokens > config.maxChunkTokens && !currentChunk.isEmpty {
                chunks.append(createChunk(
                    content: currentChunk,
                    documentId: documentId,
                    index: index,
                    startOffset: chunkStartOffset,
                    endOffset: currentOffset,
                    metadata: baseMetadata
                ))
                index += 1

                // Start new chunk with overlap
                let overlap = getOverlapText(from: currentChunk)
                currentChunk = overlap + paragraph
                chunkStartOffset = currentOffset - overlap.count
                currentOffset += paragraph.count
            }
            // Add to current chunk
            else {
                if !currentChunk.isEmpty {
                    currentChunk += "\n\n"
                    currentOffset += 2
                }
                currentChunk += paragraph
                currentOffset += paragraph.count
            }
        }

        // Don't forget the last chunk
        if !currentChunk.isEmpty && estimateTokens(currentChunk) >= minChunkTokens {
            chunks.append(createChunk(
                content: currentChunk,
                documentId: documentId,
                index: index,
                startOffset: chunkStartOffset,
                endOffset: currentOffset,
                metadata: baseMetadata
            ))
        }

        return chunks
    }

    private func splitLargeParagraph(
        _ paragraph: String,
        documentId: UUID,
        startIndex: Int,
        startOffset: Int,
        metadata: ChunkMetadata
    ) -> [DocumentChunk] {
        let sentences = splitIntoSentences(paragraph)
        var chunks: [DocumentChunk] = []
        var currentChunk = ""
        var currentOffset = startOffset
        var chunkStartOffset = startOffset
        var index = startIndex

        for sentence in sentences {
            let sentenceTokens = estimateTokens(sentence)
            let currentTokens = estimateTokens(currentChunk)

            if currentTokens + sentenceTokens > config.maxChunkTokens && !currentChunk.isEmpty {
                chunks.append(createChunk(
                    content: currentChunk,
                    documentId: documentId,
                    index: index,
                    startOffset: chunkStartOffset,
                    endOffset: currentOffset,
                    metadata: metadata
                ))
                index += 1

                let overlap = getOverlapText(from: currentChunk)
                currentChunk = overlap + sentence
                chunkStartOffset = currentOffset - overlap.count
                currentOffset += sentence.count
            } else {
                if !currentChunk.isEmpty {
                    currentChunk += " "
                    currentOffset += 1
                }
                currentChunk += sentence
                currentOffset += sentence.count
            }
        }

        if !currentChunk.isEmpty && estimateTokens(currentChunk) >= minChunkTokens {
            chunks.append(createChunk(
                content: currentChunk,
                documentId: documentId,
                index: index,
                startOffset: chunkStartOffset,
                endOffset: currentOffset,
                metadata: metadata
            ))
        }

        return chunks
    }

    // MARK: - Fixed Size Chunking

    private func chunkByFixedSize(
        document: ParsedDocument,
        documentId: UUID
    ) -> [DocumentChunk] {
        chunkTextByFixedSize(
            text: document.content,
            documentId: documentId,
            baseMetadata: ChunkMetadata()
        )
    }

    private func chunkTextByFixedSize(
        text: String,
        documentId: UUID,
        baseMetadata: ChunkMetadata
    ) -> [DocumentChunk] {
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let wordsPerChunk = config.maxChunkTokens // Approximate 1 token per word
        let overlapWords = config.overlapTokens

        var chunks: [DocumentChunk] = []
        var startWordIndex = 0
        var index = 0
        var characterOffset = 0

        while startWordIndex < words.count {
            let endWordIndex = min(startWordIndex + wordsPerChunk, words.count)
            let chunkWords = Array(words[startWordIndex..<endWordIndex])
            let content = chunkWords.joined(separator: " ")

            let chunkStartOffset = characterOffset
            let chunkEndOffset = characterOffset + content.count

            chunks.append(createChunk(
                content: content,
                documentId: documentId,
                index: index,
                startOffset: chunkStartOffset,
                endOffset: chunkEndOffset,
                metadata: baseMetadata
            ))

            characterOffset = chunkEndOffset + 1 // +1 for space
            startWordIndex = endWordIndex - overlapWords
            index += 1

            if startWordIndex < 0 { startWordIndex = endWordIndex }
        }

        return chunks
    }

    // MARK: - Sentence Chunking

    private func chunkBySentence(
        document: ParsedDocument,
        documentId: UUID
    ) -> [DocumentChunk] {
        chunkTextBySentence(
            text: document.content,
            documentId: documentId,
            baseMetadata: ChunkMetadata()
        )
    }

    private func chunkTextBySentence(
        text: String,
        documentId: UUID,
        baseMetadata: ChunkMetadata
    ) -> [DocumentChunk] {
        let sentences = splitIntoSentences(text)
        var chunks: [DocumentChunk] = []
        var currentChunk = ""
        var currentOffset = 0
        var chunkStartOffset = 0
        var index = 0

        for sentence in sentences {
            let sentenceTokens = estimateTokens(sentence)
            let currentTokens = estimateTokens(currentChunk)

            if currentTokens + sentenceTokens > config.maxChunkTokens && !currentChunk.isEmpty {
                chunks.append(createChunk(
                    content: currentChunk,
                    documentId: documentId,
                    index: index,
                    startOffset: chunkStartOffset,
                    endOffset: currentOffset,
                    metadata: baseMetadata
                ))
                index += 1

                let overlap = getOverlapText(from: currentChunk)
                currentChunk = overlap + sentence
                chunkStartOffset = currentOffset - overlap.count
                currentOffset += sentence.count
            } else {
                if !currentChunk.isEmpty {
                    currentChunk += " "
                    currentOffset += 1
                }
                currentChunk += sentence
                currentOffset += sentence.count
            }
        }

        if !currentChunk.isEmpty && estimateTokens(currentChunk) >= minChunkTokens {
            chunks.append(createChunk(
                content: currentChunk,
                documentId: documentId,
                index: index,
                startOffset: chunkStartOffset,
                endOffset: currentOffset,
                metadata: baseMetadata
            ))
        }

        return chunks
    }

    // MARK: - Helpers

    private func createChunk(
        content: String,
        documentId: UUID,
        index: Int,
        startOffset: Int,
        endOffset: Int,
        metadata: ChunkMetadata
    ) -> DocumentChunk {
        var chunkMetadata = metadata
        chunkMetadata.contentType = detectContentType(content)

        return DocumentChunk(
            documentId: documentId,
            index: index,
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            startOffset: startOffset,
            endOffset: endOffset,
            metadata: chunkMetadata
        )
    }

    private func splitIntoParagraphs(_ text: String) -> [String] {
        text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []

        text.enumerateSubstrings(
            in: text.startIndex...,
            options: .bySentences
        ) { substring, _, _, _ in
            if let sentence = substring?.trimmingCharacters(in: .whitespacesAndNewlines),
               !sentence.isEmpty {
                sentences.append(sentence)
            }
        }

        // Fallback if no sentences found
        if sentences.isEmpty && !text.isEmpty {
            sentences = [text]
        }

        return sentences
    }

    private func estimateTokens(_ text: String) -> Int {
        // Rough estimate: ~4 characters per token
        max(1, text.count / 4)
    }

    private func getOverlapText(from text: String) -> String {
        let targetChars = config.overlapTokens * 4 // Convert tokens to chars

        if text.count <= targetChars {
            return ""
        }

        // Get last N characters, but try to break at word boundary
        let startIndex = text.index(text.endIndex, offsetBy: -targetChars, limitedBy: text.startIndex) ?? text.startIndex
        var overlap = String(text[startIndex...])

        // Find first space to start at word boundary
        if let spaceIndex = overlap.firstIndex(of: " ") {
            overlap = String(overlap[overlap.index(after: spaceIndex)...])
        }

        return overlap
    }

    private func detectContentType(_ content: String) -> ChunkContentType {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for markdown header
        if trimmed.hasPrefix("#") {
            return .header
        }

        // Check for code block
        if trimmed.hasPrefix("```") || trimmed.contains("\n```") {
            return .codeBlock
        }

        // Check for list item
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") ||
           trimmed.range(of: "^\\d+\\.", options: .regularExpression) != nil {
            return .listItem
        }

        // Check for quote
        if trimmed.hasPrefix(">") {
            return .quote
        }

        return .paragraph
    }
}
