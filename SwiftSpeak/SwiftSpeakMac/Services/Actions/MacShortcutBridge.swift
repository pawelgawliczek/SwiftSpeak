//
//  MacShortcutBridge.swift
//  SwiftSpeakMac
//
//  Phase 17: Bridge to Apple Shortcuts for Power Mode actions on macOS
//  Uses NSWorkspace to run Shortcuts
//

import Foundation
import AppKit

// MARK: - Mac Shortcut Bridge

@MainActor
final class MacShortcutBridge {

    // MARK: - Types

    enum ShortcutError: Error, LocalizedError {
        case shortcutNameEmpty
        case shortcutNotFound(String)
        case urlEncodingFailed
        case cannotOpenURL
        case timeout
        case cancelled
        case resultNotReceived

        var errorDescription: String? {
            switch self {
            case .shortcutNameEmpty:
                return "Shortcut name cannot be empty"
            case .shortcutNotFound(let name):
                return "Shortcut '\(name)' not found"
            case .urlEncodingFailed:
                return "Failed to encode shortcut URL"
            case .cannotOpenURL:
                return "Cannot open Shortcuts app"
            case .timeout:
                return "Shortcut execution timed out"
            case .cancelled:
                return "Shortcut execution was cancelled"
            case .resultNotReceived:
                return "Shortcut result was not received"
            }
        }
    }

    // MARK: - Configuration

    /// Default timeout for waiting for Shortcut results
    static let defaultTimeout: TimeInterval = 30.0

    /// URL scheme for SwiftSpeak callbacks
    private static let callbackScheme = "swiftspeakmac"
    private static let callbackHost = "shortcut-result"

    // MARK: - Properties

    /// Pending callback continuations keyed by request ID
    private var pendingCallbacks: [String: CheckedContinuation<String?, Error>] = [:]

    /// Timeout duration for Shortcut execution
    var timeout: TimeInterval = MacShortcutBridge.defaultTimeout

    // MARK: - Initialization

    init() {}

    // MARK: - Run Shortcut

    /// Run an Apple Shortcut
    /// - Parameters:
    ///   - name: The exact name of the Shortcut (case-sensitive)
    ///   - input: Optional text input to pass to the Shortcut
    ///   - waitForResult: If true, waits for Shortcut to complete and return result
    /// - Returns: The Shortcut's output if waitForResult is true, nil otherwise
    /// - Throws: ShortcutError if the Shortcut cannot be run
    @discardableResult
    func runShortcut(
        name: String,
        input: String?,
        waitForResult: Bool
    ) async throws -> String? {
        guard !name.isEmpty else {
            throw ShortcutError.shortcutNameEmpty
        }

        if waitForResult {
            return try await runShortcutWithCallback(name: name, input: input)
        } else {
            try await runShortcutFireAndForget(name: name, input: input)
            return nil
        }
    }

    // MARK: - Fire and Forget

    private func runShortcutFireAndForget(name: String, input: String?) async throws {
        // Build shortcuts:// URL
        var urlString = "shortcuts://run-shortcut?name=\(name.urlEncoded)"

        if let input = input {
            urlString += "&input=text&text=\(input.urlEncoded)"
        }

        guard let url = URL(string: urlString) else {
            throw ShortcutError.urlEncodingFailed
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false  // Don't bring Shortcuts to front

        do {
            try await NSWorkspace.shared.open(url, configuration: configuration)
        } catch {
            throw ShortcutError.cannotOpenURL
        }
    }

    // MARK: - With Callback

    private func runShortcutWithCallback(name: String, input: String?) async throws -> String? {
        let requestId = UUID().uuidString

        // Build callback URL
        let callbackURL = "\(Self.callbackScheme)://\(Self.callbackHost)?id=\(requestId)"

        // Build shortcuts:// URL with x-callback-url
        var urlString = "shortcuts://x-callback-url/run-shortcut"
        urlString += "?name=\(name.urlEncoded)"

        if let input = input {
            urlString += "&input=text"
            urlString += "&text=\(input.urlEncoded)"
        }

        // Add callback URLs
        urlString += "&x-success=\(callbackURL.urlEncoded)%26result%3D[[output]]"
        urlString += "&x-cancel=\(callbackURL.urlEncoded)%26cancelled%3D1"
        urlString += "&x-error=\(callbackURL.urlEncoded)%26error%3D[[errorMessage]]"

        guard let url = URL(string: urlString) else {
            throw ShortcutError.urlEncodingFailed
        }

        // Create continuation to wait for callback
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: ShortcutError.cancelled)
                return
            }

            // Store the continuation
            self.pendingCallbacks[requestId] = continuation

            // Set up timeout
            Task {
                try await Task.sleep(nanoseconds: UInt64(self.timeout * 1_000_000_000))

                // If still pending after timeout, cancel it
                if let pending = self.pendingCallbacks.removeValue(forKey: requestId) {
                    pending.resume(throwing: ShortcutError.timeout)
                }
            }

            // Open the Shortcuts app
            Task { @MainActor in
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = false
                try? await NSWorkspace.shared.open(url, configuration: configuration)
            }
        }
    }

    // MARK: - Handle Callback

    /// Handle a callback URL from Shortcuts
    /// Call this from your app's URL handler when receiving a swiftspeakmac://shortcut-result URL
    /// - Parameter url: The callback URL
    /// - Returns: True if the URL was handled
    @discardableResult
    func handleCallback(url: URL) -> Bool {
        guard url.scheme == Self.callbackScheme,
              url.host == Self.callbackHost else {
            return false
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        guard let requestId = queryItems.first(where: { $0.name == "id" })?.value else {
            return false
        }

        guard let continuation = pendingCallbacks.removeValue(forKey: requestId) else {
            return true
        }

        // Check for cancellation
        if queryItems.first(where: { $0.name == "cancelled" })?.value == "1" {
            continuation.resume(throwing: ShortcutError.cancelled)
            return true
        }

        // Check for error
        if let errorMessage = queryItems.first(where: { $0.name == "error" })?.value {
            continuation.resume(throwing: ShortcutError.shortcutNotFound(errorMessage))
            return true
        }

        // Get result
        let result = queryItems.first(where: { $0.name == "result" })?.value
        continuation.resume(returning: result)
        return true
    }

    // MARK: - Cancel All

    /// Cancel all pending Shortcut callbacks
    func cancelAll() {
        for (_, continuation) in pendingCallbacks {
            continuation.resume(throwing: ShortcutError.cancelled)
        }
        pendingCallbacks.removeAll()
    }
}

// MARK: - String URL Encoding

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
