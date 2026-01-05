//
//  MacObsidianIndexer.swift
//  SwiftSpeakMac
//
//  Obsidian indexer for macOS
//  Scans vault, parses markdown, creates chunks, generates embeddings
//

import Foundation
import SwiftSpeakCore

// MARK: - Mac Obsidian Indexer

@MainActor
final class MacObsidianIndexer {

    private let apiKey: String
    private var sessionCost: Double = 0

    init(apiKey: String) {
        self.apiKey = apiKey
        macLog("MacObsidianIndexer initialized", category: "Indexer")
    }

    deinit {
        macLog("MacObsidianIndexer deinit", category: "Indexer")
    }

    // MARK: - Public API

    func indexVault(
        at path: String,
        vaultId: UUID,
        chunkSize: Int = ObsidianVault.defaultChunkSize,
        chunkOverlap: Int = ObsidianVault.defaultChunkOverlap
    ) -> AsyncStream<ObsidianIndexingProgress> {
        macLog("indexVault called for: \(path) (chunkSize: \(chunkSize), overlap: \(chunkOverlap))", category: "Indexer")

        let indexer = self

        return AsyncStream { continuation in
            macLog("AsyncStream created", category: "Indexer")

            // Yield initial progress
            continuation.yield(ObsidianIndexingProgress(
                phase: .scanning,
                currentNote: "Starting...",
                notesProcessed: 0,
                totalNotes: 0,
                chunksGenerated: 0,
                estimatedCost: 0
            ))

            Task.detached {
                macLog("Task.detached started", category: "Indexer")

                do {
                    let result = try await indexer.performIndexing(
                        path: path,
                        vaultId: vaultId,
                        chunkSize: chunkSize,
                        chunkOverlap: chunkOverlap,
                        continuation: continuation
                    )

                    macLog("Indexing complete: \(result.noteCount) notes, \(result.chunkCount) chunks", category: "Indexer")

                    continuation.yield(ObsidianIndexingProgress(
                        phase: .complete,
                        currentNote: nil,
                        notesProcessed: result.noteCount,
                        totalNotes: result.noteCount,
                        chunksGenerated: result.chunkCount,
                        estimatedCost: result.cost
                    ))
                    continuation.finish()
                } catch {
                    macLog("Indexing failed: \(error.localizedDescription)", category: "Indexer", level: .error)

                    continuation.yield(ObsidianIndexingProgress(
                        phase: .error,
                        currentNote: error.localizedDescription,
                        notesProcessed: 0,
                        totalNotes: 0,
                        chunksGenerated: 0,
                        estimatedCost: 0
                    ))
                    continuation.finish()
                }
            }
        }
    }

    func estimateCost(for path: String) async throws -> (noteCount: Int, chunkCount: Int, estimatedCost: Double) {
        try validateVault(at: path)

        let markdownFiles = try scanForMarkdownFiles(in: path)
        let estimatedChunks = markdownFiles.count * 5 // Rough estimate: 5 chunks per note
        let estimatedCost = Double(estimatedChunks) * 0.00002 // ~$0.02 per 1M tokens

        return (noteCount: markdownFiles.count, chunkCount: estimatedChunks, estimatedCost: estimatedCost)
    }

    // MARK: - Validation

    func validateVault(at path: String) throws {
        let fileManager = FileManager.default

        macLog("Validating vault at: \(path)", category: "Indexer")

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ObsidianIndexerError.vaultNotFound(path)
        }

        // Check for .obsidian folder
        let obsidianPath = (path as NSString).appendingPathComponent(".obsidian")
        guard fileManager.fileExists(atPath: obsidianPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            macLog("No .obsidian folder found", category: "Indexer", level: .error)
            throw ObsidianIndexerError.notObsidianVault(path)
        }

        macLog("Vault validated successfully", category: "Indexer")
    }

    // MARK: - Private Implementation

    private func performIndexing(
        path: String,
        vaultId: UUID,
        chunkSize: Int,
        chunkOverlap: Int,
        continuation: AsyncStream<ObsidianIndexingProgress>.Continuation
    ) async throws -> (noteCount: Int, chunkCount: Int, cost: Double) {

        try validateVault(at: path)

        // Phase 1: Scan
        continuation.yield(ObsidianIndexingProgress(
            phase: .scanning,
            currentNote: nil,
            notesProcessed: 0,
            totalNotes: 0,
            chunksGenerated: 0,
            estimatedCost: 0
        ))

        let markdownFiles = try scanForMarkdownFiles(in: path)
        macLog("Found \(markdownFiles.count) markdown files", category: "Indexer")

        if markdownFiles.isEmpty {
            return (noteCount: 0, chunkCount: 0, cost: 0)
        }

        // Phase 2-3: Parse and chunk - create ObsidianChunk objects
        var allChunks: [ObsidianChunk] = []
        var noteIds: [String: UUID] = [:] // Track note IDs by path

        for (index, fileURL) in markdownFiles.enumerated() {
            let relativePath = fileURL.path.replacingOccurrences(of: path + "/", with: "")
            let noteId = UUID()
            noteIds[relativePath] = noteId

            // Extract title from filename or first heading
            let noteTitle = extractTitle(from: fileURL)

            continuation.yield(ObsidianIndexingProgress(
                phase: .parsing,
                currentNote: fileURL.lastPathComponent,
                notesProcessed: index,
                totalNotes: markdownFiles.count,
                chunksGenerated: allChunks.count,
                estimatedCost: sessionCost
            ))

            // Read and chunk the file
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let chunkTexts = chunkText(content, maxChunkSize: chunkSize, overlap: chunkOverlap)

            for (chunkIndex, text) in chunkTexts.enumerated() {
                let chunk = ObsidianChunk(
                    vaultId: vaultId,
                    noteId: noteId,
                    notePath: relativePath,
                    noteTitle: noteTitle,
                    content: text,
                    chunkIndex: chunkIndex,
                    embedding: nil // Will be filled in later
                )
                allChunks.append(chunk)
            }
        }

        macLog("Created \(allChunks.count) chunks", category: "Indexer")

        // Phase 4: Generate embeddings
        continuation.yield(ObsidianIndexingProgress(
            phase: .embedding,
            currentNote: nil,
            notesProcessed: markdownFiles.count,
            totalNotes: markdownFiles.count,
            chunksGenerated: allChunks.count,
            estimatedCost: sessionCost
        ))

        // Generate embeddings in batches and attach to chunks
        let batchSize = 100

        for batchStart in stride(from: 0, to: allChunks.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, allChunks.count)

            let texts = allChunks[batchStart..<batchEnd].map { $0.content }
            let embeddings = try await generateEmbeddings(texts: texts)

            // Attach embeddings to chunks
            for (offset, embedding) in embeddings.enumerated() {
                let chunkIndex = batchStart + offset
                allChunks[chunkIndex] = ObsidianChunk(
                    id: allChunks[chunkIndex].id,
                    vaultId: allChunks[chunkIndex].vaultId,
                    noteId: allChunks[chunkIndex].noteId,
                    notePath: allChunks[chunkIndex].notePath,
                    noteTitle: allChunks[chunkIndex].noteTitle,
                    content: allChunks[chunkIndex].content,
                    chunkIndex: allChunks[chunkIndex].chunkIndex,
                    embedding: embedding
                )
            }

            macLog("Generated embeddings: \(batchEnd)/\(allChunks.count)", category: "Indexer")

            continuation.yield(ObsidianIndexingProgress(
                phase: .embedding,
                currentNote: "Batch \(batchStart/batchSize + 1)",
                notesProcessed: markdownFiles.count,
                totalNotes: markdownFiles.count,
                chunksGenerated: batchEnd,
                estimatedCost: sessionCost
            ))
        }

        // Phase 5: Save to vector store
        macLog("Saving to vector store...", category: "Indexer")
        let vectorStore = await MacObsidianVectorStore()
        try await vectorStore.save(chunks: allChunks, for: vaultId)
        macLog("Saved \(allChunks.count) chunks to vector store", category: "Indexer")

        return (noteCount: markdownFiles.count, chunkCount: allChunks.count, cost: sessionCost)
    }

    /// Extract title from markdown file (first # heading or filename)
    private func extractTitle(from fileURL: URL) -> String {
        let filename = fileURL.deletingPathExtension().lastPathComponent

        // Try to read first heading
        if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines)
            for line in lines.prefix(10) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("# ") {
                    return String(trimmed.dropFirst(2))
                }
            }
        }

        return filename
    }

    private func scanForMarkdownFiles(in path: String) throws -> [URL] {
        let fileManager = FileManager.default
        let vaultURL = URL(fileURLWithPath: path)

        var markdownFiles: [URL] = []

        let enumerator = fileManager.enumerator(
            at: vaultURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathComponents.contains(".obsidian") {
                continue
            }

            if fileURL.pathExtension.lowercased() == "md" {
                markdownFiles.append(fileURL)
            }
        }

        return markdownFiles.sorted { $0.path < $1.path }
    }

    private func chunkText(_ text: String, maxChunkSize: Int, overlap: Int) -> [String] {
        let paragraphs = text.components(separatedBy: "\n\n")
        var chunks: [String] = []
        var currentChunk = ""
        var overlapText = ""  // Text to prepend to next chunk for overlap

        for paragraph in paragraphs {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            if currentChunk.isEmpty {
                // Start new chunk, possibly with overlap from previous
                if !overlapText.isEmpty {
                    currentChunk = overlapText + "\n\n" + trimmed
                    overlapText = ""
                } else {
                    currentChunk = trimmed
                }
            } else if currentChunk.count + trimmed.count + 2 <= maxChunkSize {
                currentChunk += "\n\n" + trimmed
            } else {
                // Current chunk is full
                chunks.append(currentChunk)

                // Calculate overlap: take last N characters from current chunk
                if overlap > 0 && currentChunk.count > overlap {
                    let overlapStart = currentChunk.index(currentChunk.endIndex, offsetBy: -overlap)
                    overlapText = String(currentChunk[overlapStart...])
                    // Try to start at a word boundary
                    if let spaceIndex = overlapText.firstIndex(of: " ") {
                        overlapText = String(overlapText[spaceIndex...]).trimmingCharacters(in: .whitespaces)
                    }
                }

                // Start new chunk with overlap + new paragraph
                if !overlapText.isEmpty {
                    currentChunk = overlapText + "\n\n" + trimmed
                    overlapText = ""
                } else {
                    currentChunk = trimmed
                }
            }
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }

        return chunks
    }

    private func generateEmbeddings(texts: [String]) async throws -> [[Float]] {
        let url = URL(string: "https://api.openai.com/v1/embeddings")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "text-embedding-3-small",
            "input": texts
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ObsidianIndexerError.apiError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ObsidianIndexerError.apiError("HTTP \(httpResponse.statusCode): \(errorText)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let usage = json["usage"] as? [String: Any],
              let totalTokens = usage["total_tokens"] as? Int else {
            throw ObsidianIndexerError.apiError("Invalid response format")
        }

        // Calculate cost: $0.02 per 1M tokens for text-embedding-3-small
        sessionCost += Double(totalTokens) * 0.00002 / 1000

        var embeddings: [[Float]] = []
        for item in dataArray {
            if let embedding = item["embedding"] as? [Double] {
                embeddings.append(embedding.map { Float($0) })
            }
        }

        return embeddings
    }
}
