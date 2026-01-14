//
//  InputActionExecutor.swift
//  SwiftSpeak
//
//  Phase 17: Execute input actions for Power Modes
//  Gathers context from various sources before Power Mode processing
//

import Foundation
import SwiftUI
import SwiftSpeakCore
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Input Action Executor

@MainActor
final class InputActionExecutor {

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

    private let settings: SharedSettings
    private let webhookExecutor: WebhookExecutor
    private let shortcutBridge: ShortcutBridge
    private let session: URLSession

    // MARK: - Initialization

    init(
        settings: SharedSettings,
        webhookExecutor: WebhookExecutor? = nil,
        shortcutBridge: ShortcutBridge? = nil,
        session: URLSession? = nil
    ) {
        self.settings = settings
        self.webhookExecutor = webhookExecutor ?? WebhookExecutor(settings: settings)
        self.shortcutBridge = shortcutBridge ?? ShortcutBridge()

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
        // Some actions (like file picker) require user interaction and must be sequential
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

        // Execute sequential actions one by one (only if no required failure yet)
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

        // If a required action failed, throw an error
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

        #if os(iOS)
        guard action.type.availableOnIOS else {
            return .failure(action: action, error: ExecutionError.unsupportedPlatform(action.type).localizedDescription)
        }
        #endif

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

        case .screenContext:
            return await executeScreenContext(action: action)
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
        return .failure(action: action, error: "RAG documents search not yet implemented. Query: \(searchQuery)")
    }

    // MARK: - Obsidian Vaults Action

    private func executeObsidianVaults(action: InputAction) async -> InputActionResult {
        // Obsidian vault search would query connected vaults
        // This is a placeholder - actual implementation depends on Obsidian integration
        let maxResults = action.obsidianMaxResults ?? 5
        return .failure(action: action, error: "Obsidian vaults search not yet implemented. Max results: \(maxResults)")
    }

    // MARK: - Clipboard Action

    private func executeClipboard(action: InputAction) async -> InputActionResult {
        #if canImport(UIKit)
        let pasteboard = UIPasteboard.general
        if let content = pasteboard.string, !content.isEmpty {
            return .success(action: action, content: content)
        } else {
            return .failure(action: action, error: "Clipboard is empty or contains non-text data")
        }
        #else
        // macOS - would use NSPasteboard
        return .failure(action: action, error: "Clipboard not available on this platform")
        #endif
    }

    // MARK: - Selected Text Action (macOS only)

    private func executeSelectedText(action: InputAction) async -> InputActionResult {
        #if os(iOS)
        return .failure(action: action, error: "Selected text is only available on macOS")
        #else
        // macOS implementation would use accessibility APIs
        return .failure(action: action, error: "Selected text not implemented yet")
        #endif
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
                // Truncate very long content
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
        // File picker requires user interaction
        // This would need to be triggered from UI and result passed back
        // For now, return a placeholder that indicates the action type needs UI handling
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
                // Fire and forget
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

        guard let webhook = settings.getWebhook(id: webhookId) else {
            return .failure(action: action, error: "Webhook not found")
        }

        // Use the existing WebhookExecutor to fetch context
        // Create a minimal PowerMode with just this webhook enabled
        let tempPowerMode = PowerMode(
            name: "temp",
            enabledWebhookIds: [webhookId]
        )

        let results = await webhookExecutor.fetchContext(for: tempPowerMode)

        if let result = results.first {
            if let content = result.content {
                return .success(action: action, content: content)
            } else if let error = result.error {
                return .failure(action: action, error: error)
            }
        }

        return .failure(action: action, error: "Webhook returned no result")
    }

    // MARK: - Screen Context Action

    private func executeScreenContext(action: InputAction) async -> InputActionResult {
        let captureManager = ContextCaptureManager.shared

        // Check if context capture is enabled in settings
        guard settings.contextCaptureEnabled else {
            return .failure(action: action, error: "Screen context capture is disabled in settings. Enable it in Settings → SwiftLink → Context Capture.")
        }

        // Refresh state to get latest capture status
        captureManager.refreshState()

        // Check if broadcast is active
        guard captureManager.isCapturing else {
            return .failure(action: action, error: "Screen recording is not active. Start a SwiftLink session with screen recording to capture screen context.")
        }

        // Request fresh OCR from the broadcast extension (waits for result)
        let screenText = await captureManager.requestFreshContext(timeout: 8.0)

        if let text = screenText, !text.isEmpty {
            // Truncate very long content
            let maxLength = 30000
            let truncatedContent = text.count > maxLength
                ? String(text.prefix(maxLength)) + "\n...[truncated]"
                : text

            appLog("Screen context captured: \(truncatedContent.count) characters", category: "InputAction")
            return .success(action: action, content: truncatedContent)
        } else {
            return .failure(action: action, error: "No text detected on screen. Ensure the screen contains readable text and the broadcast extension is responding.")
        }
    }

    // MARK: - Helpers

    /// Partition actions into parallel-safe and sequential (requires user interaction)
    private func partitionActions(_ actions: [InputAction]) -> (parallel: [InputAction], sequential: [InputAction]) {
        var parallel: [InputAction] = []
        var sequential: [InputAction] = []

        for action in actions {
            switch action.type {
            case .filePicker:
                // File picker requires user interaction
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
    /// Check if this action type is required in the given list
    func isRequired(in actions: [InputAction]) -> Bool {
        actions.first { $0.type == self }?.isRequired ?? false
    }
}
