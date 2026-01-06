//
//  DiarizationProvider.swift
//  SwiftSpeakCore
//
//  Protocol for transcription providers that support speaker diarization
//  Used for meeting recording functionality
//

import Foundation

/// Protocol for transcription providers that support speaker diarization
/// Extends the base TranscriptionProvider with diarization capabilities
public protocol DiarizationProvider: TranscriptionProvider {
    /// Whether this provider supports speaker diarization
    var supportsDiarization: Bool { get }

    /// Transcribe audio with speaker diarization
    /// - Parameters:
    ///   - audioURL: Local file URL of recorded audio
    ///   - language: Optional source language hint
    ///   - promptHint: Optional context hint for transcription
    ///   - speakerCount: Expected number of speakers (helps accuracy)
    /// - Returns: DiarizedTranscriptionResult containing transcript and speaker segments
    /// - Throws: TranscriptionError on failure
    func transcribeWithDiarization(
        audioURL: URL,
        language: Language?,
        promptHint: String?,
        speakerCount: Int?
    ) async throws -> DiarizedTranscriptionResult
}

// MARK: - Default Implementation

public extension DiarizationProvider {
    /// Convenience method without speaker count hint
    func transcribeWithDiarization(
        audioURL: URL,
        language: Language?,
        promptHint: String?
    ) async throws -> DiarizedTranscriptionResult {
        try await transcribeWithDiarization(
            audioURL: audioURL,
            language: language,
            promptHint: promptHint,
            speakerCount: nil
        )
    }

    /// Convenience method with minimal parameters
    func transcribeWithDiarization(audioURL: URL) async throws -> DiarizedTranscriptionResult {
        try await transcribeWithDiarization(
            audioURL: audioURL,
            language: nil,
            promptHint: nil,
            speakerCount: nil
        )
    }
}

// MARK: - Diarization Configuration

/// Configuration options for diarization requests
public struct DiarizationConfig: Codable, Equatable, Hashable, Sendable {
    /// Minimum number of speakers to detect
    public var minSpeakers: Int?

    /// Maximum number of speakers to detect
    public var maxSpeakers: Int?

    /// Whether to include word-level timestamps
    public var includeWordTimestamps: Bool

    /// Minimum confidence threshold for segments (0.0 - 1.0)
    public var confidenceThreshold: Double?

    public init(
        minSpeakers: Int? = nil,
        maxSpeakers: Int? = nil,
        includeWordTimestamps: Bool = false,
        confidenceThreshold: Double? = nil
    ) {
        self.minSpeakers = minSpeakers
        self.maxSpeakers = maxSpeakers
        self.includeWordTimestamps = includeWordTimestamps
        self.confidenceThreshold = confidenceThreshold
    }

    public static let `default` = DiarizationConfig()
}

// MARK: - Provider Capability Check

/// Helper to check if a provider supports diarization
public func providerSupportsDiarization(_ provider: AIProvider) -> Bool {
    switch provider {
    case .assemblyAI:
        return true  // AssemblyAI has native speaker labels
    case .deepgram:
        return true  // Deepgram supports diarization
    case .google:
        return true  // Google Cloud Speech supports diarization
    default:
        return false // OpenAI Whisper, local providers don't support it
    }
}

/// Get the best diarization provider from configured providers
public func bestDiarizationProvider(from providers: [AIProvider]) -> AIProvider? {
    // Priority order for diarization: AssemblyAI > Deepgram > Google
    let priority: [AIProvider] = [.assemblyAI, .deepgram, .google]

    for preferred in priority {
        if providers.contains(preferred) && providerSupportsDiarization(preferred) {
            return preferred
        }
    }

    return nil
}
