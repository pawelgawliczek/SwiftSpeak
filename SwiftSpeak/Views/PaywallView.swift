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
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var settings = SharedSettings.shared
    @State private var selectedTier: SubscriptionTier = .pro
    @State private var isYearly = true
    @State private var isPurchasing = false
    @State private var showSuccess = false

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }

    private var cardShadow: Color {
        colorScheme == .dark ? .clear : .black.opacity(0.08)
    }

    var body: some View {
        ZStack {
            // Background
            backgroundColor.ignoresSafeArea()

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
                                .background(cardBackground)
                                .clipShape(Circle())
                                .shadow(color: cardShadow, radius: 4, y: 2)
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
                    BillingToggle(isYearly: $isYearly, colorScheme: colorScheme)
                        .padding(.top, 8)

                    // Tier cards
                    VStack(spacing: 16) {
                        TierCard(
                            tier: .pro,
                            isSelected: selectedTier == .pro,
                            isYearly: isYearly,
                            colorScheme: colorScheme,
                            onSelect: { selectedTier = .pro }
                        )

                        TierCard(
                            tier: .power,
                            isSelected: selectedTier == .power,
                            isYearly: isYearly,
                            colorScheme: colorScheme,
                            onSelect: { selectedTier = .power }
                        )
                    }
                    .padding(.horizontal, 20)

                    // Features comparison
                    FeaturesComparison(selectedTier: selectedTier, colorScheme: colorScheme)
                        .padding(.horizontal, 20)

                    // Purchase button
                    Button(action: purchase) {
                        HStack {
                            if isPurchasing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Continue with \(selectedTier.displayName)")
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 50)
                        .background(
                            selectedTier == .pro ? AppTheme.accent : Color.purple
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: (selectedTier == .pro ? AppTheme.accent : Color.purple).opacity(0.3), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
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
                SuccessOverlay(selectedTier: selectedTier) {
                    dismiss()
                }
            }
        }
    }

    private var priceText: String {
        let price = selectedTier == .pro ?
            (isYearly ? "$39.99/year" : "$4.99/month") :
            (isYearly ? "$79.99/year" : "$9.99/month")
        return price
    }

    private var savingsPercent: Int {
        selectedTier == .pro ? 33 : 33
    }

    private func purchase() {
        HapticManager.mediumTap()
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
        HapticManager.lightTap()
        // Mock restore - in Phase 5, this will call RevenueCat
        // Purchases.shared.restorePurchases()
    }
}

// MARK: - Billing Toggle
struct BillingToggle: View {
    @Binding var isYearly: Bool
    let colorScheme: ColorScheme

    private var toggleBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
    }

    private var selectedBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.2) : Color.white
    }

    var body: some View {
        HStack(spacing: 0) {
            ToggleButton(title: "Monthly", isSelected: !isYearly, colorScheme: colorScheme) {
                HapticManager.selection()
                withAnimation(AppTheme.quickSpring) {
                    isYearly = false
                }
            }

            ToggleButton(title: "Yearly", isSelected: isYearly, badge: "Save 33%", colorScheme: colorScheme) {
                HapticManager.selection()
                withAnimation(AppTheme.quickSpring) {
                    isYearly = true
                }
            }
        }
        .padding(4)
        .background(toggleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 20)
    }
}

struct ToggleButton: View {
    let title: String
    let isSelected: Bool
    var badge: String? = nil
    let colorScheme: ColorScheme
    let action: () -> Void

    private var selectedBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.2) : Color.white
    }

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
            .background(isSelected ? selectedBackground : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: isSelected && colorScheme == .light ? .black.opacity(0.1) : .clear, radius: 4, y: 2)
        }
    }
}

// MARK: - Tier Card
struct TierCard: View {
    let tier: SubscriptionTier
    let isSelected: Bool
    let isYearly: Bool
    let colorScheme: ColorScheme
    let onSelect: () -> Void

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }

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
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? tierColor : Color.clear, lineWidth: 2)
            )
            .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.08), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
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
        case .pro: return isYearly ? "$3.33" : "$4.99"
        case .power: return isYearly ? "$6.67" : "$9.99"
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
                "Multiple transcript providers",
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
    let colorScheme: ColorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Compare Plans")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)

            VStack(spacing: 12) {
                FeatureRow(feature: "Transcriptions/day", free: "10", pro: "Unlimited", power: "Unlimited")
                FeatureRow(feature: "Transcript Providers", free: "1", pro: "4+", power: "4+")
                FeatureRow(feature: "Translation", free: false, pro: true, power: true)
                FeatureRow(feature: "Custom Templates", free: false, pro: true, power: true)
                FeatureRow(feature: "Power Modes", free: false, pro: false, power: true)
                FeatureRow(feature: "AI Tools", free: false, pro: false, power: true)
            }
        }
        .padding(20)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.08), radius: 8, y: 4)
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
    let selectedTier: SubscriptionTier
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

                Text("Welcome to \(selectedTier.displayName)!")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)

                Text("You now have access to all \(selectedTier.displayName) features")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.7))

                Button(action: {
                    HapticManager.mediumTap()
                    onDismiss()
                }) {
                    Text("Start Using SwiftSpeak")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 50)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: Color.green.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)
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

#Preview("Dark") {
    PaywallView()
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    PaywallView()
        .preferredColorScheme(.light)
}
