//
//  ObsidianAPIService.swift
//  SwiftSpeakMac
//
//  Service for interacting with Obsidian via Local REST API plugin
//  https://github.com/coddingtonbear/obsidian-local-rest-api
//

import Foundation
import SwiftSpeakCore

// MARK: - Obsidian API Configuration

struct ObsidianAPIConfig: Codable, Equatable {
    var isEnabled: Bool = false
    var port: Int = 27123
    var apiKey: String = ""
    var useHTTPS: Bool = true

    var baseURL: URL? {
        let scheme = useHTTPS ? "https" : "http"
        return URL(string: "\(scheme)://127.0.0.1:\(port)")
    }

    var isConfigured: Bool {
        isEnabled && !apiKey.isEmpty
    }
}

// MARK: - API Response Types

/// Raw search result from Obsidian Local REST API
struct ObsidianAPISearchResult: Codable, Identifiable {
    let filename: String
    let matches: [ObsidianAPISearchMatch]

    var id: String { filename }

    /// Extract note title from filename (remove .md extension and path)
    var noteTitle: String {
        let name = (filename as NSString).lastPathComponent
        if name.hasSuffix(".md") {
            return String(name.dropLast(3))
        }
        return name
    }
}

struct ObsidianAPISearchMatch: Codable {
    let match: ObsidianAPIMatchPosition
    let context: String
}

struct ObsidianAPIMatchPosition: Codable {
    let start: Int
    let end: Int
}

struct ObsidianNoteContent: Codable {
    let content: String
    let tags: [String]?
    let frontmatter: [String: AnyCodable]?
    let path: String?
}

// MARK: - API Errors

enum ObsidianAPIError: Error, LocalizedError {
    case notConfigured
    case connectionFailed(String)
    case authenticationFailed
    case notFound(String)
    case serverError(Int, String)
    case invalidResponse
    case obsidianNotRunning

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Obsidian API is not configured. Please set up the Local REST API plugin."
        case .connectionFailed(let message):
            return "Failed to connect to Obsidian: \(message)"
        case .authenticationFailed:
            return "Invalid API key. Check your Obsidian Local REST API settings."
        case .notFound(let path):
            return "Note not found: \(path)"
        case .serverError(let code, let message):
            return "Obsidian API error (\(code)): \(message)"
        case .invalidResponse:
            return "Invalid response from Obsidian API"
        case .obsidianNotRunning:
            return "Obsidian is not running or the Local REST API plugin is not enabled."
        }
    }
}

// MARK: - Obsidian API Service

@MainActor
final class ObsidianAPIService {

    private let session: URLSession
    private var config: ObsidianAPIConfig

    init(config: ObsidianAPIConfig = ObsidianAPIConfig()) {
        self.config = config

        // Create session that trusts the self-signed certificate
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 10
        sessionConfig.timeoutIntervalForResource = 30

        // For local connections, we need to handle self-signed certs
        self.session = URLSession(
            configuration: sessionConfig,
            delegate: LocalhostTrustDelegate(),
            delegateQueue: nil
        )
    }

    /// Update configuration
    func updateConfig(_ newConfig: ObsidianAPIConfig) {
        self.config = newConfig
    }

    // MARK: - Connection Test

    /// Test connection to Obsidian API
    func testConnection() async throws -> Bool {
        guard config.isConfigured, let baseURL = config.baseURL else {
            throw ObsidianAPIError.notConfigured
        }

        let url = baseURL.appendingPathComponent("/")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ObsidianAPIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                macLog("Obsidian API connection successful", category: "ObsidianAPI")
                return true
            case 401, 403:
                throw ObsidianAPIError.authenticationFailed
            default:
                throw ObsidianAPIError.serverError(httpResponse.statusCode, "Connection test failed")
            }
        } catch let error as ObsidianAPIError {
            throw error
        } catch {
            throw ObsidianAPIError.obsidianNotRunning
        }
    }

    // MARK: - Search

    /// Simple text search across the vault
    /// - Parameters:
    ///   - query: Search query text
    ///   - contextLength: Number of characters of context around each match (default 100)
    /// - Returns: Array of search results with matching notes and context
    func search(query: String, contextLength: Int = 100) async throws -> [ObsidianAPISearchResult] {
        guard config.isConfigured, let baseURL = config.baseURL else {
            throw ObsidianAPIError.notConfigured
        }

        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("/search/simple/"), resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "contextLength", value: String(contextLength))
        ]

        guard let url = urlComponents.url else {
            throw ObsidianAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        macLog("Searching Obsidian for: \(query)", category: "ObsidianAPI")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ObsidianAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let results = try JSONDecoder().decode([ObsidianAPISearchResult].self, from: data)
            macLog("Found \(results.count) results", category: "ObsidianAPI")
            return results
        case 401, 403:
            throw ObsidianAPIError.authenticationFailed
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ObsidianAPIError.serverError(httpResponse.statusCode, message)
        }
    }

    // MARK: - Read Note

    /// Read the content of a note
    /// - Parameter path: Path to the note relative to vault root (e.g., "folder/note.md")
    /// - Returns: Note content and metadata
    func readNote(path: String) async throws -> ObsidianNoteContent {
        guard config.isConfigured, let baseURL = config.baseURL else {
            throw ObsidianAPIError.notConfigured
        }

        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let url = baseURL.appendingPathComponent("/vault/\(encodedPath)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.olrapi.note+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ObsidianAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode(ObsidianNoteContent.self, from: data)
        case 401, 403:
            throw ObsidianAPIError.authenticationFailed
        case 404:
            throw ObsidianAPIError.notFound(path)
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ObsidianAPIError.serverError(httpResponse.statusCode, message)
        }
    }

    /// Read raw markdown content of a note
    func readNoteMarkdown(path: String) async throws -> String {
        guard config.isConfigured, let baseURL = config.baseURL else {
            throw ObsidianAPIError.notConfigured
        }

        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let url = baseURL.appendingPathComponent("/vault/\(encodedPath)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("text/markdown", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ObsidianAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return String(data: data, encoding: .utf8) ?? ""
        case 401, 403:
            throw ObsidianAPIError.authenticationFailed
        case 404:
            throw ObsidianAPIError.notFound(path)
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ObsidianAPIError.serverError(httpResponse.statusCode, message)
        }
    }

    // MARK: - Create/Write Note

    /// Create a new note or replace existing content
    /// - Parameters:
    ///   - path: Path for the note relative to vault root
    ///   - content: Markdown content
    func createNote(path: String, content: String) async throws {
        guard config.isConfigured, let baseURL = config.baseURL else {
            throw ObsidianAPIError.notConfigured
        }

        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let url = baseURL.appendingPathComponent("/vault/\(encodedPath)")

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("text/markdown", forHTTPHeaderField: "Content-Type")
        request.httpBody = content.data(using: .utf8)

        macLog("Creating note: \(path)", category: "ObsidianAPI")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ObsidianAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200, 201, 204:
            macLog("Note created successfully", category: "ObsidianAPI")
            return
        case 401, 403:
            throw ObsidianAPIError.authenticationFailed
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ObsidianAPIError.serverError(httpResponse.statusCode, message)
        }
    }

    /// Append content to an existing note (or create if doesn't exist)
    /// - Parameters:
    ///   - path: Path for the note relative to vault root
    ///   - content: Content to append
    func appendToNote(path: String, content: String) async throws {
        guard config.isConfigured, let baseURL = config.baseURL else {
            throw ObsidianAPIError.notConfigured
        }

        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let url = baseURL.appendingPathComponent("/vault/\(encodedPath)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("text/markdown", forHTTPHeaderField: "Content-Type")
        request.httpBody = content.data(using: .utf8)

        macLog("Appending to note: \(path)", category: "ObsidianAPI")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ObsidianAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200, 201, 204:
            macLog("Content appended successfully", category: "ObsidianAPI")
            return
        case 401, 403:
            throw ObsidianAPIError.authenticationFailed
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ObsidianAPIError.serverError(httpResponse.statusCode, message)
        }
    }

    // MARK: - Daily Note

    /// Append content to today's daily note
    /// Uses standard daily note format: YYYY-MM-DD.md
    func appendToDailyNote(content: String, folder: String = "") async throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let filename = dateFormatter.string(from: Date()) + ".md"

        let path = folder.isEmpty ? filename : "\(folder)/\(filename)"
        try await appendToNote(path: path, content: content)
    }

    // MARK: - List Files

    /// List files in a directory
    /// - Parameter path: Path relative to vault root (empty for root)
    /// - Returns: Array of file/folder names
    func listFiles(path: String = "") async throws -> [String] {
        guard config.isConfigured, let baseURL = config.baseURL else {
            throw ObsidianAPIError.notConfigured
        }

        let urlPath = path.isEmpty ? "/vault/" : "/vault/\(path)/"
        let encodedPath = urlPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? urlPath
        let url = baseURL.appendingPathComponent(encodedPath)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ObsidianAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            struct FileListResponse: Codable {
                let files: [String]
            }
            let result = try JSONDecoder().decode(FileListResponse.self, from: data)
            return result.files
        case 401, 403:
            throw ObsidianAPIError.authenticationFailed
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ObsidianAPIError.serverError(httpResponse.statusCode, message)
        }
    }
}

// MARK: - SSL Trust Delegate for Localhost

/// Delegate that trusts self-signed certificates for localhost connections
private class LocalhostTrustDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Only trust for localhost
        guard challenge.protectionSpace.host == "127.0.0.1" || challenge.protectionSpace.host == "localhost" else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Trust the server's certificate for localhost
        if let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

// MARK: - AnyCodable for Frontmatter

/// Type-erased Codable wrapper for handling dynamic frontmatter
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        default:
            try container.encodeNil()
        }
    }
}
