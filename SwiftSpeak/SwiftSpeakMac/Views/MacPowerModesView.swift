//
//  MacPowerModesView.swift
//  SwiftSpeakMac
//
//  macOS version of Power Modes list and editor
//  Power Modes are AI-powered workflows for complex tasks
//

import SwiftUI
import SwiftSpeakCore

// MARK: - Power Modes View

struct MacPowerModesView: View {
    @ObservedObject var settings: MacSettings
    @ObservedObject var hotkeyManager: MacHotkeyManager = MacHotkeyManager.shared
    @State private var showingNewEditor = false
    @State private var editingPowerMode: PowerMode?
    @State private var expandedPowerModeId: UUID?
    @State private var showingDeleteConfirmation = false
    @State private var powerModeToDelete: PowerMode?
    @State private var showArchived = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Power Modes")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("AI-powered workflows for complex tasks")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: { showingNewEditor = true }) {
                        Label("New Power Mode", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.bottom, 8)

                // Global Power Mode Hotkey Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Global Shortcut")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    GlobalHotkeyEditor(
                        title: "Open Power Mode",
                        description: "Opens the Power Mode overlay from anywhere. Use arrow keys to cycle between modes.",
                        action: .openPowerModeOverlay,
                        hotkey: Binding(
                            get: { settings.globalPowerModeHotkey },
                            set: { settings.globalPowerModeHotkey = $0 }
                        ),
                        hotkeyManager: hotkeyManager
                    )
                    .padding(16)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Divider()
                    .padding(.vertical, 4)

                // Active Power Modes
                VStack(alignment: .leading, spacing: 12) {
                    Text("Active")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    if settings.activePowerModes.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "bolt.circle")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.tertiary)
                                Text("No power modes yet")
                                    .foregroundStyle(.secondary)
                                Button("Create Power Mode") {
                                    showingNewEditor = true
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 24)
                            Spacer()
                        }
                        .background(Color.primary.opacity(0.02))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        ForEach(settings.activePowerModes) { powerMode in
                            PowerModeCard(
                                powerMode: powerMode,
                                isExpanded: expandedPowerModeId == powerMode.id,
                                settings: settings,
                                onTap: { toggleExpanded(powerMode.id) },
                                onEdit: { editingPowerMode = powerMode },
                                onDelete: {
                                    powerModeToDelete = powerMode
                                    showingDeleteConfirmation = true
                                },
                                onArchive: {
                                    var updated = powerMode
                                    updated.isArchived = true
                                    settings.updatePowerMode(updated)
                                }
                            )
                        }
                    }
                }

                // Archived Power Modes
                if !settings.archivedPowerModes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Button(action: { withAnimation { showArchived.toggle() } }) {
                            HStack {
                                Text("Archived")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Image(systemName: showArchived ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Text("(\(settings.archivedPowerModes.count))")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)

                        if showArchived {
                            ForEach(settings.archivedPowerModes) { powerMode in
                                PowerModeCard(
                                    powerMode: powerMode,
                                    isExpanded: expandedPowerModeId == powerMode.id,
                                    settings: settings,
                                    onTap: { toggleExpanded(powerMode.id) },
                                    onEdit: { editingPowerMode = powerMode },
                                    onDelete: {
                                        powerModeToDelete = powerMode
                                        showingDeleteConfirmation = true
                                    },
                                    onArchive: {
                                        var updated = powerMode
                                        updated.isArchived = false
                                        settings.updatePowerMode(updated)
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showingNewEditor) {
            MacPowerModeEditorSheet(
                powerMode: PowerMode(name: "", instruction: ""),
                isNew: true,
                settings: settings,
                onSave: { savedPowerMode in
                    settings.addPowerMode(savedPowerMode)
                    expandedPowerModeId = savedPowerMode.id
                    showingNewEditor = false
                },
                onCancel: { showingNewEditor = false }
            )
        }
        .sheet(item: $editingPowerMode) { powerMode in
            MacPowerModeEditorSheet(
                powerMode: powerMode,
                isNew: false,
                settings: settings,
                onSave: { savedPowerMode in
                    settings.updatePowerMode(savedPowerMode)
                    editingPowerMode = nil
                },
                onCancel: { editingPowerMode = nil }
            )
        }
        .alert("Delete Power Mode?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                powerModeToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let powerMode = powerModeToDelete {
                    settings.deletePowerMode(id: powerMode.id)
                    if expandedPowerModeId == powerMode.id {
                        expandedPowerModeId = nil
                    }
                }
                powerModeToDelete = nil
            }
        } message: {
            if let powerMode = powerModeToDelete {
                Text("Are you sure you want to delete \"\(powerMode.name)\"? This action cannot be undone.")
            }
        }
    }

    private func toggleExpanded(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedPowerModeId == id {
                expandedPowerModeId = nil
            } else {
                expandedPowerModeId = id
            }
        }
    }
}

// MARK: - Power Mode Card

private struct PowerModeCard: View {
    let powerMode: PowerMode
    let isExpanded: Bool
    @ObservedObject var settings: MacSettings
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onArchive: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row (always visible)
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(powerMode.iconColor.color.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Image(systemName: powerMode.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(powerMode.iconColor.color)
                    }

                    // Name and stats
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(powerMode.name)
                                .font(.headline)

                            if powerMode.isArchived {
                                Text("Archived")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }

                        HStack(spacing: 8) {
                            if powerMode.usageCount > 0 {
                                Text("\(powerMode.usageCount) uses")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Created \(powerMode.createdAt, style: .date)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    // Feature badges - show enabled input/output actions
                    HStack(spacing: 6) {
                        // Show badges for enabled input actions
                        ForEach(powerMode.migratedInputActions.filter { $0.isEnabled }.prefix(4)) { action in
                            Image(systemName: action.type.icon)
                                .font(.caption)
                                .foregroundStyle(action.type.color)
                        }
                        // Show badges for enabled output actions
                        ForEach(powerMode.migratedOutputActions.filter { $0.isEnabled }.prefix(3)) { action in
                            Image(systemName: action.type.icon)
                                .font(.caption)
                                .foregroundStyle(action.type.color)
                        }
                    }

                    // Expand indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 16) {
                    // Instruction
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Instruction")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(powerMode.instruction.isEmpty ? "No instruction set" : powerMode.instruction)
                            .font(.callout)
                            .foregroundStyle(powerMode.instruction.isEmpty ? .tertiary : .primary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    // Output format
                    if !powerMode.outputFormat.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Output Format")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(powerMode.outputFormat)
                                .font(.callout)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.03))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }

                    // Settings Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        settingBadge(
                            title: "Memory",
                            value: powerMode.memoryEnabled ? "On" : "Off",
                            icon: "brain",
                            color: .purple
                        )

                        settingBadge(
                            title: "Documents",
                            value: powerMode.knowledgeDocumentIds.isEmpty ? "None" : "\(powerMode.knowledgeDocumentIds.count)",
                            icon: "doc.text",
                            color: .blue
                        )

                        settingBadge(
                            title: "Webhooks",
                            value: powerMode.enabledWebhookIds.isEmpty ? "None" : "\(powerMode.enabledWebhookIds.count)",
                            icon: "link",
                            color: .orange
                        )
                    }

                    // RAG Configuration
                    VStack(alignment: .leading, spacing: 6) {
                        Text("RAG Settings")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "text.magnifyingglass")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                Text(powerMode.ragConfiguration.chunkingStrategy.displayName)
                                    .font(.caption)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "number")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                Text("\(powerMode.ragConfiguration.maxContextChunks) chunks")
                                    .font(.caption)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "percent")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                Text("\(Int(powerMode.ragConfiguration.similarityThreshold * 100))% threshold")
                                    .font(.caption)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }

                    // Memory content
                    if powerMode.memoryEnabled {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Power Mode Memory")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let lastUpdate = powerMode.lastMemoryUpdate {
                                    Spacer()
                                    Text("Updated \(lastUpdate, style: .relative)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            Text(powerMode.memory ?? "No memory stored yet")
                                .font(.callout)
                                .foregroundStyle(powerMode.memory == nil ? .tertiary : .primary)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.purple.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                            if powerMode.memory != nil {
                                Button(action: {
                                    settings.clearPowerModeMemory(id: powerMode.id)
                                }) {
                                    Label("Clear Memory", systemImage: "trash")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.red)
                            }
                        }
                    }

                    // Action buttons
                    HStack(spacing: 12) {
                        Button(action: onArchive) {
                            Label(powerMode.isArchived ? "Unarchive" : "Archive",
                                  systemImage: powerMode.isArchived ? "tray.and.arrow.up" : "archivebox")
                        }
                        .buttonStyle(.bordered)

                        Button("Edit", action: onEdit)
                            .buttonStyle(.bordered)

                        Spacer()

                        Button(role: .destructive, action: onDelete) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                    }
                }
                .padding(12)
            }
        }
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(powerMode.isArchived ? 0.7 : 1.0)
    }

    private func settingBadge(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.callout)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Power Mode Editor Sheet

struct MacPowerModeEditorSheet: View {
    @State var powerMode: PowerMode
    let isNew: Bool
    @ObservedObject var settings: MacSettings
    let onSave: (PowerMode) -> Void
    let onCancel: () -> Void

    @StateObject private var vaultManager = ObsidianVaultManager.shared
    @State private var showingVaultsSettings = false

    // Phase 17: Input/Output Actions (unified system)
    @State private var inputActions: [InputAction] = []
    @State private var outputActions: [OutputAction] = []

    private let iconOptions = ["bolt.fill", "magnifyingglass.circle.fill", "envelope.fill", "calendar", "brain.head.profile", "text.bubble.fill", "doc.text.fill", "chart.bar.fill", "star.fill", "lightbulb.fill"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
                Spacer()
                Text(isNew ? "New Power Mode" : "Edit Power Mode")
                    .font(.headline)
                Spacer()
                Button("Save") {
                    savePowerMode()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(powerMode.name.isEmpty)
            }
            .padding()

            Divider()

            // Form
            Form {
                // Basic Info
                Section("Identity") {
                    TextField("Name", text: $powerMode.name)

                    Text("The name defines the AI's role (e.g., \"Email Writer\" → AI becomes an Email Writer assistant)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Icon", selection: $powerMode.icon) {
                        ForEach(iconOptions, id: \.self) { icon in
                            HStack {
                                Image(systemName: icon)
                                Text(icon)
                            }
                            .tag(icon)
                        }
                    }

                    Picker("Color", selection: $powerMode.iconColor) {
                        ForEach(PowerModeColorPreset.allCases) { color in
                            HStack {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 12, height: 12)
                                Text(color.displayName)
                            }
                            .tag(color)
                        }
                    }
                }

                // Instruction
                Section("Instruction") {
                    Text("Tell the AI what this power mode should do")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $powerMode.instruction)
                        .frame(minHeight: 100)
                        .font(.body)
                }

                // MARK: - Context Sources (Phase 17 unified)
                Section {
                    MacInputActionsEditor(actions: $inputActions, settings: settings)
                } header: {
                    Text("Context Sources")
                } footer: {
                    Text("Choose what information to include when running this Power Mode")
                }

                // MARK: - Delivery Actions (Phase 17 unified)
                Section {
                    MacOutputActionsEditor(actions: $outputActions, settings: settings)
                } header: {
                    Text("Delivery Actions")
                } footer: {
                    Text("Choose how to deliver the Power Mode result")
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 550, height: 900)
        .onAppear {
            // Initialize actions - use migration if legacy config exists
            inputActions = powerMode.migratedInputActions
            outputActions = powerMode.migratedOutputActions
        }
        .sheet(isPresented: $showingVaultsSettings) {
            MacVaultsSettingsView(settings: settings)
                .frame(width: 600, height: 500)
        }
    }

    private func savePowerMode() {
        var updatedMode = powerMode
        updatedMode.updatedAt = Date()

        // Phase 17: Use unified input/output actions
        updatedMode.inputActions = inputActions
        updatedMode.outputActions = outputActions

        onSave(updatedMode)
    }
}

// MARK: - Preview

#Preview {
    MacPowerModesView(settings: MacSettings.shared)
        .frame(width: 600, height: 700)
}
