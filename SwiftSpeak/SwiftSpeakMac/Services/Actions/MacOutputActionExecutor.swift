//
//  MacOutputActionExecutor.swift
//  SwiftSpeakMac
//
//  Phase 17: Execute output actions for Power Modes on macOS
//  Delivers Power Mode results to various destinations
//

import Foundation
import SwiftUI
import AppKit
import SwiftSpeakCore
import UserNotifications
import AVFoundation

// MARK: - Mac Output Action Executor

@MainActor
final class MacOutputActionExecutor {

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

    private let settings: MacSettings
    private let shortcutBridge: MacShortcutBridge
    private let textToSpeechService: MacTextToSpeechService
    private let textInsertionService: MacTextInsertionService?

    // MARK: - Initialization

    init(
        settings: MacSettings,
        shortcutBridge: MacShortcutBridge? = nil,
        textToSpeechService: MacTextToSpeechService? = nil,
        textInsertionService: MacTextInsertionService? = nil
    ) {
        self.settings = settings
        self.shortcutBridge = shortcutBridge ?? MacShortcutBridge()
        self.textToSpeechService = textToSpeechService ?? MacTextToSpeechService()
        self.textInsertionService = textInsertionService
    }

    // MARK: - Execute All Actions

    /// Execute all enabled output actions for a Power Mode result
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

        switch action.type {
        case .clipboard:
            return await executeClipboard(action: action, output: output)

        case .insertAtCursor:
            return await executeInsertAtCursor(action: action, output: output)

        case .insertAndSend:
            return await executeInsertAndSend(action: action, output: output)

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
        // Obsidian save would use the Obsidian URL scheme or direct file access on macOS
        // This is a placeholder - actual implementation depends on Obsidian integration
        guard let saveAction = action.obsidianSaveAction else {
            return .failure(action: action, error: "Save action type not specified")
        }

        guard let vaultId = action.obsidianTargetVaultId else {
            return .failure(action: action, error: "Target vault not specified")
        }

        // For now, return a placeholder error
        // Full implementation would use obsidian:// URL scheme or direct file write
        return .failure(action: action, error: "Obsidian save (\(saveAction.displayName)) not yet implemented on macOS for vault \(vaultId)")
    }

    // MARK: - Clipboard Action

    private func executeClipboard(action: OutputAction, output: String) async -> OutputActionResult {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(output, forType: .string)
        return .success(action: action)
    }

    // MARK: - Insert at Cursor Action

    private func executeInsertAtCursor(action: OutputAction, output: String) async -> OutputActionResult {
        guard let textInsertionService = textInsertionService else {
            // Fallback to clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(output, forType: .string)
            return .success(action: action)
        }

        let result = await textInsertionService.insertText(output, replaceSelection: false)

        switch result {
        case .accessibilitySuccess:
            return .success(action: action)
        case .clipboardFallback:
            return .success(action: action)
        case .failed(let error):
            return .failure(action: action, error: error.localizedDescription)
        }
    }

    // MARK: - Insert & Send Action

    private func executeInsertAndSend(action: OutputAction, output: String) async -> OutputActionResult {
        guard let textInsertionService = textInsertionService else {
            return .failure(action: action, error: "Text insertion service not available (requires non-sandboxed mode)")
        }

        let result = await textInsertionService.insertTextAndSend(output, replaceSelection: false)

        switch result {
        case .accessibilitySuccess:
            return .success(action: action)
        case .clipboardFallback:
            return .success(action: action)
        case .failed(let error):
            return .failure(action: action, error: error.localizedDescription)
        }
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
        // macOS doesn't have webhooks configured yet - they sync from iOS
        return .failure(action: action, error: "Webhooks not yet available on macOS")
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
        content.body = String(output.prefix(200))
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
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
        // Copy to clipboard and show sharing service picker
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(output, forType: .string)

        // Post notification to show sharing picker
        NotificationCenter.default.post(
            name: .macShowShareSheet,
            object: nil,
            userInfo: ["content": output]
        )

        return .success(action: action)
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

        NSWorkspace.shared.open(url)
        return .success(action: action)
    }

    // MARK: - Chain Power Mode Action

    private func executeChainPowerMode(action: OutputAction, output: String) async -> OutputActionResult {
        guard let chainedId = action.chainedPowerModeId else {
            return .failure(action: action, error: "Chained Power Mode ID is required")
        }

        // Check if Power Mode exists
        guard settings.powerModes.contains(where: { $0.id == chainedId }) else {
            return .failure(action: action, error: "Chained Power Mode not found")
        }

        // Post notification to trigger the chained Power Mode
        NotificationCenter.default.post(
            name: .macChainPowerMode,
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
    /// Posted when a share sheet should be shown on macOS
    static let macShowShareSheet = Notification.Name("macShowShareSheet")

    /// Posted when a Power Mode should be chained on macOS
    static let macChainPowerMode = Notification.Name("macChainPowerMode")
}
