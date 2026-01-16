//
//  URLContentFetcher.swift
//  SwiftSpeakCore
//
//  Fetches and extracts text content from web URLs
//  Shared between iOS and macOS
//

import Foundation

// MARK: - URL Fetch Error

public enum URLFetchError: Error, LocalizedError {
    case invalidURL
    case networkError(String)
    case noContent
    case timeout
    case unsupportedContentType(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let message):
            return "Network error: \(message)"
        case .noContent:
            return "No content found at URL"
        case .timeout:
            return "Request timed out"
        case .unsupportedContentType(let type):
            return "Unsupported content type: \(type)"
        }
    }
}

// MARK: - URL Content Fetcher

/// Fetches web content and extracts readable text
/// Works on both iOS and macOS
public final class URLContentFetcher: Sendable {

    private let session: URLSession
    private let htmlExtractor: HTMLTextExtractor
    private let timeoutInterval: TimeInterval

    public init(timeoutInterval: TimeInterval = 30) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        config.timeoutIntervalForResource = timeoutInterval * 2
        self.session = URLSession(configuration: config)
        self.htmlExtractor = HTMLTextExtractor()
        self.timeoutInterval = timeoutInterval
    }

    // MARK: - Public Methods

    /// Fetch content from a URL and extract text
    /// - Parameter url: The URL to fetch
    /// - Returns: Extracted text content and optional title
    public func fetchContent(from url: URL) async throws -> (text: String, title: String?) {
        // Validate URL
        guard url.scheme == "http" || url.scheme == "https" else {
            throw URLFetchError.invalidURL
        }

        // Create request with browser-like headers
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLFetchError.networkError("Invalid response")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw URLFetchError.networkError("HTTP \(httpResponse.statusCode)")
            }

            // Check content type
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""

            if contentType.contains("text/html") || contentType.contains("application/xhtml") {
                return try processHTML(data: data)
            } else if contentType.contains("text/plain") {
                let text = String(data: data, encoding: .utf8) ?? ""
                if text.isEmpty {
                    throw URLFetchError.noContent
                }
                return (text: text, title: nil)
            } else if contentType.contains("application/json") {
                // For JSON, return formatted JSON string
                let text = String(data: data, encoding: .utf8) ?? ""
                if text.isEmpty {
                    throw URLFetchError.noContent
                }
                return (text: text, title: nil)
            } else if contentType.contains("application/pdf") {
                // PDF needs to be handled by PDFTextExtractor
                throw URLFetchError.unsupportedContentType("PDF - use PDFTextExtractor")
            } else {
                // Try to parse as HTML anyway (many servers don't set correct content type)
                return try processHTML(data: data)
            }

        } catch let error as URLFetchError {
            throw error
        } catch let error as URLError {
            if error.code == .timedOut {
                throw URLFetchError.timeout
            }
            throw URLFetchError.networkError(error.localizedDescription)
        } catch {
            throw URLFetchError.networkError(error.localizedDescription)
        }
    }

    /// Fetch content from a URL string
    /// - Parameter urlString: The URL string to fetch
    /// - Returns: Extracted text content and optional title
    public func fetchContent(from urlString: String) async throws -> (text: String, title: String?) {
        guard let url = URL(string: urlString) else {
            throw URLFetchError.invalidURL
        }
        return try await fetchContent(from: url)
    }

    /// Fetch just the text content (convenience method)
    /// - Parameter url: The URL to fetch
    /// - Returns: Extracted text content
    public func fetchText(from url: URL) async throws -> String {
        let (text, _) = try await fetchContent(from: url)
        return text
    }

    // MARK: - Private Methods

    private func processHTML(data: Data) throws -> (text: String, title: String?) {
        // Try different encodings
        var html: String?

        // First try UTF-8
        html = String(data: data, encoding: .utf8)

        // If that fails, try to detect encoding from meta tags
        if html == nil {
            // Try common fallbacks
            html = String(data: data, encoding: .isoLatin1)
                ?? String(data: data, encoding: .windowsCP1252)
        }

        guard let htmlString = html, !htmlString.isEmpty else {
            throw URLFetchError.noContent
        }

        let title = htmlExtractor.extractTitle(from: htmlString)
        let text = htmlExtractor.extractMainContent(from: htmlString)

        if text.isEmpty {
            throw URLFetchError.noContent
        }

        return (text: text, title: title)
    }
}

// MARK: - Static Convenience Methods

public extension URLContentFetcher {
    /// Static convenience method to fetch content from URL
    static func fetchContent(from url: URL) async throws -> (text: String, title: String?) {
        try await URLContentFetcher().fetchContent(from: url)
    }

    /// Static convenience method to fetch content from URL string
    static func fetchContent(from urlString: String) async throws -> (text: String, title: String?) {
        try await URLContentFetcher().fetchContent(from: urlString)
    }

    /// Static convenience method to fetch just text
    static func fetchText(from url: URL) async throws -> String {
        try await URLContentFetcher().fetchText(from: url)
    }
}
