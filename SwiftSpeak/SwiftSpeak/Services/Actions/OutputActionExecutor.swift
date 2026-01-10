//
//  OutputActionExecutor.swift
//  SwiftSpeak
//
//  Phase 17: Execute output actions for Power Modes
//  Delivers Power Mode results to various destinations
//

import Foundation
import SwiftUI
import SwiftSpeakCore
import UserNotifications
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Output Action Executor

@MainActor
final class OutputActionExecutor {

    // MARK: - Types

    enum ExecutionError: Error, LocalizedError {
        case actionNotEnabled
        case actionFailed(String)
        case requiredActionFailed(String)
        case webhookNotFound(UUID)
        case powerModeNotFound(UUID)
        case unsupportedPlatform(OutputActionType)
        case notificationDenied

        var errorDescription: String? {
            switch self {
            case .actionNotEnabled:
                return "Action is not enabled"
            case .actionFailed(let message):
                return message
            case .requiredActionFailed(let message):
                return "Required action failed: \(message)"
            case .webhookNotFound(let id):
                return "Webhook not found: \(id)"
            case .powerModeNotFound(let id):
                return "Power Mode not found: \(id)"
            case .unsupportedPlatform(let type):
                return "\(type.displayName) is not supported on this platform"
            case .notificationDenied:
                return "Notification permission denied"
            }
        }
    }

    // MARK: - Properties

    private let settings: SharedSettings
    private let webhookExecutor: WebhookExecutor
    private let shortcutBridge: ShortcutBridge
    private let textToSpeechService: TextToSpeechService

    // MARK: - Initialization

    init(
        settings: SharedSettings,
        webhookExecutor: WebhookExecutor? = nil,
        shortcutBridge: ShortcutBridge? = nil,
        textToSpeechService: TextToSpeechService? = nil
    ) {
        self.settings = settings
        self.webhookExecutor = webhookExecutor ?? WebhookExecutor(settings: settings)
        self.shortcutBridge = shortcutBridge ?? ShortcutBridge()
        self.textToSpeechService = textToSpeechService ?? TextToSpeechService()
    }

    // MARK: - Execute All Actions

    /// Execute all enabled output actions for a Power Mode result
    /// - Parameters:
    ///   - actions: The output actions to execute
    ///   - output: The Power Mode output text
    ///   - powerMode: The Power Mode that generated the output (for context)
    /// - Returns: Array of results for each action
    /// - Throws: ExecutionError if a required action fails
    func execute(
        actions: [OutputAction],
        output: String,
        powerMode: PowerMode
    ) async throws -> [OutputActionResult] {
        let enabledActions = actions.filter { $0.isEnabled }

        guard !enabledActions.isEmpty else {
            return []
        }

        // Sort by order
        let sortedActions = enabledActions.sorted { $0.order < $1.order }

        var results: [OutputActionResult] = []

        // Execute actions sequentially by order
        for action in sortedActions {
            let result = await executeSingle(
                action: action,
                output: output,
                powerMode: powerMode
            )
            results.append(result)

            // If a required action failed, stop and throw
            if !result.success && action.isRequired {
                throw ExecutionError.requiredActionFailed(result.error ?? "Unknown error")
            }
        }

        return results
    }

    // MARK: - Single Action Execution

    private func executeSingle(
        action: OutputAction,
        output: String,
        powerMode: PowerMode
    ) async -> OutputActionResult {
        guard action.isEnabled else {
            return .failure(action: action, error: ExecutionError.actionNotEnabled.localizedDescription)
        }

        #if os(iOS)
        guard action.type.availableOnIOS else {
            return .failure(action: action, error: ExecutionError.unsupportedPlatform(action.type).localizedDescription)
        }
        #endif

        switch action.type {
        case .clipboard:
            return await executeClipboard(action: action, output: output)

        case .insertAtCursor:
            return await executeInsertAtCursor(action: action, output: output)

        case .insertAndSend:
            // Not available on iOS - requires macOS accessibility features
            return .failure(action: action, error: "Insert & Send is only available on macOS")

        case .obsidianSave:
            return await executeObsidianSave(action: action, output: output)

        case .triggerShortcut:
            return await executeShortcut(action: action, output: output)

        case .webhook:
            return await executeWebhook(action: action, output: output, powerMode: powerMode)

        case .notification:
            return await executeNotification(action: action, output: output)

        case .textToSpeech:
            return await executeTextToSpeech(action: action, output: output)

        case .shareSheet:
            return await executeShareSheet(action: action, output: output)

        case .openURL:
            return await executeOpenURL(action: action, output: output)

        case .chainPowerMode:
            return await executeChainPowerMode(action: action, output: output)
        }
    }

    // MARK: - Obsidian Save Action

    private func executeObsidianSave(action: OutputAction, output: String) async -> OutputActionResult {
        // Obsidian save would use the Obsidian URL scheme or API
        // This is a placeholder - actual implementation depends on Obsidian integration
        guard let saveAction = action.obsidianSaveAction else {
            return .failure(action: action, error: "Save action type not specified")
        }

        guard let vaultId = action.obsidianTargetVaultId else {
            return .failure(action: action, error: "Target vault not specified")
        }

        // For now, return a placeholder error
        // Full implementation would use obsidian:// URL scheme
        return .failure(action: action, error: "Obsidian save (\(saveAction.displayName)) not yet implemented for vault \(vaultId)")
    }

    // MARK: - Clipboard Action

    private func executeClipboard(action: OutputAction, output: String) async -> OutputActionResult {
        #if canImport(UIKit)
        UIPasteboard.general.string = output
        return .success(action: action)
        #else
        return .failure(action: action, error: "Clipboard not available on this platform")
        #endif
    }

    // MARK: - Insert at Cursor Action

    private func executeInsertAtCursor(action: OutputAction, output: String) async -> OutputActionResult {
        #if canImport(UIKit)
        // On iOS, we copy to clipboard and simulate paste
        // The actual paste would be triggered by the keyboard extension
        UIPasteboard.general.string = output
        return .success(action: action)
        #else
        return .failure(action: action, error: "Insert at cursor not available on this platform")
        #endif
    }

    // MARK: - Shortcut Action

    private func executeShortcut(action: OutputAction, output: String) async -> OutputActionResult {
        guard let shortcutName = action.shortcutName, !shortcutName.isEmpty else {
            return .failure(action: action, error: "Shortcut name is required")
        }

        let waitForResult = action.waitForResult ?? false

        do {
            try await shortcutBridge.runShortcut(
                name: shortcutName,
                input: output,
                waitForResult: waitForResult
            )
            return .success(action: action)
        } catch {
            return .failure(action: action, error: error.localizedDescription)
        }
    }

    // MARK: - Webhook Action

    private func executeWebhook(
        action: OutputAction,
        output: String,
        powerMode: PowerMode
    ) async -> OutputActionResult {
        guard let webhookId = action.webhookId else {
            return .failure(action: action, error: "Webhook ID is required")
        }

        guard settings.getWebhook(id: webhookId) != nil else {
            return .failure(action: action, error: "Webhook not found")
        }

        // Create a temporary PowerMode with just this webhook enabled
        let tempPowerMode = PowerMode(
            name: powerMode.name,
            enabledWebhookIds: [webhookId]
        )

        // Use existing webhook executor
        let results = await webhookExecutor.sendOutput(
            for: tempPowerMode,
            input: "", // Input was the transcription, not relevant here
            output: output,
            contextName: nil
        )

        if let result = results.first {
            if result.success {
                return .success(action: action)
            } else {
                return .failure(action: action, error: result.error ?? "Webhook failed")
            }
        }

        return .failure(action: action, error: "Webhook returned no result")
    }

    // MARK: - Notification Action

    private func executeNotification(action: OutputAction, output: String) async -> OutputActionResult {
        let center = UNUserNotificationCenter.current()

        // Check permission
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            return .failure(action: action, error: "Notification permission not granted")
        }

        // Create notification
        let content = UNMutableNotificationContent()
        content.title = action.notificationTitle ?? "Power Mode Complete"
        content.body = output.prefix(200).description  // Truncate long outputs
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // Deliver immediately
        )

        do {
            try await center.add(request)
            return .success(action: action)
        } catch {
            return .failure(action: action, error: error.localizedDescription)
        }
    }

    // MARK: - Text to Speech Action

    private func executeTextToSpeech(action: OutputAction, output: String) async -> OutputActionResult {
        do {
            try await textToSpeechService.speak(
                text: output,
                voice: action.speakVoice
            )
            return .success(action: action)
        } catch {
            return .failure(action: action, error: error.localizedDescription)
        }
    }

    // MARK: - Share Sheet Action

    private func executeShareSheet(action: OutputAction, output: String) async -> OutputActionResult {
        #if canImport(UIKit)
        // Share sheet requires UI interaction
        // We'll copy to clipboard and indicate that share sheet should be shown
        UIPasteboard.general.string = output

        // Post notification that share sheet should be shown
        NotificationCenter.default.post(
            name: .showShareSheet,
            object: nil,
            userInfo: ["content": output]
        )

        return .success(action: action)
        #else
        return .failure(action: action, error: "Share sheet not available on this platform")
        #endif
    }

    // MARK: - Open URL Action

    private func executeOpenURL(action: OutputAction, output: String) async -> OutputActionResult {
        guard let urlTemplate = action.urlTemplate, !urlTemplate.isEmpty else {
            return .failure(action: action, error: "URL template is required")
        }

        // Replace {{output}} placeholder with actual output
        let encodedOutput = output.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? output
        let urlString = urlTemplate.replacingOccurrences(of: "{{output}}", with: encodedOutput)

        guard let url = URL(string: urlString) else {
            return .failure(action: action, error: "Invalid URL: \(urlString)")
        }

        #if canImport(UIKit)
        let canOpen = await UIApplication.shared.canOpenURL(url)
        guard canOpen else {
            return .failure(action: action, error: "Cannot open URL: \(urlString)")
        }

        await UIApplication.shared.open(url, options: [:])
        return .success(action: action)
        #else
        return .failure(action: action, error: "Open URL not available on this platform")
        #endif
    }

    // MARK: - Chain Power Mode Action

    private func executeChainPowerMode(action: OutputAction, output: String) async -> OutputActionResult {
        guard let chainedId = action.chainedPowerModeId else {
            return .failure(action: action, error: "Chained Power Mode ID is required")
        }

        // Find the chained Power Mode
        guard settings.powerModes.contains(where: { $0.id == chainedId }) else {
            return .failure(action: action, error: "Chained Power Mode not found")
        }

        // Post notification to trigger the chained Power Mode
        NotificationCenter.default.post(
            name: .chainPowerMode,
            object: nil,
            userInfo: [
                "powerModeId": chainedId,
                "input": output
            ]
        )

        return .success(action: action)
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    /// Posted when a share sheet should be shown with content
    static let showShareSheet = Notification.Name("showShareSheet")

    /// Posted when a Power Mode should be chained
    static let chainPowerMode = Notification.Name("chainPowerMode")
}
