//
//  Cost.swift
//  SwiftSpeak
//
//  Cost breakdown and formatting utilities
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

// MARK: - Cost Breakdown (Phase 9)

/// Breakdown of costs for a transcription operation
public struct CostBreakdown: Codable, Equatable {
    public let transcriptionCost: Double
    public let formattingCost: Double
    public let translationCost: Double?
    public let powerModeCost: Double?  // Phase 11 - Separate Power Mode LLM cost
    public let ragCost: Double?        // Phase 11 - RAG embedding query cost
    public let predictionCost: Double? // Phase 13.12 - AI sentence prediction cost

    // Token counts (if available from LLM responses)
    public let inputTokens: Int?
    public let outputTokens: Int?

    // Word count for analytics
    public let wordCount: Int?

    /// Total cost of the operation
    public var total: Double {
        transcriptionCost + formattingCost + (translationCost ?? 0) + (powerModeCost ?? 0) + (ragCost ?? 0) + (predictionCost ?? 0)
    }

    /// Check if this breakdown has any costs
    public var hasCosts: Bool {
        total > 0
    }

    /// Create a zero-cost breakdown
    public static var zero: CostBreakdown {
        CostBreakdown(
            transcriptionCost: 0,
            formattingCost: 0,
            translationCost: nil,
            powerModeCost: nil,
            ragCost: nil,
            predictionCost: nil,
            inputTokens: nil,
            outputTokens: nil,
            wordCount: nil
        )
    }

    // Backward-compatible initializer (without new fields)
    public init(
        transcriptionCost: Double,
        formattingCost: Double,
        translationCost: Double?,
        inputTokens: Int?,
        outputTokens: Int?
    ) {
        self.transcriptionCost = transcriptionCost
        self.formattingCost = formattingCost
        self.translationCost = translationCost
        self.powerModeCost = nil
        self.ragCost = nil
        self.predictionCost = nil
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.wordCount = nil
    }

    // Full initializer with all fields
    public init(
        transcriptionCost: Double,
        formattingCost: Double,
        translationCost: Double?,
        powerModeCost: Double?,
        ragCost: Double?,
        predictionCost: Double? = nil,
        inputTokens: Int?,
        outputTokens: Int?,
        wordCount: Int? = nil
    ) {
        self.transcriptionCost = transcriptionCost
        self.formattingCost = formattingCost
        self.translationCost = translationCost
        self.powerModeCost = powerModeCost
        self.ragCost = ragCost
        self.predictionCost = predictionCost
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.wordCount = wordCount
    }
}

// MARK: - Double Extensions for Cost Formatting

public extension Double {
    /// Format cost with appropriate precision
    public var formattedCost: String {
        if self == 0 {
            return "Free"
        } else if self < 0.0001 {
            return "<$0.0001"
        } else if self < 0.01 {
            return String(format: "$%.4f", self)
        } else if self < 1 {
            return String(format: "$%.3f", self)
        } else {
            return String(format: "$%.2f", self)
        }
    }

    /// Compact cost format for badges (e.g., "3c" or "$1.50")
    public var formattedCostCompact: String {
        if self == 0 {
            return "Free"
        } else if self < 0.001 {
            return "<0.1c"
        } else if self < 0.01 {
            return String(format: "%.1fc", self * 100)
        } else if self < 1 {
            return String(format: "%.0fc", self * 100)
        } else {
            return String(format: "$%.2f", self)
        }
    }
}
