//
//  Transcription.swift
//  SwiftSpeak
//
//  Transcription record and recording state models
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation
import SwiftSpeakCore

// MARK: - Transcription Source (Phase 13.11)

/// Source of the transcription/processing operation
enum TranscriptionSource: String, Codable {
    case app = "app"                    // Main app recording
    case swiftLink = "swiftLink"        // SwiftLink background recording
    case keyboardAI = "keyboardAI"      // Keyboard AI context/power mode processing
    case edit = "edit"                  // Text editing operation
    case prediction = "prediction"      // AI sentence prediction (Phase 13.12)

    var displayName: String {
        switch self {
        case .app: return "App"
        case .swiftLink: return "SwiftLink"
        case .keyboardAI: return "Keyboard AI"
        case .edit: return "Edit"
        case .prediction: return "Prediction"
        }
    }

    var icon: String {
        switch self {
        case .app: return "mic.fill"
        case .swiftLink: return "link"
        case .keyboardAI: return "keyboard"
        case .edit: return "pencil"
        case .prediction: return "sparkles"
        }
    }
}

// MARK: - Sentence Prediction Context (Phase 13.12)

/// Context for AI sentence prediction operations stored in history
struct SentencePredictionContext: Codable, Equatable {
    /// The typing context that was used for prediction
    let typingContext: String

    /// The full prompt sent to the AI
    let prompt: String

    /// The 4 sentence predictions returned
    let predictions: [String]

    /// The active context name (if any)
    let activeContextName: String?

    init(typingContext: String, prompt: String, predictions: [String], activeContextName: String? = nil) {
        self.typingContext = typingContext
        self.prompt = prompt
        self.predictions = predictions
        self.activeContextName = activeContextName
    }
}

// MARK: - Edit Context (Phase 12)

/// Context for edit operations where user modifies existing text via voice instructions
struct EditContext: Codable, Equatable {
    /// The original text that was in the text field before editing
    let originalText: String

    /// What the user dictated as editing instructions (e.g., "make it more formal")
    let instructions: String

    /// If the original text came from a previous SwiftSpeak transcription, this links to it
    let parentEntryId: UUID?

    init(originalText: String, instructions: String, parentEntryId: UUID? = nil) {
        self.originalText = originalText
        self.instructions = instructions
        self.parentEntryId = parentEntryId
    }
}

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

    // Edit context (Phase 12 - Edit Text Feature)
    let editContext: EditContext?

    // Sentence prediction context (Phase 13.12 - AI Sentence Prediction)
    let sentencePredictionContext: SentencePredictionContext?

    // Source tracking (Phase 13.11 - Keyboard AI)
    let source: TranscriptionSource

    // Memory tracking (Phase 4 enhancement - batch memory updates)
    // State at transcription time (was memory enabled for this tier?)
    let globalMemoryEnabled: Bool
    let contextMemoryEnabled: Bool
    let powerModeMemoryEnabled: Bool
    // Processing tracking (has this been incorporated into memory?)
    var usedForGlobalMemory: Bool
    var usedForContextMemory: Bool
    var usedForPowerModeMemory: Bool

    /// Whether this is an edit operation (modifying existing text)
    var isEditOperation: Bool { editContext != nil }

    /// Whether this is a prediction operation
    var isPrediction: Bool { source == .prediction }

    /// Whether this is from keyboard AI processing
    var isKeyboardAI: Bool { source == .keyboardAI }

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
        processingMetadata: ProcessingMetadata? = nil,
        editContext: EditContext? = nil,
        sentencePredictionContext: SentencePredictionContext? = nil,
        source: TranscriptionSource = .app,
        // Memory tracking
        globalMemoryEnabled: Bool = false,
        contextMemoryEnabled: Bool = false,
        powerModeMemoryEnabled: Bool = false,
        usedForGlobalMemory: Bool = false,
        usedForContextMemory: Bool = false,
        usedForPowerModeMemory: Bool = false
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
        self.editContext = editContext
        self.sentencePredictionContext = sentencePredictionContext
        self.source = source
        // Memory tracking
        self.globalMemoryEnabled = globalMemoryEnabled
        self.contextMemoryEnabled = contextMemoryEnabled
        self.powerModeMemoryEnabled = powerModeMemoryEnabled
        self.usedForGlobalMemory = usedForGlobalMemory
        self.usedForContextMemory = usedForContextMemory
        self.usedForPowerModeMemory = usedForPowerModeMemory
    }
}

// MARK: - TranscriptionRecord Codable (Backward Compatible)

extension TranscriptionRecord: Codable {
    enum CodingKeys: String, CodingKey {
        case id, text, mode, provider, timestamp, duration, translated, targetLanguage
        case powerModeId, powerModeName, contextId, contextName, contextIcon
        case estimatedCost, costBreakdown
        case rawTranscribedText, processingMetadata
        case editContext               // Phase 12
        case sentencePredictionContext // Phase 13.12
        case source                    // Phase 13.11
        // Memory tracking (Phase 4 enhancement)
        case globalMemoryEnabled, contextMemoryEnabled, powerModeMemoryEnabled
        case usedForGlobalMemory, usedForContextMemory, usedForPowerModeMemory
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

        // Handle migration: editContext might not exist (Phase 12)
        editContext = try container.decodeIfPresent(EditContext.self, forKey: .editContext)

        // Handle migration: sentencePredictionContext might not exist (Phase 13.12)
        sentencePredictionContext = try container.decodeIfPresent(SentencePredictionContext.self, forKey: .sentencePredictionContext)

        // Handle migration: source might not exist (Phase 13.11)
        source = try container.decodeIfPresent(TranscriptionSource.self, forKey: .source) ?? .app

        // Handle migration: memory tracking might not exist (Phase 4 enhancement)
        globalMemoryEnabled = try container.decodeIfPresent(Bool.self, forKey: .globalMemoryEnabled) ?? false
        contextMemoryEnabled = try container.decodeIfPresent(Bool.self, forKey: .contextMemoryEnabled) ?? false
        powerModeMemoryEnabled = try container.decodeIfPresent(Bool.self, forKey: .powerModeMemoryEnabled) ?? false
        usedForGlobalMemory = try container.decodeIfPresent(Bool.self, forKey: .usedForGlobalMemory) ?? false
        usedForContextMemory = try container.decodeIfPresent(Bool.self, forKey: .usedForContextMemory) ?? false
        usedForPowerModeMemory = try container.decodeIfPresent(Bool.self, forKey: .usedForPowerModeMemory) ?? false
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
        try container.encodeIfPresent(editContext, forKey: .editContext)
        try container.encodeIfPresent(sentencePredictionContext, forKey: .sentencePredictionContext)
        try container.encode(source, forKey: .source)
        // Memory tracking (Phase 4 enhancement)
        try container.encode(globalMemoryEnabled, forKey: .globalMemoryEnabled)
        try container.encode(contextMemoryEnabled, forKey: .contextMemoryEnabled)
        try container.encode(powerModeMemoryEnabled, forKey: .powerModeMemoryEnabled)
        try container.encode(usedForGlobalMemory, forKey: .usedForGlobalMemory)
        try container.encode(usedForContextMemory, forKey: .usedForContextMemory)
        try container.encode(usedForPowerModeMemory, forKey: .usedForPowerModeMemory)
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
