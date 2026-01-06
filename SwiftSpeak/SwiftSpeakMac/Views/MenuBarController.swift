//
//  MenuBarController.swift
//  SwiftSpeakMac
//
//  Menu bar controller with floating overlay for macOS
//

import AppKit
import SwiftUI
import SwiftSpeakCore
import Combine
import UserNotifications

// OverlayViewModel is defined in RecordingOverlayView.swift

@MainActor
final class MenuBarController: NSObject, ObservableObject, NSWindowDelegate {

    // MARK: - Published State

    @Published var isRecording = false
    @Published var isOverlayVisible = false
    @Published var isProcessing = false {
        didSet { overlayViewModel.isProcessing = isProcessing }
    }
    @Published var isTranslationEnabled = false {
        didSet { overlayViewModel.isTranslationEnabled = isTranslationEnabled }
    }
    @Published var targetLanguage: Language = .spanish {
        didSet { overlayViewModel.targetLanguage = targetLanguage }
    }
    @Published var lastResult: String?
    @Published var lastError: String?

    // MARK: - Private Properties

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var floatingWindow: NSPanel?
    private var hostingView: NSHostingView<OverlayWrapperView>?
    private var cancellables = Set<AnyCancellable>()
    private var settingsWindow: NSWindow?
    private var transcriptionHistoryWindow: NSWindow?
    private var meetingHistoryWindow: NSWindow?
    private var meetingRecordingWindow: NSWindow?
    private var meetingResultWindow: NSWindow?
    private let overlayViewModel = OverlayViewModel()
    private var frontmostAppObserver: NSObjectProtocol?
    private var lastFrontmostBundleId: String?
    private var localKeyboardMonitor: Any?
    private var powerModeOverlayController: MacPowerModeOverlayController?
    private var transcribeOverlayController: MacTranscribeOverlayController?

    // MARK: - Dependencies

    private let audioRecorder: MacAudioRecorder
    private let textInsertion: MacTextInsertionService
    private let settings: MacSettings
    private let hotkeyManager: MacHotkeyManager
    private lazy var windowContextService = MacWindowContextService()
    private lazy var providerFactory = ProviderFactory(settings: settings)

    init(audioRecorder: MacAudioRecorder,
         textInsertion: MacTextInsertionService,
         settings: MacSettings,
         hotkeyManager: MacHotkeyManager) {
        self.audioRecorder = audioRecorder
        self.textInsertion = textInsertion
        self.settings = settings
        self.hotkeyManager = hotkeyManager
        super.init()
    }

    // MARK: - Setup

    public func setup() {
        createStatusItem()
        createMenu()
        createFloatingWindow()
        setupBindings()
        setupHotkeys()
        setupFrontmostAppMonitor()
        setupMeetingNotificationHandler()
    }

    deinit {
        if let observer = frontmostAppObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    // MARK: - Frontmost App Monitoring

    private func setupFrontmostAppMonitor() {
        frontmostAppObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleId = app.bundleIdentifier else { return }

            let appName = app.localizedName ?? bundleId
            Task { @MainActor [weak self] in
                self?.handleFrontmostAppChanged(bundleId: bundleId, appName: appName)
            }
        }
    }

    private func handleFrontmostAppChanged(bundleId: String, appName: String) {
        // Don't switch if we're the frontmost app
        guard bundleId != Bundle.main.bundleIdentifier else { return }

        // Don't switch during recording
        guard !isRecording else { return }

        // Avoid duplicate processing
        guard bundleId != lastFrontmostBundleId else { return }
        lastFrontmostBundleId = bundleId

        // Find matching context by specific app assignment
        if let context = settings.contexts.first(where: { $0.appAssignment.assignedAppIds.contains(bundleId) }) {
            if settings.activeContextId != context.id {
                settings.setActiveContext(context)
                updateMenuCheckmarks()
                print("🔄 Auto-switched to context '\(context.name)' for app: \(appName)")
            }
            return
        }

        // Find matching context by category
        let appCategory = detectAppCategory(bundleId: bundleId, appName: appName)
        if let context = settings.contexts.first(where: { $0.appAssignment.assignedCategories.contains(appCategory) }) {
            if settings.activeContextId != context.id {
                settings.setActiveContext(context)
                updateMenuCheckmarks()
                print("🔄 Auto-switched to context '\(context.name)' for category: \(appCategory.displayName)")
            }
            return
        }

        // Same for power modes
        if let powerMode = settings.powerModes.first(where: { $0.appAssignment.assignedAppIds.contains(bundleId) }) {
            if settings.activePowerModeId != powerMode.id {
                settings.setActivePowerMode(powerMode)
                updateMenuCheckmarks()
                print("🔄 Auto-switched to power mode '\(powerMode.name)' for app: \(appName)")
            }
            return
        }

        if let powerMode = settings.powerModes.first(where: { $0.appAssignment.assignedCategories.contains(appCategory) }) {
            if settings.activePowerModeId != powerMode.id {
                settings.setActivePowerMode(powerMode)
                updateMenuCheckmarks()
                print("🔄 Auto-switched to power mode '\(powerMode.name)' for category: \(appCategory.displayName)")
            }
        }
    }

    private func detectAppCategory(bundleId: String, appName: String) -> AppCategory {
        // Common app categorizations based on bundle ID patterns
        let lowercasedBundle = bundleId.lowercased()
        let lowercasedName = appName.lowercased()

        // Messaging apps
        if lowercasedBundle.contains("slack") || lowercasedBundle.contains("discord") ||
           lowercasedBundle.contains("telegram") || lowercasedBundle.contains("whatsapp") ||
           lowercasedBundle.contains("messages") || lowercasedBundle.contains("messenger") ||
           lowercasedBundle.contains("signal") || lowercasedBundle.contains("teams") {
            return .messaging
        }

        // Email apps
        if lowercasedBundle.contains("mail") || lowercasedBundle.contains("outlook") ||
           lowercasedBundle.contains("gmail") || lowercasedBundle.contains("spark") ||
           lowercasedBundle.contains("airmail") || lowercasedName.contains("mail") {
            return .email
        }

        // Social media
        if lowercasedBundle.contains("twitter") || lowercasedBundle.contains("facebook") ||
           lowercasedBundle.contains("instagram") || lowercasedBundle.contains("linkedin") ||
           lowercasedBundle.contains("tweetbot") || lowercasedBundle.contains("mastodon") {
            return .social
        }

        // Productivity/notes
        if lowercasedBundle.contains("notes") || lowercasedBundle.contains("notion") ||
           lowercasedBundle.contains("obsidian") || lowercasedBundle.contains("bear") ||
           lowercasedBundle.contains("evernote") || lowercasedBundle.contains("onenote") ||
           lowercasedBundle.contains("craft") || lowercasedBundle.contains("ulysses") {
            return .notes
        }

        // Development (categorize as work)
        if lowercasedBundle.contains("xcode") || lowercasedBundle.contains("vscode") ||
           lowercasedBundle.contains("sublime") || lowercasedBundle.contains("terminal") ||
           lowercasedBundle.contains("iterm") || lowercasedBundle.contains("jetbrains") ||
           lowercasedBundle.contains("android-studio") || lowercasedBundle.contains("cursor") {
            return .work
        }

        // Browsers
        if lowercasedBundle.contains("safari") || lowercasedBundle.contains("chrome") ||
           lowercasedBundle.contains("firefox") || lowercasedBundle.contains("edge") ||
           lowercasedBundle.contains("brave") || lowercasedBundle.contains("arc") {
            return .browser
        }

        // Office/documents
        if lowercasedBundle.contains("word") || lowercasedBundle.contains("excel") ||
           lowercasedBundle.contains("powerpoint") || lowercasedBundle.contains("pages") ||
           lowercasedBundle.contains("numbers") || lowercasedBundle.contains("keynote") ||
           lowercasedBundle.contains("docs.google") || lowercasedBundle.contains("sheets") {
            return .work
        }

        return .other
    }

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            // Use custom SwiftSpeakLogo icon
            if let icon = NSImage(named: "SwiftSpeakLogo") {
                icon.size = NSSize(width: 22, height: 22)
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

        // ==================== CONTEXT SECTION ====================
        let contextItem = NSMenuItem(title: "Context", action: nil, keyEquivalent: "")
        let contextSubmenu = NSMenu()

        // None option
        let noneContextItem = NSMenuItem(title: "None",
                                         action: #selector(selectContext(_:)),
                                         keyEquivalent: "")
        noneContextItem.target = self
        noneContextItem.representedObject = nil as ConversationContext?
        contextSubmenu.addItem(noneContextItem)
        contextSubmenu.addItem(.separator())

        // Preset contexts
        for context in ConversationContext.presets {
            let item = NSMenuItem(title: "\(context.icon) \(context.name)",
                                  action: #selector(selectContext(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = context
            contextSubmenu.addItem(item)
        }

        // Custom contexts
        let customContexts = settings.contexts.filter { !$0.isPreset }
        if !customContexts.isEmpty {
            contextSubmenu.addItem(.separator())
            for context in customContexts {
                let item = NSMenuItem(title: "\(context.icon) \(context.name)",
                                      action: #selector(selectContext(_:)),
                                      keyEquivalent: "")
                item.target = self
                item.representedObject = context
                contextSubmenu.addItem(item)
            }
        }

        contextItem.submenu = contextSubmenu
        menu?.addItem(contextItem)

        // ==================== POWER MODE SECTION ====================
        let powerModeItem = NSMenuItem(title: "Power Mode", action: nil, keyEquivalent: "")
        let powerModeSubmenu = NSMenu()

        // None option
        let nonePowerModeItem = NSMenuItem(title: "None",
                                           action: #selector(selectPowerMode(_:)),
                                           keyEquivalent: "")
        nonePowerModeItem.target = self
        nonePowerModeItem.representedObject = nil as PowerMode?
        powerModeSubmenu.addItem(nonePowerModeItem)

        if !settings.activePowerModes.isEmpty {
            powerModeSubmenu.addItem(.separator())
            for powerMode in settings.activePowerModes {
                let iconName = powerMode.icon
                let item = NSMenuItem(title: powerMode.name,
                                      action: #selector(selectPowerMode(_:)),
                                      keyEquivalent: "")
                item.target = self
                item.representedObject = powerMode
                item.image = NSImage(systemSymbolName: iconName, accessibilityDescription: powerMode.name)
                powerModeSubmenu.addItem(item)
            }
        }

        powerModeItem.submenu = powerModeSubmenu
        menu?.addItem(powerModeItem)

        menu?.addItem(.separator())

        // ==================== TRANSLATION SECTION ====================
        // Translate toggle
        let translateItem = NSMenuItem(title: "Translate",
                                       action: #selector(toggleTranslation),
                                       keyEquivalent: "")
        translateItem.target = self
        menu?.addItem(translateItem)

        // Language submenu for translation target
        let languageItem = NSMenuItem(title: "Target Language", action: nil, keyEquivalent: "")
        let languageSubmenu = NSMenu()
        for language in Language.allCases {
            let item = NSMenuItem(title: language.displayName,
                                  action: #selector(selectTargetLanguage(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = language
            languageSubmenu.addItem(item)
        }
        languageItem.submenu = languageSubmenu
        menu?.addItem(languageItem)

        menu?.addItem(.separator())

        // ==================== INPUT LANGUAGE SECTION ====================
        let inputLanguageItem = NSMenuItem(title: "Input Language", action: nil, keyEquivalent: "")
        let inputLanguageSubmenu = NSMenu()

        // Auto-detect option
        let autoDetectItem = NSMenuItem(title: "Auto-detect",
                                        action: #selector(selectInputLanguage(_:)),
                                        keyEquivalent: "")
        autoDetectItem.target = self
        autoDetectItem.representedObject = nil as Language?
        inputLanguageSubmenu.addItem(autoDetectItem)
        inputLanguageSubmenu.addItem(.separator())

        for language in Language.allCases {
            let item = NSMenuItem(title: language.displayName,
                                  action: #selector(selectInputLanguage(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = language
            inputLanguageSubmenu.addItem(item)
        }
        inputLanguageItem.submenu = inputLanguageSubmenu
        menu?.addItem(inputLanguageItem)

        menu?.addItem(.separator())

        // History
        let historyItem = NSMenuItem(title: "History...",
                                     action: #selector(openHistory),
                                     keyEquivalent: "h")
        historyItem.target = self
        menu?.addItem(historyItem)

        // Meeting Recording
        let meetingItem = NSMenuItem(title: "Meeting Recording...",
                                     action: #selector(openMeetingRecording),
                                     keyEquivalent: "m")
        meetingItem.target = self
        menu?.addItem(meetingItem)

        // Meeting History
        let meetingHistoryItem = NSMenuItem(title: "Meeting History...",
                                            action: #selector(openMeetingHistory),
                                            keyEquivalent: "M")
        meetingHistoryItem.target = self
        menu?.addItem(meetingHistoryItem)

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
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 280),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.animationBehavior = .none  // Disable animations to prevent crashes

        // Create wrapper view that observes the view model
        let wrapperView = OverlayWrapperView(
            audioRecorder: audioRecorder,
            viewModel: overlayViewModel,
            settings: settings,
            onStop: { [weak self] in
                Task { await self?.stopRecordingAndProcess() }
            },
            onCancel: { [weak self] in
                self?.cancelRecording()
            }
        )
        hostingView = NSHostingView(rootView: wrapperView)
        window.contentView = hostingView

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

        // Register global power mode hotkey if configured
        if let globalHotkey = settings.globalPowerModeHotkey {
            try? hotkeyManager.registerHotkey(globalHotkey, for: .openPowerModeOverlay)
        }

        // Re-register saved power mode hotkeys
        for (powerModeId, combination) in settings.powerModeHotkeys {
            hotkeyManager.registerPowerModeHotkey(
                powerModeId: powerModeId,
                keyCode: combination.keyCode,
                modifiers: combination.modifiers
            )
        }

        // Set handler - context is captured in the Carbon callback BEFORE async dispatch
        hotkeyManager.setHandler { [weak self] action, context in
            switch action {
            case .toggleRecording:
                self?.toggleRecording()
            case .cancelRecording:
                self?.cancelRecording()
            case .quickPaste:
                // Quick paste from clipboard
                break
            case .openPowerModeOverlay:
                // Open power mode selector overlay with captured context
                self?.openPowerModeOverlay(context: context)
            case .powerMode(let powerModeId):
                // Handle power mode activation with captured context
                self?.activatePowerMode(powerModeId, context: context)
            case .transcribeToggle:
                // Open transcribe overlay in toggle mode
                self?.openTranscribeOverlay(mode: .toggle, context: context)
            case .transcribePushToTalk:
                // Open transcribe overlay in push-to-talk mode
                self?.openTranscribeOverlay(mode: .pushToTalk, context: context)
            }
        }

        // Set key up handler for push-to-talk
        hotkeyManager.setKeyUpHandler { [weak self] action in
            if action == .transcribePushToTalk {
                self?.transcribeOverlayController?.onPushToTalkReleased()
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
        // Use the new Transcribe overlay instead of old Power Mode overlay
        openTranscribeOverlay(mode: .toggle, context: nil)
    }

    // MARK: - OBSOLETE Recording Methods (kept for reference)
    // TODO: Remove these after Transcribe overlay is fully verified

    @available(*, deprecated, message: "Use openTranscribeOverlay instead")
    private func _obsolete_toggleRecording() {
        if audioRecorder.isRecording {
            Task { await stopRecordingAndProcess() }
        } else {
            Task { await startRecording() }
        }
    }

    @objc private func toggleTranslation() {
        isTranslationEnabled.toggle()
        // Update menu item state
        if let item = menu?.item(withTitle: "Translate After Recording") {
            item.state = isTranslationEnabled ? .on : .off
        }
    }

    @objc private func selectTargetLanguage(_ sender: NSMenuItem) {
        if let language = sender.representedObject as? Language {
            targetLanguage = language
            // Update checkmarks in language menu
            if let languageMenu = menu?.item(withTitle: "Target Language")?.submenu {
                for item in languageMenu.items {
                    item.state = (item.representedObject as? Language) == language ? .on : .off
                }
            }
        }
    }

    @objc private func selectContext(_ sender: NSMenuItem) {
        if let context = sender.representedObject as? ConversationContext {
            settings.setActiveContext(context)
        } else {
            settings.setActiveContext(nil)
        }
        updateMenuCheckmarks()
    }

    @objc private func selectPowerMode(_ sender: NSMenuItem) {
        if let powerMode = sender.representedObject as? PowerMode {
            settings.setActivePowerMode(powerMode)
        } else {
            settings.setActivePowerMode(nil)
        }
        updateMenuCheckmarks()
    }

    @objc private func selectInputLanguage(_ sender: NSMenuItem) {
        if let language = sender.representedObject as? Language {
            settings.selectedDictationLanguage = language
        } else {
            settings.selectedDictationLanguage = nil
        }
        updateMenuCheckmarks()
    }

    private func updateMenuCheckmarks() {
        // Update context checkmarks
        if let contextSubmenu = menu?.item(withTitle: "Context")?.submenu {
            for item in contextSubmenu.items {
                if let context = item.representedObject as? ConversationContext {
                    item.state = settings.activeContextId == context.id ? .on : .off
                } else if item.title == "None" {
                    item.state = settings.activeContextId == nil ? .on : .off
                }
            }
        }

        // Update power mode checkmarks
        if let powerModeSubmenu = menu?.item(withTitle: "Power Mode")?.submenu {
            for item in powerModeSubmenu.items {
                if let powerMode = item.representedObject as? PowerMode {
                    item.state = settings.activePowerModeId == powerMode.id ? .on : .off
                } else if item.title == "None" {
                    item.state = settings.activePowerModeId == nil ? .on : .off
                }
            }
        }

        // Update input language checkmarks
        if let inputLangSubmenu = menu?.item(withTitle: "Input Language")?.submenu {
            for item in inputLangSubmenu.items {
                if let language = item.representedObject as? Language {
                    item.state = settings.selectedDictationLanguage == language ? .on : .off
                } else if item.title == "Auto-detect" {
                    item.state = settings.selectedDictationLanguage == nil ? .on : .off
                }
            }
        }

        // Update translation checkmark
        if let translateItem = menu?.item(withTitle: "Translate") {
            translateItem.state = isTranslationEnabled ? .on : .off
        }

        // Update target language checkmarks
        if let targetLangSubmenu = menu?.item(withTitle: "Target Language")?.submenu {
            for item in targetLangSubmenu.items {
                if let language = item.representedObject as? Language {
                    item.state = targetLanguage == language ? .on : .off
                }
            }
        }
    }

    @objc private func openHistory() {
        // If window already exists, just bring it to front
        if let existingWindow = transcriptionHistoryWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        NSApp.activate(ignoringOtherApps: true)

        let historyView = MacHistoryView(settings: MacSettings.shared)
        let hostingView = NSHostingView(rootView: historyView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Transcription History"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false  // Don't release on close
        window.makeKeyAndOrderFront(nil)

        // Retain the window
        transcriptionHistoryWindow = window
    }

    @objc private func openMeetingRecording() {
        // If window already exists, just bring it to front
        if let existingWindow = meetingRecordingWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        NSApp.activate(ignoringOtherApps: true)

        let meetingView = MacMeetingRecordingView()
            .environmentObject(MacSettings.shared)
        let hostingView = NSHostingView(rootView: meetingView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 550),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Meeting Recording"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false  // Don't release on close
        window.makeKeyAndOrderFront(nil)

        // Retain the window
        meetingRecordingWindow = window
    }

    @objc private func openMeetingHistory() {
        // If window already exists, just bring it to front
        if let existingWindow = meetingHistoryWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        NSApp.activate(ignoringOtherApps: true)

        let historyView = MacMeetingHistoryView(orchestrator: nil)
        let hostingView = NSHostingView(rootView: historyView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Meeting History"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false  // Don't release on close
        window.makeKeyAndOrderFront(nil)

        // Retain the window
        meetingHistoryWindow = window
    }

    // MARK: - Meeting Notifications

    private func setupMeetingNotificationHandler() {
        // Observe the notification manager for showing result window
        MeetingNotificationManager.shared.$showResultWindow
            .receive(on: DispatchQueue.main)
            .sink { [weak self] shouldShow in
                if shouldShow {
                    self?.showMeetingResultFromNotification()
                }
            }
            .store(in: &cancellables)
    }

    private func showMeetingResultFromNotification() {
        guard let record = MeetingNotificationManager.shared.pendingResult else {
            macLog("No pending meeting result to show", category: "Meeting", level: .error)
            return
        }

        NSApp.activate(ignoringOtherApps: true)

        let resultView = MacMeetingResultView(record: record) { [weak self] in
            MeetingNotificationManager.shared.clearPendingResult()
            self?.meetingResultWindow?.close()
        }
        let hostingView = NSHostingView(rootView: resultView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = record.title
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false  // Don't release on close
        window.makeKeyAndOrderFront(nil)

        // Retain the window
        meetingResultWindow = window

        // Clear the flag after showing
        MeetingNotificationManager.shared.showResultWindow = false

        macLog("Opened meeting result window from notification", category: "Meeting")
    }

    @objc private func openSettings() {
        // Use asyncAfter to ensure we're outside any active CA transaction
        // This avoids "Invalid attempt to open a new transaction during CA commit" crashes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            guard let self = self else { return }

            // Activate app and show settings
            NSApp.activate(ignoringOtherApps: true)

            // If window exists and is visible, just bring it to front
            if let existingWindow = self.settingsWindow, existingWindow.isVisible {
                existingWindow.makeKeyAndOrderFront(nil)
                return
            }

            // Create window if needed
            if self.settingsWindow == nil {
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
                    styleMask: [.titled, .closable, .miniaturizable, .resizable],
                    backing: .buffered,
                    defer: false
                )
                window.title = "SwiftSpeak Settings"
                window.minSize = NSSize(width: 750, height: 500)
                window.isReleasedWhenClosed = false  // Prevent dangling pointer
                window.delegate = self
                window.center()
                self.settingsWindow = window
            }

            // Create view after window exists
            let settingsView = MacSettingsView(settings: MacSettings.shared)
            let hostingView = NSHostingView(rootView: settingsView)

            self.settingsWindow?.contentView = hostingView
            self.settingsWindow?.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        Task { @MainActor in
            if window === self.settingsWindow {
                self.settingsWindow = nil
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - OBSOLETE Recording Flow (replaced by Transcribe overlay)
    // TODO: Remove after Transcribe overlay is fully verified

    @available(*, deprecated, message: "Use openTranscribeOverlay instead")
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

    @available(*, deprecated, message: "Use openTranscribeOverlay instead")
    public func stopRecordingAndProcess() async {
        isProcessing = true
        updateOverlayContent()

        do {
            let audioURL = try audioRecorder.stopRecording()

            // Get transcription via provider factory
            let transcriptionResult = try await transcribe(audioURL: audioURL)

            // Translate if enabled
            var finalResult = transcriptionResult
            if isTranslationEnabled {
                finalResult = try await translate(text: transcriptionResult, to: targetLanguage)
            }

            lastResult = finalResult

            // Insert text
            let insertResult = await textInsertion.insertText(finalResult, replaceSelection: true)

            switch insertResult {
            case .accessibilitySuccess:
                showNotification(title: "Text Inserted", body: "")
            case .clipboardFallback:
                showNotification(title: "Copied to Clipboard", body: "Press Cmd+V to paste")
            case .failed(let error):
                showNotification(title: "Insertion Failed", body: error.localizedDescription)
            }

            // Save to history
            saveToHistory(transcription: transcriptionResult, finalText: finalResult, wasTranslated: isTranslationEnabled)

        } catch {
            lastError = error.localizedDescription
            showNotification(title: "Transcription Failed", body: error.localizedDescription)
        }

        isProcessing = false
        hideOverlay()
    }

    @available(*, deprecated, message: "Use openTranscribeOverlay instead")
    public func cancelRecording() {
        audioRecorder.cancelRecording()
        hideOverlay()
    }

    /// Open the power mode overlay with selector to cycle through modes
    public func openPowerModeOverlay(context: HotkeyContext? = nil) {
        // Get first active power mode, or return if none
        guard let firstPowerMode = settings.activePowerModes.first else {
            print("No active power modes available")
            return
        }

        // Use last active power mode if set, otherwise use first
        let powerMode = settings.activePowerMode ?? firstPowerMode

        showPowerModeOverlay(for: powerMode, hotkeyContext: context)
    }

    /// Activate a specific power mode by ID
    public func activatePowerMode(_ powerModeId: UUID, context: HotkeyContext? = nil) {
        // Find the power mode
        guard let powerMode = settings.activePowerModes.first(where: { $0.id == powerModeId }) else {
            print("Power Mode not found: \(powerModeId)")
            return
        }

        showPowerModeOverlay(for: powerMode, hotkeyContext: context)
    }

    /// Open the transcribe overlay
    /// - Parameters:
    ///   - mode: Toggle or push-to-talk mode
    ///   - context: Pre-captured context from hotkey callback
    public func openTranscribeOverlay(mode: TranscribeMode, context: HotkeyContext? = nil) {
        // Create controller lazily
        if transcribeOverlayController == nil {
            transcribeOverlayController = MacTranscribeOverlayController(
                settings: settings,
                audioRecorder: audioRecorder
            )
            transcribeOverlayController?.setDependencies(
                providerFactory: providerFactory,
                textInsertion: textInsertion
            )
        }

        // Show overlay with captured context
        let capturedContext = context ?? HotkeyContext.empty
        transcribeOverlayController?.show(mode: mode, context: capturedContext)
    }

    /// Show the power mode overlay for a specific mode
    /// - Parameters:
    ///   - powerMode: The power mode to show
    ///   - hotkeyContext: Context captured in the Carbon callback (before any async dispatch)
    private func showPowerModeOverlay(for powerMode: PowerMode, hotkeyContext: HotkeyContext? = nil) {
        let inputConfig = powerMode.inputConfig

        // Use context from hotkey callback if available, otherwise capture now (fallback for menu clicks)
        let capturedPid: pid_t
        let capturedBundleId: String
        let capturedAppName: String
        let preCapturedClipboard: String?

        // DEBUG: Show what we received
        print("[SHOW OVERLAY] hotkeyContext: \(hotkeyContext != nil ? "present" : "nil")")
        if let ctx = hotkeyContext {
            print("[SHOW OVERLAY] hotkeyContext.pid: \(ctx.frontmostAppPid), app: \(ctx.frontmostAppName)")
        }

        if let context = hotkeyContext, context.frontmostAppPid > 0 {
            // Use context captured in Carbon callback (most reliable)
            capturedPid = context.frontmostAppPid
            capturedBundleId = context.frontmostAppBundleId
            capturedAppName = context.frontmostAppName
            preCapturedClipboard = inputConfig.includeClipboard ? context.clipboard : nil
            print("[SHOW OVERLAY] Using hotkey context: \(capturedAppName) (PID: \(capturedPid))")
        } else {
            // Fallback: capture now (for menu bar clicks, may capture our own app)
            let frontmostApp = NSWorkspace.shared.frontmostApplication
            capturedPid = frontmostApp?.processIdentifier ?? 0
            capturedBundleId = frontmostApp?.bundleIdentifier ?? ""
            capturedAppName = frontmostApp?.localizedName ?? capturedBundleId
            preCapturedClipboard = inputConfig.includeClipboard
                ? NSPasteboard.general.string(forType: .string)
                : nil
            print("[SHOW OVERLAY] Fallback capture: \(capturedAppName) (PID: \(capturedPid))")
        }

        // Use pre-captured context from hotkey callback (captured BEFORE async dispatch)
        var preCapturedWindowContext: WindowContext?

        if inputConfig.includeSelectedText || inputConfig.includeActiveAppText {
            if let context = hotkeyContext, context.frontmostAppPid > 0 {
                // Use selected text captured in the Carbon callback (most reliable!)
                preCapturedWindowContext = WindowContext(
                    appName: context.frontmostAppName,
                    appBundleId: context.frontmostAppBundleId,
                    windowTitle: context.windowTitle ?? "",
                    selectedText: inputConfig.includeSelectedText ? context.selectedText : nil,
                    visibleText: nil,  // Will be captured async if needed
                    capturedAt: Date()
                )
                print("[CAPTURE] Using hotkey context - selectedText: \(context.selectedText?.prefix(50) ?? "nil")")

                // Note: Window Text (Active App Text) is not reliably capturable because
                // accessibility APIs fail when the target app loses focus.
                // Selected Text via Cmd+C is the primary context capture method.
            } else {
                // Fallback: try to capture now (may fail if focus changed)
                Task { @MainActor in
                    if capturedPid > 0 && !capturedBundleId.isEmpty {
                        do {
                            let windowContext = try await windowContextService.captureWindowContext(
                                from: capturedPid,
                                bundleId: capturedBundleId,
                                appName: capturedAppName
                            )
                            print("[CAPTURE] Fallback success from \(capturedAppName)")
                            self.showOverlayWithContext(
                                powerMode: powerMode,
                                windowContext: windowContext,
                                clipboard: preCapturedClipboard
                            )
                        } catch {
                            print("[CAPTURE] Fallback failed: \(error)")
                            self.showOverlayWithContext(
                                powerMode: powerMode,
                                windowContext: nil,
                                clipboard: preCapturedClipboard
                            )
                        }
                    } else {
                        print("[CAPTURE] Invalid PID or bundleId")
                        self.showOverlayWithContext(
                            powerMode: powerMode,
                            windowContext: nil,
                            clipboard: preCapturedClipboard
                        )
                    }
                }
                return  // Early return, showOverlayWithContext called in Task
            }
        }

        // Show overlay with pre-captured context (synchronous path)
        showOverlayWithContext(
            powerMode: powerMode,
            windowContext: preCapturedWindowContext,
            clipboard: preCapturedClipboard
        )
    }

    /// Internal method to show overlay after context is captured
    private func showOverlayWithContext(powerMode: PowerMode, windowContext: WindowContext?, clipboard: String?) {
        // Create overlay controller lazily
        if powerModeOverlayController == nil {
            let obsidianService = MacObsidianQueryService(settings: settings)

            powerModeOverlayController = MacPowerModeOverlayController(
                settings: settings,
                windowContextService: windowContextService,
                audioRecorder: audioRecorder,
                providerFactory: providerFactory,
                obsidianQueryService: obsidianService,
                textInsertion: textInsertion
            )
        }

        // Update the active power mode
        settings.setActivePowerMode(powerMode)

        // Show overlay with pre-captured context
        powerModeOverlayController?.showOverlay(
            for: powerMode,
            windowContext: windowContext,
            clipboard: clipboard
        )
    }

    // MARK: - Transcription & Translation

    private func transcribe(audioURL: URL) async throws -> String {
        // Use ProviderFactory to create the appropriate transcription provider
        let providerFactory = ProviderFactory(settings: settings)
        let provider = settings.selectedTranscriptionProvider

        guard let transcriptionService = providerFactory.createTranscriptionProvider(for: provider) else {
            throw TranscriptionError.apiKeyMissing
        }

        // Build vocabulary prompt from settings and active context
        let vocabularyPrompt = buildVocabularyPrompt()

        // Pass the selected dictation language and vocabulary hints
        return try await transcriptionService.transcribe(
            audioURL: audioURL,
            language: settings.selectedDictationLanguage,
            promptHint: vocabularyPrompt
        )
    }

    /// Build vocabulary prompt for transcription from vocabulary entries and active context
    /// This helps the transcription provider recognize domain-specific terms
    private func buildVocabularyPrompt() -> String? {
        var vocabWords: [String] = []

        // Add vocabulary replacement words (target words that should be recognized)
        vocabWords.append(contentsOf: settings.vocabulary
            .filter { $0.isEnabled }
            .map { $0.replacementWord }
        )

        // Add domain jargon from active context
        if let context = settings.activeContext {
            // Add domain-specific vocabulary hints
            vocabWords.append(contentsOf: context.transcriptionVocabulary)
        }

        // Return nil if no vocabulary, otherwise comma-separated list
        guard !vocabWords.isEmpty else { return nil }

        // Remove duplicates and join
        let uniqueWords = Array(Set(vocabWords))
        return uniqueWords.joined(separator: ", ")
    }

    private func translate(text: String, to targetLanguage: Language) async throws -> String {
        // Use ProviderFactory to create the translation provider
        let providerFactory = ProviderFactory(settings: settings)

        guard let translationService = providerFactory.createSelectedTranslationProvider() else {
            throw TranscriptionError.apiKeyMissing
        }

        return try await translationService.translate(text: text, from: settings.selectedDictationLanguage, to: targetLanguage)
    }

    private func saveToHistory(transcription: String, finalText: String, wasTranslated: Bool) {
        let record = TranscriptionRecord(
            rawTranscribedText: transcription,
            text: finalText,
            mode: .raw,  // macOS uses translation, not formatting modes
            provider: settings.selectedTranscriptionProvider,
            duration: audioRecorder.duration,
            translated: wasTranslated,
            targetLanguage: wasTranslated ? settings.selectedTargetLanguage : nil
        )
        settings.addToHistory(record)
    }

    // MARK: - OBSOLETE UI Helpers (Power Mode overlay - replaced by Transcribe overlay)
    // TODO: Remove after Transcribe overlay is fully verified

    @available(*, deprecated, message: "Use openTranscribeOverlay instead")
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

        // Show toggle circles when overlay appears
        overlayViewModel.showToggleCircles = true

        updateOverlayContent()
        window.makeKeyAndOrderFront(nil)
        isOverlayVisible = true

        // Start keyboard monitoring
        startLocalKeyboardMonitor()
    }

    public func hideOverlay() {
        // Stop keyboard monitoring
        stopLocalKeyboardMonitor()

        overlayViewModel.showToggleCircles = false
        floatingWindow?.orderOut(nil)
        isOverlayVisible = false
    }

    // MARK: - Local Keyboard Monitoring

    private func startLocalKeyboardMonitor() {
        // Monitor keyboard events while recording
        localKeyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isOverlayVisible else { return event }

            switch event.keyCode {
            case 17: // T key - Toggle translation
                self.overlayViewModel.isTranslationEnabled.toggle()
                self.isTranslationEnabled = self.overlayViewModel.isTranslationEnabled
                return nil

            case 8: // C key - Cycle context
                self.cycleContext()
                return nil

            case 35: // P key - Cycle power mode
                self.cyclePowerMode()
                return nil

            case 49: // Space - Finish recording
                if self.audioRecorder.isRecording && !self.isProcessing {
                    Task { await self.stopRecordingAndProcess() }
                }
                return nil

            case 36: // Return/Enter - Finish recording
                if self.audioRecorder.isRecording && !self.isProcessing {
                    Task { await self.stopRecordingAndProcess() }
                }
                return nil

            case 53: // Escape - Cancel recording
                if self.audioRecorder.isRecording {
                    self.cancelRecording()
                }
                return nil

            default:
                return event
            }
        }
    }

    private func stopLocalKeyboardMonitor() {
        if let monitor = localKeyboardMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyboardMonitor = nil
        }
    }

    private func cycleContext() {
        let contexts = settings.contexts
        if let current = settings.activeContext,
           let index = contexts.firstIndex(where: { $0.id == current.id }) {
            let nextIndex = (index + 1) % (contexts.count + 1) // +1 to include "none"
            if nextIndex < contexts.count {
                settings.setActiveContext(contexts[nextIndex])
            } else {
                settings.setActiveContext(nil) // Back to none
            }
        } else if let first = contexts.first {
            settings.setActiveContext(first)
        }
    }

    private func cyclePowerMode() {
        let modes = settings.activePowerModes
        if let current = settings.activePowerMode,
           let index = modes.firstIndex(where: { $0.id == current.id }) {
            if index + 1 < modes.count {
                settings.setActivePowerMode(modes[index + 1])
            } else {
                settings.setActivePowerMode(nil) // Turn off
            }
        } else if let first = modes.first {
            settings.setActivePowerMode(first)
        }
    }

    private func updateOverlayContent() {
        // No longer recreates view - OverlayViewModel updates trigger SwiftUI reactivity
        // This method is kept for compatibility but view updates happen automatically
    }

    private func updateStatusIcon(isRecording: Bool) {
        if let button = statusItem?.button {
            // Use custom SwiftSpeakLogo icon
            if let icon = NSImage(named: "SwiftSpeakLogo") {
                icon.size = NSSize(width: 22, height: 22)
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

// MARK: - Settings Section Enum

enum SettingsSection: String, CaseIterable, Identifiable {
    // Main categories (match iOS)
    case voiceLanguage = "Voice & Language"
    case transcription = "Transcription & AI"
    case personalization = "Personalization"
    case behavior = "Behavior"
    case security = "Security & Privacy"
    case usage = "Usage & Costs"
    case vaults = "Vaults"
    // macOS-specific
    case hotkeys = "Hotkeys"
    case logs = "Logs"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .voiceLanguage: return "waveform"
        case .transcription: return "cpu"
        case .personalization: return "person.fill"
        case .behavior: return "bolt.fill"
        case .security: return "lock.shield.fill"
        case .usage: return "chart.pie.fill"
        case .vaults: return "seal.fill"
        case .hotkeys: return "keyboard"
        case .logs: return "doc.text"
        case .about: return "info.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .voiceLanguage: return .blue
        case .transcription: return .purple
        case .personalization: return .orange
        case .behavior: return .yellow
        case .security: return .green
        case .usage: return .mint
        case .vaults: return .purple
        case .hotkeys: return .gray
        case .logs: return .cyan
        case .about: return .blue
        }
    }
}

// MARK: - Settings View (macOS Sidebar Style)

struct MacSettingsView: View {
    @ObservedObject var settings: MacSettings
    @State private var selectedSection: SettingsSection = .voiceLanguage

    var body: some View {
        NavigationSplitView {
            // Sidebar with header inside list
            List(selection: $selectedSection) {
                // App Header
                Section {
                    VStack(spacing: 6) {
                        if let logo = NSImage(named: "SwiftSpeakLogo") {
                            Image(nsImage: logo)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                        } else {
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.purple)
                        }
                        Text("SwiftSpeak")
                            .font(.headline)
                        Text("v1.0.0")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                // Main settings (matches iOS)
                Section {
                    ForEach([SettingsSection.voiceLanguage, .transcription, .personalization, .behavior, .security, .usage, .vaults], id: \.self) { section in
                        SidebarRow(section: section, settings: settings)
                            .tag(section)
                    }
                }

                // macOS-specific
                Section("macOS") {
                    ForEach([SettingsSection.hotkeys, .logs], id: \.self) { section in
                        SidebarRow(section: section, settings: settings)
                            .tag(section)
                    }
                }

                // About
                Section {
                    SidebarRow(section: .about, settings: settings)
                        .tag(SettingsSection.about)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200)
        } detail: {
            // Detail View
            Group {
                switch selectedSection {
                case .voiceLanguage:
                    GeneralSettingsTab(settings: settings)
                case .transcription:
                    ProvidersSettingsTab(settings: settings)
                case .personalization:
                    MacPersonalizationView(settings: settings)
                case .behavior:
                    MacBehaviorView(settings: settings)
                case .security:
                    MacSecurityPrivacyView(settings: settings)
                case .usage:
                    MacCostAnalyticsView(settings: settings)
                case .vaults:
                    MacVaultsSettingsView(settings: settings)
                case .hotkeys:
                    HotkeySettingsTab()
                case .logs:
                    MacLocalLogViewer()
                case .about:
                    AboutSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 800, minHeight: 550)
        .toolbar(.hidden, for: .windowToolbar)
    }
}

// MARK: - Sidebar Row

struct SidebarRow: View {
    let section: SettingsSection
    let settings: MacSettings

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(section.iconColor.gradient)
                    .frame(width: 24, height: 24)
                if section == .vaults {
                    Image("ObsidianIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: section.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(section.rawValue)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var subtitle: String {
        switch section {
        case .voiceLanguage:
            return settings.selectedDictationLanguage?.displayName ?? "Auto-detect"
        case .transcription:
            let count = settings.configuredAIProviders.count
            return count > 0 ? "\(count) provider\(count == 1 ? "" : "s")" : "Configure"
        case .personalization:
            let contextCount = settings.contexts.count
            return contextCount > 0 ? "\(contextCount) context\(contextCount == 1 ? "" : "s")" : "Contexts, memory"
        case .behavior:
            let powerModeCount = settings.activePowerModes.count
            return powerModeCount > 0 ? "\(powerModeCount) Power Mode\(powerModeCount == 1 ? "" : "s") active" : "Power Modes, streaming"
        case .security:
            return "Biometrics, data retention"
        case .usage:
            return "Statistics"
        case .vaults:
            let count = ObsidianVaultManager.shared.vaults.count
            return count > 0 ? "\(count) vault\(count == 1 ? "" : "s")" : "None"
        case .hotkeys:
            return "Shortcuts"
        case .logs:
            return "View app logs"
        case .about:
            return "v1.0.0"
        }
    }
}

// MARK: - About Settings View

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Logo
            if let logo = NSImage(named: "SwiftSpeakLogo") {
                Image(nsImage: logo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
            } else {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.purple)
            }

            // App Name & Version
            VStack(spacing: 4) {
                Text("SwiftSpeak")
                    .font(.largeTitle.weight(.semibold))
                Text("Version 1.0.0 (Build 1)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Description
            Text("Voice transcription with AI formatting")
                .font(.body)
                .foregroundStyle(.secondary)

            // Links
            HStack(spacing: 20) {
                Link("Website", destination: URL(string: "https://swiftspeak.app")!)
                Link("Privacy Policy", destination: URL(string: "https://swiftspeak.app/privacy")!)
                Link("Terms of Service", destination: URL(string: "https://swiftspeak.app/terms")!)
            }
            .font(.callout)

            Spacer()

            // Copyright
            Text("© 2025 SwiftSpeak. All rights reserved.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ProvidersSettingsTab: View {
    @ObservedObject var settings: MacSettings
    @State private var providerToAdd: AIProvider?
    @State private var editingConfig: AIProviderConfig?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Providers")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Configure cloud AI services for transcription, translation, and formatting")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: { providerToAdd = settings.availableProvidersToAdd.first ?? .openAI }) {
                        Label("Add Provider", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(settings.availableProvidersToAdd.isEmpty)
                }
                .padding(.bottom, 8)

                // Configured Providers
                VStack(alignment: .leading, spacing: 12) {
                    Text("Configured")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    if settings.configuredAIProviders.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.15))
                                        .frame(width: 60, height: 60)
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(.orange)
                                }
                                Text("No providers configured")
                                    .font(.headline)
                                Text("Add an AI provider to enable transcription and translation")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                Button("Add Provider") {
                                    providerToAdd = settings.availableProvidersToAdd.first ?? .openAI
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 32)
                            Spacer()
                        }
                        .background(Color.primary.opacity(0.02))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        ForEach(settings.configuredAIProviders, id: \.provider) { config in
                            ProviderConfigCard(
                                config: config,
                                onEdit: { editingConfig = config },
                                onDelete: { settings.removeAIProvider(config.provider) }
                            )
                        }
                    }
                }

                // Default Provider Selection
                if !settings.configuredAIProviders.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Default Selection")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        VStack(spacing: 0) {
                            // Transcription
                            if !settings.transcriptionProviders.isEmpty {
                                DefaultProviderRow(
                                    title: "Transcription",
                                    icon: "mic.fill",
                                    color: .blue,
                                    description: "Speech-to-text conversion",
                                    selection: $settings.selectedTranscriptionProvider,
                                    options: settings.transcriptionProviders.map { $0.provider }
                                )
                            }

                            Divider().padding(.horizontal, 12)

                            // Translation
                            if !settings.translationProviders.isEmpty {
                                DefaultProviderRow(
                                    title: "Translation",
                                    icon: "globe",
                                    color: .purple,
                                    description: "Text translation between languages",
                                    selection: $settings.selectedTranslationProvider,
                                    options: settings.translationProviders.map { $0.provider }
                                )
                            }

                            Divider().padding(.horizontal, 12)

                            // Power Mode
                            if !settings.powerModeProviders.isEmpty {
                                DefaultProviderRow(
                                    title: "Power Mode",
                                    icon: "bolt.fill",
                                    color: .orange,
                                    description: "AI formatting and processing",
                                    selection: $settings.selectedPowerModeProvider,
                                    options: settings.powerModeProviders.map { $0.provider }
                                )
                            }
                        }
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                // Available Providers (not yet added)
                if !settings.availableProvidersToAdd.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Available")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(settings.availableProvidersToAdd, id: \.self) { provider in
                                AvailableProviderCard(provider: provider) {
                                    providerToAdd = provider
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .sheet(item: $providerToAdd) { provider in
            AddProviderSheet(settings: settings, initialProvider: provider)
        }
        .sheet(item: $editingConfig) { config in
            EditProviderSheet(settings: settings, config: config)
        }
    }
}

// MARK: - Provider Config Card

private struct ProviderConfigCard: View {
    let config: AIProviderConfig
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var showingDeleteConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            // Provider icon
            MacProviderIcon(config.provider, size: .large, style: .filled)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(config.provider.displayName)
                        .font(.headline)

                    // Status indicator
                    Circle()
                        .fill(config.isConfigured ? .green : .orange)
                        .frame(width: 8, height: 8)

                    if !config.isConfigured {
                        Text("API key missing")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                // Capabilities
                HStack(spacing: 6) {
                    ForEach(config.provider.capabilities, id: \.self) { capability in
                        Text(capability)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(capabilityColor(capability).opacity(0.15))
                            .foregroundStyle(capabilityColor(capability))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                Button("Edit", action: onEdit)
                    .buttonStyle(.bordered)

                Button(action: { showingDeleteConfirm = true }) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .alert("Remove Provider?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive, action: onDelete)
        } message: {
            Text("This will remove \(config.provider.displayName) from your configured providers.")
        }
    }

    private func capabilityColor(_ capability: String) -> Color {
        switch capability {
        case "Transcription": return .blue
        case "Translation": return .purple
        case "Power Mode": return .orange
        default: return .gray
        }
    }
}

// MARK: - Default Provider Row

private struct DefaultProviderRow: View {
    let title: String
    let icon: String
    let color: Color
    let description: String
    @Binding var selection: AIProvider
    let options: [AIProvider]

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundStyle(color)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Picker
            Menu {
                ForEach(options, id: \.self) { provider in
                    Button(action: { selection = provider }) {
                        HStack {
                            Text(provider.displayName)
                            if selection == provider {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    MacProviderIcon(selection, size: .small, style: .filled)
                    Text(selection.shortName)
                        .font(.callout)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
    }
}

// MARK: - Available Provider Card

private struct AvailableProviderCard: View {
    let provider: AIProvider
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            VStack(spacing: 8) {
                MacProviderIcon(provider, size: .large, style: .outline)
                Text(provider.displayName)
                    .font(.callout.weight(.medium))
                Text(provider.pricingInfo)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color.primary.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct AddProviderSheet: View {
    @ObservedObject var settings: MacSettings
    let initialProvider: AIProvider
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProvider: AIProvider?
    @State private var apiKey = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Add AI Provider")
                .font(.title2)
                .fontWeight(.bold)

            if settings.availableProvidersToAdd.isEmpty {
                Text("All providers have been added.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Provider")
                        .font(.headline)

                    ForEach(settings.availableProvidersToAdd, id: \.self) { provider in
                        Button(action: { selectedProvider = provider }) {
                            HStack {
                                Image(systemName: provider.icon)
                                    .frame(width: 24)
                                Text(provider.displayName)
                                Spacer()
                                if selectedProvider == provider {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                    }
                }

                if let provider = selectedProvider, provider.requiresAPIKey {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.headline)
                        TextField("Enter your \(provider.displayName) API key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                        if let helpURL = provider.apiKeyHelpURL {
                            Link("Get API Key", destination: helpURL)
                                .font(.caption)
                        }
                    }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Add Provider") {
                    if let provider = selectedProvider {
                        let config = AIProviderConfig(provider: provider, apiKey: apiKey)
                        settings.addAIProvider(config)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedProvider == nil || (selectedProvider?.requiresAPIKey == true && apiKey.isEmpty))
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            selectedProvider = initialProvider
        }
    }
}

struct EditProviderSheet: View {
    @ObservedObject var settings: MacSettings
    let config: AIProviderConfig
    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var apiKey: String = ""
    @State private var usageCategories: Set<ProviderUsageCategory> = []
    @State private var transcriptionModel: String = ""
    @State private var translationModel: String = ""
    @State private var powerModeModel: String = ""

    // Validation state
    @State private var isValidating = false
    @State private var isValidated = false
    @State private var validationError: String?
    @State private var refreshedSTTModels: [String]?
    @State private var refreshedLLMModels: [String]?

    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                MacProviderIcon(config.provider, size: .large, style: .filled)
                VStack(alignment: .leading, spacing: 2) {
                    Text(config.provider.displayName)
                        .font(.title2.weight(.semibold))
                    Text(config.provider.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // API Key Section
                    if config.provider.requiresAPIKey {
                        apiKeySection
                    }

                    // Capabilities Section (only show after validation)
                    if isValidated || !config.provider.requiresAPIKey {
                        capabilitiesSection
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                Button("Remove", role: .destructive) {
                    showDeleteConfirm = true
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)

                Button("Save") {
                    saveProvider()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(20)
        }
        .frame(width: 500, height: 600)
        .onAppear { loadConfig() }
        .alert("Remove Provider?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                settings.removeAIProvider(config.provider)
                dismiss()
            }
        } message: {
            Text("This will remove \(config.provider.displayName) from your configured providers.")
        }
    }

    // MARK: - API Key Section

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API Key")
                .font(.headline)

            HStack {
                SecureField("Enter your API key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                if isValidated {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            // Setup instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("How to get your API key:")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(config.provider.setupInstructions)
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                if let helpURL = config.provider.apiKeyHelpURL {
                    Link(destination: helpURL) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                            Text("Open \(config.provider.shortName) Dashboard")
                        }
                        .font(.caption.weight(.medium))
                    }
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Validate button
            Button(action: validateAPIKey) {
                HStack {
                    if isValidating {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: isValidated ? "checkmark.shield.fill" : "checkmark.shield")
                            .foregroundStyle(isValidated ? .green : .primary)
                    }
                    Text(isValidated ? "API Key Validated" : "Validate API Key")
                        .foregroundStyle(isValidated ? .green : .primary)
                }
            }
            .buttonStyle(.bordered)
            .disabled(isValidating || apiKey.isEmpty)

            // Validation error
            if let error = validationError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Capabilities Section

    private var capabilitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Capabilities & Models")
                .font(.headline)

            Text("Enable the capabilities you want to use and select the model for each.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(ProviderUsageCategory.allCases) { category in
                if config.provider.supportedCategories.contains(category) {
                    categoryRow(for: category)
                }
            }
        }
    }

    private func categoryRow(for category: ProviderUsageCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Toggle row
            Button(action: {
                if usageCategories.contains(category) {
                    usageCategories.remove(category)
                } else {
                    usageCategories.insert(category)
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: category.icon)
                        .font(.body)
                        .foregroundStyle(category.color)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.displayName)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(category.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: usageCategories.contains(category) ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(usageCategories.contains(category) ? category.color : Color.secondary.opacity(0.3))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Model picker (if enabled)
            if usageCategories.contains(category) {
                Picker("Model", selection: modelBinding(for: category)) {
                    ForEach(availableModels(for: category), id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .padding(.leading, 36)
            }
        }
        .padding(12)
        .background(usageCategories.contains(category) ? category.color.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(usageCategories.contains(category) ? category.color.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private var canSave: Bool {
        if config.provider.requiresAPIKey && apiKey.isEmpty {
            return false
        }
        return !usageCategories.isEmpty
    }

    private func modelBinding(for category: ProviderUsageCategory) -> Binding<String> {
        switch category {
        case .transcription: return $transcriptionModel
        case .translation: return $translationModel
        case .powerMode: return $powerModeModel
        }
    }

    private func availableModels(for category: ProviderUsageCategory) -> [String] {
        switch category {
        case .transcription:
            return refreshedSTTModels ?? config.provider.availableSTTModels
        case .translation, .powerMode:
            return refreshedLLMModels ?? config.provider.availableLLMModels
        }
    }

    private func loadConfig() {
        apiKey = config.apiKey
        usageCategories = config.usageCategories
        transcriptionModel = config.transcriptionModel ?? config.provider.defaultSTTModel ?? ""
        translationModel = config.translationModel ?? config.provider.defaultLLMModel ?? ""
        powerModeModel = config.powerModeModel ?? config.provider.defaultLLMModel ?? ""

        // If already has API key, mark as validated
        if !apiKey.isEmpty {
            isValidated = true
        }
    }

    private func saveProvider() {
        var updatedConfig = config
        updatedConfig.apiKey = apiKey
        updatedConfig.usageCategories = usageCategories
        updatedConfig.transcriptionModel = usageCategories.contains(.transcription) ? transcriptionModel : nil
        updatedConfig.translationModel = usageCategories.contains(.translation) ? translationModel : nil
        updatedConfig.powerModeModel = usageCategories.contains(.powerMode) ? powerModeModel : nil
        settings.updateAIProvider(updatedConfig)
        dismiss()
    }

    private func validateAPIKey() {
        isValidating = true
        validationError = nil

        Task {
            do {
                let (sttModels, llmModels) = try await fetchModelsFromAPI()

                await MainActor.run {
                    refreshedSTTModels = sttModels.isEmpty ? nil : sttModels
                    refreshedLLMModels = llmModels.isEmpty ? nil : llmModels
                    isValidated = true
                    isValidating = false

                    // Auto-select first model if none selected
                    if transcriptionModel.isEmpty, let first = (refreshedSTTModels ?? config.provider.availableSTTModels).first {
                        transcriptionModel = first
                    }
                    if translationModel.isEmpty, let first = (refreshedLLMModels ?? config.provider.availableLLMModels).first {
                        translationModel = first
                    }
                    if powerModeModel.isEmpty, let first = (refreshedLLMModels ?? config.provider.availableLLMModels).first {
                        powerModeModel = first
                    }
                }
            } catch {
                await MainActor.run {
                    validationError = error.localizedDescription
                    isValidating = false
                }
            }
        }
    }

    private func fetchModelsFromAPI() async throws -> (sttModels: [String], llmModels: [String]) {
        switch config.provider {
        case .openAI:
            return try await fetchOpenAIModels()
        case .anthropic:
            return try await fetchAnthropicModels()
        case .google:
            return try await fetchGoogleModels()
        case .deepgram:
            return try await fetchDeepgramModels()
        case .assemblyAI:
            // AssemblyAI has fixed models (no API endpoint to list them)
            // Validate API key works, then return known models
            try await validateAssemblyAIKey()
            return (["best", "nano"], [])
        case .elevenLabs:
            return try await fetchElevenLabsModels()
        default:
            // For other providers, just validate the key works
            return (config.provider.availableSTTModels, config.provider.availableLLMModels)
        }
    }

    private func fetchOpenAIModels() async throws -> (sttModels: [String], llmModels: [String]) {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OpenAI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw NSError(domain: "OpenAI", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid API key"])
            }
            throw NSError(domain: "OpenAI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API error: \(httpResponse.statusCode)"])
        }

        struct ModelsResponse: Codable {
            struct Model: Codable { let id: String }
            let data: [Model]
        }

        let modelsResponse = try JSONDecoder().decode(ModelsResponse.self, from: data)
        let allModels = modelsResponse.data.map { $0.id }

        // Filter STT models
        var sttModels = allModels.filter { $0.contains("whisper") || $0.contains("transcribe") }.sorted()
        // Add expected streaming models if not returned by API
        for model in ["gpt-4o-transcribe", "gpt-4o-mini-transcribe"] {
            if !sttModels.contains(model) {
                sttModels.insert(model, at: 0)
            }
        }

        // Filter LLM models
        let llmModels = allModels.filter {
            ($0.hasPrefix("gpt-") || $0.hasPrefix("o1") || $0.hasPrefix("o3") || $0.hasPrefix("chatgpt-")) &&
            !$0.contains("transcribe")
        }.sorted().reversed().map { String($0) }

        return (sttModels, Array(llmModels))
    }

    private func fetchGoogleModels() async throws -> (sttModels: [String], llmModels: [String]) {
        let request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1/models?key=\(apiKey)")!)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Google", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
                throw NSError(domain: "Google", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid API key"])
            }
            throw NSError(domain: "Google", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API error: \(httpResponse.statusCode)"])
        }

        struct ModelsResponse: Codable {
            struct Model: Codable { let name: String }
            let models: [Model]
        }

        let modelsResponse = try JSONDecoder().decode(ModelsResponse.self, from: data)
        let allModels = modelsResponse.models.map { $0.name.replacingOccurrences(of: "models/", with: "") }
        let llmModels = allModels.filter { $0.contains("gemini") }

        return ([], llmModels)
    }

    private func fetchAnthropicModels() async throws -> (sttModels: [String], llmModels: [String]) {
        // Anthropic models endpoint
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models")!)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Anthropic", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw NSError(domain: "Anthropic", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid API key"])
            }
            // Fallback to hardcoded models if endpoint not available
            return ([], config.provider.availableLLMModels)
        }

        struct ModelsResponse: Codable {
            struct Model: Codable { let id: String }
            let data: [Model]
        }

        let modelsResponse = try JSONDecoder().decode(ModelsResponse.self, from: data)
        let llmModels = modelsResponse.data.map { $0.id }.sorted().reversed().map { String($0) }

        return ([], Array(llmModels))
    }

    private func fetchDeepgramModels() async throws -> (sttModels: [String], llmModels: [String]) {
        var request = URLRequest(url: URL(string: "https://api.deepgram.com/v1/models")!)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Deepgram", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw NSError(domain: "Deepgram", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid API key"])
            }
            throw NSError(domain: "Deepgram", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API error: \(httpResponse.statusCode)"])
        }

        struct ModelsResponse: Codable {
            struct Model: Codable {
                let name: String
                let version: String?
            }
            let stt: [Model]?
        }

        let modelsResponse = try JSONDecoder().decode(ModelsResponse.self, from: data)
        let sttModels = modelsResponse.stt?.map { $0.name } ?? ["nova-2", "nova", "enhanced", "base"]

        return (sttModels, [])
    }

    private func validateAssemblyAIKey() async throws {
        // Validate key by making a simple API call
        var request = URLRequest(url: URL(string: "https://api.assemblyai.com/v2/transcript")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Send minimal body to check auth (will fail with bad request, but auth is checked first)
        request.httpBody = "{}".data(using: .utf8)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AssemblyAI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        // 401 means bad key, 400 means key is valid but request is bad (expected)
        if httpResponse.statusCode == 401 {
            throw NSError(domain: "AssemblyAI", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid API key"])
        }
        // Any other response (including 400) means key is valid
    }

    private func fetchElevenLabsModels() async throws -> (sttModels: [String], llmModels: [String]) {
        var request = URLRequest(url: URL(string: "https://api.elevenlabs.io/v1/models")!)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ElevenLabs", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw NSError(domain: "ElevenLabs", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid API key"])
            }
            throw NSError(domain: "ElevenLabs", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API error: \(httpResponse.statusCode)"])
        }

        struct Model: Codable {
            let model_id: String
            let name: String
            let can_do_text_to_speech: Bool?
            let can_be_finetuned: Bool?
        }

        let models = try JSONDecoder().decode([Model].self, from: data)
        // ElevenLabs has STT model(s) - scribe_v1
        let sttModels = ["scribe_v1"]  // ElevenLabs STT is Scribe

        return (sttModels, [])
    }
}

struct GeneralSettingsTab: View {
    @ObservedObject var settings: MacSettings

    var body: some View {
        Form {
            Section("Dictation Language") {
                Picker("Language", selection: Binding(
                    get: { settings.selectedDictationLanguage ?? .english },
                    set: { settings.selectedDictationLanguage = $0 }
                )) {
                    ForEach(Language.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }

                Toggle("Auto-detect language", isOn: Binding(
                    get: { settings.selectedDictationLanguage == nil },
                    set: { if $0 { settings.selectedDictationLanguage = nil } else { settings.selectedDictationLanguage = .english } }
                ))
                .help("When enabled, Whisper will automatically detect the spoken language. Disable for more accurate transcription.")
            }

            Section("Default Mode") {
                Picker("Mode", selection: $settings.selectedMode) {
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
    @ObservedObject private var hotkeyManager = MacHotkeyManager.shared
    @ObservedObject private var settings = MacSettings.shared
    @State private var recordingAction: HotkeyAction?
    @State private var showConflictAlert = false
    @State private var conflictMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Keyboard Shortcuts")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Configure global hotkeys to control SwiftSpeak from any application")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)

                // Basic Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Basic Actions")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 0) {
                        HotkeyRow(
                            action: .toggleRecording,
                            title: "Toggle Recording",
                            description: "Start or stop voice recording",
                            icon: "mic.fill",
                            color: .red,
                            currentCombination: hotkeyManager.registeredHotkeys[.toggleRecording],
                            isRecording: recordingAction == .toggleRecording,
                            onStartRecording: { recordingAction = .toggleRecording },
                            onClear: { hotkeyManager.unregisterHotkey(for: .toggleRecording) }
                        )

                        Divider().padding(.horizontal, 12)

                        HotkeyRow(
                            action: .cancelRecording,
                            title: "Cancel Recording",
                            description: "Cancel current recording without transcribing",
                            icon: "xmark.circle.fill",
                            color: .orange,
                            currentCombination: hotkeyManager.registeredHotkeys[.cancelRecording],
                            isRecording: recordingAction == .cancelRecording,
                            onStartRecording: { recordingAction = .cancelRecording },
                            onClear: { hotkeyManager.unregisterHotkey(for: .cancelRecording) }
                        )

                        Divider().padding(.horizontal, 12)

                        HotkeyRow(
                            action: .quickPaste,
                            title: "Quick Paste",
                            description: "Paste last transcription result",
                            icon: "doc.on.clipboard.fill",
                            color: .blue,
                            currentCombination: hotkeyManager.registeredHotkeys[.quickPaste],
                            isRecording: recordingAction == .quickPaste,
                            onStartRecording: { recordingAction = .quickPaste },
                            onClear: { hotkeyManager.unregisterHotkey(for: .quickPaste) }
                        )
                    }
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Global Power Mode Shortcut
                VStack(alignment: .leading, spacing: 12) {
                    Text("Power Mode")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 0) {
                        HotkeyRow(
                            action: .openPowerModeOverlay,
                            title: "Open Power Mode Overlay",
                            description: "Opens the Power Mode overlay - cycle modes with arrow keys",
                            icon: "bolt.fill",
                            color: .purple,
                            currentCombination: hotkeyManager.registeredHotkeys[.openPowerModeOverlay],
                            isRecording: recordingAction == .openPowerModeOverlay,
                            onStartRecording: { recordingAction = .openPowerModeOverlay },
                            onClear: {
                                hotkeyManager.unregisterHotkey(for: .openPowerModeOverlay)
                                settings.globalPowerModeHotkey = nil
                            }
                        )
                    }
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Per-Power Mode Hotkeys
                if !settings.powerModes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Direct Power Mode Shortcuts")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text("Assign hotkeys to directly activate specific Power Modes")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        VStack(spacing: 0) {
                            ForEach(Array(settings.activePowerModes.enumerated()), id: \.element.id) { index, powerMode in
                                if index > 0 {
                                    Divider().padding(.horizontal, 12)
                                }
                                PowerModeHotkeyRow(
                                    powerMode: powerMode,
                                    settings: settings,
                                    hotkeyManager: hotkeyManager
                                )
                            }
                        }
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                // Tips
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tips")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        HotkeyTipRow(icon: "keyboard", text: "Click \"Set\" then press your desired key combination")
                        HotkeyTipRow(icon: "exclamationmark.triangle", text: "Avoid system shortcuts like Cmd+C, Cmd+V, Cmd+Tab")
                        HotkeyTipRow(icon: "hand.raised", text: "Use modifiers: Cmd (⌘), Option (⌥), Control (⌃), Shift (⇧)")
                        HotkeyTipRow(icon: "bolt.circle", text: "Power Mode hotkeys open the overlay for voice input")
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Reset button
                HStack {
                    Spacer()
                    Button("Reset to Defaults") {
                        try? hotkeyManager.registerDefaultHotkeys()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
        }
        .onAppear {
            if hotkeyManager.registeredHotkeys.isEmpty {
                try? hotkeyManager.registerDefaultHotkeys()
            }
        }
        .alert("Hotkey Conflict", isPresented: $showConflictAlert) {
            Button("OK") {}
        } message: {
            Text(conflictMessage)
        }
        .background(
            HotkeyRecorderOverlay(
                isRecording: recordingAction != nil,
                action: recordingAction,
                onRecord: { combination in
                    if let action = recordingAction {
                        do {
                            try hotkeyManager.registerHotkey(combination, for: action)
                            // Save to settings for persistence
                            if action == .openPowerModeOverlay {
                                settings.globalPowerModeHotkey = combination
                            }
                        } catch {
                            conflictMessage = error.localizedDescription
                            showConflictAlert = true
                        }
                    }
                    recordingAction = nil
                },
                onCancel: { recordingAction = nil }
            )
        )
    }
}

// MARK: - Power Mode Hotkey Row

private struct PowerModeHotkeyRow: View {
    let powerMode: PowerMode
    @ObservedObject var settings: MacSettings
    @ObservedObject var hotkeyManager: MacHotkeyManager

    @State private var isRecording = false
    @State private var keyMonitor: Any?
    @State private var showError = false
    @State private var errorMessage = ""

    private var currentHotkey: HotkeyCombination? {
        settings.powerModeHotkeys[powerMode.id]
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: powerMode.icon)
                    .foregroundStyle(.purple)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(powerMode.name)
                    .font(.callout.weight(.medium))
                Text("Activate Power Mode overlay")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Hotkey display / recording
            if isRecording {
                Text("Press keys...")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else if let hotkey = currentHotkey {
                HStack(spacing: 4) {
                    Text(hotkey.displayString)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                    Button {
                        clearHotkey()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Text("Not Set")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Set button
            Button(isRecording ? "Cancel" : "Set") {
                toggleRecording()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .alert("Hotkey Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyPress(event)
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func handleKeyPress(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasModifier = modifiers.contains(.command) || modifiers.contains(.control) ||
                         modifiers.contains(.option) || modifiers.contains(.shift)

        guard hasModifier else {
            errorMessage = "Hotkeys must include a modifier key (⌘, ⌃, ⌥, or ⇧)"
            showError = true
            stopRecording()
            return
        }

        let keyCode = UInt16(event.keyCode)
        let modifierFlags = UInt(modifiers.rawValue)

        // Create display string
        let displayString = createDisplayString(keyCode: keyCode, modifiers: modifierFlags)

        // Save hotkey
        let combination = HotkeyCombination(
            keyCode: keyCode,
            modifiers: modifierFlags,
            displayString: displayString
        )

        settings.powerModeHotkeys[powerMode.id] = combination

        // Register with hotkey manager
        let success = hotkeyManager.registerPowerModeHotkey(
            powerModeId: powerMode.id,
            keyCode: keyCode,
            modifiers: modifierFlags
        )

        if !success {
            errorMessage = "Failed to register hotkey"
            showError = true
            settings.powerModeHotkeys.removeValue(forKey: powerMode.id)
        }

        stopRecording()
    }

    private func clearHotkey() {
        settings.powerModeHotkeys.removeValue(forKey: powerMode.id)
        hotkeyManager.unregisterPowerModeHotkey(powerModeId: powerMode.id)
    }

    private func createDisplayString(keyCode: UInt16, modifiers: UInt) -> String {
        var result = ""
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)

        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }

        // Map key codes to characters
        let keyMap: [UInt16: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H", 0x05: "G",
            0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V", 0x0B: "B", 0x0C: "Q",
            0x0D: "W", 0x0E: "E", 0x0F: "R", 0x10: "Y", 0x11: "T", 0x1F: "O",
            0x20: "U", 0x22: "I", 0x23: "P", 0x25: "L", 0x26: "J", 0x28: "K",
            0x2D: "N", 0x2E: "M", 0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4",
            0x17: "5", 0x16: "6", 0x1A: "7", 0x1C: "8", 0x19: "9", 0x1D: "0",
            0x31: "Space"
        ]

        result += keyMap[keyCode] ?? "?"
        return result
    }
}

// MARK: - Hotkey Row

private struct HotkeyRow: View {
    let action: HotkeyAction
    let title: String
    let description: String
    let icon: String
    let color: Color
    let currentCombination: HotkeyCombination?
    let isRecording: Bool
    let onStartRecording: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isRecording {
                HStack(spacing: 8) {
                    Text("Press keys...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    ProgressView()
                        .scaleEffect(0.7)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else if let combo = currentCombination {
                HStack(spacing: 8) {
                    Text(combo.displayString)
                        .font(.system(.callout, design: .rounded).weight(.medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Button(action: onStartRecording) {
                        Text("Change")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)

                    Button(action: onClear) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                }
            } else {
                Button("Set", action: onStartRecording)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
    }
}

// MARK: - Hotkey Tip Row

private struct HotkeyTipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Hotkey Recorder Overlay

private struct HotkeyRecorderOverlay: View {
    let isRecording: Bool
    let action: HotkeyAction?
    let onRecord: (HotkeyCombination) -> Void
    let onCancel: () -> Void

    var body: some View {
        if isRecording {
            HotkeyRecorderView(
                action: action,
                onRecord: onRecord,
                onCancel: onCancel
            )
        }
    }
}

private struct HotkeyRecorderView: NSViewRepresentable {
    let action: HotkeyAction?
    let onRecord: (HotkeyCombination) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.onRecord = onRecord
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.onRecord = onRecord
        nsView.onCancel = onCancel
    }
}

class HotkeyRecorderNSView: NSView {
    var onRecord: ((HotkeyCombination) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }

        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if modifiers.isEmpty {
            return
        }

        let combination = HotkeyCombination.from(event: event)
        onRecord?(combination)
    }

    override func flagsChanged(with event: NSEvent) {
        // Just update display, don't record on modifier-only press
    }
}

// MARK: - Personalization View (matches iOS)

struct MacPersonalizationView: View {
    @ObservedObject var settings: MacSettings
    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Personalization")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Customize contexts, memory, and app assignments")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)

                // Tab Picker
                Picker("", selection: $selectedTab) {
                    Text("Contexts").tag(0)
                    Text("Memory").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)

                // Content
                if selectedTab == 0 {
                    // Embed Contexts View
                    MacContextsView(settings: settings)
                        .frame(maxWidth: .infinity)
                } else {
                    // Embed Memory View
                    MacMemoryView(settings: settings)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Behavior View (matches iOS)

struct MacBehaviorView: View {
    @ObservedObject var settings: MacSettings
    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Behavior")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Configure Power Modes, streaming, and automation")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)

                // Tab Picker
                Picker("", selection: $selectedTab) {
                    Text("Power Modes").tag(0)
                    Text("Settings").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)

                if selectedTab == 0 {
                    // Power Modes
                    MacPowerModesView(settings: settings)
                        .frame(maxWidth: .infinity)
                } else {
                    // Behavior settings
                    behaviorSettings
                }
            }
            .padding(20)
        }
    }

    private var behaviorSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Streaming
            GroupBox("Streaming") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable streaming for Power Modes", isOn: $settings.powerModeStreamingEnabled)
                    Text("Stream AI responses as they're generated instead of waiting for completion")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }

            // Auto-return
            GroupBox("Auto-Return") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Return to previous app after recording", isOn: $settings.autoReturnEnabled)
                    Text("Automatically switch back to the app you were using after transcription completes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }

            // Sound effects
            GroupBox("Sound Effects") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Play sound when recording starts", isOn: $settings.playSoundOnRecordStart)
                    Toggle("Play sound when recording ends", isOn: $settings.playSoundOnRecordEnd)
                }
                .padding(8)
            }

            Spacer()
        }
    }
}

// MARK: - Security & Privacy View (matches iOS)

struct MacSecurityPrivacyView: View {
    @ObservedObject var settings: MacSettings
    @State private var showClearHistoryConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Security & Privacy")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Protect your data and control privacy settings")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)

                // Biometrics (Touch ID on Mac)
                GroupBox("Authentication") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Require Touch ID to access settings", isOn: $settings.biometricProtectionEnabled)
                        Text("Protect sensitive settings with Touch ID authentication")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                }

                // Data Retention
                GroupBox("Data Retention") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Keep transcription history for:", selection: $settings.historyRetentionDays) {
                            Text("7 days").tag(7)
                            Text("30 days").tag(30)
                            Text("90 days").tag(90)
                            Text("Forever").tag(0)
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200)

                        Text("Older transcriptions will be automatically deleted")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Divider()

                        Button(role: .destructive) {
                            showClearHistoryConfirmation = true
                        } label: {
                            Label("Clear All History", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(8)
                }

                // Privacy Settings
                GroupBox("Privacy") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Send anonymous usage analytics", isOn: $settings.analyticsEnabled)
                        Text("Help improve SwiftSpeak by sending anonymous usage data")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Divider()

                        Toggle("Enable cloud log sync", isOn: $settings.cloudLogSyncEnabled)
                        Text("Sync logs from iOS devices for debugging")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                }

                // API Key Security
                GroupBox("API Key Security") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(.green)
                            Text("API keys are stored securely in Keychain")
                        }
                        Text("Your API keys are encrypted and stored in the macOS Keychain, separate from app data.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                }

                Spacer()
            }
            .padding(20)
        }
        .alert("Clear All History?", isPresented: $showClearHistoryConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                settings.clearTranscriptionHistory()
            }
        } message: {
            Text("This will permanently delete all transcription history. This action cannot be undone.")
        }
    }
}
