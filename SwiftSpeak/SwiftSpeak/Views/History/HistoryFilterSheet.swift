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

                // Clear Filters Section
                if selectedPowerModeId != nil || selectedContextId != nil {
                    Section {
                        Button(action: {
                            HapticManager.lightTap()
                            selectedPowerModeId = nil
                            selectedContextId = nil
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
}

// MARK: - Preview

#Preview {
    HistoryFilterSheet(
        selectedPowerModeId: .constant(nil),
        selectedContextId: .constant(nil),
        powerModes: PowerMode.presets,
        contexts: ConversationContext.samples
    )
}
