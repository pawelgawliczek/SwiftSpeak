//
//  GoogleSTTService.swift
//  SwiftSpeakCore
//
//  Shared Google Cloud Speech-to-Text service
//

import Foundation

/// Google Cloud Speech-to-Text transcription service
public final class GoogleSTTService: TranscriptionProvider {

    public let providerId: AIProvider = .google
    public var isConfigured: Bool { !apiKey.isEmpty && !projectId.isEmpty }
    public var model: String { modelName }

    private let apiKey: String
    private let projectId: String
    private let modelName: String

    public init(apiKey: String, projectId: String, model: String = "long") {
        self.apiKey = apiKey
        self.projectId = projectId
        self.modelName = model
    }

    public convenience init?(config: AIProviderConfig) {
        guard config.provider == .google,
              !config.apiKey.isEmpty,
              let projectId = config.googleProjectId,
              !projectId.isEmpty else { return nil }
        self.init(apiKey: config.apiKey, projectId: projectId, model: config.transcriptionModel ?? "long")
    }

    public func transcribe(audioURL: URL, language: Language?, promptHint: String?) async throws -> String {
        guard isConfigured else { throw TranscriptionError.apiKeyMissing }
        guard FileManager.default.fileExists(atPath: audioURL.path) else { throw TranscriptionError.audioFileNotFound }

        let audioData = try Data(contentsOf: audioURL)
        let base64Audio = audioData.base64EncodedString()

        let endpoint = URL(string: "\(Constants.API.googleSTT)?key=\(apiKey)")!

        var speechContexts: [[String: Any]] = []
        if let hint = promptHint, !hint.isEmpty {
            let phrases = hint.components(separatedBy: CharacterSet(charactersIn: ",;."))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if !phrases.isEmpty {
                speechContexts.append(["phrases": phrases, "boost": 20])
            }
        }

        var config: [String: Any] = [
            "encoding": "LINEAR16",
            "sampleRateHertz": 16000,
            "languageCode": language?.googleCode ?? "en-US",
            "model": modelName,
            "enableAutomaticPunctuation": true
        ]

        if !speechContexts.isEmpty {
            config["speechContexts"] = speechContexts
        }

        let requestBody: [String: Any] = [
            "config": config,
            "audio": ["content": base64Audio]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw TranscriptionError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500, message: nil)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let alternatives = results.first?["alternatives"] as? [[String: Any]],
              let transcript = alternatives.first?["transcript"] as? String,
              !transcript.isEmpty else {
            throw TranscriptionError.emptyResponse
        }

        return transcript
    }

    public func validateAPIKey(_ key: String) async -> Bool {
        // Validation requires project ID, so just check format
        return !key.isEmpty && key.count > 20
    }
}
