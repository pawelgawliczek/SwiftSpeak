//
//  TierBadge.swift
//  SwiftSpeak
//
//  Phase 7: Small badge to indicate PRO or POWER features
//

import SwiftUI
import SwiftSpeakCore

/// A compact badge indicating subscription tier requirement
/// Used to mark premium features in lists and UI elements
struct TierBadge: View {
    let tier: SubscriptionTier
    var compact: Bool = false

    var body: some View {
        if compact {
            // Compact mode: Just a colored dot
            Circle()
                .fill(tierGradient)
                .frame(width: 8, height: 8)
        } else {
            // Full mode: Capsule with tier name
            Text(tier.displayName.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(tierGradient)
                .clipShape(Capsule())
        }
    }

    // MARK: - Private

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

extension TierBadge {
    /// Creates a PRO tier badge
    static var pro: TierBadge {
        TierBadge(tier: .pro)
    }

    /// Creates a POWER tier badge
    static var power: TierBadge {
        TierBadge(tier: .power)
    }

    /// Creates a compact PRO tier badge (dot only)
    static var proCompact: TierBadge {
        TierBadge(tier: .pro, compact: true)
    }

    /// Creates a compact POWER tier badge (dot only)
    static var powerCompact: TierBadge {
        TierBadge(tier: .power, compact: true)
    }
}

// MARK: - Preview

#Preview("TierBadge Variants") {
    VStack(spacing: 24) {
        // Full badges
        HStack(spacing: 16) {
            TierBadge(tier: .free)
            TierBadge(tier: .pro)
            TierBadge(tier: .power)
        }

        // Compact badges
        HStack(spacing: 16) {
            TierBadge(tier: .free, compact: true)
            TierBadge(tier: .pro, compact: true)
            TierBadge(tier: .power, compact: true)
        }

        // Static convenience
        HStack(spacing: 16) {
            TierBadge.pro
            TierBadge.power
        }

        // In context - feature row
        HStack {
            Image(systemName: "bolt.fill")
                .foregroundStyle(.orange)
            Text("Power Modes")
            Spacer()
            TierBadge.power
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
    }
    .padding()
    .background(AppTheme.darkBase)
    .preferredColorScheme(.dark)
}
