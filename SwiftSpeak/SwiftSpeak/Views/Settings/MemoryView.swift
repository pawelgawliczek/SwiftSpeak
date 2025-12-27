//
//  MemoryView.swift
//  SwiftSpeak
//
//  Phase 4: Unified view for the three-tier memory system with filtering
//  - History Memory (global)
//  - Workflow Memory (per Power Mode)
//  - Context Memory (per Conversation Context)
//  Redesigned: Segmented filter control + sub-pickers + link to filtered history
//

import SwiftUI

struct MemoryView: View {
    @EnvironmentObject var settings: SharedSettings

    enum FilterMode: String, CaseIterable {
        case all = "All"
        case global = "Global"
        case byContext = "Context"
        case byPowerMode = "Power Mode"
    }

    @State private var filterMode: FilterMode = .all
    @State private var selectedContextId: UUID?
    @State private var selectedPowerModeId: UUID?

    @State private var showingEditor = false
    @State private var editingMemoryType: MemoryType?
    @State private var editingMemoryContent: String = ""
    @State private var editingTitle: String = ""
    @State private var showingClearConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Filter control
                filterSection

                // Content based on filter
                switch filterMode {
                case .all:
                    allMemoriesContent
                case .global:
                    globalMemoryContent
                case .byContext:
                    contextMemoryContent
                case .byPowerMode:
                    powerModeMemoryContent
                }

                // Link to filtered history
                filteredHistoryLink

                // Clear section (only in All mode)
                if filterMode == .all {
                    clearAllSection
                }

                Spacer(minLength: 80)
            }
            .padding(16)
        }
        .background(AppTheme.darkBase.ignoresSafeArea())
        .navigationTitle("Memory")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingEditor) {
            MemoryEditorSheet(
                title: editingTitle,
                content: $editingMemoryContent,
                lastUpdated: Date(),
                onSave: { saveMemory() },
                onClear: { clearMemory() }
            )
        }
        .confirmationDialog("Clear All Memory", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
            Button("Clear All", role: .destructive) {
                clearAllMemory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all stored memories including history, workflow, and context memories. This action cannot be undone.")
        }
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        VStack(spacing: 12) {
            // Main segmented control
            Picker("Filter", selection: $filterMode) {
                ForEach(FilterMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // Sub-picker for Context
            if filterMode == .byContext {
                contextPicker
            }

            // Sub-picker for Power Mode
            if filterMode == .byPowerMode {
                powerModePicker
            }
        }
    }

    // MARK: - Context Picker

    private var contextPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(settings.contexts) { context in
                    Button(action: {
                        HapticManager.selection()
                        selectedContextId = context.id
                    }) {
                        HStack(spacing: 6) {
                            Text(context.icon)
                                .font(.callout)
                            Text(context.name)
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(selectedContextId == context.id ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedContextId == context.id ? context.color.color : Color.primary.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Power Mode Picker

    private var powerModePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(settings.powerModes.filter { $0.memoryEnabled }) { mode in
                    Button(action: {
                        HapticManager.selection()
                        selectedPowerModeId = mode.id
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: mode.icon)
                                .font(.caption)
                            Text(mode.name)
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(selectedPowerModeId == mode.id ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedPowerModeId == mode.id ? mode.iconColor.color : Color.primary.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - All Memories Content

    private var allMemoriesContent: some View {
        VStack(spacing: 24) {
            // Global History Memory
            historyMemorySection

            // Workflow Memories
            workflowMemoriesSection

            // Context Memories
            contextMemoriesSection
        }
    }

    // MARK: - Global Memory Content

    private var globalMemoryContent: some View {
        historyMemorySection
    }

    // MARK: - Context Memory Content

    private var contextMemoryContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let contextId = selectedContextId,
               let context = settings.contexts.first(where: { $0.id == contextId }) {

                Text("\(context.icon) \(context.name)")
                    .font(.headline)

                if context.memoryEnabled, let memory = context.memory, !memory.isEmpty {
                    MemoryRowView(
                        icon: context.icon,
                        iconColor: context.color.color,
                        title: "Context Memory",
                        preview: memory,
                        lastUpdated: context.lastMemoryUpdate,
                        onEdit: { editContextMemory(context) }
                    )
                } else if !context.memoryEnabled {
                    emptyMemoryCard(message: "Memory is not enabled for this context")
                } else {
                    emptyMemoryCard(message: "No memory stored for this context yet")
                }
            } else if settings.contexts.isEmpty {
                emptyMemoryCard(message: "No contexts created yet")
            } else {
                Text("Select a context above to view its memory")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            }
        }
    }

    // MARK: - Power Mode Memory Content

    private var powerModeMemoryContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            let memoryEnabledModes = settings.powerModes.filter { $0.memoryEnabled }

            if let modeId = selectedPowerModeId,
               let mode = memoryEnabledModes.first(where: { $0.id == modeId }) {

                HStack(spacing: 8) {
                    Image(systemName: mode.icon)
                        .foregroundStyle(mode.iconColor.color)
                    Text(mode.name)
                        .font(.headline)
                }

                if let memory = mode.memory, !memory.isEmpty {
                    MemoryRowView(
                        icon: mode.icon,
                        iconColor: mode.iconColor.color,
                        title: "Workflow Memory",
                        preview: memory,
                        lastUpdated: mode.lastMemoryUpdate,
                        onEdit: { editWorkflowMemory(mode) }
                    )
                } else {
                    emptyMemoryCard(message: "No memory stored for this Power Mode yet")
                }
            } else if memoryEnabledModes.isEmpty {
                emptyMemoryCard(message: "No Power Modes have memory enabled")
            } else {
                Text("Select a Power Mode above to view its memory")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            }
        }
    }

    // MARK: - History Memory Section

    private var historyMemorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HISTORY MEMORY (GLOBAL)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "brain")
                        .font(.caption)
                        .foregroundStyle(AppTheme.accent)

                    Text("Updated after every conversation")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("Always active")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.accent)
                }

                if let memory = settings.historyMemory, !memory.summary.isEmpty {
                    Text(memory.summary)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(4)

                    HStack {
                        Text("Last updated: \(timeAgo(memory.lastUpdated))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Spacer()

                        Button("Edit") {
                            editHistoryMemory()
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.accent)
                    }
                } else {
                    Text("No history recorded yet")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
            .padding(16)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
    }

    // MARK: - Workflow Memories Section

    private var workflowMemoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WORKFLOW MEMORIES")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Per Power Mode (only shows modes with memory enabled)")
                .font(.caption)
                .foregroundStyle(.tertiary)

            let modesWithMemory = settings.powerModes.filter { $0.memoryEnabled && $0.memory != nil && !($0.memory?.isEmpty ?? true) }

            if modesWithMemory.isEmpty {
                emptyMemoryCard(message: "No Power Modes have memory stored yet")
            } else {
                ForEach(modesWithMemory) { mode in
                    MemoryRowView(
                        icon: mode.icon,
                        iconColor: mode.iconColor.color,
                        title: mode.name,
                        preview: mode.memory ?? "",
                        lastUpdated: mode.lastMemoryUpdate,
                        onEdit: { editWorkflowMemory(mode) }
                    )
                }
            }
        }
    }

    // MARK: - Context Memories Section

    private var contextMemoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CONTEXT MEMORIES")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Per Context (only shows contexts with memory)")
                .font(.caption)
                .foregroundStyle(.tertiary)

            let contextsWithMemory = settings.contexts.filter { $0.memoryEnabled && $0.memory != nil && !($0.memory?.isEmpty ?? true) }

            if contextsWithMemory.isEmpty {
                emptyMemoryCard(message: "No Contexts have memory stored yet")
            } else {
                ForEach(contextsWithMemory) { context in
                    MemoryRowView(
                        icon: context.icon,
                        iconColor: context.color.color,
                        title: context.name,
                        preview: context.memory ?? "",
                        lastUpdated: context.lastMemoryUpdate,
                        onEdit: { editContextMemory(context) }
                    )
                }
            }
        }
    }

    // MARK: - Filtered History Link

    @ViewBuilder
    private var filteredHistoryLink: some View {
        switch filterMode {
        case .all:
            NavigationLink(destination: HistoryView()) {
                historyLinkContent(title: "View All History", subtitle: "All transcriptions")
            }
        case .global:
            NavigationLink(destination: HistoryView()) {
                historyLinkContent(title: "View Global History", subtitle: "All transcriptions")
            }
        case .byContext:
            if let contextId = selectedContextId {
                NavigationLink(destination: HistoryView(filterContextId: contextId, showFilterBar: false)) {
                    historyLinkContent(title: "View Context History", subtitle: "Transcriptions for this context")
                }
            }
        case .byPowerMode:
            if let modeId = selectedPowerModeId {
                NavigationLink(destination: HistoryView(filterPowerModeId: modeId, showFilterBar: false)) {
                    historyLinkContent(title: "View Power Mode History", subtitle: "Transcriptions for this mode")
                }
            }
        }
    }

    private func historyLinkContent(title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title3)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
    }

    // MARK: - Clear All Section

    private var clearAllSection: some View {
        Button(action: {
            HapticManager.warning()
            showingClearConfirmation = true
        }) {
            Text("Clear All Memory")
                .font(.body.weight(.medium))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
    }

    // MARK: - Empty Card

    private func emptyMemoryCard(message: String) -> some View {
        HStack {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .italic()
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
    }

    // MARK: - Actions

    private func editHistoryMemory() {
        HapticManager.lightTap()
        editingMemoryType = .history
        editingTitle = "History Memory"
        editingMemoryContent = settings.historyMemory?.summary ?? ""
        showingEditor = true
    }

    private func editWorkflowMemory(_ mode: PowerMode) {
        HapticManager.lightTap()
        editingMemoryType = .workflow(mode.id)
        editingTitle = "\(mode.name) - Workflow Memory"
        editingMemoryContent = mode.memory ?? ""
        showingEditor = true
    }

    private func editContextMemory(_ context: ConversationContext) {
        HapticManager.lightTap()
        editingMemoryType = .context(context.id)
        editingTitle = "\(context.name) - Context Memory"
        editingMemoryContent = context.memory ?? ""
        showingEditor = true
    }

    private func saveMemory() {
        guard let type = editingMemoryType else { return }

        switch type {
        case .history:
            settings.updateHistoryMemory(summary: editingMemoryContent, topic: nil)
        case .workflow(let id):
            settings.updatePowerModeMemory(id: id, memory: editingMemoryContent)
        case .context(let id):
            settings.updateContextMemory(id: id, memory: editingMemoryContent)
        }

        showingEditor = false
        editingMemoryType = nil
    }

    private func clearMemory() {
        guard let type = editingMemoryType else { return }

        switch type {
        case .history:
            settings.updateHistoryMemory(summary: "", topic: nil)
        case .workflow(let id):
            settings.updatePowerModeMemory(id: id, memory: "")
        case .context(let id):
            settings.updateContextMemory(id: id, memory: "")
        }

        showingEditor = false
        editingMemoryType = nil
    }

    private func clearAllMemory() {
        HapticManager.success()

        // Clear global history memory
        settings.updateHistoryMemory(summary: "", topic: nil)

        // Clear all power mode memories
        for mode in settings.powerModes {
            settings.updatePowerModeMemory(id: mode.id, memory: "")
        }

        // Clear all context memories
        for context in settings.contexts {
            settings.updateContextMemory(id: context.id, memory: "")
        }
    }

    // MARK: - Helpers

    private func timeAgo(_ date: Date?) -> String {
        guard let date = date else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Memory Type

private enum MemoryType {
    case history
    case workflow(UUID)
    case context(UUID)
}

// MARK: - Memory Row View

struct MemoryRowView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let preview: String
    let lastUpdated: Date?
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    if icon.contains(".") {
                        Image(systemName: icon)
                            .font(.body)
                            .foregroundStyle(iconColor)
                    } else {
                        Text(icon)
                            .font(.title3)
                    }
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(preview.isEmpty ? "No memory stored" : "\"\(preview.prefix(50))...\"")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let updated = lastUpdated {
                        Text("Updated: \(timeAgo(updated))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                Text("Edit")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
            }
            .padding(12)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MemoryView()
            .environmentObject(SharedSettings.shared)
    }
    .preferredColorScheme(.dark)
}
