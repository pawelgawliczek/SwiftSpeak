//
//  AppleTranslationCard.swift
//  SwiftSpeak
//
//  Shared card component for Apple Translation local model settings
//  Used by both iOS and macOS
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakMac targets
//

import SwiftUI

/// Card component for Apple Translation on-device translation settings
public struct AppleTranslationCard<Settings: LocalModelSettingsProvider>: View {
    @ObservedObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme

    /// Action to navigate to language management
    public var onManageLanguages: () -> Void

    public init(
        settings: Settings,
        onManageLanguages: @escaping () -> Void
    ) {
        self.settings = settings
        self.onManageLanguages = onManageLanguages
    }

    private var config: AppleTranslationConfig {
        settings.appleTranslationConfig
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    private var accentColor: Color {
        .blue
    }

    private var downloadedCount: Int {
        config.downloadedLanguages.count
    }

    private var totalStorageBytes: Int {
        config.downloadedLanguages.reduce(0) { $0 + $1.sizeBytes }
    }

    private var storageFormatted: String {
        let mb = Double(totalStorageBytes) / (1024 * 1024)
        if mb >= 1000 {
            return String(format: "%.1f GB", mb / 1024)
        } else if mb >= 1 {
            return String(format: "%.0f MB", mb)
        } else {
            return "< 1 MB"
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            headerView

            Divider()

            // Content
            if config.isAvailable {
                availableView
            } else {
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
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "globe")
                .font(.title2)
                .foregroundStyle(accentColor)
                .frame(width: 36, height: 36)
                .background(accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Translation")
                    .font(.headline)

                Text("On-device translation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status badge
            if downloadedCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text("\(downloadedCount) lang\(downloadedCount == 1 ? "" : "s")")
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

    // MARK: - Available View

    private var availableView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Language count
            HStack {
                Text("Languages")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if downloadedCount > 0 {
                    Text("\(downloadedCount) downloaded (\(storageFormatted))")
                        .font(.subheadline)
                } else {
                    Text("None downloaded")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Manage languages button
            Button(action: onManageLanguages) {
                HStack {
                    Spacer()
                    Text("Manage Languages")
                        .font(.subheadline.weight(.medium))
                    Image(systemName: "chevron.right")
                        .font(.caption)
                    Spacer()
                }
                .foregroundStyle(accentColor)
                .padding(.vertical, 10)
                .background(accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Not Available View

    private var notAvailableView: some View {
        HStack(spacing: 12) {
            Image(systemName: "xmark.circle")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Not available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Requires iOS 17.4+ or macOS 14.4+")
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
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
