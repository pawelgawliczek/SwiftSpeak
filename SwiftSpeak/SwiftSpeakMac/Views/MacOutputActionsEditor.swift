//
//  MacOutputActionsEditor.swift
//  SwiftSpeakMac
//
//  Phase 17: macOS version of Output Actions editor for Power Modes
//  Matches iOS OutputActionsEditor for UI consistency
//

import SwiftUI
import SwiftSpeakCore

// MARK: - Mac Output Actions Editor

struct MacOutputActionsEditor: View {
    @Binding var actions: [OutputAction]
    @ObservedObject var settings: MacSettings

    @State private var showingAddSheet = false
    @State private var editingAction: OutputAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Output Actions")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: { showingAddSheet = true }) {
                    Label("Add", systemImage: "plus")
                        .font(.callout)
                }
                .buttonStyle(.borderless)
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
            MacOutputActionTypePicker { actionType in
                let newOrder = (actions.map(\.order).max() ?? 0) + 1
                let newAction = OutputAction(type: actionType, label: actionType.displayName, order: newOrder)
                actions.append(newAction)
                editingAction = newAction
            }
        }
        .sheet(item: $editingAction) { action in
            if let index = actions.firstIndex(where: { $0.id == action.id }) {
                MacOutputActionConfigSheet(
                    action: $actions[index],
                    settings: settings
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.up.doc")
                .font(.title)
                .foregroundStyle(.tertiary)

            Text("No Output Actions")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text("Add actions to deliver results like clipboard, Shortcuts, or notifications")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button("Add Action") {
                showingAddSheet = true
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                .frame(width: 24)

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

            // Move up/down buttons
            HStack(spacing: 4) {
                Button(action: { moveUp(action) }) {
                    Image(systemName: "arrow.up")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)
                .disabled(action.order <= 1)

                Button(action: { moveDown(action) }) {
                    Image(systemName: "arrow.down")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)
                .disabled(action.order >= actions.count)
            }

            // Edit button
            Button(action: { editingAction = action }) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.borderless)

            // Enable toggle
            Toggle("", isOn: binding(for: action, keyPath: \.isEnabled))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(action.type.color)

            // Delete button
            Button(action: { deleteAction(action) }) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(action.isEnabled ? action.type.color.opacity(0.1) : Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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

        if let aboveIndex = actions.firstIndex(where: { $0.order == action.order - 1 }) {
            actions[aboveIndex].order += 1
            actions[currentIndex].order -= 1
        }
    }

    private func moveDown(_ action: OutputAction) {
        guard let currentIndex = actions.firstIndex(where: { $0.id == action.id }),
              action.order < actions.count else { return }

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

struct MacOutputActionTypePicker: View {
    let onSelect: (OutputActionType) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Output Action")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(OutputActionType.allCases, id: \.self) { type in
                        Button(action: {
                            dismiss()
                            onSelect(type)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: type.icon)
                                    .font(.title3)
                                    .foregroundStyle(type.color)
                                    .frame(width: 36, height: 36)
                                    .background(type.color.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

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
                            .padding(.vertical, 10)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 400, height: 500)
    }
}

// MARK: - Output Action Config Sheet

struct MacOutputActionConfigSheet: View {
    @Binding var action: OutputAction
    @ObservedObject var settings: MacSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Text("Configure \(action.type.displayName)")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            Form {
                // Label
                Section("Label") {
                    TextField("Action label", text: $action.label)
                }

                // Execution order
                Section("Execution Order") {
                    Stepper(value: $action.order, in: 1...99) {
                        Text("Order: \(action.order)")
                    }
                    Text("Actions run in order (1 first, then 2, etc.)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Type-specific configuration
                Section("Configuration") {
                    typeSpecificConfig
                }

                // Required toggle
                Section("Behavior") {
                    Toggle(isOn: $action.isRequired) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Required")
                            Text("Stop remaining actions if this fails")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 450, height: 500)
    }

    @ViewBuilder
    private var typeSpecificConfig: some View {
        switch action.type {
        case .clipboard:
            Text("Copies the result to the system clipboard")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .insertAtCursor:
            Text("Pastes the result at the current cursor position")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .insertAndSend:
            Text("Inserts the result and presses Enter to send (requires accessibility)")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .obsidianSave:
            obsidianSaveConfig

        case .triggerShortcut:
            TextField("Shortcut name", text: Binding(
                get: { action.shortcutName ?? "" },
                set: { action.shortcutName = $0.isEmpty ? nil : $0 }
            ))
            Text("Must match exactly the name in Shortcuts app")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Wait for Result", isOn: Binding(
                get: { action.waitForResult ?? false },
                set: { action.waitForResult = $0 }
            ))
            Text("Wait for Shortcut to complete before continuing")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .webhook:
            Text("Webhooks configured in iOS app and synced via iCloud")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .notification:
            TextField("Notification Title", text: Binding(
                get: { action.notificationTitle ?? "Power Mode Complete" },
                set: { action.notificationTitle = $0.isEmpty ? nil : $0 }
            ))
            Text("The result will be shown as the notification body")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .textToSpeech:
            TextField("Voice (optional)", text: Binding(
                get: { action.speakVoice ?? "" },
                set: { action.speakVoice = $0.isEmpty ? nil : $0 }
            ))
            Text("Leave empty for default voice")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .shareSheet:
            Text("Opens the share sheet with the result")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .openURL:
            TextField("URL Template", text: Binding(
                get: { action.urlTemplate ?? "" },
                set: { action.urlTemplate = $0.isEmpty ? nil : $0 }
            ))
            Text("Use {{output}} as placeholder for the result")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .chainPowerMode:
            if settings.powerModes.isEmpty {
                Text("No other Power Modes available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Chain to", selection: Binding(
                    get: { action.chainedPowerModeId ?? UUID() },
                    set: { action.chainedPowerModeId = $0 }
                )) {
                    Text("Select Power Mode").tag(UUID())
                    ForEach(settings.powerModes) { mode in
                        Text(mode.name).tag(mode.id)
                    }
                }
                Text("The result from this Power Mode will be the input for the chained mode")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Obsidian Save Config

    @ViewBuilder
    private var obsidianSaveConfig: some View {
        let connectedVaults = settings.obsidianVaults.filter { $0.status == .synced }

        if connectedVaults.isEmpty {
            Text("No Obsidian vaults connected. Connect vaults in Settings → Obsidian.")
                .font(.caption)
                .foregroundStyle(.orange)
        } else {
            Picker("Save Action", selection: Binding(
                get: { action.obsidianSaveAction ?? .appendDaily },
                set: { action.obsidianSaveAction = $0 }
            )) {
                ForEach(ObsidianSaveAction.allCases, id: \.self) { saveAction in
                    Text(saveAction.displayName).tag(saveAction)
                }
            }
            Text((action.obsidianSaveAction ?? .appendDaily).description)
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Target Vault", selection: Binding(
                get: { action.obsidianTargetVaultId ?? connectedVaults.first?.id ?? UUID() },
                set: { action.obsidianTargetVaultId = $0 }
            )) {
                ForEach(connectedVaults) { vault in
                    Text(vault.name).tag(vault.id)
                }
            }

            if action.obsidianSaveAction == .appendNote || action.obsidianSaveAction == .createNote {
                TextField("Note Name", text: Binding(
                    get: { action.obsidianTargetNoteName ?? "" },
                    set: { action.obsidianTargetNoteName = $0.isEmpty ? nil : $0 }
                ))
                Text(action.obsidianSaveAction == .createNote
                     ? "Name for the new note (without .md extension)"
                     : "Name of the note to append to")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Auto-Execute", isOn: Binding(
                get: { action.obsidianAutoExecute ?? false },
                set: { action.obsidianAutoExecute = $0 }
            ))
            Text("Save without confirmation prompt")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - OutputActionType Extensions for macOS

extension OutputActionType {
    var icon: String {
        switch self {
        case .clipboard: return "doc.on.clipboard"
        case .insertAtCursor: return "keyboard"
        case .insertAndSend: return "paperplane.fill"
        case .obsidianSave: return "note.text"
        case .triggerShortcut: return "command.square"
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
        case .chainPowerMode: return .purple
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
            MacOutputActionsEditor(actions: $actions, settings: MacSettings.shared)
                .padding()
                .frame(width: 500)
        }
    }

    return PreviewWrapper()
}
