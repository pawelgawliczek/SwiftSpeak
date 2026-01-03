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
public enum ProcessingStepType: String, Codable, CaseIterable {
    case transcription
    case formatting
    case translation
    case powerMode
    case ragQuery
    case webhookContext

    public var displayName: String {
        switch self {
        case .transcription: return "Transcription"
        case .formatting: return "Formatting"
        case .translation: return "Translation"
        case .powerMode: return "Power Mode"
        case .ragQuery: return "Knowledge Query"
        case .webhookContext: return "Webhook Context"
        }
    }

    public var icon: String {
        switch self {
        case .transcription: return "waveform"
        case .formatting: return "text.alignleft"
        case .translation: return "globe"
        case .powerMode: return "bolt.fill"
        case .ragQuery: return "doc.text.magnifyingglass"
        case .webhookContext: return "arrow.triangle.2.circlepath"
        }
    }

    public var color: Color {
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
public struct ProcessingStepInfo: Codable, Equatable, Identifiable {
    public let id: UUID
    public let stepType: ProcessingStepType
    public let provider: AIProvider
    public let modelName: String
    public let startTime: Date
    public let endTime: Date
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let cost: Double
    public let prompt: String?

    /// Response time in milliseconds
    public var responseTimeMs: Int {
        Int((endTime.timeIntervalSince(startTime)) * 1000)
    }

    /// Response time formatted for display
    public var responseTimeFormatted: String {
        let ms = responseTimeMs
        if ms < 1000 {
            return "\(ms)ms"
        } else {
            return String(format: "%.1fs", Double(ms) / 1000.0)
        }
    }

    public init(
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
public struct ProcessingMetadata: Codable, Equatable {
    public let steps: [ProcessingStepInfo]
    public let totalProcessingTime: TimeInterval

    // Parameters used during processing
    public let sourceLanguageHint: Language?
    public let vocabularyApplied: [String]?
    public let memorySourcesUsed: [String]?
    public let ragDocumentsQueried: [String]?
    public let webhooksExecuted: [String]?

    /// Get step by type
    public func step(ofType type: ProcessingStepType) -> ProcessingStepInfo? {
        steps.first { $0.stepType == type }
    }

    /// Get all prompts for debugging display
    public var allPrompts: [(stepType: ProcessingStepType, prompt: String)] {
        steps.compactMap { step in
            guard let prompt = step.prompt else { return nil }
            return (step.stepType, prompt)
        }
    }

    /// Total response time in milliseconds
    public var totalResponseTimeMs: Int {
        Int(totalProcessingTime * 1000)
    }

    /// Total tokens used across all steps
    public var totalInputTokens: Int {
        steps.compactMap { $0.inputTokens }.reduce(0, +)
    }

    public var totalOutputTokens: Int {
        steps.compactMap { $0.outputTokens }.reduce(0, +)
    }

    public init(
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
