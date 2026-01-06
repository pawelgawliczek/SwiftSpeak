//
//  MacObsidianQueryService.swift
//  SwiftSpeakMac
//
//  Query service for searching Obsidian vaults on macOS
//  Uses Local REST API when available, falls back to embeddings for iOS sync
//

import Foundation
import SwiftSpeakCore

/// Indicates which search method was used
enum ObsidianSearchMethod {
    case api          // Direct Obsidian Local REST API
    case embeddings   // Local embeddings with cosine similarity
}

/// Service for querying Obsidian vaults on macOS
@MainActor
final class MacObsidianQueryService {

    private let settings: MacSettings
    private let vectorStore: MacObsidianVectorStore
    private lazy var apiService: ObsidianAPIService = {
        ObsidianAPIService(config: settings.obsidianAPIConfig)
    }()

    private var apiKey: String? {
        settings.apiKey(for: .openAI)
    }

    /// The method used for the last search
    private(set) var lastSearchMethod: ObsidianSearchMethod = .embeddings

    init(settings: MacSettings) {
        self.settings = settings
        self.vectorStore = MacObsidianVectorStore()
    }

    /// Whether Obsidian API is configured and available
    var isAPIEnabled: Bool {
        settings.obsidianAPIConfig.isConfigured
    }

    /// Test connection to Obsidian API
    func testAPIConnection() async throws -> Bool {
        apiService.updateConfig(settings.obsidianAPIConfig)
        return try await apiService.testConnection()
    }

    /// Search Obsidian vaults for relevant content
    /// Uses API when available, falls back to embeddings
    /// - Parameters:
    ///   - query: Search query text
    ///   - vaultIds: Optional list of vault IDs to search (nil = all indexed vaults)
    ///   - maxResults: Maximum number of results to return
    ///   - minSimilarity: Minimum similarity threshold (0.0-1.0, default 0.3) - only used for embeddings
    /// - Returns: Array of search results sorted by relevance
    func search(
        query: String,
        vaultIds: [UUID]?,
        maxResults: Int = 5,
        minSimilarity: Float = 0.3
    ) async throws -> [ObsidianSearchResult] {

        // Try API first if configured
        if isAPIEnabled {
            do {
                apiService.updateConfig(settings.obsidianAPIConfig)
                macLog("Using Obsidian API for search...", category: "Obsidian")
                let apiResults = try await searchViaAPI(query: query, maxResults: maxResults)
                lastSearchMethod = .api
                macLog("API search returned \(apiResults.count) results", category: "Obsidian")
                return apiResults
            } catch {
                macLog("API search failed, falling back to embeddings: \(error.localizedDescription)", category: "Obsidian", level: .warning)
                // Fall through to embeddings
            }
        } else {
            let reason = !settings.obsidianAPIConfig.isEnabled ? "API disabled in settings" :
                         settings.obsidianAPIConfig.apiKey.isEmpty ? "No API key configured" : "Unknown"
            macLog("Obsidian API not available (\(reason)), using embeddings", category: "Obsidian")
        }

        // Fall back to embeddings
        return try await searchViaEmbeddings(
            query: query,
            vaultIds: vaultIds,
            maxResults: maxResults,
            minSimilarity: minSimilarity
        )
    }

    /// Check if any vaults are configured and indexed (for embeddings)
    var hasIndexedVaults: Bool {
        settings.obsidianVaults.contains { $0.status == .synced }
    }

    /// Get list of indexed vault IDs
    var indexedVaultIds: [UUID] {
        settings.obsidianVaults
            .filter { $0.status == .synced }
            .map { $0.id }
    }

    /// Get all notes from specified vaults (no filtering, for browsing)
    func getAllNotes(
        vaultIds: [UUID],
        maxResults: Int = 50
    ) async throws -> [ObsidianSearchResult] {
        let searchVaultIds = vaultIds.isEmpty ? indexedVaultIds : vaultIds
        guard !searchVaultIds.isEmpty else {
            macLog("No indexed vaults to browse", category: "Obsidian", level: .warning)
            return []
        }

        macLog("Loading all notes from \(searchVaultIds.count) vaults", category: "Obsidian")

        let results = try vectorStore.getAllChunks(
            vaultIds: searchVaultIds,
            limit: maxResults
        )

        macLog("Loaded \(results.count) notes", category: "Obsidian")
        return results
    }

    // MARK: - Note Operations (API only)

    /// Read note content via API
    func readNote(path: String) async throws -> String {
        guard isAPIEnabled else {
            throw ObsidianAPIError.notConfigured
        }
        apiService.updateConfig(settings.obsidianAPIConfig)
        return try await apiService.readNoteMarkdown(path: path)
    }

    /// Create a new note via API
    func createNote(path: String, content: String) async throws {
        guard isAPIEnabled else {
            throw ObsidianAPIError.notConfigured
        }
        apiService.updateConfig(settings.obsidianAPIConfig)
        try await apiService.createNote(path: path, content: content)
    }

    /// Append content to a note via API
    func appendToNote(path: String, content: String) async throws {
        guard isAPIEnabled else {
            throw ObsidianAPIError.notConfigured
        }
        apiService.updateConfig(settings.obsidianAPIConfig)
        try await apiService.appendToNote(path: path, content: content)
    }

    /// Append to today's daily note via API
    func appendToDailyNote(content: String, folder: String = "") async throws {
        guard isAPIEnabled else {
            throw ObsidianAPIError.notConfigured
        }
        apiService.updateConfig(settings.obsidianAPIConfig)
        try await apiService.appendToDailyNote(content: content, folder: folder)
    }

    // MARK: - Private: API Search

    private func searchViaAPI(query: String, maxResults: Int) async throws -> [ObsidianSearchResult] {
        // Search both content and titles in parallel
        async let contentSearchTask = apiService.search(query: query, contextLength: 200)
        async let titleSearchTask = searchTitlesByAPI(query: query)

        let (contentResults, titleResults) = try await (contentSearchTask, titleSearchTask)

        // Merge results: title matches first (higher relevance), then content matches
        var seenPaths = Set<String>()
        var mergedResults: [ObsidianSearchResult] = []

        // Add title matches first (similarity 1.0 = exact title match)
        for result in titleResults {
            if !seenPaths.contains(result.notePath) {
                seenPaths.insert(result.notePath)
                mergedResults.append(result)
            }
        }

        // Add content matches (similarity 0.9 = content match)
        for apiResult in contentResults {
            if !seenPaths.contains(apiResult.filename) {
                seenPaths.insert(apiResult.filename)

                let combinedContent = apiResult.matches
                    .map { $0.context }
                    .joined(separator: "\n...\n")

                mergedResults.append(ObsidianSearchResult(
                    id: UUID(),
                    noteId: UUID(),
                    vaultId: UUID(),
                    vaultName: "Obsidian",
                    notePath: apiResult.filename,
                    noteTitle: apiResult.noteTitle,
                    content: combinedContent.isEmpty ? "No preview available" : combinedContent,
                    similarity: 0.9
                ))
            }
        }

        macLog("API search: \(titleResults.count) title matches, \(contentResults.count) content matches", category: "Obsidian")
        return Array(mergedResults.prefix(maxResults))
    }

    /// Search for notes by title (filename) matching
    private func searchTitlesByAPI(query: String) async throws -> [ObsidianSearchResult] {
        // Get all files from vault
        let allFiles = try await apiService.listFiles()

        // Filter files where title contains query (case-insensitive)
        let queryLower = query.lowercased()
        let queryWords = queryLower.split(separator: " ").map(String.init)

        let matchingFiles = allFiles.filter { filename in
            guard filename.hasSuffix(".md") else { return false }
            let titleLower = filename.lowercased()

            // Match if title contains query or all query words
            return titleLower.contains(queryLower) ||
                   queryWords.allSatisfy { titleLower.contains($0) }
        }

        // Convert to results, fetching preview for each
        var results: [ObsidianSearchResult] = []
        for filename in matchingFiles.prefix(5) { // Limit to 5 title matches
            // Try to get a preview of the note content
            var preview = "Title match"
            if let content = try? await apiService.readNoteMarkdown(path: filename) {
                // Get first ~200 chars as preview, skip frontmatter
                let lines = content.components(separatedBy: "\n")
                var contentLines: [String] = []
                var inFrontmatter = false

                for line in lines {
                    if line == "---" {
                        inFrontmatter = !inFrontmatter
                        continue
                    }
                    if !inFrontmatter && !line.isEmpty {
                        contentLines.append(line)
                        if contentLines.joined(separator: " ").count > 200 {
                            break
                        }
                    }
                }
                preview = contentLines.joined(separator: " ").prefix(200) + "..."
            }

            let noteTitle = (filename as NSString).lastPathComponent
                .replacingOccurrences(of: ".md", with: "")

            results.append(ObsidianSearchResult(
                id: UUID(),
                noteId: UUID(),
                vaultId: UUID(),
                vaultName: "Obsidian",
                notePath: filename,
                noteTitle: noteTitle,
                content: String(preview),
                similarity: 1.0 // Title match = highest relevance
            ))
        }

        return results
    }

    // MARK: - Private: Embeddings Search

    private func searchViaEmbeddings(
        query: String,
        vaultIds: [UUID]?,
        maxResults: Int,
        minSimilarity: Float
    ) async throws -> [ObsidianSearchResult] {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            macLog("No OpenAI API key for Obsidian embedding search", category: "Obsidian", level: .warning)
            return []
        }

        let searchVaultIds = vaultIds ?? indexedVaultIds
        guard !searchVaultIds.isEmpty else {
            macLog("No indexed vaults to search", category: "Obsidian", level: .warning)
            return []
        }

        macLog("Searching \(searchVaultIds.count) vaults via embeddings for: \(query.prefix(50))...", category: "Obsidian")

        // Generate embedding for query
        let queryEmbedding = try await generateEmbedding(text: query, apiKey: apiKey)

        // Search vector store with keyword boosting
        let results = try vectorStore.search(
            query: queryEmbedding,
            queryText: query,
            vaultIds: searchVaultIds,
            limit: maxResults,
            minSimilarity: minSimilarity
        )

        lastSearchMethod = .embeddings
        macLog("Embeddings search found \(results.count) results", category: "Obsidian")
        return results
    }

    private func generateEmbedding(text: String, apiKey: String) async throws -> [Float] {
        let url = URL(string: "https://api.openai.com/v1/embeddings")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "text-embedding-3-small",
            "input": [text]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ObsidianQueryError.queryFailed("Embedding API error")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let first = dataArray.first,
              let embedding = first["embedding"] as? [Double] else {
            throw ObsidianQueryError.queryFailed("Invalid embedding response")
        }

        return embedding.map { Float($0) }
    }
}
