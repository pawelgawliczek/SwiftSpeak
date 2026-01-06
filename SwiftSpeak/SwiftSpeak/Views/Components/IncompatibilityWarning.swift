//
//  IncompatibilityWarning.swift
//  SwiftSpeak
//
//  Warning banner when provider doesn't support selected language
//

import SwiftUI
import SwiftSpeakCore

struct IncompatibilityWarning: View {
    let provider: AIProvider
    let language: Language
    let capability: ProviderUsageCategory
    let recommendedProvider: AIProvider?
    let onSwitchProvider: (AIProvider) -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var isExpanded = false

    private var supportLevel: LanguageSupportLevel {
        ProviderLanguageDatabase.supportLevel(
            provider: provider,
            language: language,
            for: capability
        )
    }

    private var shouldShow: Bool {
        supportLevel < .good
    }

    private var warningColor: Color {
        supportLevel == .unsupported ? .red : .orange
    }

    private var warningIcon: String {
        supportLevel == .unsupported ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"
    }

    private var warningTitle: String {
        switch supportLevel {
        case .unsupported:
            return "\(provider.shortName) doesn't support \(language.displayName)"
        case .limited:
            return "Limited \(language.displayName) support with \(provider.shortName)"
        default:
            return ""
        }
    }

    private var warningMessage: String {
        switch supportLevel {
        case .unsupported:
            return "\(capability.displayName) will fail. Switch to a supported provider."
        case .limited:
            return "You may experience lower accuracy. Consider switching providers."
        default:
            return ""
        }
    }

    // Get alternative providers sorted by support level
    private var alternativeProviders: [(AIProvider, LanguageSupportLevel)] {
        ProviderLanguageDatabase.providers(
            supporting: language,
            for: capability,
            minimumLevel: .good
        )
        .filter { $0 != provider }
        .map { alt in
            let level = ProviderLanguageDatabase.supportLevel(provider: alt, language: language, for: capability)
            return (alt, level)
        }
        .sorted { $0.1 > $1.1 }
    }

    var body: some View {
        if shouldShow {
            VStack(alignment: .leading, spacing: 12) {
                // Warning header
                HStack(spacing: 10) {
                    Image(systemName: warningIcon)
                        .font(.title3)
                        .foregroundStyle(warningColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(warningTitle)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(warningMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !alternativeProviders.isEmpty {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isExpanded.toggle()
                            }
                        }) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 28, height: 28)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                }

                // Expanded alternatives
                if isExpanded && !alternativeProviders.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Switch to:")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)

                        ForEach(alternativeProviders.prefix(3), id: \.0) { alt, level in
                            AlternativeProviderRow(
                                provider: alt,
                                level: level,
                                isRecommended: alt == recommendedProvider,
                                onSelect: {
                                    HapticManager.mediumTap()
                                    onSwitchProvider(alt)
                                }
                            )
                        }
                    }
                    .padding(.top, 4)
                }

                // Quick switch button (when not expanded)
                if !isExpanded, let recommended = recommendedProvider ?? alternativeProviders.first?.0 {
                    Button(action: {
                        HapticManager.mediumTap()
                        onSwitchProvider(recommended)
                    }) {
                        HStack(spacing: 6) {
                            ProviderIcon(recommended, size: .small, style: .plain)
                                .foregroundStyle(.white)
                            Text("Switch to \(recommended.shortName)")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppTheme.accent)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(16)
            .background(warningColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                    .stroke(warningColor.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Alternative Provider Row

private struct AlternativeProviderRow: View {
    let provider: AIProvider
    let level: LanguageSupportLevel
    let isRecommended: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                ProviderIcon(provider, size: .small, style: .filled)

                Text(provider.displayName)
                    .font(.callout)
                    .foregroundStyle(.primary)

                if isRecommended {
                    Text("Recommended")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.accent)
                        .clipShape(Capsule())
                }

                Spacer()

                // Support level stars
                HStack(spacing: 2) {
                    ForEach(0..<3) { i in
                        Image(systemName: i < level.stars ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundStyle(i < level.stars ? level.color : .secondary.opacity(0.2))
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Warning Badge

/// Small inline warning badge for limited support
struct LanguageWarningBadge: View {
    let provider: AIProvider
    let language: Language
    let capability: ProviderUsageCategory

    private var supportLevel: LanguageSupportLevel {
        ProviderLanguageDatabase.supportLevel(
            provider: provider,
            language: language,
            for: capability
        )
    }

    var body: some View {
        if supportLevel < .good {
            HStack(spacing: 4) {
                Image(systemName: supportLevel.icon)
                    .font(.caption2)
                Text(supportLevel == .unsupported ? "Unsupported" : "Limited")
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(supportLevel.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(supportLevel.color.opacity(0.15))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Inline Warning Text

/// Simple inline warning for list rows
struct InlineLanguageWarning: View {
    let provider: AIProvider
    let language: Language
    let capability: ProviderUsageCategory

    private var supportLevel: LanguageSupportLevel {
        ProviderLanguageDatabase.supportLevel(
            provider: provider,
            language: language,
            for: capability
        )
    }

    var body: some View {
        if supportLevel == .unsupported {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text("\(provider.shortName) doesn't support \(language.displayName)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if supportLevel == .limited {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Limited support for \(language.displayName)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview("Unsupported - Collapsed") {
    VStack(spacing: 20) {
        IncompatibilityWarning(
            provider: .assemblyAI,
            language: .arabic,
            capability: .transcription,
            recommendedProvider: .openAI,
            onSwitchProvider: { _ in }
        )
    }
    .padding()
    .background(AppTheme.darkBase)
    .preferredColorScheme(.dark)
}

#Preview("Limited Support") {
    VStack(spacing: 20) {
        IncompatibilityWarning(
            provider: .deepgram,
            language: .polish,
            capability: .transcription,
            recommendedProvider: .openAI,
            onSwitchProvider: { _ in }
        )
    }
    .padding()
    .background(AppTheme.darkBase)
    .preferredColorScheme(.dark)
}

#Preview("Warning Badges") {
    VStack(spacing: 16) {
        HStack {
            Text("Polish")
            Spacer()
            LanguageWarningBadge(
                provider: .deepgram,
                language: .polish,
                capability: .transcription
            )
        }

        HStack {
            Text("Arabic")
            Spacer()
            LanguageWarningBadge(
                provider: .assemblyAI,
                language: .arabic,
                capability: .transcription
            )
        }

        HStack {
            Text("English")
            Spacer()
            LanguageWarningBadge(
                provider: .openAI,
                language: .english,
                capability: .transcription
            )
        }
    }
    .padding()
    .background(AppTheme.darkBase)
    .preferredColorScheme(.dark)
}

#Preview("Inline Warnings") {
    VStack(alignment: .leading, spacing: 16) {
        InlineLanguageWarning(
            provider: .assemblyAI,
            language: .arabic,
            capability: .transcription
        )

        InlineLanguageWarning(
            provider: .deepgram,
            language: .polish,
            capability: .transcription
        )
    }
    .padding()
    .background(AppTheme.darkBase)
    .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    VStack(spacing: 20) {
        IncompatibilityWarning(
            provider: .assemblyAI,
            language: .arabic,
            capability: .transcription,
            recommendedProvider: .openAI,
            onSwitchProvider: { _ in }
        )
    }
    .padding()
    .preferredColorScheme(.light)
}
