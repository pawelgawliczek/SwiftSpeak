//
//  KeyboardTheme.swift
//  SwiftSpeakKeyboard
//
//  Design system for keyboard extension (mirrors main app Theme.swift)
//  iOS 17+ Human Interface Guidelines compliant
//
//  IMPORTANT: Keep in sync with SwiftSpeak/Theme.swift
//

import SwiftUI
import UIKit

// MARK: - Keyboard Theme
/// Centralized theme for keyboard extension
/// Mirrors AppTheme from main app (extensions can't share code)
struct KeyboardTheme {
    // MARK: - Colors

    /// Dark mode base: #1C1C1E (iOS system dark)
    static let darkBase = Color(hex: "#1C1C1E")

    /// Dark mode elevated: #2C2C2E
    static let darkElevated = Color(hex: "#2C2C2E")

    /// Light mode base: #F2F2F7 (iOS system light)
    static let lightBase = Color(hex: "#F2F2F7")

    /// Primary accent color - bright indigo blue
    static let accent = Color(red: 0.35, green: 0.45, blue: 0.95)

    /// Secondary accent for gradients
    static let accentSecondary = Color(red: 0.55, green: 0.35, blue: 0.90)

    /// Accent gradient for primary actions (topLeading → bottomTrailing)
    static let accentGradient = LinearGradient(
        colors: [accent, accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Pro tier gradient (purple → pink)
    static let proGradient = LinearGradient(
        colors: [Color.purple, Color.pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Power tier gradient (pink → orange)
    static let powerGradient = LinearGradient(
        colors: [Color.pink, Color.orange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Disabled/locked state gradient
    static let disabledGradient = LinearGradient(
        colors: [Color.gray, Color.gray.opacity(0.8)],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - Corner Radii (iOS 17+ HIG)

    /// Small elements (badges, small buttons): 8pt
    static let cornerRadiusSmall: CGFloat = 8

    /// Medium elements (cards, inputs): 12pt
    static let cornerRadiusMedium: CGFloat = 12

    /// Large elements (modals, sheets): 16pt
    static let cornerRadiusLarge: CGFloat = 16

    /// Extra large (full cards): 24pt
    static let cornerRadiusXL: CGFloat = 24

    // MARK: - Shadows

    /// Standard card shadow radius
    static let cardShadowRadius: CGFloat = 20

    /// Standard card shadow Y offset
    static let cardShadowY: CGFloat = 5

    // MARK: - Animation (physics-based springs)

    /// Standard spring animation (dampingFraction 0.75)
    static let springAnimation = Animation.spring(dampingFraction: 0.75)

    /// Quick spring for buttons (response 0.3, damping 0.7)
    static let quickSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)

    /// Smooth spring for cards (response 0.5, damping 0.8)
    static let smoothSpring = Animation.spring(response: 0.5, dampingFraction: 0.8)
}

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

// MARK: - Keyboard Haptics
/// Centralized haptic feedback for keyboard extension
/// Uses prepared generators for reliable feedback in extensions
enum KeyboardHaptics {
    // Pre-created generators for better performance
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    /// Prepare all generators (call on keyboard load)
    static func prepare() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }

    /// Light tap for minor interactions (key press)
    static func lightTap() {
        lightGenerator.impactOccurred()
        lightGenerator.prepare()
    }

    /// Medium tap for primary actions (start/stop recording)
    static func mediumTap() {
        mediumGenerator.impactOccurred()
        mediumGenerator.prepare()
    }

    /// Heavy tap for significant actions
    static func heavyTap() {
        heavyGenerator.impactOccurred()
        heavyGenerator.prepare()
    }

    /// Success notification (task complete)
    static func success() {
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    /// Warning notification
    static func warning() {
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }

    /// Error notification
    static func error() {
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
    }

    /// Selection changed (mode switch, picker)
    static func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }
}

// MARK: - HapticManager Alias
/// Alias for compatibility with main app code
typealias HapticManager = KeyboardHaptics
