//
//  PaywallView.swift
//  SwiftSpeak
//
//  Subscription paywall - designed for RevenueCat integration
//  Phase 0: UI with mock data
//  Phase 5: Connect to RevenueCat SDK
//

import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = SharedSettings.shared
    @State private var selectedTier: SubscriptionTier = .pro
    @State private var isYearly = true
    @State private var isPurchasing = false
    @State private var showSuccess = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [AppTheme.darkBase, Color(red: 0.05, green: 0.05, blue: 0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Close button
                    HStack {
                        Spacer()
                        Button(action: {
                            HapticManager.lightTap()
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(10)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)

                    // Header
                    VStack(spacing: 12) {
                        Text("Unlock SwiftSpeak")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.primary)

                        Text("Choose the plan that works for you")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    // Billing toggle
                    BillingToggle(isYearly: $isYearly)
                        .padding(.top, 8)

                    // Tier cards
                    VStack(spacing: 16) {
                        TierCard(
                            tier: .pro,
                            isSelected: selectedTier == .pro,
                            isYearly: isYearly,
                            onSelect: { selectedTier = .pro }
                        )

                        TierCard(
                            tier: .power,
                            isSelected: selectedTier == .power,
                            isYearly: isYearly,
                            onSelect: { selectedTier = .power }
                        )
                    }
                    .padding(.horizontal, 20)

                    // Features comparison
                    FeaturesComparison(selectedTier: selectedTier)
                        .padding(.horizontal, 20)

                    // Purchase button
                    Button(action: purchase) {
                        HStack {
                            if isPurchasing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Continue with \(selectedTier.displayName)")
                                    .font(.callout.weight(.semibold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: selectedTier == .pro ?
                                    [AppTheme.accent, AppTheme.accentSecondary] : [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                    }
                    .disabled(isPurchasing)
                    .padding(.horizontal, 20)

                    // Price info
                    VStack(spacing: 4) {
                        Text(priceText)
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        if isYearly {
                            Text("Save \(savingsPercent)% with yearly billing")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }

                    // Legal links
                    HStack(spacing: 16) {
                        Button("Restore Purchases") {
                            restorePurchases()
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Text("•")
                            .foregroundStyle(.secondary)

                        Button("Terms") {
                            // Open terms
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Text("•")
                            .foregroundStyle(.secondary)

                        Button("Privacy") {
                            // Open privacy
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }

            // Success overlay
            if showSuccess {
                SuccessOverlay {
                    dismiss()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var priceText: String {
        let price = selectedTier == .pro ?
            (isYearly ? "$79.99/year" : "$9.99/month") :
            (isYearly ? "$159.99/year" : "$19.99/month")
        return price
    }

    private var savingsPercent: Int {
        selectedTier == .pro ? 33 : 33
    }

    private func purchase() {
        isPurchasing = true

        // Mock purchase - in Phase 5, this will call RevenueCat
        // Purchases.shared.purchase(package: selectedPackage)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isPurchasing = false
            settings.subscriptionTier = selectedTier
            showSuccess = true
        }
    }

    private func restorePurchases() {
        // Mock restore - in Phase 5, this will call RevenueCat
        // Purchases.shared.restorePurchases()
    }
}

// MARK: - Billing Toggle
struct BillingToggle: View {
    @Binding var isYearly: Bool

    var body: some View {
        HStack(spacing: 0) {
            ToggleButton(title: "Monthly", isSelected: !isYearly) {
                HapticManager.selection()
                withAnimation(AppTheme.quickSpring) {
                    isYearly = false
                }
            }

            ToggleButton(title: "Yearly", isSelected: isYearly, badge: "Save 33%") {
                HapticManager.selection()
                withAnimation(AppTheme.quickSpring) {
                    isYearly = true
                }
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        .padding(.horizontal, 20)
    }
}

struct ToggleButton: View {
    let title: String
    let isSelected: Bool
    var badge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.medium))

                if let badge = badge, isSelected {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(isSelected ? Color.white.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        }
    }
}

// MARK: - Tier Card
struct TierCard: View {
    let tier: SubscriptionTier
    let isSelected: Bool
    let isYearly: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.selection()
            onSelect()
        }) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(tier.displayName)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)

                            if tier == .power {
                                Text("BEST VALUE")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        LinearGradient(
                                            colors: [.purple, .pink],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(Capsule())
                            }
                        }

                        Text(tierDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Selection indicator
                    ZStack {
                        Circle()
                            .stroke(isSelected ? tierColor : Color.secondary.opacity(0.5), lineWidth: 2)
                            .frame(width: 24, height: 24)

                        if isSelected {
                            Circle()
                                .fill(tierColor)
                                .frame(width: 14, height: 14)
                        }
                    }
                }

                // Price
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(priceAmount)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.primary)

                    Text(pricePeriod)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Key features
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(keyFeatures, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(tierColor)

                            Text(feature)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                            .stroke(
                                isSelected ? tierColor : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
    }

    private var tierColor: Color {
        tier == .pro ? AppTheme.accent : .purple
    }

    private var tierDescription: String {
        switch tier {
        case .pro: return "For power users"
        case .power: return "For professionals"
        default: return ""
        }
    }

    private var priceAmount: String {
        switch tier {
        case .pro: return isYearly ? "$6.67" : "$9.99"
        case .power: return isYearly ? "$13.33" : "$19.99"
        default: return "$0"
        }
    }

    private var pricePeriod: String {
        isYearly ? "/mo (billed yearly)" : "/month"
    }

    private var keyFeatures: [String] {
        switch tier {
        case .pro:
            return [
                "Unlimited transcriptions",
                "Multiple STT providers",
                "Translation feature",
                "Custom templates"
            ]
        case .power:
            return [
                "Everything in Pro",
                "Power Modes (AI agents)",
                "Web search tool",
                "Full-screen workspace"
            ]
        default:
            return []
        }
    }
}

// MARK: - Features Comparison
struct FeaturesComparison: View {
    let selectedTier: SubscriptionTier

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Compare Plans")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)

            VStack(spacing: 12) {
                FeatureRow(feature: "Transcriptions/day", free: "10", pro: "Unlimited", power: "Unlimited")
                FeatureRow(feature: "STT Providers", free: "1", pro: "4+", power: "4+")
                FeatureRow(feature: "Translation", free: false, pro: true, power: true)
                FeatureRow(feature: "Custom Templates", free: false, pro: true, power: true)
                FeatureRow(feature: "Power Modes", free: false, pro: false, power: true)
                FeatureRow(feature: "AI Tools", free: false, pro: false, power: true)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
    }
}

struct FeatureRow: View {
    let feature: String
    var free: Any
    var pro: Any
    var power: Any

    var body: some View {
        HStack {
            Text(feature)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            FeatureValue(value: free)
                .frame(width: 50)

            FeatureValue(value: pro)
                .frame(width: 50)

            FeatureValue(value: power)
                .frame(width: 50)
        }
    }
}

struct FeatureValue: View {
    let value: Any

    var body: some View {
        Group {
            if let boolValue = value as? Bool {
                Image(systemName: boolValue ? "checkmark" : "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(boolValue ? .green : .secondary)
            } else if let stringValue = value as? String {
                Text(stringValue)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
            }
        }
    }
}

// MARK: - Success Overlay
struct SuccessOverlay: View {
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Checkmark animation
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 100, height: 100)

                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(scale)

                Text("Welcome to Pro!")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.primary)

                Text("You now have access to all features")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button(action: {
                    HapticManager.mediumTap()
                    onDismiss()
                }) {
                    Text("Start Using SwiftSpeak")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 32)
                        .background(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                }
                .padding(.top, 16)
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(AppTheme.smoothSpring) {
                scale = 1.0
                opacity = 1.0
            }

            // Haptic
            HapticManager.success()
        }
    }
}

#Preview {
    PaywallView()
}
