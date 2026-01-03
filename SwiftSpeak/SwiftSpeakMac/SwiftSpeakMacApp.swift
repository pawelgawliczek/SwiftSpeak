//
//  SwiftSpeakMacApp.swift
//  SwiftSpeakMac
//
//  macOS menu bar app entry point
//

import SwiftUI
import SwiftSpeakCore
import UserNotifications

@main
struct SwiftSpeakMacApp: App {

    // MARK: - App Delegate

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - State

    @StateObject private var menuBarController: MenuBarController

    // MARK: - Dependencies

    private let audioRecorder: MacAudioRecorder
    private let textInsertion: MacTextInsertionService
    private let settings: SharedSettings
    private let hotkeyManager: MacHotkeyManager
    private let permissionManager: MacPermissionManager
    private let biometricAuth: MacBiometricAuth

    // MARK: - Initialization

    init() {
        // Initialize dependencies
        let audioRecorder = MacAudioRecorder()
        let textInsertion = MacTextInsertionService()
        let settings = SharedSettings.shared
        let hotkeyManager = MacHotkeyManager()
        let permissionManager = MacPermissionManager()
        let biometricAuth = MacBiometricAuth()

        self.audioRecorder = audioRecorder
        self.textInsertion = textInsertion
        self.settings = settings
        self.hotkeyManager = hotkeyManager
        self.permissionManager = permissionManager
        self.biometricAuth = biometricAuth

        // Create menu bar controller
        let controller = MenuBarController(
            audioRecorder: audioRecorder,
            textInsertion: textInsertion,
            settings: settings,
            hotkeyManager: hotkeyManager
        )
        _menuBarController = StateObject(wrappedValue: controller)
    }

    // MARK: - App Body

    var body: some Scene {
        // Menu bar extra (the primary UI)
        MenuBarExtra {
            MenuBarContentView(controller: menuBarController)
        } label: {
            Image(systemName: menuBarController.isRecording ? "waveform.circle.fill" : "waveform.circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(menuBarController.isRecording ? .red : .primary)
        }
        .menuBarExtraStyle(.menu)

        // Settings window (opened from menu)
        Settings {
            MacSettingsView(settings: settings)
        }
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // Hide dock icon (we're a menu bar app)
        NSApp.setActivationPolicy(.accessory)

        // Setup menu bar after a short delay to ensure @main init completes
        DispatchQueue.main.async {
            self.setupMenuBar()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
    }

    private func setupMenuBar() {
        // The actual menu bar setup is done by the MenuBarController
        // This is just a fallback in case the SwiftUI MenuBarExtra doesn't work as expected
    }
}

// MARK: - Menu Bar Content View

struct MenuBarContentView: View {
    @ObservedObject var controller: MenuBarController

    var body: some View {
        VStack(spacing: 0) {
            // Record button
            Button {
                controller.toggleRecording()
            } label: {
                HStack {
                    Image(systemName: controller.isRecording ? "stop.circle.fill" : "record.circle")
                        .foregroundStyle(controller.isRecording ? .red : .primary)
                    Text(controller.isRecording ? "Stop Recording" : "Start Recording")
                }
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Divider()

            // Mode submenu
            Menu("Mode: \(controller.currentMode.displayName)") {
                ForEach(FormattingMode.allCases, id: \.self) { mode in
                    Button {
                        controller.currentMode = mode
                    } label: {
                        HStack {
                            Text(mode.displayName)
                            if mode == controller.currentMode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Divider()

            // Settings
            SettingsLink {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings...")
                }
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            // Quit
            Button("Quit SwiftSpeak") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}

// MARK: - Accessibility Permission View

struct AccessibilityPermissionView: View {
    @ObservedObject var permissionManager: MacPermissionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Accessibility Permission Required")
                .font(.title2.bold())

            Text("SwiftSpeak needs accessibility permission to insert text directly into other applications. Without it, text will be copied to your clipboard instead.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            VStack(spacing: 12) {
                Button("Open System Settings") {
                    permissionManager.promptForAccessibilityPermission()
                }
                .buttonStyle(.borderedProminent)

                Button("Continue Without") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Text("You can always grant this permission later in System Settings > Privacy & Security > Accessibility")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(width: 400)
    }
}

// MARK: - Onboarding View

struct MacOnboardingView: View {
    @ObservedObject var permissionManager: MacPermissionManager
    @Binding var isOnboardingComplete: Bool

    @State private var currentStep = 0

    var body: some View {
        VStack(spacing: 32) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<3) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            // Content
            switch currentStep {
            case 0:
                welcomeStep
            case 1:
                microphoneStep
            case 2:
                accessibilityStep
            default:
                EmptyView()
            }

            Spacer()

            // Navigation
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button(currentStep == 2 ? "Get Started" : "Next") {
                    if currentStep == 2 {
                        isOnboardingComplete = true
                    } else {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(width: 500, height: 400)
    }

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.accent)

            Text("Welcome to SwiftSpeak")
                .font(.title.bold())

            Text("Voice-to-text with AI formatting for macOS. Dictate anywhere with a global hotkey.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private var microphoneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)

            Text("Microphone Access")
                .font(.title.bold())

            Text("SwiftSpeak needs microphone access to record your voice for transcription.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Grant Microphone Access") {
                Task {
                    _ = await permissionManager.requestPermission(.microphone)
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var accessibilityStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 72))
                .foregroundStyle(.orange)

            Text("Accessibility Access")
                .font(.title.bold())

            Text("For direct text insertion, SwiftSpeak needs accessibility access. This is optional - without it, text will be copied to your clipboard.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Grant Accessibility Access") {
                permissionManager.promptForAccessibilityPermission()
            }
            .buttonStyle(.bordered)
        }
    }
}
