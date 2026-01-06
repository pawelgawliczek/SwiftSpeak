//
//  AssemblyAITranscriptionService.swift
//  SwiftSpeakCore
//
//  Shared AssemblyAI transcription service for iOS and macOS
//  Uses upload + poll pattern for batch transcription
//

import Foundation

/// AssemblyAI transcription service using upload + poll pattern
/// Shared across iOS and macOS platforms
/// Supports speaker diarization for meeting transcription
public final class AssemblyAITranscriptionService: TranscriptionProvider, DiarizationProvider {

    // MARK: - DiarizationProvider

    public var supportsDiarization: Bool { true }

    // MARK: - TranscriptionProvider

    public let providerId: AIProvider = .assemblyAI

    public var isConfigured: Bool {
        !apiKey.isEmpty
    }

    public var model: String {
        modelName
    }

    // MARK: - Properties

    private let apiKey: String
    private let modelName: String

    /// AssemblyAI API endpoints
    private let uploadEndpoint = URL(string: Constants.API.assemblyAIUpload)!
    private let transcriptEndpoint = URL(string: Constants.API.assemblyAITranscript)!

    /// Polling configuration
    private let pollingIntervalSeconds: UInt64 = 3
    private let maxPollingAttempts: Int = 60 // 3 minutes total

    // MARK: - Initialization

    /// Initialize with API key and optional model
    /// - Parameters:
    ///   - apiKey: AssemblyAI API key
    ///   - model: Model to use ("best" for highest accuracy, "nano" for faster/cheaper)
    public init(apiKey: String, model: String = "best") {
        self.apiKey = apiKey
        self.modelName = model
    }

    /// Initialize from provider configuration
    /// - Parameter config: AI provider configuration
    public convenience init?(config: AIProviderConfig) {
        guard config.provider == .assemblyAI,
              !config.apiKey.isEmpty
        else { return nil }

        let model = config.transcriptionModel ?? "best"
        self.init(apiKey: config.apiKey, model: model)
    }

    // MARK: - Transcription

    public func transcribe(audioURL: URL, language: Language?, promptHint: String?) async throws -> String {
        guard isConfigured else {
            throw TranscriptionError.apiKeyMissing
        }

        // Verify file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.audioFileNotFound
        }

        // Step 1: Upload audio file
        let uploadURL = try await uploadAudio(fileURL: audioURL)

        // Step 2: Create transcript job with vocabulary hints
        let transcriptID = try await createTranscript(audioURL: uploadURL, language: language, promptHint: promptHint)

        // Step 3: Poll for completion
        let text = try await pollForCompletion(transcriptID: transcriptID)

        // Verify we got a result
        guard !text.isEmpty else {
            throw TranscriptionError.emptyResponse
        }

        return text
    }

    // MARK: - Diarization Transcription

    /// Transcribe audio with speaker diarization
    /// - Parameters:
    ///   - audioURL: Local audio file URL
    ///   - language: Optional source language hint
    ///   - promptHint: Optional context hint for transcription
    ///   - speakerCount: Expected number of speakers (helps accuracy)
    /// - Returns: DiarizedTranscriptionResult containing transcript and speaker segments
    public func transcribeWithDiarization(
        audioURL: URL,
        language: Language?,
        promptHint: String?,
        speakerCount: Int?
    ) async throws -> DiarizedTranscriptionResult {
        guard isConfigured else {
            throw TranscriptionError.apiKeyMissing
        }

        // Verify file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.audioFileNotFound
        }

        // Step 1: Upload audio file
        let uploadURL = try await uploadAudio(fileURL: audioURL)

        // Step 2: Create transcript job with speaker labels enabled
        let transcriptID = try await createTranscriptWithDiarization(
            audioURL: uploadURL,
            language: language,
            promptHint: promptHint,
            speakerCount: speakerCount
        )

        // Step 3: Poll for completion with diarization data
        let result = try await pollForCompletionWithDiarization(transcriptID: transcriptID)

        return result
    }

    /// Create transcript job with speaker diarization enabled
    private func createTranscriptWithDiarization(
        audioURL: String,
        language: Language?,
        promptHint: String?,
        speakerCount: Int?
    ) async throws -> String {
        // Build request body
        var body: [String: Any] = [
            "audio_url": audioURL,
            "speaker_labels": true  // Enable speaker diarization
        ]

        // Add speaker count hints if provided
        if let count = speakerCount {
            body["speakers_expected"] = count
        }

        // Add language if provided and supported
        if let language = language,
           let languageCode = language.assemblyAICode {
            body["language_code"] = languageCode
        }

        // Add speech model (best, nano)
        body["speech_model"] = modelName

        // Add word_boost from promptHint if provided
        if let hint = promptHint, !hint.isEmpty {
            let words = hint.components(separatedBy: CharacterSet(charactersIn: ",;. \n"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && $0.count >= 2 }

            if !words.isEmpty {
                body["word_boost"] = Array(words.prefix(100))
                body["boost_param"] = "high"
            }
        }

        // Create request
        var request = URLRequest(url: transcriptEndpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        // Execute request
        let (data, response) = try await executeRequest(request)

        // Parse response
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TranscriptionError.serverError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500,
                message: "Failed to create transcript with diarization"
            )
        }

        // Decode transcript response
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let transcriptResponse = try decoder.decode(DiarizedTranscriptResponse.self, from: data)

        guard !transcriptResponse.id.isEmpty else {
            throw TranscriptionError.unexpectedResponse("No transcript ID in response")
        }

        return transcriptResponse.id
    }

    /// Poll for transcript completion with diarization data
    private func pollForCompletionWithDiarization(transcriptID: String) async throws -> DiarizedTranscriptionResult {
        let pollURL = transcriptEndpoint.appendingPathComponent(transcriptID)

        for attempt in 0..<maxPollingAttempts {
            // Wait before polling (except first attempt)
            if attempt > 0 {
                try await Task.sleep(nanoseconds: pollingIntervalSeconds * 1_000_000_000)
            }

            // Create poll request
            var request = URLRequest(url: pollURL)
            request.httpMethod = "GET"
            request.setValue(apiKey, forHTTPHeaderField: "authorization")
            request.timeoutInterval = 30

            // Execute request
            let (data, response) = try await executeRequest(request)

            // Parse response
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw TranscriptionError.serverError(
                    statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500,
                    message: "Failed to poll transcript status"
                )
            }

            // Decode transcript response
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let transcriptResponse = try decoder.decode(DiarizedTranscriptResponse.self, from: data)

            // Check status
            switch transcriptResponse.status {
            case "completed":
                guard let text = transcriptResponse.text, !text.isEmpty else {
                    throw TranscriptionError.emptyResponse
                }

                // Parse diarization data
                let diarization = parseDiarization(from: transcriptResponse)
                let duration = TimeInterval(transcriptResponse.audioDuration ?? 0)

                return DiarizedTranscriptionResult(
                    text: text,
                    language: transcriptResponse.languageCode,
                    duration: duration,
                    diarization: diarization
                )

            case "error":
                let errorMessage = transcriptResponse.error ?? "Unknown error"
                throw TranscriptionError.serverError(
                    statusCode: 500,
                    message: "Transcription failed: \(errorMessage)"
                )

            case "queued", "processing":
                continue

            default:
                throw TranscriptionError.unexpectedResponse("Unknown status: \(transcriptResponse.status)")
            }
        }

        throw TranscriptionError.networkTimeout
    }

    /// Parse diarization data from AssemblyAI response
    private func parseDiarization(from response: DiarizedTranscriptResponse) -> DiarizedTranscript? {
        guard let utterances = response.utterances, !utterances.isEmpty else {
            return nil
        }

        let segments = utterances.map { utterance in
            SpeakerSegment(
                speaker: utterance.speaker,
                text: utterance.text,
                startMs: utterance.start,
                endMs: utterance.end,
                confidence: utterance.confidence
            )
        }

        let speakerCount = Set(segments.map { $0.speaker }).count

        return DiarizedTranscript(
            segments: segments,
            speakerCount: speakerCount
        )
    }

    // MARK: - API Key Validation

    public func validateAPIKey(_ key: String) async -> Bool {
        // Validate by attempting to upload a minimal data blob
        let testData = Data([0x00, 0x01, 0x02, 0x03])

        var request = URLRequest(url: uploadEndpoint)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "authorization")
        request.httpBody = testData
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

    // MARK: - Private Helper Methods

    /// Upload audio file to AssemblyAI
    /// - Parameter fileURL: Local audio file URL
    /// - Returns: Uploaded file URL from AssemblyAI
    private func uploadAudio(fileURL: URL) async throws -> String {
        // Read file data
        let audioData = try Data(contentsOf: fileURL)

        // Create upload request
        var request = URLRequest(url: uploadEndpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "authorization") // Note: NOT "Bearer"
        request.httpBody = audioData
        request.timeoutInterval = 60 // Upload can take a while

        // Execute request
        let (data, response) = try await executeRequest(request)

        // Parse response
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TranscriptionError.serverError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500,
                message: "Failed to upload audio"
            )
        }

        // Decode upload response
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let uploadResponse = try decoder.decode(UploadResponse.self, from: data)

        guard let uploadURL = uploadResponse.uploadUrl, !uploadURL.isEmpty else {
            throw TranscriptionError.unexpectedResponse("No upload URL in response")
        }

        return uploadURL
    }

    /// Create transcript job
    /// - Parameters:
    ///   - audioURL: Uploaded audio URL from AssemblyAI
    ///   - language: Optional language hint
    ///   - promptHint: Optional vocabulary/context hints for transcription
    /// - Returns: Transcript job ID
    private func createTranscript(audioURL: String, language: Language?, promptHint: String?) async throws -> String {
        // Build request body
        var body: [String: Any] = [
            "audio_url": audioURL
        ]

        // Add language if provided and supported
        if let language = language,
           let languageCode = language.assemblyAICode {
            body["language_code"] = languageCode
        }

        // Add speech model (best, nano)
        body["speech_model"] = modelName

        // Add word_boost from promptHint if provided
        // AssemblyAI uses word_boost array to improve recognition of specific terms
        if let hint = promptHint, !hint.isEmpty {
            // Extract words from the hint (split by common delimiters)
            let words = hint.components(separatedBy: CharacterSet(charactersIn: ",;. \n"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && $0.count >= 2 } // Filter out single chars

            if !words.isEmpty {
                body["word_boost"] = Array(words.prefix(100)) // AssemblyAI limit
                body["boost_param"] = "high" // Use high boost for vocabulary terms
            }
        }

        // Create request
        var request = URLRequest(url: transcriptEndpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        // Execute request
        let (data, response) = try await executeRequest(request)

        // Parse response
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TranscriptionError.serverError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500,
                message: "Failed to create transcript"
            )
        }

        // Decode transcript response
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let transcriptResponse = try decoder.decode(TranscriptResponse.self, from: data)

        guard !transcriptResponse.id.isEmpty else {
            throw TranscriptionError.unexpectedResponse("No transcript ID in response")
        }

        return transcriptResponse.id
    }

    /// Poll for transcript completion
    /// - Parameter transcriptID: Transcript job ID
    /// - Returns: Transcribed text
    private func pollForCompletion(transcriptID: String) async throws -> String {
        let pollURL = transcriptEndpoint.appendingPathComponent(transcriptID)

        for attempt in 0..<maxPollingAttempts {
            // Wait before polling (except first attempt)
            if attempt > 0 {
                try await Task.sleep(nanoseconds: pollingIntervalSeconds * 1_000_000_000)
            }

            // Create poll request
            var request = URLRequest(url: pollURL)
            request.httpMethod = "GET"
            request.setValue(apiKey, forHTTPHeaderField: "authorization")
            request.timeoutInterval = 30

            // Execute request
            let (data, response) = try await executeRequest(request)

            // Parse response
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw TranscriptionError.serverError(
                    statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500,
                    message: "Failed to poll transcript status"
                )
            }

            // Decode transcript response
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let transcriptResponse = try decoder.decode(TranscriptResponse.self, from: data)

            // Check status
            switch transcriptResponse.status {
            case "completed":
                guard let text = transcriptResponse.text, !text.isEmpty else {
                    throw TranscriptionError.emptyResponse
                }
                return text

            case "error":
                let errorMessage = transcriptResponse.error ?? "Unknown error"
                throw TranscriptionError.serverError(
                    statusCode: 500,
                    message: "Transcription failed: \(errorMessage)"
                )

            case "queued", "processing":
                // Continue polling
                continue

            default:
                throw TranscriptionError.unexpectedResponse("Unknown status: \(transcriptResponse.status)")
            }
        }

        // Polling timeout
        throw TranscriptionError.networkTimeout
    }

    /// Execute network request with error handling
    private func executeRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            return (data, response)
        } catch let error as URLError {
            throw mapURLError(error)
        } catch {
            throw TranscriptionError.networkError(error.localizedDescription)
        }
    }

    /// Map URLError to TranscriptionError
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
}

// MARK: - Response Models

/// AssemblyAI upload response
private struct UploadResponse: Decodable {
    let uploadUrl: String?
}

/// AssemblyAI transcript response (basic, without diarization)
private struct TranscriptResponse: Decodable {
    let id: String
    let status: String
    let text: String?
    let error: String?
}

/// AssemblyAI transcript response with diarization data
private struct DiarizedTranscriptResponse: Decodable {
    let id: String
    let status: String
    let text: String?
    let error: String?
    let audioDuration: Int?
    let languageCode: String?
    let utterances: [Utterance]?

    /// Speaker utterance from AssemblyAI
    struct Utterance: Decodable {
        let speaker: String   // "A", "B", "C", etc.
        let text: String
        let start: Int        // Start time in milliseconds
        let end: Int          // End time in milliseconds
        let confidence: Double
    }
}
