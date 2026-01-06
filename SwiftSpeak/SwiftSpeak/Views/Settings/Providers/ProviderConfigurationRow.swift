//
//  ProviderConfigurationRow.swift
//  SwiftSpeak
//
//  Remote configuration status row
//

import SwiftUI
import SwiftSpeakCore

// MARK: - Provider Configuration Row

struct ProviderConfigurationRow: View {
    @StateObject private var configManager = RemoteConfigManager.shared
    @State private var isRefreshing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status row
            HStack(spacing: 12) {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundStyle(statusColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Provider Configuration")
                        .font(.callout.weight(.medium))

                    if let lastFetch = configManager.lastFetchDate {
                        Text("Updated \(lastFetch, format: .relative(presentation: .named))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Using bundled defaults")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if configManager.isLoading || isRefreshing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button {
                        refreshConfig()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.blue)
                    }
                }
            }

            // What gets synced
            VStack(alignment: .leading, spacing: 6) {
                Text("Syncs from cloud:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    SyncBadge(icon: "dollarsign.circle", label: "Prices", color: .green)
                    SyncBadge(icon: "cpu", label: "Models", color: .blue)
                    SyncBadge(icon: "globe", label: "Languages", color: .purple)
                    SyncBadge(icon: "gearshape", label: "Features", color: .orange)
                }
            }

            // Version info
            if let version = configManager.config?.version {
                HStack {
                    Text("Config v\(version)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if configManager.isConfigStale {
                        Text("• Stale")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: String {
        if configManager.isConfigStale {
            return "exclamationmark.triangle.fill"
        } else if configManager.lastFetchDate != nil {
            return "checkmark.circle.fill"
        } else {
            return "arrow.down.circle"
        }
    }

    private var statusColor: Color {
        if configManager.isConfigStale {
            return .orange
        } else if configManager.lastFetchDate != nil {
            return .green
        } else {
            return .secondary
        }
    }

    private func refreshConfig() {
        Task {
            isRefreshing = true
            HapticManager.lightTap()
            await configManager.forceRefresh()
            isRefreshing = false
            HapticManager.success()
        }
    }
}

// MARK: - Sync Badge

struct SyncBadge: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption2)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.15), in: Capsule())
    }
}
