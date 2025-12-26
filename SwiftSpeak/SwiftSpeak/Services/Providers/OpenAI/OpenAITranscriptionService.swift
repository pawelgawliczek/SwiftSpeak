//
//  OpenAITranscriptionService.swift
//  SwiftSpeak
//
//  Created by Claude Code on 26/12/2025.
//

import Foundation

/// OpenAI Whisper API transcription service
final class OpenAITranscriptionService: TranscriptionProvider {

    // MARK: - TranscriptionProvider

    let providerId: AIProvider = .openAI

    var isConfigured: Bool {
        !apiKey.isEmpty
    }

    var model: String {
        modelName
    }

    // MARK: - Properties

    private let apiKey: String
    private let modelName: String
    private let apiClient: APIClient

    /// Whisper API endpoint
    private let endpoint = URL(string: Constants.API.openAIWhisper)!

    // MARK: - Initialization

    /// Initialize with API key and optional model
    /// - Parameters:
    ///   - apiKey: OpenAI API key
    ///   - model: Whisper model to use (default: whisper-1)
    ///   - apiClient: API client instance
    init(
        apiKey: String,
        model: String = "whisper-1",
        apiClient: APIClient = .shared
    ) {
        self.apiKey = apiKey
        self.modelName = model
        self.apiClient = apiClient
    }

    /// Initialize from provider configuration
    /// - Parameter config: AI provider configuration
    convenience init?(config: AIProviderConfig) {
        guard config.provider == .openAI,
              !config.apiKey.isEmpty
        else { return nil }

        let model = config.transcriptionModel ?? "whisper-1"
        self.init(apiKey: config.apiKey, model: model)
    }

    // MARK: - Transcription

    func transcribe(audioURL: URL, language: Language?) async throws -> String {
        guard isConfigured else {
            throw TranscriptionError.apiKeyMissing
        }

        // Verify file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.audioFileNotFound
        }

        // Build form fields
        var fields: [String: String] = [
            "model": modelName,
            "response_format": "text"
        ]

        // Add language hint if provided
        if let language = language {
            fields["language"] = language.whisperCode
        }

        // Upload and transcribe
        let text: String = try await apiClient.uploadForText(
            url: endpoint,
            fileURL: audioURL,
            fileFieldName: "file",
            fields: fields,
            headers: [
                "Authorization": "Bearer \(apiKey)"
            ],
            timeout: 60 // Transcription can take a while
        )

        // Verify we got a result
        guard !text.isEmpty else {
            throw TranscriptionError.emptyResponse
        }

        return text
    }

    // MARK: - API Key Validation

    func validateAPIKey(_ key: String) async -> Bool {
        // Use the models endpoint to validate
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
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
}

// MARK: - Language Extension

extension Language {
    /// ISO 639-1 code for Whisper API
    var whisperCode: String {
        switch self {
        case .english: return "en"
        case .spanish: return "es"
        case .french: return "fr"
        case .german: return "de"
        case .italian: return "it"
        case .portuguese: return "pt"
        case .russian: return "ru"
        case .japanese: return "ja"
        case .korean: return "ko"
        case .chinese: return "zh"
        case .arabic: return "ar"
        case .egyptianArabic: return "ar"  // Egyptian Arabic uses same Whisper code
        case .polish: return "pl"
        }
    }
}
