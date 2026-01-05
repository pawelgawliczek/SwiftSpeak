//
//  MacWindowContextService.swift
//  SwiftSpeakMac
//
//  Window context capture using macOS Accessibility API
//  Phase 5: Captures text from active window for Power Mode context
//

import AppKit
import ApplicationServices

// MARK: - Window Context

/// Context captured from the frontmost application window
public struct WindowContext: Sendable, Equatable {
    public let appName: String
    public let appBundleId: String
    public let windowTitle: String
    public let selectedText: String?
    public let visibleText: String?
    public let capturedAt: Date

    /// Combined text for display (prefers selected over visible)
    public var displayText: String {
        selectedText ?? visibleText ?? ""
    }

    /// Human-readable summary of captured context
    public var summary: String {
        var parts: [String] = []
        if !appName.isEmpty {
            parts.append("App: \(appName)")
        }
        if !windowTitle.isEmpty {
            parts.append("Window: \(windowTitle)")
        }
        if let selected = selectedText, !selected.isEmpty {
            parts.append("Selected: \(selected.prefix(50))...")
        } else if let visible = visibleText, !visible.isEmpty {
            parts.append("Visible: \(visible.prefix(50))...")
        }
        return parts.joined(separator: " | ")
    }

    public init(
        appName: String = "",
        appBundleId: String = "",
        windowTitle: String = "",
        selectedText: String? = nil,
        visibleText: String? = nil,
        capturedAt: Date = Date()
    ) {
        self.appName = appName
        self.appBundleId = appBundleId
        self.windowTitle = windowTitle
        self.selectedText = selectedText
        self.visibleText = visibleText
        self.capturedAt = capturedAt
    }
}

// MARK: - Window Context Errors

public enum WindowContextError: Error, LocalizedError {
    case accessibilityNotEnabled
    case noFrontmostApp
    case failedToAccessElement
    case noTextFound

    public var errorDescription: String? {
        switch self {
        case .accessibilityNotEnabled:
            return "Accessibility permission not granted. Please enable in System Settings > Privacy & Security > Accessibility."
        case .noFrontmostApp:
            return "No frontmost application found."
        case .failedToAccessElement:
            return "Failed to access window element. The app may not support accessibility."
        case .noTextFound:
            return "No text found in window."
        }
    }
}

// MARK: - Mac Window Context Service

/// Service for capturing text from the active window using Accessibility API
public actor MacWindowContextService {

    // MARK: - Configuration

    /// Maximum characters to capture from visible text (to avoid overwhelming context)
    private let maxVisibleTextLength: Int = 2000

    /// Maximum characters to capture from selected text
    private let maxSelectedTextLength: Int = 5000

    // MARK: - Initialization

    public init() {}

    // MARK: - Permission Checking

    /// Check if accessibility is enabled for this app
    public func isAccessibilityEnabled() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Request accessibility permission with system prompt
    /// Note: This will show a system dialog the first time
    public func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    // MARK: - Context Capture

    /// Capture context from the frontmost application window
    /// - Returns: WindowContext with captured text
    /// - Throws: WindowContextError if capture fails
    public func captureWindowContext() async throws -> WindowContext {
        // Check accessibility permission
        guard isAccessibilityEnabled() else {
            throw WindowContextError.accessibilityNotEnabled
        }

        // Get frontmost app
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontmostApp.bundleIdentifier else {
            throw WindowContextError.noFrontmostApp
        }

        let appName = frontmostApp.localizedName ?? bundleId
        let processIdentifier = frontmostApp.processIdentifier

        // Create AX application element
        let axApp = AXUIElementCreateApplication(processIdentifier)

        // Get window title
        let windowTitle = getWindowTitle(from: axApp) ?? ""

        // Try to get focused element for text extraction
        var selectedText: String?
        var visibleText: String?

        if let focusedElement = getFocusedElement(from: axApp) {
            // Try to get selected text first (if user has text highlighted)
            selectedText = getSelectedText(from: focusedElement)

            // If no selection, try to get all visible text
            if selectedText == nil || selectedText!.isEmpty {
                visibleText = getVisibleText(from: focusedElement)
            }
        }

        // If no focused element text, try to get text from window itself
        if selectedText == nil && visibleText == nil {
            visibleText = getTextFromWindow(axApp)
        }

        return WindowContext(
            appName: appName,
            appBundleId: bundleId,
            windowTitle: windowTitle,
            selectedText: selectedText,
            visibleText: visibleText,
            capturedAt: Date()
        )
    }

    /// Capture context from a specific application by PID
    /// Use this when you've captured the PID before showing UI to avoid capturing from the wrong app
    /// - Parameters:
    ///   - pid: Process ID of the target application
    ///   - bundleId: Bundle identifier of the target app
    ///   - appName: Display name of the target app
    /// - Returns: WindowContext with captured text
    /// - Throws: WindowContextError if capture fails
    public func captureWindowContext(from pid: pid_t, bundleId: String, appName: String) async throws -> WindowContext {
        print("[CONTEXT CAPTURE] Starting capture from PID \(pid) (\(appName))")

        // Check accessibility permission
        guard isAccessibilityEnabled() else {
            print("[CONTEXT CAPTURE] ERROR: Accessibility not enabled")
            throw WindowContextError.accessibilityNotEnabled
        }

        // Create AX application element for the specific PID
        let axApp = AXUIElementCreateApplication(pid)
        print("[CONTEXT CAPTURE] Created AXUIElement for PID \(pid)")

        // Get window title
        let windowTitle = getWindowTitle(from: axApp) ?? ""
        print("[CONTEXT CAPTURE] Window title: '\(windowTitle)'")

        // Try to get focused element for text extraction
        var selectedText: String?
        var visibleText: String?

        if let focusedElement = getFocusedElement(from: axApp) {
            print("[CONTEXT CAPTURE] Got focused element")

            // Try to get selected text first (if user has text highlighted)
            selectedText = getSelectedText(from: focusedElement)
            print("[CONTEXT CAPTURE] Selected text: \(selectedText != nil ? "'\(selectedText!.prefix(100))...'" : "nil")")

            // If no selection, try to get all visible text
            if selectedText == nil || selectedText!.isEmpty {
                visibleText = getVisibleText(from: focusedElement)
                print("[CONTEXT CAPTURE] Visible text: \(visibleText != nil ? "'\(visibleText!.prefix(100))...'" : "nil")")
            }
        } else {
            print("[CONTEXT CAPTURE] No focused element found")
        }

        // If no focused element text, try to get text from window itself
        if selectedText == nil && visibleText == nil {
            visibleText = getTextFromWindow(axApp)
            print("[CONTEXT CAPTURE] Text from window fallback: \(visibleText != nil ? "'\(visibleText!.prefix(100))...'" : "nil")")
        }

        print("[CONTEXT CAPTURE] Final result - selected: \(selectedText != nil), visible: \(visibleText != nil)")

        return WindowContext(
            appName: appName,
            appBundleId: bundleId,
            windowTitle: windowTitle,
            selectedText: selectedText,
            visibleText: visibleText,
            capturedAt: Date()
        )
    }

    /// Get frontmost app bundle ID and name
    /// - Returns: Tuple of (bundleId, appName) or nil
    public func getFrontmostApp() -> (bundleId: String, name: String)? {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontmostApp.bundleIdentifier else {
            return nil
        }

        let appName = frontmostApp.localizedName ?? bundleId
        return (bundleId, appName)
    }

    // MARK: - Private Helpers

    /// Get window title from AX application
    private func getWindowTitle(from axApp: AXUIElement) -> String? {
        var windowRef: CFTypeRef?

        // Get focused window
        let windowError = AXUIElementCopyAttributeValue(
            axApp,
            kAXFocusedWindowAttribute as CFString,
            &windowRef
        )

        guard windowError == .success,
              let window = windowRef else {
            return nil
        }

        // Get title from window
        var titleRef: CFTypeRef?
        let titleError = AXUIElementCopyAttributeValue(
            window as! AXUIElement,
            kAXTitleAttribute as CFString,
            &titleRef
        )

        guard titleError == .success,
              let title = titleRef as? String else {
            return nil
        }

        return title
    }

    /// Get focused UI element from AX application
    private func getFocusedElement(from axApp: AXUIElement) -> AXUIElement? {
        var focusedRef: CFTypeRef?

        let error = AXUIElementCopyAttributeValue(
            axApp,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )

        guard error == .success,
              let focused = focusedRef else {
            return nil
        }

        return (focused as! AXUIElement)
    }

    /// Get selected text from UI element
    private func getSelectedText(from element: AXUIElement) -> String? {
        var selectedRef: CFTypeRef?

        let error = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedRef
        )

        guard error == .success,
              let selected = selectedRef as? String,
              !selected.isEmpty else {
            return nil
        }

        // Truncate if too long
        let truncated = String(selected.prefix(maxSelectedTextLength))
        return truncated
    }

    /// Get all visible text from UI element
    private func getVisibleText(from element: AXUIElement) -> String? {
        var valueRef: CFTypeRef?

        // Try kAXValueAttribute first (works for text fields, text areas)
        var error = AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &valueRef
        )

        if error == .success, let value = valueRef as? String, !value.isEmpty {
            let truncated = String(value.prefix(maxVisibleTextLength))
            return truncated
        }

        // Try kAXDescriptionAttribute as fallback
        error = AXUIElementCopyAttributeValue(
            element,
            kAXDescriptionAttribute as CFString,
            &valueRef
        )

        if error == .success, let value = valueRef as? String, !value.isEmpty {
            let truncated = String(value.prefix(maxVisibleTextLength))
            return truncated
        }

        return nil
    }

    /// Get text from window (fallback method)
    private func getTextFromWindow(_ axApp: AXUIElement) -> String? {
        var windowRef: CFTypeRef?

        let windowError = AXUIElementCopyAttributeValue(
            axApp,
            kAXFocusedWindowAttribute as CFString,
            &windowRef
        )

        guard windowError == .success,
              let window = windowRef else {
            return nil
        }

        // Try to get window's value
        var valueRef: CFTypeRef?
        let valueError = AXUIElementCopyAttributeValue(
            window as! AXUIElement,
            kAXValueAttribute as CFString,
            &valueRef
        )

        if valueError == .success, let value = valueRef as? String, !value.isEmpty {
            let truncated = String(value.prefix(maxVisibleTextLength))
            return truncated
        }

        return nil
    }
}

// MARK: - Mock for Testing

#if DEBUG
/// Mock window context service for testing
public actor MockWindowContextService {
    private var mockContext: WindowContext?
    private var shouldThrowError: WindowContextError?

    public init() {}

    public func setMockContext(_ context: WindowContext) {
        mockContext = context
    }

    public func setError(_ error: WindowContextError?) {
        shouldThrowError = error
    }

    public func isAccessibilityEnabled() -> Bool {
        return shouldThrowError != .accessibilityNotEnabled
    }

    public func requestAccessibilityPermission() {
        // No-op for testing
    }

    public func captureWindowContext() async throws -> WindowContext {
        if let error = shouldThrowError {
            throw error
        }

        return mockContext ?? WindowContext(
            appName: "Test App",
            appBundleId: "com.test.app",
            windowTitle: "Test Window",
            selectedText: "Selected test text",
            visibleText: nil,
            capturedAt: Date()
        )
    }

    public func getFrontmostApp() -> (bundleId: String, name: String)? {
        if shouldThrowError == .noFrontmostApp {
            return nil
        }
        return ("com.test.app", "Test App")
    }
}
#endif
