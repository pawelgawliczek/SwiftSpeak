//
//  CostCalculator.swift
//  SwiftSpeak
//
//  Created by SwiftSpeak on 2024-12-28.
//

import Foundation
import SwiftSpeakCore

// MARK: - Cost Calculator

/// Calculates estimated costs for transcription, translation, and formatting operations
@MainActor
struct CostCalculator {

    private let configManager: RemoteConfigManager

    init(configManager: RemoteConfigManager) {
        self.configManager = configManager
    }

    /// Convenience initializer using shared RemoteConfigManager
    init() {
        self.configManager = RemoteConfigManager.shared
    }

    // MARK: - Transcription Cost

    /// Calculate cost for transcription based on audio duration
    /// - Parameters:
    ///   - provider: The transcription provider
    ///   - model: The model ID (e.g., "whisper-1", "nova-2")
    ///   - durationSeconds: Audio duration in seconds
    /// - Returns: Estimated cost in USD
    func transcriptionCost(
        provider: AIProvider,
        model: String,
        durationSeconds: TimeInterval
    ) -> Double {
        guard let pricing = configManager.pricing(for: provider, model: model) else {
            // Fallback to hardcoded costs if remote config unavailable
            return fallbackTranscriptionCost(provider: provider, durationSeconds: durationSeconds)
        }

        guard pricing.isUnitBased, let cost = pricing.cost, let unit = pricing.unit else {
            return 0
        }

        switch unit {
        case "minute":
            return cost * (durationSeconds / 60.0)
        case "second":
            return cost * durationSeconds
        case "15seconds":
            return cost * ceil(durationSeconds / 15.0)
        default:
            return cost * (durationSeconds / 60.0)
        }
    }

    // MARK: - LLM Cost (Token-based)

    /// Calculate cost for LLM operations based on token counts
    /// - Parameters:
    ///   - provider: The LLM provider
    ///   - model: The model ID (e.g., "gpt-4o", "claude-3-5-sonnet-latest")
    ///   - inputTokens: Number of input tokens
    ///   - outputTokens: Number of output tokens
    /// - Returns: Estimated cost in USD
    func llmCost(
        provider: AIProvider,
        model: String,
        inputTokens: Int,
        outputTokens: Int
    ) -> Double {
        guard let pricing = configManager.pricing(for: provider, model: model) else {
            // Fallback to hardcoded costs
            return fallbackLLMCost(provider: provider, inputTokens: inputTokens, outputTokens: outputTokens)
        }

        guard pricing.isTokenBased,
              let inputRate = pricing.inputPerMToken,
              let outputRate = pricing.outputPerMToken else {
            return 0
        }

        let inputCost = inputRate * Double(inputTokens) / 1_000_000
        let outputCost = outputRate * Double(outputTokens) / 1_000_000

        return inputCost + outputCost
    }

    // MARK: - Character-based Cost

    /// Calculate cost for character-based services (DeepL, Azure Translator)
    /// - Parameters:
    ///   - provider: The translation provider
    ///   - model: The model ID
    ///   - characterCount: Number of characters translated
    /// - Returns: Estimated cost in USD
    func characterCost(
        provider: AIProvider,
        model: String,
        characterCount: Int
    ) -> Double {
        guard let pricing = configManager.pricing(for: provider, model: model) else {
            return fallbackCharacterCost(provider: provider, characterCount: characterCount)
        }

        guard pricing.isUnitBased, pricing.unit == "character", let cost = pricing.cost else {
            return 0
        }

        return cost * Double(characterCount)
    }

    // MARK: - Full Cost Breakdown

    /// Calculate complete cost breakdown for a transcription operation
    /// - Parameters:
    ///   - transcriptionProvider: Provider used for transcription
    ///   - transcriptionModel: Model used for transcription
    ///   - formattingProvider: Provider used for formatting (nil if raw mode)
    ///   - formattingModel: Model used for formatting
    ///   - translationProvider: Provider used for translation (nil if not translated)
    ///   - translationModel: Model used for translation
    ///   - durationSeconds: Audio recording duration
    ///   - textLength: Character count of resulting text
    ///   - text: The actual text (used for word count calculation)
    ///   - inputTokens: Estimated input tokens for LLM (default: estimate from text)
    ///   - outputTokens: Estimated output tokens for LLM (default: estimate from text)
    ///   - predictionProvider: Provider used for AI prediction (nil if not a prediction)
    ///   - predictionModel: Model used for prediction
    ///   - predictionInputTokens: Input tokens for prediction
    ///   - predictionOutputTokens: Output tokens for prediction
    /// - Returns: Complete cost breakdown
    func calculateCostBreakdown(
        transcriptionProvider: AIProvider,
        transcriptionModel: String,
        formattingProvider: AIProvider?,
        formattingModel: String?,
        translationProvider: AIProvider?,
        translationModel: String?,
        durationSeconds: TimeInterval,
        textLength: Int,
        text: String? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        predictionProvider: AIProvider? = nil,
        predictionModel: String? = nil,
        predictionInputTokens: Int? = nil,
        predictionOutputTokens: Int? = nil
    ) -> CostBreakdown {

        // 1. Calculate transcription cost
        let transcriptionCost = self.transcriptionCost(
            provider: transcriptionProvider,
            model: transcriptionModel,
            durationSeconds: durationSeconds
        )

        // Estimate tokens if not provided (rough estimate: 1 token ≈ 4 characters)
        let estimatedInputTokens = inputTokens ?? max(50, textLength / 4)
        let estimatedOutputTokens = outputTokens ?? max(75, (textLength / 4) + 50)

        // 2. Calculate formatting cost (if applied)
        var formattingCost: Double = 0
        if let provider = formattingProvider, let model = formattingModel {
            formattingCost = llmCost(
                provider: provider,
                model: model,
                inputTokens: estimatedInputTokens,
                outputTokens: estimatedOutputTokens
            )
        }

        // 3. Calculate translation cost (if applied)
        var translationCost: Double?
        if let provider = translationProvider, let model = translationModel {
            // Check if provider uses character-based pricing
            if provider == .deepL || provider == .azure {
                translationCost = characterCost(
                    provider: provider,
                    model: model,
                    characterCount: textLength
                )
            } else {
                // LLM-based translation
                translationCost = llmCost(
                    provider: provider,
                    model: model,
                    inputTokens: estimatedInputTokens,
                    outputTokens: estimatedOutputTokens
                )
            }
        }

        // 4. Calculate prediction cost (if applied)
        var predictionCost: Double?
        if let provider = predictionProvider, let model = predictionModel {
            let predInput = predictionInputTokens ?? 100
            let predOutput = predictionOutputTokens ?? 200
            predictionCost = llmCost(
                provider: provider,
                model: model,
                inputTokens: predInput,
                outputTokens: predOutput
            )
        }

        // 5. Calculate word count from text
        let wordCount: Int?
        if let text = text, !text.isEmpty {
            wordCount = text.split(separator: " ").count
        } else {
            // Estimate from character count (~5 chars per word average)
            wordCount = textLength > 0 ? max(1, textLength / 5) : nil
        }

        return CostBreakdown(
            transcriptionCost: transcriptionCost,
            formattingCost: formattingCost,
            translationCost: translationCost,
            powerModeCost: nil,
            ragCost: nil,
            predictionCost: predictionCost,
            inputTokens: estimatedInputTokens,
            outputTokens: estimatedOutputTokens,
            wordCount: wordCount
        )
    }

    /// Calculate cost breakdown specifically for AI sentence prediction
    func calculatePredictionCostBreakdown(
        provider: AIProvider,
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        predictions: [String]
    ) -> CostBreakdown {
        let predictionCost = llmCost(
            provider: provider,
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens
        )

        // Word count from all predictions combined
        let wordCount = predictions.reduce(0) { $0 + $1.split(separator: " ").count }

        return CostBreakdown(
            transcriptionCost: 0,
            formattingCost: 0,
            translationCost: nil,
            powerModeCost: nil,
            ragCost: nil,
            predictionCost: predictionCost,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            wordCount: wordCount
        )
    }

    // MARK: - Cost Estimation Helpers

    /// Estimate monthly usage cost based on daily transcription habits
    /// - Parameters:
    ///   - transcriptionsPerDay: Average transcriptions per day
    ///   - averageDurationSeconds: Average duration per transcription
    ///   - provider: Primary provider
    ///   - model: Primary model
    /// - Returns: Estimated monthly cost in USD
    func estimateMonthlyUsageCost(
        transcriptionsPerDay: Int,
        averageDurationSeconds: TimeInterval,
        provider: AIProvider,
        model: String
    ) -> Double {
        let costPerTranscription = transcriptionCost(
            provider: provider,
            model: model,
            durationSeconds: averageDurationSeconds
        )

        return costPerTranscription * Double(transcriptionsPerDay) * 30
    }

    /// Compare costs across providers for a typical use case
    /// - Parameters:
    ///   - durationMinutes: Typical transcription duration in minutes
    ///   - capability: Which capability to compare
    /// - Returns: Dictionary of provider to cost per minute
    func compareCostsPerMinute(
        durationMinutes: Double = 1,
        capability: ProviderUsageCategory
    ) -> [(provider: AIProvider, costPerMinute: Double)] {
        var results: [(provider: AIProvider, costPerMinute: Double)] = []

        for provider in AIProvider.allCases {
            guard configManager.providerSupports(provider, capability: capability) else {
                continue
            }

            guard let defaultModel = configManager.defaultModel(for: provider, capability: capability) else {
                continue
            }

            let cost: Double
            switch capability {
            case .transcription:
                cost = transcriptionCost(
                    provider: provider,
                    model: defaultModel.id,
                    durationSeconds: durationMinutes * 60
                )
            case .translation, .formatting, .powerMode:
                // Estimate ~100 tokens per minute of speech
                cost = llmCost(
                    provider: provider,
                    model: defaultModel.id,
                    inputTokens: Int(100 * durationMinutes),
                    outputTokens: Int(150 * durationMinutes)
                )
            }

            results.append((provider: provider, costPerMinute: cost / durationMinutes))
        }

        return results.sorted { $0.costPerMinute < $1.costPerMinute }
    }

    // MARK: - Fallback Costs

    private func fallbackTranscriptionCost(provider: AIProvider, durationSeconds: TimeInterval) -> Double {
        let costPerMinute: Double
        switch provider {
        case .openAI: costPerMinute = 0.006
        case .deepgram: costPerMinute = 0.0043
        case .assemblyAI: costPerMinute = 0.00025
        case .elevenLabs: costPerMinute = 0.01
        case .google: costPerMinute = 0.006
        case .local: costPerMinute = 0              // Free (on-device WhisperKit)
        case .appleSpeech: costPerMinute = 0        // Free (on-device Apple SFSpeechRecognizer)
        default: costPerMinute = 0.006
        }
        return costPerMinute * (durationSeconds / 60.0)
    }

    private func fallbackLLMCost(provider: AIProvider, inputTokens: Int, outputTokens: Int) -> Double {
        let rates: (input: Double, output: Double)
        switch provider {
        case .openAI: rates = (0.15, 0.60)  // gpt-4o-mini
        case .anthropic: rates = (0.80, 4.00)  // claude-3-5-haiku
        case .google: rates = (0.075, 0.30)  // gemini-1.5-flash
        case .local: rates = (0, 0)
        default: rates = (0.15, 0.60)
        }

        let inputCost = rates.input * Double(inputTokens) / 1_000_000
        let outputCost = rates.output * Double(outputTokens) / 1_000_000
        return inputCost + outputCost
    }

    private func fallbackCharacterCost(provider: AIProvider, characterCount: Int) -> Double {
        let costPerChar: Double
        switch provider {
        case .deepL: costPerChar = 0.00002
        case .azure: costPerChar = 0.00001
        default: costPerChar = 0
        }
        return costPerChar * Double(characterCount)
    }
}

// MARK: - Convenience Extensions

extension CostCalculator {

    /// Quick estimate for a typical 30-second dictation
    func estimateTypicalDictationCost(provider: AIProvider, model: String) -> Double {
        transcriptionCost(provider: provider, model: model, durationSeconds: 30)
    }

    /// Get the cheapest provider for a capability
    func cheapestProvider(for capability: ProviderUsageCategory) -> AIProvider? {
        compareCostsPerMinute(capability: capability).first?.provider
    }
}
