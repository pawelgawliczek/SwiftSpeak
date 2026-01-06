//
//  ProviderStatusDashboard.swift
//  SwiftSpeak
//
//  At-a-glance status card showing what's configured
//

import SwiftUI
import SwiftSpeakCore

struct ProviderStatusDashboard: View {
    @ObservedObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme

    @State private var showProviderComparison = false
    @State private var showAddProvider = false

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
    }

    // MARK: - Status Helpers

    private var transcriptionProvider: AIProviderConfig? {
        settings.configuredAIProviders.first { $0.isConfiguredForTranscription }
    }

    private var translationProvider: AIProviderConfig? {
        settings.configuredAIProviders.first { $0.isConfiguredForTranslation }
    }

    private var powerModeProvider: AIProviderConfig? {
        settings.configuredAIProviders.first { $0.isConfiguredForPowerMode }
    }

    private var isFullyConfigured: Bool {
        transcriptionProvider != nil && translationProvider != nil && powerModeProvider != nil
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Your Setup")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                if isFullyConfigured {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("Complete")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                    }
                }
            }

            // Status rows
            VStack(spacing: 12) {
                StatusRow(
                    icon: "waveform",
                    iconColor: .blue,
                    title: "Transcription",
                    provider: transcriptionProvider,
                    isConfigured: transcriptionProvider != nil
                )

                StatusRow(
                    icon: "globe",
                    iconColor: .purple,
                    title: "Translation",
                    provider: translationProvider,
                    isConfigured: translationProvider != nil
                )

                if settings.subscriptionTier == .power {
                    StatusRow(
                        icon: "bolt.fill",
                        iconColor: .orange,
                        title: "Power Mode",
                        provider: powerModeProvider,
                        isConfigured: powerModeProvider != nil
                    )
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                if !settings.availableProvidersToAdd.isEmpty {
                    Button(action: {
                        HapticManager.lightTap()
                        showAddProvider = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Provider")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppTheme.accent.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }

                Button(action: {
                    HapticManager.lightTap()
                    showProviderComparison = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "questionmark.circle")
                        Text("Help me choose")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        .sheet(isPresented: $showProviderComparison) {
            ProviderComparisonView()
        }
    }
}

// MARK: - Status Row

private struct StatusRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let provider: AIProviderConfig?
    let isConfigured: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            // Title
            Text(title)
                .font(.callout)
                .foregroundStyle(.primary)

            Spacer()

            // Status
            if let provider = provider {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)

                    Text(provider.provider.shortName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)

                    Text("Not configured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Compact Status Badge

/// A compact status indicator for use in other views
struct ProviderStatusBadge: View {
    let category: ProviderUsageCategory
    let provider: AIProviderConfig?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(.caption2)

            if let provider = provider {
                Text(provider.provider.shortName)
                    .font(.caption2.weight(.medium))

                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            } else {
                Text("Not set")
                    .font(.caption2)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview("Status Dashboard - Partial Setup") {
    VStack {
        ProviderStatusDashboard(settings: {
            let settings = SharedSettings.shared
            settings.subscriptionTier = .pro
            return settings
        }())
    }
    .padding()
    .background(AppTheme.darkBase)
    .preferredColorScheme(.dark)
}

#Preview("Status Dashboard - Power Tier") {
    VStack {
        ProviderStatusDashboard(settings: {
            let settings = SharedSettings.shared
            settings.subscriptionTier = .power
            return settings
        }())
    }
    .padding()
    .background(AppTheme.darkBase)
    .preferredColorScheme(.dark)
}

#Preview("Status Badges") {
    HStack(spacing: 8) {
        ProviderStatusBadge(
            category: .transcription,
            provider: AIProviderConfig(provider: .openAI)
        )

        ProviderStatusBadge(
            category: .translation,
            provider: nil
        )
    }
    .padding()
    .background(AppTheme.darkBase)
    .preferredColorScheme(.dark)
}
