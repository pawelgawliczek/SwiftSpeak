//
//  ConfiguredProviderRows.swift
//  SwiftSpeak
//
//  Provider row components for settings
//

import SwiftUI
import SwiftSpeakCore

// MARK: - Configured AI Provider Row

struct ConfiguredAIProviderRow: View {
    let config: AIProviderConfig
    let colorScheme: ColorScheme
    let onEdit: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.lightTap()
            onEdit()
        }) {
            HStack(spacing: 12) {
                // Provider icon
                ProviderIcon(config.provider, size: .medium, style: .filled)

                // Provider info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(config.provider.displayName)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.primary)

                        if config.provider.requiresPowerTier {
                            Text("POWER")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }

                        if config.provider.requiresAPIKey {
                            Circle()
                                .fill(config.apiKey.isEmpty ? .orange : .green)
                                .frame(width: 6, height: 6)
                        }
                    }

                    // Show model per category
                    HStack(spacing: 6) {
                        ForEach(config.detailedModelSummary, id: \.0) { category, model in
                            HStack(spacing: 3) {
                                Image(systemName: category.icon)
                                    .font(.caption2)
                                Text(model)
                                    .font(.caption2)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(categoryColor(for: category))
                            .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func categoryColor(for category: ProviderUsageCategory) -> Color {
        switch category {
        case .transcription: return .blue
        case .translation: return .purple
        case .formatting, .powerMode: return .orange
        }
    }
}

// MARK: - Free Provider Row (for Free tier users)

struct FreeProviderRow: View {
    let provider: AIProvider
    let existingConfig: AIProviderConfig?
    let isDisabled: Bool
    let colorScheme: ColorScheme
    let onTap: () -> Void

    private var isConfigured: Bool {
        guard let config = existingConfig else { return false }
        return !config.apiKey.isEmpty
    }

    private var statusText: String {
        if isDisabled {
            return "Upgrade to Pro to add"
        } else if isConfigured {
            return "Configured"
        } else {
            return "Tap to configure"
        }
    }

    private var displayName: String {
        provider == .google ? "Gemini" : provider.displayName
    }

    var body: some View {
        Button(action: {
            HapticManager.lightTap()
            onTap()
        }) {
            HStack(spacing: 12) {
                // Provider icon
                ProviderIcon(provider, size: .medium, style: .filled, isDisabled: isDisabled)

                // Provider info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(displayName)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(isDisabled ? .secondary : .primary)

                        // Status indicator
                        if isConfigured {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                        }
                    }

                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isDisabled {
                    HStack(spacing: 4) {
                        Text("PRO")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.accent)
                            .clipShape(Capsule())

                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if !isConfigured {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
