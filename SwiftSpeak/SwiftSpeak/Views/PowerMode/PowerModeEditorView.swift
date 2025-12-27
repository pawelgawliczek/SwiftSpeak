//
//  PowerModeEditorView.swift
//  SwiftSpeak
//
//  Create or edit a Power Mode with all configuration options
//  Phase 4: Removed capabilities, added Memory and Knowledge Base sections
//

import SwiftUI

struct PowerModeEditorView: View {
    let powerMode: PowerMode?
    let onSave: (PowerMode) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SharedSettings

    // Form state
    @State private var name: String = ""
    @State private var icon: String = "bolt.fill"
    @State private var iconColor: PowerModeColorPreset = .orange
    @State private var iconBackgroundColor: PowerModeColorPreset = .orange
    @State private var instruction: String = ""
    @State private var outputFormat: String = ""

    // Phase 4: Memory
    @State private var memoryEnabled: Bool = false
    @State private var memoryContent: String = ""

    // App assignment
    @State private var appAssignment: AppAssignment = AppAssignment()

    // Phase 4e: RAG Knowledge Documents
    @State private var knowledgeDocumentIds: [UUID] = []

    // UI state
    @State private var showingIconPicker = false
    @State private var showingKnowledgeBase = false
    @State private var showingMemoryEditor = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !instruction.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Creates a temporary PowerMode with current editor values for KnowledgeBaseView
    private var currentPowerModeForKnowledgeBase: PowerMode {
        PowerMode(
            id: powerMode?.id ?? UUID(),
            name: name,
            icon: icon,
            iconColor: iconColor,
            iconBackgroundColor: iconBackgroundColor,
            instruction: instruction,
            outputFormat: outputFormat,
            memoryEnabled: memoryEnabled,
            memory: memoryContent.isEmpty ? nil : memoryContent,
            knowledgeDocumentIds: knowledgeDocumentIds,
            appAssignment: appAssignment
        )
    }

    init(powerMode: PowerMode?, onSave: @escaping (PowerMode) -> Void) {
        self.powerMode = powerMode
        self.onSave = onSave

        // Initialize state from powerMode if editing
        if let mode = powerMode {
            _name = State(initialValue: mode.name)
            _icon = State(initialValue: mode.icon)
            _iconColor = State(initialValue: mode.iconColor)
            _iconBackgroundColor = State(initialValue: mode.iconBackgroundColor)
            _instruction = State(initialValue: mode.instruction)
            _outputFormat = State(initialValue: mode.outputFormat)
            _memoryEnabled = State(initialValue: mode.memoryEnabled)
            _memoryContent = State(initialValue: mode.memory ?? "")
            _appAssignment = State(initialValue: mode.appAssignment)
            _knowledgeDocumentIds = State(initialValue: mode.knowledgeDocumentIds)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Icon and name section
                    iconAndNameSection

                    // Instruction section
                    instructionSection

                    // Output format section
                    outputFormatSection

                    // Memory section (Phase 4)
                    memorySection

                    // Knowledge Base section (Phase 4)
                    knowledgeBaseSection

                    // App assignment section
                    appAssignmentSection
                }
                .padding(16)
            }
            .background(AppTheme.darkBase.ignoresSafeArea())
            .navigationTitle(powerMode == nil ? "New Power Mode" : "Edit Power Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPicker(
                    selectedIcon: $icon,
                    iconColor: $iconColor,
                    iconBackgroundColor: $iconBackgroundColor
                )
            }
            .sheet(isPresented: $showingKnowledgeBase) {
                KnowledgeBaseView(
                    powerMode: currentPowerModeForKnowledgeBase,
                    documentIds: $knowledgeDocumentIds
                )
            }
            .sheet(isPresented: $showingMemoryEditor) {
                MemoryEditorSheet(
                    title: "\(name) - Workflow Memory",
                    content: $memoryContent,
                    lastUpdated: powerMode?.lastMemoryUpdate,
                    onSave: {
                        // Memory content is already bound
                    },
                    onClear: {
                        memoryContent = ""
                    }
                )
            }
        }
    }

    // MARK: - Icon and Name Section

    private var iconAndNameSection: some View {
        VStack(spacing: 20) {
            // Icon button
            Button(action: {
                HapticManager.selection()
                showingIconPicker = true
            }) {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 40))
                        .foregroundStyle(iconColor.gradient)
                        .frame(width: 80, height: 80)
                        .background(iconBackgroundColor.color.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))

                    Text("Tap to change icon & colors")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Name field
            TextField("Mode Name", text: $name)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        }
        .padding(20)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
    }

    // MARK: - Instruction Section

    private var instructionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INSTRUCTION")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextEditor(text: $instruction)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(12)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            Text("What the AI should do with your voice input")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Output Format Section

    private var outputFormatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OUTPUT FORMAT")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextEditor(text: $outputFormat)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(12)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            Text("How to format the response (markdown)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Memory Section (Phase 4)

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WORKFLOW MEMORY")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            // Memory toggle
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundStyle(memoryEnabled ? AppTheme.powerAccent : .secondary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Memory")
                        .font(.subheadline.weight(.medium))

                    Text("Remember context from previous sessions with this mode")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $memoryEnabled)
                    .labelsHidden()
                    .tint(AppTheme.powerAccent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            // Memory preview (when enabled and has content)
            if memoryEnabled, !memoryContent.isEmpty {
                Button(action: {
                    HapticManager.lightTap()
                    showingMemoryEditor = true
                }) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "brain")
                                .font(.caption)
                                .foregroundStyle(.purple)
                            Text("Current Memory")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("Edit")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppTheme.powerAccent)
                        }

                        Text(memoryContent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let lastUpdate = powerMode?.lastMemoryUpdate {
                            Text("Updated \(lastUpdate.formatted(.relative(presentation: .named)))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(12)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            // History link (if editing existing mode)
            if let mode = powerMode, mode.usageCount > 0 {
                NavigationLink(destination: HistoryView(filterPowerModeId: mode.id, showFilterBar: false)
                    .navigationTitle("\(mode.name) History")) {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3)
                            .foregroundStyle(AppTheme.powerAccent)
                            .frame(width: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("View Usage History")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)

                            Text("\(mode.usageCount) transcription\(mode.usageCount == 1 ? "" : "s") with this mode")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Knowledge Base Section (Phase 4)

    private var knowledgeBaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KNOWLEDGE BASE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Button(action: {
                HapticManager.selection()
                showingKnowledgeBase = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(AppTheme.powerAccent)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage Documents")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)

                        let docCount = powerMode?.knowledgeDocumentIds.count ?? 0
                        Text(docCount == 0 ? "No documents attached" : "\(docCount) document\(docCount == 1 ? "" : "s") attached")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())

            Text("Upload PDFs, text files, or URLs to give this mode context")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - App Assignment Section

    private var appAssignmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("APP AUTO-ENABLE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            AppAssignmentSection(appAssignment: $appAssignment)
                .environmentObject(settings)
        }
    }

    // MARK: - Actions

    private func saveAndDismiss() {
        // Determine if memory was updated
        let memoryWasUpdated = memoryContent != (powerMode?.memory ?? "")
        let newMemoryUpdate: Date? = memoryWasUpdated ? Date() : powerMode?.lastMemoryUpdate

        let savedMode = PowerMode(
            id: powerMode?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            icon: icon,
            iconColor: iconColor,
            iconBackgroundColor: iconBackgroundColor,
            instruction: instruction.trimmingCharacters(in: .whitespaces),
            outputFormat: outputFormat.trimmingCharacters(in: .whitespaces),
            createdAt: powerMode?.createdAt ?? Date(),
            updatedAt: Date(),
            usageCount: powerMode?.usageCount ?? 0,
            memoryEnabled: memoryEnabled,
            memory: memoryContent.isEmpty ? nil : memoryContent,
            lastMemoryUpdate: newMemoryUpdate,
            knowledgeDocumentIds: knowledgeDocumentIds,
            isArchived: powerMode?.isArchived ?? false,
            appAssignment: appAssignment
        )
        HapticManager.success()
        onSave(savedMode)
        dismiss()
    }
}

// MARK: - Color Picker Row

struct ColorPickerRow: View {
    let label: String
    @Binding var selectedColor: PowerModeColorPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(PowerModeColorPreset.allCases) { colorPreset in
                        Button(action: {
                            HapticManager.selection()
                            selectedColor = colorPreset
                        }) {
                            Circle()
                                .fill(colorPreset.gradient)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .strokeBorder(selectedColor == colorPreset ? Color.white : Color.clear, lineWidth: 2)
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(selectedColor == colorPreset ? colorPreset.color : Color.clear, lineWidth: 4)
                                        .scaleEffect(1.25)
                                )
                                .scaleEffect(selectedColor == colorPreset ? 1.1 : 1.0)
                                .animation(AppTheme.quickSpring, value: selectedColor)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Preview

#Preview("New Mode") {
    PowerModeEditorView(powerMode: nil) { _ in }
        .environmentObject(SharedSettings.shared)
        .preferredColorScheme(.dark)
}

#Preview("Edit Mode") {
    PowerModeEditorView(powerMode: PowerMode.presets.first!) { _ in }
        .environmentObject(SharedSettings.shared)
        .preferredColorScheme(.dark)
}

