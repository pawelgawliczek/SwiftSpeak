//
//  MacQuickActionsEditor.swift
//  SwiftSpeakMac
//
//  Autocomplete Suggestions editor for Power Modes
//  Similar to MacInputActionsEditor for UI consistency
//

import SwiftUI
import SwiftSpeakCore

// MARK: - Mac Quick Actions Editor

struct MacQuickActionsEditor: View {
    @Binding var actions: [QuickAction]
    @ObservedObject var settings: MacSettings

    @State private var showingAddSheet = false
    @State private var editingAction: QuickAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Autocomplete Suggestions")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: { showingAddSheet = true }) {
                    Label("Add", systemImage: "plus")
                        .font(.callout)
                }
                .buttonStyle(.borderless)
            }

            Text("Quick responses generated from screen context when Power Mode runs")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if actions.isEmpty {
                emptyState
            } else {
                actionsList
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            MacQuickActionTypePicker { actionType in
                let newAction = QuickAction(type: actionType, order: actions.count)
                actions.append(newAction)
                editingAction = newAction
            }
        }
        .sheet(item: $editingAction) { action in
            if let index = actions.firstIndex(where: { $0.id == action.id }) {
                MacQuickActionConfigSheet(action: $actions[index])
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.title)
                .foregroundStyle(.tertiary)

            Text("No Autocomplete Suggestions")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text("Add suggestions like positive, neutral, or custom responses")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button("Add Suggestion") {
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
            ForEach(actions.sorted { $0.order < $1.order }) { action in
                actionRow(action)
            }
        }
    }

    private func actionRow(_ action: QuickAction) -> some View {
        HStack(spacing: 12) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Action icon
            Image(systemName: action.type.icon)
                .font(.body)
                .foregroundStyle(action.isEnabled ? colorForType(action.type) : .secondary)
                .frame(width: 24)

            // Action info
            VStack(alignment: .leading, spacing: 2) {
                Text(action.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(action.isEnabled ? .primary : .secondary)

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
                .tint(colorForType(action.type))

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
        .background(action.isEnabled ? colorForType(action.type).opacity(0.1) : Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helpers

    private func colorForType(_ type: QuickActionType) -> Color {
        switch type.color {
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "blue": return .blue
        case "purple": return .purple
        default: return .gray
        }
    }

    private func binding(for action: QuickAction, keyPath: WritableKeyPath<QuickAction, Bool>) -> Binding<Bool> {
        guard let index = actions.firstIndex(where: { $0.id == action.id }) else {
            return .constant(false)
        }
        return Binding(
            get: { actions[index][keyPath: keyPath] },
            set: { actions[index][keyPath: keyPath] = $0 }
        )
    }

    private func deleteAction(_ action: QuickAction) {
        actions.removeAll { $0.id == action.id }
    }
}

// MARK: - Quick Action Type Picker

struct MacQuickActionTypePicker: View {
    let onSelect: (QuickActionType) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Autocomplete Suggestion")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(QuickActionType.allCases, id: \.self) { type in
                        Button(action: {
                            dismiss()
                            onSelect(type)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: type.icon)
                                    .font(.title3)
                                    .foregroundStyle(colorForType(type))
                                    .frame(width: 36, height: 36)
                                    .background(colorForType(type).opacity(0.15))
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

    private func colorForType(_ type: QuickActionType) -> Color {
        switch type.color {
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "blue": return .blue
        case "purple": return .purple
        default: return .gray
        }
    }
}

// MARK: - Quick Action Config Sheet

struct MacQuickActionConfigSheet: View {
    @Binding var action: QuickAction
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
                    TextField("Display name", text: $action.label)
                    Text("Short name shown in the suggestion chip")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Custom Prompt
                Section("Prompt") {
                    TextEditor(text: $action.prompt)
                        .frame(minHeight: 100)
                        .font(.body)

                    Text("Instructions for generating this suggestion. Leave empty to use default.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if action.prompt.isEmpty {
                        Text("Default: \(action.type.defaultPrompt)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .italic()
                    }
                }

                // Preview
                Section("Preview") {
                    HStack(spacing: 8) {
                        Image(systemName: action.type.icon)
                            .foregroundStyle(colorForType(action.type))
                        Text(action.label)
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(8)
                    .background(colorForType(action.type).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 450, height: 450)
    }

    private func colorForType(_ type: QuickActionType) -> Color {
        switch type.color {
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "blue": return .blue
        case "purple": return .purple
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State var actions: [QuickAction] = [
            .positive(order: 0),
            .neutral(order: 1),
            .negative(order: 2)
        ]

        var body: some View {
            MacQuickActionsEditor(actions: $actions, settings: MacSettings.shared)
                .padding()
                .frame(width: 500)
        }
    }

    return PreviewWrapper()
}
