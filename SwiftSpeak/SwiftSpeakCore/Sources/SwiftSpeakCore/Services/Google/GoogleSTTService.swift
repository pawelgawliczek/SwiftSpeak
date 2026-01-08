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

    public init(apiKey: String, projectId: String, model: String = "default") {
        self.apiKey = apiKey
        self.projectId = projectId
        self.modelName = model
    }

    public convenience init?(config: AIProviderConfig) {
        guard config.provider == .google,
              !config.apiKey.isEmpty,
              let projectId = config.googleProjectId,
              !projectId.isEmpty else { return nil }
        self.init(apiKey: config.apiKey, projectId: projectId, model: config.transcriptionModel ?? "default")
    }

    public func transcribe(audioURL: URL, language: Language?, promptHint: String?) async throws -> String {
        guard isConfigured else { throw TranscriptionError.apiKeyMissing }
        guard FileManager.default.fileExists(atPath: audioURL.path) else { throw TranscriptionError.audioFileNotFound }

        let audioData = try Data(contentsOf: audioURL)
        let base64Audio = audioData.base64EncodedString()

        // Google Cloud Speech-to-Text v1 API endpoint
        let endpoint = URL(string: "https://speech.googleapis.com/v1/speech:recognize?key=\(apiKey)")!

        // Build speech contexts from prompt hints
        // This allows boosting recognition of specific words/phrases from the context
        var speechContexts: [[String: Any]] = []
        if let hint = promptHint, !hint.isEmpty {
            let phrases = hint.components(separatedBy: CharacterSet(charactersIn: ",;.\n"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && $0.count < 100 }  // Google limits phrase length
            if !phrases.isEmpty {
                speechContexts.append([
                    "phrases": Array(phrases.prefix(500)),  // Google limits to 500 phrases
                    "boost": 10  // Boost factor (0-20, higher = stronger preference)
                ])
            }
        }

        // Determine the best model for this language
        // Some languages don't support all models (e.g., Chinese doesn't support latest_long)
        let effectiveModel: String
        if let lang = language {
            if lang.googleSTTSupportedModels.contains(modelName) {
                effectiveModel = modelName
            } else {
                // Fall back to the best model for this language
                effectiveModel = lang.googleSTTBestModel
            }
        } else {
            effectiveModel = modelName
        }

        // Determine audio encoding from file extension
        let encoding: String
        let sampleRate: Int?

        switch audioURL.pathExtension.lowercased() {
        case "wav":
            encoding = "LINEAR16"
            sampleRate = 16000
        case "flac":
            encoding = "FLAC"
            sampleRate = nil  // Let Google detect
        case "mp3":
            encoding = "MP3"
            sampleRate = nil
        case "ogg", "opus":
            encoding = "OGG_OPUS"
            sampleRate = nil
        case "webm":
            encoding = "WEBM_OPUS"
            sampleRate = nil
        case "m4a", "aac", "mp4":
            // M4A/AAC - use encoding unspecified for auto-detection
            encoding = "ENCODING_UNSPECIFIED"
            sampleRate = nil
        default:
            // Let Google auto-detect
            encoding = "ENCODING_UNSPECIFIED"
            sampleRate = nil
        }

        // v1 API request structure
        // Use googleSTTCode for full BCP-47 format (e.g., "pl-PL" not "pl")
        var config: [String: Any] = [
            "encoding": encoding,
            "languageCode": language?.googleSTTCode ?? "en-US",
            "model": effectiveModel,
            "enableAutomaticPunctuation": true
        ]

        // Only set sample rate if we know it (for LINEAR16)
        if let rate = sampleRate {
            config["sampleRateHertz"] = rate
        }

        // Add speech contexts if we have hints
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

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.serverError(statusCode: 500, message: "Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to extract error message from response
            var errorMessage: String? = nil
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                errorMessage = message
            }
            throw TranscriptionError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // v1 API response structure
        // Log raw response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("[GoogleSTT] Raw response: \(responseString.prefix(500))")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[GoogleSTT] Failed to parse JSON response")
            throw TranscriptionError.emptyResponse
        }

        // Check for empty results (no speech detected)
        guard let results = json["results"] as? [[String: Any]], !results.isEmpty else {
            print("[GoogleSTT] No results in response - no speech detected")
            print("[GoogleSTT] Full response: \(json)")
            throw TranscriptionError.emptyResponse
        }

        guard let alternatives = results.first?["alternatives"] as? [[String: Any]],
              let transcript = alternatives.first?["transcript"] as? String,
              !transcript.isEmpty else {
            print("[GoogleSTT] No transcript in alternatives")
            throw TranscriptionError.emptyResponse
        }

        print("[GoogleSTT] Transcript: \(transcript.prefix(100))...")
        return transcript
    }

    public func validateAPIKey(_ key: String) async -> Bool {
        // Validation requires project ID, so just check format
        return !key.isEmpty && key.count > 20
    }
}
