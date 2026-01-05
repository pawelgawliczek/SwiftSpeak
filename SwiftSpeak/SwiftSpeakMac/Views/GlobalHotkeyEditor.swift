//
//  GlobalHotkeyEditor.swift
//  SwiftSpeakMac
//
//  Reusable hotkey editor component for global actions
//  Supports recording key combinations for any HotkeyAction
//

import SwiftUI
import AppKit

// MARK: - Global Hotkey Editor View

struct GlobalHotkeyEditor: View {

    // MARK: - Properties

    let title: String
    let description: String
    let action: HotkeyAction
    @Binding var hotkey: HotkeyCombination?
    @ObservedObject var hotkeyManager: MacHotkeyManager

    @State private var isRecording = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var keyMonitor: Any?

    // MARK: - Computed Properties

    private var hotkeyDisplay: String {
        if let hotkey = hotkey {
            return hotkey.displayString
        }
        return "Not Set"
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            // Hotkey Display / Recording Field
            HStack {
                if isRecording {
                    HStack {
                        Image(systemName: "keyboard")
                            .foregroundColor(.blue)
                        Text("Press key combination...")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                    )
                } else {
                    HStack {
                        Image(systemName: hotkey != nil ? "checkmark.circle.fill" : "keyboard")
                            .foregroundColor(hotkey != nil ? .green : .secondary)

                        Text(hotkeyDisplay)
                            .foregroundColor(hotkey != nil ? .primary : .secondary)
                            .font(.system(.body, design: .monospaced))

                        Spacer()

                        if hotkey != nil {
                            Button(action: clearHotkey) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Clear hotkey")
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    )
                }

                // Record Button
                Button(action: toggleRecording) {
                    Text(isRecording ? "Cancel" : "Record")
                        .frame(minWidth: 70)
                }
                .buttonStyle(.bordered)
                .tint(isRecording ? .red : .blue)
            }

            // Description
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .alert("Hotkey Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            setupKeyMonitoring()
        }
        .onDisappear {
            cleanupKeyMonitoring()
        }
    }

    // MARK: - Actions

    private func toggleRecording() {
        if isRecording {
            // Cancel recording
            isRecording = false
            cleanupKeyMonitoring()
        } else {
            // Start recording
            isRecording = true
            setupKeyMonitoring()
        }
    }

    private func clearHotkey() {
        hotkey = nil
        hotkeyManager.unregisterHotkey(for: action)
    }

    // MARK: - Key Monitoring

    private func setupKeyMonitoring() {
        // Remove existing monitor
        cleanupKeyMonitoring()

        // Monitor for key press when recording
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if self.isRecording {
                self.handleKeyPress(event)
                return nil // Consume event
            }
            return event
        }
    }

    private func cleanupKeyMonitoring() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func handleKeyPress(_ event: NSEvent) {
        // Require at least one modifier key
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasModifier = modifiers.contains(.command) ||
                          modifiers.contains(.control) ||
                          modifiers.contains(.option)

        guard hasModifier else {
            showError(message: "Hotkeys must include at least one modifier key (⌘, ⌃, or ⌥)")
            isRecording = false
            return
        }

        // Get key code and create combination
        let keyCode = UInt16(event.keyCode)
        let modifierFlags = UInt(modifiers.rawValue)

        // Create display string
        let displayString = displayString(from: keyCode, modifiers: modifierFlags)

        // Check if hotkey is already in use by system
        if isSystemHotkey(keyCode: keyCode, modifiers: modifierFlags) {
            showError(message: "This hotkey is reserved by the system")
            isRecording = false
            return
        }

        // Check if hotkey is already in use by another action
        if isHotkeyInUse(keyCode: keyCode, modifiers: modifierFlags) {
            showError(message: "This hotkey is already assigned to another action")
            isRecording = false
            return
        }

        // Create combination
        let combination = HotkeyCombination(
            keyCode: keyCode,
            modifiers: modifierFlags,
            displayString: displayString
        )

        // Register with hotkey manager
        do {
            try hotkeyManager.registerHotkey(combination, for: action)
            hotkey = combination
        } catch {
            showError(message: "Failed to register hotkey. This combination may be in use by another application.")
        }

        isRecording = false
    }

    // MARK: - Helpers

    private func isHotkeyInUse(keyCode: UInt16, modifiers: UInt) -> Bool {
        // Check registered hotkeys
        for (_, combo) in hotkeyManager.registeredHotkeys {
            if combo.keyCode == keyCode && combo.modifiers == modifiers {
                return true
            }
        }
        return false
    }

    private func isSystemHotkey(keyCode: UInt16, modifiers: UInt) -> Bool {
        let systemHotkeys: [(UInt16, UInt)] = [
            (0x06, UInt(NSEvent.ModifierFlags.command.rawValue)), // Cmd+Z (undo)
            (0x07, UInt(NSEvent.ModifierFlags.command.rawValue)), // Cmd+X (cut)
            (0x08, UInt(NSEvent.ModifierFlags.command.rawValue)), // Cmd+C (copy)
            (0x09, UInt(NSEvent.ModifierFlags.command.rawValue)), // Cmd+V (paste)
            (0x0C, UInt(NSEvent.ModifierFlags.command.rawValue)), // Cmd+Q (quit)
            (0x0D, UInt(NSEvent.ModifierFlags.command.rawValue)), // Cmd+W (close)
        ]

        return systemHotkeys.contains { $0.0 == keyCode && $0.1 == modifiers }
    }

    private func displayString(from keyCode: UInt16, modifiers: UInt) -> String {
        var result = ""

        let flags = NSEvent.ModifierFlags(rawValue: modifiers)

        // Add modifier symbols in proper order
        if flags.contains(.control) {
            result += "⌃"
        }
        if flags.contains(.option) {
            result += "⌥"
        }
        if flags.contains(.shift) {
            result += "⇧"
        }
        if flags.contains(.command) {
            result += "⌘"
        }

        // Add key character
        result += keyCharacter(from: keyCode)

        return result
    }

    private func keyCharacter(from keyCode: UInt16) -> String {
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
        case 0x12: return "1"
        case 0x13: return "2"
        case 0x14: return "3"
        case 0x15: return "4"
        case 0x16: return "6"
        case 0x17: return "5"
        case 0x18: return "="
        case 0x19: return "9"
        case 0x1A: return "7"
        case 0x1B: return "-"
        case 0x1C: return "8"
        case 0x1D: return "0"
        case 0x1E: return "]"
        case 0x1F: return "O"
        case 0x20: return "U"
        case 0x21: return "["
        case 0x22: return "I"
        case 0x23: return "P"
        case 0x24: return "↩︎" // Return
        case 0x25: return "L"
        case 0x26: return "J"
        case 0x27: return "'"
        case 0x28: return "K"
        case 0x29: return ";"
        case 0x2A: return "\\"
        case 0x2B: return ","
        case 0x2C: return "/"
        case 0x2D: return "N"
        case 0x2E: return "M"
        case 0x2F: return "."
        case 0x31: return "Space"
        case 0x33: return "⌫" // Delete
        case 0x35: return "⎋" // Escape
        case 0x7A: return "F1"
        case 0x78: return "F2"
        case 0x63: return "F3"
        case 0x76: return "F4"
        case 0x60: return "F5"
        case 0x61: return "F6"
        case 0x62: return "F7"
        case 0x64: return "F8"
        case 0x65: return "F9"
        case 0x6D: return "F10"
        case 0x67: return "F11"
        case 0x6F: return "F12"
        case 0x7E: return "↑" // Arrow Up
        case 0x7D: return "↓" // Arrow Down
        case 0x7B: return "←" // Arrow Left
        case 0x7C: return "→" // Arrow Right
        default: return "?"
        }
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Preview

#if DEBUG
struct GlobalHotkeyEditor_Previews: PreviewProvider {
    @State static var hotkey: HotkeyCombination? = nil

    static var previews: some View {
        GlobalHotkeyEditor(
            title: "Power Mode Shortcut",
            description: "Open the Power Mode overlay from anywhere",
            action: .openPowerModeOverlay,
            hotkey: $hotkey,
            hotkeyManager: MacHotkeyManager.shared
        )
        .frame(width: 400)
        .padding()
    }
}
#endif
