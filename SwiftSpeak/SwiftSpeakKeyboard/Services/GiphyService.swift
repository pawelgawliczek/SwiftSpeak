//
//  GiphyService.swift
//  SwiftSpeakKeyboard
//
//  Phase 13.9: GIF search service using Giphy API
//

import Foundation

actor GiphyService {
    private let apiKey: String
    private let baseURL = "https://api.giphy.com/v1/gifs"

    // Default Giphy SDK API key (free tier, requires "Powered by Giphy" attribution)
    // Register at developers.giphy.com for production key with higher limits
    private static let defaultApiKey = "GZM6IIqgsLPanQfv4QSPrB36GYpXVbPZ"

    init() {
        // Use user's custom key if provided, otherwise fall back to default
        let customKey = UserDefaults(suiteName: "group.pawelgawliczek.swiftspeak")?.string(forKey: "giphyApiKey")
        self.apiKey = (customKey?.isEmpty == false) ? customKey! : Self.defaultApiKey
    }

    /// Check if service is configured (always true now with default key)
    var isConfigured: Bool { !apiKey.isEmpty }

    struct GiphyResponse: Codable {
        let data: [GiphyGif]
    }

    struct GiphyGif: Codable, Identifiable {
        let id: String
        let title: String
        let images: GiphyImages
    }

    struct GiphyImages: Codable {
        let fixedWidthSmall: GiphyImage
        let original: GiphyImage

        enum CodingKeys: String, CodingKey {
            case fixedWidthSmall = "fixed_width_small"
            case original
        }
    }

    struct GiphyImage: Codable {
        let url: String
        let width: String
        let height: String
    }

    func search(_ query: String) async throws -> [GiphyGif] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search?api_key=\(apiKey)&q=\(encodedQuery)&limit=20&rating=g") else {
            throw GiphyError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(GiphyResponse.self, from: data)
        return response.data
    }

    func trending() async throws -> [GiphyGif] {
        guard let url = URL(string: "\(baseURL)/trending?api_key=\(apiKey)&limit=20&rating=g") else {
            throw GiphyError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(GiphyResponse.self, from: data)
        return response.data
    }

    enum GiphyError: Error {
        case invalidURL
        case networkError
    }
}
