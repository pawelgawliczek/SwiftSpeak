//
//  PowerModePromptBuilder.swift
//  SwiftSpeakCore
//
//  Shared prompt builder for Power Mode execution.
//  Uses consistent [SECTION]...[/SECTION] format across iOS and macOS.
//
//  SHARED: Used by iOS PowerModeOrchestrator and macOS MacPowerModeOverlayViewModel
//

import Foundation

// MARK: - Power Mode Prompt Input

/// Input data for building Power Mode prompts
/// Platform-agnostic structure containing all context sources
public struct PowerModePromptInput: Sendable {

    // MARK: - Core Properties

    /// Power Mode being executed
    public let powerMode: PowerMode

    /// User's spoken dictation (transcribed text)
    public let userInput: String

    // MARK: - Memory (combined into single block)

    /// Global memory (if enabled)
    public let globalMemory: String?

    /// Context memory (if active context has memory enabled)
    public let contextMemory: String?

    /// Power Mode memory (if Power Mode has memory enabled)
    public let powerModeMemory: String?

    // MARK: - Knowledge Base Context

    /// RAG document chunks (from Power Mode knowledge base)
    public let ragChunks: [RAGChunkInfo]

    /// Obsidian note chunks (from connected vaults)
    public let obsidianChunks: [ObsidianChunkInfo]

    // MARK: - Platform-Specific Context (macOS only)

    /// Selected text from active window (macOS only)
    public let selectedText: String?

    /// Source application for selected text (macOS only)
    public let selectedTextSource: String?

    /// Clipboard content (macOS only - iOS omits this)
    public let clipboardText: String?

    // MARK: - Webhook Context

    /// Context fetched from webhooks
    public let webhookContexts: [WebhookContextInfo]

    // MARK: - Initialization

    public init(
        powerMode: PowerMode,
        userInput: String,
        globalMemory: String? = nil,
        contextMemory: String? = nil,
        powerModeMemory: String? = nil,
        ragChunks: [RAGChunkInfo] = [],
        obsidianChunks: [ObsidianChunkInfo] = [],
        selectedText: String? = nil,
        selectedTextSource: String? = nil,
        clipboardText: String? = nil,
        webhookContexts: [WebhookContextInfo] = []
    ) {
        self.powerMode = powerMode
        self.userInput = userInput
        self.globalMemory = globalMemory
        self.contextMemory = contextMemory
        self.powerModeMemory = powerModeMemory
        self.ragChunks = ragChunks
        self.obsidianChunks = obsidianChunks
        self.selectedText = selectedText
        self.selectedTextSource = selectedTextSource
        self.clipboardText = clipboardText
        self.webhookContexts = webhookContexts
    }
}

// MARK: - RAG Chunk Info

/// Information about a RAG document chunk for prompt injection
public struct RAGChunkInfo: Sendable {
    public let documentName: String
    public let content: String
    public let similarity: Float

    public init(documentName: String, content: String, similarity: Float = 0) {
        self.documentName = documentName
        self.content = content
        self.similarity = similarity
    }
}

// MARK: - Obsidian Chunk Info

/// Information about an Obsidian note chunk for prompt injection
public struct ObsidianChunkInfo: Sendable {
    public let noteTitle: String
    public let vaultName: String
    public let content: String
    public let similarity: Float

    public init(noteTitle: String, vaultName: String, content: String, similarity: Float = 0) {
        self.noteTitle = noteTitle
        self.vaultName = vaultName
        self.content = content
        self.similarity = similarity
    }
}

// MARK: - Webhook Context Info

/// Information about webhook-fetched context for prompt injection
public struct WebhookContextInfo: Sendable {
    public let webhookName: String
    public let content: String

    public init(webhookName: String, content: String) {
        self.webhookName = webhookName
        self.content = content
    }
}

// MARK: - Power Mode Prompt Builder

/// Builds prompts for Power Mode execution using consistent [SECTION] format
/// Shared between iOS and macOS for identical LLM behavior
public enum PowerModePromptBuilder {

    // MARK: - Public API

    /// Build the complete system prompt for Power Mode
    /// - Parameter input: All context sources for the prompt
    /// - Returns: System prompt explaining the structured input format
    public static func buildSystemPrompt(for input: PowerModePromptInput) -> String {
        let powerModeName = input.powerMode.name

        var systemPrompt = """
        You are a "\(powerModeName)" assistant. You will receive structured input with the following components:

        1. [INSTRUCTION] - A predefined task description that defines what this assistant does. This sets the context for your role.

        2. [CONTEXT] - Optional supporting information from various sources (notes, memory). Use this information to inform your response.

        3. [USER_INPUT] - The user's spoken request. This is the MOST IMPORTANT part - it contains the specific action the user wants you to perform right now.

        Your job is to:
        - Understand the task from [INSTRUCTION]
        - Use relevant information from [CONTEXT] to support your response
        - Execute the specific request in [USER_INPUT]
        - The user's spoken input takes priority and drives what you actually do
        """

        // Add output format guidance if specified
        if !input.powerMode.outputFormat.isEmpty {
            systemPrompt += "\n\nOutput Format:\n\(input.powerMode.outputFormat)"
        }

        return systemPrompt
    }

    /// Build the complete user message with all context sections
    /// - Parameter input: All context sources for the prompt
    /// - Returns: User message with [INSTRUCTION], [CONTEXT], and [USER_INPUT] sections
    public static func buildUserMessage(for input: PowerModePromptInput) -> String {
        var parts: [String] = []

        // 1. INSTRUCTION section
        parts.append("[INSTRUCTION]")
        parts.append(input.powerMode.instruction)
        parts.append("[/INSTRUCTION]")

        // 2. CONTEXT section (only if we have any context)
        let contextSection = buildContextSection(for: input)
        if !contextSection.isEmpty {
            parts.append("")
            parts.append("[CONTEXT]")
            parts.append(contextSection)
            parts.append("[/CONTEXT]")
        }

        // 3. USER_INPUT section
        parts.append("")
        parts.append("[USER_INPUT]")
        parts.append(input.userInput)
        parts.append("[/USER_INPUT]")

        return parts.joined(separator: "\n")
    }

    /// Build both system and user message as a tuple
    /// Convenience method for orchestrators
    public static func buildPrompt(for input: PowerModePromptInput) -> (systemPrompt: String, userMessage: String) {
        return (
            buildSystemPrompt(for: input),
            buildUserMessage(for: input)
        )
    }

    // MARK: - Context Section Building

    private static func buildContextSection(for input: PowerModePromptInput) -> String {
        var sections: [String] = []

        // 1. Selected Text (macOS only - iOS passes nil)
        if let selectedText = input.selectedText, !selectedText.isEmpty {
            let source = input.selectedTextSource ?? "Unknown"
            sections.append("  [SELECTED_TEXT from=\"\(source)\"]")
            sections.append(selectedText.indented(by: 4))
            sections.append("  [/SELECTED_TEXT]")
        }

        // 2. Clipboard (macOS only - iOS passes nil)
        if let clipboard = input.clipboardText, !clipboard.isEmpty {
            sections.append("  [CLIPBOARD]")
            sections.append(clipboard.indented(by: 4))
            sections.append("  [/CLIPBOARD]")
        }

        // 3. Knowledge Base (RAG docs + Obsidian notes)
        let knowledgeSection = buildKnowledgeSection(for: input)
        if !knowledgeSection.isEmpty {
            sections.append("  [KNOWLEDGE_BASE]")
            sections.append(knowledgeSection)
            sections.append("  [/KNOWLEDGE_BASE]")
        }

        // 4. Webhook Context
        if !input.webhookContexts.isEmpty {
            sections.append("  [WEBHOOKS]")
            for webhook in input.webhookContexts {
                sections.append("    [WEBHOOK name=\"\(webhook.webhookName)\"]")
                // Truncate very long responses
                let truncated = webhook.content.count > 2000
                    ? String(webhook.content.prefix(2000)) + "..."
                    : webhook.content
                sections.append(truncated.indented(by: 6))
                sections.append("    [/WEBHOOK]")
            }
            sections.append("  [/WEBHOOKS]")
        }

        // 5. Memory (combined single block)
        let memorySection = buildMemorySection(for: input)
        if !memorySection.isEmpty {
            sections.append("  [MEMORY]")
            sections.append(memorySection.indented(by: 4))
            sections.append("  [/MEMORY]")
        }

        return sections.joined(separator: "\n")
    }

    private static func buildKnowledgeSection(for input: PowerModePromptInput) -> String {
        var notes: [String] = []

        // RAG document chunks
        for chunk in input.ragChunks.prefix(5) {
            notes.append("    [DOCUMENT title=\"\(chunk.documentName)\"]")
            notes.append(chunk.content.indented(by: 6))
            notes.append("    [/DOCUMENT]")
        }

        // Obsidian note chunks
        for chunk in input.obsidianChunks.prefix(5) {
            let title = "\(chunk.noteTitle) (\(chunk.vaultName))"
            notes.append("    [NOTE title=\"\(title)\"]")
            notes.append(chunk.content.indented(by: 6))
            notes.append("    [/NOTE]")
        }

        return notes.joined(separator: "\n")
    }

    private static func buildMemorySection(for input: PowerModePromptInput) -> String {
        var memories: [String] = []

        // Global memory
        if let global = input.globalMemory, !global.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            memories.append(global)
        }

        // Context memory
        if let context = input.contextMemory, !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            memories.append(context)
        }

        // Power Mode memory
        if let powerMode = input.powerModeMemory, !powerMode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            memories.append(powerMode)
        }

        return memories.joined(separator: "\n\n")
    }
}

// MARK: - String Extension

private extension String {
    /// Indent each line by the specified number of spaces
    func indented(by spaces: Int) -> String {
        let indent = String(repeating: " ", count: spaces)
        return self.split(separator: "\n", omittingEmptySubsequences: false)
            .map { indent + $0 }
            .joined(separator: "\n")
    }
}
