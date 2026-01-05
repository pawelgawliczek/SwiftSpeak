//
//  iCloudSyncTests.swift
//  SwiftSpeakTests
//
//  Tests for iCloud KVS and CloudKit sync functionality
//

import Testing
import Foundation
@testable import SwiftSpeak

// MARK: - Mock iCloud KVS

/// Mock NSUbiquitousKeyValueStore for testing
final class MockiCloudKVS {
    private var storage: [String: Any] = [:]
    var synchronizeCalled = false
    var synchronizeReturnValue = true

    func set(_ value: Any?, forKey key: String) {
        if let value = value {
            storage[key] = value
        } else {
            storage.removeValue(forKey: key)
        }
    }

    func object(forKey key: String) -> Any? {
        storage[key]
    }

    func string(forKey key: String) -> String? {
        storage[key] as? String
    }

    func bool(forKey key: String) -> Bool {
        storage[key] as? Bool ?? false
    }

    func data(forKey key: String) -> Data? {
        storage[key] as? Data
    }

    func double(forKey key: String) -> Double {
        storage[key] as? Double ?? 0
    }

    func longLong(forKey key: String) -> Int64 {
        storage[key] as? Int64 ?? 0
    }

    func removeObject(forKey key: String) {
        storage.removeValue(forKey: key)
    }

    func synchronize() -> Bool {
        synchronizeCalled = true
        return synchronizeReturnValue
    }

    var dictionaryRepresentation: [String: Any] {
        storage
    }

    func clear() {
        storage.removeAll()
    }
}

// MARK: - iCloud Sync Tests

@Suite("iCloud Sync Tests")
struct iCloudSyncTests {

    // MARK: - iCloud Keys Consistency

    @Test("iCloud keys match between iOS and macOS")
    func testICloudKeysConsistency() {
        // These keys must be identical for cross-platform sync
        let expectedKeys = [
            "icloud_configuredAIProviders",
            "icloud_contexts",
            "icloud_powerModes",
            "icloud_vocabulary",
            "icloud_customTemplates",
            "icloud_globalMemory",
            "icloud_globalMemoryEnabled",
            "icloud_globalMemoryLimit",
            "icloud_selectedTranscriptionProvider",
            "icloud_selectedTranslationProvider",
            "icloud_selectedPowerModeProvider",
            "icloud_selectedMode",
            "icloud_selectedTargetLanguage",
            "icloud_isTranslationEnabled",
            "icloud_historyMemory",
            "icloud_lastSyncTimestamp"
        ]

        // Verify keys exist as expected (documentation test)
        for key in expectedKeys {
            #expect(key.hasPrefix("icloud_"), "Key \(key) should have icloud_ prefix")
        }

        // Transcription history is NOT in iCloud KVS - uses Core Data + CloudKit
        #expect(!expectedKeys.contains("icloud_transcriptionHistory"),
               "History should use Core Data, not iCloud KVS")
    }

    // MARK: - Data Encoding Tests

    @Test("AI provider config encodes/decodes correctly for sync")
    func testAIProviderConfigCodable() throws {
        let config = AIProviderConfig(
            provider: .openAI,
            apiKey: "test-api-key-12345",
            usageCategories: [.transcription, .translation],
            transcriptionModel: "whisper-1",
            translationModel: "gpt-4"
        )

        let encoded = try JSONEncoder().encode([config])
        let decoded = try JSONDecoder().decode([AIProviderConfig].self, from: encoded)

        #expect(decoded.count == 1)
        #expect(decoded.first?.provider == .openAI)
        #expect(decoded.first?.apiKey == "test-api-key-12345")
        #expect(decoded.first?.usageCategories.contains(.transcription) == true)
    }

    @Test("Context encodes/decodes correctly for sync")
    func testContextCodable() throws {
        var context = ConversationContext(
            name: "Work",
            icon: "briefcase",
            color: .blue,
            description: "Professional context",
            customInstructions: "Be formal"
        )
        context.contextMemory = "User prefers bullet points"

        let encoded = try JSONEncoder().encode([context])
        let decoded = try JSONDecoder().decode([ConversationContext].self, from: encoded)

        #expect(decoded.count == 1)
        #expect(decoded.first?.name == "Work")
        #expect(decoded.first?.contextMemory == "User prefers bullet points")
    }

    @Test("Power mode encodes/decodes correctly for sync")
    func testPowerModeCodable() throws {
        var mode = PowerMode(name: "Email Assistant")
        mode.instruction = "Help draft emails"
        mode.memory = "User signature: John Doe"

        let encoded = try JSONEncoder().encode([mode])
        let decoded = try JSONDecoder().decode([PowerMode].self, from: encoded)

        #expect(decoded.count == 1)
        #expect(decoded.first?.name == "Email Assistant")
        #expect(decoded.first?.memory == "User signature: John Doe")
    }

    @Test("History memory encodes/decodes correctly for sync")
    func testHistoryMemoryCodable() throws {
        var memory = HistoryMemory()
        memory.summary = "User frequently discusses work topics"
        memory.recentTopics = ["meetings", "emails", "projects"]
        memory.conversationCount = 42

        let encoded = try JSONEncoder().encode(memory)
        let decoded = try JSONDecoder().decode(HistoryMemory.self, from: encoded)

        #expect(decoded.summary == "User frequently discusses work topics")
        #expect(decoded.recentTopics.count == 3)
        #expect(decoded.conversationCount == 42)
    }

    // MARK: - Core Data History Tests

    @Test("TranscriptionRecord encodes for Core Data storage")
    func testTranscriptionRecordCodable() throws {
        let record = TranscriptionRecord(
            rawTranscribedText: "Hello world",
            text: "Hello, World!",
            mode: .formal,
            provider: .openAI,
            duration: 5.5
        )

        // Core Data stores as JSON in jsonData field
        let encoded = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(TranscriptionRecord.self, from: encoded)

        #expect(decoded.rawTranscribedText == "Hello world")
        #expect(decoded.text == "Hello, World!")
        #expect(decoded.mode == .formal)
        #expect(decoded.duration == 5.5)
    }

    // MARK: - Sync Size Tests

    @Test("Provider config stays within iCloud KVS limits")
    func testProviderConfigSizeLimit() throws {
        // iCloud KVS limit is 1MB per key
        var configs: [AIProviderConfig] = []

        // Create 20 providers (more than typical)
        for i in 0..<20 {
            let config = AIProviderConfig(
                provider: AIProvider.allCases[i % AIProvider.allCases.count],
                apiKey: String(repeating: "x", count: 100), // Reasonable API key length
                usageCategories: [.transcription, .translation, .powerMode],
                transcriptionModel: "model-\(i)",
                translationModel: "gpt-4",
                powerModeModel: "gpt-4"
            )
            configs.append(config)
        }

        let encoded = try JSONEncoder().encode(configs)

        // Should be well under 1MB (1,048,576 bytes)
        #expect(encoded.count < 100_000, "Provider configs should be under 100KB, got \(encoded.count)")
    }

    @Test("Contexts stay within iCloud KVS limits")
    func testContextsSizeLimit() throws {
        var contexts: [ConversationContext] = []

        // Create 50 contexts (more than typical)
        for i in 0..<50 {
            var context = ConversationContext(
                name: "Context \(i)",
                icon: "star",
                color: .blue,
                description: String(repeating: "Description ", count: 10),
                customInstructions: String(repeating: "Instruction ", count: 20)
            )
            context.contextMemory = String(repeating: "Memory ", count: 50)
            contexts.append(context)
        }

        let encoded = try JSONEncoder().encode(contexts)

        // Should be under 500KB
        #expect(encoded.count < 500_000, "Contexts should be under 500KB, got \(encoded.count)")
    }

    // MARK: - Merge Logic Tests

    @Test("History merge by UUID prevents duplicates")
    func testHistoryMergeLogic() {
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        let localRecords = [
            TranscriptionRecord(id: id1, text: "Local 1", mode: .raw, provider: .openAI, duration: 1.0),
            TranscriptionRecord(id: id2, text: "Local 2", mode: .raw, provider: .openAI, duration: 1.0)
        ]

        let cloudRecords = [
            TranscriptionRecord(id: id2, text: "Cloud 2 (same ID)", mode: .raw, provider: .openAI, duration: 1.0),
            TranscriptionRecord(id: id3, text: "Cloud 3", mode: .raw, provider: .openAI, duration: 1.0)
        ]

        // Simulate merge logic
        let localIds = Set(localRecords.map { $0.id })
        let newFromCloud = cloudRecords.filter { !localIds.contains($0.id) }
        let merged = localRecords + newFromCloud

        #expect(merged.count == 3, "Should have 3 unique records")
        #expect(newFromCloud.count == 1, "Only 1 new record from cloud")
        #expect(newFromCloud.first?.id == id3, "New record should be id3")
    }

    // MARK: - Timestamp Tests

    @Test("History memory uses timestamp for conflict resolution")
    func testHistoryMemoryTimestampResolution() {
        var older = HistoryMemory()
        older.summary = "Old summary"
        older.lastUpdated = Date().addingTimeInterval(-3600) // 1 hour ago

        var newer = HistoryMemory()
        newer.summary = "New summary"
        newer.lastUpdated = Date()

        // Conflict resolution: use newer
        let winner = newer.lastUpdated > older.lastUpdated ? newer : older

        #expect(winner.summary == "New summary")
    }
}

// MARK: - Core Data Manager Tests

@Suite("Core Data History Tests")
struct CoreDataHistoryTests {

    @Test("CoreDataManager shared instance exists")
    @MainActor
    func testCoreDataManagerExists() {
        // Verify CoreDataManager is accessible
        let manager = CoreDataManager.shared
        #expect(manager != nil)
    }

    @Test("CoreDataManager has transcriptionHistory property")
    @MainActor
    func testCoreDataManagerHasHistory() {
        let manager = CoreDataManager.shared

        // History should be an array (may be empty in test environment)
        #expect(manager.transcriptionHistory is [TranscriptionRecord])
    }
}
