//
//  AppleIntelligenceFormattingService.swift
//  SwiftSpeakMac
//
//  On-device text formatting using Apple Intelligence
//  Uses the Foundation Models framework (macOS 26.0+)
//

import Foundation
import SwiftSpeakCore

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Local Provider Errors

/// Errors specific to local on-device AI providers
enum LocalProviderError: LocalizedError, Equatable {
    case appleIntelligenceNotAvailable(reason: String)
    case appleIntelligenceNotEnabled
    case appleIntelligenceModelNotReady
    case appleIntelligenceGenerationFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .appleIntelligenceNotAvailable(let reason):
            return "Apple Intelligence is not available: \(reason)"
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is not enabled. Turn it on in System Settings > Apple Intelligence & Siri."
        case .appleIntelligenceModelNotReady:
            return "Apple Intelligence model is not ready. Please wait for setup to complete."
        case .appleIntelligenceGenerationFailed(let reason):
            return "Text generation failed: \(reason)"
        }
    }
}

/// On-device text formatting using Apple Intelligence
///
/// This service uses Apple's Foundation Models framework which provides access
/// to the on-device large language model that powers Apple Intelligence.
///
/// Requirements:
/// - macOS 26.0+
/// - Apple Silicon (M-series chip)
/// - Apple Intelligence enabled in Settings
@available(macOS 26.0, *)
@MainActor
final class AppleIntelligenceFormattingService: FormattingProvider, StreamingFormattingProvider {

    // MARK: - FormattingProvider Conformance

    let providerId: AIProvider = .local

    var isConfigured: Bool {
        config.isAvailable && config.isEnabled
    }

    var model: String {
        "Apple Intelligence"
    }

    var supportsStreaming: Bool {
        true
    }

    // MARK: - Properties

    private let config: AppleIntelligenceConfig

    #if canImport(FoundationModels)
    private var session: LanguageModelSession?
    #endif

    // MARK: - Initialization

    init(config: AppleIntelligenceConfig) {
        self.config = config
    }

    // MARK: - Availability Check

    /// Check if Apple Intelligence is available on this device
    static func checkAvailability() -> (available: Bool, reason: String?) {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            return (true, nil)
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return (false, "This device doesn't support Apple Intelligence. Requires Mac with M-series chip.")
            case .appleIntelligenceNotEnabled:
                return (false, "Apple Intelligence is not enabled. Turn it on in System Settings > Apple Intelligence & Siri.")
            case .modelNotReady:
                return (false, "Apple Intelligence is still setting up. Please wait and try again.")
            @unknown default:
                return (false, "Apple Intelligence is not available.")
            }
        }
        #else
        return (false, "Foundation Models framework not available. Requires macOS 26.0+.")
        #endif
    }

    // MARK: - FormattingProvider Methods

    func format(
        text: String,
        mode: FormattingMode,
        customPrompt: String?,
        context: PromptContext?
    ) async throws -> String {
        #if canImport(FoundationModels)
        // Check availability
        let (available, reason) = Self.checkAvailability()
        guard available else {
            throw LocalProviderError.appleIntelligenceNotAvailable(reason: reason ?? "Unknown")
        }

        guard config.isEnabled else {
            throw LocalProviderError.appleIntelligenceNotEnabled
        }

        do {
            // Build the system instructions
            let instructions = buildSystemInstructions(mode: mode, context: context)

            // Create a new session with instructions
            let session = LanguageModelSession(instructions: instructions)

            // Build the user prompt
            let prompt = buildPrompt(text: text, mode: mode, customPrompt: customPrompt, context: context)

            // Generate response
            let response = try await session.respond(to: prompt)
            let formattedText = response.content

            guard !formattedText.isEmpty else {
                throw TranscriptionError.emptyResponse
            }

            return formattedText

        } catch let error as LocalProviderError {
            throw error
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw LocalProviderError.appleIntelligenceGenerationFailed(reason: error.localizedDescription)
        }
        #else
        throw LocalProviderError.appleIntelligenceNotAvailable(
            reason: "Foundation Models framework not available"
        )
        #endif
    }

    // MARK: - StreamingFormattingProvider Methods

    func formatStreaming(
        text: String,
        mode: FormattingMode,
        customPrompt: String?,
        context: PromptContext?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                #if canImport(FoundationModels)
                do {
                    // Check availability
                    let (available, reason) = Self.checkAvailability()
                    guard available else {
                        continuation.finish(throwing: LocalProviderError.appleIntelligenceNotAvailable(
                            reason: reason ?? "Unknown"
                        ))
                        return
                    }

                    guard config.isEnabled else {
                        continuation.finish(throwing: LocalProviderError.appleIntelligenceNotEnabled)
                        return
                    }

                    // Build instructions and prompt
                    let instructions = buildSystemInstructions(mode: mode, context: context)
                    let session = LanguageModelSession(instructions: instructions)
                    let prompt = buildPrompt(text: text, mode: mode, customPrompt: customPrompt, context: context)

                    // Stream the response
                    let stream = session.streamResponse(to: prompt)

                    // Iterate over the stream and yield chunks
                    for try await snapshot in stream {
                        // Yield the partial content
                        let partialContent = snapshot.content
                        if !partialContent.isEmpty {
                            continuation.yield(partialContent)
                        }
                    }

                    continuation.finish()

                } catch {
                    continuation.finish(throwing: error)
                }
                #else
                continuation.finish(throwing: LocalProviderError.appleIntelligenceNotAvailable(
                    reason: "Foundation Models framework not available"
                ))
                #endif
            }
        }
    }

    // MARK: - Prompt Building

    private func buildSystemInstructions(mode: FormattingMode, context: PromptContext?) -> String {
        var instructions = """
        You are a professional writing assistant. Your task is to improve and format text while:
        - Preserving the original meaning and intent exactly
        - Fixing grammar, spelling, and punctuation errors
        - Maintaining the speaker's voice and style
        - Keeping technical terms, proper nouns, and names unchanged
        - Never adding new information or opinions

        Output ONLY the formatted text. Do not add explanations, commentary, or notes.
        """

        // Add context-specific instructions
        if let context = context {
            if let globalMemory = context.globalMemory, !globalMemory.isEmpty {
                instructions += "\n\nUser preferences: \(globalMemory)"
            }

            if let contextMemory = context.contextMemory, !contextMemory.isEmpty {
                instructions += "\n\nContext: \(contextMemory)"
            }

            if let customInstructions = context.customInstructions, !customInstructions.isEmpty {
                instructions += "\n\nAdditional instructions: \(customInstructions)"
            }
        }

        return instructions
    }

    private func buildPrompt(
        text: String,
        mode: FormattingMode,
        customPrompt: String?,
        context: PromptContext?
    ) -> String {
        // Use custom prompt if provided
        if let customPrompt = customPrompt, !customPrompt.isEmpty {
            return """
            \(customPrompt)

            Text to format:
            \(text)
            """
        }

        // Build prompt based on formatting mode
        let modeInstructions: String
        switch mode {
        case .raw:
            return text // No formatting needed
        case .email:
            modeInstructions = """
            Format this as a professional email:
            - Add appropriate greeting (Dear/Hi/Hello based on formality)
            - Structure the body with clear paragraphs
            - Add appropriate closing (Best regards/Thanks/Sincerely)
            - Fix any grammar or spelling errors
            - Keep the original message and intent intact
            """
        case .formal:
            modeInstructions = """
            Rewrite this in formal, professional language:
            - Use complete sentences with proper structure
            - Avoid contractions (don't → do not)
            - Use precise, professional vocabulary
            - Fix grammar, spelling, and punctuation
            - Maintain the original meaning exactly
            """
        case .casual:
            modeInstructions = """
            Rewrite this in a casual, conversational tone:
            - Use natural, everyday language
            - Contractions are fine (I'm, don't, won't)
            - Keep it friendly and approachable
            - Fix obvious errors but maintain casual feel
            - Preserve the original meaning
            """
        }

        var prompt = """
        \(modeInstructions)

        Text to format:
        \(text)
        """

        // Add custom instructions if present in Power Mode
        if let context = context, let customInstructions = context.customInstructions, !customInstructions.isEmpty {
            prompt = """
            \(customInstructions)

            Text to process:
            \(text)
            """
        }

        return prompt
    }
}

// MARK: - Fallback for older macOS versions

/// Placeholder for devices that don't support Apple Intelligence
@MainActor
final class AppleIntelligenceFormattingServiceFallback: FormattingProvider {
    let providerId: AIProvider = .local
    var isConfigured: Bool { false }
    var model: String { "Apple Intelligence (Unavailable)" }

    func format(
        text: String,
        mode: FormattingMode,
        customPrompt: String?,
        context: PromptContext?
    ) async throws -> String {
        throw LocalProviderError.appleIntelligenceNotAvailable(
            reason: "Requires macOS 26.0+ and a Mac with Apple Intelligence support"
        )
    }
}
