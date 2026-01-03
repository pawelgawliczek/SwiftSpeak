//
//  TranscriptionProvider.swift
//  SwiftSpeak
//
//  Created by Claude Code on 26/12/2025.
//

import Foundation

/// Protocol for speech-to-text transcription providers
/// Implemented by OpenAI Whisper, ElevenLabs, Deepgram, and Local providers
public protocol TranscriptionProvider {
    /// The provider identifier
    public var providerId: AIProvider { get }

    /// Whether the provider is properly configured (has valid API key or local config)
    public var isConfigured: Bool { get }

    /// The model being used for transcription
    public var model: String { get }

    /// Transcribe audio file to text with optional context hints
    /// - Parameters:
    ///   - audioURL: Local file URL of recorded audio (m4a, wav, mp3, etc.)
    ///   - language: Optional source language hint for better accuracy
    ///   - promptHint: Optional context hint for transcription (vocabulary, language hints, etc.)
    ///                 Format: "This audio may contain: Polish, English. Common terms: Fatma, Kochanie"
    /// - Returns: Transcribed text
    /// - Throws: TranscriptionError on failure
    public func transcribe(audioURL: URL, language: Language?, promptHint: String?) async throws -> String

    /// Validate an API key with the provider
    /// - Parameter key: The API key to validate
    /// - Returns: true if the key is valid, false otherwise
    public func validateAPIKey(_ key: String) async -> Bool
}

// MARK: - Default Implementation

public extension TranscriptionProvider {
    /// Convenience method without prompt hint
    public func transcribe(audioURL: URL, language: Language?) async throws -> String {
        try await transcribe(audioURL: audioURL, language: language, promptHint: nil)
    }

    /// Convenience method without language or prompt hint
    public func transcribe(audioURL: URL) async throws -> String {
        try await transcribe(audioURL: audioURL, language: nil, promptHint: nil)
    }
}
