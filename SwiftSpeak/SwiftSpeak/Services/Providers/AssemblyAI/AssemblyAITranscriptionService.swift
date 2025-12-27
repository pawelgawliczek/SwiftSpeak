//
//  AssemblyAITranscriptionService.swift
//  SwiftSpeak
//
//  Created by Claude Code on 26/12/2025.
//

import Foundation

/// AssemblyAI transcription service using upload + poll pattern
/// Unlike real-time providers, AssemblyAI requires uploading the file first,
/// then creating a transcript job and polling for completion
final class AssemblyAITranscriptionService: TranscriptionProvider {

    // MARK: - TranscriptionProvider

    let providerId: AIProvider = .assemblyAI

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
    ///   - model: Model to use (default: "default", also supports "nano")
    ///   - apiClient: API client instance
    init(
        apiKey: String,
        model: String = "default",
        apiClient: APIClient = .shared
    ) {
        self.apiKey = apiKey
        self.modelName = model
        self.apiClient = apiClient
    }

    /// Initialize from provider configuration
    /// - Parameter config: AI provider configuration
    convenience init?(config: AIProviderConfig) {
        guard config.provider == .assemblyAI,
              !config.apiKey.isEmpty
        else { return nil }

        let model = config.transcriptionModel ?? "default"
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

        // Step 1: Upload audio file
        let uploadURL = try await uploadAudio(fileURL: audioURL)

        // Step 2: Create transcript job
        let transcriptID = try await createTranscript(audioURL: uploadURL, language: language)

        // Step 3: Poll for completion
        let text = try await pollForCompletion(transcriptID: transcriptID)

        // Verify we got a result
        guard !text.isEmpty else {
            throw TranscriptionError.emptyResponse
        }

        return text
    }

    // MARK: - API Key Validation

    func validateAPIKey(_ key: String) async -> Bool {
        // Validate by attempting to upload a minimal data blob
        // This is the cheapest way to validate without creating a full transcript
        let testData = Data([0x00, 0x01, 0x02, 0x03]) // Minimal test data

        var request = URLRequest(url: uploadEndpoint)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "authorization") // Note: NOT "Bearer"
        request.httpBody = testData
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                // Valid key returns 200, invalid returns 401
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
    /// - Returns: Transcript job ID
    private func createTranscript(audioURL: String, language: Language?) async throws -> String {
        // Build request body
        var body: [String: Any] = [
            "audio_url": audioURL
        ]

        // Add language if provided and supported
        if let language = language,
           let languageCode = language.assemblyAICode {
            body["language_code"] = languageCode
        }

        // Add model if not default
        if modelName != "default" {
            body["speech_model"] = modelName
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

/// AssemblyAI transcript response
private struct TranscriptResponse: Decodable {
    let id: String
    let status: String
    let text: String?
    let error: String?
}
