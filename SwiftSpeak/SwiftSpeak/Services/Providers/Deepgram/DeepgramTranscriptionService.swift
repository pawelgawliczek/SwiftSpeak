//
//  DeepgramTranscriptionService.swift
//  SwiftSpeak
//
//  Created by Claude Code on 26/12/2025.
//

import Foundation

/// Deepgram API transcription service
/// Uses raw binary upload (not multipart) for audio files
final class DeepgramTranscriptionService: TranscriptionProvider {

    // MARK: - TranscriptionProvider

    let providerId: AIProvider = .deepgram

    var isConfigured: Bool {
        !apiKey.isEmpty
    }

    var model: String {
        modelName
    }

    // MARK: - Properties

    private let apiKey: String
    private let modelName: String

    /// Base Deepgram API endpoint
    private let baseEndpoint = Constants.API.deepgram

    // MARK: - Initialization

    /// Initialize with API key and optional model
    /// - Parameters:
    ///   - apiKey: Deepgram API key
    ///   - model: Deepgram model to use (default: nova-2)
    ///   - Available models: "nova-2", "nova", "enhanced", "base"
    init(
        apiKey: String,
        model: String = "nova-2"
    ) {
        self.apiKey = apiKey
        self.modelName = model
    }

    /// Initialize from provider configuration
    /// - Parameter config: AI provider configuration
    convenience init?(config: AIProviderConfig) {
        guard config.provider == .deepgram,
              !config.apiKey.isEmpty
        else { return nil }

        let model = config.transcriptionModel ?? "nova-2"
        self.init(apiKey: config.apiKey, model: model)
    }

    // MARK: - Transcription

    func transcribe(audioURL: URL, language: Language?, promptHint: String?) async throws -> String {
        guard isConfigured else {
            throw TranscriptionError.apiKeyMissing
        }

        // Verify file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.audioFileNotFound
        }

        // Check file size (25 MB limit like Whisper)
        let attributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
        guard let fileSize = attributes[.size] as? Int else {
            throw TranscriptionError.invalidAudioFile
        }

        let sizeMB = Double(fileSize) / (1024 * 1024)
        if sizeMB > 25 {
            throw TranscriptionError.fileTooLarge(sizeMB: sizeMB, maxSizeMB: 25)
        }

        // Read audio file data
        let audioData = try Data(contentsOf: audioURL)

        // Build query parameters
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "model", value: modelName),
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "smart_format", value: "true")
        ]

        // Add language if provided
        if let language = language {
            queryItems.append(URLQueryItem(name: "language", value: language.rawValue))
        }

        // Add keywords from promptHint if provided
        // Deepgram uses `keywords` parameter with format: word:boost,word:boost
        // Boost intensifier ranges from -100 to 100 (100 = strongly prefer)
        if let hint = promptHint, !hint.isEmpty {
            let words = hint.components(separatedBy: CharacterSet(charactersIn: ",;. \n"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && $0.count >= 2 }

            if !words.isEmpty {
                // Add each word with high boost (100)
                let keywordsValue = words.map { "\($0):100" }.joined(separator: ",")
                queryItems.append(URLQueryItem(name: "keywords", value: keywordsValue))
            }
        }

        // Build URL with query parameters
        var urlComponents = URLComponents(string: baseEndpoint)!
        urlComponents.queryItems = queryItems
        guard let url = urlComponents.url else {
            throw TranscriptionError.networkError("Invalid URL")
        }

        // Create request with binary upload
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60 // Transcription can take a while

        // Deepgram uses "Token" not "Bearer"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        // Set content type based on file extension
        let mimeType = mimeType(for: audioURL)
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")

        // Set body as raw binary data
        request.httpBody = audioData

        // Execute request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // Check HTTP status
            if let httpResponse = response as? HTTPURLResponse {
                try checkHTTPStatus(httpResponse, data: data)
            }

            // Decode response
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let transcriptionResponse = try decoder.decode(DeepgramResponse.self, from: data)

            // Extract transcript from nested structure
            guard let transcript = transcriptionResponse.results.channels.first?.alternatives.first?.transcript,
                  !transcript.isEmpty else {
                throw TranscriptionError.emptyResponse
            }

            return transcript

        } catch let error as TranscriptionError {
            throw error
        } catch let error as URLError {
            throw mapURLError(error)
        } catch {
            throw TranscriptionError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - API Key Validation

    func validateAPIKey(_ key: String) async -> Bool {
        // Empty keys are invalid
        guard !key.isEmpty else {
            return false
        }

        // Try to make a request to validate the key
        // We'll use a minimal request to the models endpoint
        guard let url = URL(string: "https://api.deepgram.com/v1/models") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Token \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }

    // MARK: - Error Handling

    private func checkHTTPStatus(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200...299:
            return // Success

        case 401:
            throw TranscriptionError.apiKeyInvalid

        case 429:
            // Rate limited - try to get retry-after
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
            let seconds = Int(retryAfter ?? "") ?? 60
            throw TranscriptionError.rateLimited(retryAfterSeconds: seconds)

        case 400...499:
            // Client error - try to parse error message
            if let errorResponse = try? JSONDecoder().decode(DeepgramErrorResponse.self, from: data) {
                throw TranscriptionError.serverError(statusCode: response.statusCode, message: errorResponse.err_msg)
            }
            throw TranscriptionError.serverError(statusCode: response.statusCode, message: nil)

        case 500...599:
            throw TranscriptionError.serverError(statusCode: response.statusCode, message: "Server error")

        default:
            throw TranscriptionError.unexpectedResponse("HTTP \(response.statusCode)")
        }
    }

    private func mapURLError(_ error: URLError) -> TranscriptionError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .networkUnavailable
        case .timedOut:
            return .networkTimeout
        case .cancelled:
            return .cancelled
        default:
            return .networkError(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "m4a":
            return "audio/m4a"
        case "mp3":
            return "audio/mpeg"
        case "wav":
            return "audio/wav"
        case "webm":
            return "audio/webm"
        case "mp4":
            return "audio/mp4"
        case "mpeg", "mpga":
            return "audio/mpeg"
        case "oga", "ogg":
            return "audio/ogg"
        case "flac":
            return "audio/flac"
        default:
            return "application/octet-stream"
        }
    }
}

// MARK: - Response Models

/// Deepgram API response structure
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

/// Deepgram API error response structure
private struct DeepgramErrorResponse: Decodable {
    let err_msg: String?
    let err_code: String?
}
