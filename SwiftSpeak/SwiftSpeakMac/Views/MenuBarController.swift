//
//  MenuBarController.swift
//  SwiftSpeakMac
//
//  Menu bar controller with floating overlay for macOS
//

import AppKit
import SwiftUI
import Combine
import UserNotifications

@MainActor
final class MenuBarController: ObservableObject {

    // MARK: - Published State

    @Published var isRecording = false
    @Published var isOverlayVisible = false
    @Published var isProcessing = false
    @Published var currentMode: FormattingMode = .raw
    @Published var lastResult: String?
    @Published var lastError: String?

    // MARK: - Private Properties

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var floatingWindow: NSPanel?
    private var cancellables = Set<AnyCancellable>()
    private var settingsWindow: NSWindow?

    // MARK: - Dependencies

    private let audioRecorder: MacAudioRecorder
    private let textInsertion: MacTextInsertionService
    private let settings: MacSettings
    private let hotkeyManager: MacHotkeyManager

    init(audioRecorder: MacAudioRecorder,
         textInsertion: MacTextInsertionService,
         settings: MacSettings,
         hotkeyManager: MacHotkeyManager) {
        self.audioRecorder = audioRecorder
        self.textInsertion = textInsertion
        self.settings = settings
        self.hotkeyManager = hotkeyManager
    }

    // MARK: - Setup

    public func setup() {
        createStatusItem()
        createMenu()
        createFloatingWindow()
        setupBindings()
        setupHotkeys()
    }

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            // Use custom SwiftSpeakLogo icon
            if let icon = NSImage(named: "SwiftSpeakLogo") {
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = true  // Adapts to menu bar appearance
                button.image = icon
            } else {
                // Fallback to SF Symbol
                button.image = NSImage(systemSymbolName: "waveform.circle",
                                       accessibilityDescription: "SwiftSpeak")
            }
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func createMenu() {
        menu = NSMenu()

        // Record item
        let recordItem = NSMenuItem(title: "Start Recording",
                                    action: #selector(toggleRecording),
                                    keyEquivalent: "")
        recordItem.target = self
        menu?.addItem(recordItem)

        menu?.addItem(.separator())

        // Mode submenu
        let modeItem = NSMenuItem(title: "Mode", action: nil, keyEquivalent: "")
        let modeSubmenu = NSMenu()
        for mode in FormattingMode.allCases {
            let item = NSMenuItem(title: mode.displayName,
                                  action: #selector(selectMode(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            modeSubmenu.addItem(item)
        }
        modeItem.submenu = modeSubmenu
        menu?.addItem(modeItem)

        menu?.addItem(.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...",
                                      action: #selector(openSettings),
                                      keyEquivalent: ",")
        settingsItem.target = self
        menu?.addItem(settingsItem)

        menu?.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit SwiftSpeak",
                                  action: #selector(quit),
                                  keyEquivalent: "q")
        quitItem.target = self
        menu?.addItem(quitItem)
    }

    private func createFloatingWindow() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.animationBehavior = .utilityWindow

        // Set SwiftUI content
        let overlayView = RecordingOverlayView(
            audioRecorder: audioRecorder,
            currentMode: currentMode,
            isProcessing: isProcessing,
            onStop: { [weak self] in
                Task { await self?.stopRecordingAndProcess() }
            },
            onCancel: { [weak self] in
                self?.cancelRecording()
            }
        )
        window.contentView = NSHostingView(rootView: overlayView)

        floatingWindow = window
    }

    private func setupBindings() {
        // Update menu bar icon based on recording state
        audioRecorder.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] recording in
                self?.isRecording = recording
                self?.updateStatusIcon(isRecording: recording)
            }
            .store(in: &cancellables)
    }

    private func setupHotkeys() {
        // Register default hotkey (Cmd+Shift+D)
        try? hotkeyManager.registerDefaultHotkeys()

        // Set handler
        hotkeyManager.setHandler { [weak self] action in
            switch action {
            case .toggleRecording:
                self?.toggleRecording()
            case .cancelRecording:
                self?.cancelRecording()
            case .quickPaste:
                // Quick paste from clipboard
                break
            }
        }
    }

    // MARK: - Actions

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right click shows menu
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            // Left click toggles recording
            toggleRecording()
        }
    }

    @objc public func toggleRecording() {
        if audioRecorder.isRecording {
            Task { await stopRecordingAndProcess() }
        } else {
            Task { await startRecording() }
        }
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        if let mode = sender.representedObject as? FormattingMode {
            currentMode = mode
            // Update overlay if visible
            updateOverlayContent()
        }
    }

    @objc private func openSettings() {
        // Activate app and show settings
        NSApp.activate(ignoringOtherApps: true)

        if settingsWindow == nil {
            let settingsView = MacSettingsView(settings: settings)
            let hostingView = NSHostingView(rootView: settingsView)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "SwiftSpeak Settings"
            window.contentView = hostingView
            window.center()
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Recording Flow

    public func startRecording() async {
        showOverlay()

        do {
            try await audioRecorder.startRecording()
            lastError = nil
        } catch {
            hideOverlay()
            lastError = error.localizedDescription
            showNotification(title: "Recording Failed", body: error.localizedDescription)
        }
    }

    public func stopRecordingAndProcess() async {
        isProcessing = true
        updateOverlayContent()

        do {
            let audioURL = try audioRecorder.stopRecording()

            // Get transcription via provider factory
            let transcriptionResult = try await transcribe(audioURL: audioURL)

            // Format if needed
            let formattedResult: String
            if currentMode != .raw {
                formattedResult = try await format(text: transcriptionResult, mode: currentMode)
            } else {
                formattedResult = transcriptionResult
            }

            lastResult = formattedResult

            // Insert text
            let insertResult = await textInsertion.insertText(formattedResult, replaceSelection: true)

            switch insertResult {
            case .accessibilitySuccess:
                showNotification(title: "Text Inserted", body: "")
            case .clipboardFallback:
                showNotification(title: "Copied to Clipboard", body: "Press Cmd+V to paste")
            case .failed(let error):
                showNotification(title: "Insertion Failed", body: error.localizedDescription)
            }

            // Save to history
            saveToHistory(transcription: transcriptionResult, formatted: formattedResult)

        } catch {
            lastError = error.localizedDescription
            showNotification(title: "Transcription Failed", body: error.localizedDescription)
        }

        isProcessing = false
        hideOverlay()
    }

    public func cancelRecording() {
        audioRecorder.cancelRecording()
        hideOverlay()
    }

    // MARK: - Transcription & Formatting

    private func transcribe(audioURL: URL) async throws -> String {
        // Use ProviderFactory to create the appropriate transcription provider
        let providerFactory = ProviderFactory(settings: settings)
        let provider = settings.selectedTranscriptionProvider

        guard let transcriptionService = providerFactory.createTranscriptionProvider(for: provider) else {
            throw TranscriptionError.apiKeyMissing
        }

        return try await transcriptionService.transcribe(audioURL: audioURL, language: nil)
    }

    private func format(text: String, mode: FormattingMode) async throws -> String {
        // Use ProviderFactory to create the appropriate formatting provider
        let providerFactory = ProviderFactory(settings: settings)
        let provider = settings.selectedFormattingProvider

        guard let formattingService = providerFactory.createFormattingProvider(for: provider) else {
            // Return unformatted if no provider configured
            return text
        }

        return try await formattingService.format(text: text, mode: mode, customPrompt: nil)
    }

    private func saveToHistory(transcription: String, formatted: String) {
        let record = TranscriptionRecord(
            rawTranscription: transcription,
            formattedText: formatted,
            formattingMode: currentMode,
            duration: audioRecorder.duration,
            transcriptionProvider: settings.selectedTranscriptionProvider,
            formattingProvider: currentMode != .raw ? settings.selectedFormattingProvider : nil
        )
        settings.addToHistory(record)
    }

    // MARK: - UI Helpers

    public func showOverlay() {
        guard let window = floatingWindow else { return }

        // Position near mouse or center of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame

            // Center on screen
            let x = screenFrame.midX - windowFrame.width / 2
            let y = screenFrame.midY - windowFrame.height / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        updateOverlayContent()
        window.makeKeyAndOrderFront(nil)
        isOverlayVisible = true
    }

    public func hideOverlay() {
        floatingWindow?.orderOut(nil)
        isOverlayVisible = false
    }

    private func updateOverlayContent() {
        // Recreate overlay view with current state
        let overlayView = RecordingOverlayView(
            audioRecorder: audioRecorder,
            currentMode: currentMode,
            isProcessing: isProcessing,
            onStop: { [weak self] in
                Task { await self?.stopRecordingAndProcess() }
            },
            onCancel: { [weak self] in
                self?.cancelRecording()
            }
        )
        floatingWindow?.contentView = NSHostingView(rootView: overlayView)
    }

    private func updateStatusIcon(isRecording: Bool) {
        if let button = statusItem?.button {
            // Use custom SwiftSpeakLogo icon
            if let icon = NSImage(named: "SwiftSpeakLogo") {
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = !isRecording  // Disable template when recording for color
                button.image = icon
                button.contentTintColor = isRecording ? .systemRed : nil
            } else {
                // Fallback to SF Symbol
                let iconName = isRecording ? "waveform.circle.fill" : "waveform.circle"
                button.image = NSImage(systemSymbolName: iconName,
                                       accessibilityDescription: "SwiftSpeak")
                button.contentTintColor = isRecording ? .systemRed : nil
            }
        }

        // Update menu item title
        if let recordItem = menu?.items.first {
            recordItem.title = isRecording ? "Stop Recording" : "Start Recording"
        }
    }

    private func showNotification(title: String, body: String) {
        let notification = UNMutableNotificationContent()
        notification.title = title
        notification.body = body
        notification.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: notification,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Placeholder Settings View

struct MacSettingsView: View {
    @ObservedObject var settings: MacSettings

    var body: some View {
        TabView {
            ProvidersSettingsTab(settings: settings)
                .tabItem {
                    Label("Providers", systemImage: "cloud")
                }

            GeneralSettingsTab(settings: settings)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            HotkeySettingsTab()
                .tabItem {
                    Label("Hotkeys", systemImage: "keyboard")
                }
        }
        .frame(minWidth: 500, minHeight: 400)
        .padding()
    }
}

struct ProvidersSettingsTab: View {
    @ObservedObject var settings: MacSettings

    var body: some View {
        Form {
            Section("Transcription Provider") {
                Picker("Provider", selection: $settings.selectedTranscriptionProvider) {
                    ForEach(AIProvider.transcriptionProviders, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
            }

            Section("Formatting Provider") {
                Picker("Provider", selection: $settings.selectedFormattingProvider) {
                    ForEach(AIProvider.formattingProviders, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
            }

            Section("API Keys") {
                SecureField("OpenAI API Key", text: $settings.openAIApiKey)
                SecureField("Anthropic API Key", text: $settings.anthropicApiKey)
            }
        }
    }
}

struct GeneralSettingsTab: View {
    @ObservedObject var settings: MacSettings

    var body: some View {
        Form {
            Section("Default Mode") {
                Picker("Mode", selection: $settings.defaultMode) {
                    ForEach(FormattingMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            Toggle("Auto-return to previous app", isOn: .constant(true))
                .disabled(true)
        }
    }
}

struct HotkeySettingsTab: View {
    var body: some View {
        Form {
            Section("Global Hotkey") {
                HStack {
                    Text("Toggle Recording:")
                    Spacer()
                    Text("Cmd+Shift+D")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            Text("Hotkey customization coming soon")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }
}
