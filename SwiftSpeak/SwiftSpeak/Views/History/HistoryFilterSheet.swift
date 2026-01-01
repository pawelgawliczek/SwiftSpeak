//
//  HistoryFilterSheet.swift
//  SwiftSpeak
//
//  Filter history by Power Mode and Context
//

import SwiftUI

struct HistoryFilterSheet: View {
    @Binding var selectedPowerModeId: UUID?
    @Binding var selectedContextId: UUID?
    @Binding var selectedSource: TranscriptionSource?
    let powerModes: [PowerMode]
    let contexts: [ConversationContext]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Power Mode Section
                Section {
                    Button(action: {
                        HapticManager.selection()
                        selectedPowerModeId = nil
                    }) {
                        HStack {
                            Text("All Power Modes")
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedPowerModeId == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }

                    ForEach(powerModes.filter { !$0.isArchived }) { mode in
                        Button(action: {
                            HapticManager.selection()
                            selectedPowerModeId = mode.id
                        }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(mode.iconBackgroundColor.gradient.opacity(0.2))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: mode.icon)
                                        .font(.caption)
                                        .foregroundStyle(mode.iconColor.gradient)
                                }

                                Text(mode.name)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if selectedPowerModeId == mode.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                        }
                    }
                } header: {
                    Label("Power Mode", systemImage: "bolt.fill")
                }

                // Context Section
                Section {
                    Button(action: {
                        HapticManager.selection()
                        selectedContextId = nil
                    }) {
                        HStack {
                            Text("All Contexts")
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedContextId == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }

                    ForEach(contexts) { context in
                        Button(action: {
                            HapticManager.selection()
                            selectedContextId = context.id
                        }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(context.color.gradient.opacity(0.2))
                                        .frame(width: 32, height: 32)
                                    Text(context.icon)
                                        .font(.caption)
                                }

                                Text(context.name)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if selectedContextId == context.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                        }
                    }
                } header: {
                    Label("Context", systemImage: "person.circle")
                }

                // Source Section (Phase 13.11 - Keyboard AI tracking)
                Section {
                    Button(action: {
                        HapticManager.selection()
                        selectedSource = nil
                    }) {
                        HStack {
                            Text("All Sources")
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedSource == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }

                    ForEach([TranscriptionSource.app, .swiftLink, .keyboardAI, .edit], id: \.rawValue) { source in
                        Button(action: {
                            HapticManager.selection()
                            selectedSource = source
                        }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(sourceColor(source).gradient.opacity(0.2))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: source.icon)
                                        .font(.caption)
                                        .foregroundStyle(sourceColor(source).gradient)
                                }

                                Text(source.displayName)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if selectedSource == source {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                        }
                    }
                } header: {
                    Label("Source", systemImage: "arrow.triangle.branch")
                }

                // Clear Filters Section
                if selectedPowerModeId != nil || selectedContextId != nil || selectedSource != nil {
                    Section {
                        Button(action: {
                            HapticManager.lightTap()
                            selectedPowerModeId = nil
                            selectedContextId = nil
                            selectedSource = nil
                        }) {
                            HStack {
                                Spacer()
                                Text("Clear All Filters")
                                    .foregroundStyle(.red)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func sourceColor(_ source: TranscriptionSource) -> Color {
        switch source {
        case .app: return AppTheme.accent
        case .swiftLink: return .orange
        case .keyboardAI: return AppTheme.powerAccent
        case .edit: return .green
        }
    }
}

// MARK: - Preview

#Preview {
    HistoryFilterSheet(
        selectedPowerModeId: .constant(nil),
        selectedContextId: .constant(nil),
        selectedSource: .constant(nil),
        powerModes: PowerMode.presets,
        contexts: ConversationContext.samples
    )
}
