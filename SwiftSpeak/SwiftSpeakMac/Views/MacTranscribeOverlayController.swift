//
//  MacTranscribeOverlayController.swift
//  SwiftSpeakMac
//
//  Manages the transcribe overlay window
//  Supports toggle mode and push-to-talk mode
//

import AppKit
import SwiftUI
import SwiftSpeakCore
import Carbon.HIToolbox
import Combine

// MARK: - Keyable Borderless Window

/// Custom window that can become key even when borderless
/// Required for keyboard input in overlay windows
private class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Transcribe Overlay Controller

@MainActor
final class MacTranscribeOverlayController {

    // MARK: - Properties

    private var overlayWindow: NSWindow?
    private var viewModel: MacTranscribeOverlayViewModel?
    private var hostingView: NSHostingView<AnyView>?

    private let settings: MacSettings
    private let audioRecorder: MacAudioRecorder
    private var providerFactory: ProviderFactory?
    private var textInsertion: MacTextInsertionService?

    /// Local keyboard event monitor for overlay-specific shortcuts
    private var localMonitor: Any?

    /// Combine cancellable for auto-close observation
    private var autoCloseCancellable: AnyCancellable?

    /// Whether the overlay is currently visible
    var isVisible: Bool { overlayWindow?.isVisible ?? false }

    /// Current mode (toggle vs push-to-talk)
    private(set) var currentMode: TranscribeMode = .toggle

    /// Callback when overlay closes
    var onClose: (() -> Void)?

    // MARK: - Initialization

    init(
        settings: MacSettings,
        audioRecorder: MacAudioRecorder
    ) {
        self.settings = settings
        self.audioRecorder = audioRecorder
    }

    // MARK: - Dependency Injection

    func setDependencies(
        providerFactory: ProviderFactory,
        textInsertion: MacTextInsertionService
    ) {
        self.providerFactory = providerFactory
        self.textInsertion = textInsertion
    }

    // MARK: - Show / Hide

    /// Show the transcribe overlay
    /// - Parameters:
    ///   - mode: Toggle or push-to-talk mode
    ///   - context: Pre-captured context from hotkey callback
    func show(mode: TranscribeMode, context: HotkeyContext) {
        // If already visible, just update context
        if isVisible {
            viewModel?.setPreCapturedContext(context)
            return
        }

        currentMode = mode

        // Create view model
        let vm = MacTranscribeOverlayViewModel(
            settings: settings,
            audioRecorder: audioRecorder
        )

        if let factory = providerFactory, let insertion = textInsertion {
            vm.setDependencies(providerFactory: factory, textInsertion: insertion)
        }

        vm.mode = mode
        vm.setPreCapturedContext(context)
        viewModel = vm

        // Set callback to hide overlay before text insertion
        vm.onWillInsertText = { [weak self] in
            macLog("Hiding overlay before text insertion", category: "Transcribe")
            self?.overlayWindow?.orderOut(nil)
        }

        // Observe shouldAutoClose to automatically close overlay after insertion
        autoCloseCancellable = vm.$shouldAutoClose
            .dropFirst()
            .filter { $0 }
            .sink { [weak self] _ in
                macLog("Auto-closing overlay after insertion complete", category: "Transcribe")
                self?.finishAndClose()
            }

        // Create overlay view
        let overlayView = MacTranscribeOverlayView(
            viewModel: vm,
            onClose: { [weak self] in
                self?.hide()
            },
            onFinish: { [weak self] in
                self?.finishAndClose()
            }
        )

        // Create or reuse window
        let window: NSWindow
        if let existingWindow = overlayWindow {
            window = existingWindow
        } else {
            window = createOverlayWindow()
            overlayWindow = window
        }

        // Create new hosting view (always fresh to avoid stale SwiftUI state)
        let hosting = NSHostingView(rootView: AnyView(overlayView))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        hostingView = hosting

        window.contentView = hosting

        // Position window in center of screen
        positionWindow(window)

        // Show window and ensure it can receive keyboard events
        window.makeKeyAndOrderFront(nil)
        window.level = .floating

        // Force the app to become active so we can receive keyboard events
        NSApp.activate(ignoringOtherApps: true)

        // Ensure window is first responder
        window.makeFirstResponder(hosting)

        // Double-check the window is actually key
        if !window.isKeyWindow {
            window.makeKey()
        }

        // Setup keyboard monitoring
        setupKeyboardMonitor()

        // Start recording automatically
        Task {
            await vm.startRecording()
        }

        macLog("Transcribe overlay shown (mode: \(mode))", category: "Transcribe")
    }

    /// Hide the overlay
    func hide() {
        // Cancel any ongoing recording
        viewModel?.cancelRecording()

        cleanupAndClose()
    }

    /// Finish transcription and close
    private func finishAndClose() {
        cleanupAndClose()
    }

    private func cleanupAndClose() {
        // Cancel auto-close observation
        autoCloseCancellable?.cancel()
        autoCloseCancellable = nil

        // Remove keyboard monitors first
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        // Clean up viewModel subscriptions immediately
        viewModel?.cleanup()

        // Hide window (keep it around for reuse)
        overlayWindow?.orderOut(nil)

        // Capture callback to call after cleanup
        let closeCallback = onClose

        // Delay cleanup to allow SwiftUI to finish any pending updates
        // This prevents EXC_BAD_ACCESS from "entangle context after pre-commit"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            // DON'T close the window - just clear SwiftUI state
            // The window will be reused next time (isReleasedWhenClosed = false)
            self?.hostingView = nil
            self?.viewModel = nil

            // Call close callback after all cleanup is done
            closeCallback?()
            macLog("Transcribe overlay closed", category: "Transcribe")
        }
    }

    // MARK: - Push-to-Talk Release

    /// Called when push-to-talk hotkey is released
    func onPushToTalkReleased() {
        guard currentMode == .pushToTalk,
              let vm = viewModel,
              vm.state == .recording else {
            return
        }

        Task { @MainActor in
            // Stop recording and process
            await vm.stopRecording()

            // Wait for processing to complete, then execute context's enter behavior
            // The viewModel will handle this based on enterKeyBehavior
        }
    }

    // MARK: - Window Creation

    private func createOverlayWindow() -> NSWindow {
        let window = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true

        // CRITICAL: Don't release window on close to prevent double-release crashes
        window.isReleasedWhenClosed = false

        return window
    }

    private func positionWindow(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame

        // Reset window to consistent size before positioning
        // This ensures second-use doesn't inherit a different size
        let targetSize = NSSize(width: 420, height: 320)
        window.setContentSize(targetSize)

        // Center horizontally, position just above the dock
        let x = screenFrame.midX - targetSize.width / 2
        let y = screenFrame.minY + 80

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Keyboard Handling

    private func setupKeyboardMonitor() {
        // Use both local and global monitors to ensure keyboard events are captured
        // Local monitor for when window is key, global for accessory mode backup
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleKeyDown(event) ?? event
        }

        // Also add a global monitor as fallback for accessory mode apps
        // Note: Global monitor cannot consume events, so only use it when window isn't key
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            // Skip if window is key - local monitor handles it
            if self.overlayWindow?.isKeyWindow == true {
                return
            }
            _ = self.handleKeyDown(event)
        }
    }

    /// Global event monitor for accessory mode
    private var globalMonitor: Any?

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard isVisible, let vm = viewModel else {
            macLog("Key ignored - overlay not visible or no viewModel", category: "Transcribe", level: .debug)
            return event
        }

        let keyCode = event.keyCode
        // Check for meaningful modifiers (ignore Caps Lock, Fn, etc.)
        let meaningfulModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let hasModifiers = !event.modifierFlags.intersection(meaningfulModifiers).isEmpty


        // T (keyCode 17) - Toggle translation (no meaningful modifiers)
        if keyCode == 17 && !hasModifiers {
            macLog("T pressed - toggling translation", category: "Transcribe")
            vm.toggleTranslation()
            return nil
        }

        // C (keyCode 8) - Cycle context (no meaningful modifiers)
        if keyCode == 8 && !hasModifiers {
            macLog("C pressed - cycling context", category: "Transcribe")
            vm.cycleToNextContext()
            return nil
        }

        // Enter (keyCode 36) - Finish and execute enter behavior
        if keyCode == 36 {
            macLog("Enter pressed - state: \(vm.state)", category: "Transcribe")
            switch vm.state {
            case .recording:
                Task {
                    await vm.stopRecording()
                }
            case .complete:
                Task {
                    await vm.insertText()
                    finishAndClose()
                }
            case .error:
                // Retry processing when Enter is pressed on error screen
                Task {
                    await vm.retryProcessing()
                }
            case .initializing:
                // Ignore Enter during initialization - recording hasn't started yet
                macLog("Ignoring Enter during initialization", category: "Transcribe")
            default:
                break
            }
            return nil
        }

        // Escape (keyCode 53) - Cancel
        if keyCode == 53 {
            macLog("Escape pressed - canceling", category: "Transcribe")
            hide()
            return nil
        }

        return event
    }
}
