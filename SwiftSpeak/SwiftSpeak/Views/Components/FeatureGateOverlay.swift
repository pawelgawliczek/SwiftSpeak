//
//  FeatureGateOverlay.swift
//  SwiftSpeak
//
//  Phase 7: Full-screen overlay for gated premium features
//

import SwiftUI
import SwiftSpeakCore

/// A blur overlay that blocks access to premium features
/// Shows a lock icon, feature name, and upgrade call-to-action
struct FeatureGateOverlay: View {
    let requiredTier: SubscriptionTier
    let featureName: String
    let featureDescription: String
    let onUpgrade: () -> Void
    var onDismiss: (() -> Void)?

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Blur background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            // Content
            VStack(spacing: 24) {
                Spacer()

                // Lock icon with tier gradient
                ZStack {
                    Circle()
                        .fill(tierColor.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Circle()
                        .fill(tierGradient)
                        .frame(width: 80, height: 80)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.white)
                }
                .scaleEffect(isAnimating ? 1.0 : 0.8)
                .opacity(isAnimating ? 1.0 : 0.0)

                // Feature name
                VStack(spacing: 8) {
                    Text(featureName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)

                    Text(featureDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .opacity(isAnimating ? 1.0 : 0.0)

                // Tier badge
                TierBadge(tier: requiredTier)
                    .scaleEffect(1.2)
                    .opacity(isAnimating ? 1.0 : 0.0)

                Spacer()

                // Upgrade button
                VStack(spacing: 16) {
                    Button(action: {
                        HapticManager.mediumTap()
                        onUpgrade()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.body.weight(.semibold))
                            Text("Upgrade to \(requiredTier.displayName)")
                                .font(.body.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(tierGradient)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
                    }

                    // Optional dismiss
                    if let dismiss = onDismiss {
                        Button(action: {
                            HapticManager.lightTap()
                            dismiss()
                        }) {
                            Text("Maybe Later")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
                .opacity(isAnimating ? 1.0 : 0.0)
            }
        }
        .onAppear {
            withAnimation(AppTheme.smoothSpring.delay(0.1)) {
                isAnimating = true
            }
        }
    }

    // MARK: - Private

    private var tierColor: Color {
        switch requiredTier {
        case .free:
            return .gray
        case .pro:
            return .purple
        case .power:
            return .orange
        }
    }

    private var tierGradient: LinearGradient {
        switch requiredTier {
        case .free:
            return AppTheme.disabledGradient
        case .pro:
            return AppTheme.proGradient
        case .power:
            return AppTheme.powerGradient
        }
    }
}

// MARK: - View Modifier

/// View modifier to conditionally show the feature gate overlay
struct FeatureGateModifier: ViewModifier {
    let isLocked: Bool
    let requiredTier: SubscriptionTier
    let featureName: String
    let featureDescription: String
    let onUpgrade: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay {
                if isLocked {
                    FeatureGateOverlay(
                        requiredTier: requiredTier,
                        featureName: featureName,
                        featureDescription: featureDescription,
                        onUpgrade: onUpgrade
                    )
                }
            }
    }
}

extension View {
    /// Applies a feature gate overlay when the content is locked
    func featureGate(
        isLocked: Bool,
        requiredTier: SubscriptionTier,
        featureName: String,
        featureDescription: String,
        onUpgrade: @escaping () -> Void
    ) -> some View {
        modifier(FeatureGateModifier(
            isLocked: isLocked,
            requiredTier: requiredTier,
            featureName: featureName,
            featureDescription: featureDescription,
            onUpgrade: onUpgrade
        ))
    }
}

// MARK: - Preview

#Preview("Feature Gate Overlay") {
    ZStack {
        // Background content (would be blurred)
        VStack(spacing: 16) {
            ForEach(0..<5) { i in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 80)
            }
        }
        .padding()

        // Gate overlay
        FeatureGateOverlay(
            requiredTier: .power,
            featureName: "Power Modes",
            featureDescription: "AI-powered voice workflows for research, email drafting, and creative writing",
            onUpgrade: {},
            onDismiss: {}
        )
    }
    .background(AppTheme.darkBase)
    .preferredColorScheme(.dark)
}

#Preview("Pro Gate") {
    ZStack {
        VStack {
            Text("Translation Settings")
                .font(.title2.weight(.bold))
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        FeatureGateOverlay(
            requiredTier: .pro,
            featureName: "Translation",
            featureDescription: "Translate your transcriptions to 50+ languages with DeepL and Google Translate",
            onUpgrade: {}
        )
    }
    .background(AppTheme.darkBase)
    .preferredColorScheme(.dark)
}
