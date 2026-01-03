//
//  KeychainManager.swift
//  SwiftSpeak
//
//  Phase 6: Secure storage for API keys using iOS Keychain
//

import Foundation
import Security

// MARK: - Protocol

/// Protocol for secure storage operations, enabling dependency injection and testing
public protocol SecureStorageProtocol: Sendable {
    public func save(key: String, value: String) throws
    public func retrieve(key: String) throws -> String?
    public func delete(key: String) throws
    public func exists(key: String) -> Bool
}

// MARK: - Errors

public enum KeychainError: LocalizedError {
    case itemNotFound
    case duplicateItem
    case encodingError
    case decodingError
    case unexpectedError(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "The requested item was not found in the Keychain."
        case .duplicateItem:
            return "An item with this key already exists in the Keychain."
        case .encodingError:
            return "Failed to encode the value for storage."
        case .decodingError:
            return "Failed to decode the stored value."
        case .unexpectedError(let status):
            return "Keychain error: \(status)"
        }
    }
}

// MARK: - KeychainManager

/// Thread-safe Keychain manager for storing sensitive data like API keys
/// Configured for sharing between main app and keyboard extension via access group
final class KeychainManager: SecureStorageProtocol, @unchecked Sendable {

    // MARK: - Singleton

    public static let shared = KeychainManager()

    // MARK: - Properties

    /// Access group for sharing Keychain items between app and keyboard extension
    /// Format: $(AppIdentifierPrefix)group.pawelgawliczek.swiftspeak
    private let accessGroup: String?

    /// Service identifier for Keychain items
    private let service = "pawelgawliczek.SwiftSpeak"

    /// Serial queue for thread-safe Keychain operations
    private let queue = DispatchQueue(label: "com.swiftspeak.keychain", qos: .userInitiated)

    // MARK: - Initialization

    public init(accessGroup: String? = nil) {
        // Use the provided access group or default to the shared app group
        // Note: In production, this should match the Keychain Sharing entitlement
        self.accessGroup = accessGroup
    }

    // MARK: - Public Methods

    /// Save a value to the Keychain
    /// - Parameters:
    ///   - key: Unique identifier for the item (e.g., "swiftspeak.apikey.openai")
    ///   - value: The string value to store
    public func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingError
        }

        try queue.sync {
            // Build the query
            var query = baseQuery(for: key)
            query[kSecValueData as String] = data

            // Try to add the item
            var status = SecItemAdd(query as CFDictionary, nil)

            // If item already exists, update it instead
            if status == errSecDuplicateItem {
                let updateQuery = baseQuery(for: key)
                let updateAttributes: [String: Any] = [
                    kSecValueData as String: data
                ]
                status = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
            }

            guard status == errSecSuccess else {
                throw mapError(status)
            }
        }
    }

    /// Retrieve a value from the Keychain
    /// - Parameter key: Unique identifier for the item
    /// - Returns: The stored string value, or nil if not found
    public func retrieve(key: String) throws -> String? {
        try queue.sync {
            var query = baseQuery(for: key)
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            if status == errSecItemNotFound {
                return nil
            }

            guard status == errSecSuccess else {
                throw mapError(status)
            }

            guard let data = result as? Data,
                  let value = String(data: data, encoding: .utf8) else {
                throw KeychainError.decodingError
            }

            return value
        }
    }

    /// Delete an item from the Keychain
    /// - Parameter key: Unique identifier for the item
    public func delete(key: String) throws {
        try queue.sync {
            let query = baseQuery(for: key)
            let status = SecItemDelete(query as CFDictionary)

            // Ignore "item not found" errors on delete
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw mapError(status)
            }
        }
    }

    /// Check if an item exists in the Keychain
    /// - Parameter key: Unique identifier for the item
    /// - Returns: True if the item exists
    public func exists(key: String) -> Bool {
        queue.sync {
            var query = baseQuery(for: key)
            query[kSecReturnData as String] = false

            let status = SecItemCopyMatching(query as CFDictionary, nil)
            return status == errSecSuccess
        }
    }

    /// Delete all items for this service (useful for testing or reset)
    public func deleteAll() throws {
        try queue.sync {
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service
            ]

            if let accessGroup = accessGroup {
                query[kSecAttrAccessGroup as String] = accessGroup
            }

            let status = SecItemDelete(query as CFDictionary)

            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw mapError(status)
            }
        }
    }

    // MARK: - Private Methods

    /// Build the base query dictionary for Keychain operations
    private func baseQuery(for key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            // Use AfterFirstUnlock so keyboard extension can access in background
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            // Don't sync to iCloud Keychain (API keys should be device-local)
            kSecAttrSynchronizable as String: false
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }

    /// Map Keychain OSStatus to our error type
    private func mapError(_ status: OSStatus) -> KeychainError {
        switch status {
        case errSecItemNotFound:
            return .itemNotFound
        case errSecDuplicateItem:
            return .duplicateItem
        default:
            return .unexpectedError(status)
        }
    }
}

// MARK: - Keychain Keys

/// Namespaced keys for Keychain items
public enum KeychainKeys {
    private static let prefix = "swiftspeak.apikey."

    public static let openAI = prefix + "openai"
    public static let anthropic = prefix + "anthropic"
    public static let google = prefix + "google"
    public static let elevenLabs = prefix + "elevenlabs"
    public static let deepgram = prefix + "deepgram"
    public static let assemblyAI = prefix + "assemblyai"
    public static let deepL = prefix + "deepl"
    public static let azure = prefix + "azure"
    public static let local = prefix + "local"

    /// Get the Keychain key for a given AIProvider
    public static func key(for provider: AIProvider) -> String {
        switch provider {
        case .openAI: return openAI
        case .anthropic: return anthropic
        case .google: return google
        case .elevenLabs: return elevenLabs
        case .deepgram: return deepgram
        case .assemblyAI: return assemblyAI
        case .deepL: return deepL
        case .azure: return azure
        case .local: return local
        }
    }
}
