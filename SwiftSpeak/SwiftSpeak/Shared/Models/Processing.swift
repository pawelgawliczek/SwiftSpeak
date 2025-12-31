//
//  Processing.swift
//  SwiftSpeak
//
//  Processing step and metadata models
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation
import SwiftUI

// MARK: - Processing Step Type (Phase 11 - History Enhancement)

/// Type of processing step in the transcription pipeline
enum ProcessingStepType: String, Codable, CaseIterable {
    case transcription
    case formatting
    case translation
    case powerMode
    case ragQuery
    case webhookContext

    var displayName: String {
        switch self {
        case .transcription: return "Transcription"
        case .formatting: return "Formatting"
        case .translation: return "Translation"
        case .powerMode: return "Power Mode"
        case .ragQuery: return "Knowledge Query"
        case .webhookContext: return "Webhook Context"
        }
    }

    var icon: String {
        switch self {
        case .transcription: return "waveform"
        case .formatting: return "text.alignleft"
        case .translation: return "globe"
        case .powerMode: return "bolt.fill"
        case .ragQuery: return "doc.text.magnifyingglass"
        case .webhookContext: return "arrow.triangle.2.circlepath"
        }
    }

    var color: Color {
        switch self {
        case .transcription: return .blue
        case .formatting: return .purple
        case .translation: return .teal
        case .powerMode: return .orange
        case .ragQuery: return .indigo
        case .webhookContext: return .green
        }
    }
}

// MARK: - Processing Step Info

/// Metadata for a single processing step
struct ProcessingStepInfo: Codable, Equatable, Identifiable {
    let id: UUID
    let stepType: ProcessingStepType
    let provider: AIProvider
    let modelName: String
    let startTime: Date
    let endTime: Date
    let inputTokens: Int?
    let outputTokens: Int?
    let cost: Double
    let prompt: String?

    /// Response time in milliseconds
    var responseTimeMs: Int {
        Int((endTime.timeIntervalSince(startTime)) * 1000)
    }

    /// Response time formatted for display
    var responseTimeFormatted: String {
        let ms = responseTimeMs
        if ms < 1000 {
            return "\(ms)ms"
        } else {
            return String(format: "%.1fs", Double(ms) / 1000.0)
        }
    }

    init(
        id: UUID = UUID(),
        stepType: ProcessingStepType,
        provider: AIProvider,
        modelName: String,
        startTime: Date,
        endTime: Date,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        cost: Double,
        prompt: String? = nil
    ) {
        self.id = id
        self.stepType = stepType
        self.provider = provider
        self.modelName = modelName
        self.startTime = startTime
        self.endTime = endTime
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cost = cost
        self.prompt = prompt
    }
}

// MARK: - Processing Metadata

/// Complete processing metadata for a transcription operation
struct ProcessingMetadata: Codable, Equatable {
    let steps: [ProcessingStepInfo]
    let totalProcessingTime: TimeInterval

    // Parameters used during processing
    let sourceLanguageHint: Language?
    let vocabularyApplied: [String]?
    let memorySourcesUsed: [String]?
    let ragDocumentsQueried: [String]?
    let webhooksExecuted: [String]?

    /// Get step by type
    func step(ofType type: ProcessingStepType) -> ProcessingStepInfo? {
        steps.first { $0.stepType == type }
    }

    /// Get all prompts for debugging display
    var allPrompts: [(stepType: ProcessingStepType, prompt: String)] {
        steps.compactMap { step in
            guard let prompt = step.prompt else { return nil }
            return (step.stepType, prompt)
        }
    }

    /// Total response time in milliseconds
    var totalResponseTimeMs: Int {
        Int(totalProcessingTime * 1000)
    }

    /// Total tokens used across all steps
    var totalInputTokens: Int {
        steps.compactMap { $0.inputTokens }.reduce(0, +)
    }

    var totalOutputTokens: Int {
        steps.compactMap { $0.outputTokens }.reduce(0, +)
    }

    init(
        steps: [ProcessingStepInfo],
        totalProcessingTime: TimeInterval,
        sourceLanguageHint: Language? = nil,
        vocabularyApplied: [String]? = nil,
        memorySourcesUsed: [String]? = nil,
        ragDocumentsQueried: [String]? = nil,
        webhooksExecuted: [String]? = nil
    ) {
        self.steps = steps
        self.totalProcessingTime = totalProcessingTime
        self.sourceLanguageHint = sourceLanguageHint
        self.vocabularyApplied = vocabularyApplied
        self.memorySourcesUsed = memorySourcesUsed
        self.ragDocumentsQueried = ragDocumentsQueried
        self.webhooksExecuted = webhooksExecuted
    }
}
