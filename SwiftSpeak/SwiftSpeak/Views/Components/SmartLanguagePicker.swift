//
//  SmartLanguagePicker.swift
//  SwiftSpeak
//
//  Enhanced language picker showing provider compatibility
//

import SwiftUI
import SwiftSpeakCore

struct SmartLanguagePicker: View {
    @Binding var selection: Language
    let currentProvider: AIProvider
    let capability: ProviderUsageCategory

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var searchText = ""
    @State private var showLanguageSupport = false

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

    // Languages grouped by support level
    private var excellentLanguages: [Language] {
        filteredLanguages.filter {
            ProviderLanguageDatabase.supportLevel(provider: currentProvider, language: $0, for: capability) == .excellent
        }
    }

    private var goodLanguages: [Language] {
        filteredLanguages.filter {
            ProviderLanguageDatabase.supportLevel(provider: currentProvider, language: $0, for: capability) == .good
        }
    }

    private var limitedLanguages: [Language] {
        filteredLanguages.filter {
            ProviderLanguageDatabase.supportLevel(provider: currentProvider, language: $0, for: capability) == .limited
        }
    }

    private var unsupportedLanguages: [Language] {
        filteredLanguages.filter {
            ProviderLanguageDatabase.supportLevel(provider: currentProvider, language: $0, for: capability) == .unsupported
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                List {
                    // Current provider info
                    Section {
                        currentProviderInfo
                    }

                    // Excellent support
                    if !excellentLanguages.isEmpty {
                        Section {
                            ForEach(excellentLanguages) { language in
                                languageRow(language, level: .excellent)
                            }
                        } header: {
                            supportSectionHeader(.excellent)
                        }
                    }

                    // Good support
                    if !goodLanguages.isEmpty {
                        Section {
                            ForEach(goodLanguages) { language in
                                languageRow(language, level: .good)
                            }
                        } header: {
                            supportSectionHeader(.good)
                        }
                    }

                    // Limited support
                    if !limitedLanguages.isEmpty {
                        Section {
                            ForEach(limitedLanguages) { language in
                                languageRow(language, level: .limited)
                            }
                        } header: {
                            supportSectionHeader(.limited)
                        } footer: {
                            Text("These languages may have accuracy issues with \(currentProvider.shortName)")
                        }
                    }

                    // Unsupported
                    if !unsupportedLanguages.isEmpty {
                        Section {
                            ForEach(unsupportedLanguages) { language in
                                languageRow(language, level: .unsupported)
                            }
                        } header: {
                            supportSectionHeader(.unsupported)
                        } footer: {
                            Text("\(currentProvider.shortName) doesn't support these languages. Consider switching providers.")
                        }
                    }

                    // Language support guide link
                    Section {
                        Button(action: {
                            showLanguageSupport = true
                        }) {
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundStyle(.purple)
                                Text("View All Language Support")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .listRowBackground(rowBackground)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .searchable(text: $searchText, prompt: "Search languages")
            }
            .navigationTitle("Select Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showLanguageSupport) {
                LanguageSupportView()
            }
        }
    }

    // MARK: - Current Provider Info

    private var currentProviderInfo: some View {
        HStack(spacing: 12) {
            ProviderIcon(currentProvider, size: .large, style: .filled)

            VStack(alignment: .leading, spacing: 2) {
                Text("Using \(currentProvider.displayName)")
                    .font(.callout.weight(.medium))

                Text("for \(capability.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .listRowBackground(rowBackground)
    }

    // MARK: - Section Header

    private func supportSectionHeader(_ level: LanguageSupportLevel) -> some View {
        HStack(spacing: 6) {
            Image(systemName: level.icon)
                .foregroundStyle(level.color)
            Text(level.label)
                .foregroundStyle(level.color)
        }
    }

    // MARK: - Language Row

    private func languageRow(_ language: Language, level: LanguageSupportLevel) -> some View {
        Button(action: {
            HapticManager.selection()
            selection = language
            dismiss()
        }) {
            HStack(spacing: 12) {
                Text(language.flag)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(language.displayName)
                        .font(.callout)
                        .foregroundStyle(level == .unsupported ? .secondary : .primary)

                    // Show recommended provider if not using the best one
                    if let recommended = ProviderLanguageDatabase.recommendedProvider(for: language, capability: capability),
                       recommended != currentProvider,
                       level < .good {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption2)
                            Text("Better with \(recommended.shortName)")
                                .font(.caption2)
                        }
                        .foregroundStyle(.orange)
                    }
                }

                Spacer()

                // Support indicator
                HStack(spacing: 2) {
                    ForEach(0..<3) { i in
                        Image(systemName: i < level.stars ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundStyle(i < level.stars ? level.color : .secondary.opacity(0.2))
                    }
                }

                if selection == language {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(rowBackground)
    }
}

// MARK: - Compact Language Picker Button

/// A compact button that shows the current selection and opens the picker
struct SmartLanguagePickerButton: View {
    @Binding var selection: Language
    let currentProvider: AIProvider
    let capability: ProviderUsageCategory

    @State private var showPicker = false

    private var supportLevel: LanguageSupportLevel {
        ProviderLanguageDatabase.supportLevel(
            provider: currentProvider,
            language: selection,
            for: capability
        )
    }

    var body: some View {
        Button(action: {
            HapticManager.lightTap()
            showPicker = true
        }) {
            HStack(spacing: 8) {
                Text(selection.flag)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 1) {
                    Text(selection.displayName)
                        .font(.callout)
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        Image(systemName: supportLevel.icon)
                            .font(.caption2)
                        Text(supportLevel.shortLabel)
                            .font(.caption2)
                    }
                    .foregroundStyle(supportLevel.color)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPicker) {
            SmartLanguagePicker(
                selection: $selection,
                currentProvider: currentProvider,
                capability: capability
            )
        }
    }
}

// MARK: - Inline Compatibility Indicator

/// Small inline indicator showing if current language is compatible
struct LanguageCompatibilityIndicator: View {
    let language: Language
    let provider: AIProvider
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
                Text(supportLevel == .unsupported ? "Not supported" : "Limited")
            }
            .font(.caption2)
            .foregroundStyle(supportLevel.color)
        }
    }
}

// MARK: - Preview

#Preview("Smart Language Picker") {
    struct PreviewWrapper: View {
        @State private var language: Language = .polish

        var body: some View {
            SmartLanguagePicker(
                selection: $language,
                currentProvider: .deepgram,
                capability: .transcription
            )
        }
    }

    return PreviewWrapper()
        .preferredColorScheme(.dark)
}

#Preview("Smart Language Picker Button") {
    struct PreviewWrapper: View {
        @State private var language: Language = .japanese

        var body: some View {
            List {
                SmartLanguagePickerButton(
                    selection: $language,
                    currentProvider: .openAI,
                    capability: .translation
                )
            }
        }
    }

    return PreviewWrapper()
        .preferredColorScheme(.dark)
}

#Preview("Compatibility Indicators") {
    VStack(spacing: 16) {
        LanguageCompatibilityIndicator(
            language: .polish,
            provider: .deepgram,
            capability: .transcription
        )

        LanguageCompatibilityIndicator(
            language: .arabic,
            provider: .assemblyAI,
            capability: .transcription
        )

        LanguageCompatibilityIndicator(
            language: .english,
            provider: .openAI,
            capability: .transcription
        )
    }
    .padding()
    .background(AppTheme.darkBase)
    .preferredColorScheme(.dark)
}
