//
//  VaultDetailView.swift
//  SwiftSpeak
//
//  Detail view for a downloaded Obsidian vault
//  Shows vault info, storage, Power Modes using it, and management actions
//

import SwiftUI
import SwiftSpeakCore
import CoreData

struct VaultDetailView: View {

    // MARK: - Environment

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Properties

    let vaultEntity: ObsidianVaultEntity
    let manifest: ObsidianVaultManifest

    // MARK: - State

    @State private var showingDeleteConfirmation = false
    @State private var showingRedownloadSheet = false
    @State private var errorMessage: String?
    @State private var showingError = false

    @FetchRequest(
        entity: PowerModeEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PowerModeEntity.name, ascending: true)]
    ) private var powerModes: FetchedResults<PowerModeEntity>

    // MARK: - Services

    private let syncService = ObsidianSyncService()
    private let vectorStore = ObsidianVectorStore()

    // MARK: - Body

    var body: some View {
        List {
            // Vault Info Section
            Section {
                VaultInfoRow(label: "Name", value: vaultEntity.name ?? "Untitled", icon: "folder")
                VaultInfoRow(label: "Notes", value: "\(vaultEntity.noteCount)", icon: "doc.text")
                VaultInfoRow(label: "Chunks", value: "\(vaultEntity.chunkCount)", icon: "square.grid.3x3")
                VaultInfoRow(label: "Model", value: vaultEntity.embeddingModel ?? "Unknown", icon: "cpu")

                if let lastIndexed = vaultEntity.lastIndexed {
                    HStack {
                        Label("Last Indexed", systemImage: "clock")
                        Spacer()
                        Text(lastIndexed, style: .relative)
                            .foregroundColor(.secondary)
                    }
                }

                if let lastSynced = vaultEntity.lastSynced {
                    HStack {
                        Label("Last Downloaded", systemImage: "icloud.and.arrow.down")
                        Spacer()
                        Text(lastSynced, style: .relative)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Vault Information")
            }

            // Storage Section
            Section {
                HStack {
                    Label("Local Storage", systemImage: "internaldrive")
                    Spacer()
                    Text(estimatedStorageSize)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Label("iCloud Path", systemImage: "icloud")
                    Spacer()
                    Text(vaultEntity.iCloudPath ?? "Unknown")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            } header: {
                Text("Storage")
            }

            // Power Modes Using This Vault
            Section {
                if powerModesUsingVault.isEmpty {
                    Text("No Power Modes are using this vault")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(powerModesUsingVault, id: \.id) { powerMode in
                        NavigationLink {
                            // TODO: Navigate to PowerModeEditorView
                            Text("Power Mode: \(powerMode.name ?? "Untitled")")
                        } label: {
                            Label(powerMode.name ?? "Untitled", systemImage: "bolt.fill")
                        }
                    }
                }
            } header: {
                Text("Power Modes")
            } footer: {
                if !powerModesUsingVault.isEmpty {
                    Text("These Power Modes use this vault for knowledge retrieval")
                }
            }

            // Actions Section
            Section {
                Button {
                    showingRedownloadSheet = true
                } label: {
                    Label("Re-download Vault", systemImage: "arrow.clockwise.icloud")
                }

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Local Cache", systemImage: "trash")
                }
            } header: {
                Text("Actions")
            } footer: {
                Text("Re-downloading will fetch the latest version from iCloud. Deleting removes local data but keeps the vault on iCloud.")
            }
        }
        .navigationTitle(vaultEntity.name ?? "Vault Details")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingRedownloadSheet) {
            ObsidianDownloadSheet(
                manifest: manifest,
                syncService: syncService,
                vectorStore: vectorStore
            )
        }
        .confirmationDialog(
            "Delete Local Cache",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteLocalCache()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will delete the local cached data for this vault. You can re-download it from iCloud at any time.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Computed Properties

    private var estimatedStorageSize: String {
        // Rough estimate: 1536 floats * 4 bytes per chunk + metadata
        let bytesPerChunk = 1536 * 4 + 200
        let totalBytes = Int64(Int(vaultEntity.chunkCount) * bytesPerChunk)

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytes)
    }

    private var powerModesUsingVault: [PowerModeEntity] {
        guard let vaultId = vaultEntity.id else { return [] }

        return powerModes.filter { powerMode in
            // Check if this Power Mode's RAG config references this vault
            // This requires decoding the jsonData to check the PowerMode model
            guard let jsonData = powerMode.jsonData,
                  let decoded = try? JSONDecoder().decode(PowerMode.self, from: jsonData) else {
                return false
            }

            // Check if the vault ID is in the Power Mode's vault list
            // TODO: This assumes PowerMode has a vaultIds property - adjust based on actual model
            return false // Placeholder - implement based on PowerMode structure
        }
    }

    // MARK: - Actions

    private func deleteLocalCache() {
        guard let vaultId = vaultEntity.id else { return }

        do {
            // Delete from vector store
            try vectorStore.deleteVault(vaultId)

            // Delete Core Data entity
            viewContext.delete(vaultEntity)
            try viewContext.save()

            appLog("Deleted local cache for vault: \(vaultEntity.name ?? "unknown")", category: "Obsidian")

            // Dismiss view
            dismiss()
        } catch {
            errorMessage = "Failed to delete vault: \(error.localizedDescription)"
            showingError = true
            appLog("Failed to delete vault: \(error)", category: "Obsidian", level: .error)
        }
    }
}

// MARK: - Vault Info Row

private struct VaultInfoRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Previews

#if DEBUG
struct VaultDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            VaultDetailView(
                vaultEntity: {
                    let context = PersistenceController.preview.viewContext
                    let entity = ObsidianVaultEntity(context: context)
                    entity.id = UUID()
                    entity.name = "Personal Vault"
                    entity.iCloudPath = "vaults/PersonalVault/"
                    entity.noteCount = 234
                    entity.chunkCount = 1567
                    entity.lastIndexed = Date().addingTimeInterval(-3600)
                    entity.lastSynced = Date().addingTimeInterval(-1800)
                    entity.status = "synced"
                    entity.embeddingModel = "text-embedding-3-small"
                    return entity
                }(),
                manifest: ObsidianVaultManifest(
                    vaultId: UUID(),
                    indexedAt: Date().addingTimeInterval(-3600),
                    embeddingModel: "text-embedding-3-small",
                    noteCount: 234,
                    chunkCount: 1567,
                    embeddingBatchCount: 2,
                    notes: []
                )
            )
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
        }
    }
}
#endif
