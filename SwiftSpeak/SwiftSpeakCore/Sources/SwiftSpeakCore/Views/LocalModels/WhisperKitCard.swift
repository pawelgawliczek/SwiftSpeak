//
//  WhisperKitCard.swift
//  SwiftSpeak
//
//  Shared card component for WhisperKit local model settings
//  Used by both iOS and macOS
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakMac targets
//

import SwiftUI

/// Card component for WhisperKit on-device transcription settings
public struct WhisperKitCard<Settings: LocalModelSettingsProvider>: View {
    @ObservedObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme

    /// Action to trigger model download
    public var onDownload: (WhisperModel) -> Void

    /// Action to delete the downloaded model
    public var onDelete: () -> Void

    /// Action to cancel ongoing download
    public var onCancelDownload: () -> Void

    @State private var selectedModel: WhisperModel = .largeV3Turbo

    public init(
        settings: Settings,
        onDownload: @escaping (WhisperModel) -> Void,
        onDelete: @escaping () -> Void,
        onCancelDownload: @escaping () -> Void
    ) {
        self.settings = settings
        self.onDownload = onDownload
        self.onDelete = onDelete
        self.onCancelDownload = onCancelDownload
        self._selectedModel = State(initialValue: settings.whisperKitConfig.selectedModel)
    }

    private var config: WhisperKitSettings {
        settings.whisperKitConfig
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    private var accentColor: Color {
        .green
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            headerView

            Divider()

            // Content based on state
            switch config.status {
            case .notConfigured, .error:
                notDownloadedView
            case .downloading:
                downloadingView
            case .ready:
                readyView
            case .notAvailable:
                notAvailableView
            }

            // Info footer
            infoFooter
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            selectedModel = config.selectedModel
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundStyle(accentColor)
                .frame(width: 36, height: 36)
                .background(accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("WhisperKit")
                    .font(.headline)

                Text("On-device speech recognition")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status badge
            if config.status == .ready {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text("Ready")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(accentColor.opacity(0.15))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Not Downloaded View

    private var notDownloadedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Model picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Model")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Picker("Model", selection: $selectedModel) {
                    ForEach(WhisperModel.allCases) { model in
                        VStack(alignment: .leading) {
                            Text(model.displayName)
                        }
                        .tag(model)
                    }
                }
                .pickerStyle(.menu)
                .tint(accentColor)

                Text("\(selectedModel.description) \u{2022} \(selectedModel.sizeFormatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Download button
            Button(action: {
                onDownload(selectedModel)
            }) {
                HStack {
                    Spacer()
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Download (\(selectedModel.sizeFormatted))")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .background(accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            // Error message if any
            if config.status == .error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Download failed. Tap to retry.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Downloading View

    private var downloadingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Downloading \(config.selectedModel.displayName)...")
                    .font(.subheadline)

                ProgressView(value: config.downloadProgress)
                    .tint(accentColor)

                HStack {
                    Text(formatBytes(config.downloadedBytes))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(Int(config.downloadProgress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: onCancelDownload) {
                HStack {
                    Spacer()
                    Text("Cancel")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                }
                .foregroundStyle(.red)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Ready View

    private var readyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Model info
            HStack {
                Text("Model")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(config.selectedModel.displayName) \u{2022} \(config.selectedModel.sizeFormatted)")
                    .font(.subheadline)
            }

            // Enable toggle
            Toggle(isOn: Binding(
                get: { config.isEnabled },
                set: { newValue in
                    var updated = settings.whisperKitConfig
                    updated.isEnabled = newValue
                    settings.whisperKitConfig = updated
                }
            )) {
                Text("Use for transcription")
                    .font(.subheadline)
            }
            .tint(accentColor)

            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    // Reset to allow new model selection
                    var updated = settings.whisperKitConfig
                    updated.status = .notConfigured
                    settings.whisperKitConfig = updated
                }) {
                    HStack {
                        Spacer()
                        Text("Change Model")
                            .font(.caption.weight(.medium))
                        Spacer()
                    }
                    .foregroundStyle(accentColor)
                    .padding(.vertical, 8)
                    .background(accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    HStack {
                        Spacer()
                        Text("Delete")
                            .font(.caption.weight(.medium))
                        Spacer()
                    }
                    .foregroundStyle(.red)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Not Available View

    private var notAvailableView: some View {
        HStack(spacing: 12) {
            Image(systemName: "xmark.circle")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Not available on this device")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Requires Apple Silicon (A12+)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Info Footer

    private var infoFooter: some View {
        HStack(spacing: 16) {
            Label("Offline", systemImage: "wifi.slash")
            Label("Private", systemImage: "lock.fill")
            Label("Free", systemImage: "dollarsign.circle")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        if mb >= 1000 {
            return String(format: "%.1f GB", mb / 1024)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }
}
