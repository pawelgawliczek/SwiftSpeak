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
import Vision
import CoreGraphics

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

        case .screenContext:
            return await executeScreenContext(action: action)

        case .shareAudioImport:
            // Share Extension feature - handled via macOS Share Extension or drag-and-drop
            return .failure(action: action, error: "Share Audio Import is handled via Share Extension or drag-and-drop")

        case .shareTextImport:
            // Share Extension feature - handled via macOS Share Extension or drag-and-drop
            return .failure(action: action, error: "Share Text Import is handled via Share Extension or drag-and-drop")

        case .shareImageImport:
            // Share Extension feature - handled via macOS Share Extension or drag-and-drop
            return .failure(action: action, error: "Share Image Import is handled via Share Extension or drag-and-drop")

        case .shareURLImport:
            // Share Extension feature - handled via macOS Share Extension or drag-and-drop
            return .failure(action: action, error: "Share URL Import is handled via Share Extension or drag-and-drop")

        case .sharePDFImport:
            // Share Extension feature - handled via macOS Share Extension or drag-and-drop
            return .failure(action: action, error: "Share PDF Import is handled via Share Extension or drag-and-drop")
        }
    }

    // MARK: - Screen Context Action (macOS)

    private func executeScreenContext(action: InputAction) async -> InputActionResult {
        // Check screen recording permission first
        if !CGPreflightScreenCaptureAccess() {
            // Request permission (triggers system dialog on first request)
            let granted = CGRequestScreenCaptureAccess()
            if !granted {
                return .failure(
                    action: action,
                    error: "Screen Recording permission required. Please enable in System Preferences > Privacy & Security > Screen Recording, then restart the app."
                )
            }
        }

        // Capture the frontmost window as a screenshot and run OCR
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return .failure(action: action, error: "No active application found")
        }

        // Get the window list for the frontmost app
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

        // Find the frontmost window belonging to the active app
        let appPID = frontApp.processIdentifier
        guard let windowInfo = windowList.first(where: { info in
            guard let pid = info[kCGWindowOwnerPID as String] as? Int32,
                  let layer = info[kCGWindowLayer as String] as? Int else {
                return false
            }
            return pid == appPID && layer == 0  // Layer 0 is normal window level
        }),
        let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID else {
            return .failure(action: action, error: "Could not find active window for \(frontApp.localizedName ?? "app")")
        }

        // Capture the window as an image
        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .nominalResolution]
        ) else {
            return .failure(action: action, error: "Failed to capture window screenshot")
        }

        // Run OCR on the captured image
        do {
            let screenText = try await performOCRWithAttribution(on: cgImage)

            if screenText.isEmpty {
                return .failure(action: action, error: "No text detected on screen")
            }

            // Truncate very long content
            let maxLength = 30000
            let truncatedContent = screenText.count > maxLength
                ? String(screenText.prefix(maxLength)) + "\n...[truncated]"
                : screenText

            let appName = frontApp.localizedName ?? "Unknown"
            let header = "[Screen Context from \(appName)]\n"

            return .success(action: action, content: header + truncatedContent)
        } catch {
            return .failure(action: action, error: "OCR failed: \(error.localizedDescription)")
        }
    }

    /// Perform OCR on image with position-based message attribution for messengers
    private func performOCRWithAttribution(on cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                // Extract text with position-based attribution
                let text = self.extractTextWithAttribution(from: observations)
                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Extract text with position-based message attribution for messenger apps
    private func extractTextWithAttribution(from observations: [VNRecognizedTextObservation]) -> String {
        // Sort observations by vertical position (top to bottom)
        // Vision coordinates have origin at bottom-left, so higher Y = higher on screen
        let sortedObservations = observations.sorted { $0.boundingBox.midY > $1.boundingBox.midY }

        // Threshold for determining left vs right (messenger bubble position)
        let rightThreshold: CGFloat = 0.55
        let leftThreshold: CGFloat = 0.45

        var formattedLines: [String] = []
        var lastAttribution: String? = nil

        for observation in sortedObservations {
            guard let text = observation.topCandidates(1).first?.string,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            let midX = observation.boundingBox.midX

            // Determine attribution based on horizontal position
            let attribution: String?
            if midX > rightThreshold {
                attribution = "[YOU]"
            } else if midX < leftThreshold {
                attribution = "[OTHER]"
            } else {
                attribution = nil
            }

            // Only add attribution prefix when it changes
            if let attr = attribution {
                if attr != lastAttribution {
                    formattedLines.append("\(attr): \(text)")
                    lastAttribution = attr
                } else {
                    formattedLines.append(text)
                }
            } else {
                formattedLines.append(text)
                lastAttribution = nil
            }
        }

        return formattedLines.joined(separator: "\n")
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
