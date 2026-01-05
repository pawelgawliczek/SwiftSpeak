//
//  VaultsSettingsView.swift
//  SwiftSpeak
//
//  iOS settings view for managing Obsidian vaults
//  Shows available vaults from iCloud and download status
//

import SwiftUI
import SwiftSpeakCore
import CoreData

struct VaultsSettingsView: View {

    // MARK: - Environment

    @Environment(\.managedObjectContext) private var viewContext

    // MARK: - State

    @State private var remoteVaults: [ObsidianVaultManifest] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var selectedVault: ObsidianVaultManifest?
    @State private var showingDownloadSheet = false
    @State private var isICloudAvailable = false

    @FetchRequest(
        entity: ObsidianVaultEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \ObsidianVaultEntity.name, ascending: true)]
    ) private var localVaults: FetchedResults<ObsidianVaultEntity>

    // MARK: - Services

    private let syncService = ObsidianSyncService()
    private let vectorStore = ObsidianVectorStore()

    // MARK: - Body

    var body: some View {
        List {
            // iCloud Status Section
            Section {
                HStack {
                    Image(systemName: "icloud.fill")
                        .foregroundColor(.blue)
                    Text("iCloud Drive")
                    Spacer()
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(isICloudAvailable ? "Connected" : "Not Available")
                            .foregroundColor(isICloudAvailable ? .green : .red)
                    }
                }
            } header: {
                Text("iCloud Status")
            }

            // Available Vaults Section
            Section {
                if remoteVaults.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "macbook.and.iphone")
                            .font(.system(size: 48))
                            .foregroundColor(.purple.opacity(0.6))

                        Text("No Vaults Available")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("To use Obsidian vaults with SwiftSpeak:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Label("Open SwiftSpeak on your Mac", systemImage: "1.circle.fill")
                                Label("Go to Settings → Vaults", systemImage: "2.circle.fill")
                                Label("Add and index your Obsidian vault", systemImage: "3.circle.fill")
                                Label("Vaults will sync here via iCloud", systemImage: "4.circle.fill")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)

                        if !isICloudAvailable {
                            Text("Sign in to iCloud to sync vaults")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.top, 4)
                        }

                        Button(action: {
                            Task { await refreshVaults() }
                        }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    ForEach(remoteVaults, id: \.vaultId) { manifest in
                        VaultRow(
                            manifest: manifest,
                            isDownloaded: isVaultDownloaded(manifest.vaultId),
                            localVault: getLocalVault(manifest.vaultId),
                            onDownload: {
                                selectedVault = manifest
                                showingDownloadSheet = true
                            },
                            onViewDetails: {
                                // Navigate to detail view
                            }
                        )
                    }
                }
            } header: {
                Text("Available Vaults")
            } footer: {
                if !remoteVaults.isEmpty {
                    Text("\(remoteVaults.count) vault\(remoteVaults.count == 1 ? "" : "s") synced from Mac")
                }
            }

            // Storage Section
            Section {
                HStack {
                    Label("Local Storage", systemImage: "internaldrive")
                    Spacer()
                    Text(formatStorageSize(calculateLocalStorage()))
                        .foregroundColor(.secondary)
                }

                if !localVaults.isEmpty {
                    Button(role: .destructive) {
                        clearAllLocalData()
                    } label: {
                        Label("Clear All Local Data", systemImage: "trash")
                    }
                }
            } header: {
                Text("Storage")
            }
        }
        .navigationTitle("Obsidian Vaults")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await refreshVaults()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .sheet(isPresented: $showingDownloadSheet) {
            if let vault = selectedVault {
                ObsidianDownloadSheet(
                    manifest: vault,
                    syncService: syncService,
                    vectorStore: vectorStore
                )
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
        .task {
            await refreshVaults()
        }
    }

    // MARK: - Helpers

    private func refreshVaults() async {
        isLoading = true
        defer { isLoading = false }

        // Check if iCloud is available first - don't show error if it's just unavailable
        let available = await syncService.isICloudAvailable
        isICloudAvailable = available

        guard available else {
            appLog("iCloud not available - skipping vault refresh", category: "Obsidian")
            remoteVaults = []
            return
        }

        do {
            remoteVaults = try await syncService.listRemoteVaults()
            appLog("Found \(remoteVaults.count) remote vaults", category: "Obsidian")
        } catch {
            // Only show error for unexpected failures, not for iCloud unavailable
            if case ObsidianSyncError.iCloudNotAvailable = error {
                remoteVaults = []
            } else {
                errorMessage = error.localizedDescription
                showingError = true
                appLog("Failed to list remote vaults: \(error)", category: "Obsidian", level: .error)
            }
        }
    }

    private func isVaultDownloaded(_ vaultId: UUID) -> Bool {
        localVaults.contains { $0.id == vaultId }
    }

    private func getLocalVault(_ vaultId: UUID) -> ObsidianVaultEntity? {
        localVaults.first { $0.id == vaultId }
    }

    private func calculateLocalStorage() -> Int64 {
        // Calculate approximate storage used by vector store
        // SQLite database size + any cached files
        let fileManager = FileManager.default
        guard let containerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.pawelgawliczek.swiftspeak"
        ) else {
            return 0
        }

        let dbPath = containerURL.appendingPathComponent("obsidian_vector_store.db").path

        guard let attributes = try? fileManager.attributesOfItem(atPath: dbPath),
              let fileSize = attributes[.size] as? Int64 else {
            return 0
        }

        return fileSize
    }

    private func formatStorageSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func clearAllLocalData() {
        do {
            try vectorStore.clearAll()

            // Delete all local vault entities
            for vault in localVaults {
                viewContext.delete(vault)
            }

            try viewContext.save()

            appLog("Cleared all local Obsidian data", category: "Obsidian")
        } catch {
            errorMessage = "Failed to clear data: \(error.localizedDescription)"
            showingError = true
            appLog("Failed to clear local data: \(error)", category: "Obsidian", level: .error)
        }
    }
}

// MARK: - Vault Row

struct VaultRow: View {
    let manifest: ObsidianVaultManifest
    let isDownloaded: Bool
    let localVault: ObsidianVaultEntity?
    let onDownload: () -> Void
    let onViewDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(manifest.notes.first?.title ?? "Untitled Vault")
                        .font(.headline)

                    HStack(spacing: 12) {
                        Label("\(manifest.noteCount)", systemImage: "doc.text")
                        Label("\(manifest.chunkCount)", systemImage: "square.grid.3x3")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                if isDownloaded {
                    VStack(alignment: .trailing, spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .imageScale(.large)

                        if let lastSynced = localVault?.lastSynced {
                            Text(lastSynced, style: .relative)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Button {
                        onDownload()
                    } label: {
                        Label("Download", systemImage: "icloud.and.arrow.down")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Indexed date
            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                Text("Indexed \(manifest.indexedAt, style: .relative)")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)

            // Storage estimate
            if isDownloaded, let chunkCount = localVault?.chunkCount {
                HStack {
                    Image(systemName: "internaldrive")
                        .font(.caption2)
                    Text("\(formatStorageEstimate(chunkCount: Int(chunkCount)))")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if isDownloaded {
                onViewDetails()
            }
        }
    }

    private func formatStorageEstimate(chunkCount: Int) -> String {
        // Rough estimate: 1536 floats * 4 bytes per chunk + metadata
        let bytesPerChunk = 1536 * 4 + 200 // embedding + metadata
        let totalBytes = Int64(chunkCount * bytesPerChunk)

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytes)
    }
}

// MARK: - Previews

#if DEBUG
struct VaultsSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            VaultsSettingsView()
                .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
        }
    }
}
#endif
