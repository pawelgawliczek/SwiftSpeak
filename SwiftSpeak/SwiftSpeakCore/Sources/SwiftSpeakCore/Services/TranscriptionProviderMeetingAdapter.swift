//
//  TranscriptionProviderMeetingAdapter.swift
//  SwiftSpeakCore
//
//  Adapter that wraps any TranscriptionProvider to implement MeetingTranscriptionService
//  Enables all transcription providers to be used for meeting recording
//
//  SHARED: Used by both iOS and macOS for meeting recording
//

import Foundation
import AVFoundation

// MARK: - Transcription Provider Meeting Adapter

/// Adapter that wraps any TranscriptionProvider to work with meeting recording
/// This enables all providers (OpenAI, Deepgram, Google, WhisperKit, etc.) to be used for meetings
/// Note: Most providers don't support diarization, so meetings will be transcribed without speaker labels
public final class TranscriptionProviderMeetingAdapter: MeetingTranscriptionService, @unchecked Sendable {

    // MARK: - Properties

    private let provider: any TranscriptionProvider
    private let providerName: String

    /// Whether this adapter's underlying provider supports diarization
    /// Currently only AssemblyAI has dedicated diarization support via AssemblyAIMeetingService
    public let supportsDiarization: Bool = false

    // MARK: - Initialization

    /// Create an adapter for any transcription provider
    /// - Parameter provider: The underlying transcription provider to wrap
    public init(provider: any TranscriptionProvider) {
        self.provider = provider
        self.providerName = provider.providerId.displayName
    }

    // MARK: - MeetingTranscriptionService

    /// Transcribe audio for meeting recording
    /// Since most providers don't support diarization, the result will have no speaker labels
    public func transcribe(
        audioURL: URL,
        withDiarization: Bool,
        language: String?,
        speakerCount: Int?,
        wordBoost: [String]?
    ) async throws -> DiarizedTranscriptionResult {
        // Convert language string to Language enum if provided
        let languageEnum: Language?
        if let lang = language {
            languageEnum = Language(rawValue: lang)
        } else {
            languageEnum = nil
        }

        // Build prompt hint from word boost and speaker info
        var promptParts: [String] = []

        if let words = wordBoost, !words.isEmpty {
            promptParts.append("Common terms: \(words.joined(separator: ", "))")
        }

        if let count = speakerCount, count > 1 {
            promptParts.append("This is a conversation with \(count) speakers")
        }

        let promptHint = promptParts.isEmpty ? nil : promptParts.joined(separator: ". ")

        // Call the underlying provider
        let transcribedText = try await provider.transcribe(
            audioURL: audioURL,
            language: languageEnum,
            promptHint: promptHint
        )

        // Get audio duration
        let duration = await getAudioDuration(url: audioURL)

        // Return result without diarization (provider doesn't support it)
        return DiarizedTranscriptionResult(
            text: transcribedText,
            language: language,
            duration: duration,
            diarization: nil
        )
    }

    // MARK: - Helpers

    private func getAudioDuration(url: URL) async -> TimeInterval {
        do {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            return CMTimeGetSeconds(duration)
        } catch {
            return 0
        }
    }
}

// MARK: - Factory Extension

public extension TranscriptionProviderMeetingAdapter {

    /// Provider name for display purposes
    var displayName: String {
        providerName
    }
}
