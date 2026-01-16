//
//  QuickActionsEditor.swift
//  SwiftSpeak
//
//  Editor for configuring Autocomplete Suggestions (Quick Actions) on Keyboard
//  Power tier feature - generates AI response suggestions from screen context
//

import SwiftUI
import SwiftSpeakCore

struct QuickActionsEditor: View {
    @Binding var actions: [QuickAction]
    @EnvironmentObject private var settings: SharedSettings

    @State private var showingAddSheet = false
    @State private var editingAction: QuickAction?
    @State private var showingEditSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("AUTOCOMPLETE SUGGESTIONS")
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
                    .foregroundStyle(AppTheme.accent)
                }
            }

            Text("Quick responses generated from screen context")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if actions.isEmpty {
                emptyState
            } else {
                actionsList
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            QuickActionTypePicker { actionType in
                let newAction = QuickAction(type: actionType, order: actions.count)
                actions.append(newAction)
                editingAction = newAction
                showingEditSheet = true
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let action = editingAction, let index = actions.firstIndex(where: { $0.id == action.id }) {
                QuickActionConfigSheet(action: $actions[index]) {
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
                Image(systemName: "text.bubble")
                    .font(.title2)
                    .foregroundStyle(.tertiary)

                Text("No Autocomplete Suggestions")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text("Add suggestions like positive, neutral, or custom responses")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                Button(action: {
                    HapticManager.selection()
                    showingAddSheet = true
                }) {
                    Text("Add Suggestion")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent)
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
            ForEach(actions.sorted { $0.order < $1.order }) { action in
                actionRow(action)
            }
        }
    }

    private func actionRow(_ action: QuickAction) -> some View {
        HStack(spacing: 12) {
            // Drag handle placeholder
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Action icon
            Image(systemName: action.type.icon)
                .font(.body)
                .foregroundStyle(action.isEnabled ? colorForType(action.type) : .secondary)
                .frame(width: 28)

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
                .tint(colorForType(action.type))

            // Delete button
            Button(action: {
                HapticManager.selection()
                deleteAction(action)
            }) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(action.isEnabled ? colorForType(action.type).opacity(0.1) : Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
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

struct QuickActionTypePicker: View {
    let onSelect: (QuickActionType) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(QuickActionType.allCases, id: \.self) { type in
                        Button(action: {
                            HapticManager.selection()
                            dismiss()
                            onSelect(type)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: type.icon)
                                    .font(.title3)
                                    .foregroundStyle(colorForType(type))
                                    .frame(width: 40, height: 40)
                                    .background(colorForType(type).opacity(0.15))
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
            .navigationTitle("Add Suggestion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
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

struct QuickActionConfigSheet: View {
    @Binding var action: QuickAction
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Label
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Label")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField("Display name", text: $action.label)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

                        Text("Short name shown in the suggestion chip")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    // Prompt
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prompt")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextEditor(text: $action.prompt)
                            .frame(minHeight: 100)
                            .font(.body)
                            .padding(8)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

                        Text("Instructions for generating this suggestion. Leave empty to use default.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        if action.prompt.isEmpty {
                            Text("Default: \(action.type.defaultPrompt)")
                                .font(.caption2)
                                .foregroundStyle(.quaternary)
                                .italic()
                        }
                    }

                    // Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Image(systemName: action.type.icon)
                                .foregroundStyle(colorForType(action.type))
                            Text(action.label)
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(10)
                        .background(colorForType(action.type).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                    }
                }
                .padding(16)
            }
            .background(AppTheme.darkBase.ignoresSafeArea())
            .navigationTitle("Configure \(action.type.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
            ScrollView {
                QuickActionsEditor(actions: $actions)
                    .padding()
            }
            .background(AppTheme.darkBase)
            .environmentObject(SharedSettings.shared)
        }
    }

    return PreviewWrapper()
        .preferredColorScheme(.dark)
}
