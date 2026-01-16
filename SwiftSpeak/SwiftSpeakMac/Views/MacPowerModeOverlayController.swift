//
//  MacPowerModeOverlayController.swift
//  SwiftSpeakMac
//
//  NSPanel controller for Power Mode floating overlay
//  Phase 5: Manages overlay window lifecycle and positioning
//

import AppKit
import SwiftUI
import SwiftSpeakCore

@MainActor
final class MacPowerModeOverlayController: NSObject {

    // MARK: - Properties

    private var panel: NSPanel?
    private var hostingView: NSHostingView<MacPowerModeOverlayView>?
    private var viewModel: MacPowerModeOverlayViewModel?

    /// Whether the overlay is currently visible
    private(set) var isVisible: Bool = false

    /// Previously active application (to restore focus on close)
    private var previousApp: NSRunningApplication?

    // MARK: - Dependencies

    private let settings: MacSettings
    private let windowContextService: MacWindowContextService
    private let audioRecorder: MacAudioRecorder
    private let providerFactory: ProviderFactory
    private let obsidianQueryService: MacObsidianQueryService?
    // Note: Using Mac-specific query service - see MacObsidianQueryService.swift
    private let textInsertion: MacTextInsertionService

    // MARK: - Initialization

    init(
        settings: MacSettings,
        windowContextService: MacWindowContextService,
        audioRecorder: MacAudioRecorder,
        providerFactory: ProviderFactory,
        obsidianQueryService: MacObsidianQueryService?,
        textInsertion: MacTextInsertionService
    ) {
        self.settings = settings
        self.windowContextService = windowContextService
        self.audioRecorder = audioRecorder
        self.providerFactory = providerFactory
        self.obsidianQueryService = obsidianQueryService
        self.textInsertion = textInsertion

        super.init()
    }

    // MARK: - Public Methods

    /// Show overlay for a specific Power Mode
    /// - Parameters:
    ///   - powerMode: The Power Mode to execute
    ///   - windowContext: Optional pre-captured window context
    ///   - clipboard: Optional pre-captured clipboard content
    ///   - sourcePid: Optional PID of source app for async text capture
    public func showOverlay(for powerMode: PowerMode, windowContext: WindowContext? = nil, clipboard: String? = nil, sourcePid: pid_t = 0) {
        // Store the currently active application before showing overlay
        previousApp = NSWorkspace.shared.frontmostApplication

        // Create view model
        let newViewModel = MacPowerModeOverlayViewModel(
            powerMode: powerMode,
            allPowerModes: settings.activePowerModes,
            settings: settings,
            windowContextService: windowContextService,
            audioRecorder: audioRecorder
        )

        // Set dependencies
        newViewModel.setDependencies(
            providerFactory: providerFactory,
            obsidianQueryService: obsidianQueryService,
            textInsertion: textInsertion
        )

        // Set pre-captured context (captured before overlay opens)
        newViewModel.setPreCapturedContext(windowContext: windowContext, clipboard: clipboard, sourcePid: sourcePid)

        viewModel = newViewModel

        // Create or update panel
        if panel == nil {
            createPanel()
        }

        // Create SwiftUI view
        let overlayView = MacPowerModeOverlayView(
            viewModel: newViewModel,
            onClose: { [weak self] in
                self?.hideOverlay()
            }
        )

        // Update hosting view
        if let existingHostingView = hostingView {
            existingHostingView.rootView = overlayView
        } else {
            let newHostingView = NSHostingView(rootView: overlayView)
            panel?.contentView = newHostingView
            hostingView = newHostingView
        }

        // Position and show panel
        positionPanel()
        panel?.orderFrontRegardless()

        // Make panel key window to receive keyboard focus
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        isVisible = true

        // Setup keyboard monitoring
        setupKeyboardMonitoring()

        // Explicitly load context (in case .task doesn't re-run on rootView replacement)
        Task { @MainActor in
            await newViewModel.loadContext()
        }
    }

    /// Hide the overlay
    public func hideOverlay() {
        panel?.orderOut(nil)
        isVisible = false
        viewModel?.reset()
        stopKeyboardMonitoring()

        // Restore focus to the previous application
        restoreFocusToPreviousApp()
    }

    /// Restore focus to the previously active application
    private func restoreFocusToPreviousApp() {
        guard let app = previousApp else { return }

        // Small delay to ensure panel is fully hidden
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            app.activate(options: [.activateIgnoringOtherApps])
        }

        previousApp = nil
    }

    /// Toggle overlay visibility for a Power Mode
    public func toggleOverlay(for powerMode: PowerMode) {
        if isVisible {
            hideOverlay()
        } else {
            showOverlay(for: powerMode)
        }
    }

    /// Update visible text in the overlay (called async after window text capture)
    public func updateVisibleText(_ text: String) {
        viewModel?.updateVisibleText(text)
    }

    // MARK: - Private Methods

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        panel.title = "Power Mode"
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        // Allow panel to become key window for keyboard input
        panel.becomesKeyOnlyIfNeeded = false

        // Set delegate
        panel.delegate = self

        self.panel = panel
    }

    private func positionPanel() {
        guard let panel = panel else { return }
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let panelFrame = panel.frame

        // Center horizontally, position in upper third vertically
        let x = screenFrame.midX - panelFrame.width / 2
        let y = screenFrame.midY + screenFrame.height / 6

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Keyboard Monitoring

    nonisolated(unsafe) private var keyboardMonitor: Any?

    private func setupKeyboardMonitoring() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isVisible else { return event }

            switch event.keyCode {
            case 53: // Escape - Close overlay, go back, or cancel
                if self.viewModel?.state == .obsidianSearch {
                    // Go back to contextPreview
                    self.viewModel?.state = .contextPreview
                    return nil
                } else {
                    self.hideOverlay()
                    return nil
                }

            case 36: // Enter/Return - Context-sensitive action
                // Recording state: Shift+Enter stops recording
                if self.viewModel?.state == .recording {
                    if event.modifierFlags.contains(.shift) {
                        Task { await self.viewModel?.stopRecording() }
                        return nil
                    }
                } else if self.viewModel?.state == .contextPreview {
                    // Context preview: Enter starts recording (or goes to Obsidian search)
                    Task { await self.viewModel?.startRecording() }
                    return nil
                } else if self.viewModel?.state == .obsidianSearch {
                    if event.modifierFlags.contains(.shift) {
                        // Shift+Enter = proceed to recording
                        Task { await self.viewModel?.proceedFromObsidianSearch() }
                    } else {
                        // Plain Enter = search
                        Task { await self.viewModel?.searchObsidian() }
                    }
                    return nil
                } else if self.viewModel?.state == .result {
                    // Enter in result view = refine (if text field has content)
                    if let vm = self.viewModel, !vm.userInput.isEmpty {
                        Task { await vm.refineResult(vm.userInput) }
                        return nil
                    }
                }

            case 49: // Space - Stop recording (if recording)
                if self.viewModel?.state == .recording {
                    Task { await self.viewModel?.stopRecording() }
                    return nil
                }

            case 126: // Up Arrow - Navigate up (power mode or predictions)
                if self.viewModel?.state == .contextPreview {
                    self.viewModel?.handleArrowUp()
                    return nil
                }

            case 125: // Down Arrow - Navigate down (power mode or predictions)
                if self.viewModel?.state == .contextPreview {
                    self.viewModel?.handleArrowDown()
                    return nil
                }

            case 123: // Left Arrow - Previous power mode or shorter suggestion
                if self.viewModel?.state == .contextPreview {
                    self.viewModel?.handleArrowLeft()
                    return nil
                }

            case 124: // Right Arrow - Next power mode or longer suggestion
                if self.viewModel?.state == .contextPreview {
                    self.viewModel?.handleArrowRight()
                    return nil
                }

            case 8: // C key - Cycle through SwiftSpeak Contexts (when in power mode row)
                if self.viewModel?.state == .contextPreview && self.viewModel?.navigationMode == .powerMode {
                    self.viewModel?.cycleToNextContext()
                    return nil
                }

            // Number keys 1-9 for toggling Obsidian search results
            case 18...26: // Keys 1-9 (keyCodes 18-26)
                if self.viewModel?.state == .obsidianSearch {
                    let index = Int(event.keyCode) - 17 // keyCode 18 = "1", so subtract 17 to get 1-based index
                    self.viewModel?.toggleResultByIndex(index)
                    return nil
                }

            default:
                break
            }

            return event
        }
    }

    private func stopKeyboardMonitoring() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
    }

    // MARK: - Window Lifecycle

    deinit {
        // Inline cleanup since deinit is nonisolated
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// MARK: - NSWindowDelegate

extension MacPowerModeOverlayController: NSWindowDelegate {
    public func windowWillClose(_ notification: Notification) {
        hideOverlay()
    }

    public func windowDidResignKey(_ notification: Notification) {
        // Optionally hide when losing focus
        // hideOverlay()
    }
}
