//
//  TokenCounterTests.swift
//  SwiftSpeakTests
//
//  Phase 11d: Tests for token counting and limits
//

import Testing
import Foundation
@testable import SwiftSpeak

@Suite("TokenCounter Tests")
struct TokenCounterTests {

    // MARK: - Estimation Tests

    @Suite("Token Estimation")
    struct EstimationTests {

        @Test("Empty string returns zero")
        func emptyString() {
            let count = TokenCounter.estimate("")
            #expect(count == 0)
        }

        @Test("Short English text estimation")
        func shortEnglish() {
            let text = "Hello world"  // 11 chars
            let count = TokenCounter.estimate(text)
            // ~11/4 = 2-3 tokens
            #expect(count >= 2)
            #expect(count <= 4)
        }

        @Test("Long English text estimation")
        func longEnglish() {
            let text = "The quick brown fox jumps over the lazy dog. This is a classic pangram used for testing."
            let count = TokenCounter.estimate(text)
            // ~90 chars / 4 = ~22 tokens
            #expect(count >= 15)
            #expect(count <= 30)
        }

        @Test("CJK text estimation is denser")
        func cjkText() {
            let text = "你好世界"  // 4 chars
            let count = TokenCounter.estimate(text)
            // CJK uses ~2 chars/token, so ~2 tokens
            #expect(count >= 1)
            #expect(count <= 4)
        }

        @Test("Mixed text estimation")
        func mixedText() {
            let text = "Hello 你好 World 世界"
            let count = TokenCounter.estimate(text)
            #expect(count >= 4)
            #expect(count <= 12)
        }

        @Test("Precise estimation handles whitespace")
        func preciseWhitespace() {
            let text = "Hello   World"  // Multiple spaces
            let count = TokenCounter.estimatePrecise(text)
            #expect(count >= 2)
        }

        @Test("Precise estimation handles punctuation")
        func precisePunctuation() {
            let text = "Hello, World! How are you?"
            let count = TokenCounter.estimatePrecise(text)
            // Words + punctuation
            #expect(count >= 5)
        }
    }

    // MARK: - Model Limits Tests

    @Suite("Model Limits")
    struct ModelLimitTests {

        @Test("GPT-4o limit")
        func gpt4oLimit() {
            let limit = TokenCounter.limit(for: "gpt-4o")
            #expect(limit == 128000)
        }

        @Test("GPT-4o-mini limit")
        func gpt4oMiniLimit() {
            let limit = TokenCounter.limit(for: "gpt-4o-mini")
            #expect(limit == 128000)
        }

        @Test("GPT-4 limit")
        func gpt4Limit() {
            let limit = TokenCounter.limit(for: "gpt-4")
            #expect(limit == 8192)
        }

        @Test("GPT-3.5-turbo limit")
        func gpt35Limit() {
            let limit = TokenCounter.limit(for: "gpt-3.5-turbo")
            #expect(limit == 4096)
        }

        @Test("GPT-3.5-turbo-16k limit")
        func gpt35_16kLimit() {
            let limit = TokenCounter.limit(for: "gpt-3.5-turbo-16k")
            #expect(limit == 16384)
        }

        @Test("Claude 3 Opus limit")
        func claude3OpusLimit() {
            let limit = TokenCounter.limit(for: "claude-3-opus")
            #expect(limit == 200000)
        }

        @Test("Claude 3 Sonnet limit")
        func claude3SonnetLimit() {
            let limit = TokenCounter.limit(for: "claude-3-sonnet")
            #expect(limit == 200000)
        }

        @Test("Claude 3 Haiku limit")
        func claude3HaikuLimit() {
            let limit = TokenCounter.limit(for: "claude-3-haiku")
            #expect(limit == 200000)
        }

        @Test("Gemini 1.5 Pro limit")
        func gemini15ProLimit() {
            let limit = TokenCounter.limit(for: "gemini-1.5-pro")
            #expect(limit == 2000000)
        }

        @Test("Gemini 1.5 Flash limit")
        func gemini15FlashLimit() {
            let limit = TokenCounter.limit(for: "gemini-1.5-flash")
            #expect(limit == 1000000)
        }

        @Test("Unknown model returns default")
        func unknownModel() {
            let limit = TokenCounter.limit(for: "some-unknown-model")
            #expect(limit == 4096)
        }

        @Test("Case insensitive matching")
        func caseInsensitive() {
            let limit1 = TokenCounter.limit(for: "GPT-4O")
            let limit2 = TokenCounter.limit(for: "gpt-4o")
            let limit3 = TokenCounter.limit(for: "Gpt-4O")
            #expect(limit1 == limit2)
            #expect(limit2 == limit3)
        }

        @Test("Input limit reserves buffer")
        func inputLimitBuffer() {
            let fullLimit = TokenCounter.limit(for: "gpt-4o")
            let inputLimit = TokenCounter.inputLimit(for: "gpt-4o", outputBuffer: 2000)
            #expect(inputLimit == fullLimit - 2000)
        }
    }

    // MARK: - Truncation Tests

    @Suite("Truncation")
    struct TruncationTests {

        @Test("Short text not truncated")
        func shortNotTruncated() {
            let text = "Hello world"
            let result = TokenCounter.truncate(text, maxTokens: 100)
            #expect(result == text)
        }

        @Test("Long text truncated")
        func longTruncated() {
            let text = String(repeating: "word ", count: 100)  // ~500 chars
            let result = TokenCounter.truncate(text, maxTokens: 50)  // ~200 chars
            #expect(result.count < text.count)
            #expect(result.hasSuffix("..."))
        }

        @Test("Truncation breaks at word boundary")
        func wordBoundary() {
            let text = "Hello beautiful wonderful amazing world today"
            let result = TokenCounter.truncate(text, maxTokens: 5)

            // Should not end mid-word (unless very short)
            let lastWord = result.replacingOccurrences(of: "...", with: "").split(separator: " ").last
            if let last = lastWord {
                // Verify it's a complete word from the original
                #expect(text.contains(String(last)))
            }
        }

        @Test("Smart truncation finds sentence boundary")
        func sentenceBoundary() {
            let text = "First sentence. Second sentence. Third sentence. Fourth sentence."
            let result = TokenCounter.truncateSmart(text, maxTokens: 10)

            // Should end at a sentence boundary
            let endsWithPeriod = result.hasSuffix(".") || result.hasSuffix("...")
            #expect(endsWithPeriod)
        }

        @Test("Custom suffix")
        func customSuffix() {
            let text = String(repeating: "word ", count: 100)
            let result = TokenCounter.truncate(text, maxTokens: 20, suffix: "[truncated]")
            #expect(result.hasSuffix("[truncated]"))
        }
    }

    // MARK: - Prompt Limits Tests

    @Suite("Prompt Limits")
    struct PromptLimitsTests {

        @Test("Standard limits are reasonable")
        func standardLimits() {
            #expect(PromptLimits.globalMemory > 0)
            #expect(PromptLimits.contextMemory > 0)
            #expect(PromptLimits.powerModeMemory > 0)
            #expect(PromptLimits.ragChunks > 0)
            #expect(PromptLimits.userInput > 0)
            #expect(PromptLimits.totalPrompt > 0)
        }

        @Test("Limits have hierarchy")
        func limitsHierarchy() {
            // Total should be larger than individual sections
            #expect(PromptLimits.totalPrompt > PromptLimits.globalMemory)
            #expect(PromptLimits.totalPrompt > PromptLimits.userInput)
            #expect(PromptLimits.totalPrompt > PromptLimits.ragChunks)
        }

        @Test("Available for user calculation")
        func availableForUser() {
            let available = PromptLimits.availableForUser(model: "gpt-4o")
            #expect(available > 1000)
            #expect(available < TokenCounter.limit(for: "gpt-4o"))
        }

        @Test("Available for RAG calculation")
        func availableForRAG() {
            let available = PromptLimits.availableForRAG(model: "gpt-4o")
            #expect(available >= 500)
            #expect(available <= PromptLimits.ragChunks * 2)
        }
    }

    // MARK: - Token Budget Tests

    @Suite("Token Budget")
    struct TokenBudgetTests {

        @Test("Budget initialization")
        func initialization() {
            let budget = TokenBudget(total: 1000)
            #expect(budget.total == 1000)
            #expect(budget.used == 0)
            #expect(budget.remaining == 1000)
            #expect(budget.isExhausted == false)
        }

        @Test("Model-based initialization")
        func modelInitialization() {
            let budget = TokenBudget(for: "gpt-4o")
            #expect(budget.total > 0)
            #expect(budget.total < 128000)  // Should be input limit, not full limit
        }

        @Test("Allocation succeeds when budget available")
        func allocationSuccess() {
            var budget = TokenBudget(total: 1000)
            let success = budget.allocate(500)
            #expect(success == true)
            #expect(budget.used == 500)
            #expect(budget.remaining == 500)
        }

        @Test("Allocation fails when budget exhausted")
        func allocationFails() {
            var budget = TokenBudget(total: 100)
            _ = budget.allocate(80)
            let success = budget.allocate(50)  // Only 20 remaining
            #expect(success == false)
            #expect(budget.used == 80)  // Unchanged
        }

        @Test("Force allocation exceeds budget")
        func forceAllocation() {
            var budget = TokenBudget(total: 100)
            budget.forceAllocate(150)
            #expect(budget.used == 150)
            #expect(budget.isExhausted == true)
        }

        @Test("Allocate text truncates when needed")
        func allocateTextTruncates() {
            var budget = TokenBudget(total: 20)
            let longText = String(repeating: "word ", count: 100)
            let result = budget.allocateText(longText)

            #expect(result.count < longText.count)
            #expect(budget.used > 0)
            #expect(budget.remaining < 20)
        }

        @Test("Allocate text respects maxPortion")
        func allocateTextPortion() {
            var budget = TokenBudget(total: 100)
            let text = String(repeating: "word ", count: 50)
            let result = budget.allocateText(text, maxPortion: 0.5)

            // Should only use up to 50% of budget
            #expect(budget.used <= 50)
        }

        @Test("Can fit check")
        func canFitCheck() {
            let budget = TokenBudget(total: 100)
            let shortText = "Hello"
            let longText = String(repeating: "word ", count: 100)

            #expect(budget.canFit(shortText) == true)
            #expect(budget.canFit(longText) == false)
        }

        @Test("Reset clears used")
        func resetBudget() {
            var budget = TokenBudget(total: 100)
            _ = budget.allocate(50)
            budget.reset()
            #expect(budget.used == 0)
            #expect(budget.remaining == 100)
        }

        @Test("Percent used calculation")
        func percentUsed() {
            var budget = TokenBudget(total: 100)
            _ = budget.allocate(25)
            #expect(budget.percentUsed == 25)

            _ = budget.allocate(25)
            #expect(budget.percentUsed == 50)
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases")
    struct EdgeCaseTests {

        @Test("Negative budget treated as zero")
        func negativeBudget() {
            let budget = TokenBudget(total: -100)
            #expect(budget.total == 0)
        }

        @Test("Very long text estimation doesn't overflow")
        func veryLongText() {
            let text = String(repeating: "word ", count: 100000)
            let count = TokenCounter.estimate(text)
            #expect(count > 0)
            #expect(count < text.count)  // Token count should be less than char count
        }

        @Test("Unicode emoji handling")
        func emojiHandling() {
            let text = "Hello 👋 World 🌍 Test 🎉"
            let count = TokenCounter.estimate(text)
            #expect(count > 0)
        }

        @Test("Empty truncation")
        func emptyTruncation() {
            let result = TokenCounter.truncate("", maxTokens: 100)
            #expect(result.isEmpty)
        }

        @Test("Zero token truncation")
        func zeroTruncation() {
            let text = "Hello world"
            let result = TokenCounter.truncate(text, maxTokens: 0)
            #expect(result == "...")
        }
    }
}
