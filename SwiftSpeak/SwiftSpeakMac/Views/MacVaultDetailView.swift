//
//  MacVaultDetailView.swift
//  SwiftSpeakMac
//
//  Detailed vault view for macOS with refresh/re-index controls
//  Shows vault status, change detection, and allows delta updates
//

import SwiftUI
import SwiftSpeakCore

struct MacVaultDetailView: View {
    let vault: ObsidianVault
    let hasChanges: Bool
    let changedPathsCount: Int
    let onFullReindex: () -> Void
    let onDeltaUpdate: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with vault icon and name
                header

                // Status Section
                statusSection

                // Change Detection Section
                if hasChanges {
                    changeDetectionSection
                }

                // Paths Section
                pathsSection

                // Settings Section
                settingsSection

                // Usage Section
                usageSection

                Spacer()

                // Danger Zone
                dangerZone
            }
            .padding(24)
        }
        .navigationTitle(vault.name)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if vault.status != .indexing && vault.status != .syncing {
                    Menu {
                        Button(action: onDeltaUpdate) {
                            Label("Refresh (Delta Update)", systemImage: "arrow.clockwise")
                        }
                        .disabled(!hasChanges)

                        Button(action: onFullReindex) {
                            Label("Re-Index (Full)", systemImage: "arrow.triangle.2.circlepath")
                        }

                        Divider()

                        Button(role: .destructive, action: onDelete) {
                            Label("Delete Vault", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 64, height: 64)
                Image("ObsidianIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(vault.name)
                    .font(.title2)
                    .fontWeight(.semibold)

                if vault.noteCount > 0 {
                    Text("\(vault.noteCount) notes, \(vault.chunkCount) chunks")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not indexed")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: vault.status.icon)
                        .foregroundStyle(statusColor)
                    Text("Status")
                        .font(.headline)
                }

                HStack {
                    Text(vault.statusMessage)
                        .foregroundStyle(.secondary)

                    Spacer()

                    statusBadge
                }

                if let lastIndexed = vault.lastIndexed {
                    Divider()

                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text("Last Indexed:")
                            .foregroundStyle(.secondary)
                        Text(lastIndexed.formatted(.relative(presentation: .named)))
                            .fontWeight(.medium)
                    }
                    .font(.callout)
                }
            }
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(vault.status.rawValue.capitalized)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch vault.status {
        case .notConfigured: return .gray
        case .indexing, .syncing, .downloading: return .blue
        case .synced: return .green
        case .needsRefresh: return .orange
        case .error: return .red
        }
    }

    // MARK: - Change Detection Section

    private var changeDetectionSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Changes Detected")
                        .font(.headline)
                }

                Text("\(changedPathsCount) note\(changedPathsCount == 1 ? "" : "s") modified since last index")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button(action: onDeltaUpdate) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh (\(changedPathsCount) notes)")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    Text("Delta update - only re-index changed notes")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Paths Section

    private var pathsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "folder")
                        .foregroundStyle(.blue)
                    Text("File Paths")
                        .font(.headline)
                }

                if let localPath = vault.localPath {
                    pathRow(label: "Local Path", path: localPath, icon: "folder")
                }

                pathRow(label: "iCloud Path", path: vault.iCloudPath, icon: "icloud")
            }
        }
    }

    private func pathRow(label: String, path: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(path)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .textSelection(.enabled)
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.purple)
                    Text("Settings")
                        .font(.headline)
                }

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    settingCard(
                        title: "Daily Notes",
                        value: vault.dailyNotePath,
                        icon: "calendar",
                        color: .blue
                    )

                    settingCard(
                        title: "New Notes Folder",
                        value: vault.newNotesFolder.isEmpty ? "Root" : vault.newNotesFolder,
                        icon: "folder.badge.plus",
                        color: .green
                    )

                    settingCard(
                        title: "Auto Refresh",
                        value: vault.autoRefreshEnabled ? "Enabled" : "Disabled",
                        icon: "arrow.clockwise",
                        color: vault.autoRefreshEnabled ? .green : .gray
                    )
                }
            }
        }
    }

    private func settingCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.callout)
                .fontWeight(.medium)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Usage Section

    private var usageSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.bar")
                        .foregroundStyle(.green)
                    Text("Usage")
                        .font(.headline)
                }

                HStack(spacing: 24) {
                    usageStat(label: "Notes", value: "\(vault.noteCount)")
                    usageStat(label: "Chunks", value: "\(vault.chunkCount)")

                    if vault.chunkCount > 0 {
                        let avgChunks = Double(vault.chunkCount) / Double(max(vault.noteCount, 1))
                        usageStat(label: "Avg/Note", value: String(format: "%.1f", avgChunks))
                    }
                }
            }
        }
    }

    private func usageStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                    Text("Danger Zone")
                        .font(.headline)
                }

                Text("Permanently delete this vault and all indexed data. This action cannot be undone.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button(role: .destructive, action: onDelete) {
                    Label("Delete Vault", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MacVaultDetailView(
            vault: ObsidianVault.samples[0],
            hasChanges: true,
            changedPathsCount: 12,
            onFullReindex: { print("Full reindex") },
            onDeltaUpdate: { print("Delta update") },
            onDelete: { print("Delete") }
        )
    }
    .frame(width: 600, height: 800)
}
