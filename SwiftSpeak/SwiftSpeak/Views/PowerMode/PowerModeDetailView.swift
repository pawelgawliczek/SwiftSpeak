//
//  PowerModeDetailView.swift
//  SwiftSpeak
//
//  Detail view for a Power Mode showing definition, history, and edit option
//

import SwiftUI

struct PowerModeDetailView: View {
    let powerMode: PowerMode
    let onRun: () -> Void
    let onEdit: () -> Void

    @EnvironmentObject var settings: SharedSettings

    // Memory editing state
    @State private var showingMemoryEditor = false
    @State private var editingMemoryContent = ""

    // Get the current power mode from settings (for live updates)
    private var currentPowerMode: PowerMode {
        settings.powerModes.first { $0.id == powerMode.id } ?? powerMode
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with icon
                headerSection

                // Action buttons
                actionButtons

                // Definition section
                definitionSection

                // History section
                historySection

                // Memory section (if enabled)
                if currentPowerMode.memoryEnabled {
                    memorySection
                }

                // Stats section
                statsSection
            }
            .padding(16)
        }
        .background(AppTheme.darkBase.ignoresSafeArea())
        .navigationTitle(powerMode.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onEdit) {
                    Text("Edit")
                        .fontWeight(.medium)
                }
            }
        }
        .sheet(isPresented: $showingMemoryEditor) {
            MemoryEditorSheet(
                title: "\(powerMode.name) - Workflow Memory",
                content: $editingMemoryContent,
                lastUpdated: currentPowerMode.lastMemoryUpdate,
                onSave: {
                    settings.updatePowerModeMemory(id: powerMode.id, memory: editingMemoryContent)
                },
                onClear: {
                    settings.updatePowerModeMemory(id: powerMode.id, memory: "")
                }
            )
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(powerMode.iconBackgroundColor.gradient.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: powerMode.icon)
                    .font(.system(size: 36))
                    .foregroundStyle(powerMode.iconColor.gradient)
            }

            if !powerMode.outputFormat.isEmpty {
                Text(powerMode.outputFormat)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Run button (primary action)
            Button(action: onRun) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.body.weight(.semibold))
                    Text("Run Mode")
                        .font(.callout.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(powerMode.iconColor.gradient)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            }

            // Edit button
            Button(action: onEdit) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .font(.body.weight(.semibold))
                    Text("Edit")
                        .font(.callout.weight(.semibold))
                }
                .foregroundStyle(.primary)
                .frame(width: 100)
                .frame(height: 50)
                .background(Color.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            }
        }
    }

    // MARK: - Definition Section

    private var definitionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DEFINITION")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(powerMode.instruction)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("HISTORY")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                NavigationLink(destination: HistoryView(filterPowerModeId: powerMode.id, showFilterBar: false)
                    .navigationTitle("\(powerMode.name) History")) {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.caption.weight(.medium))
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.powerAccent)
                }
            }

            let recentHistory = settings.transcriptionHistory(forPowerModeId: powerMode.id).prefix(3)

            if recentHistory.isEmpty {
                HStack {
                    Text("No history yet")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(recentHistory)) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.text)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Text(record.timestamp.formatted(.relative(presentation: .named)))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: - Memory Section

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("WORKFLOW MEMORY")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                // Edit button (always visible when memory section is shown)
                Button(action: {
                    HapticManager.lightTap()
                    editingMemoryContent = currentPowerMode.memory ?? ""
                    showingMemoryEditor = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.caption2)
                        Text("Edit")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(AppTheme.accent)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "brain")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    Text("Memory Enabled")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.purple)
                }

                if let memory = currentPowerMode.memory, !memory.isEmpty {
                    Text(memory)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(4)

                    HStack {
                        if let lastUpdate = currentPowerMode.lastMemoryUpdate {
                            Text("Updated \(lastUpdate.formatted(.relative(presentation: .named)))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        // Clear button
                        Button(action: {
                            HapticManager.warning()
                            settings.updatePowerModeMemory(id: powerMode.id, memory: "")
                        }) {
                            Text("Clear")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                    }
                } else {
                    Text("No memory stored yet. Memories are automatically created after using this Power Mode.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.purple.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STATS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                StatCard(title: "Uses", value: "\(powerMode.usageCount)", icon: "clock.arrow.circlepath")
                StatCard(title: "Created", value: powerMode.createdAt.formatted(date: .abbreviated, time: .omitted), icon: "calendar")
            }
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PowerModeDetailView(
            powerMode: PowerMode.presets[0],
            onRun: {},
            onEdit: {}
        )
        .environmentObject(SharedSettings.shared)
    }
    .preferredColorScheme(.dark)
}
