//
//  GoogleStreamingSTTService.swift
//  SwiftSpeakCore
//
//  Google Cloud Speech-to-Text real-time streaming service
//  Uses gRPC bidirectional streaming for low-latency transcription
//

import Foundation
import Combine
import GRPC
import NIO
import SwiftProtobuf

/// Google Cloud Speech-to-Text streaming transcription service
/// Uses gRPC bidirectional streaming for real-time transcription
public final class GoogleStreamingSTTService: NSObject, StreamingTranscriptionProvider {

    // MARK: - StreamingTranscriptionProvider

    public let providerId: AIProvider = .google

    public var isConfigured: Bool {
        !apiKey.isEmpty && !projectId.isEmpty
    }

    public var supportsStreaming: Bool { true }

    public private(set) var connectionState: StreamingConnectionState = .disconnected {
        didSet {
            print("[GoogleSTT] 🔌 Connection state: \(oldValue) → \(connectionState)")
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

    /// Google sends full replacement text for partials, not deltas
    public var partialsAreDelta: Bool { false }

    // MARK: - Properties

    private let apiKey: String
    private let projectId: String
    private let modelName: String

    private let partialTranscriptSubject = PassthroughSubject<String, Never>()
    private let finalTranscriptSubject = PassthroughSubject<String, Never>()
    private let sessionEndedSubject = PassthroughSubject<Void, Never>()

    private var group: MultiThreadedEventLoopGroup?
    private var channel: GRPCChannel?
    private var streamCall: BidirectionalStreamingCall<
        Google_Cloud_Speech_V1_StreamingRecognizeRequest,
        Google_Cloud_Speech_V1_StreamingRecognizeResponse
    >?

    private var isFinishing = false
    private var currentLanguage: Language?

    // MARK: - Debug Tracking

    private var audioChunksSent: Int = 0
    private var audioBytesTotal: Int = 0
    private var messagesReceived: Int = 0
    private var lastAudioStatsLog: Date?

    /// Google Cloud Speech gRPC endpoint
    private static let speechEndpoint = "speech.googleapis.com"
    private static let speechPort = 443

    // MARK: - Initialization

    public init(apiKey: String, projectId: String, model: String = "default") {
        self.apiKey = apiKey
        self.projectId = projectId
        self.modelName = model
        super.init()
    }

    public convenience init?(config: AIProviderConfig) {
        guard config.provider == .google,
              !config.apiKey.isEmpty,
              let projectId = config.googleProjectId,
              !projectId.isEmpty else { return nil }

        self.init(apiKey: config.apiKey, projectId: projectId, model: config.transcriptionModel ?? "default")
    }

    // MARK: - Connection

    public func connect(language: Language?, sampleRate: Int, transcriptionPrompt: String?, instructions: String?) async throws {
        print("[GoogleSTT] 🔌 connect() called - language: \(language?.rawValue ?? "auto"), sampleRate: \(sampleRate)")

        guard isConfigured else {
            print("[GoogleSTT] ❌ API key or project ID not configured")
            throw TranscriptionError.apiKeyMissing
        }

        currentLanguage = language
        connectionState = .connecting
        fullTranscript = ""
        isFinishing = false

        // Reset stats
        audioChunksSent = 0
        audioBytesTotal = 0
        messagesReceived = 0
        lastAudioStatsLog = nil

        // Create event loop group
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.group = group

        do {
            // Create gRPC channel with TLS and keepalive
            var channelConfig = GRPCChannelPool.Configuration.with(
                target: .host(Self.speechEndpoint, port: Self.speechPort),
                transportSecurity: .tls(GRPCTLSConfiguration.makeClientConfigurationBackedByNIOSSL()),
                eventLoopGroup: group
            )

            // Configure keepalive to prevent "Transport became inactive" errors
            channelConfig.keepalive = ClientConnectionKeepalive(
                interval: .seconds(30),
                timeout: .seconds(10),
                permitWithoutCalls: true,
                maximumPingsWithoutData: 0
            )

            // Set idle timeout to prevent premature disconnection
            channelConfig.idleTimeout = .minutes(5)

            let channel = try GRPCChannelPool.with(configuration: channelConfig)
            self.channel = channel

            print("[GoogleSTT] ✅ gRPC channel established with keepalive")

            // Create Speech client with API key in call options
            var callOptions = CallOptions()
            callOptions.customMetadata.add(name: "x-goog-api-key", value: apiKey)

            // Set a reasonable timeout for streaming (5 minutes max)
            callOptions.timeLimit = .timeout(.minutes(5))

            // Add iOS bundle ID for tracking (optional but good practice)
            if let bundleId = Bundle.main.bundleIdentifier {
                callOptions.customMetadata.add(name: "x-ios-bundle-identifier", value: bundleId)
            }

            let client = Google_Cloud_Speech_V1_SpeechNIOClient(channel: channel, defaultCallOptions: callOptions)

            // Start bidirectional streaming call
            let streamCall = client.streamingRecognize { [weak self] response in
                self?.handleResponse(response)
            }
            self.streamCall = streamCall

            // Build and send initial config request
            var config = Google_Cloud_Speech_V1_RecognitionConfig()
            config.encoding = .linear16
            config.sampleRateHertz = Int32(sampleRate)
            config.languageCode = language?.googleSTTCode ?? "en-US"
            config.enableAutomaticPunctuation = true

            // Determine effective model for this language
            if let lang = language, !lang.googleSTTSupportedModels.contains(modelName) {
                config.model = lang.googleSTTBestModel
            } else {
                config.model = modelName
            }

            // Add speech contexts for vocabulary boost
            // Best practice: boost values 10-20 for important terms (Google recommends 0-20 range)
            if let prompt = transcriptionPrompt, !prompt.isEmpty {
                let keywords = extractKeywords(from: prompt)
                if !keywords.isEmpty {
                    var context = Google_Cloud_Speech_V1_SpeechContext()
                    context.phrases = keywords
                    context.boost = 15.0  // Strong boost for custom vocabulary (0-20 range)
                    config.speechContexts = [context]
                    print("[GoogleSTT] 📝 Speech context with \(keywords.count) phrases, boost=15")
                }
            }

            var streamingConfig = Google_Cloud_Speech_V1_StreamingRecognitionConfig()
            streamingConfig.config = config
            streamingConfig.interimResults = true  // Enable partial results

            var configRequest = Google_Cloud_Speech_V1_StreamingRecognizeRequest()
            configRequest.streamingConfig = streamingConfig

            // Send config as first message
            streamCall.sendMessage(configRequest, promise: nil)

            connectionState = .connected
            print("[GoogleSTT] ✅ Streaming session started with model: \(config.model)")

            // Watch for stream completion
            streamCall.status.whenComplete { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let status):
                    print("[GoogleSTT] 🏁 Stream completed - status: \(status.code), message: \(status.message ?? "none")")
                    if status.isOk {
                        self.sessionEndedSubject.send(())
                    } else {
                        let error = TranscriptionError.serverError(statusCode: Int(status.code.rawValue), message: status.message)
                        self.delegate?.didEncounterError(error)
                    }
                case .failure(let error):
                    print("[GoogleSTT] ❌ Stream failed: \(error.localizedDescription)")
                    self.handleError(error)
                }
                DispatchQueue.main.async {
                    self.connectionState = .disconnected
                }
            }

        } catch {
            print("[GoogleSTT] ❌ Failed to connect: \(error.localizedDescription)")
            connectionState = .error(error.localizedDescription)
            throw TranscriptionError.networkError(error.localizedDescription)
        }
    }

    public func sendAudio(_ audioData: Data) {
        // Check if we can send
        if connectionState != .connected {
            print("[GoogleSTT] ⚠️ Audio dropped - not connected (state: \(connectionState), chunks so far: \(audioChunksSent))")
            return
        }
        if isFinishing {
            print("[GoogleSTT] ⚠️ Audio dropped - finishing (chunks sent: \(audioChunksSent))")
            return
        }

        // Track stats
        audioChunksSent += 1
        audioBytesTotal += audioData.count

        // Log stats every 2 seconds
        let now = Date()
        if lastAudioStatsLog == nil || now.timeIntervalSince(lastAudioStatsLog!) >= 2.0 {
            let kbSent = Double(audioBytesTotal) / 1024.0
            print("[GoogleSTT] 📤 Audio stats: \(audioChunksSent) chunks, \(String(format: "%.1f", kbSent)) KB sent, messages received: \(messagesReceived)")
            lastAudioStatsLog = now
        }

        // Build audio request
        var request = Google_Cloud_Speech_V1_StreamingRecognizeRequest()
        request.audioContent = audioData

        // Send audio chunk
        streamCall?.sendMessage(request, promise: nil)
    }

    public func finishAudio() {
        let kbSent = Double(audioBytesTotal) / 1024.0
        print("[GoogleSTT] 🏁 finishAudio() - Total: \(audioChunksSent) chunks, \(String(format: "%.1f", kbSent)) KB, messages received: \(messagesReceived)")

        guard connectionState == .connected, !isFinishing else {
            print("[GoogleSTT] ⚠️ finishAudio skipped - state: \(connectionState), isFinishing: \(isFinishing)")
            return
        }
        isFinishing = true

        // Close the request stream - this signals end of audio
        streamCall?.sendEnd(promise: nil)
        print("[GoogleSTT] ✅ End of stream sent")
    }

    public func disconnect() {
        print("[GoogleSTT] 🔌 disconnect() called - chunks sent: \(audioChunksSent)")

        streamCall?.cancel(promise: nil)
        streamCall = nil

        // Close channel gracefully
        _ = channel?.close()
        channel = nil

        // Shut down event loop group
        try? group?.syncShutdownGracefully()
        group = nil

        connectionState = .disconnected
        isFinishing = false

        // Reset stats
        audioChunksSent = 0
        audioBytesTotal = 0
        messagesReceived = 0
        lastAudioStatsLog = nil
    }

    // MARK: - Private Helpers

    /// Extract keywords from transcription prompt for speech context
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
                .filter { !$0.isEmpty && $0.count > 1 && $0.count < 100 }

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
        .prefix(500)  // Google limits to 500 phrases
        .map { $0 }
    }

    // MARK: - Response Handling

    private func handleResponse(_ response: Google_Cloud_Speech_V1_StreamingRecognizeResponse) {
        messagesReceived += 1

        // Check for errors
        if response.hasError {
            let errorMsg = response.error.message
            print("[GoogleSTT] ❌ Server error: \(errorMsg)")
            delegate?.didEncounterError(.serverError(statusCode: Int(response.error.code), message: errorMsg))
            return
        }

        // Process results
        for result in response.results {
            guard let alternative = result.alternatives.first else { continue }

            let transcript = alternative.transcript

            if result.isFinal {
                print("[GoogleSTT] 📝 Final: \"\(transcript.prefix(50))...\"")
                fullTranscript += transcript + " "
                finalTranscriptSubject.send(transcript)
                delegate?.didReceiveFinalTranscript(transcript)
            } else {
                print("[GoogleSTT] 📝 Partial: \"\(transcript.prefix(50))...\"")
                partialTranscriptSubject.send(transcript)
                delegate?.didReceivePartialTranscript(transcript)
            }
        }
    }

    private func handleError(_ error: Error) {
        print("[GoogleSTT] ❌ handleError: \(error.localizedDescription)")

        let transcriptionError: TranscriptionError
        if let grpcError = error as? GRPCStatus {
            switch grpcError.code {
            case .unavailable:
                transcriptionError = .networkUnavailable
            case .deadlineExceeded:
                transcriptionError = .networkTimeout
            case .cancelled:
                transcriptionError = .cancelled
            case .unauthenticated:
                transcriptionError = .apiKeyInvalid
            case .permissionDenied:
                transcriptionError = .serverError(statusCode: 403, message: "Permission denied - check API key and project settings")
            default:
                transcriptionError = .networkError(grpcError.message ?? "gRPC error: \(grpcError.code)")
            }
        } else {
            transcriptionError = .networkError(error.localizedDescription)
        }

        connectionState = .error(transcriptionError.errorDescription ?? "Unknown error")
        delegate?.didEncounterError(transcriptionError)
    }
}
