//
//  MockKeychainManager.swift
//  SwiftSpeak
//
//  Phase 6: Mock implementation for testing Keychain operations
//

import Foundation
import SwiftSpeakCore

/// Mock implementation of SecureStorageProtocol for unit testing
/// Stores values in memory instead of actual Keychain
final class MockKeychainManager: SecureStorageProtocol, @unchecked Sendable {

    // MARK: - Properties

    /// In-memory storage for mock Keychain items
    private var storage: [String: String] = [:]

    /// Thread safety lock
    private let lock = NSLock()

    /// Flag to simulate Keychain failures
    var shouldFailOnSave = false
    var shouldFailOnRetrieve = false
    var shouldFailOnDelete = false

    /// Track method calls for verification in tests
    private(set) var saveCallCount = 0
    private(set) var retrieveCallCount = 0
    private(set) var deleteCallCount = 0

    /// Last key that was accessed (for test verification)
    private(set) var lastAccessedKey: String?

    // MARK: - SecureStorageProtocol

    func save(key: String, value: String) throws {
        lock.lock()
        defer { lock.unlock() }

        saveCallCount += 1
        lastAccessedKey = key

        if shouldFailOnSave {
            throw KeychainError.unexpectedError(-1)
        }

        storage[key] = value
    }

    func retrieve(key: String) throws -> String? {
        lock.lock()
        defer { lock.unlock() }

        retrieveCallCount += 1
        lastAccessedKey = key

        if shouldFailOnRetrieve {
            throw KeychainError.unexpectedError(-1)
        }

        return storage[key]
    }

    func delete(key: String) throws {
        lock.lock()
        defer { lock.unlock() }

        deleteCallCount += 1
        lastAccessedKey = key

        if shouldFailOnDelete {
            throw KeychainError.unexpectedError(-1)
        }

        storage.removeValue(forKey: key)
    }

    func exists(key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        lastAccessedKey = key
        return storage[key] != nil
    }

    // MARK: - Test Helpers

    /// Reset the mock to initial state
    func reset() {
        lock.lock()
        defer { lock.unlock() }

        storage.removeAll()
        saveCallCount = 0
        retrieveCallCount = 0
        deleteCallCount = 0
        lastAccessedKey = nil
        shouldFailOnSave = false
        shouldFailOnRetrieve = false
        shouldFailOnDelete = false
    }

    /// Get all stored keys (for test verification)
    var allKeys: [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(storage.keys)
    }

    /// Get storage count (for test verification)
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }

    /// Directly set a value (bypasses save tracking, for test setup)
    func setValueDirectly(key: String, value: String) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = value
    }
}
