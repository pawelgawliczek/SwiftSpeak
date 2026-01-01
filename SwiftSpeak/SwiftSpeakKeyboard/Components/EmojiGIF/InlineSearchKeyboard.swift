//
//  InlineSearchKeyboard.swift
//  SwiftSpeakKeyboard
//
//  Phase 13.9: Inline keyboard for search within emoji/GIF panels
//  iOS keyboard extensions can't show another keyboard, so we provide our own
//

import SwiftUI

struct InlineSearchKeyboard: View {
    @Binding var text: String
    let onDismiss: () -> Void
    let onSearch: () -> Void

    private let rows = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"]
    ]

    var body: some View {
        VStack(spacing: 4) {
            // Row 1
            HStack(spacing: 3) {
                ForEach(rows[0], id: \.self) { key in
                    SearchKey(letter: key) {
                        text += key
                        KeyboardHaptics.lightTap()
                    }
                }
            }

            // Row 2 (centered)
            HStack(spacing: 3) {
                ForEach(rows[1], id: \.self) { key in
                    SearchKey(letter: key) {
                        text += key
                        KeyboardHaptics.lightTap()
                    }
                }
            }
            .padding(.horizontal, 14)

            // Row 3 with backspace and done
            HStack(spacing: 3) {
                // Done/Search button
                SearchActionKey(
                    content: AnyView(
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    ),
                    backgroundColor: KeyboardTheme.accent,
                    width: 38
                ) {
                    KeyboardHaptics.mediumTap()
                    onSearch()
                    onDismiss()
                }

                ForEach(rows[2], id: \.self) { key in
                    SearchKey(letter: key) {
                        text += key
                        KeyboardHaptics.lightTap()
                    }
                }

                // Backspace button
                SearchActionKey(
                    content: AnyView(
                        Image(systemName: "delete.left")
                            .font(.system(size: 16))
                            .foregroundStyle(.black)
                    ),
                    backgroundColor: Color(white: 0.67),
                    width: 38
                ) {
                    if !text.isEmpty {
                        text.removeLast()
                        KeyboardHaptics.lightTap()
                    }
                }
            }

            // Space and close row
            HStack(spacing: 4) {
                // Space bar
                SearchActionKey(
                    content: AnyView(
                        Text("space")
                            .font(.system(size: 14))
                            .foregroundStyle(.black)
                    ),
                    backgroundColor: .white,
                    width: nil
                ) {
                    text += " "
                    KeyboardHaptics.lightTap()
                }

                // Clear button
                SearchActionKey(
                    content: AnyView(
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    ),
                    backgroundColor: Color(white: 0.67),
                    width: 44
                ) {
                    text = ""
                    KeyboardHaptics.lightTap()
                }

                // Done button
                SearchActionKey(
                    content: AnyView(
                        Text("Done")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                    ),
                    backgroundColor: KeyboardTheme.accent,
                    width: 60
                ) {
                    KeyboardHaptics.mediumTap()
                    onDismiss()
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(Color(white: 0.82))
    }
}

// MARK: - Search Key
private struct SearchKey: View {
    let letter: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Text(letter)
            .font(.system(size: 18))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isPressed ? Color(white: 0.85) : Color.white)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        action()
                    }
            )
    }
}

// MARK: - Search Action Key (for space, backspace, done, etc.)
private struct SearchActionKey: View {
    let content: AnyView
    let backgroundColor: Color
    let width: CGFloat?
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        content
            .frame(maxWidth: width == nil ? .infinity : nil)
            .frame(width: width, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isPressed ? backgroundColor.opacity(0.7) : backgroundColor)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        action()
                    }
            )
    }
}

// MARK: - Preview
#Preview {
    InlineSearchKeyboard(
        text: .constant("hello"),
        onDismiss: {},
        onSearch: {}
    )
    .preferredColorScheme(.dark)
}
