//
//  DeepgramTranscriptionService.swift
//  SwiftSpeakCore
//
//  Shared Deepgram transcription service
//

import Foundation

/// Deepgram API transcription service
public final class DeepgramTranscriptionService: TranscriptionProvider {

    public let providerId: AIProvider = .deepgram

    public var isConfigured: Bool {
        !apiKey.isEmpty
    }

    public var model: String {
        modelName
    }

    private let apiKey: String
    private let modelName: String
    private let baseEndpoint = Constants.API.deepgram

    public init(apiKey: String, model: String = "nova-2") {
        self.apiKey = apiKey
        self.modelName = model
    }

    public convenience init?(config: AIProviderConfig) {
        guard config.provider == .deepgram, !config.apiKey.isEmpty else { return nil }
        self.init(apiKey: config.apiKey, model: config.transcriptionModel ?? "nova-2")
    }

    public func transcribe(audioURL: URL, language: Language?, promptHint: String?) async throws -> String {
        guard isConfigured else { throw TranscriptionError.apiKeyMissing }
        guard FileManager.default.fileExists(atPath: audioURL.path) else { throw TranscriptionError.audioFileNotFound }

        let audioData = try Data(contentsOf: audioURL)

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "model", value: modelName),
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "smart_format", value: "true"),
            URLQueryItem(name: "paragraphs", value: "true"),       // Add paragraph breaks
            URLQueryItem(name: "filler_words", value: "false")     // Remove "um", "uh", etc.
        ]

        if let language = language {
            queryItems.append(URLQueryItem(name: "language", value: language.rawValue))
        }

        if let hint = promptHint, !hint.isEmpty {
            let words = hint.components(separatedBy: CharacterSet(charactersIn: ",;. \n"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && $0.count >= 2 }
            if !words.isEmpty {
                let keywordsValue = words.map { "\($0):100" }.joined(separator: ",")
                queryItems.append(URLQueryItem(name: "keywords", value: keywordsValue))
            }
        }

        var urlComponents = URLComponents(string: baseEndpoint)!
        urlComponents.queryItems = queryItems
        guard let url = urlComponents.url else { throw TranscriptionError.networkError("Invalid URL") }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(mimeType(for: audioURL), forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
            throw TranscriptionError.serverError(statusCode: statusCode, message: nil)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let transcriptionResponse = try decoder.decode(DeepgramResponse.self, from: data)

        guard let transcript = transcriptionResponse.results.channels.first?.alternatives.first?.transcript, !transcript.isEmpty else {
            throw TranscriptionError.emptyResponse
        }

        return transcript
    }

    public func validateAPIKey(_ key: String) async -> Bool {
        guard !key.isEmpty, let url = URL(string: "https://api.deepgram.com/v1/models") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Token \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch { return false }
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "m4a": return "audio/m4a"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "webm": return "audio/webm"
        case "mp4": return "audio/mp4"
        case "ogg", "oga": return "audio/ogg"
        case "flac": return "audio/flac"
        default: return "application/octet-stream"
        }
    }
}

private struct DeepgramResponse: Decodable {
    let results: DeepgramResults
}

private struct DeepgramResults: Decodable {
    let channels: [DeepgramChannel]
}

private struct DeepgramChannel: Decodable {
    let alternatives: [DeepgramAlternative]
}

private struct DeepgramAlternative: Decodable {
    let transcript: String
}
