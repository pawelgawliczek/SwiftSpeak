//
//  PowerModeVaultSection.swift
//  SwiftSpeak
//
//  UI component for selecting Obsidian vaults and query settings in Power Mode editor
//  Phase 3: Obsidian Vault Integration
//

import SwiftUI
import SwiftSpeakCore

struct PowerModeVaultSection: View {
    @Binding var selectedVaultIds: [UUID]
    @Binding var maxChunks: Int
    @Binding var includeWindowContext: Bool  // Only shown on macOS

    @EnvironmentObject private var settings: SharedSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("OBSIDIAN VAULTS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            // Vault selection
            if settings.obsidianVaults.isEmpty {
                emptyStateView
            } else {
                vaultList
                querySettings
            }

            // Info text
            let selectedCount = selectedVaultIds.count
            if selectedCount > 0 {
                Text("\(selectedCount) vault\(selectedCount == 1 ? "" : "s") selected for queries")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text("Select vaults to query when using this Power Mode")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("No Vaults Configured")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text("Configure Obsidian vaults in Settings first")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
    }

    // MARK: - Vault List

    private var vaultList: some View {
        VStack(spacing: 8) {
            ForEach(settings.obsidianVaults) { vault in
                vaultRow(vault)
            }
        }
    }

    private func vaultRow(_ vault: ObsidianVault) -> some View {
        let isSelected = selectedVaultIds.contains(vault.id)

        return Button(action: {
            HapticManager.selection()
            if isSelected {
                selectedVaultIds.removeAll { $0 == vault.id }
            } else {
                selectedVaultIds.append(vault.id)
            }
        }) {
            HStack(spacing: 12) {
                // Status icon
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(vaultStatusColor(vault.status).opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: vault.status.icon)
                        .font(.caption)
                        .foregroundStyle(vaultStatusColor(vault.status))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(vault.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        Text("\(vault.noteCount) notes")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        if vault.chunkCount > 0 {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text("\(vault.chunkCount) chunks")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .purple : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.purple.opacity(0.1) : Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Query Settings

    private var querySettings: some View {
        VStack(spacing: 8) {
            // Max chunks stepper
            HStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(.purple)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Max Results")
                        .font(.subheadline.weight(.medium))

                    Text("Number of note chunks to include in context")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 12) {
                    Button(action: {
                        HapticManager.selection()
                        if maxChunks > 1 {
                            maxChunks -= 1
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(maxChunks > 1 ? .purple : .secondary)
                    }
                    .disabled(maxChunks <= 1)

                    Text("\(maxChunks)")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .frame(minWidth: 20)

                    Button(action: {
                        HapticManager.selection()
                        if maxChunks < 10 {
                            maxChunks += 1
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(maxChunks < 10 ? .purple : .secondary)
                    }
                    .disabled(maxChunks >= 10)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            // Window context toggle (macOS only)
            #if os(macOS)
            HStack(spacing: 12) {
                Image(systemName: "macwindow.badge.plus")
                    .font(.title3)
                    .foregroundStyle(includeWindowContext ? .purple : .secondary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Include Window Context")
                        .font(.subheadline.weight(.medium))

                    Text("Capture text from active window for better context")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $includeWindowContext)
                    .labelsHidden()
                    .tint(.purple)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            #endif
        }
    }

    // MARK: - Helpers

    private func vaultStatusColor(_ status: ObsidianVaultStatus) -> Color {
        switch status.color {
        case "gray": return .gray
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    PowerModeVaultSection(
        selectedVaultIds: .constant([]),
        maxChunks: .constant(3),
        includeWindowContext: .constant(false)
    )
    .environmentObject(SharedSettings.shared)
    .preferredColorScheme(.dark)
    .padding()
    .background(AppTheme.darkBase)
}
