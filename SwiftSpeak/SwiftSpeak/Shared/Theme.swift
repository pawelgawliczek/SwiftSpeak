//
//  Theme.swift
//  SwiftSpeak
//
//  Centralized design system following branding guidelines
//  iOS 17+ Human Interface Guidelines compliant
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import SwiftUI
import SwiftSpeakCore
import UIKit

// MARK: - App Theme
/// Centralized theme configuration following branding guidelines
struct AppTheme {
    // MARK: - Colors

    /// Base background colors
    static let darkBase = Color(hex: "#1C1C1E")
    static let darkElevated = Color(hex: "#2C2C2E")
    static let lightBase = Color(hex: "#F2F2F7")

    /// Primary accent color - bright indigo blue
    static let accent = Color(red: 0.35, green: 0.45, blue: 0.95)

    /// Secondary accent for gradients
    static let accentSecondary = Color(red: 0.55, green: 0.35, blue: 0.90)

    /// Accent gradient for primary actions
    static let accentGradient = LinearGradient(
        colors: [accent, accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Pro tier gradient
    static let proGradient = LinearGradient(
        colors: [Color.purple, Color.pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Power tier gradient (vibrant gold/orange)
    static let powerGradient = LinearGradient(
        colors: [Color.orange, Color.yellow],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Power accent color
    static let powerAccent = Color.orange

    /// Disabled/locked state gradient
    static let disabledGradient = LinearGradient(
        colors: [Color.gray, Color.gray.opacity(0.8)],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Confetti colors for celebrations
    static let confettiColors: [Color] = [
        accent,
        accent.opacity(0.8),
        accentSecondary.opacity(0.6),
        Color.green.opacity(0.7)
    ]

    // MARK: - Corner Radii (from branding guidelines)

    /// Small elements (buttons, keys): 6-8pt
    static let cornerRadiusSmall: CGFloat = 8

    /// Medium elements (cards, panels): 12pt
    static let cornerRadiusMedium: CGFloat = 12

    /// Large elements (modals): 16-20pt
    static let cornerRadiusLarge: CGFloat = 16

    /// Extra large (full cards): 24pt
    static let cornerRadiusXL: CGFloat = 24

    // MARK: - Shadows

    /// Standard card shadow
    static func cardShadow() -> some View {
        Color.black.opacity(0.3)
    }

    static let cardShadowRadius: CGFloat = 20
    static let cardShadowY: CGFloat = 5

    // MARK: - Animation

    /// Standard spring animation (dampingFraction 0.7-0.8)
    static let springAnimation = Animation.spring(dampingFraction: 0.75)

    /// Quick spring for buttons
    static let quickSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)

    /// Smooth spring for cards
    static let smoothSpring = Animation.spring(response: 0.5, dampingFraction: 0.8)

    // MARK: - Keyboard-Specific Properties

    /// Keyboard layout spacing
    static let keySpacing: CGFloat = 6
    static let rowSpacing: CGFloat = 12
    static let keyHeight: CGFloat = 46
    static let horizontalPadding: CGFloat = 3

    /// Keyboard key background colors (dark mode to match SwiftSpeak overlay)
    static let keyBackground: Color = Color(white: 0.22)
    static let keyBackgroundPressed: Color = Color(white: 0.30)
    static let actionKeyBackground: Color = Color(white: 0.18)
    static let actionKeyBackgroundPressed: Color = Color(white: 0.25)
    static let keyboardBackground: Color = Color(white: 0.12)

    /// Keyboard text colors
    static let keyText: Color = .white

    /// Keyboard shadows
    static let keyShadow: Color = .black.opacity(0.5)
    static let keyShadowRadius: CGFloat = 0
    static let keyShadowOffset: CGSize = CGSize(width: 0, height: 1)
}

// MARK: - Keyboard Theme Compatibility
/// Typealias for backward compatibility with keyboard extension code
typealias KeyboardTheme = AppTheme

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Haptic Manager
/// Centralized haptic feedback following branding guidelines
enum HapticManager {
    /// Light tap for minor interactions (key press)
    static func lightTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Medium tap for primary actions (start/stop recording)
    static func mediumTap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Heavy tap for significant actions
    static func heavyTap() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    /// Success notification (task complete)
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Warning notification
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Error notification
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    /// Selection changed (mode switch, picker)
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Keyboard Haptics
/// Keyboard-specific haptics that respect the haptic feedback setting
enum KeyboardHaptics {
    /// Check if haptic feedback is enabled in keyboard settings
    private static var isEnabled: Bool {
        let defaults = UserDefaults(suiteName: "group.pawelgawliczek.swiftspeak")
        // Use object(forKey:) because bool(forKey:) returns false for missing keys
        return (defaults?.object(forKey: "keyboardHapticFeedback") as? Bool) ?? true
    }

    /// Light tap for minor interactions (key press)
    static func lightTap() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Medium tap for primary actions (start/stop recording)
    static func mediumTap() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Heavy tap for significant actions
    static func heavyTap() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    /// Success notification (task complete)
    static func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Warning notification
    static func warning() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Error notification
    static func error() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    /// Selection changed (mode switch, picker)
    static func selection() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Glass Background Modifier
// Uses GlassBackground, glassBackground(), ThemedBackground, themedBackground() from SwiftSpeakCore

// MARK: - Primary Button Style
/// Standard primary button following branding guidelines
struct PrimaryButtonStyle: ButtonStyle {
    let isDisabled: Bool

    init(isDisabled: Bool = false) {
        self.isDisabled = isDisabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44) // Minimum touch target
            .padding(.vertical, 6)
            .background(isDisabled ? Color.gray : AppTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(AppTheme.quickSpring, value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style
/// Secondary/ghost button style
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .foregroundStyle(AppTheme.accent)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.vertical, 6)
            .background(AppTheme.accent.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(AppTheme.quickSpring, value: configuration.isPressed)
    }
}

// MARK: - Icon Button Style
/// Small icon button (globe, backspace, etc.)
struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(width: 44, height: 44)
            .background(Color.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(AppTheme.quickSpring, value: configuration.isPressed)
    }
}

// MARK: - Mode Badge
/// Capsule badge for displaying mode/status
struct ModeBadge: View {
    let icon: String
    let text: String
    let color: Color

    init(icon: String, text: String, color: Color = AppTheme.accent) {
        self.icon = icon
        self.text = text
        self.color = color
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.footnote.weight(.medium))
            Text(text)
                .font(.footnote.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Stat Item
/// Reusable stat display component
struct ThemedStatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(AppTheme.accent)

            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview
#Preview("Theme Components") {
    ScrollView {
        VStack(spacing: 24) {
            // Accent colors
            HStack(spacing: 16) {
                Circle()
                    .fill(AppTheme.accent)
                    .frame(width: 50, height: 50)
                Circle()
                    .fill(AppTheme.accentSecondary)
                    .frame(width: 50, height: 50)
                Circle()
                    .fill(AppTheme.accentGradient)
                    .frame(width: 50, height: 50)
            }

            // Buttons
            Button("Primary Button") {}
                .buttonStyle(PrimaryButtonStyle())

            Button("Secondary Button") {}
                .buttonStyle(SecondaryButtonStyle())

            // Glass card
            VStack {
                Text("Glass Card")
                    .font(.headline)
                Text("Translucent background")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .glassBackground()

            // Mode badge
            ModeBadge(icon: "envelope.fill", text: "Email")

            // Stats
            HStack(spacing: 24) {
                ThemedStatItem(icon: "waveform", value: "12", label: "Recordings")
                ThemedStatItem(icon: "clock", value: "5m", label: "Time")
            }
            .padding()
            .glassBackground()
        }
        .padding()
    }
    .background(AppTheme.darkBase)
    .preferredColorScheme(.dark)
}
