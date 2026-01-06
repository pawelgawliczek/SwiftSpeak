//
//  ObsidianIndexer.swift
//  SwiftSpeak
//
//  Indexes Obsidian vaults on macOS, creating embeddings for all markdown notes
//  Uses existing RAG services (DocumentParser, TextChunker, EmbeddingService)
//

import Foundation
import SwiftSpeakCore
import CryptoKit

// Debug logging that works on macOS Console.app
private func indexerLog(_ message: String) {
    let msg = "[ObsidianIndexer] \(message)"
    print(msg)
    #if os(macOS)
    NSLog("%@", msg)
    #endif
}

// MARK: - Indexing Errors

// Uses ObsidianIndexerError from SwiftSpeakCore

/// Additional error case for iOS (cancellation not in core)
enum LocalObsidianIndexerError: Error, LocalizedError {
    case indexingCancelled

    var errorDescription: String? {
        switch self {
        case .indexingCancelled:
            return "Indexing was cancelled"
        }
    }
}

// MARK: - Indexing Progress

// Uses ObsidianIndexingProgress from SwiftSpeakCore

// MARK: - Obsidian Indexer

@MainActor
final class ObsidianIndexer {

    // MARK: - Dependencies

    private let documentParser = DocumentParser.shared
    private var textChunker: TextChunker
    private var embeddingService: EmbeddingService?

    // MARK: - State

    private var isCancelled = false
    private var progressStream: AsyncStream<ObsidianIndexingProgress>.Continuation?

    /// Public accessor to keep reference alive during async iteration
    var isCancelledPublic: Bool { isCancelled }

    // MARK: - Initialization

    init(config: RAGConfiguration = .default, apiKey: String? = nil) {
        indexerLog("ObsidianIndexer init")
        self.textChunker = TextChunker(config: config)
        if let apiKey = apiKey, !apiKey.isEmpty {
            self.embeddingService = EmbeddingService(apiKey: apiKey, model: config.embeddingModel)
        }
    }

    deinit {
        indexerLog("ObsidianIndexer DEINIT - being deallocated!")
    }

    // MARK: - Public API

    /// Index an Obsidian vault, returning progress updates
    func indexVault(
        at path: String,
        vaultId: UUID,
        config: RAGConfiguration = .default
    ) -> AsyncStream<ObsidianIndexingProgress> {
        indexerLog("indexVault() called for: \(path)")

        // Capture self to keep indexer alive
        let indexer = self

        return AsyncStream { continuation in
            indexerLog("AsyncStream continuation created")
            indexer.progressStream = continuation

            // Yield initial progress immediately to confirm stream is working
            continuation.yield(ObsidianIndexingProgress(
                phase: .scanning,
                currentNote: "Starting...",
                notesProcessed: 0,
                totalNotes: 0,
                chunksGenerated: 0,
                estimatedCost: 0
            ))
            indexerLog("Yielded initial scanning progress")

            continuation.onTermination = { termination in
                indexerLog("Stream terminated: \(termination)")
            }

            // Use Task.detached to avoid blocking main actor
            Task.detached {
                indexerLog("Task started inside AsyncStream")
                do {
                    indexerLog("Starting performIndexing for path: \(path)")
                    let manifest = try await indexer.performIndexing(
                        path: path,
                        vaultId: vaultId,
                        config: config
                    )

                    indexerLog("performIndexing completed successfully")
                    let cost = await indexer.embeddingService?.sessionCost ?? 0
                    continuation.yield(ObsidianIndexingProgress(
                        phase: .complete,
                        currentNote: nil,
                        notesProcessed: manifest.noteCount,
                        totalNotes: manifest.noteCount,
                        chunksGenerated: manifest.chunkCount,
                        estimatedCost: cost
                    ))
                    continuation.finish()
                } catch {
                    // Yield error progress so UI can show the error message
                    let errorMsg = error.localizedDescription
                    indexerLog("========== INDEXING FAILED ==========")
                    indexerLog("Error: \(errorMsg)")
                    indexerLog("Error type: \(type(of: error))")
                    indexerLog("Full error: \(error)")

                    // Put error message in currentNote field for cross-target compatibility
                    let errorProgress = ObsidianIndexingProgress(
                        phase: .error,
                        currentNote: errorMsg,
                        notesProcessed: 0,
                        totalNotes: 0,
                        chunksGenerated: 0,
                        estimatedCost: 0
                    )
                    indexerLog("Yielding error progress to stream...")
                    continuation.yield(errorProgress)
                    indexerLog("Finishing stream...")
                    continuation.finish()
                    indexerLog("Stream finished")
                }
            }
        }
    }

    /// Cancel ongoing indexing operation
    func cancel() {
        isCancelled = true
    }

    // MARK: - Validation

    /// Validate that a folder is an Obsidian vault (requires .obsidian folder)
    func validateVault(at path: String) throws {
        let fileManager = FileManager.default

        indexerLog("Validating vault at: \(path)")

        // Check folder exists
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
        indexerLog("Folder exists: \(exists), isDirectory: \(isDirectory.boolValue)")

        guard exists, isDirectory.boolValue else {
            indexerLog("ERROR: Vault folder not found")
            throw ObsidianIndexerError.vaultNotFound(path)
        }

        // List contents to debug
        if let contents = try? fileManager.contentsOfDirectory(atPath: path) {
            indexerLog("Folder contents (\(contents.count) items): \(contents.prefix(20))")
            let hasObsidian = contents.contains(".obsidian")
            indexerLog("Contains .obsidian in listing: \(hasObsidian)")
        }

        // Check for .obsidian folder - this confirms it's an Obsidian vault
        let obsidianFolderPath = (path as NSString).appendingPathComponent(".obsidian")
        indexerLog("Checking for: \(obsidianFolderPath)")

        let obsidianExists = fileManager.fileExists(atPath: obsidianFolderPath, isDirectory: &isDirectory)
        indexerLog(".obsidian exists: \(obsidianExists), isDirectory: \(isDirectory.boolValue)")

        guard obsidianExists, isDirectory.boolValue else {
            indexerLog("ERROR: No .obsidian folder found - not a valid Obsidian vault")
            throw ObsidianIndexerError.notObsidianVault(path)
        }

        indexerLog("SUCCESS: Found .obsidian folder - valid Obsidian vault")
    }

    // MARK: - Private Indexing

    private func performIndexing(
        path: String,
        vaultId: UUID,
        config: RAGConfiguration
    ) async throws -> ObsidianVaultManifest {
        indexerLog("Starting indexing for vault at: \(path)")

        // Validate vault
        try validateVault(at: path)
        indexerLog("Vault validated successfully")

        // Phase 1: Scan for markdown files
        progressStream?.yield(ObsidianIndexingProgress(
            phase: .scanning,
            currentNote: nil,
            notesProcessed: 0,
            totalNotes: 0,
            chunksGenerated: 0,
            estimatedCost: 0
        ))

        let markdownFiles = try scanForMarkdownFiles(in: path)
        indexerLog("Scan complete: \(markdownFiles.count) files found")

        // Handle empty vaults gracefully - return empty manifest instead of error
        if markdownFiles.isEmpty {
            indexerLog("No markdown files found - creating empty vault")
            return ObsidianVaultManifest(
                vaultId: vaultId,
                embeddingModel: config.embeddingModel.rawValue,
                noteCount: 0,
                chunkCount: 0,
                embeddingBatchCount: 0,
                notes: []
            )
        }

        // Prepare results
        var allChunks: [DocumentChunk] = []
        var noteMetadata: [ObsidianNoteMetadata] = []
        var chunkStartIndex = 0

        // Phase 2-3: Parse and chunk each note
        for (index, fileURL) in markdownFiles.enumerated() {
            if isCancelled {
                throw LocalObsidianIndexerError.indexingCancelled
            }

            let relativePath = fileURL.path.replacingOccurrences(of: path + "/", with: "")

            progressStream?.yield(ObsidianIndexingProgress(
                phase: .parsing,
                currentNote: fileURL.lastPathComponent,
                notesProcessed: index,
                totalNotes: markdownFiles.count,
                chunksGenerated: allChunks.count,
                estimatedCost: embeddingService?.sessionCost ?? 0
            ))

            // Parse note
            let parsed = try await documentParser.parse(fileURL: fileURL)

            // Generate content hash
            let contentHash = hashContent(parsed.content)

            // Get file modification date
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let modifiedDate = attributes[.modificationDate] as? Date ?? Date()

            // Chunk the content
            progressStream?.yield(ObsidianIndexingProgress(
                phase: .chunking,
                currentNote: fileURL.lastPathComponent,
                notesProcessed: index,
                totalNotes: markdownFiles.count,
                chunksGenerated: allChunks.count,
                estimatedCost: embeddingService?.sessionCost ?? 0
            ))

            let noteId = UUID()
            let chunks = textChunker.chunk(document: parsed, documentId: noteId)

            // Store metadata
            let metadata = ObsidianNoteMetadata(
                id: noteId,
                relativePath: relativePath,
                title: parsed.metadata.title ?? fileURL.deletingPathExtension().lastPathComponent,
                contentHash: contentHash,
                lastModified: modifiedDate,
                chunkCount: chunks.count,
                chunkStartIndex: chunkStartIndex
            )
            noteMetadata.append(metadata)

            allChunks.append(contentsOf: chunks)
            chunkStartIndex += chunks.count
        }

        // Phase 4: Generate embeddings
        if let embeddingService = embeddingService {
            progressStream?.yield(ObsidianIndexingProgress(
                phase: .embedding,
                currentNote: nil,
                notesProcessed: markdownFiles.count,
                totalNotes: markdownFiles.count,
                chunksGenerated: allChunks.count,
                estimatedCost: embeddingService.sessionCost
            ))

            do {
                allChunks = try await embeddingService.embedChunks(allChunks)
            } catch {
                throw ObsidianIndexerError.embeddingFailed(error.localizedDescription)
            }
        }

        // Create manifest
        let manifest = ObsidianVaultManifest(
            vaultId: vaultId,
            embeddingModel: config.embeddingModel.rawValue,
            noteCount: noteMetadata.count,
            chunkCount: allChunks.count,
            embeddingBatchCount: (allChunks.count + 99) / 100,  // 100 chunks per batch
            notes: noteMetadata
        )

        return manifest
    }

    // MARK: - File Scanning

    private func scanForMarkdownFiles(in path: String) throws -> [URL] {
        let fileManager = FileManager.default
        let vaultURL = URL(fileURLWithPath: path)

        indexerLog("Scanning for markdown files in: \(path)")

        var markdownFiles: [URL] = []

        // Enumerator options: skip hidden files and .obsidian folder
        let options: FileManager.DirectoryEnumerationOptions = [
            .skipsHiddenFiles,
            .skipsPackageDescendants
        ]

        guard let enumerator = fileManager.enumerator(
            at: vaultURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: options
        ) else {
            indexerLog("ERROR: Failed to create enumerator for: \(path)")
            return []
        }

        for case let fileURL as URL in enumerator {
            // Skip .obsidian folder
            if fileURL.pathComponents.contains(".obsidian") {
                continue
            }

            // Only process .md files
            if fileURL.pathExtension.lowercased() == "md" {
                // Check if it's a regular file
                let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if resourceValues?.isRegularFile == true {
                    markdownFiles.append(fileURL)
                    indexerLog("Found markdown file: \(fileURL.lastPathComponent)")
                }
            }
        }

        indexerLog("Found \(markdownFiles.count) markdown files")
        return markdownFiles.sorted { $0.path < $1.path }
    }

    // MARK: - Utilities

    private func hashContent(_ content: String) -> String {
        let data = Data(content.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }

    /// Estimate cost for indexing a vault
    func estimateCost(for path: String, config: RAGConfiguration) async throws -> (noteCount: Int, chunkCount: Int, estimatedCost: Double) {
        try validateVault(at: path)

        let markdownFiles = try scanForMarkdownFiles(in: path)
        var totalChunks = 0

        // Sample a few files to estimate average chunks per note
        let sampleSize = min(10, markdownFiles.count)
        var sampleChunkCounts: [Int] = []

        for i in 0..<sampleSize {
            let fileURL = markdownFiles[i]
            let parsed = try await documentParser.parse(fileURL: fileURL)
            let chunks = textChunker.chunk(document: parsed, documentId: UUID())
            sampleChunkCounts.append(chunks.count)
        }

        // Estimate total chunks
        if !sampleChunkCounts.isEmpty {
            let avgChunks = Double(sampleChunkCounts.reduce(0, +)) / Double(sampleChunkCounts.count)
            totalChunks = Int(avgChunks * Double(markdownFiles.count))
        }

        // Estimate embedding cost
        let tokensPerChunk = config.maxChunkTokens
        let totalTokens = totalChunks * tokensPerChunk
        let costPer1M = config.embeddingModel.costPer1MTokens
        let estimatedCost = Double(totalTokens) * costPer1M / 1_000_000

        return (noteCount: markdownFiles.count, chunkCount: totalChunks, estimatedCost: estimatedCost)
    }

    // MARK: - Delta Update

    /// Perform delta update - only re-index changed notes
    /// - Parameters:
    ///   - vault: The vault to update
    ///   - changedPaths: Relative paths of notes that changed
    ///   - vectorStore: The vector store to update
    /// - Returns: AsyncStream of progress updates
    func deltaUpdate(
        vault: ObsidianVault,
        changedPaths: Set<String>,
        vectorStore: ObsidianVectorStore
    ) -> AsyncStream<ObsidianIndexingProgress> {
        AsyncStream { continuation in
            self.progressStream = continuation

            Task {
                do {
                    let fileManager = FileManager.default

                    guard let localPath = vault.localPath else {
                        throw ObsidianIndexerError.vaultNotFound(vault.iCloudPath)
                    }

                    indexerLog("Starting delta update for \(changedPaths.count) changed notes")

                    continuation.yield(ObsidianIndexingProgress(
                        phase: .scanning,
                        currentNote: nil,
                        notesProcessed: 0,
                        totalNotes: changedPaths.count,
                        chunksGenerated: 0,
                        estimatedCost: 0
                    ))

                    // Load existing note metadata from vector store
                    var existingNotes: [String: ObsidianNoteMetadata] = [:]
                    // Note: Would need to add a method to get all notes for a vault
                    // For now, we'll just process all changed paths

                    var updatedNotes: [ObsidianNoteMetadata] = []
                    var allChunks: [DocumentChunk] = []
                    var chunkStartIndex = 0

                    // Process each changed file
                    for (index, relativePath) in changedPaths.enumerated() {
                        if isCancelled {
                            throw LocalObsidianIndexerError.indexingCancelled
                        }

                        let fullPath = (localPath as NSString).appendingPathComponent(relativePath)
                        let fileURL = URL(fileURLWithPath: fullPath)

                        // Check if file still exists
                        guard fileManager.fileExists(atPath: fullPath) else {
                            indexerLog("Skipping deleted file: \(relativePath)")
                            // TODO: Delete from vector store
                            continue
                        }

                        continuation.yield(ObsidianIndexingProgress(
                            phase: .parsing,
                            currentNote: (relativePath as NSString).lastPathComponent,
                            notesProcessed: index,
                            totalNotes: changedPaths.count,
                            chunksGenerated: allChunks.count,
                            estimatedCost: embeddingService?.sessionCost ?? 0
                        ))

                        // Parse note
                        let parsed = try await documentParser.parse(fileURL: fileURL)

                        // Generate content hash
                        let contentHash = hashContent(parsed.content)

                        // Get file modification date
                        let attributes = try fileManager.attributesOfItem(atPath: fullPath)
                        let modifiedDate = attributes[.modificationDate] as? Date ?? Date()

                        // Check if content actually changed (compare hash)
                        if let existingNote = existingNotes[relativePath],
                           existingNote.contentHash == contentHash {
                            indexerLog("Skipping unchanged file: \(relativePath)")
                            continue
                        }

                        // Chunk the content
                        continuation.yield(ObsidianIndexingProgress(
                            phase: .chunking,
                            currentNote: (relativePath as NSString).lastPathComponent,
                            notesProcessed: index,
                            totalNotes: changedPaths.count,
                            chunksGenerated: allChunks.count,
                            estimatedCost: embeddingService?.sessionCost ?? 0
                        ))

                        let noteId = UUID()
                        let chunks = textChunker.chunk(document: parsed, documentId: noteId)

                        // Store metadata
                        let metadata = ObsidianNoteMetadata(
                            id: noteId,
                            relativePath: relativePath,
                            title: parsed.metadata.title ?? fileURL.deletingPathExtension().lastPathComponent,
                            contentHash: contentHash,
                            lastModified: modifiedDate,
                            chunkCount: chunks.count,
                            chunkStartIndex: chunkStartIndex
                        )
                        updatedNotes.append(metadata)

                        allChunks.append(contentsOf: chunks)
                        chunkStartIndex += chunks.count
                    }

                    // Generate embeddings for new chunks
                    if !allChunks.isEmpty, let embeddingService = embeddingService {
                        continuation.yield(ObsidianIndexingProgress(
                            phase: .embedding,
                            currentNote: nil,
                            notesProcessed: changedPaths.count,
                            totalNotes: changedPaths.count,
                            chunksGenerated: allChunks.count,
                            estimatedCost: embeddingService.sessionCost
                        ))

                        do {
                            allChunks = try await embeddingService.embedChunks(allChunks)
                        } catch {
                            throw ObsidianIndexerError.embeddingFailed(error.localizedDescription)
                        }

                        // Store updated notes and chunks in vector store
                        try vectorStore.storeNotes(updatedNotes, vaultId: vault.id)

                        for note in updatedNotes {
                            let noteChunks = allChunks.filter { $0.documentId == note.id }
                            try vectorStore.storeChunks(noteChunks, vaultId: vault.id, noteId: note.id)
                        }
                    }

                    continuation.yield(ObsidianIndexingProgress(
                        phase: .complete,
                        currentNote: nil,
                        notesProcessed: changedPaths.count,
                        totalNotes: changedPaths.count,
                        chunksGenerated: allChunks.count,
                        estimatedCost: embeddingService?.sessionCost ?? 0
                    ))

                    indexerLog("Delta update complete: \(updatedNotes.count) notes updated, \(allChunks.count) chunks")
                    continuation.finish()
                } catch {
                    indexerLog("ERROR: Delta update failed: \(error.localizedDescription)")
                    continuation.finish()
                }
            }
        }
    }
}
