//
//  TokenCounter.swift
//  SwiftSpeak
//
//  Phase 11d: Token counting and limit enforcement
//  Prevents prompt overflow and manages token budgets
//

import Foundation

/// Utility for estimating token counts and enforcing limits
struct TokenCounter {

    // MARK: - Token Estimation

    /// Estimate token count from text
    /// Uses 4 characters per token as a reasonable approximation for English
    /// This is conservative; actual tokenization varies by model
    /// - Parameter text: Text to estimate tokens for
    /// - Returns: Estimated token count
    static func estimate(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }

        // Different languages have different token densities
        // English: ~4 chars/token
        // Chinese/Japanese: ~1.5 chars/token
        // Mixed: ~3 chars/token

        let charsPerToken: Double

        // Detect script to adjust estimation
        if containsCJK(text) {
            charsPerToken = 2.0  // CJK is more dense
        } else {
            charsPerToken = 4.0  // Latin/English
        }

        return Int(ceil(Double(text.count) / charsPerToken))
    }

    /// Estimate tokens with character-level precision
    /// More accurate but slower
    static func estimatePrecise(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }

        var tokenCount = 0
        var currentRun = 0
        var lastWasCJK = false

        for char in text {
            let isCJK = char.isCJK
            let isWhitespace = char.isWhitespace
            let isPunctuation = char.isPunctuation

            if isWhitespace || isPunctuation {
                // Whitespace and punctuation end tokens
                if currentRun > 0 {
                    tokenCount += lastWasCJK ? currentRun : max(1, currentRun / 4)
                    currentRun = 0
                }
                if isPunctuation {
                    tokenCount += 1  // Punctuation is usually a separate token
                }
            } else if isCJK != lastWasCJK && currentRun > 0 {
                // Script change ends token
                tokenCount += lastWasCJK ? currentRun : max(1, currentRun / 4)
                currentRun = 1
            } else {
                currentRun += 1
            }

            lastWasCJK = isCJK
        }

        // Handle remaining run
        if currentRun > 0 {
            tokenCount += lastWasCJK ? currentRun : max(1, currentRun / 4)
        }

        return max(1, tokenCount)
    }

    /// Check if text contains CJK characters
    private static func containsCJK(_ text: String) -> Bool {
        for char in text {
            if char.isCJK {
                return true
            }
        }
        return false
    }

    // MARK: - Model Limits

    /// Get context window limit for a model
    /// - Parameter model: Model identifier string
    /// - Returns: Maximum tokens supported
    static func limit(for model: String) -> Int {
        let lowercased = model.lowercased()

        // OpenAI models
        if lowercased.contains("gpt-4o") {
            return 128000
        }
        if lowercased.contains("gpt-4-turbo") || lowercased.contains("gpt-4-0125") {
            return 128000
        }
        if lowercased.contains("gpt-4-32k") {
            return 32768
        }
        if lowercased.contains("gpt-4") {
            return 8192
        }
        if lowercased.contains("gpt-3.5-turbo-16k") {
            return 16384
        }
        if lowercased.contains("gpt-3.5") {
            return 4096
        }

        // Anthropic models
        if lowercased.contains("claude-3-opus") || lowercased.contains("claude-3-sonnet") || lowercased.contains("claude-3-haiku") {
            return 200000
        }
        if lowercased.contains("claude-2") {
            return 100000
        }
        if lowercased.contains("claude") {
            return 100000  // Default for other Claude models
        }

        // Google Gemini models
        if lowercased.contains("gemini-1.5-pro") {
            return 2000000  // 2M context
        }
        if lowercased.contains("gemini-1.5-flash") {
            return 1000000  // 1M context
        }
        if lowercased.contains("gemini-pro") || lowercased.contains("gemini-1.0") {
            return 32000
        }
        if lowercased.contains("gemini") {
            return 32000
        }

        // Local models (typically smaller)
        if lowercased.contains("llama") {
            return 8192
        }
        if lowercased.contains("mistral") {
            return 8192
        }

        // Default conservative limit
        return 4096
    }

    /// Get recommended input limit (leaving room for output)
    /// - Parameters:
    ///   - model: Model identifier
    ///   - outputBuffer: Tokens to reserve for output (default 1000)
    /// - Returns: Maximum recommended input tokens
    static func inputLimit(for model: String, outputBuffer: Int = 1000) -> Int {
        max(limit(for: model) - outputBuffer, 1000)
    }

    // MARK: - Truncation

    /// Truncate text to fit within token limit
    /// - Parameters:
    ///   - text: Text to truncate
    ///   - maxTokens: Maximum tokens allowed
    ///   - suffix: Suffix to append when truncated (default "...")
    /// - Returns: Truncated text
    static func truncate(_ text: String, maxTokens: Int, suffix: String = "...") -> String {
        let estimatedTokens = estimate(text)

        guard estimatedTokens > maxTokens else {
            return text
        }

        // Calculate approximate character limit
        let charRatio = Double(text.count) / Double(estimatedTokens)
        let targetChars = Int(Double(maxTokens) * charRatio) - suffix.count

        guard targetChars > 0 else {
            return suffix
        }

        // Find a good break point (word boundary)
        let prefix = String(text.prefix(targetChars))

        // Try to break at a space
        if let lastSpace = prefix.lastIndex(of: " ") {
            let distance = prefix.distance(from: prefix.startIndex, to: lastSpace)
            if distance > targetChars / 2 {  // Don't break too early
                return String(prefix[..<lastSpace]) + suffix
            }
        }

        return prefix + suffix
    }

    /// Truncate with smart sentence breaking
    static func truncateSmart(_ text: String, maxTokens: Int) -> String {
        let estimatedTokens = estimate(text)

        guard estimatedTokens > maxTokens else {
            return text
        }

        // Calculate approximate character limit
        let charRatio = Double(text.count) / Double(estimatedTokens)
        let targetChars = Int(Double(maxTokens) * charRatio)

        guard targetChars > 10 else {
            return "..."
        }

        let searchRange = String(text.prefix(targetChars))

        // Find sentence boundaries
        let sentenceEnders: [Character] = [".", "!", "?"]
        var lastSentenceEnd: String.Index?

        for (index, char) in searchRange.enumerated() {
            if sentenceEnders.contains(char) {
                let stringIndex = searchRange.index(searchRange.startIndex, offsetBy: index)
                lastSentenceEnd = stringIndex
            }
        }

        if let endIndex = lastSentenceEnd {
            let distance = searchRange.distance(from: searchRange.startIndex, to: endIndex)
            if distance > targetChars / 3 {  // At least 1/3 of target
                return String(searchRange[...endIndex])
            }
        }

        // Fallback to simple truncation
        return truncate(text, maxTokens: maxTokens)
    }
}

// MARK: - Prompt Limits

/// Standard limits for different prompt sections
struct PromptLimits {

    /// Global memory section
    static let globalMemory = 500

    /// Context-specific memory
    static let contextMemory = 400

    /// Power mode memory
    static let powerModeMemory = 300

    /// RAG document chunks
    static let ragChunks = 2000

    /// Webhook context data
    static let webhookContext = 1000

    /// User transcription input
    static let userInput = 4000

    /// Custom template prompt
    static let customTemplate = 500

    /// Vocabulary hints
    static let vocabularyHint = 200

    /// Total prompt limit (conservative default)
    static let totalPrompt = 8000

    /// System prompt base (before user content)
    static let systemPromptBase = 1000

    // MARK: - Dynamic Limits

    /// Calculate available tokens for user content
    /// - Parameter model: Target model
    /// - Returns: Tokens available for user input
    static func availableForUser(model: String) -> Int {
        let modelLimit = TokenCounter.inputLimit(for: model)
        let overhead = systemPromptBase + globalMemory + contextMemory + vocabularyHint
        return max(modelLimit - overhead, 1000)
    }

    /// Calculate available tokens for RAG
    /// - Parameter model: Target model
    /// - Returns: Tokens available for RAG chunks
    static func availableForRAG(model: String) -> Int {
        let modelLimit = TokenCounter.inputLimit(for: model)
        let baseOverhead = systemPromptBase + globalMemory + contextMemory + userInput
        let available = modelLimit - baseOverhead
        return min(max(available, 500), ragChunks * 2)  // Between 500 and 2x default
    }
}

// MARK: - Token Budget

/// Manages a token budget for building prompts
struct TokenBudget {
    let total: Int
    private(set) var used: Int = 0

    /// Remaining tokens
    var remaining: Int { total - used }

    /// Whether budget is exhausted
    var isExhausted: Bool { used >= total }

    /// Percentage used (0-100)
    var percentUsed: Int { total > 0 ? min(100, (used * 100) / total) : 0 }

    init(total: Int) {
        self.total = max(0, total)
    }

    init(for model: String) {
        self.total = TokenCounter.inputLimit(for: model)
    }

    /// Try to allocate tokens
    /// - Parameter count: Tokens to allocate
    /// - Returns: True if successful, false if insufficient budget
    mutating func allocate(_ count: Int) -> Bool {
        guard count <= remaining else { return false }
        used += count
        return true
    }

    /// Force allocate (may exceed budget)
    mutating func forceAllocate(_ count: Int) {
        used += count
    }

    /// Allocate text, truncating if necessary
    /// - Parameters:
    ///   - text: Text to allocate
    ///   - maxPortion: Maximum portion of remaining budget to use (0-1)
    /// - Returns: Allocated text (possibly truncated)
    mutating func allocateText(_ text: String, maxPortion: Double = 1.0) -> String {
        let available = Int(Double(remaining) * min(1.0, max(0.0, maxPortion)))
        let estimated = TokenCounter.estimate(text)

        if estimated <= available {
            used += estimated
            return text
        }

        // Truncate to fit
        let truncated = TokenCounter.truncate(text, maxTokens: available)
        used += TokenCounter.estimate(truncated)
        return truncated
    }

    /// Check if text fits in budget
    func canFit(_ text: String) -> Bool {
        TokenCounter.estimate(text) <= remaining
    }

    /// Reset the budget
    mutating func reset() {
        used = 0
    }
}

// MARK: - Character Extensions

private extension Character {
    /// Check if character is CJK (Chinese, Japanese, Korean)
    var isCJK: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        let value = scalar.value

        // CJK Unified Ideographs
        if (0x4E00...0x9FFF).contains(value) { return true }
        // CJK Extension A
        if (0x3400...0x4DBF).contains(value) { return true }
        // CJK Extension B-F
        if (0x20000...0x2CEAF).contains(value) { return true }
        // Hiragana
        if (0x3040...0x309F).contains(value) { return true }
        // Katakana
        if (0x30A0...0x30FF).contains(value) { return true }
        // Hangul
        if (0xAC00...0xD7AF).contains(value) { return true }

        return false
    }
}
