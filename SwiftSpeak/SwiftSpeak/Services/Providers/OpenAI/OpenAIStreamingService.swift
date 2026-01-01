//
//  OpenAIStreamingService.swift
//  SwiftSpeak
//
//  Real-time streaming transcription using OpenAI Realtime API
//

import Foundation
import Combine

/// OpenAI Realtime API streaming transcription service
/// Uses WebSocket connection to wss://api.openai.com/v1/realtime?intent=transcription
final class OpenAIStreamingService: NSObject, StreamingTranscriptionProvider {

    // MARK: - StreamingTranscriptionProvider

    let providerId: AIProvider = .openAI

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
    private var currentTranscriptionPrompt: String?  // Vocabulary hints
    private var currentInstructions: String?  // System instructions for formatting
    private var sessionConfigured = false

    /// Timer for periodic audio commits to get real-time transcription
    private var commitTimer: Timer?
    /// Interval between commits (seconds) - shorter = more responsive, but more API calls
    private let commitInterval: TimeInterval = 1.0
    /// Track if we have audio to commit
    private var hasUncommittedAudio = false

    /// OpenAI Realtime uses 24kHz PCM16
    static let requiredSampleRate = 24000

    // MARK: - Initialization

    init(apiKey: String, model: String = "gpt-4o-transcribe") {
        self.apiKey = apiKey
        self.model = model
        super.init()
    }

    convenience init?(config: AIProviderConfig) {
        guard config.provider == .openAI,
              !config.apiKey.isEmpty
        else { return nil }

        // OpenAI Realtime Transcription API only supports specific models
        // whisper-1 is NOT supported - must use gpt-4o-transcribe or gpt-4o-mini-transcribe
        let configuredModel = config.transcriptionModel ?? ""
        let model: String
        if configuredModel.contains("gpt-4o") && configuredModel.contains("transcribe") {
            model = configuredModel
        } else {
            // Default to gpt-4o-transcribe for streaming (whisper-1 not supported)
            model = "gpt-4o-transcribe"
            appLog("Streaming requires gpt-4o-transcribe model (configured: \(configuredModel)), using default", category: "OpenAIStreaming", level: .warning)
        }
        self.init(apiKey: config.apiKey, model: model)
    }

    // MARK: - Connection

    func connect(language: Language?, sampleRate: Int, transcriptionPrompt: String?, instructions: String?) async throws {
        appLog("connect() called - language: \(language?.whisperCode ?? "auto"), sampleRate: \(sampleRate), vocab: \(transcriptionPrompt != nil ? "yes (\(transcriptionPrompt!.count) chars)" : "none"), instructions: \(instructions != nil ? "yes (\(instructions!.count) chars)" : "none")", category: "OpenAIStreaming")

        guard isConfigured else {
            appLog("API key not configured", category: "OpenAIStreaming", level: .error)
            throw TranscriptionError.apiKeyMissing
        }

        // Validate sample rate - OpenAI Realtime requires 24kHz
        guard sampleRate == Self.requiredSampleRate else {
            appLog("Invalid sample rate: \(sampleRate), required: \(Self.requiredSampleRate)", category: "OpenAIStreaming", level: .error)
            throw TranscriptionError.invalidAudioFile
        }

        // Build WebSocket URL
        guard let url = URL(string: "wss://api.openai.com/v1/realtime?intent=transcription") else {
            appLog("Invalid WebSocket URL", category: "OpenAIStreaming", level: .error)
            throw TranscriptionError.networkError("Invalid WebSocket URL")
        }

        appLog("Connecting to: \(url.absoluteString)", category: "OpenAIStreaming")
        currentLanguage = language
        currentTranscriptionPrompt = transcriptionPrompt
        currentInstructions = instructions
        connectionState = .connecting
        fullTranscript = ""
        isFinishing = false
        sessionConfigured = false
        hasUncommittedAudio = false

        // Create URL request with auth headers
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")
        appLog("Created WebSocket request with auth headers", category: "OpenAIStreaming")

        // Create session and WebSocket task
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let socket = session.webSocketTask(with: request)

        self.urlSession = session
        self.webSocket = socket

        // Connect
        appLog("Starting WebSocket connection...", category: "OpenAIStreaming")
        socket.resume()

        // Wait for connection and configure session
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            receiveMessages { [weak self] connected in
                guard let self else {
                    appLog("Connection lost - self is nil", category: "OpenAIStreaming", level: .error)
                    continuation.resume(throwing: TranscriptionError.networkError("Connection lost"))
                    return
                }

                if connected {
                    appLog("WebSocket connected, configuring session...", category: "OpenAIStreaming")
                    // Configure the transcription session
                    self.configureSession(language: language)
                    continuation.resume()
                } else {
                    appLog("WebSocket failed to connect", category: "OpenAIStreaming", level: .error)
                    continuation.resume(throwing: TranscriptionError.networkError("Failed to connect"))
                }
            }
        }
    }

    private func configureSession(language: Language?) {
        appLog("Configuring session with model: \(self.model), language: \(language?.whisperCode ?? "auto"), hasVocab: \(currentTranscriptionPrompt != nil), hasInstructions: \(currentInstructions != nil)", category: "OpenAIStreaming")

        // Build transcription config
        var transcriptionConfig: [String: Any] = [
            "model": model
        ]

        // Add language if specified (omit for auto-detect)
        if let lang = language?.whisperCode, !lang.isEmpty {
            transcriptionConfig["language"] = lang
        }

        // Add vocabulary prompt if provided (words that might appear in audio)
        // This helps the model recognize specific terms, names, etc.
        // Note: OpenAI Realtime Transcription API only supports 'prompt' for hints,
        // NOT 'instructions'. If we have instructions, we combine them with the prompt.
        var combinedPrompt: String = ""

        if let prompt = currentTranscriptionPrompt, !prompt.isEmpty {
            combinedPrompt = prompt
        }

        // Append instructions to prompt if provided (API doesn't support separate instructions)
        if let instructions = currentInstructions, !instructions.isEmpty {
            if !combinedPrompt.isEmpty {
                combinedPrompt += " "
            }
            combinedPrompt += instructions
        }

        if !combinedPrompt.isEmpty {
            transcriptionConfig["prompt"] = combinedPrompt
            appLog("Injecting transcription prompt: \(combinedPrompt.prefix(100))...", category: "OpenAIStreaming")
        }

        // Build session configuration message
        // OpenAI Realtime API requires config wrapped in a "session" object
        let sessionConfig: [String: Any] = [
            "input_audio_format": "pcm16",
            "input_audio_transcription": transcriptionConfig,
            "turn_detection": [
                "type": "server_vad",
                "threshold": 0.5,           // Speech detection sensitivity (0.0-1.0)
                "prefix_padding_ms": 200,   // Less padding before speech
                "silence_duration_ms": 300  // Shorter silence = faster transcript delivery
            ] as [String : Any]
        ]

        let config: [String: Any] = [
            "type": "transcription_session.update",
            "session": sessionConfig
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: config),
              let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            appLog("Failed to serialize session config", category: "OpenAIStreaming", level: .error)
            return
        }

        appLog("Sending session config: \(jsonString.prefix(200))...", category: "OpenAIStreaming", level: .debug)

        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocket?.send(message) { [weak self] error in
            if let error {
                appLog("Failed to send session config: \(error.localizedDescription)", category: "OpenAIStreaming", level: .error)
                self?.handleError(error)
            } else {
                appLog("Session configured successfully", category: "OpenAIStreaming")
                self?.sessionConfigured = true
                self?.connectionState = .connected
                self?.startCommitTimer()
            }
        }
    }

    // MARK: - Periodic Commit Timer

    /// Start timer for periodic audio buffer commits
    /// This enables real-time transcription by committing audio chunks every few seconds
    private func startCommitTimer() {
        stopCommitTimer()
        appLog("Starting commit timer (interval: \(commitInterval)s)", category: "OpenAIStreaming")

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.commitTimer = Timer.scheduledTimer(withTimeInterval: self.commitInterval, repeats: true) { [weak self] _ in
                self?.commitAudioBufferIfNeeded()
            }
        }
    }

    /// Stop the commit timer
    private func stopCommitTimer() {
        commitTimer?.invalidate()
        commitTimer = nil
    }

    /// Commit audio buffer if we have uncommitted audio
    private func commitAudioBufferIfNeeded() {
        guard connectionState == .connected, sessionConfigured, !isFinishing, hasUncommittedAudio else {
            return
        }

        appLog("Periodic commit - committing audio buffer", category: "OpenAIStreaming")
        hasUncommittedAudio = false

        let commitMessage: [String: Any] = [
            "type": "input_audio_buffer.commit"
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: commitMessage),
              let jsonString = String(data: jsonData, encoding: .utf8)
        else { return }

        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocket?.send(message) { [weak self] error in
            if let error {
                appLog("Periodic commit failed: \(error.localizedDescription)", category: "OpenAIStreaming", level: .warning)
            }
        }
    }

    func sendAudio(_ audioData: Data) {
        guard connectionState == .connected, sessionConfigured, !isFinishing else {
            // Only log occasionally to avoid spam
            return
        }

        // Mark that we have audio waiting to be committed
        hasUncommittedAudio = true

        // OpenAI expects base64-encoded audio in a JSON message
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
            if let error {
                self?.handleError(error)
            }
        }
    }

    func finishAudio() {
        guard connectionState == .connected, !isFinishing else { return }
        isFinishing = true

        // Stop the periodic commit timer
        stopCommitTimer()

        // Commit any remaining audio buffer to trigger final processing
        appLog("Finishing audio - final commit", category: "OpenAIStreaming")
        let commitMessage: [String: Any] = [
            "type": "input_audio_buffer.commit"
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: commitMessage),
              let jsonString = String(data: jsonData, encoding: .utf8)
        else { return }

        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocket?.send(message) { [weak self] error in
            if let error {
                self?.handleError(error)
            }
        }
    }

    func disconnect() {
        stopCommitTimer()
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        connectionState = .disconnected
        isFinishing = false
        sessionConfigured = false
        hasUncommittedAudio = false
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
                // Continue receiving
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
        else {
            appLog("Failed to parse response: \(text.prefix(100))", category: "OpenAIStreaming", level: .warning)
            return
        }

        switch eventType {
        case "session.created", "transcription_session.created":
            // Session created, ready to configure
            appLog("Received: \(eventType) - session ready", category: "OpenAIStreaming")
            connectionCallback?(true)
            connectionCallback = nil

        case "transcription_session.updated":
            // Session configured successfully
            appLog("Received: transcription_session.updated - session configured", category: "OpenAIStreaming")
            sessionConfigured = true

        case "input_audio_buffer.committed":
            // Audio buffer was committed for processing
            if let itemId = json["item_id"] as? String {
                appLog("Audio buffer committed, item_id: \(itemId)", category: "OpenAIStreaming")
            } else {
                appLog("Audio buffer committed", category: "OpenAIStreaming")
            }
            break

        case "input_audio_buffer.speech_started":
            // Speech detected
            appLog("Speech started detected", category: "OpenAIStreaming")
            break

        case "input_audio_buffer.speech_stopped":
            // Speech ended
            appLog("Speech stopped detected", category: "OpenAIStreaming")
            break

        case "response.audio_transcript.done":
            // Response transcript completed (alternative transcript event)
            if let transcript = json["transcript"] as? String, !transcript.isEmpty {
                appLog("Transcript from response.audio_transcript.done: \(transcript.count) chars", category: "OpenAIStreaming")
                fullTranscript += transcript + " "
                finalTranscriptSubject.send(transcript)
                delegate?.didReceiveFinalTranscript(transcript)
            }

        case "response.text.done":
            // Text response completed
            if let text = json["text"] as? String, !text.isEmpty {
                appLog("Text from response.text.done: \(text.count) chars", category: "OpenAIStreaming")
                fullTranscript += text + " "
                finalTranscriptSubject.send(text)
                delegate?.didReceiveFinalTranscript(text)
            }

        case "conversation.item.input_audio_transcription.delta",
             "transcript.text.delta":
            // Partial transcription
            if let delta = json["delta"] as? String, !delta.isEmpty {
                appLog("Partial transcript: \(delta)", category: "OpenAIStreaming", level: .debug)
                partialTranscriptSubject.send(delta)
                delegate?.didReceivePartialTranscript(delta)
            }

        case "conversation.item.input_audio_transcription.completed",
             "transcript.text.done":
            // Final transcription for this utterance
            if let transcript = json["transcript"] as? String, !transcript.isEmpty {
                appLog("Final transcript: \(transcript.count) chars", category: "OpenAIStreaming")
                fullTranscript += transcript + " "
                finalTranscriptSubject.send(transcript)
                delegate?.didReceiveFinalTranscript(transcript)
            }

        case "conversation.item.created":
            // Extract transcript from conversation item
            // Structure: { item: { content: [{ type: "input_audio", transcript: "..." }] } }
            if let item = json["item"] as? [String: Any] {
                appLog("conversation.item.created - item keys: \(item.keys.joined(separator: ", "))", category: "OpenAIStreaming", level: .debug)

                if let content = item["content"] as? [[String: Any]] {
                    for contentItem in content {
                        appLog("  content item keys: \(contentItem.keys.joined(separator: ", "))", category: "OpenAIStreaming", level: .debug)
                        if let transcript = contentItem["transcript"] as? String, !transcript.isEmpty {
                            appLog("Transcript from conversation.item.created: \(transcript.count) chars", category: "OpenAIStreaming")
                            fullTranscript += transcript + " "
                            finalTranscriptSubject.send(transcript)
                            delegate?.didReceiveFinalTranscript(transcript)
                        }
                    }
                }
            } else {
                appLog("conversation.item.created - no item found, keys: \(json.keys.joined(separator: ", "))", category: "OpenAIStreaming", level: .debug)
            }

        case "error":
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                appLog("Server error: \(message)", category: "OpenAIStreaming", level: .error)
                delegate?.didEncounterError(.serverError(statusCode: 400, message: message))
            }

        default:
            // Log full JSON for unhandled events to help debug - include more details
            var details = "keys: \(json.keys.sorted().joined(separator: ", "))"
            // If there's an item, log its type
            if let item = json["item"] as? [String: Any], let itemType = item["type"] as? String {
                details += ", item.type: \(itemType)"
            }
            // If there's a delta, log it
            if let delta = json["delta"] as? String {
                details += ", delta: \(delta.prefix(50))"
            }
            appLog("EVENT: \(eventType) - \(details)", category: "OpenAIStreaming")
            break
        }
    }

    private func handleError(_ error: Error) {
        appLog("WebSocket error: \(error.localizedDescription)", category: "OpenAIStreaming", level: .error)

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
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        // Connection opened, wait for session.created event
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .disconnected
        }
    }
}

