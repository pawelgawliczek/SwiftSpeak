//
//  OpenAIStreamingService.swift
//  SwiftSpeakCore
//
//  Shared OpenAI Realtime API streaming transcription service
//

import Foundation
import Combine

/// OpenAI Realtime API streaming transcription service
public final class OpenAIStreamingService: NSObject, StreamingTranscriptionProvider {

    // MARK: - StreamingTranscriptionProvider

    public let providerId: AIProvider = .openAI

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

    /// OpenAI sends deltas that should be accumulated
    public var partialsAreDelta: Bool { true }

    // MARK: - Properties

    private let apiKey: String
    private let model: String
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?

    private let partialTranscriptSubject = PassthroughSubject<String, Never>()
    private let finalTranscriptSubject = PassthroughSubject<String, Never>()
    private let sessionEndedSubject = PassthroughSubject<Void, Never>()

    private var isFinishing = false
    private var currentLanguage: Language?
    private var currentTranscriptionPrompt: String?
    private var sessionConfigured = false
    private var lastCompletedItemId: String?

    /// OpenAI Realtime uses 24kHz PCM16
    public static let requiredSampleRate = 24000

    // MARK: - Initialization

    public init(apiKey: String, model: String = "gpt-4o-transcribe") {
        self.apiKey = apiKey
        self.model = model
        super.init()
    }

    public convenience init?(config: AIProviderConfig) {
        guard config.provider == .openAI,
              !config.apiKey.isEmpty
        else { return nil }

        let configuredModel = config.transcriptionModel ?? ""
        let model: String
        if configuredModel.contains("gpt-4o") && configuredModel.contains("transcribe") {
            model = configuredModel
        } else {
            model = "gpt-4o-transcribe"
        }
        self.init(apiKey: config.apiKey, model: model)
    }

    // MARK: - Connection

    public func connect(language: Language?, sampleRate: Int, transcriptionPrompt: String?, instructions: String?) async throws {
        guard isConfigured else {
            throw TranscriptionError.apiKeyMissing
        }

        guard sampleRate == Self.requiredSampleRate else {
            throw TranscriptionError.invalidAudioFile
        }

        guard let url = URL(string: "wss://api.openai.com/v1/realtime?intent=transcription") else {
            throw TranscriptionError.networkError("Invalid WebSocket URL")
        }

        currentLanguage = language
        currentTranscriptionPrompt = transcriptionPrompt
        connectionState = .connecting
        fullTranscript = ""
        isFinishing = false
        sessionConfigured = false
        lastCompletedItemId = nil

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let socket = session.webSocketTask(with: request)

        self.urlSession = session
        self.webSocket = socket

        socket.resume()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            receiveMessages { [weak self] connected in
                guard let self else {
                    continuation.resume(throwing: TranscriptionError.networkError("Connection lost"))
                    return
                }

                if connected {
                    self.configureSession(language: language)
                    continuation.resume()
                } else {
                    continuation.resume(throwing: TranscriptionError.networkError("Failed to connect"))
                }
            }
        }
    }

    private func configureSession(language: Language?) {
        var transcriptionConfig: [String: Any] = ["model": model]

        if let lang = language?.whisperCode, !lang.isEmpty {
            transcriptionConfig["language"] = lang
        }

        if let prompt = currentTranscriptionPrompt, !prompt.isEmpty {
            transcriptionConfig["prompt"] = prompt
        }

        let turnDetection: [String: Any] = [
            "type": "server_vad",
            "threshold": 0.5,
            "prefix_padding_ms": 300,
            "silence_duration_ms": 300
        ]

        let sessionConfig: [String: Any] = [
            "input_audio_format": "pcm16",
            "input_audio_transcription": transcriptionConfig,
            "turn_detection": turnDetection,
            "input_audio_noise_reduction": ["type": "far_field"]
        ]

        let config: [String: Any] = [
            "type": "transcription_session.update",
            "session": sessionConfig
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: config),
              let jsonString = String(data: jsonData, encoding: .utf8)
        else { return }

        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocket?.send(message) { [weak self] error in
            if let error {
                self?.handleError(error)
            } else {
                self?.sessionConfigured = true
                self?.connectionState = .connected
            }
        }
    }

    public func sendAudio(_ audioData: Data) {
        guard connectionState == .connected, sessionConfigured, !isFinishing else { return }

        let base64Audio = audioData.base64EncodedString()
        let message: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": base64Audio
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: jsonData, encoding: .utf8)
        else { return }

        let wsMessage = URLSessionWebSocketTask.Message.string(jsonString)
        webSocket?.send(wsMessage) { [weak self] error in
            if let error { self?.handleError(error) }
        }
    }

    public func finishAudio() {
        guard connectionState == .connected, !isFinishing else { return }
        isFinishing = true

        let commitMessage: [String: Any] = ["type": "input_audio_buffer.commit"]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: commitMessage),
              let jsonString = String(data: jsonData, encoding: .utf8)
        else { return }

        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocket?.send(message) { _ in }
    }

    public func disconnect() {
        // Signal session ended before disconnect
        if isFinishing {
            sessionEndedSubject.send(())
        }
        connectionState = .disconnected
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        isFinishing = false
        sessionConfigured = false
    }

    // MARK: - Message Handling

    private var connectionCallback: ((Bool) -> Void)?

    private func receiveMessages(onConnected: ((Bool) -> Void)? = nil) {
        connectionCallback = onConnected
        continueReceiving()
    }

    private func continueReceiving() {
        webSocket?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.continueReceiving()
            case .failure(let error):
                self.handleError(error)
                self.connectionCallback?(false)
                self.connectionCallback = nil
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
              let eventType = json["type"] as? String
        else { return }

        switch eventType {
        case "session.created", "transcription_session.created":
            connectionCallback?(true)
            connectionCallback = nil

        case "transcription_session.updated":
            sessionConfigured = true

        case "conversation.item.input_audio_transcription.delta", "transcript.text.delta":
            if let delta = json["delta"] as? String, !delta.isEmpty {
                partialTranscriptSubject.send(delta)
                delegate?.didReceivePartialTranscript(delta)
            }

        case "conversation.item.input_audio_transcription.completed", "transcript.text.done":
            let itemId = json["item_id"] as? String ?? "<unknown>"
            if itemId == lastCompletedItemId { return }
            lastCompletedItemId = itemId

            if let transcript = json["transcript"] as? String, !transcript.isEmpty {
                fullTranscript += transcript + " "
                finalTranscriptSubject.send(transcript)
                delegate?.didReceiveFinalTranscript(transcript)
            }

        case "error":
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                delegate?.didEncounterError(.serverError(statusCode: 400, message: message))
            }

        default:
            break
        }
    }

    private func handleError(_ error: Error) {
        guard connectionState != .disconnected else { return }

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

extension OpenAIStreamingService: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {}

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .disconnected
        }
    }
}
