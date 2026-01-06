//
//  MacObsidianQueryService.swift
//  SwiftSpeakMac
//
//  Query service for searching indexed Obsidian vaults on macOS
//  Uses embeddings + cosine similarity for semantic search
//

import Foundation
import SwiftSpeakCore

/// Service for querying Obsidian vaults on macOS
@MainActor
final class MacObsidianQueryService {

    private let settings: MacSettings
    private let vectorStore: MacObsidianVectorStore
    private var apiKey: String? {
        settings.apiKey(for: .openAI)
    }

    init(settings: MacSettings) {
        self.settings = settings
        self.vectorStore = MacObsidianVectorStore()
    }

    /// Search Obsidian vaults for relevant content
    /// - Parameters:
    ///   - query: Search query text
    ///   - vaultIds: Optional list of vault IDs to search (nil = all indexed vaults)
    ///   - maxResults: Maximum number of results to return
    ///   - minSimilarity: Minimum similarity threshold (0.0-1.0, default 0.3)
    /// - Returns: Array of search results sorted by similarity
    func search(
        query: String,
        vaultIds: [UUID]?,
        maxResults: Int = 5,
        minSimilarity: Float = 0.3
    ) async throws -> [ObsidianSearchResult] {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            macLog("No OpenAI API key for Obsidian search", category: "Obsidian", level: .warning)
            return []
        }

        let searchVaultIds = vaultIds ?? indexedVaultIds
        guard !searchVaultIds.isEmpty else {
            macLog("No indexed vaults to search", category: "Obsidian", level: .warning)
            return []
        }

        macLog("Searching \(searchVaultIds.count) vaults for: \(query.prefix(50))... (minSimilarity: \(Int(minSimilarity * 100))%)", category: "Obsidian")

        // Generate embedding for query
        let queryEmbedding = try await generateEmbedding(text: query, apiKey: apiKey)

        // Search vector store with keyword boosting
        let results = try vectorStore.search(
            query: queryEmbedding,
            queryText: query,  // Pass original text for keyword boosting
            vaultIds: searchVaultIds,
            limit: maxResults,
            minSimilarity: minSimilarity
        )

        macLog("Found \(results.count) results", category: "Obsidian")
        return results
    }

    /// Check if any vaults are configured and indexed
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
    /// - Parameters:
    ///   - vaultIds: List of vault IDs to get notes from
    ///   - maxResults: Maximum number of results to return
    /// - Returns: Array of all notes sorted by title
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

    // MARK: - Private

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
