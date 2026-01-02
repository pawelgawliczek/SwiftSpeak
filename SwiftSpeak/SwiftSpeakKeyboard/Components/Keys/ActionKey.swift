//
//  ActionKey.swift
//  SwiftSpeakKeyboard
//
//  Special action keys: Shift, Backspace, Return, 123/ABC toggle
//

import SwiftUI
import UIKit

// MARK: - Action Key
struct ActionKey: View {
    var icon: String? = nil
    var text: String? = nil
    var isHighlighted: Bool = false
    let action: () -> Void
    var onLongPress: (() -> Void)? = nil
    var onSwipeDelete: ((Int) -> Void)? = nil  // Swipe delete: passes number of words to delete
    var enableLongPressRepeat: Bool = false    // Enable long-press repeat with acceleration (for backspace)

    @State private var isPressed = false
    @State private var longPressTimer: Timer?
    @State private var swipeStartX: CGFloat = 0
    @State private var isSwipeDeleting = false
    @State private var repeatCount = 0  // Track repeats for acceleration

    private var backgroundColor: Color {
        if isHighlighted {
            return KeyboardTheme.keyBackground
        }
        return KeyboardTheme.actionKeyBackground
    }

    private var pressedBackgroundColor: Color {
        if isHighlighted {
            return KeyboardTheme.keyBackgroundPressed
        }
        return KeyboardTheme.actionKeyBackgroundPressed
    }

    var body: some View {
        Button(action: {
            KeyboardHaptics.lightTap()
            action()
        }) {
            Group {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                } else if let text = text {
                    Text(text)
                        .font(.system(size: 15, weight: .regular))
                }
            }
            .foregroundStyle(KeyboardTheme.keyText)
            .frame(maxWidth: .infinity)
            .frame(height: KeyboardTheme.keyHeight)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isPressed ? pressedBackgroundColor : backgroundColor)
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
                .onChanged { value in
                    if !isPressed {
                        isPressed = true
                        swipeStartX = value.location.x
                        KeyboardHaptics.lightTap()

                        // Start long press timer for either onLongPress or repeat mode
                        if onLongPress != nil || enableLongPressRepeat {
                            startLongPressTimer()
                        }
                    }

                    // Check for swipe-delete (swipe left from backspace)
                    if let _ = onSwipeDelete {
                        let swipeDistance = swipeStartX - value.location.x
                        if swipeDistance > 30 && !isSwipeDeleting {
                            isSwipeDeleting = true
                            // Stop long-press repeat when swiping
                            stopLongPressTimer()
                            KeyboardHaptics.mediumTap()
                        }
                    }
                }
                .onEnded { value in
                    isPressed = false
                    stopLongPressTimer()
                    repeatCount = 0

                    // Handle swipe-delete on release
                    if isSwipeDeleting, let onSwipeDelete = onSwipeDelete {
                        let swipeDistance = swipeStartX - value.location.x
                        // Calculate words to delete based on swipe distance
                        let wordsToDelete = max(1, Int(swipeDistance / 50))
                        onSwipeDelete(wordsToDelete)
                        KeyboardHaptics.success()
                    }
                    isSwipeDeleting = false
                }
        )
    }

    // MARK: - Long Press Handling with Acceleration

    private func startLongPressTimer() {
        // Initial delay before repeat starts (400ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
            guard isPressed && !isSwipeDeleting else { return }
            scheduleNextRepeat()
        }
    }

    private func scheduleNextRepeat() {
        guard isPressed && !isSwipeDeleting else {
            stopLongPressTimer()
            return
        }

        // Calculate interval with acceleration
        // Start at 0.12s, accelerate to 0.03s over ~20 repeats
        let baseInterval: TimeInterval = 0.12
        let minInterval: TimeInterval = 0.03
        let accelerationFactor = min(Double(repeatCount) / 20.0, 1.0)
        let interval = baseInterval - (accelerationFactor * (baseInterval - minInterval))

        longPressTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            guard isPressed && !isSwipeDeleting else {
                stopLongPressTimer()
                return
            }

            // Execute action
            if enableLongPressRepeat {
                action()
                // Light haptic every 5 deletions, subtler feel
                if repeatCount % 5 == 0 {
                    KeyboardHaptics.lightTap()
                }
            } else if let onLongPress = onLongPress {
                onLongPress()
            }

            repeatCount += 1
            scheduleNextRepeat()
        }
    }

    private func stopLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }
}

#Preview {
    VStack(spacing: 10) {
        HStack(spacing: 6) {
            ActionKey(icon: "shift") { }
                .frame(width: 60)
            ActionKey(icon: "shift.fill", isHighlighted: true) { }
                .frame(width: 60)
            ActionKey(icon: "capslock.fill", isHighlighted: true) { }
                .frame(width: 60)
        }
        HStack(spacing: 6) {
            ActionKey(icon: "delete.left") { } onLongPress: { }
                .frame(width: 60)
            ActionKey(text: "123") { }
                .frame(width: 80)
            ActionKey(text: "return") { }
                .frame(width: 80)
        }
    }
    .padding()
    .background(KeyboardTheme.keyboardBackground)
    .preferredColorScheme(.dark)
}
