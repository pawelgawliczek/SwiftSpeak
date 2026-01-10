//
//  OutputActionsEditor.swift
//  SwiftSpeak
//
//  Phase 17: Editor for configuring Output Actions on Power Modes
//  Allows adding, removing, and configuring actions that deliver results after Power Mode execution
//

import SwiftUI
import SwiftSpeakCore

struct OutputActionsEditor: View {
    @Binding var actions: [OutputAction]
    @EnvironmentObject private var settings: SharedSettings

    @State private var showingAddSheet = false
    @State private var editingAction: OutputAction?
    @State private var showingEditSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("OUTPUT ACTIONS")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: {
                    HapticManager.selection()
                    showingAddSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.caption.weight(.semibold))
                        Text("Add")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(AppTheme.powerAccent)
                }
            }

            Text("Actions that deliver results after Power Mode runs (in order)")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if actions.isEmpty {
                emptyState
            } else {
                actionsList
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            OutputActionTypePicker { actionType in
                let newOrder = (actions.map(\.order).max() ?? 0) + 1
                let newAction = OutputAction(type: actionType, label: actionType.displayName, order: newOrder)
                actions.append(newAction)
                editingAction = newAction
                showingEditSheet = true
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let action = editingAction, let index = actions.firstIndex(where: { $0.id == action.id }) {
                OutputActionConfigSheet(action: $actions[index]) {
                    showingEditSheet = false
                    editingAction = nil
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "arrow.up.doc")
                    .font(.title2)
                    .foregroundStyle(.tertiary)

                Text("No Output Actions")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text("Add actions to deliver results like clipboard, Shortcuts, or notifications")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                Button(action: {
                    HapticManager.selection()
                    showingAddSheet = true
                }) {
                    Text("Add Action")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.powerAccent)
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 20)
            Spacer()
        }
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
    }

    // MARK: - Actions List

    private var actionsList: some View {
        VStack(spacing: 6) {
            ForEach(sortedActions) { action in
                actionRow(action)
            }
        }
    }

    private var sortedActions: [OutputAction] {
        actions.sorted { $0.order < $1.order }
    }

    private func actionRow(_ action: OutputAction) -> some View {
        HStack(spacing: 12) {
            // Order indicator
            Text("\(action.order)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 20)

            // Action icon
            Image(systemName: action.type.icon)
                .font(.body)
                .foregroundStyle(action.isEnabled ? action.type.color : .secondary)
                .frame(width: 28)

            // Action info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(action.label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(action.isEnabled ? .primary : .secondary)

                    if action.isRequired {
                        Text("Required")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Capsule())
                    }
                }

                Text(action.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Edit button
            Button(action: {
                HapticManager.selection()
                editingAction = action
                showingEditSheet = true
            }) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            // Enable toggle
            Toggle("", isOn: binding(for: action, keyPath: \.isEnabled))
                .labelsHidden()
                .tint(action.type.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(action.isEnabled ? action.type.color.opacity(0.1) : Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        .contextMenu {
            Button(action: {
                moveUp(action)
            }) {
                Label("Move Up", systemImage: "arrow.up")
            }
            .disabled(action.order <= 1)

            Button(action: {
                moveDown(action)
            }) {
                Label("Move Down", systemImage: "arrow.down")
            }
            .disabled(action.order >= actions.count)

            Divider()

            Button(role: .destructive, action: {
                deleteAction(action)
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Helpers

    private func binding(for action: OutputAction, keyPath: WritableKeyPath<OutputAction, Bool>) -> Binding<Bool> {
        guard let index = actions.firstIndex(where: { $0.id == action.id }) else {
            return .constant(false)
        }
        return Binding(
            get: { actions[index][keyPath: keyPath] },
            set: { actions[index][keyPath: keyPath] = $0 }
        )
    }

    private func moveUp(_ action: OutputAction) {
        guard let currentIndex = actions.firstIndex(where: { $0.id == action.id }),
              action.order > 1 else { return }

        // Find the action above (by order)
        if let aboveIndex = actions.firstIndex(where: { $0.order == action.order - 1 }) {
            actions[aboveIndex].order += 1
            actions[currentIndex].order -= 1
        }
    }

    private func moveDown(_ action: OutputAction) {
        guard let currentIndex = actions.firstIndex(where: { $0.id == action.id }),
              action.order < actions.count else { return }

        // Find the action below (by order)
        if let belowIndex = actions.firstIndex(where: { $0.order == action.order + 1 }) {
            actions[belowIndex].order -= 1
            actions[currentIndex].order += 1
        }
    }

    private func deleteAction(_ action: OutputAction) {
        actions.removeAll { $0.id == action.id }
        // Renumber remaining actions
        for (index, _) in actions.enumerated() {
            actions[index].order = index + 1
        }
    }
}

// MARK: - Output Action Type Picker

struct OutputActionTypePicker: View {
    let onSelect: (OutputActionType) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(OutputActionType.allCases, id: \.self) { type in
                        Button(action: {
                            HapticManager.selection()
                            dismiss()
                            onSelect(type)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: type.icon)
                                    .font(.title3)
                                    .foregroundStyle(type.color)
                                    .frame(width: 40, height: 40)
                                    .background(type.color.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(type.displayName)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)

                                    Text(type.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(AppTheme.darkBase.ignoresSafeArea())
            .navigationTitle("Add Output Action")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Output Action Config Sheet

struct OutputActionConfigSheet: View {
    @Binding var action: OutputAction
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SharedSettings

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Label
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Label")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField("Action label", text: $action.label)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                    }

                    // Execution order
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Execution Order")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Stepper(value: $action.order, in: 1...99) {
                            Text("Order: \(action.order)")
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

                        Text("Actions run in order (1 first, then 2, etc.)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    // Type-specific configuration
                    typeSpecificConfig

                    Divider()
                        .padding(.vertical, 8)

                    // Required toggle
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title3)
                            .foregroundStyle(action.isRequired ? .red : .secondary)
                            .frame(width: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Required")
                                .font(.subheadline.weight(.medium))

                            Text("Stop remaining actions if this fails")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: $action.isRequired)
                            .labelsHidden()
                            .tint(.red)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .background(action.isRequired ? Color.red.opacity(0.1) : Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                }
                .padding(16)
            }
            .background(AppTheme.darkBase.ignoresSafeArea())
            .navigationTitle("Configure \(action.type.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        HapticManager.success()
                        onDone()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private var typeSpecificConfig: some View {
        switch action.type {
        case .clipboard:
            infoBox(text: "Copies the result to the system clipboard")

        case .insertAtCursor:
            infoBox(text: "Pastes the result at the current cursor position")

        case .insertAndSend:
            infoBox(text: "Not available on iOS")

        case .obsidianSave:
            obsidianSaveConfig

        case .triggerShortcut:
            shortcutConfig

        case .webhook:
            webhookConfig

        case .notification:
            notificationConfig

        case .textToSpeech:
            textToSpeechConfig

        case .shareSheet:
            infoBox(text: "Opens the share sheet with the result")

        case .openURL:
            openURLConfig

        case .chainPowerMode:
            chainPowerModeConfig
        }
    }

    // MARK: - Obsidian Save Config

    private var obsidianSaveConfig: some View {
        VStack(alignment: .leading, spacing: 12) {
            let connectedVaults = settings.obsidianVaults.filter { $0.status == .synced }

            if connectedVaults.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundStyle(.orange)

                        Text("No Obsidian vaults connected")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Connect vaults in Settings → Obsidian")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            } else {
                // Save action type
                VStack(alignment: .leading, spacing: 8) {
                    Text("Save Action")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(ObsidianSaveAction.allCases, id: \.self) { saveAction in
                        let isSelected = (action.obsidianSaveAction ?? .appendDaily) == saveAction

                        Button(action: {
                            HapticManager.selection()
                            action.obsidianSaveAction = saveAction
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: saveActionIcon(for: saveAction))
                                    .font(.body)
                                    .foregroundStyle(isSelected ? .purple : .secondary)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(saveAction.displayName)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)

                                    Text(saveAction.description)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }

                                Spacer()

                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? .purple : .secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(isSelected ? Color.purple.opacity(0.1) : Color.primary.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Target vault
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Vault")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(connectedVaults) { vault in
                        let isSelected = action.obsidianTargetVaultId == vault.id

                        Button(action: {
                            HapticManager.selection()
                            action.obsidianTargetVaultId = vault.id
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "folder.fill")
                                    .font(.body)
                                    .foregroundStyle(isSelected ? .purple : .secondary)
                                    .frame(width: 28)

                                Text(vault.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? .purple : .secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(isSelected ? Color.purple.opacity(0.1) : Color.primary.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Note name (for appendNote and createNote)
                if action.obsidianSaveAction == .appendNote || action.obsidianSaveAction == .createNote {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note Name")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField("My Notes", text: Binding(
                            get: { action.obsidianTargetNoteName ?? "" },
                            set: { action.obsidianTargetNoteName = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

                        Text(action.obsidianSaveAction == .createNote
                             ? "Name for the new note (without .md extension)"
                             : "Name of the note to append to")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                // Auto-execute toggle
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .font(.title3)
                        .foregroundStyle(action.obsidianAutoExecute == true ? .purple : .secondary)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Execute")
                            .font(.subheadline.weight(.medium))

                        Text("Save without confirmation prompt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { action.obsidianAutoExecute ?? false },
                        set: { action.obsidianAutoExecute = $0 }
                    ))
                    .labelsHidden()
                    .tint(.purple)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            }
        }
    }

    private func saveActionIcon(for action: ObsidianSaveAction) -> String {
        switch action {
        case .appendDaily: return "calendar"
        case .appendNote: return "doc.text"
        case .createNote: return "doc.badge.plus"
        }
    }

    private func infoBox(text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle")
                .foregroundStyle(.blue)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
    }

    private var shortcutConfig: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Shortcut Name")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("My Shortcut", text: Binding(
                    get: { action.shortcutName ?? "" },
                    set: { action.shortcutName = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

                Text("Must match exactly the name in Shortcuts app")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title3)
                    .foregroundStyle(action.waitForResult == true ? .blue : .secondary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Wait for Result")
                        .font(.subheadline.weight(.medium))

                    Text("Wait for Shortcut to complete before continuing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { action.waitForResult ?? false },
                    set: { action.waitForResult = $0 }
                ))
                .labelsHidden()
                .tint(.blue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        }
    }

    private var webhookConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Webhook")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            let outputWebhooks = settings.webhooks.filter { $0.type == .outputDestination || $0.type == .automationTrigger }

            if outputWebhooks.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("No output webhooks configured")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Configure webhooks in Settings")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                ForEach(outputWebhooks) { webhook in
                    let isSelected = action.webhookId == webhook.id

                    Button(action: {
                        HapticManager.selection()
                        action.webhookId = webhook.id
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: webhook.template.icon)
                                .font(.body)
                                .foregroundStyle(isSelected ? .orange : .secondary)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(webhook.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)

                                Text(webhook.url.host ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? .orange : .secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(isSelected ? Color.orange.opacity(0.1) : Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Webhooks of type \"Output Destination\" or \"Automation Trigger\" are shown")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var notificationConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notification Title")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("Power Mode Complete", text: Binding(
                get: { action.notificationTitle ?? "Power Mode Complete" },
                set: { action.notificationTitle = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            Text("The result will be shown as the notification body")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var textToSpeechConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Voice")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("Default voice", text: Binding(
                get: { action.speakVoice ?? "" },
                set: { action.speakVoice = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            Text("Leave empty for default voice, or enter a voice identifier")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var openURLConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("URL Template")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("https://example.com?text={{output}}", text: Binding(
                get: { action.urlTemplate ?? "" },
                set: { action.urlTemplate = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.plain)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            Text("Use {{output}} as placeholder for the result")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var chainPowerModeConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chain to Power Mode")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if settings.powerModes.isEmpty {
                HStack {
                    Spacer()
                    Text("No other Power Modes available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                ForEach(settings.powerModes) { mode in
                    let isSelected = action.chainedPowerModeId == mode.id

                    Button(action: {
                        HapticManager.selection()
                        action.chainedPowerModeId = mode.id
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: mode.icon)
                                .font(.body)
                                .foregroundStyle(isSelected ? mode.iconColor.color : .secondary)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                            }

                            Spacer()

                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? mode.iconColor.color : .secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(isSelected ? mode.iconColor.color.opacity(0.1) : Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("The result from this Power Mode will be the input for the chained mode")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - OutputActionType Extensions

extension OutputActionType {
    var icon: String {
        switch self {
        case .clipboard: return "doc.on.clipboard"
        case .insertAtCursor: return "keyboard"
        case .insertAndSend: return "paperplane.fill"
        case .obsidianSave: return "note.text"
        case .triggerShortcut: return "apps.iphone"
        case .webhook: return "link"
        case .notification: return "bell.fill"
        case .textToSpeech: return "speaker.wave.3.fill"
        case .shareSheet: return "square.and.arrow.up"
        case .openURL: return "globe"
        case .chainPowerMode: return "bolt.horizontal.fill"
        }
    }

    var color: Color {
        switch self {
        case .clipboard: return .blue
        case .insertAtCursor: return .purple
        case .insertAndSend: return .orange
        case .obsidianSave: return .purple
        case .triggerShortcut: return .pink
        case .webhook: return .orange
        case .notification: return .yellow
        case .textToSpeech: return .green
        case .shareSheet: return .blue
        case .openURL: return .green
        case .chainPowerMode: return AppTheme.powerAccent
        }
    }

    var description: String {
        switch self {
        case .clipboard:
            return "Copy the result to clipboard"
        case .insertAtCursor:
            return "Paste result into current text field"
        case .insertAndSend:
            return "Insert and press Enter to send"
        case .obsidianSave:
            return "Save result to Obsidian vault"
        case .triggerShortcut:
            return "Pass result to an Apple Shortcut"
        case .webhook:
            return "Send result to a configured webhook"
        case .notification:
            return "Show result as a notification"
        case .textToSpeech:
            return "Read the result aloud"
        case .shareSheet:
            return "Open share sheet with result"
        case .openURL:
            return "Open a URL with result as parameter"
        case .chainPowerMode:
            return "Pass result to another Power Mode"
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State var actions: [OutputAction] = [
            OutputAction(type: .clipboard, isEnabled: true, isRequired: true, label: "Copy to Clipboard", order: 1),
            OutputAction(type: .triggerShortcut, isEnabled: true, isRequired: false, label: "Save to Notes", order: 2, shortcutName: "Add to Notes", waitForResult: false),
            OutputAction(type: .notification, isEnabled: true, isRequired: false, label: "Notify", order: 3, notificationTitle: "Done!")
        ]

        var body: some View {
            ScrollView {
                OutputActionsEditor(actions: $actions)
                    .padding()
            }
            .background(AppTheme.darkBase)
            .environmentObject(SharedSettings.shared)
        }
    }

    return PreviewWrapper()
        .preferredColorScheme(.dark)
}
