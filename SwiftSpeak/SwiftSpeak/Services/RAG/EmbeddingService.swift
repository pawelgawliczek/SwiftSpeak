//
//  EmbeddingService.swift
//  SwiftSpeak
//
//  Generates embeddings for document chunks using OpenAI API
//

import Foundation

// MARK: - Embedding Errors

enum EmbeddingError: Error, LocalizedError {
    case apiKeyMissing
    case invalidResponse
    case networkError(Error)
    case apiError(String)
    case batchTooLarge(Int, maxAllowed: Int)
    case emptyInput

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "OpenAI API key is not configured."
        case .invalidResponse:
            return "Invalid response from embedding API."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        case .batchTooLarge(let count, let max):
            return "Batch size (\(count)) exceeds maximum (\(max))."
        case .emptyInput:
            return "Cannot generate embeddings for empty input."
        }
    }
}

// MARK: - Embedding Response Models

private struct EmbeddingRequest: Encodable {
    let input: [String]
    let model: String
    let encodingFormat: String

    enum CodingKeys: String, CodingKey {
        case input
        case model
        case encodingFormat = "encoding_format"
    }
}

private struct EmbeddingResponse: Decodable {
    let object: String
    let data: [EmbeddingData]
    let model: String
    let usage: EmbeddingUsage

    struct EmbeddingData: Decodable {
        let object: String
        let embedding: [Float]
        let index: Int
    }

    struct EmbeddingUsage: Decodable {
        let promptTokens: Int
        let totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

private struct EmbeddingErrorResponse: Decodable {
    let error: APIError

    struct APIError: Decodable {
        let message: String
        let type: String
        let code: String?
    }
}

// MARK: - Embedding Service

@MainActor
final class EmbeddingService {

    // MARK: - Constants

    private static let baseURL = "https://api.openai.com/v1/embeddings"
    private static let maxBatchSize = 100  // OpenAI limit
    private static let maxInputTokens = 8191  // Per input text

    // MARK: - Properties

    private let apiKey: String
    private let model: RAGEmbeddingModel
    private let session: URLSession

    /// Total tokens used in current session (for cost tracking)
    private(set) var totalTokensUsed: Int = 0

    // MARK: - Initialization

    init(apiKey: String, model: RAGEmbeddingModel = .openAISmall) {
        self.apiKey = apiKey
        self.model = model

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    /// Create from provider config
    convenience init?(config: AIProviderConfig) {
        guard config.provider == .openAI, !config.apiKey.isEmpty else {
            return nil
        }
        self.init(apiKey: config.apiKey)
    }

    // MARK: - Public API

    /// Generate embedding for a single text
    func embed(text: String) async throws -> [Float] {
        guard !text.isEmpty else {
            throw EmbeddingError.emptyInput
        }
        guard !apiKey.isEmpty else {
            throw EmbeddingError.apiKeyMissing
        }

        let results = try await embedBatch(texts: [text])
        guard let embedding = results.first else {
            throw EmbeddingError.invalidResponse
        }
        return embedding
    }

    /// Generate embeddings for multiple texts (batched for efficiency)
    func embedBatch(texts: [String]) async throws -> [[Float]] {
        guard !texts.isEmpty else {
            throw EmbeddingError.emptyInput
        }
        guard !apiKey.isEmpty else {
            throw EmbeddingError.apiKeyMissing
        }

        // Split into batches if needed
        if texts.count <= Self.maxBatchSize {
            return try await performEmbeddingRequest(texts: texts)
        }

        // Process in batches
        var allEmbeddings: [[Float]] = []
        let batches = texts.chunked(into: Self.maxBatchSize)

        for batch in batches {
            let batchEmbeddings = try await performEmbeddingRequest(texts: batch)
            allEmbeddings.append(contentsOf: batchEmbeddings)
        }

        return allEmbeddings
    }

    /// Generate embeddings for document chunks
    func embedChunks(_ chunks: [DocumentChunk]) async throws -> [DocumentChunk] {
        let texts = chunks.map { $0.content }
        let embeddings = try await embedBatch(texts: texts)

        return zip(chunks, embeddings).map { chunk, embedding in
            var updated = chunk
            updated.embedding = embedding
            return updated
        }
    }

    // MARK: - Private Methods

    private func performEmbeddingRequest(texts: [String]) async throws -> [[Float]] {
        // Prepare request
        var request = URLRequest(url: URL(string: Self.baseURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = EmbeddingRequest(
            input: texts,
            model: model.rawValue,
            encodingFormat: "float"
        )

        request.httpBody = try JSONEncoder().encode(body)

        // Make request
        let (data, response) = try await session.data(for: request)

        // Check HTTP status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmbeddingError.invalidResponse
        }

        // Handle error responses
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(EmbeddingErrorResponse.self, from: data) {
                throw EmbeddingError.apiError(errorResponse.error.message)
            }
            throw EmbeddingError.apiError("HTTP \(httpResponse.statusCode)")
        }

        // Decode success response
        let embeddingResponse = try JSONDecoder().decode(EmbeddingResponse.self, from: data)

        // Track usage
        totalTokensUsed += embeddingResponse.usage.totalTokens

        // Sort by index to maintain order
        let sortedData = embeddingResponse.data.sorted { $0.index < $1.index }
        return sortedData.map { $0.embedding }
    }

    // MARK: - Utility

    /// Estimated cost for embedding a text
    func estimateCost(text: String) -> Double {
        let tokens = text.count / 4  // Rough estimate
        return Double(tokens) * model.costPer1MTokens / 1_000_000
    }

    /// Estimated cost for embedding multiple texts
    func estimateCost(texts: [String]) -> Double {
        let totalTokens = texts.reduce(0) { $0 + $1.count / 4 }
        return Double(totalTokens) * model.costPer1MTokens / 1_000_000
    }

    /// Current session cost
    var sessionCost: Double {
        Double(totalTokensUsed) * model.costPer1MTokens / 1_000_000
    }

    /// Reset token counter
    func resetTokenCounter() {
        totalTokensUsed = 0
    }
}

// MARK: - Array Extension

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
