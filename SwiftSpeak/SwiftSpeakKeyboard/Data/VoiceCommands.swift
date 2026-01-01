//
//  VoiceCommands.swift
//  SwiftSpeakKeyboard
//
//  Voice command examples and patterns for UI hints
//  Phase 13.7: Voice Commands Parser
//

import Foundation

/// Voice command example for UI display
struct VoiceCommandExample: Identifiable {
    let id = UUID()
    let command: String
    let description: String
}

/// Common voice command patterns and examples
struct VoiceCommands {
    // MARK: - Command Examples

    /// Example voice commands for UI hints and documentation
    /// These are NOT executed locally - they're sent to the LLM for processing
    static let examples: [VoiceCommandExample] = [
        // Deletion commands
        VoiceCommandExample(command: "Delete last word", description: "Removes the last word"),
        VoiceCommandExample(command: "Delete that", description: "Removes the last sentence"),
        VoiceCommandExample(command: "Clear all", description: "Removes all text"),

        // Formatting commands
        VoiceCommandExample(command: "New paragraph", description: "Adds paragraph break"),
        VoiceCommandExample(command: "Add punctuation", description: "Adds proper punctuation"),
        VoiceCommandExample(command: "Fix the grammar", description: "Corrects grammar errors"),

        // Tone and style
        VoiceCommandExample(command: "Make it formal", description: "Rewrites in formal tone"),
        VoiceCommandExample(command: "Make it casual", description: "Rewrites in casual tone"),
        VoiceCommandExample(command: "Make it professional", description: "Rewrites in professional tone"),
        VoiceCommandExample(command: "Make it friendly", description: "Rewrites in friendly tone"),

        // Content transformation
        VoiceCommandExample(command: "Summarize this", description: "Creates a summary"),
        VoiceCommandExample(command: "Expand this", description: "Adds more detail"),
        VoiceCommandExample(command: "Shorten this", description: "Makes it more concise"),
        VoiceCommandExample(command: "Simplify this", description: "Uses simpler language"),

        // Translation
        VoiceCommandExample(command: "Translate to Spanish", description: "Translates text to Spanish"),
        VoiceCommandExample(command: "Translate to French", description: "Translates text to French"),
        VoiceCommandExample(command: "Translate to German", description: "Translates text to German"),

        // Corrections
        VoiceCommandExample(command: "Fix spelling", description: "Corrects spelling errors"),
        VoiceCommandExample(command: "Fix typos", description: "Corrects typos"),
        VoiceCommandExample(command: "Capitalize properly", description: "Fixes capitalization"),

        // Additions
        VoiceCommandExample(command: "Add emoji", description: "Adds relevant emoji"),
        VoiceCommandExample(command: "Add bullets", description: "Formats as bullet list"),
        VoiceCommandExample(command: "Number the items", description: "Formats as numbered list"),
    ]

    // MARK: - Command Categories

    /// Deletion command examples
    static let deletionCommands: [VoiceCommandExample] = examples.filter {
        $0.command.lowercased().contains("delete") || $0.command.lowercased().contains("clear")
    }

    /// Formatting command examples
    static let formattingCommands: [VoiceCommandExample] = examples.filter {
        $0.command.lowercased().contains("format") ||
        $0.command.lowercased().contains("punctuation") ||
        $0.command.lowercased().contains("paragraph")
    }

    /// Style command examples
    static let styleCommands: [VoiceCommandExample] = examples.filter {
        $0.command.lowercased().contains("make it")
    }

    /// Transformation command examples
    static let transformationCommands: [VoiceCommandExample] = examples.filter {
        $0.command.lowercased().contains("summarize") ||
        $0.command.lowercased().contains("expand") ||
        $0.command.lowercased().contains("shorten") ||
        $0.command.lowercased().contains("simplify")
    }

    /// Translation command examples
    static let translationCommands: [VoiceCommandExample] = examples.filter {
        $0.command.lowercased().contains("translate")
    }
}
