//
//  TranscriptionProvider.swift
//  SwiftSpeak
//
//  Created by Claude Code on 26/12/2025.
//

import Foundation

/// Protocol for speech-to-text transcription providers
/// Implemented by OpenAI Whisper, ElevenLabs, Deepgram, and Local providers
protocol TranscriptionProvider {
    /// The provider identifier
    var providerId: AIProvider { get }

    /// Whether the provider is properly configured (has valid API key or local config)
    var isConfigured: Bool { get }

    /// The model being used for transcription
    var model: String { get }

    /// Transcribe audio file to text
    /// - Parameters:
    ///   - audioURL: Local file URL of recorded audio (m4a, wav, mp3, etc.)
    ///   - language: Optional source language hint for better accuracy
    /// - Returns: Transcribed text
    /// - Throws: TranscriptionError on failure
    func transcribe(audioURL: URL, language: Language?) async throws -> String

    /// Validate an API key with the provider
    /// - Parameter key: The API key to validate
    /// - Returns: true if the key is valid, false otherwise
    func validateAPIKey(_ key: String) async -> Bool
}

// MARK: - Default Implementation

extension TranscriptionProvider {
    /// Default implementation assumes language hint is optional
    func transcribe(audioURL: URL) async throws -> String {
        try await transcribe(audioURL: audioURL, language: nil)
    }
}
