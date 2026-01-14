//
//  MacInputActionsEditor.swift
//  SwiftSpeakMac
//
//  Phase 17: macOS version of Input Actions editor for Power Modes
//  Matches iOS InputActionsEditor for UI consistency
//

import SwiftUI
import SwiftSpeakCore

// MARK: - Mac Input Actions Editor

struct MacInputActionsEditor: View {
    @Binding var actions: [InputAction]
    @ObservedObject var settings: MacSettings

    @State private var showingAddSheet = false
    @State private var editingAction: InputAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Input Actions")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: { showingAddSheet = true }) {
                    Label("Add", systemImage: "plus")
                        .font(.callout)
                }
                .buttonStyle(.borderless)
            }

            Text("Actions that gather context before Power Mode runs")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if actions.isEmpty {
                emptyState
            } else {
                actionsList
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            MacInputActionTypePicker { actionType in
                let newAction = InputAction(type: actionType, label: actionType.displayName)
                actions.append(newAction)
                editingAction = newAction
            }
        }
        .sheet(item: $editingAction) { action in
            if let index = actions.firstIndex(where: { $0.id == action.id }) {
                MacInputActionConfigSheet(
                    action: $actions[index],
                    settings: settings
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.down.doc")
                .font(.title)
                .foregroundStyle(.tertiary)

            Text("No Input Actions")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text("Add actions to gather context like clipboard, URLs, or Shortcuts output")
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
            ForEach(actions) { action in
                actionRow(action)
            }
        }
    }

    private func actionRow(_ action: InputAction) -> some View {
        HStack(spacing: 12) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)

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

    private func binding(for action: InputAction, keyPath: WritableKeyPath<InputAction, Bool>) -> Binding<Bool> {
        guard let index = actions.firstIndex(where: { $0.id == action.id }) else {
            return .constant(false)
        }
        return Binding(
            get: { actions[index][keyPath: keyPath] },
            set: { actions[index][keyPath: keyPath] = $0 }
        )
    }

    private func deleteAction(_ action: InputAction) {
        actions.removeAll { $0.id == action.id }
    }
}

// MARK: - Input Action Type Picker

struct MacInputActionTypePicker: View {
    let onSelect: (InputActionType) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Input Action")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(InputActionType.allCases, id: \.self) { type in
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
        .frame(width: 400, height: 380)
    }
}

// MARK: - Input Action Config Sheet

struct MacInputActionConfigSheet: View {
    @Binding var action: InputAction
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

                // Type-specific configuration
                Section("Configuration") {
                    typeSpecificConfig
                }

                // Required toggle
                Section("Behavior") {
                    Toggle(isOn: $action.isRequired) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Required")
                            Text("Power Mode fails if this action fails")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 450, height: 400)
    }

    @ViewBuilder
    private var typeSpecificConfig: some View {
        switch action.type {
        case .memory:
            memoryConfig

        case .ragDocuments:
            ragDocumentsConfig

        case .obsidianVaults:
            obsidianVaultsConfig

        case .clipboard:
            Text("Reads the current clipboard content and includes it as context")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .selectedText:
            Text("Reads the currently selected text from the active application")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .urlFetch:
            TextField("URL to fetch", text: Binding(
                get: { action.urlToFetch ?? "" },
                set: { action.urlToFetch = $0.isEmpty ? nil : $0 }
            ))
            Text("The content from this URL will be included as context")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .filePicker:
            Text("File picker allows user to select a file to include as context")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .shortcutResult:
            TextField("Shortcut name", text: Binding(
                get: { action.shortcutName ?? "" },
                set: { action.shortcutName = $0.isEmpty ? nil : $0 }
            ))
            Text("Must match exactly the name in Shortcuts app")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Wait for Result", isOn: Binding(
                get: { action.waitForResult ?? true },
                set: { action.waitForResult = $0 }
            ))
            Text("Include the Shortcut's output as context")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .webhook:
            Text("Webhooks configured in iOS app and synced via iCloud")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .screenContext:
            VStack(alignment: .leading, spacing: 8) {
                Text("Captures visible text from your screen using OCR")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Note: On macOS, window context capture via accessibility is preferred. Screen context is primarily for iOS broadcast extension.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Memory Config

    @ViewBuilder
    private var memoryConfig: some View {
        Toggle("Global Memory", isOn: Binding(
            get: { action.includeGlobalMemory ?? true },
            set: { action.includeGlobalMemory = $0 }
        ))
        Text("AI memory shared across all contexts")
            .font(.caption)
            .foregroundStyle(.secondary)

        Toggle("Context Memory", isOn: Binding(
            get: { action.includeContextMemory ?? true },
            set: { action.includeContextMemory = $0 }
        ))
        Text("Memory specific to the current context")
            .font(.caption)
            .foregroundStyle(.secondary)

        Toggle("Power Mode Memory", isOn: Binding(
            get: { action.includePowerModeMemory ?? true },
            set: { action.includePowerModeMemory = $0 }
        ))
        Text("Memory specific to this Power Mode")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - RAG Documents Config

    @ViewBuilder
    private var ragDocumentsConfig: some View {
        Text("Searches your uploaded knowledge base documents for relevant context")
            .font(.caption)
            .foregroundStyle(.secondary)

        TextField("Search query (optional)", text: Binding(
            get: { action.ragSearchQuery ?? "" },
            set: { action.ragSearchQuery = $0.isEmpty ? nil : $0 }
        ))
        Text("If empty, the user's transcription will be used as the search query")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Obsidian Vaults Config

    @ViewBuilder
    private var obsidianVaultsConfig: some View {
        let connectedVaults = settings.obsidianVaults.filter { $0.status == .synced }

        if connectedVaults.isEmpty {
            Text("No Obsidian vaults connected. Connect vaults in Settings → Obsidian.")
                .font(.caption)
                .foregroundStyle(.orange)
        } else {
            Text("Select vaults to search:")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(connectedVaults) { vault in
                let isSelected = action.obsidianVaultIds?.contains(vault.id) ?? true

                Toggle(vault.name, isOn: Binding(
                    get: { isSelected },
                    set: { newValue in
                        if newValue {
                            if action.obsidianVaultIds == nil {
                                action.obsidianVaultIds = [vault.id]
                            } else {
                                action.obsidianVaultIds?.append(vault.id)
                            }
                        } else {
                            if action.obsidianVaultIds == nil {
                                action.obsidianVaultIds = connectedVaults.map(\.id).filter { $0 != vault.id }
                            } else {
                                action.obsidianVaultIds?.removeAll { $0 == vault.id }
                            }
                        }
                    }
                ))
            }

            Picker("Max Results", selection: Binding(
                get: { action.obsidianMaxResults ?? 5 },
                set: { action.obsidianMaxResults = $0 }
            )) {
                Text("3").tag(3)
                Text("5").tag(5)
                Text("10").tag(10)
                Text("15").tag(15)
            }
        }
    }
}

// MARK: - InputActionType Extensions for macOS

extension InputActionType {
    var icon: String {
        switch self {
        case .memory: return "brain.head.profile"
        case .ragDocuments: return "doc.text.magnifyingglass"
        case .obsidianVaults: return "note.text"
        case .clipboard: return "doc.on.clipboard"
        case .selectedText: return "selection.pin.in.out"
        case .urlFetch: return "globe"
        case .filePicker: return "doc"
        case .shortcutResult: return "command.square"
        case .webhook: return "link"
        case .screenContext: return "text.viewfinder"
        }
    }

    var color: Color {
        switch self {
        case .memory: return .purple
        case .ragDocuments: return .indigo
        case .obsidianVaults: return .purple
        case .clipboard: return .blue
        case .selectedText: return .purple
        case .urlFetch: return .green
        case .filePicker: return .orange
        case .shortcutResult: return .pink
        case .webhook: return .orange
        case .screenContext: return .cyan
        }
    }

    var description: String {
        switch self {
        case .memory:
            return "Include AI memory context"
        case .ragDocuments:
            return "Search knowledge base documents"
        case .obsidianVaults:
            return "Search connected Obsidian notes"
        case .clipboard:
            return "Read current clipboard content"
        case .selectedText:
            return "Read selected text from active app"
        case .urlFetch:
            return "Download and parse webpage content"
        case .filePicker:
            return "Select a file to include as context"
        case .shortcutResult:
            return "Run an Apple Shortcut and use its output"
        case .webhook:
            return "Fetch data from a configured webhook"
        case .screenContext:
            return "Capture text from screen via OCR (iOS)"
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State var actions: [InputAction] = [
            InputAction(type: .clipboard, isEnabled: true, isRequired: false, label: "Clipboard"),
            InputAction(type: .shortcutResult, isEnabled: true, isRequired: true, label: "Get Calendar", shortcutName: "Get Today's Events", waitForResult: true)
        ]

        var body: some View {
            MacInputActionsEditor(actions: $actions, settings: MacSettings.shared)
                .padding()
                .frame(width: 500)
        }
    }

    return PreviewWrapper()
}
