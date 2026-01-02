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

    // Keyboard height - increased for typing mode with SwiftSpeakBar + PredictionRow + QWERTY
    private let keyboardHeight: CGFloat = 350

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
        let swiftUIView = KeyboardView(viewModel: viewModel) { [weak self] in
            self?.advanceToNextInputMode()
        }

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

        // Set keyboard height using constraint (proper way for keyboard extensions)
        heightConstraint = view.heightAnchor.constraint(equalToConstant: keyboardHeight)
        heightConstraint?.priority = .required
        heightConstraint?.isActive = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Enable logging now that keyboard is fully initialized
        SharedLogManager.isInitialized = true
        keyboardLog("Keyboard appeared", category: "Lifecycle")

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
}
