//
//  AppleIntelligenceCard.swift
//  SwiftSpeak
//
//  Shared card component for Apple Intelligence local model settings
//  Used by both iOS and macOS
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakMac targets
//

import SwiftUI

/// Card component for Apple Intelligence on-device formatting settings
public struct AppleIntelligenceCard<Settings: LocalModelSettingsProvider>: View {
    @ObservedObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme

    public init(settings: Settings) {
        self.settings = settings
    }

    private var config: AppleIntelligenceConfig {
        settings.appleIntelligenceConfig
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    private var accentColor: Color {
        .purple
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
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundStyle(accentColor)
                .frame(width: 36, height: 36)
                .background(accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Intelligence")
                    .font(.headline)

                Text("On-device text formatting")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status badge
            if config.isEnabled && config.isAvailable {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text("Enabled")
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
            // Availability status
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)

                Text("Available on this device")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Enable toggle
            Toggle(isOn: Binding(
                get: { config.isEnabled },
                set: { newValue in
                    var updated = settings.appleIntelligenceConfig
                    updated.isEnabled = newValue
                    settings.appleIntelligenceConfig = updated
                }
            )) {
                Text("Use for formatting")
                    .font(.subheadline)
            }
            .tint(accentColor)
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

                Text(config.unavailableReason ?? "Requires iPhone 15 Pro or later")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Info Footer

    private var infoFooter: some View {
        HStack(spacing: 16) {
            Label("Private", systemImage: "lock.fill")
            Label("Built-in", systemImage: "sparkles")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
