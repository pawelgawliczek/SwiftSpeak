//
//  UpgradePromptBanner.swift
//  SwiftSpeak
//
//  Phase 7: Inline banner with upgrade call-to-action
//

import SwiftUI

/// An inline banner prompting users to upgrade
/// Used in lists and settings to subtly suggest upgrading
struct UpgradePromptBanner: View {
    let tier: SubscriptionTier
    let message: String
    var compact: Bool = false
    let onUpgrade: () -> Void

    var body: some View {
        if compact {
            compactBanner
        } else {
            fullBanner
        }
    }

    // MARK: - Full Banner

    private var fullBanner: some View {
        HStack(spacing: 12) {
            // Lock icon
            Image(systemName: "lock.fill")
                .font(.body.weight(.medium))
                .foregroundStyle(tierColor)

            // Message
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer()

            // Upgrade button
            Button(action: {
                HapticManager.mediumTap()
                onUpgrade()
            }) {
                Text("Upgrade")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(tierGradient)
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(tierColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .stroke(tierColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Compact Banner

    private var compactBanner: some View {
        Button(action: {
            HapticManager.mediumTap()
            onUpgrade()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.caption.weight(.medium))
                Text("Upgrade to \(tier.displayName)")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tierGradient)
            .clipShape(Capsule())
        }
    }

    // MARK: - Private

    private var tierColor: Color {
        switch tier {
        case .free:
            return .gray
        case .pro:
            return .purple
        case .power:
            return .orange
        }
    }

    private var tierGradient: LinearGradient {
        switch tier {
        case .free:
            return AppTheme.disabledGradient
        case .pro:
            return AppTheme.proGradient
        case .power:
            return AppTheme.powerGradient
        }
    }
}

// MARK: - Convenience Initializers

extension UpgradePromptBanner {
    /// Creates a Pro upgrade banner with default message
    static func pro(message: String = "Unlock this feature with Pro", onUpgrade: @escaping () -> Void) -> UpgradePromptBanner {
        UpgradePromptBanner(tier: .pro, message: message, onUpgrade: onUpgrade)
    }

    /// Creates a Power upgrade banner with default message
    static func power(message: String = "Unlock this feature with Power", onUpgrade: @escaping () -> Void) -> UpgradePromptBanner {
        UpgradePromptBanner(tier: .power, message: message, onUpgrade: onUpgrade)
    }
}

// MARK: - Preview

#Preview("UpgradePromptBanner") {
    VStack(spacing: 24) {
        // Pro banner - full
        UpgradePromptBanner(
            tier: .pro,
            message: "Unlock unlimited transcriptions and custom templates",
            onUpgrade: {}
        )

        // Power banner - full
        UpgradePromptBanner(
            tier: .power,
            message: "Access AI Power Modes for advanced workflows",
            onUpgrade: {}
        )

        // Pro banner - compact
        UpgradePromptBanner(
            tier: .pro,
            message: "",
            compact: true,
            onUpgrade: {}
        )

        // Power banner - compact
        UpgradePromptBanner(
            tier: .power,
            message: "",
            compact: true,
            onUpgrade: {}
        )

        // Using convenience initializers
        UpgradePromptBanner.pro(message: "Translation requires Pro") {}
        UpgradePromptBanner.power(message: "Power Modes require Power tier") {}
    }
    .padding()
    .background(AppTheme.darkBase)
    .preferredColorScheme(.dark)
}
