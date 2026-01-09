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
        // Note: AssemblyAI doesn't support system instructions, only vocabulary via word_boost
        guard isConfigured else {
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

        // Extract keywords from transcription prompt for AssemblyAI word boosting
        if let prompt = transcriptionPrompt, !prompt.isEmpty {
            let keywords = extractKeywords(from: prompt)
            if !keywords.isEmpty {
                // AssemblyAI uses word_boost parameter with JSON array
                if let jsonData = try? JSONSerialization.data(withJSONObject: keywords),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    queryItems.append(URLQueryItem(name: "word_boost", value: jsonString))
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
        guard connectionState == .connected, !isFinishing else { return }

        // AssemblyAI expects raw binary audio data
        let message = URLSessionWebSocketTask.Message.data(audioData)
        webSocket?.send(message) { [weak self] error in
            if let error {
                self?.handleError(error)
            }
        }
    }

    public func finishAudio() {
        guard connectionState == .connected, !isFinishing else { return }
        isFinishing = true

        // Send terminate message
        let terminateMessage = "{\"type\": \"Terminate\"}"
        let message = URLSessionWebSocketTask.Message.string(terminateMessage)
        webSocket?.send(message) { [weak self] error in
            if let error {
                self?.handleError(error)
            }
        }
    }

    public func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        connectionState = .disconnected
        isFinishing = false
        sessionId = nil
    }

    // MARK: - Private Helpers

    /// Extract keywords from transcription prompt for word boosting
    private func extractKeywords(from prompt: String) -> [String] {
        // Extract words after "Keywords:" if present, otherwise use whole prompt
        let keywordsSection = prompt.components(separatedBy: "Keywords:").last ?? prompt
        return keywordsSection
            .components(separatedBy: CharacterSet(charactersIn: ",.:;"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.count > 2 }
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
            guard let self else { return }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                // Continue receiving
                self.continueReceiving()

            case .failure(let error):
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
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messageType = json["type"] as? String
        else { return }

        switch messageType {
        case "Begin":
            // Session started
            sessionId = json["id"] as? String
            sessionBeganCallback?(true)
            sessionBeganCallback = nil

        case "Turn":
            // Transcription result
            handleTurnMessage(json)

        case "Termination":
            // Session ended - server has processed all audio
            #if DEBUG
            print("[AssemblyAI] 🏁 Session terminated - all audio processed")
            #endif
            sessionEndedSubject.send(())
            disconnect()

        case "Error":
            if let errorMsg = json["error"] as? String {
                delegate?.didEncounterError(.serverError(statusCode: 400, message: errorMsg))
            }

        default:
            break
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

        #if DEBUG
        print("[AssemblyAI] Turn: '\(transcript.prefix(40))' endOfTurn=\(endOfTurn) formatted=\(turnIsFormatted)")
        #endif

        if turnIsFormatted {
            // Formatted final - this is the high-quality output we want
            fullTranscript += transcript + " "
            #if DEBUG
            print("[AssemblyAI] 📨 Sending FORMATTED FINAL: '\(transcript.prefix(40))'")
            #endif
            finalTranscriptSubject.send(transcript)
            delegate?.didReceiveFinalTranscript(transcript)
        } else if endOfTurn {
            // Unformatted end-of-turn - skip this, wait for the formatted version
            // (AssemblyAI sends both, we only want the formatted one)
            #if DEBUG
            print("[AssemblyAI] ⏭️ Skipping unformatted endOfTurn (waiting for formatted)")
            #endif
        } else {
            // Partial/interim result - use transcript directly (utterance is often empty)
            // The transcript field contains the current partial text
            #if DEBUG
            print("[AssemblyAI] 📨 Sending PARTIAL: '\(transcript.prefix(40))'")
            #endif
            partialTranscriptSubject.send(transcript)
            delegate?.didReceivePartialTranscript(transcript)
        }
    }

    private func handleError(_ error: Error) {
        let transcriptionError: TranscriptionError
        if let urlError = error as? URLError {
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
        // Connection opened, wait for Begin message
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .disconnected
        }
    }
}
