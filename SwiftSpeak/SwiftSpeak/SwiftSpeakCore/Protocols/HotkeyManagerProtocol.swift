import Foundation
import Combine

public enum HotkeyAction: String, CaseIterable, Codable, Sendable {
    case startRecording
    case stopRecording
    case toggleRecording
    case openSettings
    case showOverlay
    case cancelRecording
}

public struct HotkeyCombination: Codable, Equatable, Sendable {
    public let keyCode: UInt16
    public let modifiers: UInt
    public let displayString: String

    public init(keyCode: UInt16, modifiers: UInt, displayString: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayString = displayString
    }
}

@MainActor
public protocol HotkeyManagerProtocol: ObservableObject {
    var registeredHotkeys: [HotkeyAction: HotkeyCombination] { get }
    func registerHotkey(_ combo: HotkeyCombination, for action: HotkeyAction) throws
    func unregisterHotkey(for action: HotkeyAction)
    func setHandler(_ handler: @escaping (HotkeyAction) -> Void)
}

// Note: HotkeyError is defined in MacHotkeyManager.swift to avoid duplication
