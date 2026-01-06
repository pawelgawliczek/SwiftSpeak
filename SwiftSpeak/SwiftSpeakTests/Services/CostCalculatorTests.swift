//
//  CostCalculatorTests.swift
//  SwiftSpeakTests
//
//  Tests for CostCalculator - cost estimation for transcription, translation, and formatting
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

@MainActor
struct CostCalculatorTests {

    // MARK: - Setup

    var calculator: CostCalculator {
        CostCalculator(configManager: RemoteConfigManager.shared)
    }

    // MARK: - Transcription Cost Tests

    @Test func transcriptionCostPerMinute() async {
        let cost = calculator.transcriptionCost(
            provider: .openAI,
            model: "whisper-1",
            durationSeconds: 60
        )

        // OpenAI Whisper is $0.006/minute
        #expect(cost > 0.005 && cost < 0.007, "One minute should cost ~$0.006")
    }

    @Test func transcriptionCostScalesWithDuration() async {
        let oneMinuteCost = calculator.transcriptionCost(
            provider: .openAI,
            model: "whisper-1",
            durationSeconds: 60
        )

        let twoMinuteCost = calculator.transcriptionCost(
            provider: .openAI,
            model: "whisper-1",
            durationSeconds: 120
        )

        #expect(abs(twoMinuteCost - (oneMinuteCost * 2)) < 0.0001, "Two minutes should cost twice as much")
    }

    @Test func transcriptionCost30Seconds() async {
        let cost = calculator.transcriptionCost(
            provider: .openAI,
            model: "whisper-1",
            durationSeconds: 30
        )

        // 30 seconds = 0.5 minutes * $0.006 = $0.003
        #expect(cost > 0.002 && cost < 0.004, "30 seconds should cost ~$0.003")
    }

    @Test func localTranscriptionIsFree() async {
        let cost = calculator.transcriptionCost(
            provider: .local,
            model: "whisperkit-base",
            durationSeconds: 600  // 10 minutes
        )

        #expect(cost == 0, "Local transcription should be free")
    }

    @Test func deepgramTranscriptionCost() async {
        let cost = calculator.transcriptionCost(
            provider: .deepgram,
            model: "nova-2",
            durationSeconds: 60
        )

        // Deepgram Nova-2 is $0.0043/minute
        #expect(cost > 0.003 && cost < 0.006, "One minute should cost ~$0.0043")
    }

    // MARK: - LLM Cost Tests

    @Test func llmCostCalculation() async {
        let cost = calculator.llmCost(
            provider: .openAI,
            model: "gpt-4o-mini",
            inputTokens: 1000,
            outputTokens: 1000
        )

        // gpt-4o-mini: $0.15/1M input, $0.60/1M output
        // 1000 tokens = 0.001M tokens
        // Input: 0.15 * 0.001 = $0.00015
        // Output: 0.60 * 0.001 = $0.00060
        // Total: $0.00075
        #expect(cost > 0.0005 && cost < 0.001, "1K input + 1K output tokens should cost ~$0.00075")
    }

    @Test func llmCostForTypicalFormatting() async {
        // Typical formatting: ~100 input tokens, ~150 output tokens
        let cost = calculator.llmCost(
            provider: .openAI,
            model: "gpt-4o-mini",
            inputTokens: 100,
            outputTokens: 150
        )

        // Very small cost for typical formatting
        #expect(cost > 0 && cost < 0.001, "Typical formatting should cost less than $0.001")
    }

    @Test func localLLMIsFree() async {
        let cost = calculator.llmCost(
            provider: .local,
            model: "apple-intelligence",
            inputTokens: 10000,
            outputTokens: 10000
        )

        #expect(cost == 0, "Local LLM should be free")
    }

    @Test func anthropicLLMCost() async {
        let cost = calculator.llmCost(
            provider: .anthropic,
            model: "claude-3-5-haiku-latest",
            inputTokens: 1000,
            outputTokens: 1000
        )

        // Haiku: $0.80/1M input, $4.00/1M output
        // 1K tokens = 0.001M
        // Input: 0.80 * 0.001 = $0.0008
        // Output: 4.00 * 0.001 = $0.004
        // Total: $0.0048
        #expect(cost > 0.003 && cost < 0.006, "Anthropic Haiku should cost ~$0.0048 per 1K tokens")
    }

    // MARK: - Character Cost Tests

    @Test func characterCostCalculation() async {
        let cost = calculator.characterCost(
            provider: .deepL,
            model: "default",
            characterCount: 1000
        )

        // DeepL: $0.00002/character
        // 1000 chars = $0.02
        #expect(cost > 0.01 && cost < 0.03, "1000 characters should cost ~$0.02")
    }

    @Test func azureCharacterCost() async {
        let cost = calculator.characterCost(
            provider: .azure,
            model: "default",
            characterCount: 1000
        )

        // Azure: $0.00001/character
        // 1000 chars = $0.01
        #expect(cost > 0.005 && cost < 0.015, "Azure 1000 characters should cost ~$0.01")
    }

    // MARK: - Cost Breakdown Tests

    @Test func costBreakdownCalculation() async {
        let breakdown = calculator.calculateCostBreakdown(
            transcriptionProvider: .openAI,
            transcriptionModel: "whisper-1",
            formattingProvider: .openAI,
            formattingModel: "gpt-4o-mini",
            translationProvider: nil,
            translationModel: nil,
            durationSeconds: 60,
            textLength: 500
        )

        #expect(breakdown.transcriptionCost > 0, "Transcription cost should be positive")
        #expect(breakdown.formattingCost > 0, "Formatting cost should be positive")
        #expect(breakdown.translationCost == nil, "Translation cost should be nil when not translating")
        #expect(breakdown.total > breakdown.transcriptionCost, "Total should include formatting")
    }

    @Test func costBreakdownWithTranslation() async {
        let breakdown = calculator.calculateCostBreakdown(
            transcriptionProvider: .openAI,
            transcriptionModel: "whisper-1",
            formattingProvider: .openAI,
            formattingModel: "gpt-4o-mini",
            translationProvider: .deepL,
            translationModel: "default",
            durationSeconds: 60,
            textLength: 500
        )

        #expect(breakdown.transcriptionCost > 0)
        #expect(breakdown.formattingCost > 0)
        #expect(breakdown.translationCost != nil, "Translation cost should be present")
        #expect(breakdown.translationCost! > 0, "Translation cost should be positive")
        #expect(breakdown.total > breakdown.transcriptionCost + breakdown.formattingCost)
    }

    @Test func costBreakdownRawMode() async {
        let breakdown = calculator.calculateCostBreakdown(
            transcriptionProvider: .openAI,
            transcriptionModel: "whisper-1",
            formattingProvider: nil,
            formattingModel: nil,
            translationProvider: nil,
            translationModel: nil,
            durationSeconds: 60,
            textLength: 500
        )

        #expect(breakdown.transcriptionCost > 0)
        #expect(breakdown.formattingCost == 0, "Raw mode should have no formatting cost")
        #expect(breakdown.translationCost == nil)
        #expect(breakdown.total == breakdown.transcriptionCost)
    }

    // MARK: - Monthly Estimation Tests

    @Test func monthlyUsageEstimation() async {
        let monthlyCost = calculator.estimateMonthlyUsageCost(
            transcriptionsPerDay: 10,
            averageDurationSeconds: 30,
            provider: .openAI,
            model: "whisper-1"
        )

        // 10 transcriptions * 30 sec = 5 min/day
        // 5 min * $0.006 = $0.03/day
        // $0.03 * 30 days = $0.90/month
        #expect(monthlyCost > 0.5 && monthlyCost < 1.5, "Monthly cost should be ~$0.90")
    }

    @Test func heavyUserMonthlyEstimation() async {
        let monthlyCost = calculator.estimateMonthlyUsageCost(
            transcriptionsPerDay: 50,
            averageDurationSeconds: 60,
            provider: .openAI,
            model: "whisper-1"
        )

        // 50 * 1 min = 50 min/day
        // 50 * $0.006 = $0.30/day
        // $0.30 * 30 = $9/month
        #expect(monthlyCost > 7 && monthlyCost < 12, "Heavy user should cost ~$9/month")
    }

    // MARK: - Cost Comparison Tests

    @Test func compareCostsReturnsResults() async {
        let comparison = calculator.compareCostsPerMinute(capability: .transcription)

        #expect(!comparison.isEmpty, "Should return at least one provider")
        #expect(comparison.first?.costPerMinute != nil)
    }

    @Test func compareCostsSortedByCost() async {
        let comparison = calculator.compareCostsPerMinute(capability: .transcription)

        guard comparison.count >= 2 else { return }

        // Verify sorted ascending by cost
        for i in 0..<(comparison.count - 1) {
            #expect(comparison[i].costPerMinute <= comparison[i + 1].costPerMinute,
                   "Results should be sorted by cost ascending")
        }
    }

    @Test func localIsAlwaysCheapest() async {
        let comparison = calculator.compareCostsPerMinute(capability: .transcription)

        if let localEntry = comparison.first(where: { $0.provider == .local }) {
            #expect(localEntry.costPerMinute == 0, "Local should be free")
        }
    }

    // MARK: - Convenience Method Tests

    @Test func typicalDictationCost() async {
        let cost = calculator.estimateTypicalDictationCost(provider: .openAI, model: "whisper-1")

        // 30 seconds = 0.5 min * $0.006 = $0.003
        #expect(cost > 0.002 && cost < 0.004)
    }

    @Test func cheapestProviderForTranscription() async {
        let cheapest = calculator.cheapestProvider(for: .transcription)

        // Local should be cheapest (free)
        #expect(cheapest == .local, "Local should be the cheapest transcription provider")
    }

    // MARK: - Fallback Tests

    @Test func fallbackCostWhenRemoteConfigMissing() async {
        // This tests the fallback when pricing is not in remote config
        // The fallback costs are hardcoded in CostCalculator
        let cost = calculator.transcriptionCost(
            provider: .openAI,
            model: "nonexistent-model",
            durationSeconds: 60
        )

        // Should use fallback rate for OpenAI: $0.006/min
        #expect(cost > 0.005 && cost < 0.007)
    }

    // MARK: - Edge Cases

    @Test func zeroDurationCostsNothing() async {
        let cost = calculator.transcriptionCost(
            provider: .openAI,
            model: "whisper-1",
            durationSeconds: 0
        )

        #expect(cost == 0)
    }

    @Test func zeroTokensCostNothing() async {
        let cost = calculator.llmCost(
            provider: .openAI,
            model: "gpt-4o-mini",
            inputTokens: 0,
            outputTokens: 0
        )

        #expect(cost == 0)
    }

    @Test func veryLongTranscriptionCost() async {
        // 1 hour transcription
        let cost = calculator.transcriptionCost(
            provider: .openAI,
            model: "whisper-1",
            durationSeconds: 3600
        )

        // 60 min * $0.006 = $0.36
        #expect(cost > 0.30 && cost < 0.42)
    }
}

// MARK: - CostBreakdown Tests

@MainActor
struct CostBreakdownTests {

    @Test func totalCalculation() {
        let breakdown = CostBreakdown(
            transcriptionCost: 0.10,
            formattingCost: 0.05,
            translationCost: 0.03,
            inputTokens: 100,
            outputTokens: 150
        )

        #expect(breakdown.total == 0.18, "Total should be sum of all costs")
    }

    @Test func totalWithoutTranslation() {
        let breakdown = CostBreakdown(
            transcriptionCost: 0.10,
            formattingCost: 0.05,
            translationCost: nil,
            inputTokens: 100,
            outputTokens: 150
        )

        #expect(breakdown.total == 0.15)
    }

    @Test func costBreakdownEquality() {
        let breakdown1 = CostBreakdown(
            transcriptionCost: 0.10,
            formattingCost: 0.05,
            translationCost: nil,
            inputTokens: 100,
            outputTokens: 150
        )

        let breakdown2 = CostBreakdown(
            transcriptionCost: 0.10,
            formattingCost: 0.05,
            translationCost: nil,
            inputTokens: 100,
            outputTokens: 150
        )

        #expect(breakdown1 == breakdown2)
    }

    @Test func costBreakdownEncodesAndDecodes() throws {
        let original = CostBreakdown(
            transcriptionCost: 0.10,
            formattingCost: 0.05,
            translationCost: 0.03,
            inputTokens: 100,
            outputTokens: 150
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CostBreakdown.self, from: encoded)

        #expect(decoded == original)
    }
}
