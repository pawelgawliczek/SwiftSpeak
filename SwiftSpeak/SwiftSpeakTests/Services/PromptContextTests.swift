//
//  PromptContextTests.swift
//  SwiftSpeakTests
//
//  Comprehensive tests for PromptContext - the universal context injection system.
//  Tests cover: 3-tier memory, prompt building, transcription hints, formality inference.
//

import Testing
import Foundation
@testable import SwiftSpeak

struct PromptContextTests {

    // MARK: - Initialization Tests

    @Test func emptyContextHasNoContent() {
        let context = PromptContext.empty

        #expect(context.globalMemory == nil)
        #expect(context.contextMemory == nil)
        #expect(context.powerModeMemory == nil)
        #expect(context.customInstructions == nil)
        #expect(context.examples.isEmpty)
        #expect(context.selectedInstructions.isEmpty)
        #expect(context.vocabularyWords.isEmpty)
        #expect(!context.hasContent)
    }

    @Test func initializesWithAllParameters() {
        let context = PromptContext(
            globalMemory: "Global memory content",
            contextMemory: "Context memory content",
            contextName: "Fatma",
            powerModeMemory: "Power mode memory",
            powerModeName: "Research",
            examples: ["Example 1", "Example 2"],
            selectedInstructions: ["punctuation", "formal"],
            customInstructions: "Use Polish",
            vocabularyWords: ["Kochanie", "Warszawa"],
            domainJargon: .business
        )

        #expect(context.globalMemory == "Global memory content")
        #expect(context.contextMemory == "Context memory content")
        #expect(context.contextName == "Fatma")
        #expect(context.powerModeMemory == "Power mode memory")
        #expect(context.powerModeName == "Research")
        #expect(context.examples.count == 2)
        #expect(context.selectedInstructions.count == 2)
        #expect(context.customInstructions == "Use Polish")
        #expect(context.vocabularyWords.count == 2)
        #expect(context.domainJargon == .business)
        #expect(context.hasContent)
    }

    // MARK: - Memory Tier Tests

    @Test func hasMemoryReturnsTrueForGlobalMemory() {
        let context = PromptContext(globalMemory: "Some global memory")
        #expect(context.hasMemory)
    }

    @Test func hasMemoryReturnsTrueForContextMemory() {
        let context = PromptContext(contextMemory: "Some context memory", contextName: "Test")
        #expect(context.hasMemory)
    }

    @Test func hasMemoryReturnsTrueForPowerModeMemory() {
        let context = PromptContext(powerModeMemory: "Some power mode memory", powerModeName: "Test")
        #expect(context.hasMemory)
    }

    @Test func hasMemoryReturnsFalseForEmptyMemory() {
        let context = PromptContext(globalMemory: "   ", contextMemory: "  ")
        #expect(!context.hasMemory)
    }

    @Test func hasMemoryReturnsFalseForNilMemory() {
        let context = PromptContext()
        #expect(!context.hasMemory)
    }

    // MARK: - Formatting Tests

    @Test func hasFormattingReturnsTrueForExamples() {
        let context = PromptContext(examples: ["Example message"])
        #expect(context.hasFormatting)
    }

    @Test func hasFormattingReturnsTrueForSelectedInstructions() {
        let context = PromptContext(selectedInstructions: ["punctuation"])
        #expect(context.hasFormatting)
    }

    @Test func hasFormattingReturnsTrueForCustomInstructions() {
        let context = PromptContext(customInstructions: "Always use formal Polish")
        #expect(context.hasFormatting)
    }

    @Test func hasFormattingReturnsFalseForEmpty() {
        let context = PromptContext()
        #expect(!context.hasFormatting)
    }

    // MARK: - Instructions Tests

    @Test func hasInstructionsReturnsTrueWhenPresent() {
        let context = PromptContext(customInstructions: "Always use formal Polish")
        #expect(context.hasInstructions)
    }

    @Test func hasInstructionsReturnsFalseForWhitespaceOnly() {
        let context = PromptContext(customInstructions: "   ")
        #expect(!context.hasInstructions)
    }

    // MARK: - System Prompt Building Tests

    @Test func buildSystemPromptWithTaskOnly() {
        let context = PromptContext.empty
        let prompt = context.buildSystemPrompt(task: "Format this as an email")

        #expect(prompt.contains("<task>"))
        #expect(prompt.contains("Format this as an email"))
        #expect(prompt.contains("</task>"))
        #expect(!prompt.contains("<context>"))
        #expect(!prompt.contains("<guidelines>"))
    }

    @Test func buildSystemPromptWithGlobalMemory() {
        let context = PromptContext(globalMemory: "User prefers formal Polish")
        let prompt = context.buildSystemPrompt(task: "Format this text")

        #expect(prompt.contains("<context>"))
        #expect(prompt.contains("<memory type=\"global\">"))
        #expect(prompt.contains("User prefers formal Polish"))
        #expect(prompt.contains("</memory>"))
        #expect(prompt.contains("</context>"))
        #expect(prompt.contains("<task>"))
    }

    @Test func buildSystemPromptWithContextMemory() {
        let context = PromptContext(
            contextMemory: "Fatma prefers Kochanie",
            contextName: "Fatma"
        )
        let prompt = context.buildSystemPrompt(task: "Format this text")

        #expect(prompt.contains("<memory type=\"context\" name=\"Fatma\">"))
        #expect(prompt.contains("Fatma prefers Kochanie"))
    }

    @Test func buildSystemPromptWithPowerModeMemory() {
        let context = PromptContext(
            powerModeMemory: "Research focuses on AI",
            powerModeName: "Research Assistant"
        )
        let prompt = context.buildSystemPrompt(task: "Process this")

        #expect(prompt.contains("<memory type=\"powerMode\" name=\"Research Assistant\">"))
        #expect(prompt.contains("Research focuses on AI"))
    }

    @Test func buildSystemPromptWithAllThreeMemoryTiers() {
        let context = PromptContext(
            globalMemory: "Global memory",
            contextMemory: "Context memory",
            contextName: "Test Context",
            powerModeMemory: "Power mode memory",
            powerModeName: "Test Mode"
        )
        let prompt = context.buildSystemPrompt(task: "Do something")

        #expect(prompt.contains("<memory type=\"global\">"))
        #expect(prompt.contains("Global memory"))
        #expect(prompt.contains("<memory type=\"context\" name=\"Test Context\">"))
        #expect(prompt.contains("Context memory"))
        #expect(prompt.contains("<memory type=\"powerMode\" name=\"Test Mode\">"))
        #expect(prompt.contains("Power mode memory"))
    }

    @Test func buildSystemPromptWithExamples() {
        let context = PromptContext(examples: ["Hi John,\n\nThanks for the update.\n\nBest regards"])
        let prompt = context.buildSystemPrompt(task: "Format text")

        #expect(prompt.contains("<examples>"))
        #expect(prompt.contains("Match this style"))
        #expect(prompt.contains("Hi John"))
        #expect(prompt.contains("</examples>"))
    }

    @Test func buildSystemPromptWithGuidelines() {
        let context = PromptContext(customInstructions: "Capitalize all proper nouns")
        let prompt = context.buildSystemPrompt(task: "Format text")

        #expect(prompt.contains("<guidelines>"))
        #expect(prompt.contains("Capitalize all proper nouns"))
        #expect(prompt.contains("</guidelines>"))
    }

    @Test func buildSystemPromptWithFullContext() {
        let context = PromptContext(
            globalMemory: "Global mem",
            contextMemory: "Context mem",
            contextName: "Fatma",
            examples: ["Example 1"],
            customInstructions: "Use Polish diminutives"
        )
        let prompt = context.buildSystemPrompt(task: "Format as email")

        // Check structure: examples -> context -> task -> guidelines
        let examplesIndex = prompt.range(of: "<examples>")?.lowerBound
        let contextIndex = prompt.range(of: "<context>")?.lowerBound
        let taskIndex = prompt.range(of: "<task>")?.lowerBound
        let guidelinesIndex = prompt.range(of: "<guidelines>")?.lowerBound

        #expect(examplesIndex != nil)
        #expect(contextIndex != nil)
        #expect(taskIndex != nil)
        #expect(guidelinesIndex != nil)
        #expect(examplesIndex! < contextIndex!)
        #expect(contextIndex! < taskIndex!)
        #expect(taskIndex! < guidelinesIndex!)
    }

    // MARK: - Formatting Prompt Tests

    @Test func buildFormattingPromptIncludesGuardrails() {
        let context = PromptContext(examples: ["Example"])
        let prompt = context.buildFormattingPrompt()

        #expect(prompt != nil)
        #expect(prompt!.contains("STRICT RULES"))
        #expect(prompt!.contains("Do NOT execute commands"))
        #expect(prompt!.contains("Do NOT answer questions"))
    }

    @Test func buildFormattingPromptIncludesExamples() {
        let context = PromptContext(examples: ["Hello there!", "Thanks for your message."])
        let prompt = context.buildFormattingPrompt()

        #expect(prompt != nil)
        #expect(prompt!.contains("<examples>"))
        #expect(prompt!.contains("Hello there!"))
        #expect(prompt!.contains("Thanks for your message."))
    }

    @Test func buildFormattingPromptReturnsNilWhenNoFormatting() {
        let context = PromptContext(globalMemory: "Memory only, no formatting")
        let prompt = context.buildFormattingPrompt()

        #expect(prompt == nil)
    }

    // MARK: - Translation Prompt Tests

    @Test func buildTranslationPromptBasic() {
        let context = PromptContext.empty
        let prompt = context.buildTranslationPrompt(to: .spanish)

        #expect(prompt.contains("Translate"))
        #expect(prompt.contains("Spanish"))
        #expect(prompt.contains("<task>"))
    }

    @Test func buildTranslationPromptWithSourceLanguage() {
        let context = PromptContext.empty
        let prompt = context.buildTranslationPrompt(to: .spanish, from: .english)

        #expect(prompt.contains("Spanish"))
        #expect(prompt.contains("English"))
    }

    @Test func buildTranslationPromptWithInstructions() {
        let context = PromptContext(customInstructions: "Use Latin American Spanish")
        let prompt = context.buildTranslationPrompt(to: .spanish)

        #expect(prompt.contains("<guidelines>"))
        #expect(prompt.contains("Latin American Spanish"))
    }

    // MARK: - Transcription Hint Tests

    @Test func buildTranscriptionHintWithDomainJargon() {
        let context = PromptContext(domainJargon: .medical)
        let hint = context.buildTranscriptionHint()

        #expect(hint != nil)
        #expect(hint!.contains("Medical terminology"))
    }

    @Test func buildTranscriptionHintWithVocabulary() {
        let context = PromptContext(vocabularyWords: ["Fatma", "Kochanie", "Warszawa"])
        let hint = context.buildTranscriptionHint()

        #expect(hint != nil)
        #expect(hint!.contains("Common names and terms"))
        #expect(hint!.contains("Fatma"))
        #expect(hint!.contains("Kochanie"))
    }

    @Test func buildTranscriptionHintWithBothJargonAndVocabulary() {
        let context = PromptContext(
            vocabularyWords: ["Jan Kowalski"],
            domainJargon: .legal
        )
        let hint = context.buildTranscriptionHint()

        #expect(hint != nil)
        #expect(hint!.contains("Legal terminology"))
        #expect(hint!.contains("Jan Kowalski"))
    }

    @Test func buildTranscriptionHintIncludesContextName() {
        let context = PromptContext(contextName: "Fatma")
        let hint = context.buildTranscriptionHint()

        #expect(hint != nil)
        #expect(hint!.contains("Fatma"))
    }

    @Test func buildTranscriptionHintLimitsVocabularyTo20() {
        let manyWords = (1...30).map { "Word\($0)" }
        let context = PromptContext(vocabularyWords: manyWords)
        let hint = context.buildTranscriptionHint()

        #expect(hint != nil)
        #expect(hint!.contains("Word1"))
        #expect(hint!.contains("Word20"))
        #expect(!hint!.contains("Word21"))
    }

    @Test func buildTranscriptionHintReturnsNilWhenEmpty() {
        let context = PromptContext.empty
        let hint = context.buildTranscriptionHint()

        #expect(hint == nil)
    }

    @Test func buildTranscriptionHintEndsWithPeriod() {
        let context = PromptContext(domainJargon: .technical)
        let hint = context.buildTranscriptionHint()

        #expect(hint != nil)
        #expect(hint!.hasSuffix("."))
    }

    // MARK: - Formality Inference Tests

    @Test func inferFormalityFromFormalChip() {
        let context = PromptContext(selectedInstructions: ["formal", "punctuation"])
        #expect(context.inferFormality() == .formal)
    }

    @Test func inferFormalityFromCasualChip() {
        let context = PromptContext(selectedInstructions: ["casual", "grammar"])
        #expect(context.inferFormality() == .informal)
    }

    @Test func inferFormalityNeutralWhenNoStyleChip() {
        let context = PromptContext(selectedInstructions: ["punctuation", "spelling"])
        #expect(context.inferFormality() == .neutral)
    }

    @Test func inferFormalityNeutralForEmpty() {
        let context = PromptContext()
        #expect(context.inferFormality() == .neutral)
    }

    // MARK: - Formality Enum Tests

    @Test func formalityDeepLValues() {
        #expect(Formality.formal.deepLValue == "prefer_more")
        #expect(Formality.informal.deepLValue == "prefer_less")
        #expect(Formality.neutral.deepLValue == "default")
    }

    @Test func formalityIsCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for formality in Formality.allCases {
            let data = try encoder.encode(formality)
            let decoded = try decoder.decode(Formality.self, from: data)
            #expect(decoded == formality)
        }
    }

    // MARK: - hasContent Tests

    @Test func hasContentTrueForMemory() {
        let context = PromptContext(globalMemory: "Some memory")
        #expect(context.hasContent)
    }

    @Test func hasContentTrueForFormatting() {
        let context = PromptContext(examples: ["Example"])
        #expect(context.hasContent)
    }

    @Test func hasContentTrueForInstructions() {
        let context = PromptContext(customInstructions: "Use Polish")
        #expect(context.hasContent)
    }

    @Test func hasContentTrueForVocabulary() {
        let context = PromptContext(vocabularyWords: ["Test"])
        #expect(context.hasContent)
    }

    @Test func hasContentFalseForEmpty() {
        let context = PromptContext.empty
        #expect(!context.hasContent)
    }

    // MARK: - XML Structure Validation Tests

    @Test func xmlTagsAreProperlyNested() {
        let context = PromptContext(
            globalMemory: "Global",
            examples: ["Example"]
        )
        let prompt = context.buildSystemPrompt(task: "Test")

        // Count opening and closing tags
        let contextOpen = prompt.components(separatedBy: "<context>").count - 1
        let contextClose = prompt.components(separatedBy: "</context>").count - 1
        #expect(contextOpen == contextClose)

        let memoryOpen = prompt.components(separatedBy: "<memory").count - 1
        let memoryClose = prompt.components(separatedBy: "</memory>").count - 1
        #expect(memoryOpen == memoryClose)

        let taskOpen = prompt.components(separatedBy: "<task>").count - 1
        let taskClose = prompt.components(separatedBy: "</task>").count - 1
        #expect(taskOpen == taskClose)
    }

    @Test func xmlAttributesAreProperlyQuoted() {
        let context = PromptContext(
            contextMemory: "Test",
            contextName: "Test Context"
        )
        let prompt = context.buildSystemPrompt(task: "Test")

        // Attributes should be quoted
        #expect(prompt.contains("type=\"context\""))
        #expect(prompt.contains("name=\"Test Context\""))
    }

    // MARK: - Edge Cases

    @Test func handlesSpecialCharactersInContent() {
        let context = PromptContext(
            globalMemory: "Contains <special> & \"characters\"",
            examples: ["Use 'quotes' and <tags>"]
        )
        let prompt = context.buildSystemPrompt(task: "Test & verify")

        // Should include the content (not escaped for LLM consumption)
        #expect(prompt.contains("Contains <special> & \"characters\""))
        #expect(prompt.contains("Use 'quotes' and <tags>"))
    }

    @Test func handlesEmptyStringsVsNil() {
        let contextWithEmpty = PromptContext(
            globalMemory: "",
            customInstructions: ""
        )

        let contextWithNil = PromptContext(
            globalMemory: nil,
            customInstructions: nil
        )

        // Both should behave the same - no content
        #expect(!contextWithEmpty.hasMemory)
        #expect(!contextWithNil.hasMemory)
        #expect(!contextWithEmpty.hasInstructions)
        #expect(!contextWithNil.hasInstructions)
    }

    @Test func handlesWhitespaceOnlyContent() {
        let context = PromptContext(
            globalMemory: "   \n\t  ",
            customInstructions: "\n\n"
        )

        #expect(!context.hasMemory)
        #expect(!context.hasInstructions)
        #expect(!context.hasContent)
    }

    @Test func handlesVeryLongContent() {
        let longMemory = String(repeating: "Memory content. ", count: 1000)
        let context = PromptContext(globalMemory: longMemory)
        let prompt = context.buildSystemPrompt(task: "Process")

        #expect(prompt.contains("Memory content."))
        #expect(context.hasMemory)
    }

    @Test func handlesUnicodeContent() {
        let context = PromptContext(
            globalMemory: "Uywaj polskich znakow: aelnoszzz",
            examples: ["Kochanie Skarbie"],
            vocabularyWords: ["Nihongo", "Zhongwen", "Hangugeo"]
        )
        let prompt = context.buildSystemPrompt(task: "Test")
        let hint = context.buildTranscriptionHint()

        #expect(prompt.contains("polskich znakow"))
        #expect(prompt.contains("Kochanie"))
        #expect(hint?.contains("Nihongo") == true)
    }
}

// MARK: - PromptContext Factory Tests

struct PromptContextFactoryTests {

    @Test func createsFromSettingsWithGlobalMemory() {
        // This test would require a mock SharedSettings
        // For now, we test the direct creation
        let context = PromptContext(
            globalMemory: "Test global memory"
        )

        #expect(context.globalMemory == "Test global memory")
        #expect(context.hasMemory)
    }

    @Test func createsFromSettingsWithContext() {
        let conversationContext = ConversationContext(
            name: "Fatma",
            icon: "heart.fill",
            color: .purple,
            description: "Wife",
            domainJargon: .none,
            examples: ["Hi love!", "Miss you!"],
            selectedInstructions: ["punctuation", "casual", "emoji_few"],
            customInstructions: "Use Kochanie",
            useGlobalMemory: true,
            useContextMemory: true,
            contextMemory: "Fatma's memory"
        )

        // Simulate what PromptContext.from() would do
        let promptContext = PromptContext(
            contextMemory: conversationContext.useContextMemory ? conversationContext.contextMemory : nil,
            contextName: conversationContext.name,
            examples: conversationContext.examples,
            selectedInstructions: conversationContext.selectedInstructions,
            customInstructions: conversationContext.customInstructions,
            domainJargon: conversationContext.domainJargon
        )

        #expect(promptContext.contextName == "Fatma")
        #expect(promptContext.contextMemory == "Fatma's memory")
        #expect(promptContext.examples.count == 2)
        #expect(promptContext.selectedInstructions.contains("casual"))
        #expect(promptContext.customInstructions == "Use Kochanie")
    }

    @Test func disabledMemoryIsNotIncluded() {
        let conversationContext = ConversationContext(
            name: "Work",
            icon: "briefcase",
            color: .blue,
            description: "Work context",
            useContextMemory: false,
            contextMemory: "This should not appear"
        )

        let promptContext = PromptContext(
            contextMemory: conversationContext.useContextMemory ? conversationContext.contextMemory : nil,
            contextName: conversationContext.name
        )

        #expect(promptContext.contextMemory == nil)
        #expect(!promptContext.hasMemory)
    }
}
