// SwiftSpeakMac/Platform/MacTextInsertionService.swift

import AppKit
import ApplicationServices

// MARK: - Errors

enum TextInsertionError: LocalizedError {
    case noFocusedElement
    case elementNotEditable
    case insertionFailed

    var errorDescription: String? {
        switch self {
        case .noFocusedElement:
            return "No text field is currently focused."
        case .elementNotEditable:
            return "The focused element does not accept text input."
        case .insertionFailed:
            return "Failed to insert text into the focused element."
        }
    }
}

// MARK: - MacTextInsertionService

@MainActor
final class MacTextInsertionService: TextInsertionProtocol {

    // MARK: - Properties

    var isAccessibilityAvailable: Bool {
        AXIsProcessTrusted()
    }

    // MARK: - Public Methods

    func insertText(_ text: String, replaceSelection: Bool) async -> TextInsertionResult {
        // Try accessibility first
        if isAccessibilityAvailable {
            do {
                try insertViaAccessibility(text, replaceSelection: replaceSelection)
                return .accessibilitySuccess
            } catch {
                // Fall through to clipboard
            }
        }

        // Fallback to clipboard
        return copyToClipboard(text)
    }

    func getSelectedText() async -> String? {
        guard isAccessibilityAvailable else { return nil }
        guard let element = getFocusedElement() else { return nil }

        var selectedText: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )

        guard result == .success, let text = selectedText as? String else {
            return nil
        }

        return text.isEmpty ? nil : text
    }

    func replaceAllText(with text: String) async -> TextInsertionResult {
        if isAccessibilityAvailable {
            do {
                try replaceAllViaAccessibility(text)
                return .accessibilitySuccess
            } catch {
                // Fall through
            }
        }
        return copyToClipboard(text)
    }

    /// Request accessibility permission (opens System Preferences)
    func requestAccessibilityPermission() {
        // Prompt the system to show accessibility dialog
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Open System Preferences to Accessibility pane
    func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Private Methods

    private func getFocusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()

        // Get focused application
        var focusedApp: AnyObject?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        ) == .success else {
            return nil
        }

        // Get focused UI element within that app
        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(
            focusedApp as! AXUIElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        ) == .success else {
            return nil
        }

        // AXUIElement is a CFTypeRef, cast from AnyObject
        guard let element = focusedElement else { return nil }
        return (element as! AXUIElement)
    }

    private func insertViaAccessibility(_ text: String, replaceSelection: Bool) throws {
        guard let element = getFocusedElement() else {
            throw TextInsertionError.noFocusedElement
        }

        // Check if element is editable
        var role: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)

        let editableRoles = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]
        guard let roleString = role as? String, editableRoles.contains(roleString) else {
            throw TextInsertionError.elementNotEditable
        }

        // Check if element is enabled
        var enabled: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &enabled)
        if let isEnabled = enabled as? Bool, !isEnabled {
            throw TextInsertionError.elementNotEditable
        }

        if replaceSelection {
            // Replace selected text only
            let result = AXUIElementSetAttributeValue(
                element,
                kAXSelectedTextAttribute as CFString,
                text as CFString
            )
            guard result == .success else {
                throw TextInsertionError.insertionFailed
            }
        } else {
            // Get current value and cursor position for proper insertion
            var currentValue: AnyObject?
            AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &currentValue)

            var selectedRange: AnyObject?
            AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRange)

            if let range = selectedRange, let currentText = currentValue as? String {
                // Insert at cursor position
                var cfRange = CFRange()
                AXValueGetValue(range as! AXValue, .cfRange, &cfRange)

                let location = cfRange.location
                let prefix = String(currentText.prefix(location))
                let suffix = String(currentText.dropFirst(location + cfRange.length))
                let newValue = prefix + text + suffix

                let result = AXUIElementSetAttributeValue(
                    element,
                    kAXValueAttribute as CFString,
                    newValue as CFString
                )
                guard result == .success else {
                    throw TextInsertionError.insertionFailed
                }
            } else {
                // Fallback: append to end
                let result = AXUIElementSetAttributeValue(
                    element,
                    kAXValueAttribute as CFString,
                    text as CFString
                )
                guard result == .success else {
                    throw TextInsertionError.insertionFailed
                }
            }
        }
    }

    private func replaceAllViaAccessibility(_ text: String) throws {
        guard let element = getFocusedElement() else {
            throw TextInsertionError.noFocusedElement
        }

        let result = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            text as CFString
        )

        guard result == .success else {
            throw TextInsertionError.insertionFailed
        }
    }

    private func copyToClipboard(_ text: String) -> TextInsertionResult {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        return .clipboardFallback
    }
}
