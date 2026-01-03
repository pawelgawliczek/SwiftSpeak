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

// OverlayViewModel is defined in RecordingOverlayView.swift

@MainActor
final class MenuBarController: ObservableObject {

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
    private let overlayViewModel = OverlayViewModel()
    private var frontmostAppObserver: NSObjectProtocol?
    private var lastFrontmostBundleId: String?
    private var localKeyboardMonitor: Any?

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
        setupFrontmostAppMonitor()
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
        // Show history window
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
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func openSettings() {
        // Activate app and show settings
        NSApp.activate(ignoringOtherApps: true)

        // Always recreate the window to ensure fresh state
        let settingsView = MacSettingsView(settings: MacSettings.shared)
        let hostingView = NSHostingView(rootView: settingsView)

        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "SwiftSpeak Settings"
            window.minSize = NSSize(width: 750, height: 500)
            window.center()
            settingsWindow = window
        }

        settingsWindow?.contentView = hostingView
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

    public func cancelRecording() {
        audioRecorder.cancelRecording()
        hideOverlay()
    }

    // MARK: - Transcription & Translation

    private func transcribe(audioURL: URL) async throws -> String {
        // Use ProviderFactory to create the appropriate transcription provider
        let providerFactory = ProviderFactory(settings: settings)
        let provider = settings.selectedTranscriptionProvider

        guard let transcriptionService = providerFactory.createTranscriptionProvider(for: provider) else {
            throw TranscriptionError.apiKeyMissing
        }

        // Pass the selected dictation language (nil = auto-detect)
        return try await transcriptionService.transcribe(audioURL: audioURL, language: settings.selectedDictationLanguage)
    }

    private func translate(text: String, to targetLanguage: Language) async throws -> String {
        // Use ProviderFactory to create the translation provider
        let providerFactory = ProviderFactory(settings: settings)

        guard let translationService = providerFactory.createDefaultTranslationProvider() else {
            throw TranscriptionError.apiKeyMissing
        }

        return try await translationService.translate(text: text, from: settings.selectedDictationLanguage, to: targetLanguage)
    }

    private func saveToHistory(transcription: String, finalText: String, wasTranslated: Bool) {
        let record = TranscriptionRecord(
            rawTranscription: transcription,
            formattedText: finalText,
            formattingMode: .raw,  // macOS uses translation, not formatting modes
            duration: audioRecorder.duration,
            transcriptionProvider: settings.selectedTranscriptionProvider,
            formattingProvider: wasTranslated ? settings.selectedTranscriptionProvider : nil
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

// MARK: - Settings Navigation

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case providers = "Providers"
    case contexts = "Contexts"
    case powerModes = "Power Modes"
    case memory = "Memory"
    case analytics = "Analytics"
    case hotkeys = "Hotkeys"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .providers: return "cloud"
        case .contexts: return "person.2"
        case .powerModes: return "bolt.circle"
        case .memory: return "brain"
        case .analytics: return "chart.bar"
        case .hotkeys: return "keyboard"
        }
    }
}

// MARK: - Settings View with Sidebar

struct MacSettingsView: View {
    @ObservedObject var settings: MacSettings
    @State private var selectedSection: SettingsSection = .general

    var body: some View {
        NavigationSplitView {
            // Sidebar - always visible
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
        } detail: {
            // Content area
            Group {
                switch selectedSection {
                case .general:
                    GeneralSettingsTab(settings: settings)
                case .providers:
                    ProvidersSettingsTab(settings: settings)
                case .contexts:
                    MacContextsView(settings: settings)
                case .powerModes:
                    MacPowerModesView(settings: settings)
                case .memory:
                    MacMemoryView(settings: settings)
                case .analytics:
                    MacCostAnalyticsView(settings: settings)
                case .hotkeys:
                    HotkeySettingsTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

struct ProvidersSettingsTab: View {
    @ObservedObject var settings: MacSettings
    @State private var showingAddProvider = false
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
                    Button(action: { showingAddProvider = true }) {
                        Label("Add Provider", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
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
                                    showingAddProvider = true
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
                                    showingAddProvider = true
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showingAddProvider) {
            AddProviderSheet(settings: settings)
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
                        SecureField("Enter your \(provider.displayName) API key", text: $apiKey)
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
            // Anthropic doesn't have a models endpoint
            return ([], config.provider.availableLLMModels)
        case .google:
            return try await fetchGoogleModels()
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
    @StateObject private var hotkeyManager = MacHotkeyManager()
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

                // Hotkey List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Actions")
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

                // Tips
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tips")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        HotkeyTipRow(icon: "keyboard", text: "Click \"Set\" then press your desired key combination")
                        HotkeyTipRow(icon: "exclamationmark.triangle", text: "Avoid system shortcuts like Cmd+C, Cmd+V, Cmd+Tab")
                        HotkeyTipRow(icon: "hand.raised", text: "Use modifiers: Cmd (⌘), Option (⌥), Control (⌃), Shift (⇧)")
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
