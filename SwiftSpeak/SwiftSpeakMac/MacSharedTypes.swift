//
//  MacSharedTypes.swift
//  SwiftSpeakMac
//
//  macOS-specific type definitions
//  Imports shared types from SwiftSpeakCore
//

import Foundation
import SwiftUI
import SwiftSpeakCore

// Re-export SwiftSpeakCore types for convenience
// (These are imported from SwiftSpeakCore, not redefined)

// MARK: - macOS-Specific Types

// MARK: - Hotkey Types

enum HotkeyAction: CaseIterable, Hashable {
    case toggleRecording
    case cancelRecording
    case quickPaste
    case openPowerModeOverlay     // Open power mode selector overlay
    case powerMode(UUID)          // Trigger specific Power Mode by ID
    case context(UUID)            // Trigger transcribe overlay with specific Context pre-selected
    case transcribeToggle         // Toggle transcribe overlay (opens/closes)
    case transcribePushToTalk     // Push-to-talk transcribe (held down)
    case testContextCapture       // SPIKE: Test accessibility context capture

    // For CaseIterable conformance
    static var allCases: [HotkeyAction] {
        [.toggleRecording, .cancelRecording, .quickPaste, .openPowerModeOverlay, .transcribeToggle, .transcribePushToTalk, .testContextCapture]
    }

    // Custom hashable to support associated value
    func hash(into hasher: inout Hasher) {
        switch self {
        case .toggleRecording:
            hasher.combine("toggleRecording")
        case .cancelRecording:
            hasher.combine("cancelRecording")
        case .quickPaste:
            hasher.combine("quickPaste")
        case .openPowerModeOverlay:
            hasher.combine("openPowerModeOverlay")
        case .powerMode(let id):
            hasher.combine("powerMode")
            hasher.combine(id)
        case .context(let id):
            hasher.combine("context")
            hasher.combine(id)
        case .transcribeToggle:
            hasher.combine("transcribeToggle")
        case .transcribePushToTalk:
            hasher.combine("transcribePushToTalk")
        case .testContextCapture:
            hasher.combine("testContextCapture")
        }
    }

    static func == (lhs: HotkeyAction, rhs: HotkeyAction) -> Bool {
        switch (lhs, rhs) {
        case (.toggleRecording, .toggleRecording): return true
        case (.cancelRecording, .cancelRecording): return true
        case (.quickPaste, .quickPaste): return true
        case (.openPowerModeOverlay, .openPowerModeOverlay): return true
        case (.powerMode(let lhsId), .powerMode(let rhsId)): return lhsId == rhsId
        case (.context(let lhsId), .context(let rhsId)): return lhsId == rhsId
        case (.transcribeToggle, .transcribeToggle): return true
        case (.transcribePushToTalk, .transcribePushToTalk): return true
        case (.testContextCapture, .testContextCapture): return true
        default: return false
        }
    }
}

struct HotkeyCombination: Codable, Hashable {
    let keyCode: UInt16
    let modifiers: UInt
    let displayString: String
}

/// Context captured at the moment a hotkey is pressed (before any async dispatch)
struct HotkeyContext: Sendable {
    let frontmostAppPid: pid_t
    let frontmostAppBundleId: String
    let frontmostAppName: String
    let clipboard: String?
    let selectedText: String?  // Captured via Accessibility API in callback
    let windowTitle: String?   // Captured via Accessibility API in callback

    static let empty = HotkeyContext(frontmostAppPid: 0, frontmostAppBundleId: "", frontmostAppName: "", clipboard: nil, selectedText: nil, windowTitle: nil)
}

protocol HotkeyManagerProtocol {
    var registeredHotkeys: [HotkeyAction: HotkeyCombination] { get }
    func registerHotkey(_ combination: HotkeyCombination, for action: HotkeyAction) throws
    func unregisterHotkey(for action: HotkeyAction)
    func setHandler(_ handler: @escaping (HotkeyAction, HotkeyContext) -> Void)
}

// MARK: - Text Insertion Types

enum TextInsertionResult {
    case accessibilitySuccess
    case clipboardFallback
    case failed(Error)
}

protocol TextInsertionProtocol {
    var isAccessibilityAvailable: Bool { get }
    func insertText(_ text: String, replaceSelection: Bool) async -> TextInsertionResult
    func getSelectedText() async -> String?
    func replaceAllText(with text: String) async -> TextInsertionResult
}

// MARK: - Audio Recorder Protocol (macOS)

protocol AudioRecorderProtocol: ObservableObject {
    var isRecording: Bool { get }
    var currentLevel: Float { get }
    var duration: TimeInterval { get }
    var recordingURL: URL? { get }
    var recordingFileSize: Int? { get }

    func startRecording() async throws
    func stopRecording() throws -> URL
    func cancelRecording()
    func deleteRecording()
}

// MARK: - Text Insertion Method

enum TextInsertionMethod: String, Codable, CaseIterable, Identifiable {
    case auto = "auto"
    case accessibility = "accessibility"
    case clipboard = "clipboard"
    case typeCharacters = "type"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto (Recommended)"
        case .accessibility: return "Accessibility API"
        case .clipboard: return "Clipboard Paste"
        case .typeCharacters: return "Type Characters"
        }
    }

    var icon: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .accessibility: return "accessibility"
        case .clipboard: return "doc.on.clipboard"
        case .typeCharacters: return "keyboard"
        }
    }

    var description: String {
        switch self {
        case .auto: return "Automatically choose the best method for the current app"
        case .accessibility: return "Direct text insertion via macOS accessibility (fastest, preserves clipboard)"
        case .clipboard: return "Copy to clipboard and paste (works everywhere, overwrites clipboard)"
        case .typeCharacters: return "Simulate typing characters (slowest, most compatible)"
        }
    }
}

// MARK: - Cost Formatting Extensions

extension Double {
    /// Format as cost string (e.g., "$0.0012")
    var formattedCost: String {
        if self == 0 {
            return "$0.00"
        } else if self < 0.01 {
            return String(format: "$%.4f", self)
        } else if self < 1 {
            return String(format: "$%.3f", self)
        } else {
            return String(format: "$%.2f", self)
        }
    }

    /// Compact cost format for charts (e.g., "$1.2K")
    var formattedCostCompact: String {
        if self < 0.01 {
            return "$0"
        } else if self < 1 {
            return String(format: "$%.2f", self)
        } else if self < 1000 {
            return String(format: "$%.1f", self)
        } else {
            return String(format: "$%.1fK", self / 1000)
        }
    }
}
