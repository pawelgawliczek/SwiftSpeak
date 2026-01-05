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
    ///   - debugInfo: Debug info string to display in overlay
    public func showOverlay(for powerMode: PowerMode, windowContext: WindowContext? = nil, clipboard: String? = nil, debugInfo: String = "") {
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
        newViewModel.setPreCapturedContext(windowContext: windowContext, clipboard: clipboard)

        // Set debug info for display
        newViewModel.debugInfo = debugInfo

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
            case 53: // Escape - Close overlay and return to previous app
                self.hideOverlay()
                return nil

            case 36: // Enter/Return - Start recording or proceed (in contextPreview)
                if self.viewModel?.state == .contextPreview {
                    Task { await self.viewModel?.startRecording() }
                    return nil
                }

            case 49: // Space - Stop recording (if recording)
                if self.viewModel?.state == .recording {
                    Task { await self.viewModel?.stopRecording() }
                    return nil
                }

            case 123, 126: // Left Arrow (123) or Up Arrow (126) - Previous power mode
                if self.viewModel?.state == .contextPreview {
                    self.viewModel?.cycleToPreviousPowerMode()
                    return nil
                }

            case 124, 125: // Right Arrow (124) or Down Arrow (125) - Next power mode
                if self.viewModel?.state == .contextPreview {
                    self.viewModel?.cycleToNextPowerMode()
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
