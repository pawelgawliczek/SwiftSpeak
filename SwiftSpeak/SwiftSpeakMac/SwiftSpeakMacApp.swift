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
    private var splashController: MacSplashController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request accessibility permission (required for window context capture)
        requestAccessibilityPermission()

        // Set up main menu with Edit menu (enables Cmd+C, Cmd+V, etc. in text fields)
        setupMainMenu()

        // Initialize components on main actor
        Task { @MainActor in
            // Show splash screen during initialization
            let splash = MacSplashController()
            self.splashController = splash
            splash.show()

            // Initialize components
            let audioRecorder = MacAudioRecorder()

            // Load saved audio device selection
            if let savedDeviceID = UserDefaults.standard.string(forKey: "mac_selectedAudioInputDeviceID"),
               let deviceID = UInt32(savedDeviceID) {
                audioRecorder.selectedDeviceID = deviceID
                macLog("Loaded saved audio device: \(savedDeviceID)", category: "Audio")
            }

            // Pre-warm audio engine (this is the heavy operation)
            // We await it to ensure splash shows during the actual initialization
            await audioRecorder.prewarmAsync()

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

            // Dismiss splash screen - initialization complete
            splash.dismiss()
            self.splashController = nil
        }

        // Request notification permission
        requestNotificationPermission()
    }

    /// Set up the main menu with standard Edit menu for Copy/Paste support
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu (required, even if mostly empty)
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit SwiftSpeak", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit menu (enables standard text editing shortcuts)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")

        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
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
