//
//  Transcription.swift
//  SwiftSpeak
//
//  Transcription record and recording state models
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

// MARK: - Transcription Record
struct TranscriptionRecord: Identifiable {
    let id: UUID

    // Text content - Phase 11: Store both raw and final
    let rawTranscribedText: String  // Raw text before formatting (new)
    let text: String                // Final formatted/translated text

    let mode: FormattingMode
    let provider: AIProvider
    let timestamp: Date
    let duration: TimeInterval
    let translated: Bool
    let targetLanguage: Language?

    // Power Mode and Context tracking (Phase 4)
    let powerModeId: UUID?       // nil for regular transcriptions
    let powerModeName: String?   // Cached name for display even if mode deleted
    let contextId: UUID?         // nil if no context was active
    let contextName: String?     // Cached name for display even if context deleted
    let contextIcon: String?     // Cached icon for display

    // Cost tracking (Phase 9)
    let estimatedCost: Double?   // Total estimated cost for this transcription
    let costBreakdown: CostBreakdown?  // Detailed cost breakdown by operation type

    // Processing metadata (Phase 11 - History Enhancement)
    let processingMetadata: ProcessingMetadata?

    /// Whether this record has detailed processing info
    var hasProcessingDetails: Bool {
        processingMetadata != nil && !(processingMetadata?.steps.isEmpty ?? true)
    }

    /// Whether formatting was applied (mode != raw or power mode used)
    var formattingWasApplied: Bool {
        mode != .raw || powerModeId != nil
    }

    /// Whether there's a difference between input and output
    var hasTransformation: Bool {
        rawTranscribedText != text
    }

    init(
        id: UUID = UUID(),
        rawTranscribedText: String? = nil,  // Optional for backward compatibility
        text: String,
        mode: FormattingMode,
        provider: AIProvider,
        timestamp: Date = Date(),
        duration: TimeInterval,
        translated: Bool = false,
        targetLanguage: Language? = nil,
        powerModeId: UUID? = nil,
        powerModeName: String? = nil,
        contextId: UUID? = nil,
        contextName: String? = nil,
        contextIcon: String? = nil,
        estimatedCost: Double? = nil,
        costBreakdown: CostBreakdown? = nil,
        processingMetadata: ProcessingMetadata? = nil
    ) {
        self.id = id
        // For migration: if rawTranscribedText is nil, use text as raw
        self.rawTranscribedText = rawTranscribedText ?? text
        self.text = text
        self.mode = mode
        self.provider = provider
        self.timestamp = timestamp
        self.duration = duration
        self.translated = translated
        self.targetLanguage = targetLanguage
        self.powerModeId = powerModeId
        self.powerModeName = powerModeName
        self.contextId = contextId
        self.contextName = contextName
        self.contextIcon = contextIcon
        self.estimatedCost = estimatedCost
        self.costBreakdown = costBreakdown
        self.processingMetadata = processingMetadata
    }
}

// MARK: - TranscriptionRecord Codable (Backward Compatible)

extension TranscriptionRecord: Codable {
    enum CodingKeys: String, CodingKey {
        case id, text, mode, provider, timestamp, duration, translated, targetLanguage
        case powerModeId, powerModeName, contextId, contextName, contextIcon
        case estimatedCost, costBreakdown
        case rawTranscribedText, processingMetadata  // New fields
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        mode = try container.decode(FormattingMode.self, forKey: .mode)
        provider = try container.decode(AIProvider.self, forKey: .provider)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        translated = try container.decode(Bool.self, forKey: .translated)
        targetLanguage = try container.decodeIfPresent(Language.self, forKey: .targetLanguage)
        powerModeId = try container.decodeIfPresent(UUID.self, forKey: .powerModeId)
        powerModeName = try container.decodeIfPresent(String.self, forKey: .powerModeName)
        contextId = try container.decodeIfPresent(UUID.self, forKey: .contextId)
        contextName = try container.decodeIfPresent(String.self, forKey: .contextName)
        contextIcon = try container.decodeIfPresent(String.self, forKey: .contextIcon)
        estimatedCost = try container.decodeIfPresent(Double.self, forKey: .estimatedCost)
        costBreakdown = try container.decodeIfPresent(CostBreakdown.self, forKey: .costBreakdown)

        // Handle migration: rawTranscribedText might not exist in old records
        rawTranscribedText = try container.decodeIfPresent(String.self, forKey: .rawTranscribedText) ?? text

        // Handle migration: processingMetadata might not exist
        processingMetadata = try container.decodeIfPresent(ProcessingMetadata.self, forKey: .processingMetadata)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(mode, forKey: .mode)
        try container.encode(provider, forKey: .provider)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(duration, forKey: .duration)
        try container.encode(translated, forKey: .translated)
        try container.encodeIfPresent(targetLanguage, forKey: .targetLanguage)
        try container.encodeIfPresent(powerModeId, forKey: .powerModeId)
        try container.encodeIfPresent(powerModeName, forKey: .powerModeName)
        try container.encodeIfPresent(contextId, forKey: .contextId)
        try container.encodeIfPresent(contextName, forKey: .contextName)
        try container.encodeIfPresent(contextIcon, forKey: .contextIcon)
        try container.encodeIfPresent(estimatedCost, forKey: .estimatedCost)
        try container.encodeIfPresent(costBreakdown, forKey: .costBreakdown)
        try container.encode(rawTranscribedText, forKey: .rawTranscribedText)
        try container.encodeIfPresent(processingMetadata, forKey: .processingMetadata)
    }
}

// MARK: - Recording State
enum RecordingState: Equatable {
    case idle
    case recording
    case processing
    case formatting
    case translating
    case retrying(attempt: Int, maxAttempts: Int, reason: String)  // Phase 11e
    case complete(String)
    case error(String)

    var statusText: String {
        switch self {
        case .idle: return "Tap to record"
        case .recording: return "Listening..."
        case .processing: return "Transcribing..."
        case .formatting: return "Formatting..."
        case .translating: return "Translating..."
        case .retrying(let attempt, let max, _):
            return "Retrying (\(attempt)/\(max))..."
        case .complete: return "Done!"
        case .error(let message): return message
        }
    }

    /// Whether the state represents active processing
    var isActive: Bool {
        switch self {
        case .recording, .processing, .formatting, .translating, .retrying:
            return true
        case .idle, .complete, .error:
            return false
        }
    }
}
