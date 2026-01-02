//
//  AccentPopup.swift
//  SwiftSpeakKeyboard
//
//  Accent selection popup that appears on long-press of letter keys
//

import SwiftUI

// MARK: - Accent Popup
struct AccentPopup: View {
    let accents: [String]
    let keyFrame: CGRect
    let shiftState: ShiftState
    let onSelect: (String) -> Void
    let onCancel: () -> Void
    var keyboardFrame: CGRect = .zero  // Parent keyboard frame for relative positioning

    @State private var selectedIndex: Int = -1
    @GestureState private var dragLocation: CGPoint = .zero

    // Sizing constants
    private let bubbleWidth: CGFloat = 40
    private let bubbleHeight: CGFloat = 46
    private let bubbleSpacing: CGFloat = 2
    private let pointerHeight: CGFloat = 8

    private var totalWidth: CGFloat {
        CGFloat(accents.count) * bubbleWidth + CGFloat(accents.count - 1) * bubbleSpacing
    }

    // Calculate position relative to keyboard's coordinate system
    private func popupX(in containerWidth: CGFloat) -> CGFloat {
        let localKeyMidX = keyFrame.midX - keyboardFrame.minX
        var x = localKeyMidX

        // Keep popup within screen bounds
        let margin: CGFloat = 8
        let halfWidth = totalWidth / 2
        if x - halfWidth < margin {
            x = margin + halfWidth
        } else if x + halfWidth > containerWidth - margin {
            x = containerWidth - margin - halfWidth
        }

        return x
    }

    private var popupY: CGFloat {
        // Position above the key
        let localKeyMinY = keyFrame.minY - keyboardFrame.minY
        return localKeyMinY - bubbleHeight / 2 - pointerHeight
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background overlay (invisible, for tap-to-cancel)
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onCancel()
                    }

                // Accent bubbles - positioned above the key
                HStack(spacing: bubbleSpacing) {
                    ForEach(Array(accents.enumerated()), id: \.offset) { index, accent in
                        accentBubble(for: accent, at: index)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(KeyboardTheme.actionKeyBackground)
                        .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
                )
                .position(x: popupX(in: geometry.size.width), y: popupY)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($dragLocation) { value, state, _ in
                    state = value.location
                    updateSelection(at: value.location, containerWidth: UIScreen.main.bounds.width)
                }
                .onEnded { value in
                    if selectedIndex >= 0 && selectedIndex < accents.count {
                        onSelect(accents[selectedIndex])
                    } else {
                        onCancel()
                    }
                }
        )
    }

    // MARK: - Accent Bubble

    @ViewBuilder
    private func accentBubble(for accent: String, at index: Int) -> some View {
        let isSelected = selectedIndex == index

        Text(accent)
            .font(.system(size: 24, weight: .regular))
            .foregroundStyle(KeyboardTheme.keyText)
            .frame(width: bubbleWidth, height: bubbleHeight)
            .background(
                isSelected ?
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(KeyboardTheme.accent)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    : nil
            )
            .scaleEffect(isSelected ? 1.15 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
    }

    // MARK: - Selection Logic

    private func updateSelection(at location: CGPoint, containerWidth: CGFloat) {
        // Calculate popup center position
        let centerX = popupX(in: containerWidth)
        let centerY = popupY

        // Check if within vertical bounds (with some tolerance)
        let tolerance: CGFloat = 30
        guard location.y >= centerY - bubbleHeight/2 - tolerance &&
              location.y <= centerY + bubbleHeight/2 + tolerance else {
            selectedIndex = -1
            return
        }

        // Calculate which bubble based on horizontal position
        let popupLeft = centerX - totalWidth / 2
        let relativeX = location.x - popupLeft

        if relativeX < 0 || relativeX > totalWidth {
            selectedIndex = -1
            return
        }

        // Calculate which bubble
        let singleBubbleWidth = bubbleWidth + bubbleSpacing
        let index = Int(relativeX / singleBubbleWidth)

        if index >= 0 && index < accents.count {
            selectedIndex = index
        } else {
            selectedIndex = -1
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(white: 0.82)
            .ignoresSafeArea()

        // Simulate a key frame
        let keyFrame = CGRect(x: 100, y: 300, width: 36, height: 42)

        // Simulated key (for visual reference)
        Rectangle()
            .fill(Color.white)
            .frame(width: keyFrame.width, height: keyFrame.height)
            .position(x: keyFrame.midX, y: keyFrame.midY)

        // Accent popup
        AccentPopup(
            accents: ["á", "à", "â", "ä", "ã", "å"],
            keyFrame: keyFrame,
            shiftState: .lowercase,
            onSelect: { accent in
                print("Selected: \(accent)")
            },
            onCancel: {
                print("Cancelled")
            }
        )
    }
    .preferredColorScheme(.dark)
}
