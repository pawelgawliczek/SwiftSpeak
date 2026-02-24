//
//  CostCalculator.swift
//  SwiftSpeakCore
//
//  Shared cost calculation for transcription, translation, and formatting
//  Used by both iOS and macOS
//

import Foundation

// MARK: - Cost Calculator Protocol

/// Protocol for cost calculation - allows iOS to extend with RemoteConfig
public protocol CostCalculatorProtocol {
    func transcriptionCost(provider: AIProvider, model: String, durationSeconds: TimeInterval) -> Double
    func llmCost(provider: AIProvider, model: String, inputTokens: Int, outputTokens: Int) -> Double
    func characterCost(provider: AIProvider, model: String, characterCount: Int) -> Double
}

// MARK: - Base Cost Calculator

/// Base cost calculator with fallback rates
/// iOS can extend this with RemoteConfigManager for dynamic pricing
public struct BaseCostCalculator: CostCalculatorProtocol {

    public init() {}

    // MARK: - Transcription Cost

    /// Calculate cost for transcription based on audio duration
    /// - Parameters:
    ///   - provider: The transcription provider
    ///   - model: The model ID (e.g., "whisper-1", "nova-2")
    ///   - durationSeconds: Audio duration in seconds
    /// - Returns: Estimated cost in USD
    public func transcriptionCost(
        provider: AIProvider,
        model: String,
        durationSeconds: TimeInterval
    ) -> Double {
        let costPerMinute: Double
        switch provider {
        case .openAI: costPerMinute = 0.006       // Whisper $0.006/min
        case .deepgram: costPerMinute = 0.0043    // Nova-2 $0.0043/min
        case .assemblyAI: costPerMinute = 0.00617 // Best model ~$0.37/hour = $0.00617/min
        case .elevenLabs: costPerMinute = 0.01
        case .google: costPerMinute = 0.006
        case .azure: costPerMinute = 0.006
        case .local: costPerMinute = 0            // Free (on-device)
        case .whisperKit: costPerMinute = 0       // Free (on-device WhisperKit)
        case .appleSpeech: costPerMinute = 0      // Free (on-device Apple SFSpeechRecognizer)
        case .parakeetMLX: costPerMinute = 0      // Free (on-device Parakeet MLX)
        default: costPerMinute = 0.006
        }
        return costPerMinute * (durationSeconds / 60.0)
    }

    // MARK: - LLM Cost (Token-based)

    /// Calculate cost for LLM operations based on token counts
    /// - Parameters:
    ///   - provider: The LLM provider
    ///   - model: The model ID (e.g., "gpt-4o", "claude-3-5-sonnet-latest")
    ///   - inputTokens: Number of input tokens
    ///   - outputTokens: Number of output tokens
    /// - Returns: Estimated cost in USD
    public func llmCost(
        provider: AIProvider,
        model: String,
        inputTokens: Int,
        outputTokens: Int
    ) -> Double {
        // Rates per million tokens (input, output)
        let rates: (input: Double, output: Double)

        switch provider {
        case .openAI:
            // gpt-4o-mini rates
            rates = (0.15, 0.60)
        case .anthropic:
            // claude-3-5-haiku rates
            rates = (0.80, 4.00)
        case .google:
            // gemini-1.5-flash rates
            rates = (0.075, 0.30)
        case .local, .whisperKit, .appleSpeech, .parakeetMLX:
            // Free (on-device)
            rates = (0, 0)
        default:
            rates = (0.15, 0.60)
        }

        let inputCost = rates.input * Double(inputTokens) / 1_000_000
        let outputCost = rates.output * Double(outputTokens) / 1_000_000
        return inputCost + outputCost
    }

    // MARK: - Character-based Cost

    /// Calculate cost for character-based services (DeepL, Azure Translator)
    /// - Parameters:
    ///   - provider: The translation provider
    ///   - model: The model ID
    ///   - characterCount: Number of characters translated
    /// - Returns: Estimated cost in USD
    public func characterCost(
        provider: AIProvider,
        model: String,
        characterCount: Int
    ) -> Double {
        let costPerChar: Double
        switch provider {
        case .deepL: costPerChar = 0.00002      // $20/million chars
        case .azure: costPerChar = 0.00001      // $10/million chars
        default: costPerChar = 0
        }
        return costPerChar * Double(characterCount)
    }

    // MARK: - Full Cost Breakdown

    /// Calculate complete cost breakdown for a transcription operation
    public func calculateCostBreakdown(
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
        outputTokens: Int? = nil
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

        // 4. Calculate word count from text
        let wordCount: Int?
        if let text = text, !text.isEmpty {
            wordCount = text.split(separator: " ").count
        } else {
            wordCount = textLength > 0 ? max(1, textLength / 5) : nil
        }

        return CostBreakdown(
            transcriptionCost: transcriptionCost,
            formattingCost: formattingCost,
            translationCost: translationCost,
            powerModeCost: nil,
            ragCost: nil,
            predictionCost: nil,
            inputTokens: estimatedInputTokens,
            outputTokens: estimatedOutputTokens,
            wordCount: wordCount
        )
    }

    /// Simple cost calculation for basic transcription (no formatting/translation)
    public func calculateSimpleCost(
        provider: AIProvider,
        durationSeconds: TimeInterval
    ) -> CostBreakdown {
        let cost = transcriptionCost(
            provider: provider,
            model: provider.defaultTranscriptionModel,
            durationSeconds: durationSeconds
        )

        return CostBreakdown(
            transcriptionCost: cost,
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
}

// MARK: - AIProvider Extension (Transcription Models only)

public extension AIProvider {
    /// Default transcription model for each provider
    var defaultTranscriptionModel: String {
        switch self {
        case .openAI: return "whisper-1"
        case .assemblyAI: return "best"
        case .deepgram: return "nova-2"
        case .google: return "latest_long"
        case .azure: return "default"
        case .local: return "whisperkit"
        case .whisperKit: return "whisperkit"
        case .appleSpeech: return "on-device"
        case .parakeetMLX: return "parakeet-tdt"
        default: return "default"
        }
    }
}
