//
//  RAGOrchestratorTests.swift
//  SwiftSpeakTests
//
//  Tests for RAGOrchestrator - Document ingestion and query coordination
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

// MARK: - Error Type Tests

@Suite("RAGOrchestrator - Errors")
struct RAGOrchestratorErrorTests {

    @Test("Not configured error has description")
    func notConfiguredError() {
        let error = RAGOrchestratorError.notConfigured
        #expect(error.errorDescription?.contains("not configured") == true)
    }

    @Test("Document ingestion failed error includes reason")
    func documentIngestionFailedError() {
        let error = RAGOrchestratorError.documentIngestionFailed("File not found")
        #expect(error.errorDescription?.contains("File not found") == true)
    }

    @Test("Query failed error includes reason")
    func queryFailedError() {
        let error = RAGOrchestratorError.queryFailed("Invalid embedding")
        #expect(error.errorDescription?.contains("Invalid embedding") == true)
    }

    @Test("No relevant chunks error has description")
    func noRelevantChunksError() {
        let error = RAGOrchestratorError.noRelevantChunksFound
        #expect(error.errorDescription?.contains("No relevant content") == true)
    }

    @Test("Refresh failed error includes reason")
    func refreshFailedError() {
        let error = RAGOrchestratorError.refreshFailed("Network timeout")
        #expect(error.errorDescription?.contains("Network timeout") == true)
    }
}

// MARK: - Ingestion Progress Tests

@Suite("RAGOrchestrator - Ingestion Progress")
struct RAGOrchestratorProgressTests {

    @Test("Creates parsing progress")
    func createsParsingProgress() {
        let progress = IngestionProgress(
            stage: .parsing,
            progress: 0.1,
            message: "Parsing document..."
        )

        #expect(progress.progress == 0.1)
        #expect(progress.message == "Parsing document...")
    }

    @Test("Creates chunking progress")
    func createsChunkingProgress() {
        let progress = IngestionProgress(
            stage: .chunking,
            progress: 0.3,
            message: "Splitting into chunks..."
        )

        #expect(progress.progress == 0.3)
    }

    @Test("Creates embedding progress")
    func createsEmbeddingProgress() {
        let progress = IngestionProgress(
            stage: .embedding,
            progress: 0.5,
            message: "Generating embeddings..."
        )

        #expect(progress.progress == 0.5)
    }

    @Test("Creates storing progress")
    func createsStoringProgress() {
        let progress = IngestionProgress(
            stage: .storing,
            progress: 0.8,
            message: "Storing in knowledge base..."
        )

        #expect(progress.progress == 0.8)
    }

    @Test("Creates complete progress")
    func createsCompleteProgress() {
        let progress = IngestionProgress(
            stage: .complete,
            progress: 1.0,
            message: "Done"
        )

        #expect(progress.progress == 1.0)
    }
}

// MARK: - Query Result Tests

@Suite("RAGOrchestrator - Query Result")
struct RAGOrchestratorQueryResultTests {

    @Test("Formats context correctly")
    func formatsContextCorrectly() {
        let documentId = UUID()
        let chunk = DocumentChunk(
            documentId: documentId,
            index: 0,
            content: "This is test content about Swift programming.",
            startOffset: 0,
            endOffset: 46
        )

        let similarityResult = SimilarityResult(
            id: chunk.id,
            chunk: chunk,
            score: 0.95,
            documentName: "Swift Guide"
        )

        let result = RAGQueryResult(
            contextText: "This is test content about Swift programming.",
            chunks: [similarityResult],
            documentNames: ["Swift Guide"],
            tokenEstimate: 11
        )

        #expect(result.formattedContext.contains("Relevant Knowledge Base Content"))
        #expect(result.formattedContext.contains("Swift Guide"))
        #expect(result.formattedContext.contains("This is test content"))
    }

    @Test("Empty chunks returns empty formatted context")
    func emptyChunksReturnsEmptyContext() {
        let result = RAGQueryResult(
            contextText: "",
            chunks: [],
            documentNames: [],
            tokenEstimate: 0
        )

        #expect(result.formattedContext.isEmpty)
    }

    @Test("Multiple chunks formatted with source numbers")
    func multipleChunksFormattedWithSourceNumbers() {
        let documentId = UUID()
        let chunk1 = DocumentChunk(
            documentId: documentId,
            index: 0,
            content: "First chunk content",
            startOffset: 0,
            endOffset: 19
        )
        let chunk2 = DocumentChunk(
            documentId: documentId,
            index: 1,
            content: "Second chunk content",
            startOffset: 20,
            endOffset: 40
        )

        let results = [
            SimilarityResult(id: chunk1.id, chunk: chunk1, score: 0.9, documentName: "Doc 1"),
            SimilarityResult(id: chunk2.id, chunk: chunk2, score: 0.8, documentName: "Doc 2")
        ]

        let result = RAGQueryResult(
            contextText: "First\nSecond",
            chunks: results,
            documentNames: ["Doc 1", "Doc 2"],
            tokenEstimate: 10
        )

        #expect(result.formattedContext.contains("Source 1"))
        #expect(result.formattedContext.contains("Source 2"))
        #expect(result.formattedContext.contains("Doc 1"))
        #expect(result.formattedContext.contains("Doc 2"))
    }
}

// MARK: - Document Refresh Logic Tests

@Suite("RAGOrchestrator - Document Refresh")
struct RAGOrchestratorRefreshTests {

    @Test("Daily documents needing refresh")
    @MainActor
    func dailyDocumentsNeedingRefresh() async throws {
        let orchestrator = RAGOrchestrator()

        // Document checked 2 days ago with daily interval
        let oldDocument = KnowledgeDocument(
            name: "Old Doc",
            type: .remoteURL,
            sourceURL: URL(string: "https://example.com/doc"),
            autoUpdateInterval: .daily,
            lastChecked: Date(timeIntervalSinceNow: -48 * 60 * 60)  // 2 days ago
        )

        // Document checked 1 hour ago with daily interval
        let recentDocument = KnowledgeDocument(
            name: "Recent Doc",
            type: .remoteURL,
            sourceURL: URL(string: "https://example.com/recent"),
            autoUpdateInterval: .daily,
            lastChecked: Date(timeIntervalSinceNow: -60 * 60)  // 1 hour ago
        )

        let needsRefresh = orchestrator.getDocumentsNeedingRefresh(documents: [oldDocument, recentDocument])

        #expect(needsRefresh.count == 1)
        #expect(needsRefresh.first?.name == "Old Doc")
    }

    @Test("Weekly documents needing refresh")
    @MainActor
    func weeklyDocumentsNeedingRefresh() async throws {
        let orchestrator = RAGOrchestrator()

        // Document checked 8 days ago with weekly interval
        let oldDocument = KnowledgeDocument(
            name: "Old Weekly",
            type: .remoteURL,
            sourceURL: URL(string: "https://example.com/weekly"),
            autoUpdateInterval: .weekly,
            lastChecked: Date(timeIntervalSinceNow: -8 * 24 * 60 * 60)
        )

        let needsRefresh = orchestrator.getDocumentsNeedingRefresh(documents: [oldDocument])

        #expect(needsRefresh.count == 1)
    }

    @Test("Never interval documents not included")
    @MainActor
    func neverIntervalNotIncluded() async throws {
        let orchestrator = RAGOrchestrator()

        let document = KnowledgeDocument(
            name: "Static Doc",
            type: .remoteURL,
            sourceURL: URL(string: "https://example.com/static"),
            autoUpdateInterval: .never,
            lastChecked: Date(timeIntervalSinceNow: -365 * 24 * 60 * 60)  // 1 year ago
        )

        let needsRefresh = orchestrator.getDocumentsNeedingRefresh(documents: [document])

        #expect(needsRefresh.isEmpty)
    }

    @Test("Local files not included in refresh")
    @MainActor
    func localFilesNotIncluded() async throws {
        let orchestrator = RAGOrchestrator()

        let localDocument = KnowledgeDocument(
            name: "Local File",
            type: .localFile,
            localPath: "/path/to/file.txt"
        )

        let needsRefresh = orchestrator.getDocumentsNeedingRefresh(documents: [localDocument])

        #expect(needsRefresh.isEmpty)
    }

    @Test("Always interval documents always included")
    @MainActor
    func alwaysIntervalAlwaysIncluded() async throws {
        let orchestrator = RAGOrchestrator()

        let document = KnowledgeDocument(
            name: "Always Refresh",
            type: .remoteURL,
            sourceURL: URL(string: "https://example.com/live"),
            autoUpdateInterval: .always,
            lastChecked: Date()  // Just checked
        )

        let needsRefresh = orchestrator.getDocumentsNeedingRefresh(documents: [document])

        #expect(needsRefresh.count == 1)
    }
}

// MARK: - Configuration Tests

@Suite("RAGOrchestrator - Configuration")
struct RAGOrchestratorConfigTests {

    @Test("Not configured by default")
    @MainActor
    func notConfiguredByDefault() async throws {
        let orchestrator = RAGOrchestrator()
        #expect(orchestrator.isConfigured == false)
    }

    @Test("Not processing by default")
    @MainActor
    func notProcessingByDefault() async throws {
        let orchestrator = RAGOrchestrator()
        #expect(orchestrator.isProcessing == false)
    }

    @Test("No last error by default")
    @MainActor
    func noLastErrorByDefault() async throws {
        let orchestrator = RAGOrchestrator()
        #expect(orchestrator.lastError == nil)
    }

    @Test("No ingestion progress by default")
    @MainActor
    func noIngestionProgressByDefault() async throws {
        let orchestrator = RAGOrchestrator()
        #expect(orchestrator.ingestionProgress == nil)
    }
}

// MARK: - Unconfigured Error Tests

@Suite("RAGOrchestrator - Unconfigured Operations")
struct RAGOrchestratorUnconfiguredTests {

    @Test("Query throws when not configured")
    @MainActor
    func queryThrowsWhenNotConfigured() async throws {
        let orchestrator = RAGOrchestrator()
        let powerMode = PowerMode(
            name: "Test",
            icon: "bolt",
            iconColor: .orange,
            iconBackgroundColor: .orange,
            instruction: "Test",
            outputFormat: "Test"
        )

        await #expect(throws: RAGOrchestratorError.self) {
            _ = try await orchestrator.query("test query", powerMode: powerMode)
        }
    }

    @Test("Ingest local file throws when not configured")
    @MainActor
    func ingestLocalThrowsWhenNotConfigured() async throws {
        let orchestrator = RAGOrchestrator()
        let powerMode = PowerMode(
            name: "Test",
            icon: "bolt",
            iconColor: .orange,
            iconBackgroundColor: .orange,
            instruction: "Test",
            outputFormat: "Test"
        )

        let tempURL = URL(fileURLWithPath: "/tmp/test.txt")

        await #expect(throws: RAGOrchestratorError.self) {
            _ = try await orchestrator.ingestLocalFile(at: tempURL, powerMode: powerMode)
        }
    }

    @Test("Ingest remote URL throws when not configured")
    @MainActor
    func ingestRemoteThrowsWhenNotConfigured() async throws {
        let orchestrator = RAGOrchestrator()
        let powerMode = PowerMode(
            name: "Test",
            icon: "bolt",
            iconColor: .orange,
            iconBackgroundColor: .orange,
            instruction: "Test",
            outputFormat: "Test"
        )

        await #expect(throws: RAGOrchestratorError.self) {
            _ = try await orchestrator.ingestRemoteURL("https://example.com", powerMode: powerMode)
        }
    }
}

// MARK: - Session Cost Tests

@Suite("RAGOrchestrator - Costs")
struct RAGOrchestratorCostTests {

    @Test("Session cost is zero when not configured")
    @MainActor
    func sessionCostZeroWhenNotConfigured() async throws {
        let orchestrator = RAGOrchestrator()
        #expect(orchestrator.sessionEmbeddingCost == 0)
    }
}
