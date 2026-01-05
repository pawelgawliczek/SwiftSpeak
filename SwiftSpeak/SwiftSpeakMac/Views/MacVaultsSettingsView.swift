//
//  MacVaultsSettingsView.swift
//  SwiftSpeakMac
//
//  macOS view for managing Obsidian vaults
//  Allows adding vaults, viewing indexing status, and managing vault settings
//

import SwiftUI
import SwiftSpeakCore
import Combine
import os.log

private let logger = Logger(subsystem: "SwiftSpeakMac", category: "Vaults")

// MARK: - Vaults Settings View

struct MacVaultsSettingsView: View {
    @ObservedObject var settings: MacSettings
    @StateObject private var vaultManager = ObsidianVaultManager.shared
    @StateObject private var fileWatcher = MacFileWatcher()

    @State private var showingAddVault = false
    @State private var editingVault: ObsidianVault?
    @State private var expandedVaultId: UUID?
    @State private var showingDeleteConfirmation = false
    @State private var vaultToDelete: ObsidianVault?

    // Sync status
    @State private var showingSyncAlert = false
    @State private var syncAlertTitle = ""
    @State private var syncAlertMessage = ""
    @State private var isSyncing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Obsidian Vaults")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Index your Obsidian vaults for voice queries and note creation")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: { showingAddVault = true }) {
                        Label("Add Vault", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.bottom, 8)

                // Vaults List
                if vaultManager.vaults.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(vaultManager.vaults) { vault in
                            VaultCard(
                                vault: vault,
                                isExpanded: expandedVaultId == vault.id,
                                hasChanges: fileWatcher.vaultsWithChanges.contains(vault.id),
                                changedPathsCount: fileWatcher.changedNotePaths[vault.id]?.count ?? 0,
                                onTap: { toggleExpanded(vault.id) },
                                onRefresh: { refreshVault(vault) },
                                onSyncToCloud: { syncVaultToCloud(vault) },
                                onEdit: { editingVault = vault },
                                onDelete: {
                                    vaultToDelete = vault
                                    showingDeleteConfirmation = true
                                }
                            )
                        }
                    }
                }
            }
            .padding(24)
        }
        .onAppear {
            // Start watching all vaults with auto-refresh enabled
            for vault in vaultManager.vaults where vault.autoRefreshEnabled {
                fileWatcher.startWatching(vault: vault)
            }
        }
        .onDisappear {
            // Stop all watchers when view disappears
            fileWatcher.stopAll()
        }
        .sheet(isPresented: $showingAddVault) {
            MacAddVaultSheet(
                onAdd: { vault in
                    vaultManager.addVault(vault)
                    showingAddVault = false
                },
                onCancel: { showingAddVault = false }
            )
        }
        .sheet(item: $editingVault) { vault in
            MacAddVaultSheet(
                vault: vault,
                onAdd: { updatedVault in
                    vaultManager.updateVault(updatedVault)
                    editingVault = nil
                },
                onCancel: { editingVault = nil }
            )
        }
        .alert("Delete Vault?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                vaultToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let vault = vaultToDelete {
                    vaultManager.deleteVault(vault.id)
                    if expandedVaultId == vault.id {
                        expandedVaultId = nil
                    }
                }
                vaultToDelete = nil
            }
        } message: {
            if let vault = vaultToDelete {
                Text("Are you sure you want to delete \"\(vault.name)\"? All indexed data will be removed. This action cannot be undone.")
            }
        }
        .alert(syncAlertTitle, isPresented: $showingSyncAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(syncAlertMessage)
        }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                Image("ObsidianIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .opacity(0.5)
                Text("No Obsidian Vaults")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Add your first vault to start querying your notes with voice")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                Button("Add Vault") {
                    showingAddVault = true
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: 400)
            .padding(.vertical, 40)
            Spacer()
        }
        .background(Color.primary.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func toggleExpanded(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedVaultId == id {
                expandedVaultId = nil
            } else {
                expandedVaultId = id
            }
        }
    }

    private func refreshVault(_ vault: ObsidianVault) {
        Task {
            await vaultManager.refreshVault(vault.id)
            // Clear change detection after refresh
            fileWatcher.clearChanges(for: vault.id)

            // Auto-sync to iCloud after successful indexing
            if let updatedVault = vaultManager.vaults.first(where: { $0.id == vault.id }),
               updatedVault.status == .synced {
                await syncVaultToCloudInternal(updatedVault, showAlert: true)
            }
        }
    }

    private func syncVaultToCloud(_ vault: ObsidianVault) {
        Task {
            await syncVaultToCloudInternal(vault, showAlert: true)
        }
    }

    @MainActor
    private func syncVaultToCloudInternal(_ vault: ObsidianVault, showAlert: Bool) async {
        guard !isSyncing else { return }
        isSyncing = true

        do {
            let cloudSync = MacObsidianCloudSync()
            try await cloudSync.uploadVault(vault.id)
            logger.info("Vault \(vault.name) synced to iCloud")

            if showAlert {
                syncAlertTitle = "Synced to iCloud"
                syncAlertMessage = "\"\(vault.name)\" has been synced to iCloud. It may take a few minutes to appear on your other devices."
                showingSyncAlert = true
            }
        } catch {
            logger.error("Failed to sync vault to iCloud: \(error.localizedDescription)")

            if showAlert {
                syncAlertTitle = "Sync Failed"
                syncAlertMessage = "Failed to sync \"\(vault.name)\" to iCloud: \(error.localizedDescription)"
                showingSyncAlert = true
            }
        }

        isSyncing = false
    }
}

// MARK: - Vault Card

private struct VaultCard: View {
    let vault: ObsidianVault
    let isExpanded: Bool
    let hasChanges: Bool
    let changedPathsCount: Int
    let onTap: () -> Void
    let onRefresh: () -> Void
    let onSyncToCloud: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var cloudSyncStatus: MacObsidianCloudSync.VaultSyncStatus?
    @State private var statusTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerButton
            expandedContent
        }
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(statusBorderColor, lineWidth: 2)
        )
        .onAppear {
            refreshCloudStatus()
        }
        .onChange(of: isExpanded) { newValue in
            if newValue {
                refreshCloudStatus()
                // Start periodic refresh while expanded
                statusTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                    refreshCloudStatus()
                }
            } else {
                statusTimer?.invalidate()
                statusTimer = nil
            }
        }
        .onDisappear {
            statusTimer?.invalidate()
            statusTimer = nil
        }
    }

    private func refreshCloudStatus() {
        Task { @MainActor in
            let sync = MacObsidianCloudSync()
            cloudSyncStatus = sync.getVaultSyncStatus(vault.id)
        }
    }

    private var statusBorderColor: Color {
        switch vault.status {
        case .synced: return .green.opacity(0.3)
        case .error: return .red.opacity(0.3)
        case .indexing, .syncing: return .blue.opacity(0.3)
        default: return .clear
        }
    }

    @ViewBuilder
    private var headerButton: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                vaultIcon
                nameAndStats
                Spacer()

                if hasChanges {
                    changesBadge
                }

                statusBadge
                expandIndicator
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var vaultIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.purple.opacity(0.15))
                .frame(width: 40, height: 40)
            Image("ObsidianIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
        }
    }

    private var nameAndStats: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(vault.name)
                .font(.headline)

            if vault.noteCount > 0 {
                Text("\(vault.noteCount) notes, \(vault.chunkCount) chunks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Not indexed")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var changesBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption)
            Text("\(changedPathsCount) changed")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.15))
        .clipShape(Capsule())
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: vault.status.icon)
                .font(.caption)
            Text(vault.statusMessage)
                .font(.caption)
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch vault.status {
        case .notConfigured: return .gray
        case .indexing, .syncing, .downloading: return .blue
        case .synced: return .green
        case .needsRefresh: return .orange
        case .error: return .red
        }
    }

    private var expandIndicator: some View {
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .foregroundStyle(.tertiary)
            .font(.caption)
    }

    @ViewBuilder
    private var expandedContent: some View {
        if isExpanded {
            Divider()
                .padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 16) {
                pathInfo
                cloudStatusInfo
                settingsInfo
                actionButtons
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private var cloudStatusInfo: some View {
        if let status = cloudSyncStatus {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: cloudStatusIcon(for: status))
                        .foregroundStyle(cloudStatusColor(for: status))

                    Text("iCloud: \(status.statusMessage)")
                        .font(.callout)
                        .fontWeight(.medium)

                    Spacer()

                    if !status.isFullyUploaded && status.isInCloud && status.syncedToServer {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                // Show warning if files exist locally but haven't synced to server
                if status.isInCloud && !status.syncedToServer {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.caption)
                            Text("Files waiting to upload")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.orange)

                        Text("iCloud sync is paused or slow on this network. Connect to WiFi for reliable sync to iOS.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func cloudStatusIcon(for status: MacObsidianCloudSync.VaultSyncStatus) -> String {
        if !status.isInCloud {
            return "icloud.slash"
        } else if !status.syncedToServer {
            return "icloud.and.arrow.up"
        } else if status.isFullyUploaded {
            return "checkmark.icloud.fill"
        } else {
            return "icloud.and.arrow.up"
        }
    }

    private func cloudStatusColor(for status: MacObsidianCloudSync.VaultSyncStatus) -> Color {
        if !status.isInCloud {
            return .gray
        } else if !status.syncedToServer {
            return .orange
        } else if status.isFullyUploaded {
            return .green
        } else {
            return .blue
        }
    }

    private var pathInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let localPath = vault.localPath {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Local Path")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(localPath)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("iCloud Path")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(vault.iCloudPath)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var settingsInfo: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            settingBadge(
                title: "Daily Notes",
                value: vault.dailyNotePath,
                icon: "calendar",
                color: .blue
            )

            settingBadge(
                title: "New Notes",
                value: vault.newNotesFolder,
                icon: "folder.badge.plus",
                color: .green
            )

            settingBadge(
                title: "Auto Refresh",
                value: vault.autoRefreshEnabled ? "On" : "Off",
                icon: "arrow.clockwise",
                color: .purple
            )
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: onRefresh) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .disabled(vault.status == .indexing || vault.status == .syncing)

            Button(action: onSyncToCloud) {
                Label("Sync to iCloud", systemImage: "icloud.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .disabled(vault.status != .synced)

            Button("Edit", action: onEdit)
                .buttonStyle(.bordered)

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
        }
    }

    private func settingBadge(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.callout)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Obsidian Vault Manager

@MainActor
class ObsidianVaultManager: ObservableObject {
    static let shared = ObsidianVaultManager()

    @Published var vaults: [ObsidianVault] = []

    private let bookmarkManager = MacFileBookmarkManager.shared
    private let defaults = UserDefaults.standard
    private let vaultsKey = "obsidianVaults"

    init() {
        loadVaults()
        restoreBookmarks()
    }

    func addVault(_ vault: ObsidianVault) {
        vaults.append(vault)
        saveVaults()
    }

    func updateVault(_ vault: ObsidianVault) {
        if let index = vaults.firstIndex(where: { $0.id == vault.id }) {
            vaults[index] = vault
            saveVaults()
        }
    }

    func deleteVault(_ vaultId: UUID) {
        vaults.removeAll { $0.id == vaultId }
        bookmarkManager.removeBookmark(for: vaultId)
        saveVaults()
    }

    func refreshVault(_ vaultId: UUID) async {
        logger.info("Refreshing vault \(vaultId)")

        guard let vaultIndex = vaults.firstIndex(where: { $0.id == vaultId }) else {
            logger.error("Vault not found: \(vaultId)")
            return
        }

        let vault = vaults[vaultIndex]
        guard let localPath = vault.localPath else {
            logger.error("Vault has no local path")
            return
        }

        // Check for OpenAI API key
        guard let apiKey = MacSettings.shared.apiKey(for: .openAI), !apiKey.isEmpty else {
            logger.error("No OpenAI API key configured for embeddings")
            // Update vault status to error
            var updatedVault = vault
            updatedVault.status = .error
            vaults[vaultIndex] = updatedVault
            saveVaults()
            return
        }

        // Start bookmark access
        let bookmarkManager = MacFileBookmarkManager.shared
        do {
            _ = try bookmarkManager.restoreBookmark(for: vaultId)
        } catch {
            logger.error("Failed to access vault folder: \(error.localizedDescription)")
            return
        }
        defer { bookmarkManager.stopAccessing(vaultId: vaultId) }

        // Update status to indexing
        var indexingVault = vault
        indexingVault.status = .indexing
        vaults[vaultIndex] = indexingVault
        saveVaults()

        // Run the indexer
        let indexer = MacObsidianIndexer(apiKey: apiKey)
        var lastProgress: ObsidianIndexingProgress?

        for await progress in indexer.indexVault(at: localPath, vaultId: vaultId) {
            lastProgress = progress
            logger.info("Indexing progress: \(progress.phase.rawValue) - \(progress.chunksGenerated) chunks")
        }

        // Update vault with results
        var finalVault = vault
        if let progress = lastProgress, progress.phase == .complete {
            finalVault.status = .synced
            finalVault.noteCount = progress.notesProcessed
            finalVault.chunkCount = progress.chunksGenerated
            finalVault.lastIndexed = Date()
            logger.info("Vault indexed successfully: \(progress.notesProcessed) notes, \(progress.chunksGenerated) chunks")
        } else if lastProgress?.phase == .error {
            finalVault.status = .error
            logger.error("Indexing failed: \(lastProgress?.currentNote ?? "Unknown error")")
        } else {
            finalVault.status = .error
            logger.error("Indexing ended unexpectedly")
        }

        vaults[vaultIndex] = finalVault
        saveVaults()

        // Also update MacSettings
        MacSettings.shared.updateObsidianVault(finalVault)
    }

    private func loadVaults() {
        if let data = defaults.data(forKey: vaultsKey),
           let decoded = try? JSONDecoder().decode([ObsidianVault].self, from: data) {
            vaults = decoded
            logger.info("Loaded \(self.vaults.count) Obsidian vaults")
        }
    }

    private func saveVaults() {
        if let encoded = try? JSONEncoder().encode(vaults) {
            defaults.set(encoded, forKey: vaultsKey)
            logger.info("Saved \(self.vaults.count) Obsidian vaults")
        }
    }

    private func restoreBookmarks() {
        let vaultIds = vaults.map { $0.id }
        bookmarkManager.restoreAllBookmarks(for: vaultIds)
    }
}

// MARK: - Preview

#Preview {
    MacVaultsSettingsView(settings: MacSettings.shared)
        .frame(width: 600, height: 700)
}
