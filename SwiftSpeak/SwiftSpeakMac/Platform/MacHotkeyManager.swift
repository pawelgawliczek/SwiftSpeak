//
//  MacHotkeyManager.swift
//  SwiftSpeakMac
//
//  Global hotkey management using Carbon Events API
//

import Carbon
import AppKit
import SwiftSpeakCore

@MainActor
public final class MacHotkeyManager: HotkeyManagerProtocol, ObservableObject {

    @Published private(set) public var registeredHotkeys: [HotkeyAction: HotkeyCombination] = [:]

    private var eventHandler: ((HotkeyAction) -> Void)?
    private var hotkeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var hotkeyActions: [UInt32: HotkeyAction] = [:]
    private var nextHotkeyId: UInt32 = 1
    private var eventHandlerRef: EventHandlerRef?

    // MARK: - Initialization

    public init() {
        installEventHandler()
    }

    deinit {
        // Unregister all hotkeys
        for ref in hotkeyRefs.values {
            UnregisterEventHotKey(ref)
        }
        // Remove event handler
        if let handlerRef = eventHandlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    // MARK: - Public Methods

    public func registerHotkey(_ combination: HotkeyCombination, for action: HotkeyAction) throws {
        // Unregister existing hotkey for this action
        unregisterHotkey(for: action)

        let hotkeyId = nextHotkeyId
        nextHotkeyId += 1

        var hotKeyRef: EventHotKeyRef?
        var hotKeyID = EventHotKeyID(
            signature: OSType(0x5353_504B), // "SSPK"
            id: hotkeyId
        )

        let modifiers = carbonModifiers(from: combination.modifiers)

        let status = RegisterEventHotKey(
            UInt32(combination.keyCode),
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let ref = hotKeyRef else {
            throw HotkeyError.registrationFailed
        }

        hotkeyRefs[hotkeyId] = ref
        hotkeyActions[hotkeyId] = action
        registeredHotkeys[action] = combination
    }

    public func unregisterHotkey(for action: HotkeyAction) {
        guard registeredHotkeys[action] != nil else { return }

        for (id, registeredAction) in hotkeyActions where registeredAction == action {
            if let ref = hotkeyRefs[id] {
                UnregisterEventHotKey(ref)
            }
            hotkeyRefs.removeValue(forKey: id)
            hotkeyActions.removeValue(forKey: id)
        }

        registeredHotkeys.removeValue(forKey: action)
    }

    public func setHandler(_ handler: @escaping (HotkeyAction) -> Void) {
        self.eventHandler = handler
    }

    // MARK: - Default Hotkeys

    public func registerDefaultHotkeys() throws {
        // Default: Cmd+Shift+D for toggle recording
        let defaultCombination = HotkeyCombination(
            keyCode: 0x02, // 'd' key
            modifiers: UInt(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue),
            displayString: "⌘⇧D"
        )

        try registerHotkey(defaultCombination, for: .toggleRecording)
    }

    // MARK: - Private Methods

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Store self pointer for callback
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let callback: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let event = event, let userData = userData else { return OSStatus(eventNotHandledErr) }

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            guard status == noErr else { return status }

            // Dispatch to main actor
            let manager = Unmanaged<MacHotkeyManager>.fromOpaque(userData).takeUnretainedValue()

            Task { @MainActor in
                if let action = manager.hotkeyActions[hotKeyID.id] {
                    manager.eventHandler?(action)
                }
            }

            return noErr
        }

        var handlerRef: EventHandlerRef?
        InstallEventHandler(
            GetEventDispatcherTarget(),
            callback,
            1,
            &eventType,
            selfPtr,
            &handlerRef
        )

        self.eventHandlerRef = handlerRef
    }

    private func carbonModifiers(from modifiers: UInt) -> UInt32 {
        var result: UInt32 = 0

        if modifiers & NSEvent.ModifierFlags.command.rawValue != 0 {
            result |= UInt32(cmdKey)
        }
        if modifiers & NSEvent.ModifierFlags.option.rawValue != 0 {
            result |= UInt32(optionKey)
        }
        if modifiers & NSEvent.ModifierFlags.control.rawValue != 0 {
            result |= UInt32(controlKey)
        }
        if modifiers & NSEvent.ModifierFlags.shift.rawValue != 0 {
            result |= UInt32(shiftKey)
        }

        return result
    }
}

// MARK: - Hotkey Combination Helpers

extension HotkeyCombination {
    /// Create from NSEvent
    public static func from(event: NSEvent) -> HotkeyCombination {
        HotkeyCombination(
            keyCode: event.keyCode,
            modifiers: event.modifierFlags.rawValue,
            displayString: event.modifierFlags.description + (event.charactersIgnoringModifiers?.uppercased() ?? "")
        )
    }
}

// MARK: - Errors

public enum HotkeyError: LocalizedError {
    case registrationFailed
    case alreadyRegistered
    case invalidCombination

    public var errorDescription: String? {
        switch self {
        case .registrationFailed:
            return "Failed to register hotkey. It may be in use by another application."
        case .alreadyRegistered:
            return "This hotkey is already registered."
        case .invalidCombination:
            return "Invalid key combination."
        }
    }
}
