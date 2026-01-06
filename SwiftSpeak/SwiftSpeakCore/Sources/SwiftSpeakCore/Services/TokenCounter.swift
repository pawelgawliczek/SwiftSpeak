//
//  TokenCounter.swift
//  SwiftSpeakCore
//
//  Shared token counting service for estimating context size
//  Used by both iOS and macOS to show token usage in Power Mode
//

import Foundation

/// Token counting utility for estimating LLM context usage
public struct TokenCounter: Sendable {

    // MARK: - Constants

    /// Average characters per token (GPT-style tokenization)
    /// English text averages ~4 chars/token, but varies by content
    private static let charsPerToken: Double = 4.0

    /// Overhead tokens for message formatting, system prompts, etc.
    private static let baseOverhead: Int = 100

    // MARK: - Token Estimation

    /// Estimate token count for a string
    public static func estimateTokens(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        return Int(ceil(Double(text.count) / charsPerToken))
    }

    /// Estimate token count for optional string
    public static func estimateTokens(_ text: String?) -> Int {
        guard let text = text else { return 0 }
        return estimateTokens(text)
    }

    // MARK: - Context Item Counts

    /// Token count breakdown for Power Mode context
    public struct ContextTokens: Sendable {
        public var systemPrompt: Int = 0
        public var globalMemory: Int = 0
        public var powerModeMemory: Int = 0
        public var ragDocuments: Int = 0
        public var obsidianNotes: Int = 0
        public var selectedText: Int = 0
        public var clipboardText: Int = 0
        public var webhookContext: Int = 0

        /// Total tokens across all sources
        public var total: Int {
            systemPrompt + globalMemory + powerModeMemory + ragDocuments +
            obsidianNotes + selectedText + clipboardText + webhookContext + TokenCounter.baseOverhead
        }

        /// Formatted total string (e.g., "~2.5k tokens")
        public var formattedTotal: String {
            formatTokenCount(total)
        }

        /// List of non-zero sources with their counts
        public var breakdown: [(name: String, tokens: Int)] {
            var items: [(String, Int)] = []
            if systemPrompt > 0 { items.append(("System Prompt", systemPrompt)) }
            if globalMemory > 0 { items.append(("Global Memory", globalMemory)) }
            if powerModeMemory > 0 { items.append(("Power Mode Memory", powerModeMemory)) }
            if ragDocuments > 0 { items.append(("RAG Documents", ragDocuments)) }
            if obsidianNotes > 0 { items.append(("Obsidian Notes", obsidianNotes)) }
            if selectedText > 0 { items.append(("Selected Text", selectedText)) }
            if clipboardText > 0 { items.append(("Clipboard", clipboardText)) }
            if webhookContext > 0 { items.append(("Webhook Data", webhookContext)) }
            return items
        }

        public init() {}
    }

    /// Count tokens for a Power Mode configuration
    public static func countContextTokens(
        systemPrompt: String?,
        globalMemory: String?,
        powerModeMemory: String?,
        ragDocuments: [String],
        obsidianNotes: [String],
        selectedText: String?,
        clipboardText: String?,
        webhookContext: String?
    ) -> ContextTokens {
        var tokens = ContextTokens()

        tokens.systemPrompt = estimateTokens(systemPrompt)
        tokens.globalMemory = estimateTokens(globalMemory)
        tokens.powerModeMemory = estimateTokens(powerModeMemory)
        tokens.ragDocuments = ragDocuments.reduce(0) { $0 + estimateTokens($1) }
        tokens.obsidianNotes = obsidianNotes.reduce(0) { $0 + estimateTokens($1) }
        tokens.selectedText = estimateTokens(selectedText)
        tokens.clipboardText = estimateTokens(clipboardText)
        tokens.webhookContext = estimateTokens(webhookContext)

        return tokens
    }

    // MARK: - Formatting

    /// Format token count for display (e.g., 1234 -> "~1.2k")
    public static func formatTokenCount(_ count: Int) -> String {
        if count < 1000 {
            return "~\(count)"
        } else if count < 10000 {
            let k = Double(count) / 1000.0
            return String(format: "~%.1fk", k)
        } else {
            let k = count / 1000
            return "~\(k)k"
        }
    }

    /// Color indicator based on token count (for UI)
    public enum TokenLevel: Sendable {
        case low      // < 2k tokens - green
        case medium   // 2k-8k tokens - yellow
        case high     // 8k-16k tokens - orange
        case critical // > 16k tokens - red

        public static func from(_ count: Int) -> TokenLevel {
            switch count {
            case ..<2000: return .low
            case ..<8000: return .medium
            case ..<16000: return .high
            default: return .critical
            }
        }
    }
}
