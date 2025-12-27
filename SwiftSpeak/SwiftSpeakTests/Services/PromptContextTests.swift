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
        #expect(context.toneDescription == nil)
        #expect(context.customInstructions == nil)
        #expect(context.languageHints.isEmpty)
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
            toneDescription: "Warm and caring",
            customInstructions: "Use Polish",
            languageHints: [.polish, .english],
            vocabularyWords: ["Kochanie", "Warszawa"]
        )

        #expect(context.globalMemory == "Global memory content")
        #expect(context.contextMemory == "Context memory content")
        #expect(context.contextName == "Fatma")
        #expect(context.powerModeMemory == "Power mode memory")
        #expect(context.powerModeName == "Research")
        #expect(context.toneDescription == "Warm and caring")
        #expect(context.customInstructions == "Use Polish")
        #expect(context.languageHints.count == 2)
        #expect(context.vocabularyWords.count == 2)
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

    // MARK: - Tone Tests

    @Test func hasToneReturnsTrueWhenTonePresent() {
        let context = PromptContext(toneDescription: "Professional and formal")
        #expect(context.hasTone)
    }

    @Test func hasToneReturnsFalseForWhitespaceOnly() {
        let context = PromptContext(toneDescription: "   \n  ")
        #expect(!context.hasTone)
    }

    @Test func hasToneReturnsFalseForNil() {
        let context = PromptContext()
        #expect(!context.hasTone)
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

    @Test func buildSystemPromptWithTone() {
        let context = PromptContext(toneDescription: "Warm, caring, playful")
        let prompt = context.buildSystemPrompt(task: "Format text")

        #expect(prompt.contains("<context>"))
        #expect(prompt.contains("<tone>"))
        #expect(prompt.contains("Warm, caring, playful"))
        #expect(prompt.contains("</tone>"))
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
            toneDescription: "Warm and caring",
            customInstructions: "Use Polish diminutives"
        )
        let prompt = context.buildSystemPrompt(task: "Format as email")

        // Check structure order: context -> task -> guidelines
        let contextIndex = prompt.range(of: "<context>")?.lowerBound
        let taskIndex = prompt.range(of: "<task>")?.lowerBound
        let guidelinesIndex = prompt.range(of: "<guidelines>")?.lowerBound

        #expect(contextIndex != nil)
        #expect(taskIndex != nil)
        #expect(guidelinesIndex != nil)
        #expect(contextIndex! < taskIndex!)
        #expect(taskIndex! < guidelinesIndex!)
    }

    @Test func buildSystemPromptPreservesMultilineContent() {
        let multilineTone = """
        Be warm and caring.
        Use Polish endearments.
        Keep it playful.
        """
        let context = PromptContext(toneDescription: multilineTone)
        let prompt = context.buildSystemPrompt(task: "Format")

        #expect(prompt.contains("Be warm and caring."))
        #expect(prompt.contains("Use Polish endearments."))
        #expect(prompt.contains("Keep it playful."))
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

    @Test func buildTranslationPromptWithTone() {
        let context = PromptContext(toneDescription: "Formal and respectful")
        let prompt = context.buildTranslationPrompt(to: .german)

        #expect(prompt.contains("<tone>"))
        #expect(prompt.contains("Formal and respectful"))
        #expect(prompt.contains("German"))
    }

    @Test func buildTranslationPromptWithInstructions() {
        let context = PromptContext(customInstructions: "Use Latin American Spanish")
        let prompt = context.buildTranslationPrompt(to: .spanish)

        #expect(prompt.contains("<guidelines>"))
        #expect(prompt.contains("Latin American Spanish"))
    }

    // MARK: - Transcription Hint Tests

    @Test func buildTranscriptionHintWithLanguages() {
        let context = PromptContext(languageHints: [.polish, .english])
        let hint = context.buildTranscriptionHint()

        #expect(hint != nil)
        #expect(hint!.contains("Polish"))
        #expect(hint!.contains("English"))
        #expect(hint!.contains("This audio may contain"))
    }

    @Test func buildTranscriptionHintWithVocabulary() {
        let context = PromptContext(vocabularyWords: ["Fatma", "Kochanie", "Warszawa"])
        let hint = context.buildTranscriptionHint()

        #expect(hint != nil)
        #expect(hint!.contains("Common names and terms"))
        #expect(hint!.contains("Fatma"))
        #expect(hint!.contains("Kochanie"))
    }

    @Test func buildTranscriptionHintWithBothLanguagesAndVocabulary() {
        let context = PromptContext(
            languageHints: [.polish],
            vocabularyWords: ["Jan Kowalski"]
        )
        let hint = context.buildTranscriptionHint()

        #expect(hint != nil)
        #expect(hint!.contains("Polish"))
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
        let context = PromptContext(languageHints: [.english])
        let hint = context.buildTranscriptionHint()

        #expect(hint != nil)
        #expect(hint!.hasSuffix("."))
    }

    // MARK: - Formality Inference Tests

    @Test func inferFormalityFromFormalTone() {
        let formalTones = [
            "Professional and formal",
            "Business tone, very formal",
            "Official communication style",
            "Respectful and polite",
            "Corporate language"
        ]

        for tone in formalTones {
            let context = PromptContext(toneDescription: tone)
            #expect(context.inferFormality() == .formal, "Expected formal for: \(tone)")
        }
    }

    @Test func inferFormalityFromInformalTone() {
        let informalTones = [
            "Casual and friendly",
            "Informal, relaxed style",
            "Playful and fun",
            "Conversational tone",
            "Warm and friendly"
        ]

        for tone in informalTones {
            let context = PromptContext(toneDescription: tone)
            #expect(context.inferFormality() == .informal, "Expected informal for: \(tone)")
        }
    }

    @Test func inferFormalityNeutralForAmbiguous() {
        let neutralTones = [
            "Clear and concise",
            "Standard writing style",
            "Just normal text"
        ]

        for tone in neutralTones {
            let context = PromptContext(toneDescription: tone)
            #expect(context.inferFormality() == .neutral, "Expected neutral for: \(tone)")
        }
    }

    @Test func inferFormalityNeutralForEmptyTone() {
        let context = PromptContext(toneDescription: "")
        #expect(context.inferFormality() == .neutral)
    }

    @Test func inferFormalityNeutralForNilTone() {
        let context = PromptContext()
        #expect(context.inferFormality() == .neutral)
    }

    @Test func inferFormalityIsCaseInsensitive() {
        let context1 = PromptContext(toneDescription: "FORMAL")
        let context2 = PromptContext(toneDescription: "Formal")
        let context3 = PromptContext(toneDescription: "formal")

        #expect(context1.inferFormality() == .formal)
        #expect(context2.inferFormality() == .formal)
        #expect(context3.inferFormality() == .formal)
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

    @Test func hasContentTrueForTone() {
        let context = PromptContext(toneDescription: "Warm")
        #expect(context.hasContent)
    }

    @Test func hasContentTrueForInstructions() {
        let context = PromptContext(customInstructions: "Use Polish")
        #expect(context.hasContent)
    }

    @Test func hasContentTrueForLanguageHints() {
        let context = PromptContext(languageHints: [.polish])
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
            toneDescription: "Warm"
        )
        let prompt = context.buildSystemPrompt(task: "Test")

        // Count opening and closing tags
        let contextOpen = prompt.components(separatedBy: "<context>").count - 1
        let contextClose = prompt.components(separatedBy: "</context>").count - 1
        #expect(contextOpen == contextClose)

        let memoryOpen = prompt.components(separatedBy: "<memory").count - 1
        let memoryClose = prompt.components(separatedBy: "</memory>").count - 1
        #expect(memoryOpen == memoryClose)

        let toneOpen = prompt.components(separatedBy: "<tone>").count - 1
        let toneClose = prompt.components(separatedBy: "</tone>").count - 1
        #expect(toneOpen == toneClose)

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
            toneDescription: "Use 'quotes' and <tags>"
        )
        let prompt = context.buildSystemPrompt(task: "Test & verify")

        // Should include the content (not escaped for LLM consumption)
        #expect(prompt.contains("Contains <special> & \"characters\""))
        #expect(prompt.contains("Use 'quotes' and <tags>"))
    }

    @Test func handlesEmptyStringsVsNil() {
        let contextWithEmpty = PromptContext(
            globalMemory: "",
            toneDescription: ""
        )

        let contextWithNil = PromptContext(
            globalMemory: nil,
            toneDescription: nil
        )

        // Both should behave the same - no content
        #expect(!contextWithEmpty.hasMemory)
        #expect(!contextWithNil.hasMemory)
        #expect(!contextWithEmpty.hasTone)
        #expect(!contextWithNil.hasTone)
    }

    @Test func handlesWhitespaceOnlyContent() {
        let context = PromptContext(
            globalMemory: "   \n\t  ",
            toneDescription: "  ",
            customInstructions: "\n\n"
        )

        #expect(!context.hasMemory)
        #expect(!context.hasTone)
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
            globalMemory: "Używaj polskich znaków: ąęłńóśźż",
            toneDescription: "Kochanie ❤️ Skarbie 💕",
            vocabularyWords: ["日本語", "中文", "한국어"]
        )
        let prompt = context.buildSystemPrompt(task: "Test")
        let hint = context.buildTranscriptionHint()

        #expect(prompt.contains("ąęłńóśźż"))
        #expect(prompt.contains("❤️"))
        #expect(hint?.contains("日本語") == true)
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
            icon: "❤️",
            color: .purple,
            description: "Wife",
            toneDescription: "Warm and loving",
            languageHints: [.polish, .english],
            customInstructions: "Use Kochanie",
            memoryEnabled: true,
            memory: "Fatma's memory"
        )

        // Simulate what PromptContext.from() would do
        let promptContext = PromptContext(
            contextMemory: conversationContext.memoryEnabled ? conversationContext.memory : nil,
            contextName: conversationContext.name,
            toneDescription: conversationContext.toneDescription,
            customInstructions: conversationContext.customInstructions,
            languageHints: conversationContext.languageHints
        )

        #expect(promptContext.contextName == "Fatma")
        #expect(promptContext.contextMemory == "Fatma's memory")
        #expect(promptContext.toneDescription == "Warm and loving")
        #expect(promptContext.customInstructions == "Use Kochanie")
        #expect(promptContext.languageHints.count == 2)
    }

    @Test func disabledMemoryIsNotIncluded() {
        let conversationContext = ConversationContext(
            name: "Work",
            icon: "💼",
            color: .blue,
            description: "Work context",
            memoryEnabled: false,
            memory: "This should not appear"
        )

        let promptContext = PromptContext(
            contextMemory: conversationContext.memoryEnabled ? conversationContext.memory : nil,
            contextName: conversationContext.name
        )

        #expect(promptContext.contextMemory == nil)
        #expect(!promptContext.hasMemory)
    }
}
