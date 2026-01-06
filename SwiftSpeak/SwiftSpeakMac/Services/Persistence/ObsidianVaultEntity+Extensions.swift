//
//  ObsidianVaultEntity+Extensions.swift
//  SwiftSpeak
//
//  Core Data entity extensions for ObsidianVaultEntity
//  Provides convenience methods and computed properties
//

import Foundation
import CoreData
import SwiftSpeakCore

extension ObsidianVaultEntity {

    // MARK: - Computed Properties

    /// Convert entity to model
    var asModel: ObsidianVault? {
        guard let id = id,
              let name = name,
              let iCloudPath = iCloudPath,
              let statusString = status,
              let status = ObsidianVaultStatus(rawValue: statusString) else {
            return nil
        }

        return ObsidianVault(
            id: id,
            name: name,
            localPath: nil, // Not stored in Core Data
            iCloudPath: iCloudPath,
            lastIndexed: lastIndexed,
            noteCount: Int(noteCount),
            chunkCount: Int(chunkCount),
            status: status,
            autoRefreshEnabled: true,
            dailyNotePath: "Daily Notes/{date}.md",
            newNotesFolder: "Inbox"
        )
    }

    // MARK: - Convenience Methods

    /// Update from model
    func update(from vault: ObsidianVault) {
        self.name = vault.name
        self.iCloudPath = vault.iCloudPath
        self.lastIndexed = vault.lastIndexed
        self.noteCount = Int32(vault.noteCount)
        self.chunkCount = Int32(vault.chunkCount)
        self.status = vault.status.rawValue
    }

    /// Create entity from model
    static func create(from vault: ObsidianVault, in context: NSManagedObjectContext) -> ObsidianVaultEntity {
        let entity = ObsidianVaultEntity(context: context)
        entity.id = vault.id
        entity.name = vault.name
        entity.iCloudPath = vault.iCloudPath
        entity.lastIndexed = vault.lastIndexed
        entity.lastSynced = nil
        entity.noteCount = Int32(vault.noteCount)
        entity.chunkCount = Int32(vault.chunkCount)
        entity.status = vault.status.rawValue
        entity.embeddingModel = "text-embedding-3-small"
        return entity
    }

    // MARK: - Query Helpers

    /// Find vault by ID
    static func find(byId id: UUID, in context: NSManagedObjectContext) throws -> ObsidianVaultEntity? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    /// Find vaults needing refresh
    static func findNeedingRefresh(in context: NSManagedObjectContext) throws -> [ObsidianVaultEntity] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "status == %@", ObsidianVaultStatus.needsRefresh.rawValue)
        return try context.fetch(request)
    }

    /// Find vaults by status
    static func find(byStatus status: ObsidianVaultStatus, in context: NSManagedObjectContext) throws -> [ObsidianVaultEntity] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "status == %@", status.rawValue)
        return try context.fetch(request)
    }

    /// Get all vaults sorted by name
    static func fetchAll(in context: NSManagedObjectContext) throws -> [ObsidianVaultEntity] {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ObsidianVaultEntity.name, ascending: true)]
        return try context.fetch(request)
    }
}
