//
//  AutocompletePromptBuilder.swift
//  SwiftSpeakCore
//
//  Shared prompt building for AI autocomplete features.
//  Used by sentence predictions and macOS quick actions.
//

import Foundation

/// Builds prompts for AI-powered autocomplete features
/// Shared between sentence predictions and macOS quick actions
public struct AutocompletePromptBuilder {

    // MARK: - Sentence Continuation Prompt

    /// Build a sentence continuation prompt for sentence predictions
    /// - Parameters:
    ///   - typingContext: Current text being typed (last ~100 chars before cursor)
    ///   - recentMessagesContext: Recent conversation messages for context (optional)
    ///   - styleContext: Formatting style from ConversationContext (optional)
    ///   - globalMemory: User's global memory facts (optional)
    ///   - contextMemory: Context-specific memory (optional)
    ///   - screenContext: OCR text from screen capture (optional)
    /// - Returns: A prompt string for the LLM
    public static func buildSentenceContinuationPrompt(
        typingContext: String,
        recentMessagesContext: String? = nil,
        styleContext: String? = nil,
        globalMemory: String? = nil,
        contextMemory: String? = nil,
        screenContext: String? = nil
    ) -> String {
        var parts: [String] = []

        // 1. User information from global memory
        if let global = globalMemory, !global.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("User information:\n\(global)")
        }

        // 2. Context-specific memory
        if let context = contextMemory, !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Context knowledge:\n\(context)")
        }

        // 3. Style/formatting instructions
        if let style = styleContext, !style.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Writing style:\n\(style)")
        }

        // 4. Recent conversation context
        if let recent = recentMessagesContext, !recent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Recent conversation:\n\(recent)")
        }

        // 5. Screen context from OCR (if context capture is enabled)
        if let screen = screenContext, !screen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Truncate to avoid huge prompts (same as sentence prediction: 1500 chars max)
            let truncated = screen.count > 1500 ? String(screen.prefix(1500)) + "..." : screen
            parts.append("Screen context (what user is looking at):\n\(truncated)")
        }

        // 6. Current typing context
        let conversationContext: String
        if typingContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            conversationContext = "The user is starting a new message."
        } else {
            conversationContext = "Current text: \"\(typingContext)\""
        }
        parts.append(conversationContext)

        // Combine all context parts
        let contextSection = parts.joined(separator: "\n\n")

        return """
        \(contextSection)

        Continue this text naturally with a single sentence. The continuation should:
        - Flow seamlessly from what was already typed
        - Match the tone and style of the existing text
        - Be concise (under 15 words)
        - Not repeat what was already written

        Respond with ONLY the continuation text, no quotes or explanation.
        """
    }

    // MARK: - Multi-Option Prediction Prompt

    /// Build a prompt for generating multiple sentence options (4 options)
    /// Used by the full SentencePredictionView panel
    public static func buildMultiOptionPredictionPrompt(
        typingContext: String,
        globalMemory: String? = nil,
        contextMemory: String? = nil,
        contextName: String? = nil
    ) -> String {
        var systemContext = ""

        if let global = globalMemory, !global.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            systemContext += "User information:\n\(global)\n\n"
        }

        if let name = contextName, !name.isEmpty,
           let memory = contextMemory, !memory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            systemContext += "Context (\(name)):\n\(memory)\n\n"
        }

        let conversationContext = typingContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "The user is starting a new message."
            : "Current text: \"\(typingContext)\""

        return """
        \(systemContext)\(conversationContext)

        Generate exactly 4 natural sentence completions or responses the user might want to send next. Each should be a complete, standalone sentence that continues naturally from the context.

        Rules:
        - Make sentences varied in tone and approach
        - Keep sentences concise (under 20 words each)
        - Make them contextually appropriate
        - If starting fresh, provide common greeting/opener options

        Respond with exactly 4 sentences, one per line, no numbering or bullets.
        """
    }

    // MARK: - Context Prompt Building

    /// Build a comprehensive context prompt from formatting instructions
    /// Migrated from MacPowerModeOverlayViewModel for shared use
    ///
    /// - Parameters:
    ///   - examples: Writing examples for few-shot learning
    ///   - formattingInstructions: Selected formatting instructions
    ///   - selectedInstructions: Set of instruction identifiers (e.g., "emoji_lots", "formal")
    ///   - customInstructions: User's free-form custom instructions
    ///   - contextMemory: Context-specific memory
    ///   - useContextMemory: Whether context memory is enabled
    ///   - contextName: Name of the context
    ///   - contextDescription: Description of the context
    /// - Returns: A formatted context prompt string
    public static func buildContextPrompt(
        examples: [String] = [],
        formattingInstructions: [(id: String, promptText: String)] = [],
        selectedInstructions: Set<String> = [],
        customInstructions: String? = nil,
        contextMemory: String? = nil,
        useContextMemory: Bool = false,
        contextName: String? = nil,
        contextDescription: String? = nil
    ) -> String {
        var parts: [String] = []

        // 1. EXAMPLES (highest priority - few-shot learning)
        if !examples.isEmpty {
            let examplesText = examples.enumerated().map { idx, example in
                "Example \(idx + 1):\n\"\"\"\n\(example)\n\"\"\""
            }.joined(separator: "\n\n")
            parts.append("## Writing Examples (MATCH THIS STYLE EXACTLY)\n\(examplesText)")
        }

        // 2. FORMATTING INSTRUCTIONS (from selected chips)
        if !formattingInstructions.isEmpty {
            let rulesText = formattingInstructions.map { "- \($0.promptText)" }.joined(separator: "\n")
            parts.append("## Formatting Rules\n\(rulesText)")
        }

        // 3. EMOJI LEVEL
        if selectedInstructions.contains("emoji_lots") {
            parts.append("## Emoji Usage\nUse emoji generously throughout - this person loves emoji! 😊🎉✨")
        } else if selectedInstructions.contains("emoji_few") {
            parts.append("## Emoji Usage\nUse emoji sparingly, only where they enhance the message.")
        } else if selectedInstructions.contains("emoji_never") {
            parts.append("## Emoji Usage\nDo NOT use any emoji. Keep it text-only.")
        }

        // 4. CUSTOM INSTRUCTIONS (user's free-form rules)
        if let custom = customInstructions, !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("## Custom Instructions\n\(custom)")
        }

        // 5. CONTEXT MEMORY (facts about this context)
        if useContextMemory,
           let memory = contextMemory,
           !memory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("## Context Knowledge\n\(memory)")
        }

        // 6. CONTEXT IDENTITY
        if let name = contextName, !name.isEmpty {
            let desc = contextDescription ?? ""
            parts.append("## Context\nWriting as/for: \(name)" + (desc.isEmpty ? "" : " (\(desc))"))
        }

        if parts.isEmpty {
            return "Write in a professional and friendly tone."
        }

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Style Description

    /// Derive a simple tone description from selected instructions
    /// Kept for compatibility with simpler use cases
    public static func deriveToneDescription(from selectedInstructions: Set<String>) -> String {
        var toneWords: [String] = []

        if selectedInstructions.contains("formal") {
            toneWords.append("formal")
            toneWords.append("professional")
        }
        if selectedInstructions.contains("casual") {
            toneWords.append("casual")
            toneWords.append("friendly")
        }
        if selectedInstructions.contains("concise") {
            toneWords.append("concise")
        }
        if selectedInstructions.contains("emoji_lots") {
            toneWords.append("expressive with emojis")
        } else if selectedInstructions.contains("emoji_never") {
            toneWords.append("without emojis")
        }

        return toneWords.isEmpty ? "professional and friendly" : toneWords.joined(separator: ", ")
    }
}
