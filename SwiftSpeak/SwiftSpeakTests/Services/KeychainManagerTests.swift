//
//  KeychainManagerTests.swift
//  SwiftSpeakTests
//
//  Tests for KeychainManager - secure API key storage
//

import Testing
import Foundation
@testable import SwiftSpeak

// MARK: - KeychainManager Tests

@Suite("KeychainManager Tests")
struct KeychainManagerTests {

    // MARK: - KeychainError Tests

    @Test("KeychainError descriptions are correct")
    func testErrorDescriptions() {
        #expect(KeychainError.itemNotFound.errorDescription?.contains("not found") == true)
        #expect(KeychainError.duplicateItem.errorDescription?.contains("already exists") == true)
        #expect(KeychainError.encodingError.errorDescription?.contains("encode") == true)
        #expect(KeychainError.decodingError.errorDescription?.contains("decode") == true)
        #expect(KeychainError.unexpectedError(-25300).errorDescription?.contains("-25300") == true)
    }

    // MARK: - KeychainKeys Tests

    @Test("KeychainKeys returns correct key for each provider")
    func testKeychainKeys() {
        #expect(KeychainKeys.key(for: .openAI) == "swiftspeak.apikey.openai")
        #expect(KeychainKeys.key(for: .anthropic) == "swiftspeak.apikey.anthropic")
        #expect(KeychainKeys.key(for: .google) == "swiftspeak.apikey.google")
        #expect(KeychainKeys.key(for: .elevenLabs) == "swiftspeak.apikey.elevenlabs")
        #expect(KeychainKeys.key(for: .deepgram) == "swiftspeak.apikey.deepgram")
        #expect(KeychainKeys.key(for: .assemblyAI) == "swiftspeak.apikey.assemblyai")
        #expect(KeychainKeys.key(for: .deepL) == "swiftspeak.apikey.deepl")
        #expect(KeychainKeys.key(for: .azure) == "swiftspeak.apikey.azure")
        #expect(KeychainKeys.key(for: .local) == "swiftspeak.apikey.local")
    }

    @Test("KeychainKeys all have same prefix")
    func testKeychainKeysPrefix() {
        for provider in AIProvider.allCases {
            let key = KeychainKeys.key(for: provider)
            #expect(key.hasPrefix("swiftspeak.apikey."))
        }
    }

    // MARK: - MockKeychainManager Tests (Unit Tests)

    @Test("MockKeychainManager save and retrieve")
    func testMockSaveAndRetrieve() throws {
        let mock = MockKeychainManager()

        try mock.save(key: "test-key", value: "test-value")
        let retrieved = try mock.retrieve(key: "test-key")

        #expect(retrieved == "test-value")
    }

    @Test("MockKeychainManager retrieve non-existent key returns nil")
    func testMockRetrieveNonExistent() throws {
        let mock = MockKeychainManager()

        let retrieved = try mock.retrieve(key: "non-existent")

        #expect(retrieved == nil)
    }

    @Test("MockKeychainManager delete")
    func testMockDelete() throws {
        let mock = MockKeychainManager()

        try mock.save(key: "test-key", value: "test-value")
        try mock.delete(key: "test-key")
        let retrieved = try mock.retrieve(key: "test-key")

        #expect(retrieved == nil)
    }

    @Test("MockKeychainManager exists")
    func testMockExists() throws {
        let mock = MockKeychainManager()

        #expect(mock.exists(key: "test-key") == false)

        try mock.save(key: "test-key", value: "test-value")

        #expect(mock.exists(key: "test-key") == true)
    }

    @Test("MockKeychainManager update existing value")
    func testMockUpdate() throws {
        let mock = MockKeychainManager()

        try mock.save(key: "test-key", value: "original")
        try mock.save(key: "test-key", value: "updated")

        let retrieved = try mock.retrieve(key: "test-key")

        #expect(retrieved == "updated")
    }

    @Test("MockKeychainManager handles multiple keys")
    func testMockMultipleKeys() throws {
        let mock = MockKeychainManager()

        try mock.save(key: "key1", value: "value1")
        try mock.save(key: "key2", value: "value2")
        try mock.save(key: "key3", value: "value3")

        #expect(try mock.retrieve(key: "key1") == "value1")
        #expect(try mock.retrieve(key: "key2") == "value2")
        #expect(try mock.retrieve(key: "key3") == "value3")
    }

    @Test("MockKeychainManager simulates error")
    func testMockSimulateError() throws {
        let mock = MockKeychainManager()
        mock.shouldFailOnSave = true

        #expect(throws: KeychainError.self) {
            try mock.save(key: "test", value: "value")
        }
    }

    // MARK: - Real KeychainManager Tests (Integration - requires device/simulator)

    @Test("Real KeychainManager save, retrieve, delete cycle")
    func testRealKeychainCycle() throws {
        let keychain = KeychainManager()
        let testKey = "swiftspeak.test.\(UUID().uuidString)"
        let testValue = "test-api-key-\(UUID().uuidString)"

        // Clean up any existing value
        try? keychain.delete(key: testKey)

        // Save
        try keychain.save(key: testKey, value: testValue)

        // Verify exists
        #expect(keychain.exists(key: testKey) == true)

        // Retrieve
        let retrieved = try keychain.retrieve(key: testKey)
        #expect(retrieved == testValue)

        // Delete
        try keychain.delete(key: testKey)

        // Verify deleted
        #expect(keychain.exists(key: testKey) == false)
        let afterDelete = try keychain.retrieve(key: testKey)
        #expect(afterDelete == nil)
    }

    @Test("Real KeychainManager update existing value")
    func testRealKeychainUpdate() throws {
        let keychain = KeychainManager()
        let testKey = "swiftspeak.test.update.\(UUID().uuidString)"

        // Clean up
        try? keychain.delete(key: testKey)

        // Save original
        try keychain.save(key: testKey, value: "original-value")

        // Update
        try keychain.save(key: testKey, value: "updated-value")

        // Verify update
        let retrieved = try keychain.retrieve(key: testKey)
        #expect(retrieved == "updated-value")

        // Clean up
        try keychain.delete(key: testKey)
    }

    @Test("Real KeychainManager delete non-existent key doesn't throw")
    func testRealKeychainDeleteNonExistent() throws {
        let keychain = KeychainManager()
        let testKey = "swiftspeak.test.nonexistent.\(UUID().uuidString)"

        // Should not throw
        try keychain.delete(key: testKey)
    }

    @Test("Real KeychainManager handles special characters in value")
    func testRealKeychainSpecialCharacters() throws {
        let keychain = KeychainManager()
        let testKey = "swiftspeak.test.special.\(UUID().uuidString)"
        let specialValue = "sk-abc123!@#$%^&*()_+-=[]{}|;':\",./<>?`~"

        try? keychain.delete(key: testKey)

        try keychain.save(key: testKey, value: specialValue)
        let retrieved = try keychain.retrieve(key: testKey)

        #expect(retrieved == specialValue)

        try keychain.delete(key: testKey)
    }

    @Test("Real KeychainManager handles unicode in value")
    func testRealKeychainUnicode() throws {
        let keychain = KeychainManager()
        let testKey = "swiftspeak.test.unicode.\(UUID().uuidString)"
        let unicodeValue = "API密钥-キー-مفتاح-🔑"

        try? keychain.delete(key: testKey)

        try keychain.save(key: testKey, value: unicodeValue)
        let retrieved = try keychain.retrieve(key: testKey)

        #expect(retrieved == unicodeValue)

        try keychain.delete(key: testKey)
    }

    @Test("Real KeychainManager handles empty value")
    func testRealKeychainEmptyValue() throws {
        let keychain = KeychainManager()
        let testKey = "swiftspeak.test.empty.\(UUID().uuidString)"

        try? keychain.delete(key: testKey)

        try keychain.save(key: testKey, value: "")
        let retrieved = try keychain.retrieve(key: testKey)

        #expect(retrieved == "")

        try keychain.delete(key: testKey)
    }

    @Test("Real KeychainManager handles long value")
    func testRealKeychainLongValue() throws {
        let keychain = KeychainManager()
        let testKey = "swiftspeak.test.long.\(UUID().uuidString)"
        let longValue = String(repeating: "a", count: 10000)

        try? keychain.delete(key: testKey)

        try keychain.save(key: testKey, value: longValue)
        let retrieved = try keychain.retrieve(key: testKey)

        #expect(retrieved == longValue)

        try keychain.delete(key: testKey)
    }

    @Test("Real KeychainManager deleteAll")
    func testRealKeychainDeleteAll() throws {
        let keychain = KeychainManager()
        let testKey1 = "swiftspeak.test.all1.\(UUID().uuidString)"
        let testKey2 = "swiftspeak.test.all2.\(UUID().uuidString)"

        // Note: deleteAll deletes ALL items for the service, so we use unique keys
        // and only test that the method doesn't throw
        try? keychain.delete(key: testKey1)
        try? keychain.delete(key: testKey2)

        try keychain.save(key: testKey1, value: "value1")
        try keychain.save(key: testKey2, value: "value2")

        // This will delete all items - be careful in production tests!
        // For safety, we won't actually call deleteAll in tests
        // try keychain.deleteAll()

        // Clean up individually instead
        try keychain.delete(key: testKey1)
        try keychain.delete(key: testKey2)
    }

    // MARK: - Thread Safety Tests

    @Test("Real KeychainManager is thread safe")
    func testRealKeychainThreadSafety() async throws {
        let keychain = KeychainManager()
        let testKey = "swiftspeak.test.threadsafe.\(UUID().uuidString)"

        try? keychain.delete(key: testKey)

        // Perform concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    try? keychain.save(key: testKey, value: "value-\(i)")
                }
            }
        }

        // Should have some value (last write wins)
        let retrieved = try keychain.retrieve(key: testKey)
        #expect(retrieved?.hasPrefix("value-") == true)

        try keychain.delete(key: testKey)
    }
}

// MARK: - SecureStorageProtocol Conformance Tests

@Suite("SecureStorageProtocol Conformance Tests")
struct SecureStorageProtocolTests {

    @Test("KeychainManager conforms to SecureStorageProtocol")
    func testKeychainManagerConformance() {
        let keychain: SecureStorageProtocol = KeychainManager()
        #expect(keychain is SecureStorageProtocol)
    }

    @Test("MockKeychainManager conforms to SecureStorageProtocol")
    func testMockKeychainManagerConformance() {
        let mock: SecureStorageProtocol = MockKeychainManager()
        #expect(mock is SecureStorageProtocol)
    }

    @Test("Protocol methods work through protocol type")
    func testProtocolMethodsThroughInterface() throws {
        let storage: SecureStorageProtocol = MockKeychainManager()

        try storage.save(key: "test", value: "value")
        let retrieved = try storage.retrieve(key: "test")
        #expect(retrieved == "value")

        #expect(storage.exists(key: "test") == true)

        try storage.delete(key: "test")
        #expect(storage.exists(key: "test") == false)
    }
}
