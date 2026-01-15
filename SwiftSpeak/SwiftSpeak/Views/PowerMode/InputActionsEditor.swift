//
//  InputActionsEditor.swift
//  SwiftSpeak
//
//  Phase 17: Editor for configuring Input Actions on Power Modes
//  Allows adding, removing, and configuring actions that gather context before Power Mode execution
//

import SwiftUI
import SwiftSpeakCore

struct InputActionsEditor: View {
    @Binding var actions: [InputAction]
    @EnvironmentObject private var settings: SharedSettings

    @State private var showingAddSheet = false
    @State private var editingAction: InputAction?
    @State private var showingEditSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("INPUT ACTIONS")
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
            InputActionTypePicker { actionType in
                let newAction = InputAction(type: actionType, label: actionType.displayName)
                actions.append(newAction)
                editingAction = newAction
                showingEditSheet = true
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let action = editingAction, let index = actions.firstIndex(where: { $0.id == action.id }) {
                InputActionConfigSheet(action: $actions[index]) {
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
                Image(systemName: "arrow.down.doc")
                    .font(.title2)
                    .foregroundStyle(.tertiary)

                Text("No Input Actions")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text("Add actions to gather context like clipboard, URLs, or Shortcuts output")
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
            ForEach(actions) { action in
                actionRow(action)
            }
            .onDelete(perform: deleteActions)
        }
    }

    private func actionRow(_ action: InputAction) -> some View {
        HStack(spacing: 12) {
            // Drag handle placeholder (visual only for now)
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)

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

    private func deleteActions(at offsets: IndexSet) {
        actions.remove(atOffsets: offsets)
    }
}

// MARK: - Input Action Type Picker

struct InputActionTypePicker: View {
    let onSelect: (InputActionType) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(InputActionType.allCases, id: \.self) { type in
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
            .navigationTitle("Add Input Action")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Input Action Config Sheet

struct InputActionConfigSheet: View {
    @Binding var action: InputAction
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

                            Text("Power Mode fails if this action fails")
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
        case .memory:
            memoryConfig

        case .ragDocuments:
            ragDocumentsConfig

        case .obsidianVaults:
            obsidianVaultsConfig

        case .clipboard:
            // No additional config needed
            infoBox(text: "Reads the current clipboard content and includes it as context")

        case .selectedText:
            // macOS only
            infoBox(text: "Reads the currently selected text (macOS only)")

        case .urlFetch:
            urlFetchConfig

        case .filePicker:
            filePickerConfig

        case .shortcutResult:
            shortcutConfig

        case .webhook:
            webhookConfig

        case .screenContext:
            screenContextConfig

        case .shareAudioImport:
            infoBox(text: "Marks this Power Mode as available for shared audio import from other apps")
        }
    }

    // MARK: - Memory Config

    private var memoryConfig: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Memory Sources")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                memoryToggle(
                    label: "Global Memory",
                    description: "AI memory shared across all contexts",
                    icon: "globe",
                    isOn: Binding(
                        get: { action.includeGlobalMemory ?? true },
                        set: { action.includeGlobalMemory = $0 }
                    )
                )

                memoryToggle(
                    label: "Context Memory",
                    description: "Memory specific to the current context",
                    icon: "rectangle.stack",
                    isOn: Binding(
                        get: { action.includeContextMemory ?? true },
                        set: { action.includeContextMemory = $0 }
                    )
                )

                memoryToggle(
                    label: "Power Mode Memory",
                    description: "Memory specific to this Power Mode",
                    icon: "bolt.fill",
                    isOn: Binding(
                        get: { action.includePowerModeMemory ?? true },
                        set: { action.includePowerModeMemory = $0 }
                    )
                )
            }

            Text("Selected memories will be included as context for the AI")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func memoryToggle(label: String, description: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isOn.wrappedValue ? .purple : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.purple)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isOn.wrappedValue ? Color.purple.opacity(0.1) : Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
    }

    // MARK: - RAG Documents Config

    private var ragDocumentsConfig: some View {
        VStack(alignment: .leading, spacing: 12) {
            infoBox(text: "Searches your uploaded knowledge base documents for relevant context")

            VStack(alignment: .leading, spacing: 8) {
                Text("Search Query (Optional)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("Leave empty to use transcription", text: Binding(
                    get: { action.ragSearchQuery ?? "" },
                    set: { action.ragSearchQuery = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

                Text("If empty, the user's transcription will be used as the search query")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Obsidian Vaults Config

    private var obsidianVaultsConfig: some View {
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
                Text("Search Vaults")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(connectedVaults) { vault in
                    let isSelected = action.obsidianVaultIds?.contains(vault.id) ?? true

                    Button(action: {
                        HapticManager.selection()
                        if isSelected {
                            if action.obsidianVaultIds == nil {
                                action.obsidianVaultIds = connectedVaults.map(\.id).filter { $0 != vault.id }
                            } else {
                                action.obsidianVaultIds?.removeAll { $0 == vault.id }
                            }
                        } else {
                            if action.obsidianVaultIds == nil {
                                action.obsidianVaultIds = [vault.id]
                            } else {
                                action.obsidianVaultIds?.append(vault.id)
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "folder.fill")
                                .font(.body)
                                .foregroundStyle(isSelected ? .purple : .secondary)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(vault.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)

                                Text("\(vault.noteCount) notes indexed")
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

                // Search settings
                VStack(alignment: .leading, spacing: 8) {
                    Text("Search Settings")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)

                    HStack {
                        Text("Max Results")
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        Spacer()

                        Picker("", selection: Binding(
                            get: { action.obsidianMaxResults ?? 5 },
                            set: { action.obsidianMaxResults = $0 }
                        )) {
                            Text("3").tag(3)
                            Text("5").tag(5)
                            Text("10").tag(10)
                            Text("15").tag(15)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                }
            }
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

    private var urlFetchConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("URL to Fetch")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("https://example.com/api/data", text: Binding(
                get: { action.urlToFetch ?? "" },
                set: { action.urlToFetch = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.plain)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            Text("The content from this URL will be included as context")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var filePickerConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Allowed File Types")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Select the types of files the user can pick")
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Show common file type toggles
            VStack(spacing: 6) {
                fileTypeToggle(label: "Text files", utType: "public.plain-text")
                fileTypeToggle(label: "PDF documents", utType: "com.adobe.pdf")
                fileTypeToggle(label: "Markdown", utType: "net.daringfireball.markdown")
            }
        }
    }

    private func fileTypeToggle(label: String, utType: String) -> some View {
        let isEnabled = action.fileTypes?.contains(utType) ?? false

        return Button(action: {
            HapticManager.selection()
            if isEnabled {
                action.fileTypes?.removeAll { $0 == utType }
            } else {
                if action.fileTypes == nil {
                    action.fileTypes = []
                }
                action.fileTypes?.append(utType)
            }
        }) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isEnabled ? .green : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        }
        .buttonStyle(.plain)
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

                    Text("Include the Shortcut's output as context")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { action.waitForResult ?? true },
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

            let contextSourceWebhooks = settings.webhooks.filter { $0.type == .contextSource }

            if contextSourceWebhooks.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("No context source webhooks")
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
                ForEach(contextSourceWebhooks) { webhook in
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

            Text("Only webhooks of type \"Context Source\" are shown")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Screen Context Config

    private var screenContextConfig: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Info box
            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.cyan)
                Text("Captures visible text from your screen using OCR when Power Mode starts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cyan.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            // Requirements
            VStack(alignment: .leading, spacing: 8) {
                Text("Requirements")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    requirementRow(
                        icon: "record.circle",
                        text: "Screen recording must be active",
                        isWarning: false
                    )

                    requirementRow(
                        icon: "text.viewfinder",
                        text: "Context Capture enabled in Settings",
                        isWarning: false
                    )
                }
            }

            // How it works
            VStack(alignment: .leading, spacing: 8) {
                Text("How It Works")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Start screen recording via SwiftLink")
                    Text("2. When Power Mode runs, OCR extracts visible text")
                    Text("3. Text is included as context for AI processing")
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
    }

    private func requirementRow(icon: String, text: String, isWarning: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(isWarning ? .orange : .cyan)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - InputActionType Extensions

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
        case .shortcutResult: return "apps.iphone"
        case .webhook: return "link"
        case .screenContext: return "text.viewfinder"
        case .shareAudioImport: return "waveform.badge.plus"
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
        case .shareAudioImport: return .teal
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
            return "Read selected text (macOS only)"
        case .urlFetch:
            return "Download and parse webpage content"
        case .filePicker:
            return "Select a file to include as context"
        case .shortcutResult:
            return "Run an Apple Shortcut and use its output"
        case .webhook:
            return "Fetch data from a configured webhook"
        case .screenContext:
            return "Capture text from your screen via OCR"
        case .shareAudioImport:
            return "Accept audio files shared from other apps"
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
            ScrollView {
                InputActionsEditor(actions: $actions)
                    .padding()
            }
            .background(AppTheme.darkBase)
            .environmentObject(SharedSettings.shared)
        }
    }

    return PreviewWrapper()
        .preferredColorScheme(.dark)
}
