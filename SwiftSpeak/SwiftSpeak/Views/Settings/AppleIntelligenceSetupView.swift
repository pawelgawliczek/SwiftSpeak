//
//  AppleIntelligenceSetupView.swift
//  SwiftSpeak
//
//  Phase 10: Apple Intelligence on-device text processing setup
//

import SwiftUI

struct AppleIntelligenceSetupView: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    private var isAvailable: Bool {
        settings.appleIntelligenceConfig.isAvailable
    }

    private var isEnabled: Bool {
        settings.appleIntelligenceConfig.isEnabled
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            List {
                // Header Section
                headerSection

                if isAvailable {
                    // Features Section
                    featuresSection

                    // Enable Section
                    enableSection

                    // Usage Section
                    if isEnabled {
                        usageSection
                    }
                } else {
                    // Not Available Section
                    notAvailableSection
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Apple Intelligence")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        Section {
            VStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.purple.opacity(0.3), .pink.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: 8) {
                    Text("Apple Intelligence")
                        .font(.title2.weight(.bold))

                    Text("On-device AI text processing powered by Apple's foundation models. Write, rewrite, and format text with complete privacy.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Benefits
                HStack(spacing: 20) {
                    BenefitBadge(icon: "apple.logo", text: "Native", color: .primary)
                    BenefitBadge(icon: "lock.shield", text: "Private", color: .green)
                    BenefitBadge(icon: "bolt", text: "Fast", color: .orange)
                }
            }
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        Section {
            AIFeatureRow(
                icon: "text.badge.checkmark",
                iconColor: .blue,
                title: "Proofread",
                description: "Check spelling, grammar, and punctuation"
            )
            .listRowBackground(rowBackground)

            AIFeatureRow(
                icon: "arrow.triangle.2.circlepath",
                iconColor: .purple,
                title: "Rewrite",
                description: "Adjust tone and style of your text"
            )
            .listRowBackground(rowBackground)

            AIFeatureRow(
                icon: "text.alignleft",
                iconColor: .orange,
                title: "Summarize",
                description: "Create concise summaries of longer text"
            )
            .listRowBackground(rowBackground)

            AIFeatureRow(
                icon: "wand.and.stars",
                iconColor: .pink,
                title: "Compose",
                description: "Generate text from prompts"
            )
            .listRowBackground(rowBackground)
        } header: {
            Text("Capabilities")
        } footer: {
            Text("Apple Intelligence features are processed entirely on-device. Your data never leaves your iPhone.")
        }
    }

    // MARK: - Enable Section

    private var enableSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { isEnabled },
                set: { enabled in
                    var config = settings.appleIntelligenceConfig
                    config.isEnabled = enabled
                    settings.appleIntelligenceConfig = config
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use Apple Intelligence")
                        .font(.callout)

                    Text("Enable on-device text formatting")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.purple)
            .listRowBackground(rowBackground)
        } header: {
            Text("Settings")
        } footer: {
            Text("When enabled, Apple Intelligence will be available for Power Mode formatting and text processing.")
        }
    }

    // MARK: - Usage Section

    private var usageSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ready to Use")
                        .font(.callout.weight(.medium))

                    Text("Apple Intelligence is enabled and ready for text processing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(rowBackground)

            NavigationLink {
                // Future: Usage stats or history
                Text("Coming soon")
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.fill")
                        .font(.title3)
                        .foregroundStyle(.purple)

                    Text("View Usage")
                        .font(.callout)
                }
            }
            .listRowBackground(rowBackground)
        } header: {
            Text("Status")
        }
    }

    // MARK: - Not Available Section

    private var notAvailableSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    Text("Not Available")
                        .font(.headline)

                    Text(settings.appleIntelligenceConfig.unavailableReason ?? "Apple Intelligence is not available on this device.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .listRowBackground(Color.clear)
        } header: {
            Text("Status")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Requirements:")
                    .font(.caption.weight(.medium))

                RequirementRow(text: "iPhone 15 Pro or later (A17 Pro chip)", isMet: false)
                RequirementRow(text: "iOS 18.5 or later", isMet: false)
                RequirementRow(text: "Apple Intelligence enabled in Settings", isMet: false)
            }
        }
    }
}

// MARK: - Benefit Badge

private struct BenefitBadge: View {
    let icon: String
    let text: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - AI Feature Row

private struct AIFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Requirement Row

private struct RequirementRow: View {
    let text: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "xmark.circle")
                .font(.caption)
                .foregroundStyle(isMet ? .green : .secondary)

            Text(text)
                .font(.caption)
                .foregroundStyle(isMet ? .primary : .secondary)
        }
    }
}

#Preview("Available") {
    NavigationStack {
        AppleIntelligenceSetupView()
            .environmentObject({
                let settings = SharedSettings.shared
                settings.appleIntelligenceConfig = AppleIntelligenceConfig(
                    isEnabled: false,
                    isAvailable: true,
                    unavailableReason: nil
                )
                return settings
            }())
    }
}

#Preview("Not Available") {
    NavigationStack {
        AppleIntelligenceSetupView()
            .environmentObject({
                let settings = SharedSettings.shared
                settings.appleIntelligenceConfig = AppleIntelligenceConfig(
                    isEnabled: false,
                    isAvailable: false,
                    unavailableReason: "Requires iPhone 15 Pro or later with iOS 18.5+"
                )
                return settings
            }())
    }
}
