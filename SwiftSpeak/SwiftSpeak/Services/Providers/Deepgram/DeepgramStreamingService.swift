//
//  DeepgramStreamingService.swift
//  SwiftSpeak
//
//  Real-time streaming transcription using Deepgram WebSocket API
//

import Foundation
import Combine

/// Deepgram real-time streaming transcription service
/// Uses WebSocket connection to wss://api.deepgram.com/v1/listen
final class DeepgramStreamingService: NSObject, StreamingTranscriptionProvider {

    // MARK: - StreamingTranscriptionProvider

    let providerId: AIProvider = .deepgram

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
    private let model: String
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?

    private let partialTranscriptSubject = PassthroughSubject<String, Never>()
    private let finalTranscriptSubject = PassthroughSubject<String, Never>()

    private var isFinishing = false
    private var currentLanguage: Language?

    // MARK: - Initialization

    init(apiKey: String, model: String = "nova-2") {
        self.apiKey = apiKey
        self.model = model
        super.init()
    }

    convenience init?(config: AIProviderConfig) {
        guard config.provider == .deepgram,
              !config.apiKey.isEmpty
        else { return nil }

        let model = config.transcriptionModel ?? "nova-2"
        self.init(apiKey: config.apiKey, model: model)
    }

    // MARK: - Connection

    func connect(language: Language?, sampleRate: Int, transcriptionPrompt: String?) async throws {
        guard isConfigured else {
            throw TranscriptionError.apiKeyMissing
        }

        // Build WebSocket URL with parameters
        var components = URLComponents(string: "wss://api.deepgram.com/v1/listen")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "model", value: model),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: String(sampleRate)),
            URLQueryItem(name: "channels", value: "1"),
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "smart_format", value: "true"),
            URLQueryItem(name: "interim_results", value: "true"),
            URLQueryItem(name: "endpointing", value: "300"), // 300ms silence for endpointing
            URLQueryItem(name: "utterance_end_ms", value: "1000")
        ]

        if let language = language {
            queryItems.append(URLQueryItem(name: "language", value: language.rawValue))
        }

        // Extract keywords from transcription prompt for Deepgram word boosting
        // Format: "Context: Work. Keywords: SwiftSpeak, API, transcription"
        if let prompt = transcriptionPrompt, !prompt.isEmpty {
            // Extract words after "Keywords:" if present, otherwise use all words
            let keywordsSection = prompt.components(separatedBy: "Keywords:").last ?? prompt
            let keywords = keywordsSection
                .components(separatedBy: CharacterSet(charactersIn: ",.:"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && $0.count > 2 }
                .prefix(20) // Limit to 20 keywords

            for keyword in keywords {
                // Add keyword with moderate boost (1.5)
                queryItems.append(URLQueryItem(name: "keywords", value: "\(keyword):1.5"))
            }
            appLog("Deepgram keywords: \(Array(keywords).joined(separator: ", "))", category: "DeepgramStreaming")
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw TranscriptionError.networkError("Invalid WebSocket URL")
        }

        currentLanguage = language
        connectionState = .connecting
        fullTranscript = ""
        isFinishing = false

        // Create URL request with auth header
        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        // Create session and WebSocket task
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let socket = session.webSocketTask(with: request)

        self.urlSession = session
        self.webSocket = socket

        // Connect
        socket.resume()

        // Wait for connection with timeout
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // Start receive loop
            receiveMessages()

            // Give connection time to establish
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                if self.connectionState == .connecting {
                    self.connectionState = .connected
                }
                continuation.resume()
            }
        }
    }

    func sendAudio(_ audioData: Data) {
        guard connectionState == .connected, !isFinishing else { return }

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

        // Send finalize message to flush any remaining audio
        let finalizeMessage = "{\"type\": \"Finalize\"}"
        let message = URLSessionWebSocketTask.Message.string(finalizeMessage)
        webSocket?.send(message) { [weak self] error in
            if let error {
                self?.handleError(error)
            }
        }

        // Send close stream message after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            let closeMessage = "{\"type\": \"CloseStream\"}"
            let message = URLSessionWebSocketTask.Message.string(closeMessage)
            self?.webSocket?.send(message) { _ in }
        }
    }

    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        connectionState = .disconnected
        isFinishing = false
    }

    // MARK: - Message Handling

    private func receiveMessages() {
        webSocket?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                // Continue receiving
                self.receiveMessages()

            case .failure(let error):
                self.handleError(error)
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
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        // Check for error
        if let errorMsg = json["err_msg"] as? String {
            delegate?.didEncounterError(.serverError(statusCode: 400, message: errorMsg))
            return
        }

        // Parse transcript from channel -> alternatives -> transcript
        guard let channel = (json["channel"] as? [String: Any]),
              let alternatives = channel["alternatives"] as? [[String: Any]],
              let firstAlt = alternatives.first,
              let transcript = firstAlt["transcript"] as? String,
              !transcript.isEmpty
        else { return }

        // Check if this is a final result
        let isFinal = json["is_final"] as? Bool ?? false
        let speechFinal = json["speech_final"] as? Bool ?? false

        if isFinal || speechFinal {
            // Final transcript for this utterance
            fullTranscript += transcript + " "
            finalTranscriptSubject.send(transcript)
            delegate?.didReceiveFinalTranscript(transcript)
        } else {
            // Interim/partial result
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

extension DeepgramStreamingService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .connected
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .disconnected
        }
    }
}

// MARK: - Response Models

private struct DeepgramStreamingResponse: Decodable {
    let type: String?
    let channel: DeepgramChannel?
    let isFinal: Bool?
    let speechFinal: Bool?

    enum CodingKeys: String, CodingKey {
        case type
        case channel
        case isFinal = "is_final"
        case speechFinal = "speech_final"
    }
}

private struct DeepgramChannel: Decodable {
    let alternatives: [DeepgramAlternative]
}

private struct DeepgramAlternative: Decodable {
    let transcript: String
    let confidence: Double?
}
