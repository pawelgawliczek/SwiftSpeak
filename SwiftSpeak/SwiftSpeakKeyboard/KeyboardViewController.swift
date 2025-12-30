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

    override func viewDidLoad() {
        super.viewDidLoad()

        keyboardLog("Keyboard loaded", category: "Lifecycle")

        // Update Full Access status in shared defaults for main app to detect
        updateFullAccessStatus()

        // Set up the SwiftUI keyboard view
        viewModel.textDocumentProxy = textDocumentProxy
        viewModel.hostViewController = self

        let swiftUIView = KeyboardView(viewModel: viewModel) { [weak self] in
            self?.advanceToNextInputMode()
        }

        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear

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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        keyboardLog("Keyboard appeared", category: "Lifecycle")

        // Update Full Access status each time keyboard appears
        updateFullAccessStatus()

        // Reload settings when keyboard appears
        viewModel.loadSettings()
        viewModel.textDocumentProxy = textDocumentProxy
        viewModel.hostViewController = self

        // Phase 11: Check for auto-insert after main app completes transcription
        viewModel.checkAutoInsert()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        // Set keyboard height
        let height: CGFloat = 220
        view.frame.size.height = height
    }

    override func textWillChange(_ textInput: UITextInput?) {
        // Called when text is about to change
    }

    override func textDidChange(_ textInput: UITextInput?) {
        // Update proxy reference when text changes
        viewModel.textDocumentProxy = textDocumentProxy
    }

    // MARK: - Full Access Detection

    /// Updates the shared defaults with the current Full Access status
    /// so the main app can detect whether keyboard has required permissions
    private func updateFullAccessStatus() {
        // hasFullAccess is a property of UIInputViewController
        // that indicates whether the user has granted Full Access
        let sharedDefaults = UserDefaults(suiteName: "group.pawelgawliczek.swiftspeak")
        let previousStatus = sharedDefaults?.bool(forKey: "keyboardHasFullAccess") ?? false
        sharedDefaults?.set(hasFullAccess, forKey: "keyboardHasFullAccess")
        sharedDefaults?.synchronize()

        // Log only when status changes
        if previousStatus != hasFullAccess {
            keyboardLog("Full Access status changed: \(hasFullAccess)", category: "Lifecycle")
        }
    }
}
