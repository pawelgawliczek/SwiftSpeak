//
//  ParakeetCard.swift
//  SwiftSpeak
//
//  Shared card component for Parakeet MLX local model settings
//  Used by macOS only (parakeet-mlx requires Python + Apple Silicon)
//
//  SHARED: This file is in SwiftSpeakCore but only relevant for macOS
//

import SwiftUI

/// Card component for Parakeet MLX on-device transcription settings
public struct ParakeetCard<Settings: LocalModelSettingsProvider>: View {
    @ObservedObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme

    /// Action to check if parakeet-mlx is installed
    public var onCheckInstallation: () -> Void

    /// Action to reset/reconfigure
    public var onReset: () -> Void

    @State private var modelId: String

    public init(
        settings: Settings,
        onCheckInstallation: @escaping () -> Void,
        onReset: @escaping () -> Void
    ) {
        self.settings = settings
        self.onCheckInstallation = onCheckInstallation
        self.onReset = onReset
        self._modelId = State(initialValue: settings.parakeetMLXConfig.modelId)
    }

    private var config: ParakeetMLXSettings {
        settings.parakeetMLXConfig
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    private var accentColor: Color {
        .orange
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            headerView

            Divider()

            // Content based on state
            switch config.status {
            case .notConfigured:
                notConfiguredView
            case .downloading:
                checkingView
            case .ready:
                readyView
            case .notAvailable:
                notAvailableView
            case .error:
                errorView
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
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "bird")
                .font(.title2)
                .foregroundStyle(accentColor)
                .frame(width: 36, height: 36)
                .background(accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Parakeet MLX")
                        .font(.headline)

                    Text("macOS")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue)
                        .clipShape(Capsule())
                }

                Text("NVIDIA Parakeet TDT v3 \u{00B7} 25 languages")
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

    // MARK: - Not Configured View

    private var notConfiguredView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Install parakeet-mlx to enable on-device transcription with Parakeet TDT v3.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Installation")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack {
                    Text("pip install parakeet-mlx")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    Spacer()

                    Button {
                        #if canImport(AppKit)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("pip install parakeet-mlx", forType: .string)
                        #endif
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }

            // Check Installation button
            Button(action: onCheckInstallation) {
                HStack {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                    Text("Check Installation")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .background(accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Checking View (reuses .downloading status)

    private var checkingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking installation...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
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

                Text(config.modelId.components(separatedBy: "/").last ?? config.modelId)
                    .font(.subheadline)
            }

            // Enable toggle
            Toggle(isOn: Binding(
                get: { config.isEnabled },
                set: { newValue in
                    var updated = settings.parakeetMLXConfig
                    updated.isEnabled = newValue
                    settings.parakeetMLXConfig = updated
                }
            )) {
                Text("Use for transcription")
                    .font(.subheadline)
            }
            .tint(accentColor)

            // Supported languages info
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("English, Spanish, French, German, Italian, Portuguese, Polish, Russian + 17 more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: onCheckInstallation) {
                    HStack {
                        Spacer()
                        Text("Re-check")
                            .font(.caption.weight(.medium))
                        Spacer()
                    }
                    .foregroundStyle(accentColor)
                    .padding(.vertical, 8)
                    .background(accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: onReset) {
                    HStack {
                        Spacer()
                        Text("Reset")
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
                Text("Not available on this platform")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Requires macOS with Apple Silicon")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                Text(config.errorMessage ?? "Installation check failed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button(action: onCheckInstallation) {
                HStack {
                    Spacer()
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .background(accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
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
}
