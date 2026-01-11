//
//  ElevenLabsTranscriptionService.swift
//  SwiftSpeakCore
//
//  ElevenLabs Scribe v2 transcription service
//  High-accuracy speech-to-text with Egyptian Arabic dialect support
//

import Foundation

/// ElevenLabs Scribe API transcription service
/// Supports keyterm prompting for improved accuracy on technical terms and names
public final class ElevenLabsTranscriptionService: TranscriptionProvider {

    // MARK: - TranscriptionProvider

    public let providerId: AIProvider = .elevenLabs

    public var isConfigured: Bool {
        !apiKey.isEmpty
    }

    public var model: String {
        modelId
    }

    // MARK: - Properties

    private let apiKey: String
    private let modelId: String
    private let baseEndpoint = Constants.API.elevenLabs

    /// Maximum keyterms allowed by ElevenLabs API
    private static let maxKeyterms = 100

    /// Maximum characters per keyterm
    private static let maxKeyTermLength = 50

    // MARK: - Initialization

    public init(apiKey: String, model: String = "scribe_v2") {
        self.apiKey = apiKey
        self.modelId = model
    }

    public convenience init?(config: AIProviderConfig) {
        guard config.provider == .elevenLabs,
              !config.apiKey.isEmpty
        else { return nil }

        let model = config.transcriptionModel ?? "scribe_v2"
        self.init(apiKey: config.apiKey, model: model)
    }

    // MARK: - Transcription

    public func transcribe(
        audioURL: URL,
        language: Language?,
        promptHint: String?
    ) async throws -> String {
        guard isConfigured else {
            throw TranscriptionError.apiKeyMissing
        }

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.audioFileNotFound
        }

        let audioData = try Data(contentsOf: audioURL)

        // Build multipart form data
        let boundary = UUID().uuidString
        var body = Data()

        // Add model_id field
        body.appendFormField(named: "model_id", value: modelId, boundary: boundary)

        // Add language_code if specified (improves accuracy)
        if let language = language {
            body.appendFormField(named: "language_code", value: language.elevenLabsCode, boundary: boundary)
        }

        // Add audio tagging for enriched transcripts
        body.appendFormField(named: "tag_audio_events", value: "true", boundary: boundary)

        // Add keyterms if prompt hint provided
        if let hint = promptHint, !hint.isEmpty {
            let keyterms = parseKeyterms(from: hint)
            for (index, keyterm) in keyterms.enumerated() {
                body.appendFormField(named: "keyterms[\(index)]", value: keyterm, boundary: boundary)
            }
        }

        // Add Egyptian Arabic common keyterms if language is Egyptian Arabic
        if language == .egyptianArabic {
            let egyptianKeyterms = egyptianArabicKeyterms()
            for (index, keyterm) in egyptianKeyterms.enumerated() {
                body.appendFormField(named: "keyterms[\(index + 50)]", value: keyterm, boundary: boundary)
            }
        }

        // Add audio file
        let filename = audioURL.lastPathComponent
        let mimeType = mimeType(for: audioURL)
        body.appendFormFile(named: "file", filename: filename, mimeType: mimeType, data: audioData, boundary: boundary)

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        // Create request
        guard let url = URL(string: baseEndpoint) else {
            throw TranscriptionError.networkError("Invalid API endpoint")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120  // Longer timeout for large files
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.httpBody = body

        // Log request details
        print("--------------------------------------------------")
        print("ElevenLabs Scribe Transcription Request")
        print("--------------------------------------------------")
        print("Model: \(modelId)")
        print("Language: \(language?.elevenLabsCode ?? "auto-detect")")
        print("Audio file: \(filename)")
        print("File size: \(audioData.count) bytes")
        if let hint = promptHint {
            print("Prompt hint: \(hint.prefix(100))...")
        }
        print("--------------------------------------------------")

        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.networkError("Invalid response")
        }

        // Handle errors
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            if httpResponse.statusCode == 401 {
                throw TranscriptionError.apiKeyMissing
            }
            throw TranscriptionError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Parse response
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            let transcriptionResponse = try decoder.decode(ElevenLabsResponse.self, from: data)

            guard !transcriptionResponse.text.isEmpty else {
                throw TranscriptionError.emptyResponse
            }

            return transcriptionResponse.text

        } catch let decodingError as DecodingError {
            // Try to extract text directly if response format differs
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = json["text"] as? String {
                return text
            }
            throw TranscriptionError.networkError("Failed to decode response: \(decodingError.localizedDescription)")
        }
    }

    // MARK: - API Key Validation

    public func validateAPIKey(_ key: String) async -> Bool {
        guard !key.isEmpty else { return false }

        // ElevenLabs doesn't have a simple validation endpoint
        // Use the models endpoint to verify the key
        guard let url = URL(string: "https://api.elevenlabs.io/v1/models") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(key, forHTTPHeaderField: "xi-api-key")
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Private Helpers

    /// Parse prompt hint into keyterms array
    /// Keyterms: max 100 items, max 50 chars each, max 5 words per term
    private func parseKeyterms(from hint: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",;\n")
        let terms = hint.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { $0.count <= Self.maxKeyTermLength }
            .filter { $0.split(separator: " ").count <= 5 }
            .prefix(Self.maxKeyterms)

        return Array(terms)
    }

    /// Common Egyptian Arabic keyterms to improve transcription accuracy
    private func egyptianArabicKeyterms() -> [String] {
        return [
            // Common greetings/phrases
            "ازيك", "ازيكم", "عامل ايه", "عاملة ايه",
            "تمام", "كويس", "الحمدلله",
            // Question words
            "ازاي", "فين", "امتى", "ليه", "ايه",
            // Common expressions
            "يلا", "معلش", "ماشي", "اوكي", "خلاص",
            // Demonstratives
            "ده", "دي", "دول",
            // Pronouns
            "انا", "انت", "انتي", "هو", "هي", "احنا",
            // Common verbs
            "عايز", "عايزة", "مش عايز",
            // Time expressions
            "دلوقتي", "النهارده", "بكره", "امبارح",
            // Places (Egyptian)
            "القاهرة", "اسكندرية", "الجيزة"
        ]
    }

    /// Determine MIME type from file extension
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

// MARK: - Response Models

private struct ElevenLabsResponse: Decodable {
    let text: String
    let languageCode: String?
    let languageProbability: Double?
    let words: [ElevenLabsWord]?
}

private struct ElevenLabsWord: Decodable {
    let text: String
    let start: Double?
    let end: Double?
    let type: String?
    let speakerId: String?
}

// MARK: - Data Extensions for Multipart Form

private extension Data {
    mutating func appendFormField(named name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendFormFile(named name: String, filename: String, mimeType: String, data: Data, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
