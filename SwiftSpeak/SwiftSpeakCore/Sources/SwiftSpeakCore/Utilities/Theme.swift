import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct AppTheme {
    public static let darkBase = Color(hex: "#1C1C1E")
    public static let darkElevated = Color(hex: "#2C2C2E")
    public static let lightBase = Color(hex: "#F2F2F7")
    public static let accent = Color(red: 0.35, green: 0.45, blue: 0.95)
    public static let accentSecondary = Color(red: 0.55, green: 0.35, blue: 0.90)
    public static let accentGradient = LinearGradient(colors: [accent, accentSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
    public static let proGradient = LinearGradient(colors: [Color.purple, Color.pink], startPoint: .topLeading, endPoint: .bottomTrailing)
    public static let powerGradient = LinearGradient(colors: [Color.orange, Color.yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
    public static let powerAccent = Color.orange
    public static let disabledGradient = LinearGradient(colors: [Color.gray, Color.gray.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
    public static let confettiColors: [Color] = [accent, accent.opacity(0.8), accentSecondary.opacity(0.6), Color.green.opacity(0.7)]
    public static let cornerRadiusSmall: CGFloat = 8
    public static let cornerRadiusMedium: CGFloat = 12
    public static let cornerRadiusLarge: CGFloat = 16
    public static let cornerRadiusXL: CGFloat = 24
    public static func cardShadow() -> some View { Color.black.opacity(0.3) }
    public static let cardShadowRadius: CGFloat = 20
    public static let cardShadowY: CGFloat = 5
    public static let springAnimation = Animation.spring(dampingFraction: 0.75)
    public static let quickSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    public static let smoothSpring = Animation.spring(response: 0.5, dampingFraction: 0.8)
    public static let keySpacing: CGFloat = 6
    public static let rowSpacing: CGFloat = 12
    public static let keyHeight: CGFloat = 46
    public static let horizontalPadding: CGFloat = 3
    public static let keyBackground: Color = Color(white: 0.22)
    public static let keyBackgroundPressed: Color = Color(white: 0.30)
    public static let actionKeyBackground: Color = Color(white: 0.18)
    public static let actionKeyBackgroundPressed: Color = Color(white: 0.25)
    public static let keyboardBackground: Color = Color(white: 0.12)
    public static let keyText: Color = .white
    public static let keyShadow: Color = .black.opacity(0.5)
    public static let keyShadowRadius: CGFloat = 0
    public static let keyShadowOffset: CGSize = CGSize(width: 0, height: 1)
}
public typealias KeyboardTheme = AppTheme
public extension Color {
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
#if os(iOS)
public enum HapticManager {
    public static func lightTap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    public static func mediumTap() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    public static func heavyTap() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    public static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    public static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    public static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    public static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}
#endif
#if os(macOS)
public enum HapticManager {
    public static func lightTap() {}
    public static func mediumTap() {}
    public static func heavyTap() {}
    public static func success() {}
    public static func warning() {}
    public static func error() {}
    public static func selection() {}
}
#endif
public struct GlassBackground: ViewModifier {
    public let cornerRadius: CGFloat; let includeShadow: Bool
    public init(cornerRadius: CGFloat = AppTheme.cornerRadiusMedium, includeShadow: Bool = true) { self.cornerRadius = cornerRadius; self.includeShadow = includeShadow }
    public func body(content: Content) -> some View { content.background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)).shadow(color: includeShadow ? .black.opacity(0.3) : .clear, radius: includeShadow ? AppTheme.cardShadowRadius : 0, x: 0, y: includeShadow ? AppTheme.cardShadowY : 0) }
}
public extension View { func glassBackground(cornerRadius: CGFloat = AppTheme.cornerRadiusMedium, includeShadow: Bool = true) -> some View { modifier(GlassBackground(cornerRadius: cornerRadius, includeShadow: includeShadow)) } }
public struct ThemedBackground: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    public init() {}
    public func body(content: Content) -> some View { content.background(colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase) }
}
public extension View { func themedBackground() -> some View { modifier(ThemedBackground()) } }
public struct PrimaryButtonStyle: ButtonStyle {
    public let isDisabled: Bool
    public init(isDisabled: Bool = false) { self.isDisabled = isDisabled }
    public func makeBody(configuration: Configuration) -> some View { configuration.label.font(.callout.weight(.semibold)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(minHeight: 44).padding(.vertical, 6).background(isDisabled ? Color.gray : AppTheme.accent).clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)).scaleEffect(configuration.isPressed ? 0.97 : 1.0).animation(AppTheme.quickSpring, value: configuration.isPressed) }
}
public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { configuration.label.font(.callout.weight(.medium)).foregroundStyle(AppTheme.accent).frame(maxWidth: .infinity).frame(minHeight: 44).padding(.vertical, 6).background(AppTheme.accent.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)).scaleEffect(configuration.isPressed ? 0.97 : 1.0).animation(AppTheme.quickSpring, value: configuration.isPressed) }
}
public struct IconButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { configuration.label.font(.body).foregroundStyle(.secondary).frame(width: 44, height: 44).background(Color.primary.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)).scaleEffect(configuration.isPressed ? 0.95 : 1.0).animation(AppTheme.quickSpring, value: configuration.isPressed) }
}
public struct ModeBadge: View {
    public let icon: String; let text: String; let color: Color
    public init(icon: String, text: String, color: Color = AppTheme.accent) { self.icon = icon; self.text = text; self.color = color }
    public var body: some View { HStack(spacing: 6) { Image(systemName: icon).font(.footnote.weight(.medium)); Text(text).font(.footnote.weight(.semibold)) }.foregroundStyle(color).padding(.horizontal, 12).padding(.vertical, 6).background(color.opacity(0.15)).clipShape(Capsule()) }
}
public struct ThemedStatItem: View {
    public let icon: String; let value: String; let label: String
    public init(icon: String, value: String, label: String) { self.icon = icon; self.value = value; self.label = label }
    public var body: some View { VStack(spacing: 4) { Image(systemName: icon).font(.callout).foregroundStyle(AppTheme.accent); Text(value).font(.headline).foregroundStyle(.primary); Text(label).font(.caption2).foregroundStyle(.secondary) } }
}

// MARK: - Keyboard Haptics (respects user preference)
#if os(iOS)
public enum KeyboardHaptics {
    private static var isEnabled: Bool {
        let defaults = UserDefaults(suiteName: "group.pawelgawliczek.swiftspeak")
        return (defaults?.object(forKey: "keyboardHapticFeedback") as? Bool) ?? true
    }
    // Minimal haptics: soft style with reduced intensity (0.0-1.0)
    public static func lightTap() { guard isEnabled else { return }; UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.3) }
    public static func mediumTap() { guard isEnabled else { return }; UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5) }
    public static func heavyTap() { guard isEnabled else { return }; UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6) }
    public static func success() { guard isEnabled else { return }; UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.4) }
    public static func warning() { guard isEnabled else { return }; UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5) }
    public static func error() { guard isEnabled else { return }; UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6) }
    public static func selection() { guard isEnabled else { return }; UISelectionFeedbackGenerator().selectionChanged() }
}
#elseif os(macOS)
public enum KeyboardHaptics {
    public static func lightTap() {}
    public static func mediumTap() {}
    public static func heavyTap() {}
    public static func success() {}
    public static func warning() {}
    public static func error() {}
    public static func selection() {}
}
#endif
