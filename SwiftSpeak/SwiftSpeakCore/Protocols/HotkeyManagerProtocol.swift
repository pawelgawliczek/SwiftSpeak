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
    public var registeredHotkeys: [HotkeyAction: HotkeyCombination] { get }
    public func registerHotkey(_ combo: HotkeyCombination, for action: HotkeyAction) throws
    public func unregisterHotkey(for action: HotkeyAction)
    public func setHandler(_ handler: @escaping (HotkeyAction) -> Void)
}

public enum HotkeyError: Error, LocalizedError {
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
