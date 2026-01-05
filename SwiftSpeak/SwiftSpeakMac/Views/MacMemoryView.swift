//
//  MacMemoryView.swift
//  SwiftSpeakMac
//
//  macOS version of Memory management view
//  Manages global, context, and power mode memory
//

import SwiftUI
import SwiftSpeakCore

// MARK: - Memory View

struct MacMemoryView: View {
    @ObservedObject var settings: MacSettings
    @State private var selectedMemoryType: MemoryType = .global
    @State private var showingClearConfirmation = false
    @State private var editingGlobalMemory = false
    @State private var editingMemoryText = ""

    enum MemoryType: String, CaseIterable {
        case global = "Global"
        case contexts = "Contexts"
        case powerModes = "Power Modes"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab Picker
            Picker("Memory Type", selection: $selectedMemoryType) {
                ForEach(MemoryType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // Content based on selection
            switch selectedMemoryType {
            case .global:
                globalMemoryView
            case .contexts:
                contextMemoriesView
            case .powerModes:
                powerModeMemoriesView
            }
        }
        .sheet(isPresented: $editingGlobalMemory) {
            MacMemoryEditorSheet(
                title: "Global Memory",
                memoryText: editingMemoryText,
                memoryLimit: settings.globalMemoryLimit,
                onSave: { newText in
                    settings.globalMemory = newText.isEmpty ? nil : newText
                    editingGlobalMemory = false
                },
                onCancel: { editingGlobalMemory = false }
            )
        }
        .alert("Clear All Memory?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearAllMemory()
            }
        } message: {
            Text("This will clear the global memory and all context/power mode memories. This action cannot be undone.")
        }
    }

    // MARK: - Global Memory View

    private var globalMemoryView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Global Memory")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Information the AI remembers about you across all contexts")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("Enabled", isOn: $settings.globalMemoryEnabled)
                        .toggleStyle(.switch)
                }

                if settings.globalMemoryEnabled {
                    // Memory Content
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Memory Content")
                                .font(.headline)
                            Spacer()
                            if let memory = settings.globalMemory {
                                Text("\(memory.count)/\(settings.globalMemoryLimit) characters")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Button("Edit") {
                                editingMemoryText = settings.globalMemory ?? ""
                                editingGlobalMemory = true
                            }
                            .buttonStyle(.bordered)
                        }

                        if let memory = settings.globalMemory, !memory.isEmpty {
                            Text(memory)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.purple.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "brain")
                                    .font(.largeTitle)
                                    .foregroundStyle(.tertiary)
                                Text("No memory stored yet")
                                    .foregroundStyle(.secondary)
                                Text("The AI will learn about you as you use SwiftSpeak")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(32)
                            .background(Color.primary.opacity(0.02))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    // Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Settings")
                            .font(.headline)

                        HStack {
                            Text("Memory Limit")
                            Spacer()
                            Stepper("\(settings.globalMemoryLimit) characters",
                                    value: $settings.globalMemoryLimit,
                                    in: 500...2000,
                                    step: 100)
                        }
                        .padding()
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Actions
                    HStack {
                        Button(role: .destructive) {
                            settings.globalMemory = nil
                        } label: {
                            Label("Clear Global Memory", systemImage: "trash")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                        .disabled(settings.globalMemory == nil)

                        Spacer()

                        Button(role: .destructive) {
                            showingClearConfirmation = true
                        } label: {
                            Label("Clear All Memory", systemImage: "trash.fill")
                        }
                        .buttonStyle(.bordered)
                        .foregroundStyle(.red)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "brain.head.profile.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text("Global Memory Disabled")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Enable global memory to let the AI remember information about you across all contexts")
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(32)
                }
            }
            .padding(24)
        }
    }

    // MARK: - Context Memories View

    private var contextMemoriesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Context Memories")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                Text("Each context can have its own memory that the AI uses when that context is active")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)

                if settings.contexts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text("No Contexts")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(48)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(settings.contexts) { context in
                            ContextMemoryCard(context: context, settings: settings)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Power Mode Memories View

    private var powerModeMemoriesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Power Mode Memories")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                Text("Each power mode can remember information from previous uses")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)

                if settings.powerModes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bolt.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text("No Power Modes")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(48)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(settings.powerModes.filter { $0.memoryEnabled }) { powerMode in
                            PowerModeMemoryCard(powerMode: powerMode, settings: settings)
                        }

                        if settings.powerModes.allSatisfy({ !$0.memoryEnabled }) {
                            VStack(spacing: 12) {
                                Image(systemName: "brain.head.profile")
                                    .font(.title)
                                    .foregroundStyle(.tertiary)
                                Text("No power modes with memory enabled")
                                    .foregroundStyle(.secondary)
                                Text("Enable memory on a power mode to see it here")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(32)
                            .background(Color.primary.opacity(0.02))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Actions

    private func clearAllMemory() {
        settings.globalMemory = nil
        for context in settings.contexts {
            settings.clearContextMemory(id: context.id)
        }
        for powerMode in settings.powerModes {
            settings.clearPowerModeMemory(id: powerMode.id)
        }
    }
}

// MARK: - Context Memory Card

struct ContextMemoryCard: View {
    let context: ConversationContext
    @ObservedObject var settings: MacSettings
    @State private var isExpanded = false
    @State private var isEditing = false
    @State private var editingText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(context.color.color.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Text(context.icon)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.name)
                            .fontWeight(.medium)

                        HStack(spacing: 8) {
                            if context.useContextMemory {
                                Label("Memory enabled", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else {
                                Label("Memory disabled", systemImage: "xmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let lastUpdate = context.lastMemoryUpdate {
                                Text("Updated \(lastUpdate, style: .relative)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded Content
            if isExpanded && context.useContextMemory {
                Divider()

                if let memory = context.contextMemory, !memory.isEmpty {
                    Text(memory)
                        .font(.callout)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Text("No memory stored for this context")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }

                HStack {
                    Button("Edit") {
                        editingText = context.contextMemory ?? ""
                        isEditing = true
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        settings.clearContextMemory(id: context.id)
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                    .disabled(context.contextMemory == nil)
                }
            }
        }
        .padding()
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .sheet(isPresented: $isEditing) {
            MacMemoryEditorSheet(
                title: "\(context.name) Memory",
                memoryText: editingText,
                memoryLimit: context.memoryLimit,
                onSave: { newText in
                    settings.updateContextMemory(id: context.id, memory: newText)
                    isEditing = false
                },
                onCancel: { isEditing = false }
            )
        }
    }
}

// MARK: - Power Mode Memory Card

struct PowerModeMemoryCard: View {
    let powerMode: PowerMode
    @ObservedObject var settings: MacSettings
    @State private var isExpanded = false
    @State private var isEditing = false
    @State private var editingText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(powerMode.iconColor.color.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Image(systemName: powerMode.icon)
                            .foregroundStyle(powerMode.iconColor.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(powerMode.name)
                            .fontWeight(.medium)

                        HStack(spacing: 8) {
                            Label("\(powerMode.usageCount) uses", systemImage: "chart.bar")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let lastUpdate = powerMode.lastMemoryUpdate {
                                Text("Updated \(lastUpdate, style: .relative)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded Content
            if isExpanded {
                Divider()

                if let memory = powerMode.memory, !memory.isEmpty {
                    Text(memory)
                        .font(.callout)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Text("No memory stored for this power mode")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }

                HStack {
                    Button("Edit") {
                        editingText = powerMode.memory ?? ""
                        isEditing = true
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        settings.clearPowerModeMemory(id: powerMode.id)
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                    .disabled(powerMode.memory == nil)
                }
            }
        }
        .padding()
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .sheet(isPresented: $isEditing) {
            MacMemoryEditorSheet(
                title: "\(powerMode.name) Memory",
                memoryText: editingText,
                memoryLimit: powerMode.memoryLimit,
                onSave: { newText in
                    settings.updatePowerModeMemory(id: powerMode.id, memory: newText)
                    isEditing = false
                },
                onCancel: { isEditing = false }
            )
        }
    }
}

// MARK: - Memory Editor Sheet

struct MacMemoryEditorSheet: View {
    let title: String
    @State var memoryText: String
    let memoryLimit: Int
    let onSave: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
                Spacer()
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Save") {
                    onSave(memoryText)
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            // Editor
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Memory Content")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(memoryText.count)/\(memoryLimit)")
                        .font(.caption)
                        .foregroundStyle(memoryText.count > memoryLimit ? .red : .secondary)
                }

                TextEditor(text: $memoryText)
                    .font(.body)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text("This memory will be included in prompts when the AI is active in this context or power mode.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()

            Spacer()
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - Preview

#Preview {
    MacMemoryView(settings: MacSettings.shared)
        .frame(width: 600, height: 500)
}
