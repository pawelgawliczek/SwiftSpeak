//
//  DeepgramStreamingService.swift
//  SwiftSpeakCore
//
//  Shared Deepgram streaming transcription service
//

import Foundation
import Combine

/// Deepgram real-time streaming transcription service
public final class DeepgramStreamingService: NSObject, StreamingTranscriptionProvider {

    public let providerId: AIProvider = .deepgram
    public var isConfigured: Bool { !apiKey.isEmpty }
    public var supportsStreaming: Bool { true }

    public private(set) var connectionState: StreamingConnectionState = .disconnected {
        didSet { delegate?.connectionStateDidChange(connectionState) }
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

    /// Deepgram sends full transcript text (replacement), not deltas
    public var partialsAreDelta: Bool { false }

    private let apiKey: String
    private let model: String
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private let partialTranscriptSubject = PassthroughSubject<String, Never>()
    private let finalTranscriptSubject = PassthroughSubject<String, Never>()
    private let sessionEndedSubject = PassthroughSubject<Void, Never>()
    private var isFinishing = false

    public init(apiKey: String, model: String = "nova-2") {
        self.apiKey = apiKey
        self.model = model
        super.init()
    }

    public convenience init?(config: AIProviderConfig) {
        guard config.provider == .deepgram, !config.apiKey.isEmpty else { return nil }
        self.init(apiKey: config.apiKey, model: config.transcriptionModel ?? "nova-2")
    }

    public func connect(language: Language?, sampleRate: Int, transcriptionPrompt: String?, instructions: String?) async throws {
        guard isConfigured else { throw TranscriptionError.apiKeyMissing }

        var components = URLComponents(string: "wss://api.deepgram.com/v1/listen")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "model", value: model),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: String(sampleRate)),
            URLQueryItem(name: "channels", value: "1"),
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "smart_format", value: "true"),
            URLQueryItem(name: "interim_results", value: "true"),
            URLQueryItem(name: "endpointing", value: "500"),
            URLQueryItem(name: "utterance_end_ms", value: "1200")
        ]

        if let language = language {
            queryItems.append(URLQueryItem(name: "language", value: language.rawValue))
        }

        if let prompt = transcriptionPrompt, !prompt.isEmpty {
            let keywords = prompt.components(separatedBy: CharacterSet(charactersIn: ",.:"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && $0.count > 2 }
                .prefix(20)
            for keyword in keywords {
                queryItems.append(URLQueryItem(name: "keywords", value: "\(keyword):1.5"))
            }
        }

        components.queryItems = queryItems
        guard let url = components.url else { throw TranscriptionError.networkError("Invalid WebSocket URL") }

        connectionState = .connecting
        fullTranscript = ""
        isFinishing = false

        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let socket = session.webSocketTask(with: request)

        self.urlSession = session
        self.webSocket = socket
        socket.resume()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            receiveMessages()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.connectionState = .connected
                continuation.resume()
            }
        }
    }

    public func sendAudio(_ audioData: Data) {
        guard connectionState == .connected, !isFinishing else { return }
        let message = URLSessionWebSocketTask.Message.data(audioData)
        webSocket?.send(message) { [weak self] error in
            if let error { self?.handleError(error) }
        }
    }

    public func finishAudio() {
        guard connectionState == .connected, !isFinishing else { return }
        isFinishing = true
        let message = URLSessionWebSocketTask.Message.string("{\"type\": \"Finalize\"}")
        webSocket?.send(message) { _ in }
    }

    public func disconnect() {
        // Signal session ended before disconnect
        if isFinishing {
            sessionEndedSubject.send(())
        }
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        connectionState = .disconnected
        isFinishing = false
    }

    private func receiveMessages() {
        webSocket?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveMessages()
            case .failure(let error):
                self.handleError(error)
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text): parseResponse(text)
        case .data(let data): if let text = String(data: data, encoding: .utf8) { parseResponse(text) }
        @unknown default: break
        }
    }

    private func parseResponse(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let channel = json["channel"] as? [String: Any],
              let alternatives = channel["alternatives"] as? [[String: Any]],
              let firstAlt = alternatives.first,
              let transcript = firstAlt["transcript"] as? String,
              !transcript.isEmpty
        else { return }

        let isFinal = json["is_final"] as? Bool ?? false
        let speechFinal = json["speech_final"] as? Bool ?? false

        if isFinal || speechFinal {
            fullTranscript += transcript + " "
            finalTranscriptSubject.send(transcript)
            delegate?.didReceiveFinalTranscript(transcript)
        } else {
            partialTranscriptSubject.send(transcript)
            delegate?.didReceivePartialTranscript(transcript)
        }
    }

    private func handleError(_ error: Error) {
        let transcriptionError: TranscriptionError
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost: transcriptionError = .networkUnavailable
            case .timedOut: transcriptionError = .networkTimeout
            case .cancelled: transcriptionError = .cancelled
            default: transcriptionError = .networkError(urlError.localizedDescription)
            }
        } else {
            transcriptionError = .networkError(error.localizedDescription)
        }
        connectionState = .error(transcriptionError.errorDescription ?? "Unknown error")
        delegate?.didEncounterError(transcriptionError)
    }
}

extension DeepgramStreamingService: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async { [weak self] in self?.connectionState = .connected }
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async { [weak self] in self?.connectionState = .disconnected }
    }
}
