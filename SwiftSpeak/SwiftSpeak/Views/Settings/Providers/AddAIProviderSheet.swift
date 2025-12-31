//
//  AddAIProviderSheet.swift
//  SwiftSpeak
//
//  Sheet for adding new AI providers
//

import SwiftUI

struct AddAIProviderSheet: View {
    let availableProviders: [AIProvider]
    let currentTier: SubscriptionTier
    let onSelect: (AIProvider) -> Void
    let onShowPaywall: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    // Filter state - nil means "All"
    @State private var selectedFilter: ProviderUsageCategory? = nil
    @State private var selectedLanguage: Language? = nil
    @State private var showLanguagePicker = false

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    /// Check if a provider is locked for the current subscription tier
    private func isProviderLocked(_ provider: AIProvider) -> Bool {
        // Power tier providers require Power subscription
        if provider.requiresPowerTier && currentTier != .power {
            return true
        }

        // For free tier: only OpenAI and Google are accessible
        // All other cloud providers require Pro or higher
        if currentTier == .free && provider != .openAI && provider != .google {
            return true
        }

        return false
    }

    /// Get the required tier badge text for a locked provider
    private func requiredTierBadge(_ provider: AIProvider) -> String? {
        if provider.requiresPowerTier && currentTier != .power {
            return "POWER"
        }
        if currentTier == .free && provider != .openAI && provider != .google {
            return "PRO"
        }
        return nil
    }

    private var filteredProviders: [AIProvider] {
        // Filter out local provider - it's in the Local Models section
        var providers = availableProviders.filter { !$0.isLocalProvider }

        // Filter by capability
        if let filter = selectedFilter {
            providers = providers.filter { $0.supportedCategories.contains(filter) }
        }

        // Filter by language support (only when a language is selected)
        if let language = selectedLanguage, let capability = selectedFilter {
            providers = providers.filter { provider in
                let level = ProviderLanguageDatabase.supportLevel(
                    provider: provider,
                    language: language,
                    for: capability
                )
                return level >= .limited
            }
        }

        return providers
    }

    /// Get language support level for display
    private func languageSupport(for provider: AIProvider) -> LanguageSupportLevel? {
        guard let language = selectedLanguage, let capability = selectedFilter else {
            return nil
        }
        return ProviderLanguageDatabase.supportLevel(provider: provider, language: language, for: capability)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                List {
                    // Filter Section
                    Section {
                        capabilityFilterView

                        // Language filter (shown when a capability is selected)
                        if selectedFilter != nil {
                            languageFilterRow
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

                    Section {
                        ForEach(filteredProviders) { provider in
                            let isLocked = isProviderLocked(provider)

                            Button(action: {
                                HapticManager.selection()
                                if isLocked {
                                    dismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        onShowPaywall()
                                    }
                                } else {
                                    onSelect(provider)
                                }
                            }) {
                                HStack(spacing: 12) {
                                    ProviderIcon(provider, size: .large, style: .filled, isDisabled: isLocked)

                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Text(provider.displayName)
                                                .font(.callout.weight(.medium))
                                                .foregroundStyle(isLocked ? .secondary : .primary)

                                            if let badge = requiredTierBadge(provider) {
                                                Text(badge)
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(badge == "POWER" ? Color.orange : AppTheme.accent)
                                                    .clipShape(Capsule())
                                            }
                                        }

                                        Text(provider.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)

                                        // Show capabilities
                                        HStack(spacing: 4) {
                                            ForEach(Array(provider.supportedCategories).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { category in
                                                HStack(spacing: 2) {
                                                    Image(systemName: category.icon)
                                                        .font(.caption2)
                                                }
                                                .foregroundStyle(isLocked ? .secondary : categoryColor(for: category))
                                            }
                                        }
                                    }

                                    Spacer()

                                    // Language support indicator (when language is selected)
                                    if let level = languageSupport(for: provider) {
                                        LanguageSupportBadge(level: level)
                                    }

                                    if isLocked {
                                        Image(systemName: "lock.fill")
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(AppTheme.accent)
                                    }
                                }
                            }
                            .listRowBackground(rowBackground)
                        }
                    } header: {
                        Text("Available Providers")
                    } footer: {
                        Text("Add an AI provider to use for transcription, translation, or Power Mode.")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add AI Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Capability Filter View

    private var capabilityFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // "All" filter chip
                FilterChip(
                    title: "All",
                    icon: "square.grid.2x2",
                    color: AppTheme.accent,
                    isSelected: selectedFilter == nil,
                    count: availableProviders.count
                ) {
                    HapticManager.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedFilter = nil
                        selectedLanguage = nil
                    }
                }

                // Category filter chips
                ForEach(ProviderUsageCategory.allCases) { category in
                    let count = availableProviders.filter { $0.supportedCategories.contains(category) }.count
                    FilterChip(
                        title: category.displayName,
                        icon: category.icon,
                        color: categoryColor(for: category),
                        isSelected: selectedFilter == category,
                        count: count
                    ) {
                        HapticManager.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedFilter = category
                            // Clear language when switching categories
                            if category != selectedFilter {
                                selectedLanguage = nil
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Language Filter Row

    private var languageFilterRow: some View {
        VStack(spacing: 0) {
            Button(action: {
                HapticManager.selection()
                showLanguagePicker = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.body.weight(.medium))
                        .foregroundStyle(selectedLanguage != nil ? .white : .secondary)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selectedLanguage != nil ? categoryColor(for: selectedFilter ?? .translation) : Color.secondary.opacity(0.15))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Filter by Language")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)

                        if let lang = selectedLanguage {
                            Text("\(lang.flag) \(lang.displayName)")
                                .font(.caption)
                                .foregroundStyle(categoryColor(for: selectedFilter ?? .translation))
                        } else {
                            Text("Show providers supporting a specific language")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if selectedLanguage != nil {
                        Button(action: {
                            HapticManager.selection()
                            withAnimation {
                                selectedLanguage = nil
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .sheet(isPresented: $showLanguagePicker) {
            LanguageFilterPicker(
                selectedLanguage: $selectedLanguage,
                capability: selectedFilter ?? .translation
            )
        }
    }

    private func categoryColor(for category: ProviderUsageCategory) -> Color {
        switch category {
        case .transcription: return .blue
        case .translation: return .purple
        case .powerMode: return .orange
        }
    }
}

// MARK: - Filter Chip Component

struct FilterChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))

                Text(title)
                    .font(.subheadline.weight(.medium))

                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.25) : color.opacity(0.15))
                    .clipShape(Capsule())
            }
            .foregroundStyle(isSelected ? .white : color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color : color.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Language Support Badge

struct LanguageSupportBadge: View {
    let level: LanguageSupportLevel

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: level.icon)
                .font(.caption2)
            Text(level.shortLabel)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(level.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(level.color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Language Filter Picker

struct LanguageFilterPicker: View {
    @Binding var selectedLanguage: Language?
    let capability: ProviderUsageCategory
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    /// Languages sorted by provider support count (most supported first)
    private var sortedLanguages: [Language] {
        Language.allCases.sorted { lang1, lang2 in
            let count1 = ProviderLanguageDatabase.providers(supporting: lang1, for: capability, minimumLevel: .limited).count
            let count2 = ProviderLanguageDatabase.providers(supporting: lang2, for: capability, minimumLevel: .limited).count
            return count1 > count2
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                List {
                    // Popular languages section
                    Section {
                        ForEach(ProviderLanguageDatabase.popularLanguages, id: \.self) { language in
                            languageRow(for: language)
                        }
                    } header: {
                        Text("Popular")
                    }

                    // All languages section
                    Section {
                        ForEach(sortedLanguages.filter { !ProviderLanguageDatabase.popularLanguages.contains($0) }, id: \.self) { language in
                            languageRow(for: language)
                        }
                    } header: {
                        Text("All Languages")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Select Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if selectedLanguage != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") {
                            selectedLanguage = nil
                            dismiss()
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func languageRow(for language: Language) -> some View {
        let providerCount = ProviderLanguageDatabase.providers(
            supporting: language,
            for: capability,
            minimumLevel: .limited
        ).count

        let excellentCount = ProviderLanguageDatabase.providers(
            supporting: language,
            for: capability,
            minimumLevel: .excellent
        ).count

        return Button(action: {
            HapticManager.selection()
            selectedLanguage = language
            dismiss()
        }) {
            HStack(spacing: 12) {
                Text(language.flag)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(language.displayName)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        Text("\(providerCount) provider\(providerCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if excellentCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                Text("\(excellentCount) excellent")
                                    .font(.caption)
                            }
                            .foregroundStyle(.green)
                        }
                    }
                }

                Spacer()

                if selectedLanguage == language {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(rowBackground)
    }
}

#Preview("Add AI Provider Sheet") {
    AddAIProviderSheet(
        availableProviders: AIProvider.allCases,
        currentTier: .pro,
        onSelect: { _ in },
        onShowPaywall: { }
    )
}
