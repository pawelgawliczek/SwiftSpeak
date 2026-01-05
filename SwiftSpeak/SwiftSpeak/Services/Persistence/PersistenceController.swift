//
//  PersistenceController.swift
//  SwiftSpeak
//
//  Core Data persistence controller.
//  CloudKit sync is DISABLED until entitlements are properly configured.
//

import CoreData

/// Manages Core Data persistence for local storage.
/// CloudKit sync is temporarily disabled - data stored locally only.
final class PersistenceController: @unchecked Sendable {

    // MARK: - Shared Instance

    static let shared = PersistenceController()

    /// Preview instance for SwiftUI previews
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        return controller
    }()

    // MARK: - Properties

    /// The persistent container (regular NSPersistentContainer - CloudKit disabled)
    let container: NSPersistentContainer

    /// Main view context for UI operations (main thread only)
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Background context for heavy operations
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    // MARK: - Initialization

    init(inMemory: Bool = false) {
        // Use regular NSPersistentContainer (CloudKit disabled)
        container = NSPersistentContainer(name: "SwiftSpeak")

        // Configure store description
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("No persistent store description found")
        }

        if inMemory {
            // Use in-memory store for previews/testing
            description.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Platform-specific storage location
            #if os(iOS)
            // iOS: Use App Groups for shared access with keyboard extension
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.pawelgawliczek.swiftspeak") {
                let storeURL = containerURL.appendingPathComponent("SwiftSpeak.sqlite")
                description.url = storeURL
            }
            #elseif os(macOS)
            // macOS: Use Application Support directory
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let storeDirectory = appSupport.appendingPathComponent("SwiftSpeakMac", isDirectory: true)
            try? FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
            let storeURL = storeDirectory.appendingPathComponent("SwiftSpeak.sqlite")
            description.url = storeURL
            #endif
        }

        // Load persistent stores
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // Log error but don't crash - allow app to run with potential data issues
                appLog("Core Data load error: \(error.localizedDescription)", category: "CoreData", level: .error)

                // In development, you might want to crash to catch issues early
                #if DEBUG
                fatalError("Core Data load error: \(error)")
                #endif
            } else {
                appLog("Core Data store loaded: \(storeDescription.url?.lastPathComponent ?? "unknown")", category: "CoreData")
            }
        }

        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Set query generation to keep a stable view of data
        try? container.viewContext.setQueryGenerationFrom(.current)
    }

    // MARK: - Save Helpers

    /// Save the view context if there are changes
    func save() {
        let context = viewContext
        guard context.hasChanges else { return }

        do {
            try context.save()
            appLog("Core Data changes saved", category: "CoreData", level: .debug)
        } catch {
            appLog("Core Data save error: \(error.localizedDescription)", category: "CoreData", level: .error)
        }
    }

    /// Save a background context
    func saveBackground(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            appLog("Core Data background save error: \(error.localizedDescription)", category: "CoreData", level: .error)
        }
    }

    /// Perform a block on a background context and save
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            block(context)

            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    appLog("Core Data background task save error: \(error.localizedDescription)", category: "CoreData", level: .error)
                }
            }
        }
    }

    // MARK: - Debug Helpers

    #if DEBUG
    /// Delete all data (for testing only)
    func deleteAllData() {
        let entities = container.managedObjectModel.entities

        for entity in entities {
            guard let entityName = entity.name else { continue }

            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                try container.persistentStoreCoordinator.execute(deleteRequest, with: viewContext)
            } catch {
                appLog("Failed to delete \(entityName): \(error)", category: "CoreData", level: .error)
            }
        }

        save()
        appLog("All Core Data deleted", category: "CoreData")
    }
    #endif
}

// MARK: - Notifications

extension Notification.Name {
    /// Posted when Core Data receives changes from iCloud (placeholder for future CloudKit support)
    static let coreDataDidSyncFromCloud = Notification.Name("coreDataDidSyncFromCloud")
}
