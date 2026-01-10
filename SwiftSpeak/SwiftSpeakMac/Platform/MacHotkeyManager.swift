//
//  MacHotkeyManager.swift
//  SwiftSpeakMac
//
//  Global hotkey management using Carbon Events API
//

import Carbon
import AppKit
import Combine
import ApplicationServices

@MainActor
final class MacHotkeyManager: HotkeyManagerProtocol, ObservableObject {

    /// Shared singleton instance
    static let shared = MacHotkeyManager()

    @Published private(set) var registeredHotkeys: [HotkeyAction: HotkeyCombination] = [:]

    private var eventHandler: ((HotkeyAction, HotkeyContext) -> Void)?
    private var keyUpHandler: ((HotkeyAction) -> Void)?  // Handler for key release events
    private var hotkeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var hotkeyActions: [UInt32: HotkeyAction] = [:]
    private var nextHotkeyId: UInt32 = 1
    private var eventHandlerRef: EventHandlerRef?
    private var keyUpEventHandlerRef: EventHandlerRef?  // Separate handler for key up
    private var hotkeyIdToPowerModeId: [UInt32: UUID] = [:]
    private var powerModeHotkeys: [UUID: HotkeyCombination] = [:]
    private var hotkeyIdToContextId: [UInt32: UUID] = [:]
    private var contextHotkeys: [UUID: HotkeyCombination] = [:]

    // MARK: - Initialization

    private init() {
        installEventHandler()
    }

    deinit {
        // Unregister all hotkeys
        for ref in hotkeyRefs.values {
            UnregisterEventHotKey(ref)
        }
        // Remove event handlers
        if let handlerRef = eventHandlerRef {
            RemoveEventHandler(handlerRef)
        }
        if let keyUpHandlerRef = keyUpEventHandlerRef {
            RemoveEventHandler(keyUpHandlerRef)
        }
    }

    // MARK: - Public Methods

    func registerHotkey(_ combination: HotkeyCombination, for action: HotkeyAction) throws {
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

    func unregisterHotkey(for action: HotkeyAction) {
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

    func setHandler(_ handler: @escaping (HotkeyAction, HotkeyContext) -> Void) {
        self.eventHandler = handler
    }

    /// Set handler for key up (release) events
    /// Used for push-to-talk functionality
    func setKeyUpHandler(_ handler: @escaping (HotkeyAction) -> Void) {
        self.keyUpHandler = handler
    }

    // MARK: - Default Hotkeys

    func registerDefaultHotkeys() throws {
        // Default: Cmd+Shift+D for toggle recording
        let defaultCombination = HotkeyCombination(
            keyCode: 0x02, // 'd' key
            modifiers: UInt(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue),
            displayString: "⌘⇧D"
        )

        try registerHotkey(defaultCombination, for: .toggleRecording)
    }

    // MARK: - Power Mode Hotkeys

    /// Register a hotkey for a specific Power Mode
    /// - Parameters:
    ///   - powerModeId: UUID of the Power Mode
    ///   - keyCode: Virtual key code
    ///   - modifiers: Modifier flags
    /// - Returns: true if registration succeeded
    @discardableResult
    func registerPowerModeHotkey(
        powerModeId: UUID,
        keyCode: UInt16,
        modifiers: UInt
    ) -> Bool {
        // Create hotkey combination
        let combination = HotkeyCombination(
            keyCode: keyCode,
            modifiers: modifiers,
            displayString: displayString(from: keyCode, modifiers: modifiers)
        )

        // Unregister existing hotkey for this Power Mode
        unregisterPowerModeHotkey(powerModeId: powerModeId)

        let hotkeyId = nextHotkeyId
        nextHotkeyId += 1

        var hotKeyRef: EventHotKeyRef?
        var hotKeyID = EventHotKeyID(
            signature: OSType(0x5353_504B), // "SSPK"
            id: hotkeyId
        )

        let carbonModifiers = carbonModifiers(from: modifiers)

        let status = RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let ref = hotKeyRef else {
            return false
        }

        hotkeyRefs[hotkeyId] = ref
        hotkeyIdToPowerModeId[hotkeyId] = powerModeId
        powerModeHotkeys[powerModeId] = combination

        return true
    }

    /// Unregister hotkey for a Power Mode
    /// - Parameter powerModeId: UUID of the Power Mode
    func unregisterPowerModeHotkey(powerModeId: UUID) {
        // Find the hotkey ID for this Power Mode
        guard let hotkeyId = hotkeyIdToPowerModeId.first(where: { $0.value == powerModeId })?.key else {
            return
        }

        // Unregister the hotkey
        if let ref = hotkeyRefs[hotkeyId] {
            UnregisterEventHotKey(ref)
        }

        hotkeyRefs.removeValue(forKey: hotkeyId)
        hotkeyIdToPowerModeId.removeValue(forKey: hotkeyId)
        powerModeHotkeys.removeValue(forKey: powerModeId)
    }

    /// Get all registered Power Mode hotkeys
    /// - Returns: Dictionary mapping Power Mode IDs to hotkey combinations
    func getPowerModeHotkeys() -> [UUID: HotkeyCombination] {
        return powerModeHotkeys
    }

    // MARK: - Context Hotkeys

    /// Register a hotkey for a specific Context
    /// - Parameters:
    ///   - contextId: UUID of the Context
    ///   - keyCode: Virtual key code
    ///   - modifiers: Modifier flags
    /// - Returns: true if registration succeeded
    @discardableResult
    func registerContextHotkey(
        contextId: UUID,
        keyCode: UInt16,
        modifiers: UInt
    ) -> Bool {
        // Create hotkey combination
        let combination = HotkeyCombination(
            keyCode: keyCode,
            modifiers: modifiers,
            displayString: displayString(from: keyCode, modifiers: modifiers)
        )

        // Unregister existing hotkey for this Context
        unregisterContextHotkey(contextId: contextId)

        let hotkeyId = nextHotkeyId
        nextHotkeyId += 1

        var hotKeyRef: EventHotKeyRef?
        var hotKeyID = EventHotKeyID(
            signature: OSType(0x5353_504B), // "SSPK"
            id: hotkeyId
        )

        let carbonModifiers = carbonModifiers(from: modifiers)

        let status = RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let ref = hotKeyRef else {
            return false
        }

        hotkeyRefs[hotkeyId] = ref
        hotkeyIdToContextId[hotkeyId] = contextId
        contextHotkeys[contextId] = combination

        return true
    }

    /// Unregister hotkey for a Context
    /// - Parameter contextId: UUID of the Context
    func unregisterContextHotkey(contextId: UUID) {
        // Find the hotkey ID for this Context
        guard let hotkeyId = hotkeyIdToContextId.first(where: { $0.value == contextId })?.key else {
            return
        }

        // Unregister the hotkey
        if let ref = hotkeyRefs[hotkeyId] {
            UnregisterEventHotKey(ref)
        }

        hotkeyRefs.removeValue(forKey: hotkeyId)
        hotkeyIdToContextId.removeValue(forKey: hotkeyId)
        contextHotkeys.removeValue(forKey: contextId)
    }

    /// Get all registered Context hotkeys
    /// - Returns: Dictionary mapping Context IDs to hotkey combinations
    func getContextHotkeys() -> [UUID: HotkeyCombination] {
        return contextHotkeys
    }

    /// Generate display string for hotkey combination
    private func displayString(from keyCode: UInt16, modifiers: UInt) -> String {
        var result = ""

        if modifiers & NSEvent.ModifierFlags.control.rawValue != 0 {
            result += "⌃"
        }
        if modifiers & NSEvent.ModifierFlags.option.rawValue != 0 {
            result += "⌥"
        }
        if modifiers & NSEvent.ModifierFlags.shift.rawValue != 0 {
            result += "⇧"
        }
        if modifiers & NSEvent.ModifierFlags.command.rawValue != 0 {
            result += "⌘"
        }

        // Map key code to character (simplified)
        let keyChar = keyCodeToCharacter(keyCode)
        result += keyChar

        return result
    }

    /// Convert key code to character (simplified mapping)
    private func keyCodeToCharacter(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 0x00: return "A"
        case 0x01: return "S"
        case 0x02: return "D"
        case 0x03: return "F"
        case 0x04: return "H"
        case 0x05: return "G"
        case 0x06: return "Z"
        case 0x07: return "X"
        case 0x08: return "C"
        case 0x09: return "V"
        case 0x0B: return "B"
        case 0x0C: return "Q"
        case 0x0D: return "W"
        case 0x0E: return "E"
        case 0x0F: return "R"
        case 0x10: return "Y"
        case 0x11: return "T"
        case 0x1D: return "0"
        case 0x12: return "1"
        case 0x13: return "2"
        case 0x14: return "3"
        case 0x15: return "4"
        case 0x17: return "5"
        case 0x16: return "6"
        case 0x1A: return "7"
        case 0x1C: return "8"
        case 0x19: return "9"
        case 0x23: return "P"
        case 0x25: return "L"
        case 0x26: return "J"
        case 0x28: return "K"
        case 0x2C: return "/"
        case 0x2E: return "M"
        case 0x2F: return "N"
        case 0x20: return "U"
        case 0x22: return "I"
        case 0x1F: return "O"
        case 0x31: return "Space"
        default: return String(format: "Key%02X", keyCode)
        }
    }

    // MARK: - Private Methods

    private func installEventHandler() {
        // Install key down handler
        var keyDownEventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Install key up handler for push-to-talk
        var keyUpEventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyReleased)
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

            // CRITICAL: Capture frontmost app NOW, before any async dispatch
            // This is the only moment we can reliably get the user's active app
            let frontmostApp = NSWorkspace.shared.frontmostApplication
            let pid = frontmostApp?.processIdentifier ?? 0
            let bundleId = frontmostApp?.bundleIdentifier ?? ""
            let appName = frontmostApp?.localizedName ?? ""
            let clipboard = NSPasteboard.general.string(forType: .string)

            // CRITICAL: Capture selected text by simulating Cmd+C
            // This is the reliable method used by Alfred, Raycast, etc.
            // Accessibility APIs fail because focus shifts even in synchronous callbacks
            var selectedText: String?
            var windowTitle: String?

            // Save original clipboard content
            let originalClipboard = NSPasteboard.general.string(forType: .string)

            // Clear clipboard to detect if copy succeeds
            NSPasteboard.general.clearContents()

            // Simulate Cmd+C to copy selected text
            let source = CGEventSource(stateID: .hidSystemState)
            let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)  // 'c' key
            cmdDown?.flags = .maskCommand
            let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
            cmdUp?.flags = .maskCommand

            cmdDown?.post(tap: .cghidEventTap)
            cmdUp?.post(tap: .cghidEventTap)

            // Brief pause to let the copy complete
            usleep(50000)  // 50ms

            // Read the copied text
            if let copiedText = NSPasteboard.general.string(forType: .string), !copiedText.isEmpty {
                selectedText = String(copiedText.prefix(5000))
                print("[HOTKEY] Captured selected text via Cmd+C: \(copiedText.prefix(50))...")

                // Restore original clipboard
                if let original = originalClipboard {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(original, forType: .string)
                }
            } else {
                print("[HOTKEY] No text was selected (Cmd+C returned empty)")
                // Restore original clipboard
                if let original = originalClipboard {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(original, forType: .string)
                }
            }

            // DEBUG: Print to Xcode console
            print("[HOTKEY CALLBACK] Captured app: \(appName) (PID: \(pid), bundle: \(bundleId))")
            print("[HOTKEY CALLBACK] Selected text: \(selectedText?.prefix(50) ?? "nil")")
            print("[HOTKEY CALLBACK] Thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")

            let capturedContext = HotkeyContext(
                frontmostAppPid: pid,
                frontmostAppBundleId: bundleId,
                frontmostAppName: appName,
                clipboard: clipboard,
                selectedText: selectedText,
                windowTitle: windowTitle
            )

            // Dispatch to main actor with captured context
            let manager = Unmanaged<MacHotkeyManager>.fromOpaque(userData).takeUnretainedValue()

            Task { @MainActor in
                // Check standard hotkey actions
                if let action = manager.hotkeyActions[hotKeyID.id] {
                    manager.eventHandler?(action, capturedContext)
                }
                // Check power mode specific hotkeys
                else if let powerModeId = manager.hotkeyIdToPowerModeId[hotKeyID.id] {
                    manager.eventHandler?(.powerMode(powerModeId), capturedContext)
                }
                // Check context specific hotkeys
                else if let contextId = manager.hotkeyIdToContextId[hotKeyID.id] {
                    manager.eventHandler?(.context(contextId), capturedContext)
                }
            }

            return noErr
        }

        var handlerRef: EventHandlerRef?
        InstallEventHandler(
            GetEventDispatcherTarget(),
            callback,
            1,
            &keyDownEventType,
            selfPtr,
            &handlerRef
        )

        self.eventHandlerRef = handlerRef

        // Key up callback (for push-to-talk)
        let keyUpCallback: EventHandlerUPP = { _, event, userData -> OSStatus in
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

            let manager = Unmanaged<MacHotkeyManager>.fromOpaque(userData).takeUnretainedValue()

            Task { @MainActor in
                // Check standard hotkey actions
                if let action = manager.hotkeyActions[hotKeyID.id] {
                    manager.keyUpHandler?(action)
                }
            }

            return noErr
        }

        var keyUpHandlerRef: EventHandlerRef?
        InstallEventHandler(
            GetEventDispatcherTarget(),
            keyUpCallback,
            1,
            &keyUpEventType,
            selfPtr,
            &keyUpHandlerRef
        )

        self.keyUpEventHandlerRef = keyUpHandlerRef
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
    static func from(event: NSEvent) -> HotkeyCombination {
        HotkeyCombination(
            keyCode: event.keyCode,
            modifiers: event.modifierFlags.rawValue,
            displayString: modifierString(from: event.modifierFlags) + (event.charactersIgnoringModifiers?.uppercased() ?? "")
        )
    }

    private static func modifierString(from flags: NSEvent.ModifierFlags) -> String {
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        return result
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
