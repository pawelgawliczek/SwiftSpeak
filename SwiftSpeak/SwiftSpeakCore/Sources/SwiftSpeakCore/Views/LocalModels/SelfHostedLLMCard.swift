//
//  SelfHostedLLMCard.swift
//  SwiftSpeak
//
//  Shared card component for self-hosted LLM settings (Ollama, LM Studio)
//  Used by both iOS and macOS
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakMac targets
//

import SwiftUI

/// Card component for self-hosted LLM (Ollama, LM Studio) settings
public struct SelfHostedLLMCard<Settings: LocalModelSettingsProvider>: View {
    @ObservedObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme

    /// Action to navigate to server configuration
    public var onConfigure: () -> Void

    public init(
        settings: Settings,
        onConfigure: @escaping () -> Void
    ) {
        self.settings = settings
        self.onConfigure = onConfigure
    }

    private var config: LocalProviderConfig? {
        settings.selfHostedLLMConfig
    }

    private var isConfigured: Bool {
        config != nil && !(config?.baseURL.isEmpty ?? true)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    private var accentColor: Color {
        .gray
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            headerView

            Divider()

            // Content
            if isConfigured {
                configuredView
            } else {
                notConfiguredView
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
            Image(systemName: "desktopcomputer")
                .font(.title2)
                .foregroundStyle(accentColor)
                .frame(width: 36, height: 36)
                .background(accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Self-Hosted LLM")
                    .font(.headline)

                Text("Ollama, LM Studio, or compatible")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status badge
            if isConfigured {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text("Connected")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.15))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Configured View

    private var configuredView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Server info
            if let config = config {
                HStack {
                    Text("Server")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(config.baseURL)
                        .font(.subheadline.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if let model = config.defaultModel, !model.isEmpty {
                    HStack {
                        Text("Model")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(model)
                            .font(.subheadline)
                    }
                }
            }

            // Configure button
            Button(action: onConfigure) {
                HStack {
                    Spacer()
                    Text("Configure")
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

    // MARK: - Not Configured View

    private var notConfiguredView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "circle.dashed")
                    .foregroundStyle(.secondary)

                Text("Not configured")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Configure button
            Button(action: onConfigure) {
                HStack {
                    Spacer()
                    Text("Configure Server")
                        .font(.subheadline.weight(.medium))
                    Image(systemName: "chevron.right")
                        .font(.caption)
                    Spacer()
                }
                .foregroundStyle(.primary)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Info Footer

    private var infoFooter: some View {
        HStack(spacing: 16) {
            Label("Your hardware", systemImage: "cpu")
            Label("Private", systemImage: "lock.fill")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
