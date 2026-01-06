//
//  SubscriptionCard.swift
//  SwiftSpeak
//
//  Subscription status card component
//

import SwiftUI
import SwiftSpeakCore

// MARK: - Subscription Card

struct SubscriptionCard: View {
    let tier: SubscriptionTier
    let onUpgrade: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var cardBackground: LinearGradient {
        if tier == .free {
            return LinearGradient(
                colors: colorScheme == .dark ?
                    [Color.white.opacity(0.1), Color.white.opacity(0.05)] :
                    [Color.black.opacity(0.05), Color.black.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [AppTheme.accent.opacity(0.3), AppTheme.accentSecondary.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Plan")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Text(tier.displayName)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)

                        if tier != .free {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                }

                Spacer()

                if tier == .free {
                    Button(action: {
                        HapticManager.lightTap()
                        onUpgrade()
                    }) {
                        Text("Upgrade")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(AppTheme.accentGradient)
                            .clipShape(Capsule())
                    }
                } else if tier == .pro {
                    Button(action: {
                        HapticManager.lightTap()
                        onUpgrade()
                    }) {
                        Text("Go Power")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.accent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }

            // Different messages based on tier
            switch tier {
            case .free:
                Text("Unlock unlimited transcriptions, multiple providers, and more!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .pro:
                Text("Unlimited transcriptions & multiple providers unlocked!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .power:
                Text("All features unlocked. Thank you for your support!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

#Preview("Subscription Card - Free") {
    SubscriptionCard(tier: .free, onUpgrade: {})
        .preferredColorScheme(.dark)
}

#Preview("Subscription Card - Pro") {
    SubscriptionCard(tier: .pro, onUpgrade: {})
        .preferredColorScheme(.dark)
}

#Preview("Subscription Card - Power") {
    SubscriptionCard(tier: .power, onUpgrade: {})
        .preferredColorScheme(.dark)
}
