//
//  MacInputActionExecutor.swift
//  SwiftSpeakMac
//
//  Phase 17: Execute input actions for Power Modes on macOS
//  Gathers context from various sources before Power Mode processing
//

import Foundation
import SwiftUI
import AppKit
import SwiftSpeakCore

// MARK: - Mac Input Action Executor

@MainActor
final class MacInputActionExecutor {

    // MARK: - Types

    enum ExecutionError: Error, LocalizedError {
        case actionNotEnabled
        case actionFailed(String)
        case requiredActionFailed(String)
        case shortcutNotFound(String)
        case webhookNotFound(UUID)
        case urlFetchFailed(String)
        case filePickerCancelled
        case unsupportedPlatform(InputActionType)

        var errorDescription: String? {
            switch self {
            case .actionNotEnabled:
                return "Action is not enabled"
            case .actionFailed(let message):
                return message
            case .requiredActionFailed(let message):
                return "Required action failed: \(message)"
            case .shortcutNotFound(let name):
                return "Shortcut '\(name)' not found"
            case .webhookNotFound(let id):
                return "Webhook not found: \(id)"
            case .urlFetchFailed(let message):
                return "URL fetch failed: \(message)"
            case .filePickerCancelled:
                return "File picker was cancelled"
            case .unsupportedPlatform(let type):
                return "\(type.displayName) is not supported on this platform"
            }
        }
    }

    // MARK: - Properties

    private let settings: MacSettings
    private let shortcutBridge: MacShortcutBridge
    private let windowContextService: MacWindowContextService?
    private let session: URLSession

    // MARK: - Initialization

    init(
        settings: MacSettings,
        shortcutBridge: MacShortcutBridge? = nil,
        windowContextService: MacWindowContextService? = nil,
        session: URLSession? = nil
    ) {
        self.settings = settings
        self.shortcutBridge = shortcutBridge ?? MacShortcutBridge()
        self.windowContextService = windowContextService

        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 60
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - Execute All Actions

    /// Execute all enabled input actions for a Power Mode
    /// - Parameter actions: The input actions to execute
    /// - Returns: Array of results for each action
    /// - Throws: ExecutionError if a required action fails
    func execute(actions: [InputAction]) async throws -> [InputActionResult] {
        let enabledActions = actions.filter { $0.isEnabled }

        guard !enabledActions.isEmpty else {
            return []
        }

        var results: [InputActionResult] = []
        var hasRequiredFailure = false
        var requiredFailureMessage = ""

        // Execute actions in parallel where safe
        let (parallelActions, sequentialActions) = partitionActions(enabledActions)

        // Execute parallel actions concurrently
        if !parallelActions.isEmpty {
            let parallelResults = await executeParallel(actions: parallelActions)
            results.append(contentsOf: parallelResults)

            // Check for required failures
            for result in parallelResults {
                if let error = result.error, result.actionType.isRequired(in: enabledActions) {
                    hasRequiredFailure = true
                    requiredFailureMessage = error
                    break
                }
            }
        }

        // Execute sequential actions one by one
        if !hasRequiredFailure {
            for action in sequentialActions {
                let result = await executeSingle(action: action)
                results.append(result)

                if let error = result.error, action.isRequired {
                    hasRequiredFailure = true
                    requiredFailureMessage = error
                    break
                }
            }
        }

        if hasRequiredFailure {
            throw ExecutionError.requiredActionFailed(requiredFailureMessage)
        }

        return results
    }

    // MARK: - Parallel Execution

    private func executeParallel(actions: [InputAction]) async -> [InputActionResult] {
        var results: [InputActionResult] = []

        await withTaskGroup(of: InputActionResult.self) { group in
            for action in actions {
                group.addTask {
                    await self.executeSingle(action: action)
                }
            }

            for await result in group {
                results.append(result)
            }
        }

        return results
    }

    // MARK: - Single Action Execution

    private func executeSingle(action: InputAction) async -> InputActionResult {
        guard action.isEnabled else {
            return .failure(action: action, error: ExecutionError.actionNotEnabled.localizedDescription)
        }

        switch action.type {
        case .memory:
            return await executeMemory(action: action)

        case .ragDocuments:
            return await executeRAGDocuments(action: action)

        case .obsidianVaults:
            return await executeObsidianVaults(action: action)

        case .clipboard:
            return await executeClipboard(action: action)

        case .selectedText:
            return await executeSelectedText(action: action)

        case .urlFetch:
            return await executeUrlFetch(action: action)

        case .filePicker:
            return await executeFilePicker(action: action)

        case .shortcutResult:
            return await executeShortcut(action: action)

        case .webhook:
            return await executeWebhook(action: action)
        }
    }

    // MARK: - Memory Action

    private func executeMemory(action: InputAction) async -> InputActionResult {
        var memoryParts: [String] = []

        // Gather memory based on configuration
        if action.includeGlobalMemory ?? true {
            if let globalMemory = settings.globalMemory, !globalMemory.isEmpty {
                memoryParts.append("Global Memory:\n\(globalMemory)")
            }
        }

        if action.includeContextMemory ?? true {
            // Context memory would be gathered from current context
            // This is a placeholder - actual implementation depends on context system
        }

        if action.includePowerModeMemory ?? true {
            // Power Mode memory would be gathered from the specific Power Mode
            // This is a placeholder - actual implementation depends on Power Mode memory system
        }

        if memoryParts.isEmpty {
            return .failure(action: action, error: "No memory content available")
        }

        return .success(action: action, content: memoryParts.joined(separator: "\n\n"))
    }

    // MARK: - RAG Documents Action

    private func executeRAGDocuments(action: InputAction) async -> InputActionResult {
        // RAG document search would query the knowledge base
        // This is a placeholder - actual implementation depends on RAG system
        let searchQuery = action.ragSearchQuery ?? "No search query provided"
        return .failure(action: action, error: "RAG documents search not yet implemented on macOS. Query: \(searchQuery)")
    }

    // MARK: - Obsidian Vaults Action

    private func executeObsidianVaults(action: InputAction) async -> InputActionResult {
        // Obsidian vault search would query connected vaults
        // This is a placeholder - actual implementation depends on Obsidian integration
        let maxResults = action.obsidianMaxResults ?? 5
        return .failure(action: action, error: "Obsidian vaults search not yet implemented on macOS. Max results: \(maxResults)")
    }

    // MARK: - Clipboard Action

    private func executeClipboard(action: InputAction) async -> InputActionResult {
        let pasteboard = NSPasteboard.general
        if let content = pasteboard.string(forType: .string), !content.isEmpty {
            return .success(action: action, content: content)
        } else {
            return .failure(action: action, error: "Clipboard is empty or contains non-text data")
        }
    }

    // MARK: - Selected Text Action

    private func executeSelectedText(action: InputAction) async -> InputActionResult {
        guard let windowService = windowContextService else {
            return .failure(action: action, error: "Window context service not available")
        }

        do {
            let context = try await windowService.captureWindowContext()
            if let selectedText = context.selectedText, !selectedText.isEmpty {
                return .success(action: action, content: selectedText)
            } else {
                return .failure(action: action, error: "No text selected")
            }
        } catch {
            return .failure(action: action, error: error.localizedDescription)
        }
    }

    // MARK: - URL Fetch Action

    private func executeUrlFetch(action: InputAction) async -> InputActionResult {
        guard let urlString = action.urlToFetch, let url = URL(string: urlString) else {
            return .failure(action: action, error: "Invalid or missing URL")
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(action: action, error: "Invalid response")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                return .failure(action: action, error: "HTTP \(httpResponse.statusCode)")
            }

            if let content = String(data: data, encoding: .utf8) {
                let maxLength = 50000
                let truncatedContent = content.count > maxLength
                    ? String(content.prefix(maxLength)) + "\n...[truncated]"
                    : content
                return .success(action: action, content: truncatedContent)
            } else {
                return .failure(action: action, error: "Could not decode response as text")
            }
        } catch {
            return .failure(action: action, error: error.localizedDescription)
        }
    }

    // MARK: - File Picker Action

    private func executeFilePicker(action: InputAction) async -> InputActionResult {
        // File picker requires user interaction - not yet implemented
        return .failure(action: action, error: "File picker requires user interaction - not yet implemented")
    }

    // MARK: - Shortcut Action

    private func executeShortcut(action: InputAction) async -> InputActionResult {
        guard let shortcutName = action.shortcutName, !shortcutName.isEmpty else {
            return .failure(action: action, error: "Shortcut name is required")
        }

        let waitForResult = action.waitForResult ?? true

        do {
            if waitForResult {
                let result = try await shortcutBridge.runShortcut(
                    name: shortcutName,
                    input: nil,
                    waitForResult: true
                )
                if let content = result {
                    return .success(action: action, content: content)
                } else {
                    return .failure(action: action, error: "Shortcut returned no output")
                }
            } else {
                try await shortcutBridge.runShortcut(
                    name: shortcutName,
                    input: nil,
                    waitForResult: false
                )
                return .success(action: action, content: "[Shortcut launched]")
            }
        } catch {
            return .failure(action: action, error: error.localizedDescription)
        }
    }

    // MARK: - Webhook Action

    private func executeWebhook(action: InputAction) async -> InputActionResult {
        guard let webhookId = action.webhookId else {
            return .failure(action: action, error: "Webhook ID is required")
        }

        // macOS doesn't have webhooks configured yet - they sync from iOS
        return .failure(action: action, error: "Webhooks not yet available on macOS")
    }

    // MARK: - Helpers

    private func partitionActions(_ actions: [InputAction]) -> (parallel: [InputAction], sequential: [InputAction]) {
        var parallel: [InputAction] = []
        var sequential: [InputAction] = []

        for action in actions {
            switch action.type {
            case .filePicker:
                sequential.append(action)
            default:
                parallel.append(action)
            }
        }

        return (parallel, sequential)
    }
}

// MARK: - Helper Extension

private extension InputActionType {
    func isRequired(in actions: [InputAction]) -> Bool {
        actions.first { $0.type == self }?.isRequired ?? false
    }
}
