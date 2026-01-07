//
//  KeyboardViewController.swift
//  SwiftSpeakKeyboard
//
//  Main keyboard extension controller
//

import UIKit
import SwiftUI

class KeyboardViewController: UIInputViewController {

    private var keyboardView: UIHostingController<KeyboardView>?
    private var viewModel = KeyboardViewModel()
    private var heightConstraint: NSLayoutConstraint?

    // MARK: - Height Configuration

    /// Base heights for different keyboard modes
    private enum HeightConfig {
        static let voiceMode: CGFloat = 260          // Voice mode with corner buttons
        static let typingModeFull: CGFloat = 350     // Full QWERTY + all bars
        static let swiftSpeakBarHeight: CGFloat = 50 // SwiftSpeakBar contribution
        static let predictionRowHeight: CGFloat = 36 // PredictionRow contribution
    }

    /// Current display mode (cached for height calculations)
    private var currentDisplayMode: KeyboardDisplayMode = .voice

    override func viewDidLoad() {
        super.viewDidLoad()

        keyboardLog("Keyboard loaded", category: "Lifecycle")

        // Update Full Access status in shared defaults for main app to detect
        updateFullAccessStatus()

        // Set up the SwiftUI keyboard view
        keyboardLog("Setting up viewModel...", category: "Lifecycle")
        viewModel.textDocumentProxy = textDocumentProxy
        viewModel.hostViewController = self

        keyboardLog("Creating KeyboardView...", category: "Lifecycle")
        let swiftUIView = KeyboardView(
            viewModel: viewModel,
            onNextKeyboard: { [weak self] in
                self?.advanceToNextInputMode()
            },
            onModeChange: { [weak self] mode in
                self?.updateHeight(for: mode)
            },
            onRefreshHeight: { [weak self] in
                self?.refreshHeight()
            }
        )

        keyboardLog("Creating hostingController...", category: "Lifecycle")
        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear

        keyboardLog("Adding hostingController to view...", category: "Lifecycle")
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        keyboardView = hostingController

        // Load saved display mode preference
        let sharedDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        if let modeRaw = sharedDefaults?.string(forKey: "lastKeyboardMode"),
           let mode = KeyboardDisplayMode(rawValue: modeRaw) {
            currentDisplayMode = mode
        }

        // Set keyboard height using constraint based on current mode
        let initialHeight = calculateHeight(for: currentDisplayMode)
        heightConstraint = view.heightAnchor.constraint(equalToConstant: initialHeight)
        heightConstraint?.priority = .required
        heightConstraint?.isActive = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Enable logging now that keyboard is fully initialized
        SharedLogManager.isInitialized = true
        keyboardLog("Keyboard appeared", category: "Lifecycle")

        // Prepare haptic generators for immediate feedback
        KeyboardHaptics.prepare()

        // Update Full Access status each time keyboard appears
        updateFullAccessStatus()

        // Refresh all state including SwiftLink status checks
        viewModel.textDocumentProxy = textDocumentProxy
        viewModel.hostViewController = self
        viewModel.refreshState()

        // Phase 11: Check for auto-insert after main app completes transcription
        viewModel.checkAutoInsert()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        keyboardLog("Keyboard disappearing", category: "Lifecycle")

        // Clean up timers and status checks
        viewModel.cleanup()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // Height is now set via constraint in viewDidLoad
    }

    override func textWillChange(_ textInput: UITextInput?) {
        // Called when text is about to change
    }

    override func textDidChange(_ textInput: UITextInput?) {
        // Update proxy reference when text changes
        viewModel.textDocumentProxy = textDocumentProxy
    }

    // MARK: - Keyboard Status Detection

    /// Updates the shared defaults with keyboard status
    /// so the main app can detect whether keyboard is enabled and has permissions
    private func updateFullAccessStatus() {
        let sharedDefaults = UserDefaults(suiteName: "group.pawelgawliczek.swiftspeak")

        // Mark that the keyboard extension has been loaded (means it's enabled)
        sharedDefaults?.set(true, forKey: "keyboardIsActive")

        // hasFullAccess is a property of UIInputViewController
        // that indicates whether the user has granted Full Access
        let previousStatus = sharedDefaults?.bool(forKey: "keyboardHasFullAccess") ?? false
        sharedDefaults?.set(hasFullAccess, forKey: "keyboardHasFullAccess")
        sharedDefaults?.synchronize()

        // Log only when status changes
        if previousStatus != hasFullAccess {
            keyboardLog("Full Access status changed: \(hasFullAccess)", category: "Lifecycle")
        }
    }

    // MARK: - Dynamic Height Management

    /// Calculates the appropriate keyboard height based on mode and user settings
    /// - Parameter mode: The current display mode (voice or typing)
    /// - Returns: The calculated height in points
    private func calculateHeight(for mode: KeyboardDisplayMode) -> CGFloat {
        let sharedDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        switch mode {
        case .voice:
            // Voice mode is always compact
            return HeightConfig.voiceMode

        case .typing:
            // Start with full typing height
            var height = HeightConfig.typingModeFull

            // Check if SwiftSpeakBar is hidden
            let showSwiftSpeakBar = sharedDefaults?.object(forKey: Constants.Keys.keyboardShowSwiftSpeakBar) as? Bool ?? true
            if !showSwiftSpeakBar {
                height -= HeightConfig.swiftSpeakBarHeight
            }

            // Check if PredictionRow is hidden
            let showPredictionRow = sharedDefaults?.object(forKey: Constants.Keys.keyboardShowPredictionRow) as? Bool ?? true
            if !showPredictionRow {
                height -= HeightConfig.predictionRowHeight
            }

            return height
        }
    }

    /// Updates the keyboard height with animation
    /// Called from SwiftUI when display mode changes
    /// - Parameter mode: The new display mode
    func updateHeight(for mode: KeyboardDisplayMode) {
        guard currentDisplayMode != mode else { return }

        currentDisplayMode = mode
        let newHeight = calculateHeight(for: mode)

        keyboardLog("Updating height for \(mode): \(newHeight)pt", category: "Layout")

        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) { [weak self] in
            self?.heightConstraint?.constant = newHeight
            self?.view.superview?.layoutIfNeeded()
        }
    }

    /// Refreshes height based on current settings (call when settings change)
    func refreshHeight() {
        let newHeight = calculateHeight(for: currentDisplayMode)

        if heightConstraint?.constant != newHeight {
            keyboardLog("Refreshing height: \(newHeight)pt", category: "Layout")

            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) { [weak self] in
                self?.heightConstraint?.constant = newHeight
                self?.view.superview?.layoutIfNeeded()
            }
        }
    }
}
