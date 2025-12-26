//
//  PowerModeListView.swift
//  SwiftSpeak
//
//  Main hub for managing and launching Power Modes
//

import SwiftUI

struct PowerModeListView: View {
    @State private var powerModes: [PowerMode] = PowerMode.presets
    @State private var showingEditor = false
    @State private var editingMode: PowerMode?
    @State private var selectedModeForExecution: PowerMode?
    @State private var showingDeleteConfirmation = false
    @State private var modeToDelete: PowerMode?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header section
                    headerSection

                    // Power modes list
                    LazyVStack(spacing: 12) {
                        ForEach(powerModes) { mode in
                            PowerModeCard(
                                powerMode: mode,
                                onTap: { selectedModeForExecution = mode },
                                onEdit: { editingMode = mode },
                                onDelete: {
                                    modeToDelete = mode
                                    showingDeleteConfirmation = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)

                    // Create new button
                    createNewButton
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                }
            }
            .background(AppTheme.darkBase.ignoresSafeArea())
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: { showingEditor = true }) {
                            Image(systemName: "plus")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppTheme.powerAccent)
                        }

                        NavigationLink(destination: Text("Settings")) {
                            Image(systemName: "gearshape")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                PowerModeEditorView(
                    powerMode: nil,
                    onSave: { newMode in
                        powerModes.append(newMode)
                    }
                )
            }
            .sheet(item: $editingMode) { mode in
                PowerModeEditorView(
                    powerMode: mode,
                    onSave: { updatedMode in
                        if let index = powerModes.firstIndex(where: { $0.id == updatedMode.id }) {
                            powerModes[index] = updatedMode
                        }
                    }
                )
            }
            .fullScreenCover(item: $selectedModeForExecution) { mode in
                PowerModeExecutionView(
                    powerMode: mode,
                    onDismiss: { selectedModeForExecution = nil }
                )
            }
            .alert("Delete Power Mode?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    modeToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let mode = modeToDelete {
                        withAnimation(AppTheme.smoothSpring) {
                            powerModes.removeAll { $0.id == mode.id }
                        }
                    }
                    modeToDelete = nil
                }
            } message: {
                if let mode = modeToDelete {
                    Text("Are you sure you want to delete \"\(mode.name)\"? This action cannot be undone.")
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.powerGradient)

                Text("Power Modes")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.primary)
            }

            Text("Create AI-powered voice workflows")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Create New Button

    private var createNewButton: some View {
        Button(action: { showingEditor = true }) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                Text("Create New Mode")
                    .font(.callout.weight(.semibold))
            }
            .foregroundStyle(AppTheme.powerAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(AppTheme.powerAccent.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
    }
}

// MARK: - Power Mode Card

struct PowerModeCard: View {
    let powerMode: PowerMode
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticManager.mediumTap()
            onTap()
        }) {
            HStack(spacing: 14) {
                // Icon
                Image(systemName: powerMode.icon)
                    .font(.title2)
                    .foregroundStyle(AppTheme.powerGradient)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.powerAccent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(powerMode.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Capabilities
                    if !powerMode.enabledCapabilities.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(Array(powerMode.enabledCapabilities), id: \.self) { capability in
                                Text(capability.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .lineLimit(1)
                        }
                    } else {
                        Text("No capabilities")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // Usage count
                    Text("Used \(powerMode.usageCount) times")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Play button indicator
                Image(systemName: "play.fill")
                    .font(.body)
                    .foregroundStyle(AppTheme.powerAccent)
            }
            .padding(14)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(AppTheme.quickSpring, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }

            Button(action: {
                // Duplicate action
                HapticManager.selection()
            }) {
                Label("Duplicate", systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PowerModeListView()
        .preferredColorScheme(.dark)
}
