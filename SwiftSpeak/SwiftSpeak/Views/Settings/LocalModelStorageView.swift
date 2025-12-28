//
//  LocalModelStorageView.swift
//  SwiftSpeak
//
//  Phase 10: View for managing local model storage
//

import SwiftUI

struct LocalModelStorageView: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme
    @State private var showDeleteAllConfirmation = false

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    private var totalStorageBytes: Int {
        settings.localModelStorageBytes
    }

    private var totalStorageFormatted: String {
        formatBytes(totalStorageBytes)
    }

    private var hasDownloadedModels: Bool {
        settings.whisperKitConfig.status == .ready ||
        !settings.appleTranslationConfig.downloadedLanguages.filter { !$0.isSystem }.isEmpty
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            List {
                // Summary Section
                summarySection

                // WhisperKit Section
                if settings.whisperKitConfig.status == .ready {
                    whisperKitSection
                }

                // Apple Translation Section
                if !settings.appleTranslationConfig.downloadedLanguages.isEmpty {
                    translationSection
                }

                // Actions Section
                if hasDownloadedModels {
                    actionsSection
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Model Storage")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete All Models?", isPresented: $showDeleteAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllModels()
            }
        } message: {
            Text("This will remove all downloaded models and free up \(totalStorageFormatted). You can re-download them at any time.")
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        Section {
            VStack(spacing: 20) {
                // Storage ring
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 12)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0, to: storageProgress)
                        .stroke(
                            LinearGradient(
                                colors: [.green, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text(totalStorageFormatted)
                            .font(.title3.weight(.bold))
                        Text("Used")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Breakdown
                HStack(spacing: 24) {
                    StorageStatBadge(
                        icon: "mic.fill",
                        label: "WhisperKit",
                        value: whisperKitStorageFormatted,
                        color: .green
                    )

                    StorageStatBadge(
                        icon: "globe",
                        label: "Translation",
                        value: translationStorageFormatted,
                        color: .blue
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .listRowBackground(Color.clear)
        }
    }

    private var storageProgress: Double {
        // Assume 5GB max for visualization
        let maxBytes = 5.0 * 1024 * 1024 * 1024
        return min(Double(totalStorageBytes) / maxBytes, 1.0)
    }

    private var whisperKitStorageFormatted: String {
        if settings.whisperKitConfig.status == .ready {
            return formatBytes(settings.whisperKitConfig.selectedModel.sizeBytes)
        }
        return "0 MB"
    }

    private var translationStorageFormatted: String {
        let total = settings.appleTranslationConfig.downloadedLanguages
            .filter { !$0.isSystem }
            .reduce(0) { $0 + $1.sizeBytes }
        return formatBytes(total)
    }

    // MARK: - WhisperKit Section

    private var whisperKitSection: some View {
        Section {
            NavigationLink {
                WhisperKitSetupView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "mic.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("WhisperKit")
                            .font(.callout.weight(.medium))

                        Text(settings.whisperKitConfig.selectedModel.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(formatBytes(settings.whisperKitConfig.selectedModel.sizeBytes))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(rowBackground)
        } header: {
            Text("Speech Recognition")
        }
    }

    // MARK: - Translation Section

    private var translationSection: some View {
        Section {
            ForEach(settings.appleTranslationConfig.downloadedLanguages) { lang in
                HStack(spacing: 12) {
                    Text(lang.language.flag)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(lang.language.displayName)
                                .font(.callout.weight(.medium))

                            if lang.isSystem {
                                Text("SYSTEM")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Spacer()

                    Text(lang.sizeFormatted)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(rowBackground)
            }

            NavigationLink {
                AppleTranslationSetupView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)

                    Text("Manage Languages")
                        .font(.callout)
                }
            }
            .listRowBackground(rowBackground)
        } header: {
            Text("Translation Languages")
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        Section {
            Button(role: .destructive, action: {
                showDeleteAllConfirmation = true
            }) {
                HStack {
                    Spacer()
                    Text("Delete All Downloaded Models")
                    Spacer()
                }
            }
            .listRowBackground(rowBackground)
        } footer: {
            Text("Deleting models will free up storage space. You can re-download them at any time when needed.")
        }
    }

    // MARK: - Actions

    private func deleteAllModels() {
        // Reset WhisperKit
        var whisperConfig = settings.whisperKitConfig
        whisperConfig.status = .notConfigured
        whisperConfig.isEnabled = false
        whisperConfig.downloadProgress = 0
        whisperConfig.downloadedBytes = 0
        whisperConfig.lastDownloadDate = nil
        settings.whisperKitConfig = whisperConfig

        // Remove non-system translation languages
        var translationConfig = settings.appleTranslationConfig
        translationConfig.downloadedLanguages = translationConfig.downloadedLanguages.filter { $0.isSystem }
        settings.appleTranslationConfig = translationConfig

        HapticManager.success()
    }

    private func formatBytes(_ bytes: Int) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        if mb >= 1000 {
            return String(format: "%.1f GB", mb / 1024)
        } else if mb >= 1 {
            return String(format: "%.0f MB", mb)
        } else {
            return "0 MB"
        }
    }
}

// MARK: - Storage Stat Badge

private struct StorageStatBadge: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption.weight(.medium))
        }
    }
}

#Preview {
    NavigationStack {
        LocalModelStorageView()
            .environmentObject({
                let settings = SharedSettings.shared
                settings.whisperKitConfig = WhisperKitSettings(
                    selectedModel: .largeV3,
                    status: .ready,
                    downloadProgress: 1.0,
                    downloadedBytes: 1500 * 1024 * 1024,
                    lastDownloadDate: Date(),
                    isEnabled: true
                )
                settings.appleTranslationConfig = AppleTranslationConfig(
                    isAvailable: true,
                    downloadedLanguages: [
                        DownloadedTranslationLanguage(language: .english, sizeBytes: 85 * 1024 * 1024, isSystem: true),
                        DownloadedTranslationLanguage(language: .spanish, sizeBytes: 72 * 1024 * 1024, isSystem: false),
                        DownloadedTranslationLanguage(language: .french, sizeBytes: 68 * 1024 * 1024, isSystem: false)
                    ]
                )
                return settings
            }())
    }
}

#Preview("Empty") {
    NavigationStack {
        LocalModelStorageView()
            .environmentObject(SharedSettings.shared)
    }
}
