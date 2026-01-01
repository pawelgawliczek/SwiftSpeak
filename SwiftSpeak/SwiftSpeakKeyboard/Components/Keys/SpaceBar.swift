//
//  SpaceBar.swift
//  SwiftSpeakKeyboard
//
//  Wide space bar component with distinct styling
//  Phase 13.5: Long-press activates cursor control mode
//

import SwiftUI

// MARK: - Space Bar
struct SpaceBar: View {
    let action: () -> Void
    let textDocumentProxy: UITextDocumentProxy?

    @StateObject private var cursorController = CursorController()
    @State private var isPressed = false
    @State private var longPressTimer: Timer?
    @State private var dragStartPosition: CGPoint?

    private var hasTextToNavigate: Bool {
        guard let proxy = textDocumentProxy else { return false }
        let before = proxy.documentContextBeforeInput ?? ""
        let after = proxy.documentContextAfterInput ?? ""
        return !before.isEmpty || !after.isEmpty
    }

    var body: some View {
        Button(action: {
            // This won't be called when using gesture
        }) {
            ZStack {
                // Base space bar with SwiftSpeak logo silhouette
                HStack(spacing: 0) {
                    Spacer()
                    Image("SwiftSpeakLogo")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 52)
                        .foregroundStyle(cursorController.cursorModeActive ? KeyboardTheme.accent : KeyboardTheme.keyText.opacity(0.3))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: KeyboardTheme.keyHeight)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isPressed ? KeyboardTheme.keyBackgroundPressed : KeyboardTheme.keyBackground)
                        .shadow(
                            color: KeyboardTheme.keyShadow,
                            radius: KeyboardTheme.keyShadowRadius,
                            x: KeyboardTheme.keyShadowOffset.width,
                            y: KeyboardTheme.keyShadowOffset.height
                        )
                )

                // Cursor mode overlay
                if cursorController.cursorModeActive {
                    CursorModeOverlay()
                }
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if cursorController.cursorModeActive {
                        // In cursor mode - handle drag for cursor movement
                        cursorController.handleDrag(to: value.location)
                    } else {
                        // Not in cursor mode yet - handle press and start long-press timer
                        if !isPressed {
                            isPressed = true
                            dragStartPosition = value.startLocation
                            startLongPressTimer(at: value.startLocation)
                        }
                    }
                }
                .onEnded { _ in
                    if cursorController.cursorModeActive {
                        // Exit cursor mode
                        exitCursorMode()
                    } else {
                        // Was a tap - insert space
                        cancelLongPressTimer()
                        if isPressed {
                            KeyboardHaptics.lightTap()
                            action()
                        }
                    }
                    isPressed = false
                    dragStartPosition = nil
                }
        )
        .onAppear {
            cursorController.textDocumentProxy = textDocumentProxy
        }
    }

    // MARK: - Long Press Handling

    private func startLongPressTimer(at position: CGPoint) {
        // Only start timer if there's text to navigate
        guard hasTextToNavigate else { return }

        cancelLongPressTimer()

        // Start timer for long press (500ms)
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [position] _ in
            guard isPressed else { return }
            enterCursorMode(at: position)
        }
    }

    private func cancelLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }

    private func enterCursorMode(at position: CGPoint) {
        cancelLongPressTimer()
        cursorController.enterCursorMode(at: position)
    }

    private func exitCursorMode() {
        cursorController.exitCursorMode()
    }
}

// MARK: - Cursor Mode Overlay

/// Visual indicator showing cursor control is active
struct CursorModeOverlay: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(KeyboardTheme.accent)

            Image(systemName: "arrow.left.and.right")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(KeyboardTheme.accent)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(KeyboardTheme.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(KeyboardTheme.accent.opacity(0.2))
        )
        .overlay(
            Capsule()
                .strokeBorder(KeyboardTheme.accent.opacity(0.4), lineWidth: 1)
        )
        .transition(.scale.combined(with: .opacity))
    }
}

#Preview {
    VStack(spacing: 10) {
        // Normal state
        SpaceBar(action: {}, textDocumentProxy: nil)
            .frame(width: 250)

        // Simulated cursor mode
        ZStack {
            Image("SwiftSpeakLogo")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 52)
                .foregroundStyle(KeyboardTheme.accent)
                .frame(maxWidth: .infinity)
                .frame(height: KeyboardTheme.keyHeight)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(KeyboardTheme.keyBackground)
                )

            CursorModeOverlay()
        }
        .frame(width: 250)
    }
    .padding()
    .background(KeyboardTheme.keyboardBackground)
    .preferredColorScheme(.dark)
}
