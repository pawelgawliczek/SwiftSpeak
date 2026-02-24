//
//  Meeting.swift
//  SwiftSpeakCore
//
//  Meeting recording models with speaker diarization support
//  Used by both iOS and macOS for meeting transcription
//

import Foundation

// MARK: - Speaker Segment

/// A segment of speech attributed to a single speaker
public struct SpeakerSegment: Codable, Equatable, Hashable, Sendable {
    /// Speaker identifier (e.g., "A", "B", "C" or custom names)
    public let speaker: String

    /// The transcribed text for this segment
    public let text: String

    /// Start time in milliseconds from audio beginning
    public let startMs: Int

    /// End time in milliseconds from audio beginning
    public let endMs: Int

    /// Confidence score (0.0 - 1.0) if provided by the API
    public let confidence: Double?

    public init(
        speaker: String,
        text: String,
        startMs: Int,
        endMs: Int,
        confidence: Double? = nil
    ) {
        self.speaker = speaker
        self.text = text
        self.startMs = startMs
        self.endMs = endMs
        self.confidence = confidence
    }

    /// Start time as TimeInterval (seconds)
    public var startTime: TimeInterval {
        Double(startMs) / 1000.0
    }

    /// End time as TimeInterval (seconds)
    public var endTime: TimeInterval {
        Double(endMs) / 1000.0
    }

    /// Duration in seconds
    public var duration: TimeInterval {
        endTime - startTime
    }

    /// Formatted timestamp string (MM:SS)
    public var formattedTimestamp: String {
        let minutes = Int(startTime) / 60
        let seconds = Int(startTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Diarized Transcript

/// A complete transcript with speaker diarization
public struct DiarizedTranscript: Codable, Equatable, Hashable, Sendable {
    /// All speaker segments in chronological order
    public let segments: [SpeakerSegment]

    /// Number of unique speakers detected
    public let speakerCount: Int

    /// Speaker names mapping (e.g., "A" -> "John")
    public var speakerNames: [String: String]

    public init(
        segments: [SpeakerSegment],
        speakerCount: Int? = nil,
        speakerNames: [String: String] = [:]
    ) {
        self.segments = segments
        self.speakerCount = speakerCount ?? Set(segments.map { $0.speaker }).count
        self.speakerNames = speakerNames
    }

    /// Plain text without speaker labels
    public var plainText: String {
        segments.map { $0.text }.joined(separator: " ")
    }

    /// Formatted text with speaker labels
    /// Format: [Speaker A]: text\n\n[Speaker B]: text
    public var formattedText: String {
        segments.map { segment in
            let name = speakerNames[segment.speaker] ?? "Speaker \(segment.speaker)"
            return "[\(name)]: \(segment.text)"
        }.joined(separator: "\n\n")
    }

    /// Formatted text with timestamps
    /// Format: [00:00] Speaker A: text
    public var formattedTextWithTimestamps: String {
        segments.map { segment in
            let name = speakerNames[segment.speaker] ?? "Speaker \(segment.speaker)"
            return "[\(segment.formattedTimestamp)] \(name): \(segment.text)"
        }.joined(separator: "\n\n")
    }

    /// Get all unique speaker IDs
    public var speakers: [String] {
        Array(Set(segments.map { $0.speaker })).sorted()
    }

    /// Total duration of the transcript
    public var totalDuration: TimeInterval {
        guard let lastSegment = segments.last else { return 0 }
        return lastSegment.endTime
    }

    /// Get display name for a speaker
    public func displayName(for speaker: String) -> String {
        speakerNames[speaker] ?? "Speaker \(speaker)"
    }

    /// Create a copy with updated speaker names
    public func withSpeakerNames(_ names: [String: String]) -> DiarizedTranscript {
        DiarizedTranscript(
            segments: segments,
            speakerCount: speakerCount,
            speakerNames: names
        )
    }
}

// MARK: - Audio Source Configuration

/// Audio source for meeting recording
public enum MeetingAudioSource: String, Codable, CaseIterable, Sendable {
    /// Record only from microphone (single source)
    case microphoneOnly = "microphone"

    /// Record both microphone and system audio (dual source)
    /// Microphone = user's voice, System audio = remote participants
    case microphoneAndSystemAudio = "dual"

    public var displayName: String {
        switch self {
        case .microphoneOnly:
            return "Microphone Only"
        case .microphoneAndSystemAudio:
            return "Microphone + Meeting Audio"
        }
    }

    public var description: String {
        switch self {
        case .microphoneOnly:
            return "Records your voice only. Best for in-person meetings."
        case .microphoneAndSystemAudio:
            return "Records your voice separately from meeting app audio. Your segments are automatically tagged as 'Me'."
        }
    }
}

// MARK: - Meeting Settings

/// Configuration for meeting recording
public struct MeetingSettings: Codable, Equatable, Hashable, Sendable {
    /// Require speaker diarization for this meeting
    public var requireDiarization: Bool

    /// Maximum recording duration in minutes (default 120)
    public var maxDurationMinutes: Int

    /// Automatically save to Obsidian when complete
    public var autoSaveToObsidian: Bool

    /// Include timestamps in the output
    public var includeTimestamps: Bool

    /// Expected number of speakers (helps diarization accuracy)
    public var expectedSpeakerCount: Int?

    /// Language for transcription
    public var language: String?

    /// Audio source configuration (macOS only)
    /// When using dual source, microphone is tagged as "Me" and system audio goes through diarization
    public var audioSource: MeetingAudioSource

    /// User's display name for their own speech segments (used when audioSource is dual)
    public var userDisplayName: String

    /// Context ID for vocabulary hints (optional)
    /// When set, domain jargon and vocabulary from the context improve transcription accuracy
    public var contextId: UUID?

    /// Custom vocabulary words to boost in transcription
    /// These are extracted from the selected context's domain jargon
    public var wordBoost: [String]

    public init(
        requireDiarization: Bool = true,
        maxDurationMinutes: Int = 120,
        autoSaveToObsidian: Bool = true,
        includeTimestamps: Bool = false,
        expectedSpeakerCount: Int? = nil,
        language: String? = nil,
        audioSource: MeetingAudioSource = .microphoneAndSystemAudio,
        userDisplayName: String = "Me",
        contextId: UUID? = nil,
        wordBoost: [String] = []
    ) {
        self.requireDiarization = requireDiarization
        self.maxDurationMinutes = maxDurationMinutes
        self.autoSaveToObsidian = autoSaveToObsidian
        self.includeTimestamps = includeTimestamps
        self.expectedSpeakerCount = expectedSpeakerCount
        self.language = language
        self.audioSource = audioSource
        self.userDisplayName = userDisplayName
        self.contextId = contextId
        self.wordBoost = wordBoost
    }

    public static let `default` = MeetingSettings()

    // MARK: - Context Integration

    /// Update settings from a conversation context
    /// Call this when user selects a context for the meeting
    /// Sets contextId, wordBoost (vocabulary), and language
    /// - Parameters:
    ///   - context: The selected context, or nil to clear
    public mutating func setContext(_ context: ConversationContext?) {
        if let context = context {
            contextId = context.id
            wordBoost = context.transcriptionVocabulary
            // Set language from context if specified
            if context.autoDetectInputLanguage {
                language = nil
            } else if let inputLanguage = context.defaultInputLanguage {
                language = inputLanguage.rawValue
            }
        } else {
            contextId = nil
            wordBoost = []
            language = nil
        }
    }

    /// Update word boost by looking up context from a list
    /// Convenience method for UI bindings
    /// - Parameters:
    ///   - contextId: The context ID to set, or nil to clear
    ///   - contexts: Available contexts to search
    public mutating func setContext(id contextId: UUID?, from contexts: [ConversationContext]) {
        if let contextId = contextId,
           let context = contexts.first(where: { $0.id == contextId }) {
            setContext(context)
        } else {
            setContext(nil)
        }
    }
}

// MARK: - Meeting Processing Status

/// Status of a meeting recording through its lifecycle
public enum MeetingProcessingStatus: String, Codable, Equatable, Hashable, Sendable {
    /// Recording is in progress
    case recording

    /// Recording complete, waiting to transcribe
    case pendingTranscription

    /// Currently being transcribed
    case transcribing

    /// Transcription failed, can be retried
    case transcriptionFailed

    /// Successfully transcribed
    case completed

    /// User cancelled
    case cancelled

    public var displayName: String {
        switch self {
        case .recording: return "Recording..."
        case .pendingTranscription: return "Pending"
        case .transcribing: return "Transcribing..."
        case .transcriptionFailed: return "Failed"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    public var iconName: String {
        switch self {
        case .recording: return "record.circle"
        case .pendingTranscription: return "clock"
        case .transcribing: return "arrow.triangle.2.circlepath"
        case .transcriptionFailed: return "exclamationmark.triangle"
        case .completed: return "checkmark.circle"
        case .cancelled: return "xmark.circle"
        }
    }

    public var canRetry: Bool {
        self == .transcriptionFailed || self == .pendingTranscription
    }

    public var canDelete: Bool {
        self != .recording && self != .transcribing
    }

    public var audioRequired: Bool {
        // Audio is required until transcription succeeds
        self != .completed
    }
}

// MARK: - Meeting Record

/// A saved meeting recording with transcript and metadata
public struct MeetingRecord: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID

    /// Meeting title (user-provided or auto-generated)
    public var title: String

    /// When the meeting was recorded
    public let recordedAt: Date

    /// Total recording duration in seconds
    public var duration: TimeInterval

    /// Current processing status
    public var status: MeetingProcessingStatus

    /// Error message if transcription failed
    public var errorMessage: String?

    /// The diarized transcript (nil if diarization wasn't used or not yet transcribed)
    public var diarizedTranscript: DiarizedTranscript?

    /// Plain transcript text (empty until transcribed)
    public var plainTranscript: String

    /// AI-generated meeting notes (from Power Mode)
    public var generatedNotes: String?

    /// Power Mode ID used for note generation
    public var powerModeId: UUID?

    /// Estimated cost for this transcription
    public var estimatedCost: Double?

    /// Provider used for transcription
    public var provider: String?

    /// Settings used for this meeting
    public var settings: MeetingSettings

    /// Obsidian note path if saved
    public var obsidianNotePath: String?

    /// Permanent audio file path (relative to meetings directory)
    /// Audio is preserved until transcription succeeds
    public var audioFileName: String?

    /// Number of transcription attempts
    public var transcriptionAttempts: Int

    public init(
        id: UUID = UUID(),
        title: String,
        recordedAt: Date = Date(),
        duration: TimeInterval = 0,
        status: MeetingProcessingStatus = .recording,
        errorMessage: String? = nil,
        diarizedTranscript: DiarizedTranscript? = nil,
        plainTranscript: String = "",
        generatedNotes: String? = nil,
        powerModeId: UUID? = nil,
        estimatedCost: Double? = nil,
        provider: String? = nil,
        settings: MeetingSettings = .default,
        obsidianNotePath: String? = nil,
        audioFileName: String? = nil,
        transcriptionAttempts: Int = 0
    ) {
        self.id = id
        self.title = title
        self.recordedAt = recordedAt
        self.duration = duration
        self.status = status
        self.errorMessage = errorMessage
        self.diarizedTranscript = diarizedTranscript
        self.plainTranscript = plainTranscript
        self.generatedNotes = generatedNotes
        self.powerModeId = powerModeId
        self.estimatedCost = estimatedCost
        self.provider = provider
        self.settings = settings
        self.obsidianNotePath = obsidianNotePath
        self.audioFileName = audioFileName
        self.transcriptionAttempts = transcriptionAttempts
    }

    // MARK: - Migration from old audioFileURL

    /// For backwards compatibility - get audio URL if available
    @available(*, deprecated, message: "Use audioFileName with MeetingHistoryManager.audioURL(for:)")
    public var audioFileURL: URL? {
        get { nil }
        set { /* ignored */ }
    }

    /// Number of speakers in this meeting
    public var speakerCount: Int {
        diarizedTranscript?.speakerCount ?? 1
    }

    /// Formatted duration string (HH:MM:SS or MM:SS)
    public var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// Get the best available transcript text
    public var bestTranscript: String {
        if let diarized = diarizedTranscript {
            return settings.includeTimestamps ? diarized.formattedTextWithTimestamps : diarized.formattedText
        }
        return plainTranscript
    }
}

// MARK: - Meeting Recording State

/// State machine for meeting recording UI
public enum MeetingRecordingState: Equatable, Sendable {
    case idle
    case recording(duration: TimeInterval, isPaused: Bool)
    case stopping
    case chunking(progress: Double)
    case transcribing(chunkIndex: Int, totalChunks: Int)
    case mergingTranscripts
    case generatingNotes
    case savingToObsidian
    case complete(MeetingRecord)
    case error(MeetingRecordingError)

    public var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    public var isPaused: Bool {
        if case .recording(_, let paused) = self { return paused }
        return false
    }

    public var isProcessing: Bool {
        switch self {
        case .stopping, .chunking, .transcribing, .mergingTranscripts, .generatingNotes, .savingToObsidian:
            return true
        default:
            return false
        }
    }

    public var statusText: String {
        switch self {
        case .idle:
            return "Ready to record"
        case .recording(_, let isPaused):
            return isPaused ? "Paused" : "Recording"
        case .stopping:
            return "Stopping..."
        case .chunking(let progress):
            return "Preparing audio... \(Int(progress * 100))%"
        case .transcribing(let chunk, let total):
            if total > 1 {
                return "Transcribing chunk \(chunk + 1)/\(total)..."
            }
            return "Transcribing..."
        case .mergingTranscripts:
            return "Merging transcripts..."
        case .generatingNotes:
            return "Generating meeting notes..."
        case .savingToObsidian:
            return "Saving to Obsidian..."
        case .complete:
            return "Complete"
        case .error(let error):
            return error.localizedDescription
        }
    }

    public var progress: Double? {
        switch self {
        case .chunking(let progress):
            return progress
        case .transcribing(let chunk, let total):
            return Double(chunk) / Double(total)
        default:
            return nil
        }
    }
}

// MARK: - Meeting Recording Error

/// Errors that can occur during meeting recording
public enum MeetingRecordingError: Error, Equatable, Sendable {
    case microphoneAccessDenied
    case recordingFailed(String)
    case chunkingFailed(String)
    case transcriptionFailed(String)
    case diarizationNotSupported
    case noteGenerationFailed(String)
    case obsidianSaveFailed(String)
    case cancelled
    case maxDurationExceeded
    case audioTooShort

    public var localizedDescription: String {
        switch self {
        case .microphoneAccessDenied:
            return "Microphone access denied"
        case .recordingFailed(let reason):
            return "Recording failed: \(reason)"
        case .chunkingFailed(let reason):
            return "Audio processing failed: \(reason)"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .diarizationNotSupported:
            return "Speaker diarization not supported by this provider"
        case .noteGenerationFailed(let reason):
            return "Note generation failed: \(reason)"
        case .obsidianSaveFailed(let reason):
            return "Failed to save to Obsidian: \(reason)"
        case .cancelled:
            return "Recording cancelled"
        case .maxDurationExceeded:
            return "Maximum recording duration exceeded"
        case .audioTooShort:
            return "Recording too short - please record at least a few seconds"
        }
    }
}

// MARK: - Transcription Result Extension

/// Extended transcription result with diarization
public struct DiarizedTranscriptionResult: Sendable {
    /// Plain text transcription
    public let text: String

    /// Detected or specified language
    public let language: String?

    /// Duration of the audio in seconds
    public let duration: TimeInterval

    /// Diarized transcript (nil if diarization not requested or not supported)
    public let diarization: DiarizedTranscript?

    public init(
        text: String,
        language: String? = nil,
        duration: TimeInterval,
        diarization: DiarizedTranscript? = nil
    ) {
        self.text = text
        self.language = language
        self.duration = duration
        self.diarization = diarization
    }
}
