//
//  LetterKey.swift
//  SwiftSpeakKeyboard
//
//  Individual letter key component with accent popup on long press
//

import SwiftUI

// MARK: - Letter Key
struct LetterKey: View {
    let letter: String
    let shiftState: ShiftState
    let action: () -> Void
    let onShowAccentPopup: ((String, CGRect) -> Void)?

    @State private var keyFrame: CGRect = .zero
    @State private var pressStartTime: Date?
    @State private var didTriggerHaptic = false

    private var hasPopup: Bool {
        AccentMappings.hasPopup(letter)
    }

    /// Long press threshold for accent popup (400ms)
    private let longPressDuration: TimeInterval = 0.4

    var body: some View {
        GeometryReader { geometry in
            Button(action: {
                // Action handled by gesture for long-press detection
            }) {
                Text(letter)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(KeyboardTheme.keyText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(KeyboardTheme.keyBackground)
                            .shadow(
                                color: KeyboardTheme.keyShadow,
                                radius: KeyboardTheme.keyShadowRadius,
                                x: KeyboardTheme.keyShadowOffset.width,
                                y: KeyboardTheme.keyShadowOffset.height
                            )
                    )
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        // First touch - record time and haptic
                        if pressStartTime == nil {
                            pressStartTime = Date()
                            didTriggerHaptic = false
                        }
                        // Trigger haptic immediately on touch
                        if !didTriggerHaptic {
                            didTriggerHaptic = true
                            KeyboardHaptics.lightTap()
                        }
                    }
                    .onEnded { _ in
                        guard let startTime = pressStartTime else { return }
                        let pressDuration = Date().timeIntervalSince(startTime)
                        pressStartTime = nil
                        didTriggerHaptic = false

                        if pressDuration >= longPressDuration {
                            // Long press - show accent popup if available
                            if hasPopup, let onShowAccentPopup = onShowAccentPopup {
                                let frame = geometry.frame(in: .global)
                                KeyboardHaptics.mediumTap()
                                onShowAccentPopup(letter, frame)
                            } else {
                                // No popup, just insert the letter
                                action()
                            }
                        } else {
                            // Quick tap - insert letter
                            action()
                        }
                    }
            )
            .onAppear {
                keyFrame = geometry.frame(in: .global)
            }
            .onChange(of: geometry.frame(in: .global)) { _, newFrame in
                keyFrame = newFrame
            }
        }
        .frame(height: KeyboardTheme.keyHeight)
    }

}

#Preview {
    VStack(spacing: 10) {
        HStack(spacing: 6) {
            LetterKey(letter: "Q", shiftState: .shift, action: { }, onShowAccentPopup: nil)
            LetterKey(letter: "W", shiftState: .shift, action: { }, onShowAccentPopup: nil)
            LetterKey(letter: "E", shiftState: .shift, action: { }, onShowAccentPopup: nil)
        }
        HStack(spacing: 6) {
            LetterKey(letter: "a", shiftState: .lowercase, action: { }, onShowAccentPopup: { letter, frame in
                print("Show accents for \(letter) at \(frame)")
            })
            LetterKey(letter: "s", shiftState: .lowercase, action: { }, onShowAccentPopup: nil)
            LetterKey(letter: "d", shiftState: .lowercase, action: { }, onShowAccentPopup: nil)
        }
    }
    .padding()
    .background(KeyboardTheme.keyboardBackground)
    .preferredColorScheme(.dark)
}
