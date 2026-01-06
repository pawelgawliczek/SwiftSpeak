//
//  AssemblyAIMeetingService.swift
//  SwiftSpeakCore
//
//  AssemblyAI transcription service adapter for meetings
//  Implements MeetingTranscriptionService protocol
//  Shared between iOS and macOS
//

import Foundation

// MARK: - AssemblyAI Meeting Transcription Service

/// AssemblyAI transcription service with speaker diarization support
/// Implements MeetingTranscriptionService protocol for meeting recording
public final class AssemblyAIMeetingService: MeetingTranscriptionService, @unchecked Sendable {

    private let apiKey: String
    private let model: String

    // MARK: - Initialization

    public init(apiKey: String, model: String = "best") {
        self.apiKey = apiKey
        self.model = model
    }

    /// Initialize from AIProviderConfig if available
    public convenience init?(config: AIProviderConfig) {
        guard config.provider == .assemblyAI, !config.apiKey.isEmpty else {
            return nil
        }
        self.init(apiKey: config.apiKey, model: config.transcriptionModel ?? "best")
    }

    // MARK: - MeetingTranscriptionService

    public var supportsDiarization: Bool { true }

    public func transcribe(
        audioURL: URL,
        withDiarization: Bool,
        language: String?,
        speakerCount: Int?,
        wordBoost: [String]? = nil
    ) async throws -> DiarizedTranscriptionResult {
        // Upload audio
        let audioData = try Data(contentsOf: audioURL)
        let uploadURL = try await uploadAudio(audioData)

        // Create transcription request
        var body: [String: Any] = [
            "audio_url": uploadURL,
            "speech_model": model
        ]

        if withDiarization {
            body["speaker_labels"] = true
            if let count = speakerCount {
                body["speakers_expected"] = count
            }
        }

        if let lang = language {
            body["language_code"] = lang
        }

        // Add word boost for custom vocabulary (improves recognition of jargon, names, etc.)
        if let words = wordBoost, !words.isEmpty {
            // AssemblyAI accepts up to 1000 words, limit to 100 for practicality
            let boostWords = Array(words.prefix(100))
            body["word_boost"] = boostWords
            // boost_param controls how much to boost (default is "default", can be "low" or "high")
            body["boost_param"] = "high"
        }

        // Start transcription
        var request = URLRequest(url: URL(string: "https://api.assemblyai.com/v2/transcript")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw MeetingRecordingError.transcriptionFailed("Failed to start transcription")
        }

        struct TranscriptResponse: Codable {
            let id: String
            let status: String
        }

        let transcriptResponse = try JSONDecoder().decode(TranscriptResponse.self, from: data)

        // Poll for completion
        return try await pollForCompletion(transcriptId: transcriptResponse.id, withDiarization: withDiarization)
    }

    // MARK: - Private Methods

    private func uploadAudio(_ audioData: Data) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.assemblyai.com/v2/upload")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw MeetingRecordingError.transcriptionFailed("Failed to upload audio")
        }

        struct UploadResponse: Codable {
            let upload_url: String
        }

        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        return uploadResponse.upload_url
    }

    private func pollForCompletion(transcriptId: String, withDiarization: Bool) async throws -> DiarizedTranscriptionResult {
        let maxAttempts = 120 // 10 minutes max
        let pollInterval: UInt64 = 5_000_000_000 // 5 seconds

        for _ in 0..<maxAttempts {
            var request = URLRequest(url: URL(string: "https://api.assemblyai.com/v2/transcript/\(transcriptId)")!)
            request.setValue(apiKey, forHTTPHeaderField: "authorization")

            let (data, _) = try await URLSession.shared.data(for: request)

            struct PollResponse: Codable {
                let status: String
                let text: String?
                let error: String?
                let audio_duration: Double?
                let utterances: [Utterance]?
            }

            struct Utterance: Codable {
                let speaker: String
                let text: String
                let start: Int
                let end: Int
                let confidence: Double
            }

            let pollResponse = try JSONDecoder().decode(PollResponse.self, from: data)

            switch pollResponse.status {
            case "completed":
                let text = pollResponse.text ?? ""
                var diarization: DiarizedTranscript?

                if withDiarization, let utterances = pollResponse.utterances {
                    let segments = utterances.map { utterance in
                        SpeakerSegment(
                            speaker: utterance.speaker,
                            text: utterance.text,
                            startMs: utterance.start,
                            endMs: utterance.end,
                            confidence: utterance.confidence
                        )
                    }
                    diarization = DiarizedTranscript(segments: segments)
                }

                return DiarizedTranscriptionResult(
                    text: text,
                    language: nil,
                    duration: pollResponse.audio_duration ?? 0,
                    diarization: diarization
                )

            case "error":
                throw MeetingRecordingError.transcriptionFailed(pollResponse.error ?? "Transcription failed")

            default:
                // Still processing, wait and retry
                try await Task.sleep(nanoseconds: pollInterval)
            }
        }

        throw MeetingRecordingError.transcriptionFailed("Transcription timed out")
    }
}
