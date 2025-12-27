//
//  ProviderHelpSheet.swift
//  SwiftSpeak
//
//  Bottom sheet showing setup guide for a provider
//

import SwiftUI

struct ProviderHelpSheet: View {
    let provider: AIProvider
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var guide: ProviderSetupGuide {
        ProviderHelpDatabase.guide(for: provider)
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    providerHeader

                    // Setup Steps
                    setupStepsSection

                    // Tips Section
                    if !guide.tips.isEmpty {
                        tipsSection
                    }

                    // Cost Info
                    costInfoSection

                    // Action Buttons
                    actionButtons

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(backgroundColor)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Provider Header

    private var providerHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: provider.icon)
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 80, height: 80)
                .background(AppTheme.accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text("Setting up \(provider.displayName)")
                .font(.title2.weight(.bold))

            Text(provider.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Best for badges
            if !guide.bestFor.isEmpty {
                HStack(spacing: 8) {
                    ForEach(guide.bestFor, id: \.self) { capability in
                        Text(capability)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppTheme.accent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 16)
    }

    // MARK: - Setup Steps Section

    private var setupStepsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Setup Steps")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 0) {
                ForEach(Array(guide.steps.enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .top, spacing: 16) {
                        // Step number with connecting line
                        VStack(spacing: 0) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.accentGradient)
                                    .frame(width: 28, height: 28)

                                Text("\(step.number)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }

                            if index < guide.steps.count - 1 {
                                Rectangle()
                                    .fill(AppTheme.accent.opacity(0.3))
                                    .frame(width: 2)
                                    .frame(maxHeight: .infinity)
                            }
                        }

                        // Step content
                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.title)
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.primary)

                            if let description = step.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let url = step.actionURL {
                                Button(action: {
                                    UIApplication.shared.open(url)
                                }) {
                                    HStack(spacing: 4) {
                                        Text("Open")
                                        Image(systemName: "arrow.up.right")
                                    }
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppTheme.accent)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.bottom, index < guide.steps.count - 1 ? 20 : 0)

                        Spacer()
                    }
                }
            }
            .padding(16)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
    }

    // MARK: - Tips Section

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("Tips")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(guide.tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                            .padding(.top, 2)

                        Text(tip)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
    }

    // MARK: - Cost Info Section

    private var costInfoSection: some View {
        HStack(spacing: 16) {
            // Estimated Cost
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundStyle(.green)
                    Text("Cost")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(guide.estimatedCost)
                    .font(.callout.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            // Free Credits
            if let freeCredits = guide.freeCredits {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "gift.fill")
                            .foregroundStyle(.purple)
                        Text("Free")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(freeCredits)
                        .font(.callout.weight(.semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if let websiteURL = guide.websiteURL {
                Button(action: {
                    HapticManager.lightTap()
                    UIApplication.shared.open(websiteURL)
                }) {
                    HStack {
                        Image(systemName: "globe")
                        Text("Open \(provider.shortName) Website")
                    }
                    .font(.callout.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                }
            }

            if let apiKeyURL = guide.apiKeyURL {
                Button(action: {
                    HapticManager.mediumTap()
                    UIApplication.shared.open(apiKeyURL)
                }) {
                    HStack {
                        Image(systemName: "key.fill")
                        Text("Get API Key")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                }
            }

            // Documentation link
            if let docsURL = guide.documentationURL {
                Button(action: {
                    UIApplication.shared.open(docsURL)
                }) {
                    HStack {
                        Image(systemName: "book.closed.fill")
                        Text("View Documentation")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("OpenAI Help") {
    ProviderHelpSheet(provider: .openAI)
        .preferredColorScheme(.dark)
}

#Preview("Anthropic Help") {
    ProviderHelpSheet(provider: .anthropic)
        .preferredColorScheme(.dark)
}

#Preview("Google Help") {
    ProviderHelpSheet(provider: .google)
        .preferredColorScheme(.dark)
}

#Preview("Local AI Help") {
    ProviderHelpSheet(provider: .local)
        .preferredColorScheme(.dark)
}

#Preview("DeepL Help") {
    ProviderHelpSheet(provider: .deepL)
        .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    ProviderHelpSheet(provider: .openAI)
        .preferredColorScheme(.light)
}
