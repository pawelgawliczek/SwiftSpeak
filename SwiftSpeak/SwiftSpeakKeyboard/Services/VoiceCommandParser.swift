//
//  VoiceCommandParser.swift
//  SwiftSpeakKeyboard
//
//  Simple parser for voice commands in edit mode
//  Phase 13.7: Voice Commands Parser
//

import Foundation

/// Parser for voice commands in edit mode
/// This formatter prepares the command + existing text for LLM processing
/// The LLM handles all command interpretation and execution
class VoiceCommandParser {
    // MARK: - Command Formatting

    /// Format a voice command with existing text for LLM processing
    /// - Parameters:
    ///   - command: The transcribed voice command (e.g., "delete the last word")
    ///   - existingText: The current text in the field
    /// - Returns: Formatted prompt for the LLM
    func formatEditRequest(command: String, existingText: String) -> String {
        """
        Existing text:
        \(existingText)

        User command: \(command)

        Apply the command to the existing text and return only the modified text. Do not include explanations or commentary - return just the updated text.
        """
    }

    // MARK: - Command Detection

    /// Check if a transcription looks like a command (vs new content to append)
    /// This is a heuristic check to help the UI decide whether to enter edit mode
    /// - Parameter text: The transcribed text to check
    /// - Returns: True if the text appears to be a voice command
    func looksLikeCommand(_ text: String) -> Bool {
        let lowercased = text.lowercased()

        // Common command indicators
        let commandIndicators = [
            // Deletion
            "delete", "remove", "clear", "erase",

            // Modification
            "fix", "correct", "change", "update", "replace",

            // Formatting
            "make it", "rewrite", "rephrase",

            // Addition
            "add", "insert", "include",

            // Transformation
            "translate", "summarize", "expand", "shorten", "simplify",

            // Correction
            "capitalize", "punctuation", "spelling", "grammar",

            // Structure
            "paragraph", "bullet", "number", "list"
        ]

        // Check if text contains any command indicators
        return commandIndicators.contains { indicator in
            lowercased.contains(indicator)
        }
    }

    /// Check if a command is a deletion command
    /// - Parameter text: The command text to check
    /// - Returns: True if this is a deletion command
    func isDeletionCommand(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let deletionIndicators = ["delete", "remove", "clear", "erase"]
        return deletionIndicators.contains { lowercased.contains($0) }
    }

    /// Check if a command is a translation command
    /// - Parameter text: The command text to check
    /// - Returns: True if this is a translation command
    func isTranslationCommand(_ text: String) -> Bool {
        text.lowercased().contains("translate")
    }

    /// Check if a command is a style change command
    /// - Parameter text: The command text to check
    /// - Returns: True if this is a style change command (formal, casual, etc.)
    func isStyleCommand(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return lowercased.contains("make it") ||
               lowercased.contains("formal") ||
               lowercased.contains("casual") ||
               lowercased.contains("professional") ||
               lowercased.contains("friendly")
    }

    // MARK: - Suggestions

    /// Get suggested follow-up commands based on current text
    /// - Parameter text: The current text in the field
    /// - Returns: Array of suggested voice commands
    func suggestedCommands(for text: String) -> [String] {
        var suggestions: [String] = []

        // If text is long, suggest summarization
        if text.split(separator: " ").count > 50 {
            suggestions.append("Summarize this")
            suggestions.append("Make it shorter")
        }

        // If text is short, suggest expansion
        if text.split(separator: " ").count < 20 {
            suggestions.append("Expand this")
            suggestions.append("Add more detail")
        }

        // Always suggest common edits
        suggestions.append("Fix grammar")
        suggestions.append("Make it formal")
        suggestions.append("Make it casual")

        return suggestions
    }
}
