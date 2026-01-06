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

                    // Feature badges - show what inputs/outputs are enabled
                    HStack(spacing: 6) {
                        // Memory (Power Mode or Global)
                        if powerMode.inputConfig.includePowerModeMemory || powerMode.inputConfig.includeGlobalMemory {
                            Image(systemName: "brain")
                                .font(.caption)
                                .foregroundStyle(.purple)
                        }
                        // RAG Documents (enabled AND has documents)
                        if powerMode.inputConfig.includeRAGDocuments && !powerMode.knowledgeDocumentIds.isEmpty {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        // Obsidian Vaults (enabled AND has vaults selected)
                        if powerMode.inputConfig.includeObsidianVaults && !powerMode.obsidianVaultIds.isEmpty {
                            Image(systemName: "folder.fill")
                                .font(.caption)
                                .foregroundStyle(.purple)
                        }
                        // Selected Text (macOS only, requires accessibility)
                        if powerMode.inputConfig.includeSelectedText {
                            Image(systemName: "text.cursor")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        // Clipboard
                        if powerMode.inputConfig.includeClipboard {
                            Image(systemName: "doc.on.clipboard")
                                .font(.caption)
                                .foregroundStyle(.indigo)
                        }
                        // Webhooks (enabled AND has webhooks selected)
                        if powerMode.outputConfig.webhookEnabled && !powerMode.outputConfig.webhookIds.isEmpty {
                            Image(systemName: "link")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        // Obsidian Output Action
                        if powerMode.outputConfig.obsidianAction != nil {
                            Image(systemName: "square.and.arrow.down.on.square")
                                .font(.caption)
                                .foregroundStyle(.purple)
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

                // INPUT CONTEXT Section
                Section {
                    // Global Memory
                    Toggle(isOn: $powerMode.inputConfig.includeGlobalMemory) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading) {
                                Text("Global Memory")
                                Text("Include your global AI memory across all modes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Power Mode Memory
                    Toggle(isOn: $powerMode.inputConfig.includePowerModeMemory) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundStyle(.purple)
                            VStack(alignment: .leading) {
                                Text("Power Mode Memory")
                                Text("Include memory specific to this mode")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if powerMode.inputConfig.includePowerModeMemory {
                        Stepper("Memory Limit: \(powerMode.memoryLimit) characters",
                                value: $powerMode.memoryLimit,
                                in: 500...2000,
                                step: 100)
                    }

                    // RAG Documents
                    Toggle(isOn: $powerMode.inputConfig.includeRAGDocuments) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading) {
                                Text("RAG Documents")
                                let count = powerMode.knowledgeDocumentIds.count
                                Text(count == 0 ? "No documents attached" : "\(count) document\(count == 1 ? "" : "s") attached")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Obsidian Vaults
                    Toggle(isOn: $powerMode.inputConfig.includeObsidianVaults) {
                        HStack {
                            Image("ObsidianIcon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                            VStack(alignment: .leading) {
                                Text("Obsidian Vaults")
                                // Count only vault IDs that actually exist in vaultManager
                                let validVaultIds = powerMode.obsidianVaultIds.filter { vaultId in
                                    vaultManager.vaults.contains { $0.id == vaultId }
                                }
                                let count = validVaultIds.count
                                Text(count == 0 ? "No vaults selected" : "\(count) vault\(count == 1 ? "" : "s") selected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onChange(of: powerMode.inputConfig.includeObsidianVaults) { isEnabled in
                        // Clean up stale vault IDs when toggling
                        if isEnabled {
                            let validVaultIds = vaultManager.vaults.map { $0.id }
                            powerMode.obsidianVaultIds = powerMode.obsidianVaultIds.filter { validVaultIds.contains($0) }
                        }
                    }

                    if powerMode.inputConfig.includeObsidianVaults {
                        if vaultManager.vaults.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No Obsidian vaults configured")
                                    .foregroundStyle(.secondary)
                                Button("Configure Vaults...") {
                                    showingVaultsSettings = true
                                }
                                .buttonStyle(.bordered)
                            }
                        } else {
                            ForEach(vaultManager.vaults) { vault in
                                Toggle(isOn: Binding(
                                    get: { powerMode.obsidianVaultIds.contains(vault.id) },
                                    set: { isSelected in
                                        if isSelected {
                                            if !powerMode.obsidianVaultIds.contains(vault.id) {
                                                powerMode.obsidianVaultIds.append(vault.id)
                                            }
                                        } else {
                                            powerMode.obsidianVaultIds.removeAll { $0 == vault.id }
                                        }
                                    }
                                )) {
                                    HStack {
                                        Image(systemName: "folder")
                                            .foregroundStyle(.secondary)
                                        Text(vault.name)
                                        Spacer()
                                        Text("\(vault.noteCount) notes")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.leading, 20)
                            }

                            // Default search query field - show when at least one valid vault is selected
                            let hasValidVaults = powerMode.obsidianVaultIds.contains { vaultId in
                                vaultManager.vaults.contains { $0.id == vaultId }
                            }
                            if hasValidVaults {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Default Search Query")
                                        .font(.subheadline.weight(.medium))

                                    TextField("Leave empty to show all notes", text: $powerMode.defaultObsidianSearchQuery)
                                        .textFieldStyle(.roundedBorder)

                                    Text("Pre-fills the search field when using this Power Mode")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.leading, 20)
                                .padding(.top, 8)

                                // Similarity Thresholds
                                VStack(alignment: .leading, spacing: 12) {
                                    // Min Similarity (for showing results)
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Minimum Similarity")
                                                .font(.subheadline.weight(.medium))
                                            Spacer()
                                            Text("\(Int(powerMode.obsidianMinSimilarity * 100))%")
                                                .font(.subheadline.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                        Slider(value: $powerMode.obsidianMinSimilarity, in: 0.1...0.9, step: 0.05)
                                        Text("Notes below this similarity won't appear in search results")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    // Auto-Select Threshold
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Auto-Select Threshold")
                                                .font(.subheadline.weight(.medium))
                                            Spacer()
                                            Text("\(Int(powerMode.obsidianAutoSelectThreshold * 100))%")
                                                .font(.subheadline.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                        Slider(value: $powerMode.obsidianAutoSelectThreshold, in: 0.1...0.95, step: 0.05)
                                        Text("Notes above this similarity are automatically selected")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.leading, 20)
                                .padding(.top, 8)
                            }
                        }
                    }

                    Divider()

                    // macOS-specific: Selected Text (requires accessibility/non-sandboxed)
                    if SandboxDetector.isSandboxed {
                        disabledAccessibilityRow(
                            icon: "text.cursor",
                            iconColor: .orange,
                            title: "Selected Text",
                            subtitle: "Include currently selected text from active app"
                        )
                    } else {
                        Toggle(isOn: $powerMode.inputConfig.includeSelectedText) {
                            HStack {
                                Image(systemName: "text.cursor")
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading) {
                                    Text("Selected Text")
                                    Text("Include currently selected text from active app")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    // macOS-specific: Clipboard
                    Toggle(isOn: $powerMode.inputConfig.includeClipboard) {
                        HStack {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundStyle(.indigo)
                            VStack(alignment: .leading) {
                                Text("Clipboard")
                                Text("Include current clipboard contents")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Input Context")
                } footer: {
                    Text("Choose what information to include when running this Power Mode")
                }

                // OUTPUT DELIVERY Section
                Section {
                    // Output Format (describes how AI should format response)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "text.alignleft")
                                .foregroundStyle(.teal)
                            Text("Output Format")
                        }
                        Text("Describe how the AI should format its response")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $powerMode.outputFormat)
                            .frame(minHeight: 60)
                            .font(.body)
                    }

                    // Primary Output Action
                    Picker("Primary Action", selection: $powerMode.outputConfig.primaryAction) {
                        ForEach(PowerModeOutputAction.allCases, id: \.self) { action in
                            HStack {
                                Image(systemName: action.icon)
                                Text(action.displayName)
                            }
                            .tag(action)
                        }
                    }

                    Text(powerMode.outputConfig.primaryAction.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Auto-send toggle
                    Toggle(isOn: $powerMode.outputConfig.autoSendAfterInsert) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading) {
                                Text("Auto-Send Message")
                                Text("Press Enter/Return after inserting text")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Webhooks
                    Toggle(isOn: $powerMode.outputConfig.webhookEnabled) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading) {
                                Text("Webhooks")
                                let count = powerMode.outputConfig.webhookIds.count
                                Text(count == 0 ? "Send output to external services" : "\(count) webhook\(count == 1 ? "" : "s") enabled")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Note: Webhooks are configured via iOS app and synced via iCloud
                    // macOS displays the configuration but webhook list comes from shared settings
                    if powerMode.outputConfig.webhookEnabled {
                        Text("Webhooks configured in iOS app")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 20)
                    }

                    // Obsidian Action
                    Toggle(isOn: Binding(
                        get: { powerMode.outputConfig.obsidianAction != nil },
                        set: { enabled in
                            if enabled {
                                if let firstVault = vaultManager.vaults.first {
                                    powerMode.outputConfig.obsidianAction = ObsidianActionConfig(
                                        action: .appendToDaily,
                                        targetVaultId: firstVault.id
                                    )
                                }
                            } else {
                                powerMode.outputConfig.obsidianAction = nil
                            }
                        }
                    )) {
                        HStack {
                            Image("ObsidianIcon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                            VStack(alignment: .leading) {
                                Text("Save to Obsidian")
                                Text(powerMode.outputConfig.obsidianAction != nil
                                     ? powerMode.outputConfig.obsidianAction!.action.displayName
                                     : "No action configured")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if powerMode.outputConfig.obsidianAction != nil {
                        // Action type picker
                        Picker("Action", selection: Binding(
                            get: { powerMode.outputConfig.obsidianAction?.action ?? .appendToDaily },
                            set: { powerMode.outputConfig.obsidianAction?.action = $0 }
                        )) {
                            ForEach(ObsidianAction.allCases.filter { $0 != .none }, id: \.self) { action in
                                HStack {
                                    Image(systemName: action.icon)
                                    Text(action.displayName)
                                }
                                .tag(action)
                            }
                        }
                        .padding(.leading, 20)

                        // Vault picker
                        if !vaultManager.vaults.isEmpty {
                            Picker("Target Vault", selection: Binding(
                                get: { powerMode.outputConfig.obsidianAction?.targetVaultId ?? UUID() },
                                set: { powerMode.outputConfig.obsidianAction?.targetVaultId = $0 }
                            )) {
                                ForEach(vaultManager.vaults) { vault in
                                    Text(vault.name).tag(vault.id)
                                }
                            }
                            .padding(.leading, 20)
                        }

                        // Note name (for specific actions)
                        if let action = powerMode.outputConfig.obsidianAction?.action,
                           action == .appendToNote || action == .createNote {
                            TextField(
                                action == .createNote ? "Note Name" : "Target Note",
                                text: Binding(
                                    get: { powerMode.outputConfig.obsidianAction?.targetNoteName ?? "" },
                                    set: { powerMode.outputConfig.obsidianAction?.targetNoteName = $0.isEmpty ? nil : $0 }
                                )
                            )
                            .padding(.leading, 20)
                        }

                        // Auto-execute toggle
                        Toggle(isOn: Binding(
                            get: { powerMode.outputConfig.obsidianAction?.autoExecute ?? false },
                            set: { powerMode.outputConfig.obsidianAction?.autoExecute = $0 }
                        )) {
                            HStack {
                                Image(systemName: "bolt.fill")
                                    .foregroundStyle(.purple)
                                VStack(alignment: .leading) {
                                    Text("Auto-Execute")
                                    Text("Save to Obsidian automatically when Power Mode completes")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.leading, 20)
                    }
                } header: {
                    Text("Output Delivery")
                } footer: {
                    Text("Choose how to deliver the Power Mode result")
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 550, height: 800)
        .sheet(isPresented: $showingVaultsSettings) {
            MacVaultsSettingsView(settings: settings)
                .frame(width: 600, height: 500)
        }
    }

    /// Row for accessibility features that are disabled in App Store (sandboxed) version
    private func disabledAccessibilityRow(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(iconColor.opacity(0.4))
            VStack(alignment: .leading) {
                HStack {
                    Text(title)
                        .foregroundStyle(.secondary)
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text("Available in Direct Download version")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .opacity(0.6)
    }

    private func savePowerMode() {
        // Sync legacy fields with new config
        var updatedMode = powerMode
        updatedMode.memoryEnabled = powerMode.inputConfig.includePowerModeMemory
        updatedMode.enterSendsMessage = powerMode.outputConfig.autoSendAfterInsert
        updatedMode.enabledWebhookIds = powerMode.outputConfig.webhookEnabled ? powerMode.outputConfig.webhookIds : []
        updatedMode.obsidianAction = powerMode.outputConfig.obsidianAction
        updatedMode.includeWindowContext = powerMode.inputConfig.includeActiveAppText
        updatedMode.updatedAt = Date()

        onSave(updatedMode)
    }
}

// MARK: - Preview

#Preview {
    MacPowerModesView(settings: MacSettings.shared)
        .frame(width: 600, height: 700)
}
