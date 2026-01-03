//
//  StreamingTranscriptionProvider.swift
//  SwiftSpeak
//
//  Protocol for real-time streaming speech-to-text providers
//

import Foundation
import Combine

/// Delegate to receive streaming transcription updates
public protocol StreamingTranscriptionDelegate: AnyObject {
    /// Called when partial/interim transcription is received
    public func didReceivePartialTranscript(_ text: String)

    /// Called when final transcription for an utterance is received
    public func didReceiveFinalTranscript(_ text: String)

    /// Called when an error occurs during streaming
    public func didEncounterError(_ error: TranscriptionError)

    /// Called when the connection state changes
    public func connectionStateDidChange(_ state: StreamingConnectionState)
}

/// Connection state for streaming transcription
public enum StreamingConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case error(String)
}

/// Protocol for real-time streaming transcription providers
/// Implemented by OpenAI Realtime, Deepgram, and AssemblyAI streaming services
public protocol StreamingTranscriptionProvider: AnyObject {
    /// The provider identifier
    public var providerId: AIProvider { get }

    /// Whether the provider is properly configured (has valid API key)
    public var isConfigured: Bool { get }

    /// Whether streaming is supported by this provider
    public var supportsStreaming: Bool { get }

    /// Current connection state
    public var connectionState: StreamingConnectionState { get }

    /// Delegate for receiving transcription updates
    public var delegate: StreamingTranscriptionDelegate? { get set }

    /// Publisher for partial transcripts (for SwiftUI binding)
    public var partialTranscriptPublisher: AnyPublisher<String, Never> { get }

    /// Publisher for final transcripts
    public var finalTranscriptPublisher: AnyPublisher<String, Never> { get }

    /// Connect to the streaming service
    /// - Parameters:
    ///   - language: Optional language hint
    ///   - sampleRate: Audio sample rate (default 16000)
    ///   - transcriptionPrompt: Optional vocabulary hints (words that might appear in audio)
    ///   - instructions: Optional system instructions for formatting/style (e.g., "Use professional punctuation")
    public func connect(language: Language?, sampleRate: Int, transcriptionPrompt: String?, instructions: String?) async throws

    /// Send audio data chunk to the service
    /// - Parameter audioData: Raw PCM16 audio data
    public func sendAudio(_ audioData: Data)

    /// Signal end of audio input (triggers final processing)
    public func finishAudio()

    /// Disconnect from the streaming service
    public func disconnect()

    /// Get the accumulated full transcript
    public var fullTranscript: String { get }
}

// MARK: - Default Implementation

public extension StreamingTranscriptionProvider {
    public var supportsStreaming: Bool { true }

    public func connect(language: Language?) async throws {
        try await connect(language: language, sampleRate: 16000, transcriptionPrompt: nil, instructions: nil)
    }

    public func connect(language: Language?, sampleRate: Int) async throws {
        try await connect(language: language, sampleRate: sampleRate, transcriptionPrompt: nil, instructions: nil)
    }

    public func connect(language: Language?, sampleRate: Int, transcriptionPrompt: String?) async throws {
        try await connect(language: language, sampleRate: sampleRate, transcriptionPrompt: transcriptionPrompt, instructions: nil)
    }
}
