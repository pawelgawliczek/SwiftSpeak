//
//  PowerModeListView.swift
//  SwiftSpeak
//
//  Main hub for managing and launching Power Modes
//  Refactored for Phase 4: Uses SharedSettings and SwipeablePowerModeCard
//

import SwiftUI

// MARK: - Power Mode List View (Standalone wrapper)

struct PowerModeListView: View {
    var body: some View {
        NavigationStack {
            PowerModeListContent()
                .navigationTitle("Power Modes")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Power Mode List Content (Embeddable in PowerTabView)

struct PowerModeListContent: View {
    @EnvironmentObject var settings: SharedSettings

    @State private var showingEditor = false
    @State private var editingMode: PowerMode?
    @State private var selectedModeForExecution: PowerMode?
    @State private var showingDeleteConfirmation = false
    @State private var modeToDelete: PowerMode?
    @State private var showingArchived = false
    @State private var navigateToHistory: PowerMode?
    @State private var navigateToDetail: PowerMode?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header section
                headerSection

                // Active power modes list
                if settings.activePowerModes.isEmpty && settings.archivedPowerModes.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(settings.activePowerModes) { mode in
                            SwipeablePowerModeCard(
                                powerMode: mode,
                                onTap: {
                                    HapticManager.lightTap()
                                    navigateToDetail = mode
                                },
                                onEdit: { editingMode = mode },
                                onRun: {
                                    HapticManager.mediumTap()
                                    selectedModeForExecution = mode
                                },
                                onArchive: {
                                    settings.archivePowerMode(id: mode.id)
                                },
                                onDelete: {
                                    modeToDelete = mode
                                    showingDeleteConfirmation = true
                                },
                                onShowHistory: {
                                    navigateToHistory = mode
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)

                    // Archived section
                    if !settings.archivedPowerModes.isEmpty {
                        archivedSection
                    }
                }

                // Create new button
                createNewButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
            }
        }
        .background(AppTheme.darkBase.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingEditor = true }) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.powerAccent)
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            PowerModeEditorView(
                powerMode: nil,
                onSave: { newMode in
                    settings.addPowerMode(newMode)
                }
            )
        }
        .sheet(item: $editingMode) { mode in
            PowerModeEditorView(
                powerMode: mode,
                onSave: { updatedMode in
                    settings.updatePowerMode(updatedMode)
                }
            )
        }
        .fullScreenCover(item: $selectedModeForExecution) { mode in
            PowerModeExecutionView(
                powerMode: mode,
                onDismiss: { selectedModeForExecution = nil }
            )
        }
        .navigationDestination(item: $navigateToHistory) { mode in
            HistoryView(filterPowerModeId: mode.id, showFilterBar: false)
                .navigationTitle("\(mode.name) History")
        }
        .navigationDestination(item: $navigateToDetail) { mode in
            PowerModeDetailView(
                powerMode: mode,
                onRun: {
                    navigateToDetail = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedModeForExecution = mode
                    }
                },
                onEdit: {
                    navigateToDetail = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        editingMode = mode
                    }
                }
            )
        }
        .alert("Delete Power Mode?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                modeToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let mode = modeToDelete {
                    withAnimation(AppTheme.smoothSpring) {
                        settings.deletePowerMode(id: mode.id)
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

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI-powered voice workflows")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.circle")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.powerGradient)

            Text("No Power Modes")
                .font(.headline)

            Text("Create your first AI-powered voice workflow")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    // MARK: - Archived Section

    private var archivedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation {
                    showingArchived.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "archivebox.fill")
                        .font(.caption)
                    Text("Archived (\(settings.archivedPowerModes.count))")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Image(systemName: showingArchived ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
            }

            if showingArchived {
                LazyVStack(spacing: 12) {
                    ForEach(settings.archivedPowerModes) { mode in
                        SwipeablePowerModeCard(
                            powerMode: mode,
                            onTap: {
                                HapticManager.lightTap()
                                navigateToDetail = mode
                            },
                            onEdit: { editingMode = mode },
                            onRun: {
                                HapticManager.mediumTap()
                                selectedModeForExecution = mode
                            },
                            onArchive: {
                                settings.unarchivePowerMode(id: mode.id)
                            },
                            onDelete: {
                                modeToDelete = mode
                                showingDeleteConfirmation = true
                            },
                            onShowHistory: {
                                navigateToHistory = mode
                            }
                        )
                        .opacity(0.7)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
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

// MARK: - Preview

#Preview {
    PowerModeListView()
        .environmentObject(SharedSettings.shared)
        .preferredColorScheme(.dark)
}
