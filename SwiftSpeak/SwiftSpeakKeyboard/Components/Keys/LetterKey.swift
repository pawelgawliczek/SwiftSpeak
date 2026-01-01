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

    private var hasAccents: Bool {
        AccentMappings.hasAccents(letter)
    }

    var body: some View {
        GeometryReader { geometry in
            Button(action: {
                // Normal tap - insert letter
                KeyboardHaptics.lightTap()
                action()
            }) {
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
            }
            .buttonStyle(.plain)
            // Use LongPressGesture for accent popup instead of DragGesture
            // This allows parent swipe gesture to work
            .onLongPressGesture(minimumDuration: 0.4, pressing: { pressing in
                isPressed = pressing
            }) {
                // Long press completed - show accent popup
                if hasAccents, let onShowAccentPopup = onShowAccentPopup {
                    let frame = geometry.frame(in: .global)
                    KeyboardHaptics.mediumTap()
                    onShowAccentPopup(letter, frame)
                }
            }
            .onAppear {
                // Capture key frame for popup positioning
                keyFrame = geometry.frame(in: .global)
            }
            .onChange(of: geometry.frame(in: .global)) { _, newFrame in
                keyFrame = newFrame
            }
            // Phase 13.8: Report key frame for swipe typing
            .preference(
                key: KeyFramePreferenceKey.self,
                value: [letter.uppercased(): geometry.frame(in: .global)]
            )
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
