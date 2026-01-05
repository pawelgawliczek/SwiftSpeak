//
//  ObsidianVaultManager.swift
//  SwiftSpeak
//
//  Manages Obsidian vaults persistence and lifecycle across iOS and macOS
//  Acts as single source of truth for vault state, synced via Core Data + CloudKit
//

import Foundation
import CoreData
import SwiftSpeakCore
import Combine

// MARK: - Obsidian Vault Manager

/// Manages Obsidian vault persistence and synchronization
/// This is the single source of truth for vault state across all platforms
@MainActor
class ObsidianVaultManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ObsidianVaultManager()

    // MARK: - Published Properties

    @Published private(set) var vaults: [ObsidianVault] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    // MARK: - Private Properties

    private let viewContext: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        self.viewContext = PersistenceController.shared.viewContext

        // Listen for Core Data remote changes
        NotificationCenter.default.publisher(for: .coreDataDidSyncFromCloud)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.loadVaults()
                }
            }
            .store(in: &cancellables)

        // Initial load
        loadVaults()
    }

    // MARK: - Public API

    /// Load all vaults from Core Data
    func loadVaults() {
        let fetchRequest = ObsidianVaultEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ObsidianVaultEntity.name, ascending: true)]

        do {
            let entities = try viewContext.fetch(fetchRequest)
            self.vaults = entities.compactMap { entity in
                guard let id = entity.id,
                      let name = entity.name,
                      let iCloudPath = entity.iCloudPath,
                      let status = entity.status else {
                    return nil
                }

                return ObsidianVault(
                    id: id,
                    name: name,
                    localPath: nil, // Not stored in Core Data (macOS-specific, uses bookmarks)
                    iCloudPath: iCloudPath,
                    lastIndexed: entity.lastIndexed,
                    noteCount: Int(entity.noteCount),
                    chunkCount: Int(entity.chunkCount),
                    status: ObsidianVaultStatus(rawValue: status) ?? .notConfigured,
                    autoRefreshEnabled: true,
                    dailyNotePath: "Daily Notes/{date}.md",
                    newNotesFolder: "Inbox"
                )
            }

            appLog("Loaded \(self.vaults.count) vaults from Core Data", category: "Obsidian")
        } catch {
            appLog("Failed to load vaults: \(error.localizedDescription)", category: "Obsidian", level: .error)
            self.errorMessage = error.localizedDescription
        }
    }

    /// Add a new vault
    func addVault(_ vault: ObsidianVault) throws {
        let entity = ObsidianVaultEntity(context: viewContext)
        entity.id = vault.id
        entity.name = vault.name
        entity.iCloudPath = vault.iCloudPath
        entity.lastIndexed = vault.lastIndexed
        entity.lastSynced = nil
        entity.noteCount = Int32(vault.noteCount)
        entity.chunkCount = Int32(vault.chunkCount)
        entity.status = vault.status.rawValue
        entity.embeddingModel = "text-embedding-3-small"

        try viewContext.save()

        appLog("Added vault: \(vault.name)", category: "Obsidian")
        loadVaults()
    }

    /// Update an existing vault
    func updateVault(_ vault: ObsidianVault) throws {
        let fetchRequest = ObsidianVaultEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", vault.id as CVarArg)

        guard let entity = try viewContext.fetch(fetchRequest).first else {
            throw ObsidianVaultManagerError.vaultNotFound(vault.id)
        }

        entity.name = vault.name
        entity.iCloudPath = vault.iCloudPath
        entity.lastIndexed = vault.lastIndexed
        entity.noteCount = Int32(vault.noteCount)
        entity.chunkCount = Int32(vault.chunkCount)
        entity.status = vault.status.rawValue

        try viewContext.save()

        appLog("Updated vault: \(vault.name)", category: "Obsidian")
        loadVaults()
    }

    /// Update vault status
    func updateVaultStatus(_ vaultId: UUID, status: ObsidianVaultStatus) throws {
        let fetchRequest = ObsidianVaultEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", vaultId as CVarArg)

        guard let entity = try viewContext.fetch(fetchRequest).first else {
            throw ObsidianVaultManagerError.vaultNotFound(vaultId)
        }

        entity.status = status.rawValue
        try viewContext.save()

        appLog("Updated vault status: \(status)", category: "Obsidian")
        loadVaults()
    }

    /// Update vault after indexing
    func updateVaultAfterIndexing(
        _ vaultId: UUID,
        noteCount: Int,
        chunkCount: Int
    ) throws {
        let fetchRequest = ObsidianVaultEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", vaultId as CVarArg)

        guard let entity = try viewContext.fetch(fetchRequest).first else {
            throw ObsidianVaultManagerError.vaultNotFound(vaultId)
        }

        entity.lastIndexed = Date()
        entity.noteCount = Int32(noteCount)
        entity.chunkCount = Int32(chunkCount)
        entity.status = ObsidianVaultStatus.indexing.rawValue

        try viewContext.save()

        appLog("Updated vault after indexing: \(noteCount) notes, \(chunkCount) chunks", category: "Obsidian")
        loadVaults()
    }

    /// Update vault after sync
    func updateVaultAfterSync(_ vaultId: UUID) throws {
        let fetchRequest = ObsidianVaultEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", vaultId as CVarArg)

        guard let entity = try viewContext.fetch(fetchRequest).first else {
            throw ObsidianVaultManagerError.vaultNotFound(vaultId)
        }

        entity.lastSynced = Date()
        entity.status = ObsidianVaultStatus.synced.rawValue

        try viewContext.save()

        appLog("Updated vault after sync", category: "Obsidian")
        loadVaults()
    }

    /// Delete a vault
    func deleteVault(_ vaultId: UUID) throws {
        let fetchRequest = ObsidianVaultEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", vaultId as CVarArg)

        guard let entity = try viewContext.fetch(fetchRequest).first else {
            throw ObsidianVaultManagerError.vaultNotFound(vaultId)
        }

        viewContext.delete(entity)
        try viewContext.save()

        appLog("Deleted vault: \(vaultId)", category: "Obsidian")
        loadVaults()
    }

    /// Get a specific vault by ID
    func getVault(_ vaultId: UUID) -> ObsidianVault? {
        vaults.first { $0.id == vaultId }
    }

    /// Check if any vault needs refresh
    var hasVaultsNeedingRefresh: Bool {
        vaults.contains { $0.needsRefresh }
    }

    /// Get vaults that need refresh
    var vaultsNeedingRefresh: [ObsidianVault] {
        vaults.filter { $0.needsRefresh }
    }
}

// MARK: - Errors

enum ObsidianVaultManagerError: Error, LocalizedError {
    case vaultNotFound(UUID)
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .vaultNotFound(let id):
            return "Vault not found: \(id)"
        case .saveFailed(let message):
            return "Failed to save vault: \(message)"
        }
    }
}
