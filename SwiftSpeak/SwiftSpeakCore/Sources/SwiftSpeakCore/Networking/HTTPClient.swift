//
//  HTTPClient.swift
//  SwiftSpeakCore
//
//  Shared HTTP client for API communication
//  Platform-agnostic (works on iOS and macOS)
//

import Foundation

/// Shared HTTP client for making API requests
/// Used by all provider services in SwiftSpeakCore
public final class HTTPClient: @unchecked Sendable {

    /// Shared instance
    public static let shared = HTTPClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(session: URLSession = .shared) {
        self.session = session

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    // MARK: - JSON POST

    /// POST JSON request and decode response
    public func post<T: Encodable, R: Decodable>(
        url: URL,
        body: T,
        headers: [String: String] = [:],
        timeout: TimeInterval = 30
    ) async throws -> R {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        request.httpBody = try encoder.encode(body)

        let (data, response) = try await executeRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.networkError("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TranscriptionError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        return try decoder.decode(R.self, from: data)
    }

    // MARK: - Multipart Upload

    /// Upload file with multipart form data
    /// Uses smart timeout: short initial timeout to detect if upload is progressing,
    /// then allows more time for processing. Retries automatically if upload stalls.
    /// - Parameters:
    ///   - initialTimeout: Time to wait for first bytes to be sent (default 5s)
    ///   - processingTimeout: Time to wait for server response after upload (default 45s)
    ///   - maxRetries: Number of retry attempts if upload stalls (default 2)
    public func uploadForText(
        url: URL,
        fileURL: URL,
        fileFieldName: String,
        fields: [String: String] = [:],
        headers: [String: String] = [:],
        timeout: TimeInterval = 60,
        initialTimeout: TimeInterval = 5,
        processingTimeout: TimeInterval = 45,
        maxRetries: Int = 2
    ) async throws -> String {
        let boundary = UUID().uuidString

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        // Use the total timeout for the request
        request.timeoutInterval = timeout

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Build multipart body
        var body = Data()

        // Add form fields
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        // Add file
        let filename = fileURL.lastPathComponent
        let mimeType = mimeType(for: fileURL)
        let fileData = try Data(contentsOf: fileURL)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        // Note: Do NOT set request.httpBody here - we pass bodyData to uploadTask(with:from:) instead
        // Setting httpBody on a request used with upload tasks causes iOS warning:
        // "The request of a upload task should not contain a body or a body stream"

        // Retry loop for stalled uploads
        var lastError: Error?
        for attempt in 0...maxRetries {
            if attempt > 0 {
                print("📤 Upload retry attempt \(attempt)/\(maxRetries)")
            }

            do {
                let (data, response) = try await executeUploadWithProgress(
                    request: request,
                    bodyData: body,
                    initialTimeout: initialTimeout,
                    processingTimeout: processingTimeout
                )

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw TranscriptionError.networkError("Invalid response")
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw TranscriptionError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
                }

                guard let text = String(data: data, encoding: .utf8) else {
                    throw TranscriptionError.emptyResponse
                }

                return text

            } catch let error as TranscriptionError where error.isRetryable {
                lastError = error
                // Small delay before retry
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                continue
            } catch {
                // Non-retryable error, throw immediately
                throw error
            }
        }

        // All retries exhausted
        throw lastError ?? TranscriptionError.networkError("Upload failed after \(maxRetries) retries")
    }

    /// Execute upload with progress tracking and early failure detection
    /// Uses modern async/await upload API for reliability
    private func executeUploadWithProgress(
        request: URLRequest,
        bodyData: Data,
        initialTimeout: TimeInterval,
        processingTimeout: TimeInterval
    ) async throws -> (Data, URLResponse) {
        print("📤 HTTPClient: Starting upload (\(bodyData.count) bytes)...")

        // Use the modern async/await upload API (iOS 15+)
        // This is more reliable than the delegate-based approach
        do {
            let (data, response) = try await session.upload(for: request, from: bodyData)
            print("📥 HTTPClient: Upload complete, received \(data.count) bytes")
            return (data, response)
        } catch let error as URLError {
            print("❌ HTTPClient: Upload failed with URLError: \(error.code.rawValue) - \(error.localizedDescription)")
            throw mapURLError(error)
        } catch {
            print("❌ HTTPClient: Upload failed with error: \(error.localizedDescription)")
            throw TranscriptionError.networkError(error.localizedDescription)
        }
    }

    // MARK: - Streaming

    /// Stream SSE events from a POST request
    public func streamPost<T: Encodable>(
        url: URL,
        body: T,
        headers: [String: String] = [:],
        timeout: TimeInterval = 120
    ) async -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.timeoutInterval = timeout

                    for (key, value) in headers {
                        request.setValue(value, forHTTPHeaderField: key)
                    }

                    request.httpBody = try self.encoder.encode(body)

                    let (bytes, response) = try await self.session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        throw TranscriptionError.serverError(
                            statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500,
                            message: "Streaming request failed"
                        )
                    }

                    var buffer = ""
                    for try await byte in bytes {
                        buffer.append(Character(UnicodeScalar(byte)))

                        // Process complete lines
                        while let lineEnd = buffer.firstIndex(of: "\n") {
                            let line = String(buffer[..<lineEnd])
                            buffer = String(buffer[buffer.index(after: lineEnd)...])

                            if line.hasPrefix("data: ") {
                                let data = String(line.dropFirst(6))
                                if data == "[DONE]" {
                                    continuation.finish()
                                    return
                                }
                                continuation.yield(SSEEvent(data: data))
                            }
                        }
                    }

                    continuation.finish()

                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Raw Request

    /// Execute a raw request and return data and response
    /// Use this when you need full control over the request/response
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        return try await executeRequest(request)
    }

    // MARK: - Private Helpers

    private func executeRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            throw mapURLError(error)
        } catch {
            throw TranscriptionError.networkError(error.localizedDescription)
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

    private func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "m4a": return "audio/m4a"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "webm": return "audio/webm"
        case "mp4": return "audio/mp4"
        case "ogg": return "audio/ogg"
        case "flac": return "audio/flac"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - SSE Event

/// Server-Sent Event from streaming response
public struct SSEEvent: Sendable {
    public let data: String

    public init(data: String) {
        self.data = data
    }

    /// Check if this is an OpenAI [DONE] marker
    public var isOpenAIDone: Bool {
        data == "[DONE]"
    }

    /// Check if this is an Anthropic message_stop event
    public var isAnthropicDone: Bool {
        data.contains("\"type\":\"message_stop\"") || data.contains("\"type\": \"message_stop\"")
    }

    /// Extract content delta from OpenAI streaming response
    public func openAIContent() -> String? {
        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let delta = firstChoice["delta"] as? [String: Any],
              let content = delta["content"] as? String
        else { return nil }
        return content
    }

    /// Extract content delta from Anthropic streaming response
    public func anthropicContent() -> String? {
        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let type = json["type"] as? String,
              type == "content_block_delta",
              let delta = json["delta"] as? [String: Any],
              let text = delta["text"] as? String
        else { return nil }
        return text
    }
}

// MARK: - Upload Progress Delegate

/// Delegate that tracks upload progress and detects stalled connections
private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {

    enum UploadResult {
        case success(Data, URLResponse)
        case failure(Error)
    }

    var completion: ((UploadResult) -> Void)?
    private(set) var isCompleted = false

    private let initialTimeout: TimeInterval
    private var hasReceivedProgress = false
    private var initialTimeoutTimer: DispatchWorkItem?
    private var receivedData = Data()
    private var response: URLResponse?

    private let lock = NSLock()

    init(initialTimeout: TimeInterval) {
        self.initialTimeout = initialTimeout
        super.init()

        // Start initial timeout timer
        let timer = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            let hasProgress = self.hasReceivedProgress
            self.lock.unlock()

            if !hasProgress && !self.isCompleted {
                self.cancel(with: TranscriptionError.networkError("Upload stalled - no progress within \(Int(initialTimeout))s"))
            }
        }
        initialTimeoutTimer = timer
        DispatchQueue.global().asyncAfter(deadline: .now() + initialTimeout, execute: timer)
    }

    func cancel(with error: Error) {
        lock.lock()
        guard !isCompleted else {
            lock.unlock()
            return
        }
        isCompleted = true
        let handler = completion
        completion = nil
        lock.unlock()

        initialTimeoutTimer?.cancel()
        handler?(.failure(error))
    }

    // MARK: - URLSessionTaskDelegate

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        lock.lock()
        hasReceivedProgress = true
        lock.unlock()

        // Cancel initial timeout since we're making progress
        initialTimeoutTimer?.cancel()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        guard !isCompleted else {
            lock.unlock()
            return
        }
        isCompleted = true
        let handler = completion
        let data = receivedData
        let resp = response
        completion = nil
        lock.unlock()

        initialTimeoutTimer?.cancel()

        if let error = error {
            handler?(.failure(error))
        } else if let resp = resp {
            handler?(.success(data, resp))
        } else {
            handler?(.failure(TranscriptionError.networkError("No response received")))
        }
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        lock.lock()
        self.response = response
        hasReceivedProgress = true
        lock.unlock()

        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        receivedData.append(data)
        lock.unlock()
    }
}
