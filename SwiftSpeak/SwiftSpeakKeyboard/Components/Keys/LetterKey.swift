//
//  LetterKey.swift
//  SwiftSpeakKeyboard
//
//  Individual letter key component with press feedback and accent popup
//

import SwiftUI

// MARK: - Letter Key
struct LetterKey: View {
    let letter: String
    let shiftState: ShiftState
    let action: () -> Void
    let onShowAccentPopup: ((String, CGRect) -> Void)?

    @State private var isPressed = false
    @State private var keyFrame: CGRect = .zero

    private var hasPopup: Bool {
        AccentMappings.hasPopup(letter)
    }

    var body: some View {
        GeometryReader { geometry in
            Text(letter)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(KeyboardTheme.keyText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .contentShape(Rectangle())
                .gesture(
                    LongPressGesture(minimumDuration: 0.4)
                        .onChanged { _ in
                            // Finger down - show pressed state and haptic
                            if !isPressed {
                                isPressed = true
                                KeyboardHaptics.lightTap()
                            }
                        }
                        .onEnded { _ in
                            // Long press completed - show popup if available
                            isPressed = false
                            if hasPopup, let onShowAccentPopup = onShowAccentPopup {
                                let frame = geometry.frame(in: .global)
                                KeyboardHaptics.mediumTap()
                                onShowAccentPopup(letter, frame)
                            } else {
                                // No popup, just insert the letter
                                action()
                            }
                        }
                )
                .simultaneousGesture(
                    TapGesture()
                        .onEnded {
                            // Quick tap - insert letter
                            KeyboardHaptics.lightTap()
                            action()
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
