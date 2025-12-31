//
//  PendingAudio.swift
//  SwiftSpeak
//
//  Pending audio queue models for retry functionality
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

// MARK: - Phase 11: Pending Audio & Retry

/// Status of a pending audio file in the retry queue
enum PendingAudioStatus: String, Codable {
    case pending       // Awaiting retry
    case processing    // Currently being processed
    case partialSuccess // Transcription OK, formatting failed
    case failed        // All retries exhausted
}

/// Represents an audio file waiting for retry
struct PendingAudio: Codable, Identifiable, Equatable {
    let id: UUID
    let audioFileURL: URL
    let createdAt: Date
    let duration: TimeInterval
    let mode: FormattingMode
    let translateEnabled: Bool
    let targetLanguage: Language?
    let customTemplateId: UUID?
    var status: PendingAudioStatus
    var rawTranscription: String?  // Preserved if transcription succeeded but formatting failed
    var retryCount: Int
    var lastError: String?
    var lastAttemptAt: Date?

    init(
        id: UUID = UUID(),
        audioFileURL: URL,
        createdAt: Date = Date(),
        duration: TimeInterval,
        mode: FormattingMode,
        translateEnabled: Bool = false,
        targetLanguage: Language? = nil,
        customTemplateId: UUID? = nil,
        status: PendingAudioStatus = .pending,
        rawTranscription: String? = nil,
        retryCount: Int = 0,
        lastError: String? = nil,
        lastAttemptAt: Date? = nil
    ) {
        self.id = id
        self.audioFileURL = audioFileURL
        self.createdAt = createdAt
        self.duration = duration
        self.mode = mode
        self.translateEnabled = translateEnabled
        self.targetLanguage = targetLanguage
        self.customTemplateId = customTemplateId
        self.status = status
        self.rawTranscription = rawTranscription
        self.retryCount = retryCount
        self.lastError = lastError
        self.lastAttemptAt = lastAttemptAt
    }

    /// Whether this pending audio can be retried
    var canRetry: Bool {
        status == .pending || status == .failed || status == .partialSuccess
    }

    /// Age of this pending audio
    var age: TimeInterval {
        Date().timeIntervalSince(createdAt)
    }
}

/// Step in the processing pipeline
enum ProcessingStep: String, Codable {
    case idle
    case recording
    case transcribing
    case formatting
    case translating
    case retrying
    case complete
    case failed

    var displayName: String {
        switch self {
        case .idle: return "Ready"
        case .recording: return "Recording"
        case .transcribing: return "Transcribing"
        case .formatting: return "Formatting"
        case .translating: return "Translating"
        case .retrying: return "Retrying"
        case .complete: return "Complete"
        case .failed: return "Failed"
        }
    }

    var icon: String {
        switch self {
        case .idle: return "circle"
        case .recording: return "mic.fill"
        case .transcribing: return "waveform"
        case .formatting: return "text.alignleft"
        case .translating: return "globe"
        case .retrying: return "arrow.clockwise"
        case .complete: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
}

/// Processing status shared between main app and keyboard extension
struct ProcessingStatus: Codable, Equatable {
    var isProcessing: Bool
    var currentStep: ProcessingStep
    var retryAttempt: Int
    var maxRetries: Int
    var errorMessage: String?
    var pendingAutoInsert: Bool
    var lastCompletedText: String?
    var lastUpdateAt: Date?

    static var idle: ProcessingStatus {
        ProcessingStatus(
            isProcessing: false,
            currentStep: .idle,
            retryAttempt: 0,
            maxRetries: 3,
            errorMessage: nil,
            pendingAutoInsert: false,
            lastCompletedText: nil,
            lastUpdateAt: nil
        )
    }

    /// Whether text is ready to be auto-inserted
    var hasTextToInsert: Bool {
        pendingAutoInsert && lastCompletedText != nil && !lastCompletedText!.isEmpty
    }

    /// Progress through retries (0.0 - 1.0)
    var retryProgress: Double {
        guard maxRetries > 0 else { return 0 }
        return Double(retryAttempt) / Double(maxRetries)
    }
}
