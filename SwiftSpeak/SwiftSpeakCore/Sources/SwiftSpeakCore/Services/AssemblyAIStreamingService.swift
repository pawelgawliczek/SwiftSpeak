//
//  AssemblyAIStreamingService.swift
//  SwiftSpeakCore
//
//  Shared AssemblyAI real-time streaming transcription service
//  Uses WebSocket connection to wss://streaming.assemblyai.com/v3/ws
//  Works on both iOS and macOS
//

import Foundation
import Combine

/// AssemblyAI real-time streaming transcription service
/// Uses WebSocket connection to wss://streaming.assemblyai.com/v3/ws
public final class AssemblyAIStreamingService: NSObject, StreamingTranscriptionProvider {

    // MARK: - StreamingTranscriptionProvider

    public let providerId: AIProvider = .assemblyAI

    public var isConfigured: Bool {
        !apiKey.isEmpty
    }

    public var supportsStreaming: Bool { true }

    public private(set) var connectionState: StreamingConnectionState = .disconnected {
        didSet {
            print("[AssemblyAI] 🔌 Connection state: \(oldValue) → \(connectionState)")
            delegate?.connectionStateDidChange(connectionState)
        }
    }

    public weak var delegate: StreamingTranscriptionDelegate?

    public var partialTranscriptPublisher: AnyPublisher<String, Never> {
        partialTranscriptSubject.eraseToAnyPublisher()
    }

    public var finalTranscriptPublisher: AnyPublisher<String, Never> {
        finalTranscriptSubject.eraseToAnyPublisher()
    }

    public var sessionEndedPublisher: AnyPublisher<Void, Never> {
        sessionEndedSubject.eraseToAnyPublisher()
    }

    public private(set) var fullTranscript: String = ""

    /// AssemblyAI sends full utterance text (replacement), not deltas
    public var partialsAreDelta: Bool { false }

    // MARK: - Properties

    private let apiKey: String
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?

    private let partialTranscriptSubject = PassthroughSubject<String, Never>()
    private let finalTranscriptSubject = PassthroughSubject<String, Never>()
    private let sessionEndedSubject = PassthroughSubject<Void, Never>()

    private var isFinishing = false
    private var currentLanguage: Language?
    private var sessionId: String?

    // MARK: - Debug Tracking

    /// Count of audio chunks sent (for debugging)
    private var audioChunksSent: Int = 0
    /// Total bytes of audio sent (for debugging)
    private var audioBytesTotal: Int = 0
    /// Count of messages received (for debugging)
    private var messagesReceived: Int = 0
    /// Last time we logged audio stats
    private var lastAudioStatsLog: Date?

    /// WebSocket endpoint
    private static let streamingEndpoint = "wss://streaming.assemblyai.com/v3/ws"

    // MARK: - Initialization

    public init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
    }

    public convenience init?(config: AIProviderConfig) {
        guard config.provider == .assemblyAI,
              !config.apiKey.isEmpty
        else { return nil }

        self.init(apiKey: config.apiKey)
    }

    // MARK: - Connection

    public func connect(language: Language?, sampleRate: Int, transcriptionPrompt: String?, instructions: String?) async throws {
        print("[AssemblyAI] 🔌 connect() called - language: \(language?.rawValue ?? "auto"), sampleRate: \(sampleRate)")

        // Note: AssemblyAI doesn't support system instructions, only vocabulary via word_boost
        guard isConfigured else {
            print("[AssemblyAI] ❌ API key not configured")
            throw TranscriptionError.apiKeyMissing
        }

        // Build WebSocket URL with parameters
        // Quality optimizations based on AssemblyAI v3 best practices
        var components = URLComponents(string: Self.streamingEndpoint)!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "sample_rate", value: String(sampleRate)),
            URLQueryItem(name: "format_turns", value: "true"),  // Request formatted final transcripts
            URLQueryItem(name: "disable_partial_transcripts", value: "false"), // Keep partials for real-time feedback
            URLQueryItem(name: "end_of_turn_silence_threshold", value: "600")  // Increased from default ~400ms for better phrase detection
        ]

        // AssemblyAI v3 supports language detection or specific language
        if let language = language {
            queryItems.append(URLQueryItem(name: "language_code", value: language.assemblyAICode ?? "en"))
        } else {
            // Enable automatic language detection
            queryItems.append(URLQueryItem(name: "language_detection", value: "true"))
        }

        // Extract keywords from transcription prompt for AssemblyAI
        // Use keyterms_prompt (newer, 21% better accuracy) instead of deprecated word_boost
        if let prompt = transcriptionPrompt, !prompt.isEmpty {
            let keywords = extractKeywords(from: prompt)
            if !keywords.isEmpty {
                // AssemblyAI keyterms_prompt: max 100 terms, 50 chars each
                let limitedKeywords = keywords
                    .map { String($0.prefix(50)) }  // Max 50 chars per term
                    .prefix(100)  // Max 100 terms
                    .map { $0 }

                if let jsonData = try? JSONSerialization.data(withJSONObject: limitedKeywords),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    queryItems.append(URLQueryItem(name: "keyterms_prompt", value: jsonString))
                    print("[AssemblyAI] 📝 Keyterms prompting enabled with \(limitedKeywords.count) terms")
                }
            }
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw TranscriptionError.networkError("Invalid WebSocket URL")
        }

        currentLanguage = language
        connectionState = .connecting
        fullTranscript = ""
        isFinishing = false
        sessionId = nil

        // Create URL request with auth header
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")

        // Create session and WebSocket task
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let socket = session.webSocketTask(with: request)

        self.urlSession = session
        self.webSocket = socket

        // Connect
        socket.resume()

        // Start receive loop and wait for session begin
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            receiveMessages { [weak self] sessionBegan in
                if sessionBegan {
                    self?.connectionState = .connected
                    continuation.resume()
                } else {
                    continuation.resume(throwing: TranscriptionError.networkError("Failed to establish session"))
                }
            }
        }
    }

    public func sendAudio(_ audioData: Data) {
        // Log if audio is being dropped
        if connectionState != .connected {
            print("[AssemblyAI] ⚠️ Audio dropped - not connected (state: \(connectionState), chunks so far: \(audioChunksSent))")
            return
        }
        if isFinishing {
            print("[AssemblyAI] ⚠️ Audio dropped - finishing (chunks sent: \(audioChunksSent))")
            return
        }

        // Track audio stats
        audioChunksSent += 1
        audioBytesTotal += audioData.count

        // Log audio stats every 2 seconds
        let now = Date()
        if lastAudioStatsLog == nil || now.timeIntervalSince(lastAudioStatsLog!) >= 2.0 {
            let kbSent = Double(audioBytesTotal) / 1024.0
            print("[AssemblyAI] 📤 Audio stats: \(audioChunksSent) chunks, \(String(format: "%.1f", kbSent)) KB sent, messages received: \(messagesReceived)")
            lastAudioStatsLog = now
        }

        // AssemblyAI expects raw binary audio data
        let message = URLSessionWebSocketTask.Message.data(audioData)
        webSocket?.send(message) { [weak self] error in
            if let error {
                print("[AssemblyAI] ❌ WebSocket send error: \(error.localizedDescription)")
                self?.handleError(error)
            }
        }
    }

    public func finishAudio() {
        let kbSent = Double(audioBytesTotal) / 1024.0
        print("[AssemblyAI] 🏁 finishAudio() - Total: \(audioChunksSent) chunks, \(String(format: "%.1f", kbSent)) KB, messages received: \(messagesReceived)")

        guard connectionState == .connected, !isFinishing else {
            print("[AssemblyAI] ⚠️ finishAudio skipped - state: \(connectionState), isFinishing: \(isFinishing)")
            return
        }
        isFinishing = true

        // Send terminate message
        let terminateMessage = "{\"type\": \"Terminate\"}"
        let message = URLSessionWebSocketTask.Message.string(terminateMessage)
        webSocket?.send(message) { [weak self] error in
            if let error {
                print("[AssemblyAI] ❌ Terminate send error: \(error.localizedDescription)")
                self?.handleError(error)
            } else {
                print("[AssemblyAI] ✅ Terminate message sent")
            }
        }
    }

    public func disconnect() {
        print("[AssemblyAI] 🔌 disconnect() called - session: \(sessionId ?? "nil"), chunks sent: \(audioChunksSent)")
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        connectionState = .disconnected
        isFinishing = false
        sessionId = nil

        // Reset stats for next session
        audioChunksSent = 0
        audioBytesTotal = 0
        messagesReceived = 0
        lastAudioStatsLog = nil
    }

    // MARK: - Private Helpers

    /// Extract keywords from transcription prompt for word boosting
    /// Handles various formats: "Keywords: a, b", "Common names and terms: a, b", "Domain terminology: a, b"
    private func extractKeywords(from prompt: String) -> [String] {
        // Split by period to handle multiple sections, then extract from each
        var allKeywords: [String] = []

        for section in prompt.components(separatedBy: ".") {
            var text = section

            // Try multiple section markers
            for marker in ["Keywords:", "Common names and terms:", "Domain terminology:", "terminology:", "Context:"] {
                if let range = section.range(of: marker, options: .caseInsensitive) {
                    text = String(section[range.upperBound...])
                    break
                }
            }

            let keywords = text
                .components(separatedBy: CharacterSet(charactersIn: ",;:\n"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0.count > 1 }

            allKeywords.append(contentsOf: keywords)
        }

        // Remove duplicates while preserving order
        var seen = Set<String>()
        return allKeywords.filter { word in
            let lowercased = word.lowercased()
            if seen.contains(lowercased) { return false }
            seen.insert(lowercased)
            return true
        }
        .prefix(100)  // AssemblyAI limit
        .map { $0 }
    }

    // MARK: - Message Handling

    private var sessionBeganCallback: ((Bool) -> Void)?

    private func receiveMessages(onSessionBegan: ((Bool) -> Void)? = nil) {
        sessionBeganCallback = onSessionBegan
        continueReceiving()
    }

    private func continueReceiving() {
        webSocket?.receive { [weak self] result in
            guard let self else {
                print("[AssemblyAI] ⚠️ continueReceiving - self is nil")
                return
            }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                // Continue receiving
                self.continueReceiving()

            case .failure(let error):
                print("[AssemblyAI] ❌ Receive failed: \(error.localizedDescription)")
                self.handleError(error)
                self.sessionBeganCallback?(false)
                self.sessionBeganCallback = nil
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            parseResponse(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseResponse(text)
            }
        @unknown default:
            break
        }
    }

    private func parseResponse(_ text: String) {
        messagesReceived += 1

        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messageType = json["type"] as? String
        else {
            print("[AssemblyAI] ⚠️ Failed to parse message: \(text.prefix(100))")
            return
        }

        switch messageType {
        case "Begin":
            // Session started
            sessionId = json["id"] as? String
            print("[AssemblyAI] ✅ Session began - id: \(sessionId ?? "unknown")")
            sessionBeganCallback?(true)
            sessionBeganCallback = nil

        case "Turn":
            // Transcription result
            let transcript = json["transcript"] as? String ?? ""
            let endOfTurn = json["end_of_turn"] as? Bool ?? false
            let turnIsFormatted = json["turn_is_formatted"] as? Bool ?? false
            print("[AssemblyAI] 📝 Turn - formatted: \(turnIsFormatted), endOfTurn: \(endOfTurn), text: \"\(transcript.prefix(50))...\"")
            handleTurnMessage(json)

        case "Termination":
            // Session ended - server has processed all audio
            print("[AssemblyAI] 🛑 Termination received - total messages: \(messagesReceived)")
            sessionEndedSubject.send(())
            disconnect()

        case "Error":
            if let errorMsg = json["error"] as? String {
                print("[AssemblyAI] ❌ Server error: \(errorMsg)")
                delegate?.didEncounterError(.serverError(statusCode: 400, message: errorMsg))
            }

        default:
            print("[AssemblyAI] 📨 Unknown message type: \(messageType)")
        }
    }

    private func handleTurnMessage(_ json: [String: Any]) {
        // Get transcript text
        guard let transcript = json["transcript"] as? String,
              !transcript.isEmpty
        else { return }

        // Check if this is the end of a turn (final result)
        let endOfTurn = json["end_of_turn"] as? Bool ?? false
        let turnIsFormatted = json["turn_is_formatted"] as? Bool ?? false

        if turnIsFormatted {
            // Formatted final - this is the high-quality output we want
            fullTranscript += transcript + " "
            finalTranscriptSubject.send(transcript)
            delegate?.didReceiveFinalTranscript(transcript)
        } else if endOfTurn {
            // Unformatted end-of-turn - skip this, wait for formatted version
        } else {
            // Partial/interim result
            partialTranscriptSubject.send(transcript)
            delegate?.didReceivePartialTranscript(transcript)
        }
    }

    private func handleError(_ error: Error) {
        print("[AssemblyAI] ❌ handleError: \(error.localizedDescription)")

        let transcriptionError: TranscriptionError
        if let urlError = error as? URLError {
            print("[AssemblyAI] ❌ URLError code: \(urlError.code.rawValue) - \(urlError.code)")
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                transcriptionError = .networkUnavailable
            case .timedOut:
                transcriptionError = .networkTimeout
            case .cancelled:
                transcriptionError = .cancelled
            default:
                transcriptionError = .networkError(urlError.localizedDescription)
            }
        } else {
            transcriptionError = .networkError(error.localizedDescription)
        }

        connectionState = .error(transcriptionError.errorDescription ?? "Unknown error")
        delegate?.didEncounterError(transcriptionError)
    }
}

// MARK: - URLSessionWebSocketDelegate

extension AssemblyAIStreamingService: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("[AssemblyAI] 🔌 WebSocket opened - protocol: \(`protocol` ?? "none")")
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "none"
        print("[AssemblyAI] 🔌 WebSocket closed - code: \(closeCode.rawValue), reason: \(reasonString)")
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .disconnected
        }
    }
}
