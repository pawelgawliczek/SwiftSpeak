//
//  SwiftSpeakMacApp.swift
//  SwiftSpeakMac
//
//  Main entry point for SwiftSpeak macOS menu bar app
//

import SwiftUI
import AppKit
import UserNotifications

@main
struct SwiftSpeakMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar app - no main window
        Settings {
            MacSettingsView(settings: MacSettings.shared)
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon for menu bar app
        NSApp.setActivationPolicy(.accessory)

        // Initialize components
        let audioRecorder = MacAudioRecorder()
        let textInsertion = MacTextInsertionService()
        let settings = MacSettings.shared
        let hotkeyManager = MacHotkeyManager()

        // Create menu bar controller
        menuBarController = MenuBarController(
            audioRecorder: audioRecorder,
            textInsertion: textInsertion,
            settings: settings,
            hotkeyManager: hotkeyManager
        )
        menuBarController?.setup()

        // Request notification permission
        requestNotificationPermission()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
