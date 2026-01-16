//
//  MacWindowContextService.swift
//  SwiftSpeakMac
//
//  Window context capture using macOS Accessibility API
//  Phase 5: Captures text from active window for Power Mode context
//

import AppKit
import ApplicationServices
import Vision
import CoreGraphics

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

    /// Alias for displayText - combined text content for AI context
    public var contextText: String {
        displayText
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

    // MARK: - Permission Diagnostics

    /// Check accessibility permission with detailed diagnostics
    public func checkAccessibilityWithDiagnostics() -> (granted: Bool, details: String) {
        let trusted = AXIsProcessTrusted()

        var details = "AXIsProcessTrusted(): \(trusted)\n"

        // Try to access system-wide element as additional check
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )

        details += "System-wide kAXFocusedApplicationAttribute: \(error == .success ? "OK" : "error \(error.rawValue)")\n"

        // Decode error codes
        switch error {
        case .success:
            details += "✅ Accessibility working!\n"
        case .apiDisabled:
            details += "❌ API DISABLED (error -25211) - Need to enable in System Settings\n"
        case .notImplemented:
            details += "⚠️ Not implemented (error -25208)\n"
        case .cannotComplete:
            details += "⚠️ Cannot complete (error -25204) - may need restart\n"
        case .invalidUIElement:
            details += "⚠️ Invalid UI element (error -25205)\n"
        case .attributeUnsupported:
            details += "⚠️ Attribute unsupported (error -25206)\n"
        case .noValue:
            details += "⚠️ No value (error -25212) - no focused app?\n"
        default:
            details += "⚠️ Unknown error: \(error.rawValue)\n"
        }

        // If AXIsProcessTrusted is true, that's the main permission check
        // The other check can fail for various reasons unrelated to permission
        let isGranted = trusted

        if trusted {
            details += "\n✅ Permission GRANTED (AXIsProcessTrusted=true)"
        } else {
            details += "\n❌ Permission DENIED - Add app to System Settings → Privacy → Accessibility"
        }

        return (isGranted, details)
    }

    // MARK: - Active Conversation Extraction

    /// Capture only the active conversation content (filters out sidebar/navigation)
    /// Uses window-relative positioning to find conversation area
    public func captureActiveConversation(from pid: pid_t, contactName: String? = nil) async -> String? {
        guard AXIsProcessTrusted() else {
            print("[AX CONV] ❌ Accessibility not granted")
            return nil
        }

        print("[AX CONV] Capturing active conversation from PID \(pid), contact filter: \(contactName ?? "none")")

        // Get focused app element
        let systemWide = AXUIElementCreateSystemWide()
        var focusedAppRef: CFTypeRef?
        let focusedAppError = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedAppRef
        )

        let axApp = focusedAppError == .success && focusedAppRef != nil
            ? (focusedAppRef as! AXUIElement)
            : AXUIElementCreateApplication(pid)

        // Get the main/focused window
        var windowRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef) != .success {
            if AXUIElementCopyAttributeValue(axApp, kAXMainWindowAttribute as CFString, &windowRef) != .success {
                print("[AX CONV] Could not get window")
                return nil
            }
        }

        guard let window = windowRef else { return nil }

        // Get window position to calculate relative thresholds
        var windowPosRef: CFTypeRef?
        var windowX: CGFloat = 0
        if AXUIElementCopyAttributeValue(window as! AXUIElement, kAXPositionAttribute as CFString, &windowPosRef) == .success,
           CFGetTypeID(windowPosRef!) == AXValueGetTypeID() {
            var point = CGPoint.zero
            AXValueGetValue(windowPosRef as! AXValue, .cgPoint, &point)
            windowX = point.x
        }

        // Conversation area starts ~440px from window left edge (sidebar is ~400px)
        let conversationThreshold = windowX + 440
        print("[AX CONV] Window x=\(Int(windowX)), conversation threshold x>\(Int(conversationThreshold))")

        // Collect messages from conversation area using AXDescription
        var conversationTexts: [String] = []
        var visited = Set<String>()

        collectConversationMessages(
            from: window as! AXUIElement,
            into: &conversationTexts,
            visited: &visited,
            depth: 0,
            maxDepth: 20,
            conversationThreshold: conversationThreshold,
            contactFilter: contactName
        )

        if conversationTexts.isEmpty {
            print("[AX CONV] No conversation messages found")
            return nil
        }

        let combined = conversationTexts.joined(separator: "\n")
        print("[AX CONV] ✅ Found \(conversationTexts.count) conversation messages, \(combined.count) chars")

        return String(combined.prefix(maxVisibleTextLength))
    }

    /// Collect messages from conversation area using AXDescription attribute
    private func collectConversationMessages(
        from element: AXUIElement,
        into texts: inout [String],
        visited: inout Set<String>,
        depth: Int,
        maxDepth: Int,
        conversationThreshold: CGFloat,
        contactFilter: String?
    ) {
        guard depth < maxDepth else { return }

        // Get role
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = (roleRef as? String) ?? "unknown"

        // Avoid infinite loops
        var idRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &idRef)
        let identifier = (idRef as? String) ?? "\(depth)-\(role)-\(visited.count)"
        if visited.contains(identifier) { return }
        visited.insert(identifier)

        // Get position
        var posRef: CFTypeRef?
        var elementX: CGFloat = 0
        if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success,
           CFGetTypeID(posRef!) == AXValueGetTypeID() {
            var point = CGPoint.zero
            AXValueGetValue(posRef as! AXValue, .cgPoint, &point)
            elementX = point.x
        }

        // Only process elements in conversation area
        let isInConversationArea = elementX >= conversationThreshold

        if isInConversationArea {
            // WhatsApp messages are in AXDescription, especially for AXGenericElement
            var descRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef) == .success,
               let desc = descRef as? String, !desc.isEmpty {

                // Filter out UI labels and noise
                let isUILabel = desc.contains("Compose message") ||
                    desc.contains("Voice message") ||
                    desc.contains("Share media") ||
                    desc.contains("older messages") ||
                    desc.hasPrefix("0") && desc.contains("-") ||  // Button UUIDs like "0FAB8AA6-8FAD..."
                    (desc.count < 10 && !desc.contains("message"))

                // Filter by contact if specified
                let matchesContact = contactFilter == nil ||
                    desc.localizedCaseInsensitiveContains(contactFilter!)

                if !isUILabel && matchesContact && !texts.contains(desc) {
                    texts.append(desc)
                    print("[AX CONV] ✓ Message: \(desc.prefix(60))...")
                }
            }
        }

        // Recurse into children
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                collectConversationMessages(
                    from: child,
                    into: &texts,
                    visited: &visited,
                    depth: depth + 1,
                    maxDepth: maxDepth,
                    conversationThreshold: conversationThreshold,
                    contactFilter: contactFilter
                )
            }
        }
    }

    /// Find parent scroll area from a given element
    private func findParentScrollArea(from element: AXUIElement) -> AXUIElement? {
        var current: AXUIElement? = element
        var depth = 0
        var parentRoles: [String] = []

        while let el = current, depth < 15 {
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &roleRef)
            let role = (roleRef as? String) ?? "unknown"
            parentRoles.append(role)

            // Look for container types that might hold messages
            if role == "AXScrollArea" || role == "AXList" || role == "AXTable" ||
               role == "AXWebArea" || (role == "AXGroup" && depth > 3) {
                print("[AX CONV] Found parent \(role) at depth \(depth)")
                print("[AX CONV] Parent chain: \(parentRoles.joined(separator: " → "))")
                return el
            }

            // Go to parent
            var parentRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(el, kAXParentAttribute as CFString, &parentRef) == .success,
               let parent = parentRef {
                current = (parent as! AXUIElement)
            } else {
                break
            }
            depth += 1
        }

        print("[AX CONV] No scroll area found. Parent chain: \(parentRoles.joined(separator: " → "))")
        return nil
    }

    /// Collect only message-like text (longer strings, avoiding UI labels)
    private func collectMessagesOnly(from element: AXUIElement, into texts: inout [String], visited: inout Set<String>, depth: Int, maxDepth: Int) {
        guard depth < maxDepth else { return }

        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = (roleRef as? String) ?? "unknown"

        // Skip UI chrome
        if ["AXButton", "AXMenuItem", "AXToolbar", "AXMenuBar", "AXImage"].contains(role) {
            return
        }

        // Get identifier for dedup
        var idRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &idRef)
        let identifier = (idRef as? String) ?? "\(depth)-\(role)-\(texts.count)"
        if visited.contains(identifier) { return }
        visited.insert(identifier)

        // Get text
        var valueRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
           let value = valueRef as? String, value.count > 10 {
            // Skip short UI labels
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 10 && !texts.contains(trimmed) {
                texts.append(trimmed)
            }
        }

        // Also check description for message metadata
        if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &valueRef) == .success,
           let desc = valueRef as? String, desc.count > 20, !texts.contains(desc) {
            texts.append(desc)
        }

        // Recurse
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                collectMessagesOnly(from: child, into: &texts, visited: &visited, depth: depth + 1, maxDepth: maxDepth)
            }
        }
    }

    /// Find conversation content by looking for scroll areas and message-like elements
    private func findConversationContent(
        from element: AXUIElement,
        into texts: inout [String],
        visited: inout Set<String>,
        depth: Int,
        maxDepth: Int,
        contactFilter: String?
    ) {
        guard depth < maxDepth else { return }

        // Get role
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = (roleRef as? String) ?? "unknown"

        // Avoid infinite loops
        var hashValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &hashValue)
        let identifier = (hashValue as? String) ?? "\(depth)-\(role)-\(texts.count)"
        if visited.contains(identifier) { return }
        visited.insert(identifier)

        // Get position to filter sidebar (left side) vs main content (right side)
        var elementX: CGFloat = 0
        var positionRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
           CFGetTypeID(positionRef!) == AXValueGetTypeID() {
            var point = CGPoint.zero
            AXValueGetValue(positionRef as! AXValue, .cgPoint, &point)
            elementX = point.x
        }

        // Debug position
        if depth <= 3 && elementX > 0 {
            print("[AX CONV] depth=\(depth) role=\(role) x=\(Int(elementX))")
        }

        // WhatsApp sidebar is typically < 350px, conversation area starts around 350-400px
        // Skip sidebar elements (navigation: Chats, Calls, Updates, chat list)
        let isSidebar = elementX > 0 && elementX < 350 && depth > 1

        // Skip UI chrome (very short labels that are likely buttons/tabs)
        let isUIChrome = ["AXButton", "AXTab", "AXToolbar", "AXMenuBar"].contains(role)

        // Look for actual message content in the main area
        if !isSidebar && !isUIChrome {
            var valueRef: CFTypeRef?

            // Get text value
            if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
               let value = valueRef as? String, !value.isEmpty {
                // Filter by contact if specified
                if let contact = contactFilter {
                    // Only include if it's FROM or TO the contact (in active conversation)
                    // Exclude chat list previews which say "Sent to X" in a different format
                    let isDirectMessage = value.localizedCaseInsensitiveContains("from \(contact)") ||
                                          value.localizedCaseInsensitiveContains("to \(contact)") ||
                                          (value.count > 50 && value.localizedCaseInsensitiveContains(contact))
                    if isDirectMessage {
                        texts.append(value)
                        print("[AX CONV] ✓ Matched contact '\(contact)': \(value.prefix(60))...")
                    }
                } else {
                    texts.append(value)
                }
            }

            // Get description (often contains message metadata)
            if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &valueRef) == .success,
               let desc = valueRef as? String, !desc.isEmpty, desc.count > 30 {
                if let contact = contactFilter {
                    let isDirectMessage = desc.localizedCaseInsensitiveContains("from \(contact)") ||
                                          desc.localizedCaseInsensitiveContains("to \(contact)")
                    if isDirectMessage && !texts.contains(desc) {
                        texts.append(desc)
                        print("[AX CONV] ✓ Matched desc '\(contact)': \(desc.prefix(60))...")
                    }
                } else if !texts.contains(desc) {
                    texts.append(desc)
                }
            }
        }

        // Recurse into children
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                findConversationContent(
                    from: child,
                    into: &texts,
                    visited: &visited,
                    depth: depth + 1,
                    maxDepth: maxDepth,
                    contactFilter: contactFilter
                )
            }
        }
    }

    // MARK: - Debug: Dump Accessibility Tree

    /// Debug function to dump the full accessibility tree structure
    public func dumpAccessibilityTree(from pid: pid_t, maxDepth: Int = 8) async {
        guard AXIsProcessTrusted() else {
            print("[AX DUMP] ❌ Accessibility not granted")
            return
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedAppRef: CFTypeRef?
        let focusedAppError = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedAppRef
        )

        let axApp = focusedAppError == .success && focusedAppRef != nil
            ? (focusedAppRef as! AXUIElement)
            : AXUIElementCreateApplication(pid)

        var windowRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef) != .success {
            AXUIElementCopyAttributeValue(axApp, kAXMainWindowAttribute as CFString, &windowRef)
        }

        guard let window = windowRef else {
            print("[AX DUMP] Could not get window")
            return
        }

        print("\n[AX DUMP] ════════════ ACCESSIBILITY TREE DUMP ════════════")
        var visited = Set<String>()
        dumpElement(window as! AXUIElement, depth: 0, maxDepth: maxDepth, visited: &visited)
        print("[AX DUMP] ════════════ END DUMP ════════════\n")
    }

    private func dumpElement(_ element: AXUIElement, depth: Int, maxDepth: Int, visited: inout Set<String>) {
        guard depth < maxDepth else { return }

        let indent = String(repeating: "  ", count: depth)

        // Get role
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = (roleRef as? String) ?? "?"

        // Get identifier for dedup
        var idRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &idRef)
        let identifier = (idRef as? String) ?? "\(depth)-\(role)-\(visited.count)"
        if visited.contains(identifier) { return }
        visited.insert(identifier)

        // Get title/value/description
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
        let title = (titleRef as? String)?.prefix(50) ?? ""

        var valueRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef)
        let value = (valueRef as? String)?.prefix(50) ?? ""

        var descRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
        let desc = (descRef as? String)?.prefix(50) ?? ""

        // Get position
        var posRef: CFTypeRef?
        var posX: CGFloat = 0
        if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success,
           CFGetTypeID(posRef!) == AXValueGetTypeID() {
            var point = CGPoint.zero
            AXValueGetValue(posRef as! AXValue, .cgPoint, &point)
            posX = point.x
        }

        // Get child count
        var childrenRef: CFTypeRef?
        var childCount = 0
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            childCount = children.count
        }

        // Print this element - show more detail for conversation area (x > 2900)
        var info = "\(indent)[\(role)] x=\(Int(posX))"
        if !title.isEmpty { info += " T=\"\(title)\"" }
        if !value.isEmpty { info += " V=\"\(value)\"" }
        if !desc.isEmpty { info += " D=\"\(desc)\"" }
        if childCount > 0 { info += " (\(childCount)ch)" }
        print(info)

        // For conversation area elements (x > 2900), go deeper
        let effectiveMaxDepth = posX > 2900 ? maxDepth + 4 : maxDepth

        // Recurse into children
        if let children = childrenRef as? [AXUIElement] {
            for child in children {
                dumpElement(child, depth: depth + 1, maxDepth: effectiveMaxDepth, visited: &visited)
            }
        }
    }

    /// Apps where OCR is preferred because Accessibility often captures sidebar/UI instead of main content
    private let ocrPreferredBundleIds: Set<String> = [
        "net.whatsapp.WhatsApp",           // WhatsApp - sidebar chat list captured instead of conversation
        "com.apple.MobileSMS",             // iMessage
        "com.tdesktop.Telegram",           // Telegram
        "org.nickvision.cavalier",         // Cavalier
        "com.facebook.Messenger",          // Messenger
        "com.slack.Slack",                 // Slack - Electron captures limited content
        "com.hnc.Discord",                 // Discord
        "com.microsoft.teams2",            // Teams
    ]

    /// Capture all visible text with OCR fallback
    /// First tries Accessibility API, falls back to OCR if insufficient content
    /// - Parameters:
    ///   - pid: Process ID of the target app
    ///   - bundleId: Optional bundle ID to detect messaging apps that need OCR
    public func captureAllVisibleTextWithOCRFallback(from pid: pid_t, bundleId: String? = nil) async -> String? {
        // For messaging apps, prefer OCR because accessibility often captures sidebar
        let preferOCR = bundleId.map { ocrPreferredBundleIds.contains($0) } ?? false

        if preferOCR {
            print("[OCR FALLBACK] Messaging app detected (\(bundleId ?? "unknown")) - trying OCR first")
            if let ocrText = await captureWindowTextViaOCR(pid: pid), !ocrText.isEmpty {
                print("[OCR FALLBACK] OCR captured \(ocrText.count) chars for messaging app:")
                print("[OCR CONTENT] \(ocrText)")
                return ocrText
            }
            print("[OCR FALLBACK] OCR failed for messaging app, falling back to Accessibility")
        }

        // First try accessibility
        let axText = await captureAllVisibleText(from: pid)
        let axLength = axText?.count ?? 0

        print("[OCR FALLBACK] Accessibility captured \(axLength) chars")

        // Check if we got enough content and it's not just UI elements
        let hasEnoughContent = axLength >= minAccessibilityChars
        let seemsLikeUIOnly = isLikelyUIElementsOnly(axText ?? "")

        if hasEnoughContent && !seemsLikeUIOnly {
            print("[OCR FALLBACK] Using Accessibility result")
            return axText
        }

        // Fall back to OCR (for non-messaging apps that didn't get enough from accessibility)
        if !preferOCR {
            print("[OCR FALLBACK] Falling back to OCR (axLength=\(axLength), enough=\(hasEnoughContent), uiOnly=\(seemsLikeUIOnly))")
            if let ocrText = await captureWindowTextViaOCR(pid: pid), !ocrText.isEmpty {
                print("[OCR FALLBACK] OCR captured \(ocrText.count) chars:")
                print("[OCR CONTENT] \(ocrText)")
                return ocrText
            }
        }

        // If OCR failed, return accessibility result (may be nil)
        print("[OCR FALLBACK] OCR failed, returning Accessibility result")
        return axText
    }

    // MARK: - Deep Text Extraction (Full Window)

    /// Recursively traverse accessibility tree to extract ALL visible text from a window
    /// This is useful for apps like WhatsApp/Slack that don't expose text via focused element
    public func captureAllVisibleText(from pid: pid_t) async -> String? {
        // Check permission - use AXIsProcessTrusted() as the authoritative check
        let trusted = AXIsProcessTrusted()
        print("[AX DEEP] AXIsProcessTrusted: \(trusted)")

        guard trusted else {
            print("[AX DEEP] ❌ Accessibility not granted - add app to System Settings → Privacy → Accessibility")
            return nil
        }

        print("[AX DEEP] ✅ Permission OK, attempting to read from PID \(pid)")

        // Create element directly from PID (don't use system-wide focused app
        // because by the time this runs, our overlay might be frontmost)
        let axApp = AXUIElementCreateApplication(pid)
        print("[AX DEEP] Created AXUIElement from PID \(pid)")

        // Check if the app element is valid by getting its role
        var roleRef: CFTypeRef?
        let roleError = AXUIElementCopyAttributeValue(axApp, kAXRoleAttribute as CFString, &roleRef)
        print("[AX DEEP] App AXRole check: \(roleError == .success ? (roleRef as? String ?? "unknown") : "error \(roleError.rawValue)")")

        // Always use PID-based element - don't use system-wide focused app
        // because by the time this runs, our overlay might be frontmost
        let appElement = axApp
        print("[AX DEEP] Using PID-based app element for \(pid)")

        // First try: Get focused window
        var windowRef: CFTypeRef?
        var windowError = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &windowRef
        )

        // Second try: If no focused window, get first window from windows list
        if windowError != .success || windowRef == nil {
            print("[AX DEEP] No focused window (error: \(windowError.rawValue)), trying windows list...")

            var windowsRef: CFTypeRef?
            let windowsError = AXUIElementCopyAttributeValue(
                appElement,
                kAXWindowsAttribute as CFString,
                &windowsRef
            )

            if windowsError == .success, let windows = windowsRef as? [AXUIElement], !windows.isEmpty {
                windowRef = windows[0]
                windowError = .success
                print("[AX DEEP] Got first window from list (total: \(windows.count) windows)")
            } else {
                print("[AX DEEP] Windows list also failed (error: \(windowsError.rawValue))")
            }

            // Debug: List ALL available attributes on the app element
            var attrNames: CFArray?
            if AXUIElementCopyAttributeNames(appElement, &attrNames) == .success,
               let names = attrNames as? [String] {
                print("[AX DEEP] Available APP attributes: \(names.joined(separator: ", "))")

                // Try each window-related attribute
                for attr in ["AXWindows", "AXMainWindow", "AXFocusedWindow", "AXChildren"] {
                    var ref: CFTypeRef?
                    let err = AXUIElementCopyAttributeValue(appElement, attr as CFString, &ref)
                    if err == .success {
                        if let arr = ref as? [AXUIElement] {
                            print("[AX DEEP] \(attr): \(arr.count) elements")
                        } else {
                            print("[AX DEEP] \(attr): got value (type: \(type(of: ref)))")
                        }
                    } else {
                        print("[AX DEEP] \(attr): error \(err.rawValue)")
                    }
                }
            } else {
                print("[AX DEEP] ❌ Could not get attribute names from app element!")
            }

            // Try AXMainWindow as another fallback
            var mainWindowRef: CFTypeRef?
            let mainWindowError = AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &mainWindowRef)
            if mainWindowError == .success, mainWindowRef != nil {
                windowRef = mainWindowRef
                windowError = .success
                print("[AX DEEP] Got main window!")
            }
        }

        guard windowError == .success, let window = windowRef else {
            print("[AX DEEP] Could not get any window from WhatsApp")
            print("[AX DEEP] This app may not expose accessibility - try Gmail in Chrome instead")
            return nil
        }

        // Recursively collect all text
        var allTexts: [String] = []
        var visited = Set<String>()
        collectAllText(from: window as! AXUIElement, into: &allTexts, visited: &visited, depth: 0, maxDepth: 20)

        if allTexts.isEmpty {
            print("[AX DEEP] No text elements found in tree")
            return nil
        }

        // Join with newlines, remove duplicates while preserving order
        let uniqueTexts = allTexts.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let combined = uniqueTexts.joined(separator: "\n")
        print("[AX DEEP] Found \(uniqueTexts.count) text elements, total \(combined.count) chars")

        return String(combined.prefix(maxVisibleTextLength))
    }

    /// Recursively collect text from all children of an accessibility element
    private func collectAllText(from element: AXUIElement, into texts: inout [String], visited: inout Set<String>, depth: Int, maxDepth: Int) {
        guard depth < maxDepth else { return }

        // Get role for debugging
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = (roleRef as? String) ?? "unknown"

        // Get element identifier to avoid infinite loops
        var hashValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &hashValue)
        let identifier = (hashValue as? String) ?? "\(depth)-\(role)-\(texts.count)"
        if visited.contains(identifier) { return }
        visited.insert(identifier)

        // Try to get text value from this element
        var valueRef: CFTypeRef?

        // Check AXValue (text fields, text areas)
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
           let value = valueRef as? String, !value.isEmpty {
            texts.append(value)
            if depth < 3 { print("[AX DEEP] depth=\(depth) role=\(role) value=\(value.prefix(50))") }
        }

        // Check AXTitle (buttons, labels)
        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &valueRef) == .success,
           let title = valueRef as? String, !title.isEmpty {
            // Avoid duplicating if already in value
            if !texts.contains(title) {
                texts.append(title)
                if depth < 3 { print("[AX DEEP] depth=\(depth) role=\(role) title=\(title.prefix(50))") }
            }
        }

        // Check AXDescription (for accessibility descriptions)
        if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &valueRef) == .success,
           let desc = valueRef as? String, !desc.isEmpty {
            if !texts.contains(desc) {
                texts.append(desc)
            }
        }

        // For static text elements, the value IS the text content
        if role == "AXStaticText" {
            // Already captured via AXValue above
        }

        // Recurse into children
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                collectAllText(from: child, into: &texts, visited: &visited, depth: depth + 1, maxDepth: maxDepth)
            }
        }
    }

    // MARK: - OCR Fallback

    /// Minimum characters to consider Accessibility capture successful
    /// If less than this, we fall back to OCR
    private let minAccessibilityChars = 400

    /// Capture window context with OCR fallback
    /// First tries Accessibility API, falls back to OCR if insufficient content captured
    public func captureWindowContextWithOCRFallback(from pid: pid_t, bundleId: String, appName: String) async throws -> WindowContext {
        print("[OCR FALLBACK] Starting capture from PID \(pid) (\(appName))")

        // First try Accessibility API
        let axContext = try? await captureWindowContext(from: pid, bundleId: bundleId, appName: appName)

        // Check if we got enough content
        let axTextLength = axContext?.contextText.count ?? 0
        let hasEnoughContent = axTextLength >= minAccessibilityChars

        // Also check if it's mostly UI elements (short lines, navigation text)
        let seemsLikeUIOnly = isLikelyUIElementsOnly(axContext?.contextText ?? "")

        print("[OCR FALLBACK] Accessibility captured \(axTextLength) chars, enough=\(hasEnoughContent), uiOnly=\(seemsLikeUIOnly)")

        if hasEnoughContent && !seemsLikeUIOnly {
            print("[OCR FALLBACK] Using Accessibility result")
            return axContext!
        }

        // Fall back to OCR
        print("[OCR FALLBACK] Falling back to OCR...")
        if let ocrText = await captureWindowTextViaOCR(pid: pid) {
            print("[OCR FALLBACK] OCR captured \(ocrText.count) chars")

            // Use OCR text, keep other metadata from accessibility if available
            return WindowContext(
                appName: axContext?.appName ?? appName,
                appBundleId: axContext?.appBundleId ?? bundleId,
                windowTitle: axContext?.windowTitle ?? "",
                selectedText: axContext?.selectedText,
                visibleText: ocrText,
                capturedAt: Date()
            )
        }

        // If OCR also failed, return whatever accessibility got (or throw)
        if let axContext = axContext {
            print("[OCR FALLBACK] OCR failed, using Accessibility result anyway")
            return axContext
        }

        throw WindowContextError.noTextFound
    }

    /// Check if captured text is likely just UI elements (navigation, buttons, etc.)
    private func isLikelyUIElementsOnly(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else { return true }

        // UI patterns: very short lines, navigation keywords
        let uiKeywords = ["Navigation", "Back", "Forward", "History", "Search", "Settings",
                         "Home", "Menu", "Close", "Minimize", "Messages", "Files", "Channels"]

        var uiLineCount = 0
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Short lines are likely buttons/labels
            if trimmed.count < 20 {
                uiLineCount += 1
                continue
            }
            // Check for UI keywords
            if uiKeywords.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) {
                uiLineCount += 1
            }
        }

        // If more than 70% of lines seem like UI, it's probably just UI
        let uiRatio = Double(uiLineCount) / Double(lines.count)
        print("[OCR FALLBACK] UI ratio: \(uiRatio) (\(uiLineCount)/\(lines.count) lines)")
        return uiRatio > 0.7
    }

    /// Capture window screenshot and perform OCR
    private func captureWindowTextViaOCR(pid: pid_t) async -> String? {
        // Get the window image
        guard let windowImage = captureWindowScreenshot(pid: pid) else {
            print("[OCR] Failed to capture screenshot")
            return nil
        }

        print("[OCR] Captured screenshot: \(windowImage.width)x\(windowImage.height)")

        // Perform OCR
        return await performOCR(on: windowImage)
    }

    /// Capture screenshot of window belonging to PID
    private func captureWindowScreenshot(pid: pid_t) -> CGImage? {
        // Get window list for this PID
        let windowListInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

        // Find windows belonging to this PID
        var targetWindowID: CGWindowID?
        var targetBounds: CGRect?

        for windowInfo in windowListInfo {
            guard let windowPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  windowPID == pid,
                  let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let layer = windowInfo[kCGWindowLayer as String] as? Int,
                  layer == 0 else { // Layer 0 = normal windows
                continue
            }

            let bounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )

            // Skip tiny windows (tooltips, etc.)
            if bounds.width < 200 || bounds.height < 200 {
                continue
            }

            // Prefer larger windows (main window)
            if targetBounds == nil || (bounds.width * bounds.height > targetBounds!.width * targetBounds!.height) {
                targetWindowID = windowID
                targetBounds = bounds
            }
        }

        guard let windowID = targetWindowID else {
            print("[OCR] No suitable window found for PID \(pid)")
            return nil
        }

        print("[OCR] Capturing window \(windowID) at \(targetBounds!)")

        // Capture the window
        let image = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .nominalResolution]
        )

        return image
    }

    /// Perform OCR on image using Vision framework
    private func performOCR(on image: CGImage) async -> String? {
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("[OCR] Vision error: \(error)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    print("[OCR] No text observations")
                    continuation.resume(returning: nil)
                    return
                }

                // Sort observations by position (top to bottom, left to right)
                let sortedObservations = observations.sorted { obs1, obs2 in
                    // Vision coordinates are bottom-left origin, so invert Y
                    let y1 = 1 - obs1.boundingBox.midY
                    let y2 = 1 - obs2.boundingBox.midY
                    if abs(y1 - y2) > 0.02 { // Different rows
                        return y1 < y2
                    }
                    return obs1.boundingBox.midX < obs2.boundingBox.midX
                }

                // Extract text
                var lines: [String] = []
                var currentY: CGFloat = -1
                var currentLine: [String] = []

                for observation in sortedObservations {
                    guard let candidate = observation.topCandidates(1).first else { continue }

                    let y = 1 - observation.boundingBox.midY

                    // Check if we're on a new line
                    if currentY < 0 || abs(y - currentY) > 0.015 {
                        if !currentLine.isEmpty {
                            lines.append(currentLine.joined(separator: " "))
                        }
                        currentLine = [candidate.string]
                        currentY = y
                    } else {
                        currentLine.append(candidate.string)
                    }
                }

                // Add last line
                if !currentLine.isEmpty {
                    lines.append(currentLine.joined(separator: " "))
                }

                let result = lines.joined(separator: "\n")
                print("[OCR] Extracted \(result.count) chars, \(lines.count) lines")
                continuation.resume(returning: result)
            }

            // Configure request for best accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            // Use supported Vision language codes (not locales)
            // See: VNRecognizeTextRequest.supportedRecognitionLanguages(for:revision:)
            request.recognitionLanguages = ["en-US", "de-DE", "fr-FR", "es-ES", "it-IT", "pt-BR"]
            // Note: Polish (pl) is not supported by Vision OCR, but it can still recognize Latin text

            // Perform request
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("[OCR] Handler error: \(error)")
                continuation.resume(returning: nil)
            }
        }
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
