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
        let mimeType = mimeType(for: fileURL)

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

        // Build body
        var body = Data()

        // Add form fields
        for (key, value) in fields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }

        // Add file
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(fileName)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.append("\r\n")

        // End boundary
        body.append("--\(boundary)--\r\n")

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
        let mimeType = mimeType(for: fileURL)

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

        // Build body
        var body = Data()

        // Add form fields
        for (key, value) in fields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }

        // Add file
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(fileName)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.append("\r\n")

        // End boundary
        body.append("--\(boundary)--\r\n")

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
            // Try to decode error response
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
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
            // Client error - try to parse error message
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
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

// MARK: - API Error Response Models

/// Generic API error response structure
struct APIErrorResponse: Decodable {
    let error: APIError?
    let message: String?

    struct APIError: Decodable {
        let message: String?
        let type: String?
        let code: String?
    }
}

// MARK: - Data Extension

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
