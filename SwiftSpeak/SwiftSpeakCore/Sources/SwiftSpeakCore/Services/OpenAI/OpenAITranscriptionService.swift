//
//  OpenAITranscriptionService.swift
//  SwiftSpeakCore
//
//  Shared OpenAI Whisper transcription service
//

import Foundation

/// OpenAI Whisper API transcription service
public final class OpenAITranscriptionService: TranscriptionProvider {

    // MARK: - TranscriptionProvider

    public let providerId: AIProvider = .openAI

    public var isConfigured: Bool {
        !apiKey.isEmpty
    }

    public var model: String {
        modelName
    }

    // MARK: - Properties

    private let apiKey: String
    private let modelName: String
    private let httpClient: HTTPClient

    /// Whisper API endpoint
    private let endpoint = URL(string: Constants.API.openAIWhisper)!

    // MARK: - Initialization

    public init(
        apiKey: String,
        model: String = "whisper-1",
        httpClient: HTTPClient = .shared
    ) {
        self.apiKey = apiKey
        self.modelName = model
        self.httpClient = httpClient
    }

    public convenience init?(config: AIProviderConfig) {
        guard config.provider == .openAI,
              !config.apiKey.isEmpty
        else { return nil }

        let model = config.transcriptionModel ?? "whisper-1"
        self.init(apiKey: config.apiKey, model: model)
    }

    // MARK: - Transcription

    public func transcribe(audioURL: URL, language: Language?, promptHint: String?) async throws -> String {
        guard isConfigured else {
            throw TranscriptionError.apiKeyMissing
        }

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.audioFileNotFound
        }

        var fields: [String: String] = [
            "model": modelName,
            "response_format": "text",
            "temperature": "0"          // Use temperature 0 for more deterministic output
        ]

        if let language = language {
            fields["language"] = language.whisperCode
        }

        if let prompt = promptHint, !prompt.isEmpty {
            fields["prompt"] = prompt
        }

        // Log the request details for debugging
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📤 OpenAI Whisper Transcription Request")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Model: \(modelName)")
        print("Language: \(language?.whisperCode ?? "auto-detect")")
        print("Temperature: 0")
        print("Audio file: \(audioURL.lastPathComponent)")
        if let prompt = fields["prompt"] {
            print("Prompt hint:")
            print("  \(prompt)")
        } else {
            print("Prompt hint: (none)")
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        let text: String = try await httpClient.uploadForText(
            url: endpoint,
            fileURL: audioURL,
            fileFieldName: "file",
            fields: fields,
            headers: ["Authorization": "Bearer \(apiKey)"],
            timeout: 60
        )

        guard !text.isEmpty else {
            throw TranscriptionError.emptyResponse
        }

        return text
    }

    public func validateAPIKey(_ key: String) async -> Bool {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
