//
//  AssemblyAIStreamingService.swift
//  SwiftSpeak
//
//  Real-time streaming transcription using AssemblyAI WebSocket API v3
//

import Foundation
import Combine

/// AssemblyAI real-time streaming transcription service
/// Uses WebSocket connection to wss://streaming.assemblyai.com/v3/ws
final class AssemblyAIStreamingService: NSObject, StreamingTranscriptionProvider {

    // MARK: - StreamingTranscriptionProvider

    let providerId: AIProvider = .assemblyAI

    var isConfigured: Bool {
        !apiKey.isEmpty
    }

    var supportsStreaming: Bool { true }

    private(set) var connectionState: StreamingConnectionState = .disconnected {
        didSet {
            delegate?.connectionStateDidChange(connectionState)
        }
    }

    weak var delegate: StreamingTranscriptionDelegate?

    var partialTranscriptPublisher: AnyPublisher<String, Never> {
        partialTranscriptSubject.eraseToAnyPublisher()
    }

    var finalTranscriptPublisher: AnyPublisher<String, Never> {
        finalTranscriptSubject.eraseToAnyPublisher()
    }

    private(set) var fullTranscript: String = ""

    // MARK: - Properties

    private let apiKey: String
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?

    private let partialTranscriptSubject = PassthroughSubject<String, Never>()
    private let finalTranscriptSubject = PassthroughSubject<String, Never>()

    private var isFinishing = false
    private var currentLanguage: Language?
    private var sessionId: String?

    // MARK: - Initialization

    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
    }

    convenience init?(config: AIProviderConfig) {
        guard config.provider == .assemblyAI,
              !config.apiKey.isEmpty
        else { return nil }

        self.init(apiKey: config.apiKey)
    }

    // MARK: - Connection

    func connect(language: Language?, sampleRate: Int, transcriptionPrompt: String?) async throws {
        guard isConfigured else {
            throw TranscriptionError.apiKeyMissing
        }

        // Build WebSocket URL with parameters
        var components = URLComponents(string: "wss://streaming.assemblyai.com/v3/ws")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "sample_rate", value: String(sampleRate)),
            URLQueryItem(name: "format_turns", value: "true") // Request formatted final transcripts
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
            // Extract words after "Keywords:" if present
            let keywordsSection = prompt.components(separatedBy: "Keywords:").last ?? prompt
            let keywords = keywordsSection
                .components(separatedBy: CharacterSet(charactersIn: ",.:"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && $0.count > 2 }
                .prefix(20)

            if !keywords.isEmpty {
                // AssemblyAI uses word_boost parameter with JSON array
                let keywordArray = Array(keywords)
                if let jsonData = try? JSONSerialization.data(withJSONObject: keywordArray),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    queryItems.append(URLQueryItem(name: "word_boost", value: jsonString))
                }
                appLog("AssemblyAI word_boost: \(keywordArray.joined(separator: ", "))", category: "AssemblyAIStreaming")
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

    func sendAudio(_ audioData: Data) {
        guard connectionState == .connected, !isFinishing else { return }

        // AssemblyAI expects raw binary audio data
        let message = URLSessionWebSocketTask.Message.data(audioData)
        webSocket?.send(message) { [weak self] error in
            if let error {
                self?.handleError(error)
            }
        }
    }

    func finishAudio() {
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

    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        connectionState = .disconnected
        isFinishing = false
        sessionId = nil
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
            // Session ended
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

        if endOfTurn || turnIsFormatted {
            // Final transcript for this turn
            fullTranscript += transcript + " "
            finalTranscriptSubject.send(transcript)
            delegate?.didReceiveFinalTranscript(transcript)
        } else {
            // Partial/interim result - use utterance if available
            let displayText = (json["utterance"] as? String) ?? transcript
            partialTranscriptSubject.send(displayText)
            delegate?.didReceivePartialTranscript(displayText)
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
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        // Connection opened, wait for Begin message
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .disconnected
        }
    }
}

