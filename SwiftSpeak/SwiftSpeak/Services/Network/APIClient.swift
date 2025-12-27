//
//  APIClient.swift
//  SwiftSpeak
//
//  Created by Claude Code on 26/12/2025.
//

import Foundation

/// Generic HTTP client for API calls
/// Handles JSON requests, multipart uploads, and error handling
actor APIClient {

    // MARK: - Configuration

    /// Default timeout for requests (30 seconds)
    let defaultTimeout: TimeInterval = 30

    /// Maximum file size for uploads (25 MB - Whisper limit)
    let maxUploadSizeMB: Double = 25

    // MARK: - Shared Instance

    static let shared = APIClient()

    private init() {}

    // MARK: - JSON POST Request

    /// Send a JSON POST request
    /// - Parameters:
    ///   - url: The endpoint URL
    ///   - body: Encodable request body
    ///   - headers: HTTP headers (Authorization, etc.)
    ///   - timeout: Request timeout in seconds
    /// - Returns: Decoded response
    func post<T: Decodable, U: Encodable>(
        url: URL,
        body: U,
        headers: [String: String] = [:],
        timeout: TimeInterval? = nil
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout ?? defaultTimeout

        // Set headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Encode body
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        return try await performRequest(request)
    }

    // MARK: - Streaming POST Request

    /// Send a streaming POST request that yields SSE events as they arrive
    /// - Parameters:
    ///   - url: The endpoint URL
    ///   - body: Encodable request body
    ///   - headers: HTTP headers (Authorization, etc.)
    ///   - timeout: Request timeout in seconds (longer default for streaming)
    /// - Returns: AsyncThrowingStream of SSE events
    func streamPost<U: Encodable>(
        url: URL,
        body: U,
        headers: [String: String] = [:],
        timeout: TimeInterval = 120
    ) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.timeoutInterval = timeout

                    // Set headers for SSE streaming
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    for (key, value) in headers {
                        request.setValue(value, forHTTPHeaderField: key)
                    }

                    // Encode body
                    let encoder = JSONEncoder()
                    request.httpBody = try encoder.encode(body)

                    // Start streaming request
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    // Validate response
                    if let httpResponse = response as? HTTPURLResponse {
                        guard (200...299).contains(httpResponse.statusCode) else {
                            // For non-success, try to collect error data
                            var errorData = Data()
                            for try await byte in bytes {
                                errorData.append(byte)
                                // Limit error data collection
                                if errorData.count > 4096 { break }
                            }

                            if httpResponse.statusCode == 401 {
                                throw TranscriptionError.apiKeyInvalid
                            } else if httpResponse.statusCode == 429 {
                                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                                let seconds = Int(retryAfter ?? "") ?? 60
                                throw TranscriptionError.rateLimited(retryAfterSeconds: seconds)
                            } else {
                                // Try to parse error message
                                let errorMessage = String(data: errorData, encoding: .utf8)
                                throw TranscriptionError.serverError(
                                    statusCode: httpResponse.statusCode,
                                    message: errorMessage
                                )
                            }
                        }
                    }

                    // Parse SSE stream
                    let parser = SSEParser()

                    for try await line in bytes.lines {
                        // Check for cancellation
                        if Task.isCancelled {
                            continuation.finish()
                            return
                        }

                        // Parse line (add newline back since lines strips it)
                        let events = await parser.parse(line + "\n")
                        for event in events {
                            continuation.yield(event)
                        }
                    }

                    // Handle any remaining buffered content
                    if await parser.hasBufferedContent {
                        // Final empty line to flush any pending event
                        let events = await parser.parse("\n")
                        for event in events {
                            continuation.yield(event)
                        }
                    }

                    continuation.finish()

                } catch let error as TranscriptionError {
                    continuation.finish(throwing: error)
                } catch let error as URLError {
                    continuation.finish(throwing: mapURLErrorSync(error))
                } catch {
                    if Task.isCancelled {
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: TranscriptionError.networkError(error.localizedDescription))
                    }
                }
            }

            // Handle cancellation
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    // MARK: - Multipart Upload

    /// Upload a file using multipart form data
    /// - Parameters:
    ///   - url: The endpoint URL
    ///   - fileURL: Local file URL to upload
    ///   - fileFieldName: Form field name for the file (e.g., "file")
    ///   - fields: Additional form fields
    ///   - headers: HTTP headers
    ///   - timeout: Request timeout
    /// - Returns: Decoded response
    func upload<T: Decodable>(
        url: URL,
        fileURL: URL,
        fileFieldName: String = "file",
        fields: [String: String] = [:],
        headers: [String: String] = [:],
        timeout: TimeInterval? = nil
    ) async throws -> T {
        // Check file size
        try checkFileSize(fileURL)

        // Read file data
        let fileData = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent
        let fileMimeType = mimeType(for: fileURL)

        // Build multipart request
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout ?? defaultTimeout
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Set additional headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Build body using helper (Sendable-safe)
        let body = MultipartDataBuilder.build(
            boundary: boundary,
            fields: fields,
            fileFieldName: fileFieldName,
            fileName: fileName,
            mimeType: fileMimeType,
            fileData: fileData
        )

        request.httpBody = body

        return try await performRequest(request)
    }

    /// Upload a file and return raw text response (for Whisper text format)
    func uploadForText(
        url: URL,
        fileURL: URL,
        fileFieldName: String = "file",
        fields: [String: String] = [:],
        headers: [String: String] = [:],
        timeout: TimeInterval? = nil
    ) async throws -> String {
        // Check file size
        try checkFileSize(fileURL)

        // Read file data
        let fileData = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent
        let fileMimeType = mimeType(for: fileURL)

        // Build multipart request
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout ?? defaultTimeout
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Set additional headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Build body using helper (Sendable-safe)
        let body = MultipartDataBuilder.build(
            boundary: boundary,
            fields: fields,
            fileFieldName: fileFieldName,
            fileName: fileName,
            mimeType: fileMimeType,
            fileData: fileData
        )

        request.httpBody = body

        return try await performTextRequest(request)
    }

    // MARK: - Request Execution

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await executeRequest(request)

        // Decode response
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            // Try to decode error response using nonisolated helper
            if let errorResponse = decodeAPIErrorResponse(from: data) {
                throw mapAPIError(errorResponse, statusCode: (response as? HTTPURLResponse)?.statusCode)
            }
            throw TranscriptionError.decodingError(error.localizedDescription)
        }
    }

    private func performTextRequest(_ request: URLRequest) async throws -> String {
        let (data, _) = try await executeRequest(request)

        guard let text = String(data: data, encoding: .utf8) else {
            throw TranscriptionError.decodingError("Failed to decode text response")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func executeRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // Check HTTP status
            if let httpResponse = response as? HTTPURLResponse {
                try checkHTTPStatus(httpResponse, data: data)
            }

            return (data, response)

        } catch let error as TranscriptionError {
            throw error
        } catch let error as URLError {
            throw mapURLError(error)
        } catch {
            throw TranscriptionError.networkError(error.localizedDescription)
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
            // Client error - try to parse error message using nonisolated helper
            if let errorResponse = decodeAPIErrorResponse(from: data) {
                throw mapAPIError(errorResponse, statusCode: response.statusCode)
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

    private func mapAPIError(_ error: APIErrorResponse, statusCode: Int?) -> TranscriptionError {
        let message = error.error?.message ?? error.message ?? "Unknown error"

        // Check for specific error types
        if message.lowercased().contains("invalid api key") ||
           message.lowercased().contains("incorrect api key") {
            return .apiKeyInvalid
        }

        if message.lowercased().contains("rate limit") {
            return .rateLimited(retryAfterSeconds: 60)
        }

        if message.lowercased().contains("quota") {
            return .quotaExceeded
        }

        return .serverError(statusCode: statusCode ?? 500, message: message)
    }

    // MARK: - Helpers

    private func checkFileSize(_ fileURL: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard let fileSize = attributes[.size] as? Int else {
            throw TranscriptionError.invalidAudioFile
        }

        let sizeMB = Double(fileSize) / (1024 * 1024)
        if sizeMB > maxUploadSizeMB {
            throw TranscriptionError.fileTooLarge(sizeMB: sizeMB, maxSizeMB: maxUploadSizeMB)
        }
    }

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
        case "mpeg":
            return "audio/mpeg"
        case "mpga":
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

// MARK: - Nonisolated URL Error Mapping

/// Maps URLError to TranscriptionError (nonisolated for use in closures)
nonisolated private func mapURLErrorSync(_ error: URLError) -> TranscriptionError {
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

// MARK: - API Error Response Models

/// Generic API error response structure (Sendable for actor safety)
struct APIErrorResponse: Sendable {
    let error: APIError?
    let message: String?

    struct APIError: Sendable {
        let message: String?
        let type: String?
        let code: String?
    }
}

/// Decodes API error response from data (nonisolated free function for Swift 6 compatibility)
nonisolated private func decodeAPIErrorResponse(from data: Data) -> APIErrorResponse? {
    struct CodableResponse: Decodable {
        let error: CodableError?
        let message: String?

        struct CodableError: Decodable {
            let message: String?
            let type: String?
            let code: String?
        }
    }

    guard let decoded = try? JSONDecoder().decode(CodableResponse.self, from: data) else {
        return nil
    }

    return APIErrorResponse(
        error: decoded.error.map { APIErrorResponse.APIError(message: $0.message, type: $0.type, code: $0.code) },
        message: decoded.message
    )
}

// MARK: - Multipart Data Builder

/// Helper for building multipart form data (Sendable-safe, nonisolated)
private enum MultipartDataBuilder: Sendable {
    nonisolated static func build(
        boundary: String,
        fields: [String: String],
        fileFieldName: String,
        fileName: String,
        mimeType: String,
        fileData: Data
    ) -> Data {
        var body = Data()

        // Add form fields
        for (key, value) in fields {
            appendString(&body, "--\(boundary)\r\n")
            appendString(&body, "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            appendString(&body, "\(value)\r\n")
        }

        // Add file
        appendString(&body, "--\(boundary)\r\n")
        appendString(&body, "Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(fileName)\"\r\n")
        appendString(&body, "Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        appendString(&body, "\r\n")

        // End boundary
        appendString(&body, "--\(boundary)--\r\n")

        return body
    }

    nonisolated private static func appendString(_ data: inout Data, _ string: String) {
        if let stringData = string.data(using: .utf8) {
            data.append(stringData)
        }
    }
}
