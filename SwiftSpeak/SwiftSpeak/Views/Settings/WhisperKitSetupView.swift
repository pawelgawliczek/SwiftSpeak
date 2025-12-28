//
//  WhisperKitSetupView.swift
//  SwiftSpeak
//
//  Phase 10: WhisperKit on-device transcription setup
//

import SwiftUI

struct WhisperKitSetupView: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var selectedModel: WhisperModel = .largeV3
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var showDeleteConfirmation = false

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    // Simulated device chip generation (in real app, detect from device)
    private var deviceChipGeneration: Int {
        // For demo purposes, assume A15 (iPhone 13/14)
        // In production, use ProcessInfo or device model detection
        15
    }

    private var isModelReady: Bool {
        settings.whisperKitConfig.status == .ready
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            List {
                // Header Section
                headerSection

                // Model Selection Section
                modelSelectionSection

                // Download/Status Section
                downloadSection

                // Storage Section
                if isModelReady {
                    storageSection
                }

                // Enable Section
                if isModelReady {
                    enableSection
                }

                // Delete Section
                if isModelReady {
                    deleteSection
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("WhisperKit")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedModel = settings.whisperKitConfig.selectedModel
        }
        .alert("Delete Model?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteModel()
            }
        } message: {
            Text("This will remove the downloaded model and free up \(settings.whisperKitConfig.selectedModel.sizeFormatted) of storage.")
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
                            colors: [.green.opacity(0.3), .green.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.green)
                }

                VStack(spacing: 8) {
                    Text("WhisperKit")
                        .font(.title2.weight(.bold))

                    Text("On-device speech recognition powered by OpenAI's Whisper model. All processing happens locally on your device.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Benefits
                HStack(spacing: 20) {
                    BenefitBadge(icon: "lock.shield", text: "Private")
                    BenefitBadge(icon: "wifi.slash", text: "Offline")
                    BenefitBadge(icon: "bolt", text: "Fast")
                }
            }
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Model Selection Section

    private var modelSelectionSection: some View {
        Section {
            ForEach(WhisperModel.allCases, id: \.self) { model in
                ModelSelectionRow(
                    model: model,
                    isSelected: selectedModel == model,
                    isRecommended: model == WhisperModel.recommendedModel(forChipGeneration: deviceChipGeneration),
                    chipGeneration: deviceChipGeneration,
                    colorScheme: colorScheme
                ) {
                    HapticManager.selection()
                    selectedModel = model
                }
                .listRowBackground(rowBackground)
            }
        } header: {
            Text("Select Model")
        } footer: {
            Text("Larger models are more accurate but require more storage and processing power. Recommended models are optimized for your device.")
        }
    }

    // MARK: - Download Section

    private var downloadSection: some View {
        Section {
            if isDownloading {
                // Download progress
                VStack(spacing: 12) {
                    HStack {
                        Text("Downloading \(selectedModel.displayName)...")
                            .font(.callout)

                        Spacer()

                        Text("\(Int(downloadProgress * 100))%")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: downloadProgress)
                        .tint(.green)

                    HStack {
                        Text(formatBytes(Int(Double(selectedModel.sizeBytes) * downloadProgress)))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(selectedModel.sizeFormatted)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(rowBackground)
            } else if settings.whisperKitConfig.status == .ready && selectedModel == settings.whisperKitConfig.selectedModel {
                // Already downloaded
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Model Ready")
                            .font(.callout.weight(.medium))

                        Text("\(selectedModel.displayName) is downloaded and ready to use")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(rowBackground)
            } else {
                // Download button
                Button(action: {
                    startDownload()
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Download Model")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.primary)

                            Text("\(selectedModel.sizeFormatted) required")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("Download")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.green)
                            .clipShape(Capsule())
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(rowBackground)
            }
        } header: {
            Text("Download")
        } footer: {
            if !isDownloading && settings.whisperKitConfig.status != .ready {
                Text("Models are downloaded from Hugging Face. Download size: \(selectedModel.sizeFormatted)")
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
                    Text("Storage Used")
                        .font(.callout)

                    Text(settings.whisperKitConfig.selectedModel.sizeFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let date = settings.whisperKitConfig.lastDownloadDate {
                    Text("Downloaded \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .listRowBackground(rowBackground)
        } header: {
            Text("Storage")
        }
    }

    // MARK: - Enable Section

    private var enableSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { settings.whisperKitConfig.isEnabled },
                set: { enabled in
                    var config = settings.whisperKitConfig
                    config.isEnabled = enabled
                    settings.whisperKitConfig = config
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use WhisperKit for Transcription")
                        .font(.callout)

                    Text("Replace cloud transcription with on-device processing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.green)
            .listRowBackground(rowBackground)
        } header: {
            Text("Settings")
        } footer: {
            Text("When enabled, WhisperKit will be used for all transcription instead of cloud providers. This ensures complete privacy.")
        }
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        Section {
            Button(role: .destructive, action: {
                showDeleteConfirmation = true
            }) {
                HStack {
                    Spacer()
                    Text("Delete Downloaded Model")
                    Spacer()
                }
            }
            .listRowBackground(rowBackground)
        } footer: {
            Text("This will free up \(settings.whisperKitConfig.selectedModel.sizeFormatted) of storage. You can re-download at any time.")
        }
    }

    // MARK: - Actions

    private func startDownload() {
        isDownloading = true
        downloadProgress = 0

        // Update config with selected model
        var config = settings.whisperKitConfig
        config.selectedModel = selectedModel
        config.status = .downloading
        settings.whisperKitConfig = config

        // Simulate download progress
        // In production, this would use actual WhisperKit download API
        Task { @MainActor in
            while downloadProgress < 1.0 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

                downloadProgress += 0.02

                // Update config progress
                var config = settings.whisperKitConfig
                config.downloadProgress = downloadProgress
                config.downloadedBytes = Int(Double(selectedModel.sizeBytes) * downloadProgress)
                settings.whisperKitConfig = config
            }

            isDownloading = false

            // Mark as ready
            var finalConfig = settings.whisperKitConfig
            finalConfig.status = .ready
            finalConfig.downloadProgress = 1.0
            finalConfig.downloadedBytes = selectedModel.sizeBytes
            finalConfig.lastDownloadDate = Date()
            settings.whisperKitConfig = finalConfig

            HapticManager.success()
        }
    }

    private func deleteModel() {
        var config = settings.whisperKitConfig
        config.status = .notConfigured
        config.isEnabled = false
        config.downloadProgress = 0
        config.downloadedBytes = 0
        config.lastDownloadDate = nil
        settings.whisperKitConfig = config

        HapticManager.lightTap()
    }

    private func formatBytes(_ bytes: Int) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        if mb >= 1000 {
            return String(format: "%.1f GB", mb / 1024)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }
}

// MARK: - Benefit Badge

private struct BenefitBadge: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.green)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Model Selection Row

private struct ModelSelectionRow: View {
    let model: WhisperModel
    let isSelected: Bool
    let isRecommended: Bool
    let chipGeneration: Int
    let colorScheme: ColorScheme
    let onSelect: () -> Void

    private var performanceIndicator: (icon: String, color: Color, text: String)? {
        if model.isNotRecommended(chipGeneration) {
            return ("exclamationmark.triangle.fill", .orange, "May be slow")
        } else if model.mayHavePerformanceIssues(chipGeneration) {
            return ("exclamationmark.circle", .yellow, "May be slow")
        }
        return nil
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .green : Color.secondary.opacity(0.3))

                // Model info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(model.displayName)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.primary)

                        if isRecommended {
                            Text("RECOMMENDED")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.green)
                                .clipShape(Capsule())
                        }

                        if model.isEnglishOnly {
                            Text("EN")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.blue)
                                .clipShape(Capsule())
                        }
                    }

                    Text(model.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let warning = performanceIndicator {
                        HStack(spacing: 4) {
                            Image(systemName: warning.icon)
                                .font(.caption2)
                            Text(warning.text)
                                .font(.caption2)
                        }
                        .foregroundStyle(warning.color)
                    }
                }

                Spacer()

                // Size
                Text(model.sizeFormatted)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        WhisperKitSetupView()
            .environmentObject(SharedSettings.shared)
    }
}
