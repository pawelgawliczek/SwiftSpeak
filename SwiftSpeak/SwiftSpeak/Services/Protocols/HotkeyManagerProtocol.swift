//
//  HotkeyManagerProtocol.swift
//  SwiftSpeakCore
//
//  Protocol for global hotkey management (macOS only)
//

import Foundation
import Combine

/// Actions that can be triggered by global hotkeys
enum HotkeyAction: String, CaseIterable, Codable, Sendable {
    case startRecording
    case stopRecording
    case toggleRecording
    case openSettings
    case showOverlay
    case cancelRecording
    case pushToTalk
}

/// Hotkey key combination
struct HotkeyCombination: Codable, Equatable, Sendable, Hashable {
    public let keyCode: UInt16
    public let modifiers: UInt
    public let displayString: String

    public init(keyCode: UInt16, modifiers: UInt, displayString: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayString = displayString
    }
}

/// Protocol for managing global hotkeys
@MainActor
protocol HotkeyManagerProtocol: ObservableObject {
    /// Currently registered hotkeys
    var registeredHotkeys: [HotkeyAction: HotkeyCombination] { get }

    /// Register a hotkey for an action
    func registerHotkey(_ combo: HotkeyCombination, for action: HotkeyAction) throws

    /// Unregister a hotkey for an action
    func unregisterHotkey(for action: HotkeyAction)

    /// Set the handler for hotkey events
    func setHandler(_ handler: @escaping (HotkeyAction) -> Void)
}

/// Hotkey registration errors
enum HotkeyError: Error, LocalizedError {
    case alreadyRegistered(HotkeyAction)
    case systemConflict(String)
    case registrationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .alreadyRegistered(let action):
            return "Hotkey already registered for \(action.rawValue)"
        case .systemConflict(let message):
            return "System hotkey conflict: \(message)"
        case .registrationFailed(let message):
            return "Failed to register hotkey: \(message)"
        }
    }
}
