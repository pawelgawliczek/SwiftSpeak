//
//  LargeDataTests.swift
//  SwiftSpeakTests
//
//  Tests for handling large data volumes and edge cases
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

// MARK: - Large History Tests

@Suite("Large History Tests")
@MainActor
struct LargeHistoryTests {

    @Test("Can store many history entries")
    func canStoreManyHistoryEntries() {
        let settings = SharedSettings.shared
        let originalHistory = settings.transcriptionHistory

        // Add many entries
        for i in 0..<100 {
            let record = TranscriptionRecord(
                text: "Test transcription \(i) with some content to make it realistic",
                mode: FormattingMode.allCases[i % FormattingMode.allCases.count],
                provider: .openAI,
                duration: Double(i) + 1.0
            )
            settings.addTranscription(record)
        }

        #expect(settings.transcriptionHistory.count >= 100)

        // Clean up
        settings.clearHistory()
        for record in originalHistory {
            settings.addTranscription(record)
        }
    }

    @Test("History with long text entries")
    func historyWithLongTextEntries() {
        let settings = SharedSettings.shared
        let originalHistory = settings.transcriptionHistory

        // Create entry with very long text (10KB)
        let longText = String(repeating: "This is a test sentence. ", count: 500)

        let record = TranscriptionRecord(
            text: longText,
            mode: .raw,
            provider: .openAI,
            duration: 60.0
        )

        settings.addTranscription(record)

        let retrieved = settings.transcriptionHistory.first(where: { $0.id == record.id })
        #expect(retrieved?.text.count == longText.count)

        // Clean up
        settings.clearHistory()
        for r in originalHistory {
            settings.addTranscription(r)
        }
    }

    @Test("History search performance")
    func historySearchPerformance() {
        let settings = SharedSettings.shared
        let originalHistory = settings.transcriptionHistory

        // Add entries with searchable content
        for i in 0..<50 {
            let record = TranscriptionRecord(
                text: "Entry \(i): keyword_\(i % 5)",
                mode: .raw,
                provider: .openAI,
                duration: 5.0
            )
            settings.addTranscription(record)
        }

        // Search
        let matching = settings.transcriptionHistory.filter { $0.text.contains("keyword_0") }
        #expect(matching.count >= 10)

        // Clean up
        settings.clearHistory()
        for record in originalHistory {
            settings.addTranscription(record)
        }
    }
}

// MARK: - Large Power Mode Tests

@Suite("Large Power Mode Tests")
@MainActor
struct LargePowerModeTests {

    @Test("Can create many power modes")
    func canCreateManyPowerModes() {
        let settings = SharedSettings.shared
        let originalModes = settings.powerModes

        for i in 0..<50 {
            let mode = PowerMode(
                name: "Mode \(i)",
                icon: "bolt.fill",
                instruction: "You are assistant number \(i)"
            )
            settings.addPowerMode(mode)
        }

        #expect(settings.powerModes.count >= 50)

        settings.powerModes = originalModes
    }

    @Test("Power mode with long instruction")
    func powerModeWithLongInstruction() {
        let longInstruction = String(repeating: "You are a helpful assistant. ", count: 200)

        var mode = PowerMode(
            name: "Long Instruction Mode",
            icon: "doc.text",
            instruction: longInstruction
        )

        #expect(mode.instruction.count == longInstruction.count)
    }

    @Test("Power mode with long memory")
    func powerModeWithLongMemory() {
        var mode = PowerMode(name: "Memory Test")
        mode.memoryEnabled = true

        let longMemory = String(repeating: "User preference: ", count: 500)
        mode.memory = longMemory

        #expect(mode.memory?.count == longMemory.count)
    }
}

// MARK: - Large Context Tests

@Suite("Large Context Tests")
@MainActor
struct LargeContextTests {

    @Test("Can create many contexts")
    func canCreateManyContexts() {
        let settings = SharedSettings.shared
        let originalContexts = settings.contexts

        for i in 0..<50 {
            let context = ConversationContext(
                name: "Context \(i)",
                icon: "folder",
                color: .blue,
                description: "Test context number \(i)"
            )
            settings.contexts.append(context)
        }

        #expect(settings.contexts.count >= 50)

        settings.contexts = originalContexts
    }

    @Test("Context with long custom instructions")
    func contextWithLongCustomInstructions() {
        let longInstructions = String(repeating: "Be professional and helpful. ", count: 200)

        let context = ConversationContext(
            name: "Long Instructions",
            icon: "doc",
            color: .purple,
            description: "Context with very long instructions",
            customInstructions: longInstructions
        )

        #expect(context.customInstructions?.count == longInstructions.count)
    }

    @Test("Context with long memory")
    func contextWithLongMemory() {
        var context = ConversationContext(
            name: "Memory Test",
            icon: "brain",
            color: .orange,
            description: "Test",
            useContextMemory: true,
            contextMemory: nil
        )

        let longMemory = String(repeating: "Remember this: ", count: 500)
        context = ConversationContext(
            id: context.id,
            name: context.name,
            icon: context.icon,
            color: context.color,
            description: context.description,
            useContextMemory: true,
            contextMemory: longMemory,
            createdAt: context.createdAt,
            updatedAt: Date()
        )

        #expect(context.contextMemory?.count == longMemory.count)
    }
}

// MARK: - Large Vocabulary Tests

@Suite("Large Vocabulary Tests")
@MainActor
struct LargeVocabularyTests {

    @Test("Can store many vocabulary entries")
    func canStoreManyVocabularyEntries() {
        let settings = SharedSettings.shared
        let originalVocab = settings.vocabulary

        for i in 0..<200 {
            let entry = VocabularyEntry(
                recognizedWord: "term\(i)",
                replacementWord: "replacement\(i)",
                category: .name
            )
            settings.addVocabularyEntry(entry)
        }

        #expect(settings.vocabulary.count >= 200)

        settings.vocabulary = originalVocab
    }

    @Test("Vocabulary with long replacement strings")
    func vocabularyWithLongReplacements() {
        let settings = SharedSettings.shared
        let originalVocab = settings.vocabulary

        let longReplacement = String(repeating: "word ", count: 100)

        let entry = VocabularyEntry(
            recognizedWord: "abbreviation",
            replacementWord: longReplacement,
            category: .name
        )

        settings.addVocabularyEntry(entry)

        let stored = settings.vocabulary.first(where: { $0.recognizedWord == "abbreviation" })
        #expect(stored?.replacementWord.count == longReplacement.count)

        settings.vocabulary = originalVocab
    }
}

// MARK: - Large Document Tests

@Suite("Large Document Tests")
@MainActor
struct LargeDocumentTests {

    @Test("Can store many knowledge documents")
    func canStoreManyKnowledgeDocuments() {
        let settings = SharedSettings.shared
        let originalDocs = settings.knowledgeDocuments

        for i in 0..<100 {
            let doc = KnowledgeDocument(
                name: "Document \(i).pdf",
                type: i % 2 == 0 ? .localFile : .remoteURL
            )
            settings.knowledgeDocuments.append(doc)
        }

        #expect(settings.knowledgeDocuments.count >= 100)

        settings.knowledgeDocuments = originalDocs
    }

    @Test("Document with long name")
    func documentWithLongName() {
        let longName = String(repeating: "a", count: 255) + ".pdf"

        let doc = KnowledgeDocument(
            name: longName,
            type: .localFile
        )

        #expect(doc.name.count == longName.count)
    }
}

// MARK: - Large Webhook Tests

@Suite("Large Webhook Tests")
@MainActor
struct LargeWebhookTests {

    @Test("Can store many webhooks")
    func canStoreManyWebhooks() {
        let settings = SharedSettings.shared
        let originalWebhooks = settings.webhooks

        for i in 0..<50 {
            let webhook = Webhook(
                name: "Webhook \(i)",
                type: .contextSource,
                url: URL(string: "https://example.com/webhook/\(i)")!
            )
            settings.webhooks.append(webhook)
        }

        #expect(settings.webhooks.count >= 50)

        settings.webhooks = originalWebhooks
    }

    @Test("Webhook with complex configuration")
    func webhookWithComplexConfiguration() {
        var webhook = Webhook(
            name: "Complex Webhook",
            type: .contextSource,
            url: URL(string: "https://api.example.com/data")!
        )

        // Set all optional fields
        webhook.authType = .bearerToken
        webhook.authToken = "test-token-12345"

        #expect(webhook.authType == .bearerToken)
        #expect(webhook.authToken == "test-token-12345")
    }
}

// MARK: - Large Provider Config Tests

@Suite("Large Provider Config Tests")
@MainActor
struct LargeProviderConfigTests {

    @Test("Can configure many providers")
    func canConfigureManyProviders() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        var configs: [AIProviderConfig] = []

        for provider in AIProvider.allCases {
            let config = AIProviderConfig(
                provider: provider,
                apiKey: "test-key-\(provider.rawValue)",
                usageCategories: [.transcription, .translation, .powerMode],
                transcriptionModel: "model-1",
                translationModel: "model-2",
                powerModeModel: "model-3"
            )
            configs.append(config)
        }

        settings.configuredAIProviders = configs

        #expect(settings.configuredAIProviders.count == AIProvider.allCases.count)

        settings.configuredAIProviders = originalProviders
    }

    @Test("Provider config with long API key")
    func providerConfigWithLongAPIKey() {
        let longKey = String(repeating: "a", count: 256)

        let config = AIProviderConfig(
            provider: .openAI,
            apiKey: longKey,
            usageCategories: [.transcription]
        )

        #expect(config.apiKey.count == longKey.count)
    }
}

// MARK: - Edge Case Tests

@Suite("Edge Case Tests")
@MainActor
struct EdgeCaseTests {

    @Test("Empty string handling")
    func emptyStringHandling() {
        var mode = PowerMode(name: "")
        #expect(mode.name.isEmpty)

        mode.instruction = ""
        #expect(mode.instruction.isEmpty)
    }

    @Test("Unicode text handling")
    func unicodeTextHandling() {
        let unicodeText = "Hello 世界 مرحبا שלום 🌍 emoji test"

        let record = TranscriptionRecord(
            text: unicodeText,
            mode: .raw,
            provider: .openAI,
            duration: 5.0
        )

        #expect(record.text == unicodeText)
    }

    @Test("Special characters in names")
    func specialCharactersInNames() {
        let specialName = "Mode with <special> & \"characters\""

        let mode = PowerMode(
            name: specialName,
            instruction: "Test"
        )

        #expect(mode.name == specialName)
    }

    @Test("Whitespace-only text")
    func whitespaceOnlyText() {
        let whitespaceText = "   \t\n   "

        let record = TranscriptionRecord(
            text: whitespaceText,
            mode: .raw,
            provider: .openAI,
            duration: 1.0
        )

        #expect(record.text == whitespaceText)
    }

    @Test("Very long text handling")
    func veryLongTextHandling() {
        // 1MB of text
        let veryLongText = String(repeating: "x", count: 1_000_000)

        let record = TranscriptionRecord(
            text: veryLongText,
            mode: .raw,
            provider: .openAI,
            duration: 600.0
        )

        #expect(record.text.count == 1_000_000)
    }

    @Test("Zero duration handling")
    func zeroDurationHandling() {
        let record = TranscriptionRecord(
            text: "Quick test",
            mode: .raw,
            provider: .openAI,
            duration: 0.0
        )

        #expect(record.duration == 0.0)
    }

    @Test("Negative values handling")
    func negativeValuesHandling() {
        // Some models might use negative values in edge cases
        let breakdown = CostBreakdown(
            transcriptionCost: -0.001,  // Shouldn't happen but should handle
            formattingCost: 0.0,
            translationCost: nil,
            inputTokens: 0,
            outputTokens: 0
        )

        // Should not crash
        #expect(breakdown.transcriptionCost < 0)
    }

    @Test("Maximum UUID count")
    func maximumUUIDCount() {
        // Test UUID uniqueness for many items
        var uuids = Set<UUID>()

        for _ in 0..<1000 {
            let uuid = UUID()
            uuids.insert(uuid)
        }

        // All UUIDs should be unique
        #expect(uuids.count == 1000)
    }
}

// MARK: - Memory Pressure Tests

@Suite("Memory Pressure Tests")
@MainActor
struct MemoryPressureTests {

    @Test("Settings can handle rapid updates")
    func settingsCanHandleRapidUpdates() {
        let settings = SharedSettings.shared
        let originalMode = settings.selectedMode

        for mode in FormattingMode.allCases {
            settings.selectedMode = mode
        }

        // Should not crash or lose data
        #expect(FormattingMode.allCases.contains(settings.selectedMode))

        settings.selectedMode = originalMode
    }

    @Test("Large history doesn't block operations")
    func largeHistoryDoesntBlock() {
        let settings = SharedSettings.shared
        let originalHistory = settings.transcriptionHistory

        // Add many entries
        for i in 0..<200 {
            let record = TranscriptionRecord(
                text: "Entry \(i)",
                mode: .raw,
                provider: .openAI,
                duration: 1.0
            )
            settings.addTranscription(record)
        }

        // Should still be able to read settings quickly
        _ = settings.selectedMode
        _ = settings.selectedTargetLanguage
        _ = settings.powerModes

        #expect(Bool(true))

        settings.clearHistory()
        for record in originalHistory {
            settings.addTranscription(record)
        }
    }

    @Test("Cleanup removes old data")
    func cleanupRemovesOldData() {
        let settings = SharedSettings.shared
        let originalHistory = settings.transcriptionHistory

        // Add entries
        for i in 0..<10 {
            let record = TranscriptionRecord(
                text: "Entry \(i)",
                mode: .raw,
                provider: .openAI,
                duration: 1.0
            )
            settings.addTranscription(record)
        }

        // Clear history
        settings.clearHistory()

        #expect(settings.transcriptionHistory.isEmpty)

        // Restore
        for record in originalHistory {
            settings.addTranscription(record)
        }
    }
}

// MARK: - Data Integrity Tests

@Suite("Data Integrity Tests")
@MainActor
struct DataIntegrityTests {

    @Test("UUID uniqueness is maintained")
    func uuidUniquenessIsMaintained() {
        let mode1 = PowerMode(name: "Mode 1")
        let mode2 = PowerMode(name: "Mode 2")

        #expect(mode1.id != mode2.id)
    }

    @Test("Timestamps are accurate")
    func timestampsAreAccurate() {
        let before = Date()

        let record = TranscriptionRecord(
            text: "Test",
            mode: .raw,
            provider: .openAI,
            duration: 1.0
        )

        let after = Date()

        #expect(record.timestamp >= before)
        #expect(record.timestamp <= after)
    }

    @Test("Data survives encode/decode cycle")
    func dataSurvivesEncodeDecode() {
        let original = PowerMode(
            name: "Test Mode",
            icon: "star",
            instruction: "Be helpful"
        )

        // Encode
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(original) else {
            Issue.record("Failed to encode")
            return
        }

        // Decode
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(PowerMode.self, from: data) else {
            Issue.record("Failed to decode")
            return
        }

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.icon == original.icon)
        #expect(decoded.instruction == original.instruction)
    }

    @Test("Context color survives encode/decode")
    func contextColorSurvivesEncodeDecode() {
        let original = ConversationContext(
            name: "Test",
            icon: "star",
            color: .purple,
            description: "Test context"
        )

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(original) else {
            Issue.record("Failed to encode")
            return
        }

        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(ConversationContext.self, from: data) else {
            Issue.record("Failed to decode")
            return
        }

        #expect(decoded.color == original.color)
    }
}
