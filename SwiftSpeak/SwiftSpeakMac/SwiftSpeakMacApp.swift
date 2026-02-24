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
import SwiftSpeakCore

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var splashController: MacSplashController?
    private var contentImportWindowController: MacContentImportWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register URL scheme handler
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        // Request accessibility permission (required for window context capture)
        requestAccessibilityPermission()

        // Request Automation permission for System Events (triggers prompt on first run)
        requestAutomationPermission()

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

            // Initialize device manager to get validated device ID
            // Device IDs can change between macOS sessions, so we must validate
            let audioDeviceManager = MacAudioDeviceManager()
            if let validatedDeviceID = audioDeviceManager.getSelectedDeviceID() {
                audioRecorder.selectedDeviceID = validatedDeviceID
                macLog("Loaded validated audio device ID: \(validatedDeviceID)", category: "Audio")
            } else {
                macLog("Using system default audio device", category: "Audio")
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

    /// Request Automation permission for System Events - triggers system prompt
    private func requestAutomationPermission() {
        print("[APP] Requesting Automation permission for System Events...")

        // This simple AppleScript will trigger the Automation permission dialog
        let script = NSAppleScript(source: """
            tell application "System Events"
                return name of first process whose frontmost is true
            end tell
        """)

        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)

        if let output = result?.stringValue {
            print("[APP] Automation permission granted! Frontmost app: \(output)")
        } else if let err = error {
            let errorNum = err["NSAppleScriptErrorNumber"] as? Int ?? 0
            if errorNum == -1743 {
                print("[APP] Automation permission DENIED by user")
            } else if errorNum == -600 {
                print("[APP] Automation permission needed - should show prompt")
            } else {
                print("[APP] Automation error: \(err)")
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return false
    }

    // MARK: - URL Scheme Handling

    private func logToFile(_ message: String) {
        let logFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("swiftspeak_debug.log")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(message)\n"
        if let data = entry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        logToFile("handleURLEvent called")
        print("[URLScheme] handleURLEvent called")
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            logToFile("Failed to parse URL from event")
            print("[URLScheme] Failed to parse URL from event")
            macLog("Failed to parse URL from event", category: "URLScheme")
            return
        }

        logToFile("Received URL: \(urlString)")
        print("[URLScheme] Received URL: \(urlString)")
        macLog("Received URL: \(urlString)", category: "URLScheme")
        handleURL(url)
    }

    private func handleURL(_ url: URL) {
        // Parse URL scheme: swiftspeak-mac://share?type={type}&file={id}
        guard url.scheme == "swiftspeak-mac" else { return }

        switch url.host {
        case "share":
            handleShareURL(url)
        default:
            macLog("Unknown URL host: \(url.host ?? "nil")", category: "URLScheme")
        }
    }

    private func handleShareURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            macLog("Invalid share URL format", category: "URLScheme")
            return
        }

        // Parse type parameter
        let typeString = queryItems.first(where: { $0.name == "type" })?.value ?? "audio"
        guard let contentType = SharedContentType(rawValue: typeString) else {
            macLog("Unknown content type: \(typeString)", category: "URLScheme")
            return
        }

        // Parse file/source parameter
        let fileId = queryItems.first(where: { $0.name == "file" })?.value
        let sourceURL = queryItems.first(where: { $0.name == "source" })?.value

        macLog("Share received: type=\(contentType.rawValue), fileId=\(fileId ?? "nil"), source=\(sourceURL ?? "nil")", category: "URLScheme")

        // Open content import window
        Task { @MainActor in
            showContentImportWindow(contentType: contentType, fileId: fileId, sourceURL: sourceURL)
        }
    }

    @MainActor
    private func showContentImportWindow(contentType: SharedContentType, fileId: String?, sourceURL: String?) {
        print("[URLScheme] showContentImportWindow called with type: \(contentType.rawValue)")

        // Create or reuse window controller
        if contentImportWindowController == nil {
            print("[URLScheme] Creating new MacContentImportWindowController")
            contentImportWindowController = MacContentImportWindowController()
        }

        // Create provider factory for LLM access
        let providerFactory = ProviderFactory(settings: MacSettings.shared)

        print("[URLScheme] Calling showWindow...")
        contentImportWindowController?.showWindow(
            contentType: contentType,
            fileId: fileId,
            sourceURL: sourceURL,
            settings: MacSettings.shared,
            providerFactory: providerFactory
        )
        print("[URLScheme] showWindow completed")
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
