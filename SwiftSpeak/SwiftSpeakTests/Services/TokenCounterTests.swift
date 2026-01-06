//
//  TokenCounterTests.swift
//  SwiftSpeakTests
//
//  Tests for TokenCounter - uses simplified API from SwiftSpeakCore
//

import Testing
import SwiftSpeakCore

@Suite struct TokenCounterTests {
    
    @Test func estimateTokensForEmptyString() {
        let tokens = TokenCounter.estimateTokens("")
        #expect(tokens == 0)
    }
    
    @Test func estimateTokensForSimpleText() {
        let tokens = TokenCounter.estimateTokens("Hello, world!")
        #expect(tokens > 0)
    }
    
    @Test func estimateTokensForLongerText() {
        let text = "This is a longer piece of text that should result in more tokens."
        let tokens = TokenCounter.estimateTokens(text)
        #expect(tokens > 10)
    }
    
    @Test func estimateTokensForNil() {
        let tokens = TokenCounter.estimateTokens(nil as String?)
        #expect(tokens == 0)
    }
}
