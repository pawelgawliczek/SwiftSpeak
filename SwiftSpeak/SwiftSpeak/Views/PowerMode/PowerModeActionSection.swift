//
//  PowerModeActionSection.swift
//  SwiftSpeak
//
//  UI component for configuring Obsidian output actions in Power Mode editor
//  Phase 3: Obsidian Vault Integration
//

import SwiftUI
import SwiftSpeakCore

struct PowerModeActionSection: View {
    @Binding var action: ObsidianActionConfig?
    let availableVaults: [ObsidianVault]

    @State private var selectedAction: ObsidianAction = .none
    @State private var selectedVaultId: UUID?
    @State private var targetNoteName: String = ""
    @State private var autoExecute: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("OBSIDIAN OUTPUT ACTION")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            // Action picker
            actionPicker

            // Configuration based on selected action
            if selectedAction != .none {
                actionConfiguration
            }

            // Info text
            Text(selectedAction.description)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .onAppear {
            loadFromConfig()
        }
        .onChange(of: selectedAction) { updateConfig() }
        .onChange(of: selectedVaultId) { updateConfig() }
        .onChange(of: targetNoteName) { updateConfig() }
        .onChange(of: autoExecute) { updateConfig() }
    }

    // MARK: - Action Picker

    private var actionPicker: some View {
        VStack(spacing: 8) {
            ForEach(ObsidianAction.allCases, id: \.self) { actionType in
                actionRow(actionType)
            }
        }
    }

    private func actionRow(_ actionType: ObsidianAction) -> some View {
        let isSelected = selectedAction == actionType

        return Button(action: {
            HapticManager.selection()
            selectedAction = actionType
        }) {
            HStack(spacing: 12) {
                Image(systemName: actionType.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .purple : .secondary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(actionType.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(actionType.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .purple : Color.secondary.opacity(0.3))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(isSelected ? Color.purple.opacity(0.1) : Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Action Configuration

    @ViewBuilder
    private var actionConfiguration: some View {
        VStack(spacing: 12) {
            // Vault picker (required for all actions except .none)
            vaultPicker

            // Note name field (for appendToNote)
            if selectedAction == .appendToNote || selectedAction == .createNote {
                noteNameField
            }

            // Auto-execute toggle
            autoExecuteToggle
        }
    }

    private var vaultPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Target Vault")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            if availableVaults.isEmpty {
                Text("No vaults configured")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            } else {
                Menu {
                    ForEach(availableVaults) { vault in
                        Button(action: {
                            HapticManager.selection()
                            selectedVaultId = vault.id
                        }) {
                            HStack {
                                Text(vault.name)
                                if selectedVaultId == vault.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        if let vaultId = selectedVaultId,
                           let vault = availableVaults.first(where: { $0.id == vaultId }) {
                            Text(vault.name)
                                .foregroundStyle(.primary)
                        } else {
                            Text("Select vault...")
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var noteNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedAction == .createNote ? "Note Name" : "Note Path")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            TextField(
                selectedAction == .createNote ? "My Note" : "Folder/Note Name",
                text: $targetNoteName
            )
            .textFieldStyle(.plain)
            .padding(12)
            .background(Color.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            Text(selectedAction == .createNote
                 ? "Name for the new note"
                 : "Path to existing note (e.g., 'Work/Meeting Notes')")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var autoExecuteToggle: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.title3)
                .foregroundStyle(autoExecute ? .purple : .secondary)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("Auto-Execute")
                    .font(.subheadline.weight(.medium))

                Text("Automatically write to vault after generation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $autoExecute)
                .labelsHidden()
                .tint(.purple)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
    }

    // MARK: - State Management

    private func loadFromConfig() {
        if let config = action {
            selectedAction = config.action
            selectedVaultId = config.targetVaultId
            targetNoteName = config.targetNoteName ?? ""
            autoExecute = config.autoExecute
        } else {
            selectedAction = .none
            selectedVaultId = availableVaults.first?.id
            targetNoteName = ""
            autoExecute = false
        }
    }

    private func updateConfig() {
        if selectedAction == .none {
            action = nil
        } else if let vaultId = selectedVaultId {
            action = ObsidianActionConfig(
                action: selectedAction,
                targetVaultId: vaultId,
                targetNoteName: targetNoteName.isEmpty ? nil : targetNoteName,
                autoExecute: autoExecute
            )
        }
    }
}

// MARK: - Preview

#Preview {
    PowerModeActionSection(
        action: .constant(nil),
        availableVaults: ObsidianVault.samples
    )
    .preferredColorScheme(.dark)
    .padding()
    .background(AppTheme.darkBase)
}
