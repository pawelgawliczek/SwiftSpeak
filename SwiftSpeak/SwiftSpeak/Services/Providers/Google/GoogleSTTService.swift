//
//  GoogleSTTService.swift
//  SwiftSpeak
//
//  Created by Claude Code on 26/12/2025.
//

import Foundation

/// Google Cloud Speech-to-Text API v2 transcription service
final class GoogleSTTService: TranscriptionProvider {

    // MARK: - TranscriptionProvider

    let providerId: AIProvider = .google

    var isConfigured: Bool {
        !apiKey.isEmpty && !projectId.isEmpty
    }

    var model: String {
        modelName
    }

    // MARK: - Properties

    private let apiKey: String
    private let projectId: String
    private let modelName: String
    private let apiClient: APIClient

    /// Google Cloud Speech-to-Text v2 endpoint base
    private var endpoint: URL {
        URL(string: "\(Constants.API.googleSTT)/\(projectId)/locations/global/recognizers/_:recognize")!
    }

    // MARK: - Initialization

    /// Initialize with API key, project ID, and optional model
    /// - Parameters:
    ///   - apiKey: Google Cloud API key
    ///   - projectId: Google Cloud project ID
    ///   - model: Recognition model to use (default: long)
    ///   - apiClient: API client instance
    init(
        apiKey: String,
        projectId: String,
        model: String = "long",
        apiClient: APIClient = .shared
    ) {
        self.apiKey = apiKey
        self.projectId = projectId
        self.modelName = model
        self.apiClient = apiClient
    }

    /// Initialize from provider configuration
    /// - Parameter config: AI provider configuration
    convenience init?(config: AIProviderConfig) {
        guard config.provider == .google,
              !config.apiKey.isEmpty,
              let projectId = config.googleProjectId,
              !projectId.isEmpty
        else { return nil }

        let model = config.transcriptionModel ?? "long"
        self.init(apiKey: config.apiKey, projectId: projectId, model: model)
    }

    // MARK: - Transcription

    func transcribe(audioURL: URL, language: Language?) async throws -> String {
        guard isConfigured else {
            throw TranscriptionError.providerNotConfigured
        }

        // Verify file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.audioFileNotFound
        }

        // Read and base64 encode audio file
        let audioData: Data
        do {
            audioData = try Data(contentsOf: audioURL)
        } catch {
            throw TranscriptionError.invalidAudioFile
        }

        let base64Audio = audioData.base64EncodedString()

        // Build request body
        let requestBody = GoogleSTTRequest(
            config: GoogleSTTConfig(
                languageCodes: [language?.googleSTTCode ?? "en-US"],
                model: modelName,
                autoDecodingConfig: GoogleSTTAutoDecodingConfig()
            ),
            content: base64Audio
        )

        // Send request
        let response: GoogleSTTResponse = try await apiClient.post(
            url: endpoint,
            body: requestBody,
            headers: [
                "x-goog-api-key": apiKey,
                "Content-Type": "application/json"
            ],
            timeout: 60 // Transcription can take a while
        )

        // Extract transcript from results
        guard let results = response.results, !results.isEmpty else {
            throw TranscriptionError.emptyResponse
        }

        // Concatenate all transcripts (there may be multiple segments)
        let transcripts = results.compactMap { result in
            result.alternatives?.first?.transcript
        }

        guard !transcripts.isEmpty else {
            throw TranscriptionError.emptyResponse
        }

        // Join with spaces
        let fullTranscript = transcripts.joined(separator: " ")

        return fullTranscript
    }

    // MARK: - API Key Validation

    func validateAPIKey(_ key: String) async -> Bool {
        // For Google Cloud, we need both API key AND project ID to validate
        // We'll do a minimal STT request with a tiny audio sample

        // Create a minimal silent audio sample (base64 encoded)
        // This is a 1-second silent WAV file (44 bytes header + minimal data)
        let silentAudioBase64 = "UklGRiQAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQAAAAA="

        guard let testURL = URL(string: "\(Constants.API.googleSTT)/\(projectId)/locations/global/recognizers/_:recognize") else {
            return false
        }

        let requestBody = GoogleSTTRequest(
            config: GoogleSTTConfig(
                languageCodes: ["en-US"],
                model: "long",
                autoDecodingConfig: GoogleSTTAutoDecodingConfig()
            ),
            content: silentAudioBase64
        )

        var request = URLRequest(url: testURL)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(requestBody)

            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                // 200 = success, 400 = valid key but bad request (still means key works)
                return httpResponse.statusCode == 200 || httpResponse.statusCode == 400
            }
            return false
        } catch {
            return false
        }
    }
}

// MARK: - Google STT Request/Response Models

/// Request body for Google Cloud Speech-to-Text v2
private struct GoogleSTTRequest: Encodable {
    let config: GoogleSTTConfig
    let content: String
}

/// Configuration for Google Cloud Speech-to-Text
private struct GoogleSTTConfig: Encodable {
    let languageCodes: [String]
    let model: String
    let autoDecodingConfig: GoogleSTTAutoDecodingConfig
}

/// Auto-decoding configuration (empty struct tells Google to auto-detect format)
private struct GoogleSTTAutoDecodingConfig: Encodable {
    // Empty - Google will auto-detect audio format
}

/// Response from Google Cloud Speech-to-Text v2
private struct GoogleSTTResponse: Decodable {
    let results: [GoogleSTTResult]?
}

/// Individual recognition result
private struct GoogleSTTResult: Decodable {
    let alternatives: [GoogleSTTAlternative]?
}

/// Recognition alternative (hypothesis)
private struct GoogleSTTAlternative: Decodable {
    let transcript: String?
    let confidence: Double?
}
