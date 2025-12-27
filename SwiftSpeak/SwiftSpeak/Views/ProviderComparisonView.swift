//
//  ProviderComparisonView.swift
//  SwiftSpeak
//
//  Help users choose the right provider based on their use case
//

import SwiftUI

struct ProviderComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var settings: SharedSettings

    @State private var selectedRecommendation: ProviderRecommendation?
    @State private var showProviderHelp = false
    @State private var selectedProvider: AIProvider?

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection

                        // Use Case Cards
                        useCaseSection

                        // All Providers Comparison
                        allProvidersSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Choose a Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedProvider) { provider in
                ProviderHelpSheet(provider: provider)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.accentGradient)

            Text("What do you need?")
                .font(.title2.weight(.bold))

            Text("Choose based on your primary use case")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Use Case Section

    private var useCaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended for You")
                .font(.headline)

            ForEach(ProviderRecommendations.allRecommendations) { recommendation in
                RecommendationCard(
                    recommendation: recommendation,
                    isConfigured: isProviderConfigured(recommendation.recommendedProvider),
                    onSetUp: {
                        selectedProvider = recommendation.recommendedProvider
                    }
                )
            }
        }
    }

    // MARK: - All Providers Section

    private var allProvidersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Providers")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(AIProvider.allCases) { provider in
                    ProviderComparisonRow(
                        provider: provider,
                        guide: ProviderHelpDatabase.guide(for: provider),
                        isConfigured: isProviderConfigured(provider),
                        onTap: {
                            selectedProvider = provider
                        }
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func isProviderConfigured(_ provider: AIProvider) -> Bool {
        settings.configuredAIProviders.contains { $0.provider == provider }
    }
}

// MARK: - Recommendation Card

private struct RecommendationCard: View {
    let recommendation: ProviderRecommendation
    let isConfigured: Bool
    let onSetUp: () -> Void

    @Environment(\.colorScheme) var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: recommendation.icon)
                    .font(.title2)
                    .foregroundStyle(recommendation.iconColor)
                    .frame(width: 44, height: 44)
                    .background(recommendation.iconColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                // Title & Description
                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.useCase)
                        .font(.callout.weight(.semibold))

                    Text(recommendation.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Recommendation
            HStack(spacing: 8) {
                Image(systemName: recommendation.recommendedProvider.icon)
                    .foregroundStyle(AppTheme.accent)

                Text(recommendation.recommendedProvider.displayName)
                    .font(.subheadline.weight(.medium))

                if isConfigured {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }

                Spacer()

                Button(action: {
                    HapticManager.lightTap()
                    onSetUp()
                }) {
                    Text(isConfigured ? "View" : "Set Up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent)
                        .clipShape(Capsule())
                }
            }
            .padding(12)
            .background(AppTheme.accent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Reasoning
            Text(recommendation.reasoning)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Alternatives
            if !recommendation.alternativeProviders.isEmpty {
                HStack(spacing: 4) {
                    Text("Also good:")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    ForEach(recommendation.alternativeProviders, id: \.self) { provider in
                        Text(provider.shortName)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
    }
}

// MARK: - Provider Comparison Row

private struct ProviderComparisonRow: View {
    let provider: AIProvider
    let guide: ProviderSetupGuide
    let isConfigured: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) var colorScheme

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    var body: some View {
        Button(action: {
            HapticManager.lightTap()
            onTap()
        }) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: provider.icon)
                    .font(.body)
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.accent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(provider.displayName)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.primary)

                        if isConfigured {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }

                        if provider.requiresPowerTier {
                            Text("POWER")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                    }

                    // Capabilities
                    HStack(spacing: 4) {
                        ForEach(Array(provider.supportedCategories).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { category in
                            Image(systemName: category.icon)
                                .font(.caption2)
                                .foregroundStyle(categoryColor(for: category))
                        }

                        Text("·")
                            .foregroundStyle(.tertiary)

                        Text(guide.estimatedCost)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func categoryColor(for category: ProviderUsageCategory) -> Color {
        switch category {
        case .transcription: return .blue
        case .translation: return .purple
        case .powerMode: return .orange
        }
    }
}

// MARK: - Preview

#Preview("Provider Comparison") {
    ProviderComparisonView()
        .environmentObject(SharedSettings.shared)
        .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    ProviderComparisonView()
        .environmentObject(SharedSettings.shared)
        .preferredColorScheme(.light)
}
