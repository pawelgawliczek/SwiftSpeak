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

        // Prepare haptic feedback generators for reliable response
        KeyboardHaptics.prepare()

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

        // Reload settings when keyboard appears
        viewModel.loadSettings()
        viewModel.textDocumentProxy = textDocumentProxy
        viewModel.hostViewController = self
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
}
