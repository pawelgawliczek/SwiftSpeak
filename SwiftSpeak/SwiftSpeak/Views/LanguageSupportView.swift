//
//  LanguageSupportView.swift
//  SwiftSpeak
//
//  Language-provider compatibility matrix
//

import SwiftUI

struct LanguageSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var settings: SharedSettings

    @State private var searchText = ""
    @State private var selectedCapability: ProviderUsageCategory = .transcription
    @State private var selectedLanguage: Language?
    @State private var showLanguageDetail = false

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    private var filteredLanguages: [Language] {
        if searchText.isEmpty {
            return Language.allCases
        }
        return Language.allCases.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var popularLanguages: [Language] {
        filteredLanguages.filter { ProviderLanguageDatabase.isPopularLanguage($0) }
    }

    private var otherLanguages: [Language] {
        filteredLanguages.filter { !ProviderLanguageDatabase.isPopularLanguage($0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                List {
                    // Capability Picker
                    Section {
                        Picker("Capability", selection: $selectedCapability) {
                            ForEach([ProviderUsageCategory.transcription, .translation], id: \.self) { category in
                                HStack(spacing: 6) {
                                    Image(systemName: category.icon)
                                    Text(category.displayName)
                                }
                                .tag(category)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }

                    // Legend
                    Section {
                        legendRow
                            .listRowBackground(rowBackground)
                    }

                    // Popular Languages
                    if !popularLanguages.isEmpty {
                        Section {
                            ForEach(popularLanguages) { language in
                                LanguageSupportRow(
                                    language: language,
                                    capability: selectedCapability,
                                    colorScheme: colorScheme
                                ) {
                                    selectedLanguage = language
                                    showLanguageDetail = true
                                }
                                .listRowBackground(rowBackground)
                            }
                        } header: {
                            Text("Popular Languages")
                        }
                    }

                    // Other Languages
                    if !otherLanguages.isEmpty {
                        Section {
                            ForEach(otherLanguages) { language in
                                LanguageSupportRow(
                                    language: language,
                                    capability: selectedCapability,
                                    colorScheme: colorScheme
                                ) {
                                    selectedLanguage = language
                                    showLanguageDetail = true
                                }
                                .listRowBackground(rowBackground)
                            }
                        } header: {
                            Text("All Languages")
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .searchable(text: $searchText, prompt: "Search languages")
            }
            .navigationTitle("Language Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showLanguageDetail) {
                if let language = selectedLanguage {
                    LanguageDetailSheet(
                        language: language,
                        capability: selectedCapability
                    )
                }
            }
        }
    }

    // MARK: - Legend Row

    private var legendRow: some View {
        HStack(spacing: 16) {
            ForEach(LanguageSupportLevel.allCases, id: \.self) { level in
                if level != .unsupported {
                    HStack(spacing: 4) {
                        Image(systemName: level.icon)
                            .font(.caption2)
                            .foregroundStyle(level.color)
                        Text(level.shortLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Language Support Row

private struct LanguageSupportRow: View {
    let language: Language
    let capability: ProviderUsageCategory
    let colorScheme: ColorScheme
    let onTap: () -> Void

    // Get best provider for this language
    private var bestProvider: AIProvider? {
        ProviderLanguageDatabase.recommendedProvider(for: language, capability: capability)
    }

    // Get support level for each provider
    private var providerSupport: [(AIProvider, LanguageSupportLevel)] {
        AIProvider.allCases.compactMap { provider in
            switch capability {
            case .transcription:
                guard provider.supportsTranscription else { return nil }
            case .translation, .powerMode:
                guard provider.supportsTranslation else { return nil }
            }
            let level = ProviderLanguageDatabase.supportLevel(
                provider: provider,
                language: language,
                for: capability
            )
            return (provider, level)
        }
        .sorted { $0.1 > $1.1 }
    }

    // Get top 3 providers by support level
    private var topProviders: [(AIProvider, LanguageSupportLevel)] {
        Array(providerSupport.prefix(4))
    }

    var body: some View {
        Button(action: {
            HapticManager.lightTap()
            onTap()
        }) {
            HStack(spacing: 12) {
                // Flag
                Text(language.flag)
                    .font(.title2)

                // Language name
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.displayName)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)

                    // Best provider indicator
                    if let best = bestProvider {
                        HStack(spacing: 4) {
                            Text("Best:")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(best.shortName)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Provider support indicators
                HStack(spacing: 6) {
                    ForEach(topProviders, id: \.0) { provider, level in
                        ProviderSupportBadge(provider: provider, level: level)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Provider Support Badge

private struct ProviderSupportBadge: View {
    let provider: AIProvider
    let level: LanguageSupportLevel

    var body: some View {
        VStack(spacing: 2) {
            ProviderIcon(provider, size: .small, style: .plain)

            Image(systemName: level.icon)
                .font(.system(size: 6))
                .foregroundStyle(level.color)
        }
        .frame(width: 24)
    }
}

// MARK: - Language Detail Sheet

struct LanguageDetailSheet: View {
    let language: Language
    let capability: ProviderUsageCategory

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var settings: SharedSettings

    @State private var selectedProvider: AIProvider?

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
    }

    // Get all providers sorted by support level
    private var rankedProviders: [(AIProvider, LanguageSupportLevel, String?)] {
        AIProvider.allCases.compactMap { provider -> (AIProvider, LanguageSupportLevel, String?)? in
            switch capability {
            case .transcription:
                guard provider.supportsTranscription else { return nil }
            case .translation, .powerMode:
                guard provider.supportsTranslation else { return nil }
            }
            let level = ProviderLanguageDatabase.supportLevel(
                provider: provider,
                language: language,
                for: capability
            )
            let notes = ProviderLanguageDatabase.notes(for: provider)
            return (provider, level, notes)
        }
        .sorted { $0.1 > $1.1 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text(language.flag)
                            .font(.system(size: 60))

                        Text(language.displayName)
                            .font(.title2.weight(.bold))

                        Text("Best providers for \(capability.displayName.lowercased())")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 16)

                    // Provider ranking
                    VStack(spacing: 12) {
                        ForEach(Array(rankedProviders.enumerated()), id: \.element.0) { index, item in
                            let (provider, level, notes) = item

                            ProviderRankingCard(
                                rank: index + 1,
                                provider: provider,
                                level: level,
                                notes: notes,
                                isConfigured: isProviderConfigured(provider),
                                onSetUp: {
                                    selectedProvider = provider
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
            }
            .background(backgroundColor)
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func isProviderConfigured(_ provider: AIProvider) -> Bool {
        settings.configuredAIProviders.contains { $0.provider == provider }
    }
}

// MARK: - Provider Ranking Card

private struct ProviderRankingCard: View {
    let rank: Int
    let provider: AIProvider
    let level: LanguageSupportLevel
    let notes: String?
    let isConfigured: Bool
    let onSetUp: () -> Void

    @Environment(\.colorScheme) var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange.opacity(0.7)
        default: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rank <= 3 ? rankColor.opacity(0.2) : Color.clear)
                    .frame(width: 32, height: 32)

                if rank <= 3 {
                    Image(systemName: "medal.fill")
                        .font(.body)
                        .foregroundStyle(rankColor)
                } else {
                    Text("#\(rank)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }

            // Provider info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    ProviderIcon(provider, size: .small, style: .filled)

                    Text(provider.displayName)
                        .font(.callout.weight(.medium))

                    if isConfigured {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }

                // Support level
                HStack(spacing: 4) {
                    HStack(spacing: 2) {
                        ForEach(0..<3) { i in
                            Image(systemName: i < level.stars ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundStyle(i < level.stars ? level.color : .secondary.opacity(0.3))
                        }
                    }

                    Text(level.label)
                        .font(.caption)
                        .foregroundStyle(level.color)
                }

                // Notes
                if let notes = notes {
                    Text(notes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }

            Spacer()

            // Action button
            Button(action: {
                HapticManager.lightTap()
                onSetUp()
            }) {
                Text(isConfigured ? "View" : "Set Up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isConfigured ? Color.secondary : Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isConfigured ? Color.secondary.opacity(0.2) : AppTheme.accent)
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
    }
}

// MARK: - Preview

#Preview("Language Support") {
    LanguageSupportView()
        .environmentObject(SharedSettings.shared)
        .preferredColorScheme(.dark)
}

#Preview("Language Detail - Polish") {
    LanguageDetailSheet(language: .polish, capability: .transcription)
        .environmentObject(SharedSettings.shared)
        .preferredColorScheme(.dark)
}

#Preview("Language Detail - Japanese") {
    LanguageDetailSheet(language: .japanese, capability: .translation)
        .environmentObject(SharedSettings.shared)
        .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    LanguageSupportView()
        .environmentObject(SharedSettings.shared)
        .preferredColorScheme(.light)
}
