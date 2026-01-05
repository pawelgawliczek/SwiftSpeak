//
//  SwiftSpeakMacApp.swift
//  SwiftSpeakMac
//
//  Main entry point for SwiftSpeak macOS menu bar app
//  MENU BAR ONLY - no dock icon, no main window
//  Settings accessed via right-click → Settings on menu bar icon
//

import AppKit
import UserNotifications
import ApplicationServices

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request accessibility permission (required for window context capture)
        requestAccessibilityPermission()

        // Initialize components on main actor
        Task { @MainActor in
            // Initialize components
            let audioRecorder = MacAudioRecorder()
            let textInsertion = MacTextInsertionService()
            let settings = MacSettings.shared
            let hotkeyManager = MacHotkeyManager.shared

            // Create menu bar controller
            self.menuBarController = MenuBarController(
                audioRecorder: audioRecorder,
                textInsertion: textInsertion,
                settings: settings,
                hotkeyManager: hotkeyManager
            )
            self.menuBarController?.setup()

            // Start monitoring for pending Obsidian notes from iOS
            MacPendingNotesProcessor.shared.startMonitoring()
        }

        // Request notification permission
        requestNotificationPermission()
    }

    /// Request accessibility permission - shows system prompt if not already granted
    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        print("[APP] Accessibility permission: \(trusted ? "granted" : "requesting...")")
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return false
    }
}

// MARK: - Main Entry Point

@main
struct SwiftSpeakMacMain {
    static func main() {
        // Set activation policy BEFORE NSApplication runs
        // This must happen early to prevent dock icon
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let delegate = AppDelegate()
        app.delegate = delegate

        // Run the application
        app.run()
    }
}
