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
                Button(action: {
                    KeyboardHaptics.mediumTap()
                    onSearch()
                    onDismiss()
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 32)
                        .background(KeyboardTheme.accent, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)

                ForEach(rows[2], id: \.self) { key in
                    SearchKey(letter: key) {
                        text += key
                        KeyboardHaptics.lightTap()
                    }
                }

                // Backspace button
                Button(action: {
                    if !text.isEmpty {
                        text.removeLast()
                        KeyboardHaptics.lightTap()
                    }
                }) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 16))
                        .foregroundStyle(.black)
                        .frame(width: 38, height: 32)
                        .background(Color(white: 0.67), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            // Space and close row
            HStack(spacing: 4) {
                // Space bar
                Button(action: {
                    text += " "
                    KeyboardHaptics.lightTap()
                }) {
                    Text("space")
                        .font(.system(size: 14))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)

                // Clear button
                Button(action: {
                    text = ""
                    KeyboardHaptics.lightTap()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 32)
                        .background(Color(white: 0.67), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)

                // Done button
                Button(action: {
                    KeyboardHaptics.mediumTap()
                    onDismiss()
                }) {
                    Text("Done")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 32)
                        .background(KeyboardTheme.accent, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
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

    var body: some View {
        Button(action: action) {
            Text(letter)
                .font(.system(size: 18))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
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
