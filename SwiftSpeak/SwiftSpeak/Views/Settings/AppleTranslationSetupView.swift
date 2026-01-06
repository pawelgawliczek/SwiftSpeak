//
//  AppleTranslationSetupView.swift
//  SwiftSpeak
//
//  Phase 10: Apple Translation on-device translation setup
//

import SwiftUI
import SwiftSpeakCore

struct AppleTranslationSetupView: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme
    @State private var showAddLanguage = false
    @State private var languageToDelete: DownloadedTranslationLanguage?
    @State private var showDeleteConfirmation = false

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    private var downloadedLanguages: [DownloadedTranslationLanguage] {
        settings.appleTranslationConfig.downloadedLanguages
    }

    private var totalStorageUsed: String {
        let total = downloadedLanguages.reduce(0) { $0 + $1.sizeBytes }
        let mb = Double(total) / (1024 * 1024)
        if mb >= 1000 {
            return String(format: "%.1f GB", mb / 1024)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            List {
                // Header Section
                headerSection

                // Downloaded Languages Section
                downloadedLanguagesSection

                // Storage Section
                if !downloadedLanguages.isEmpty {
                    storageSection
                }

                // Info Section
                infoSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Apple Translation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    showAddLanguage = true
                }) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                }
            }
        }
        .sheet(isPresented: $showAddLanguage) {
            AddTranslationLanguageSheet()
        }
        .alert("Delete Language?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                languageToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let lang = languageToDelete {
                    deleteLanguage(lang)
                }
                languageToDelete = nil
            }
        } message: {
            if let lang = languageToDelete {
                Text("This will remove \(lang.language.displayName) and free up \(lang.sizeFormatted) of storage.")
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        Section {
            VStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)

                    Image(systemName: "globe")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: 8) {
                    Text("Apple Translation")
                        .font(.title2.weight(.bold))

                    Text("Download language packs for offline translation. Translations are processed entirely on your device.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Benefits
                HStack(spacing: 20) {
                    BenefitBadge(icon: "wifi.slash", text: "Offline", color: .blue)
                    BenefitBadge(icon: "lock.shield", text: "Private", color: .green)
                    BenefitBadge(icon: "sparkles", text: "Accurate", color: .orange)
                }
            }
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Downloaded Languages Section

    private var downloadedLanguagesSection: some View {
        Section {
            if downloadedLanguages.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "globe.badge.chevron.backward")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)

                    Text("No Languages Downloaded")
                        .font(.headline)

                    Text("Download language packs to translate offline")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button(action: {
                        showAddLanguage = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Language")
                        }
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.blue)
                        .clipShape(Capsule())
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .listRowBackground(Color.clear)
            } else {
                // Downloaded languages list
                ForEach(downloadedLanguages) { lang in
                    DownloadedLanguageRow(
                        language: lang,
                        colorScheme: colorScheme,
                        onDelete: lang.isSystem ? nil : {
                            languageToDelete = lang
                            showDeleteConfirmation = true
                        }
                    )
                    .listRowBackground(rowBackground)
                }

                // Add more button
                Button(action: {
                    showAddLanguage = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)

                        Text("Add Language")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                }
                .listRowBackground(rowBackground)
            }
        } header: {
            if !downloadedLanguages.isEmpty {
                Text("Downloaded Languages")
            }
        } footer: {
            if !downloadedLanguages.isEmpty {
                Text("System languages cannot be removed. Swipe left on other languages to delete them.")
            }
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "externaldrive.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Storage Used")
                        .font(.callout)

                    Text("\(downloadedLanguages.count) language\(downloadedLanguages.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(totalStorageUsed)
                    .font(.callout.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(rowBackground)
        } header: {
            Text("Storage")
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("About Apple Translation")
                        .font(.callout.weight(.medium))

                    Text("Language packs are managed by iOS. Downloads may take a few minutes depending on your connection.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(rowBackground)
        }
    }

    // MARK: - Actions

    private func deleteLanguage(_ lang: DownloadedTranslationLanguage) {
        var config = settings.appleTranslationConfig
        config.downloadedLanguages.removeAll { $0.id == lang.id }
        settings.appleTranslationConfig = config
        HapticManager.lightTap()
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

// MARK: - Downloaded Language Row

private struct DownloadedLanguageRow: View {
    let language: DownloadedTranslationLanguage
    let colorScheme: ColorScheme
    let onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Text(language.language.flag)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(language.language.displayName)
                        .font(.callout.weight(.medium))

                    if language.isSystem {
                        Text("SYSTEM")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.blue)
                            .clipShape(Capsule())
                    }
                }

                Text(language.sizeFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Add Translation Language Sheet

struct AddTranslationLanguageSheet: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var searchText = ""
    @State private var downloadingLanguages: Set<Language> = []

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    private var downloadedLanguageIds: Set<String> {
        Set(settings.appleTranslationConfig.downloadedLanguages.map { $0.language.rawValue })
    }

    private var availableLanguages: [Language] {
        let available = Language.allCases.filter { !downloadedLanguageIds.contains($0.rawValue) }

        if searchText.isEmpty {
            return available
        }
        return available.filter { lang in
            lang.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    // Popular languages to show first
    private var popularLanguages: [Language] {
        [.english, .spanish, .french, .german, .italian, .portuguese, .chinese, .japanese, .korean]
            .filter { !downloadedLanguageIds.contains($0.rawValue) }
    }

    private var otherLanguages: [Language] {
        availableLanguages.filter { !popularLanguages.contains($0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                List {
                    if searchText.isEmpty && !popularLanguages.isEmpty {
                        Section {
                            ForEach(popularLanguages, id: \.self) { language in
                                languageRow(for: language)
                                    .listRowBackground(rowBackground)
                            }
                        } header: {
                            Text("Popular")
                        }
                    }

                    Section {
                        ForEach(searchText.isEmpty ? otherLanguages : availableLanguages, id: \.self) { language in
                            languageRow(for: language)
                                .listRowBackground(rowBackground)
                        }
                    } header: {
                        Text(searchText.isEmpty ? "All Languages" : "Results")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .searchable(text: $searchText, prompt: "Search languages")
            }
            .navigationTitle("Add Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func languageRow(for language: Language) -> some View {
        Button(action: {
            downloadLanguage(language)
        }) {
            HStack(spacing: 12) {
                Text(language.flag)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(language.displayName)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)

                    Text("~50-100 MB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if downloadingLanguages.contains(language) {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(.blue)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(downloadingLanguages.contains(language))
    }

    private func downloadLanguage(_ language: Language) {
        downloadingLanguages.insert(language)
        HapticManager.lightTap()

        // Simulate download
        // In production, this would use Translation framework
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            let downloaded = DownloadedTranslationLanguage(
                language: language,
                sizeBytes: Int.random(in: 50...100) * 1024 * 1024,
                isSystem: false
            )

            var config = settings.appleTranslationConfig
            config.downloadedLanguages.append(downloaded)
            settings.appleTranslationConfig = config

            downloadingLanguages.remove(language)
            HapticManager.success()
        }
    }
}

#Preview {
    NavigationStack {
        AppleTranslationSetupView()
            .environmentObject({
                let settings = SharedSettings.shared
                settings.appleTranslationConfig = AppleTranslationConfig(
                    isAvailable: true,
                    downloadedLanguages: [
                        DownloadedTranslationLanguage(language: .english, sizeBytes: 85 * 1024 * 1024, isSystem: true),
                        DownloadedTranslationLanguage(language: .spanish, sizeBytes: 72 * 1024 * 1024, isSystem: false)
                    ]
                )
                return settings
            }())
    }
}

#Preview("Empty") {
    NavigationStack {
        AppleTranslationSetupView()
            .environmentObject(SharedSettings.shared)
    }
}
