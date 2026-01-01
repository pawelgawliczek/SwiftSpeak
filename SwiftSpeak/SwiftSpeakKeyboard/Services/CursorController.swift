//
//  CursorController.swift
//  SwiftSpeakKeyboard
//
//  Phase 13.5: Cursor control via long-press on space bar
//  Long-press space bar (0.5s) activates cursor mode, drag left/right to move cursor
//

import SwiftUI
import UIKit
import Combine

/// Manages cursor movement via drag gestures on space bar
@MainActor
class CursorController: ObservableObject {
    weak var textDocumentProxy: UITextDocumentProxy?

    @Published private(set) var cursorModeActive = false

    private var initialDragPosition: CGPoint?
    private var accumulatedOffset: CGFloat = 0

    /// How many points of horizontal drag equals 1 character move
    /// Calibrated for comfortable cursor control (smaller = more sensitive)
    private let pointsPerCharacter: CGFloat = 15

    /// Minimum drag distance to trigger character movement (reduces jitter)
    private let minimumDragThreshold: CGFloat = 5

    // MARK: - Public API

    /// Enter cursor control mode at the given touch position
    func enterCursorMode(at position: CGPoint) {
        guard !cursorModeActive else { return }

        cursorModeActive = true
        initialDragPosition = position
        accumulatedOffset = 0

        // Medium haptic feedback to indicate mode activation
        KeyboardHaptics.mediumTap()

        keyboardLog("Cursor mode activated", category: "CursorControl")
    }

    /// Handle drag gesture to move cursor left/right
    func handleDrag(to position: CGPoint) {
        guard cursorModeActive,
              let initial = initialDragPosition,
              let proxy = textDocumentProxy else { return }

        // Calculate horizontal delta from initial position
        let deltaX = position.x - initial.x

        // Only process if moved beyond minimum threshold
        guard abs(deltaX - accumulatedOffset) >= minimumDragThreshold else { return }

        // Calculate how many characters to move
        let charactersMoved = Int((deltaX - accumulatedOffset) / pointsPerCharacter)

        if charactersMoved != 0 {
            // Move cursor (positive = right, negative = left)
            proxy.adjustTextPosition(byCharacterOffset: charactersMoved)

            // Update accumulated offset to prevent repeated moves
            accumulatedOffset += CGFloat(charactersMoved) * pointsPerCharacter

            // Light haptic feedback for each character moved
            KeyboardHaptics.lightTap()

            keyboardLog("Cursor moved \(charactersMoved > 0 ? "right" : "left") by \(abs(charactersMoved))", category: "CursorControl")
        }
    }

    /// Exit cursor control mode
    func exitCursorMode() {
        guard cursorModeActive else { return }

        cursorModeActive = false
        initialDragPosition = nil
        accumulatedOffset = 0

        // Medium haptic to indicate mode deactivation
        KeyboardHaptics.mediumTap()

        keyboardLog("Cursor mode deactivated", category: "CursorControl")
    }

    // MARK: - Helpers

    /// Check if there is text to navigate through
    var hasTextToNavigate: Bool {
        guard let proxy = textDocumentProxy else { return false }
        let before = proxy.documentContextBeforeInput ?? ""
        let after = proxy.documentContextAfterInput ?? ""
        return !before.isEmpty || !after.isEmpty
    }
}
