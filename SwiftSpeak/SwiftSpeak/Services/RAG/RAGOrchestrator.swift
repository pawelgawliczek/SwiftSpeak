//
//  RAGOrchestrator.swift
//  SwiftSpeak
//
//  Orchestrates the full RAG pipeline:
//  - Document ingestion (parse, chunk, embed, store)
//  - Query processing (embed query, search, format context)
//  - Document refresh (sync remote documents)
//

import Foundation
import Combine

// MARK: - RAG Orchestrator Errors

enum RAGOrchestratorError: Error, LocalizedError {
    case notConfigured
    case documentIngestionFailed(String)
    case queryFailed(String)
    case noRelevantChunksFound
    case refreshFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "RAG system is not configured. Please add an OpenAI API key."
        case .documentIngestionFailed(let reason):
            return "Failed to ingest document: \(reason)"
        case .queryFailed(let reason):
            return "Query failed: \(reason)"
        case .noRelevantChunksFound:
            return "No relevant content found in knowledge base."
        case .refreshFailed(let reason):
            return "Document refresh failed: \(reason)"
        }
    }
}

// MARK: - Ingestion Progress

struct IngestionProgress {
    let stage: IngestionStage
    let progress: Double  // 0.0 - 1.0
    let message: String

    enum IngestionStage {
        case parsing
        case chunking
        case embedding
        case storing
        case complete
    }
}

// MARK: - Query Result

struct RAGQueryResult {
    let contextText: String
    let chunks: [SimilarityResult]
    let documentNames: [String]
    let tokenEstimate: Int

    /// Format context for injection into LLM prompt
    var formattedContext: String {
        guard !chunks.isEmpty else { return "" }

        var formatted = "## Relevant Knowledge Base Content\n\n"

        for (index, result) in chunks.enumerated() {
            formatted += "### Source \(index + 1): \(result.documentName)\n"
            formatted += result.chunk.content
            formatted += "\n\n"
        }

        return formatted
    }
}

// MARK: - RAG Orchestrator

@MainActor
final class RAGOrchestrator: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isProcessing = false
    @Published private(set) var lastError: Error?
    @Published private(set) var ingestionProgress: IngestionProgress?

    // MARK: - Dependencies

    private let securityManager = RAGSecurityManager.shared
    private let parser = DocumentParser.shared
    private var embeddingService: EmbeddingService?
    private let vectorStore: VectorStore

    // MARK: - Configuration

    private var openAIApiKey: String = ""

    // MARK: - Initialization

    init() {
        self.vectorStore = VectorStore()
    }

    // MARK: - Configuration

    /// Configure with API key
    func configure(openAIApiKey: String) throws {
        self.openAIApiKey = openAIApiKey
        self.embeddingService = EmbeddingService(apiKey: openAIApiKey)
        try vectorStore.open()
    }

    /// Check if RAG is ready
    var isConfigured: Bool {
        !openAIApiKey.isEmpty && embeddingService != nil && vectorStore.isOpen
    }

    // MARK: - Document Ingestion

    /// Ingest a local file into the knowledge base
    func ingestLocalFile(
        at url: URL,
        powerMode: PowerMode,
        progressHandler: ((IngestionProgress) -> Void)? = nil
    ) async throws -> KnowledgeDocument {
        guard isConfigured else {
            throw RAGOrchestratorError.notConfigured
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            // Stage 1: Parse
            updateProgress(.parsing, 0.1, "Parsing document...", handler: progressHandler)
            let parsed = try await parser.parse(fileURL: url)

            // Create document record
            let document = KnowledgeDocument(
                id: UUID(),
                name: url.deletingPathExtension().lastPathComponent,
                type: parser.getFileType(from: url),
                sourceURL: url,
                localPath: url.path,
                contentHash: hashContent(parsed.content),
                chunkCount: 0,  // Will update after chunking
                fileSizeBytes: try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0,
                isIndexed: false,
                lastUpdated: Date()
            )

            // Stage 2: Chunk
            updateProgress(.chunking, 0.3, "Splitting into chunks...", handler: progressHandler)
            let chunker = TextChunker(powerMode: powerMode)
            var chunks = chunker.chunk(document: parsed, documentId: document.id)

            // Stage 3: Embed
            updateProgress(.embedding, 0.5, "Generating embeddings...", handler: progressHandler)
            guard let service = embeddingService else {
                throw RAGOrchestratorError.notConfigured
            }
            chunks = try await service.embedChunks(chunks)

            // Stage 4: Store
            updateProgress(.storing, 0.8, "Storing in knowledge base...", handler: progressHandler)
            try vectorStore.storeDocument(document, powerModeId: powerMode.id)
            try vectorStore.storeChunks(chunks)

            // Update document with final chunk count
            var finalDocument = document
            finalDocument.chunkCount = chunks.count
            finalDocument.isIndexed = true

            updateProgress(.complete, 1.0, "Document added successfully", handler: progressHandler)

            return finalDocument

        } catch {
            lastError = error
            throw RAGOrchestratorError.documentIngestionFailed(error.localizedDescription)
        }
    }

    /// Ingest a remote URL into the knowledge base
    func ingestRemoteURL(
        _ urlString: String,
        powerMode: PowerMode,
        refreshInterval: UpdateInterval = .never,
        progressHandler: ((IngestionProgress) -> Void)? = nil
    ) async throws -> KnowledgeDocument {
        guard isConfigured else {
            throw RAGOrchestratorError.notConfigured
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            // Validate URL
            let url = try securityManager.validateURLString(urlString)

            // Stage 1: Fetch and parse
            updateProgress(.parsing, 0.2, "Fetching remote content...", handler: progressHandler)
            let content = try await fetchRemoteContent(url)
            let parsed = try await parser.parseRemoteContent(content, from: url)

            // Create document record
            var document = KnowledgeDocument(
                id: UUID(),
                name: parsed.metadata.title ?? url.lastPathComponent,
                type: .remoteURL,
                sourceURL: url,
                localPath: nil,
                contentHash: hashContent(parsed.content),
                chunkCount: 0,
                fileSizeBytes: content.utf8.count,
                isIndexed: false,
                lastUpdated: Date(),
                autoUpdateInterval: refreshInterval,
                lastChecked: Date()
            )

            // Stage 2: Chunk
            updateProgress(.chunking, 0.4, "Splitting into chunks...", handler: progressHandler)
            let chunker = TextChunker(powerMode: powerMode)
            var chunks = chunker.chunk(document: parsed, documentId: document.id)

            // Stage 3: Embed
            updateProgress(.embedding, 0.6, "Generating embeddings...", handler: progressHandler)
            guard let service = embeddingService else {
                throw RAGOrchestratorError.notConfigured
            }
            chunks = try await service.embedChunks(chunks)

            // Stage 4: Store
            updateProgress(.storing, 0.85, "Storing in knowledge base...", handler: progressHandler)
            try vectorStore.storeDocument(document, powerModeId: powerMode.id)
            try vectorStore.storeChunks(chunks)

            // Update document
            document.chunkCount = chunks.count
            document.isIndexed = true

            updateProgress(.complete, 1.0, "Remote document added successfully", handler: progressHandler)

            return document

        } catch {
            lastError = error
            throw RAGOrchestratorError.documentIngestionFailed(error.localizedDescription)
        }
    }

    // MARK: - Query

    /// Query the knowledge base for relevant context
    func query(
        _ queryText: String,
        powerMode: PowerMode,
        maxChunks: Int? = nil
    ) async throws -> RAGQueryResult {
        guard isConfigured else {
            throw RAGOrchestratorError.notConfigured
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            // Get query embedding
            guard let service = embeddingService else {
                throw RAGOrchestratorError.notConfigured
            }
            let queryEmbedding = try await service.embed(text: queryText)

            // Search for similar chunks
            let config = powerMode.ragConfiguration
            let limit = maxChunks ?? config.maxContextChunks
            let results = try vectorStore.search(
                queryEmbedding: queryEmbedding,
                documentIds: powerMode.knowledgeDocumentIds.isEmpty ? nil : powerMode.knowledgeDocumentIds,
                limit: limit,
                minSimilarity: config.similarityThreshold
            )

            guard !results.isEmpty else {
                throw RAGOrchestratorError.noRelevantChunksFound
            }

            // Build context
            let contextText = results.map { $0.chunk.content }.joined(separator: "\n\n")
            let documentNames = Array(Set(results.map { $0.documentName }))
            let tokenEstimate = contextText.count / 4

            return RAGQueryResult(
                contextText: contextText,
                chunks: results,
                documentNames: documentNames,
                tokenEstimate: tokenEstimate
            )

        } catch let error as RAGOrchestratorError {
            lastError = error
            throw error
        } catch {
            lastError = error
            throw RAGOrchestratorError.queryFailed(error.localizedDescription)
        }
    }

    // MARK: - Document Management

    /// Delete a document from the knowledge base
    func deleteDocument(_ documentId: UUID) throws {
        try vectorStore.deleteDocument(documentId)
    }

    /// Refresh a remote document
    func refreshDocument(
        _ document: KnowledgeDocument,
        powerMode: PowerMode
    ) async throws -> KnowledgeDocument {
        guard let sourceURL = document.sourceURL,
              document.type == .remoteURL else {
            throw RAGOrchestratorError.refreshFailed("Document is not a remote URL")
        }

        // Fetch latest content
        let content = try await fetchRemoteContent(sourceURL)
        let newHash = hashContent(content)

        // Check if content changed
        if newHash == document.contentHash {
            // No changes, just update last checked
            var updated = document
            updated.lastChecked = Date()
            return updated
        }

        // Content changed - re-ingest
        try vectorStore.deleteChunks(forDocument: document.id)

        let parsed = try await parser.parseRemoteContent(content, from: sourceURL)
        let chunker = TextChunker(powerMode: powerMode)
        var chunks = chunker.chunk(document: parsed, documentId: document.id)
        guard let service = embeddingService else {
            throw RAGOrchestratorError.notConfigured
        }
        chunks = try await service.embedChunks(chunks)
        try vectorStore.storeChunks(chunks)

        var updated = document
        updated.contentHash = newHash
        updated.chunkCount = chunks.count
        updated.lastUpdated = Date()
        updated.lastChecked = Date()

        return updated
    }

    /// Check if any documents need refresh
    func getDocumentsNeedingRefresh(documents: [KnowledgeDocument]) -> [KnowledgeDocument] {
        let now = Date()

        return documents.filter { doc in
            guard doc.type == .remoteURL,
                  let interval = doc.autoUpdateInterval,
                  interval != .never,
                  let lastChecked = doc.lastChecked else {
                return false
            }

            let checkInterval: TimeInterval
            switch interval {
            case .daily:
                checkInterval = 24 * 60 * 60
            case .weekly:
                checkInterval = 7 * 24 * 60 * 60
            case .always:
                checkInterval = 0  // Always refresh
            case .never:
                return false
            }

            return now.timeIntervalSince(lastChecked) >= checkInterval
        }
    }

    // MARK: - Stats

    /// Get total chunks in store
    func getTotalChunkCount() throws -> Int {
        try vectorStore.getTotalChunkCount()
    }

    /// Estimated embedding cost for session
    var sessionEmbeddingCost: Double {
        embeddingService?.sessionCost ?? 0
    }

    // MARK: - Private Helpers

    private func updateProgress(
        _ stage: IngestionProgress.IngestionStage,
        _ progress: Double,
        _ message: String,
        handler: ((IngestionProgress) -> Void)?
    ) {
        let progressUpdate = IngestionProgress(stage: stage, progress: progress, message: message)
        ingestionProgress = progressUpdate
        handler?(progressUpdate)
    }

    private func hashContent(_ content: String) -> String {
        // Simple hash for content change detection
        var hasher = Hasher()
        hasher.combine(content)
        return String(format: "%08x", hasher.finalize())
    }

    private func fetchRemoteContent(_ url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw RAGOrchestratorError.refreshFailed("HTTP request failed")
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw RAGOrchestratorError.refreshFailed("Could not decode content")
        }

        return content
    }
}
