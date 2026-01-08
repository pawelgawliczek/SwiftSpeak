//
//  PersistenceController.swift
//  SwiftSpeak
//
//  Core Data persistence controller with CloudKit sync.
//  Syncs history, contexts, and settings between iOS and macOS.
//

import CoreData

/// Manages Core Data persistence with CloudKit sync.
/// Data is automatically synced between iOS and macOS via iCloud.
final class PersistenceController: @unchecked Sendable {

    // MARK: - Shared Instance

    static let shared = PersistenceController()

    /// Preview instance for SwiftUI previews
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        return controller
    }()

    // MARK: - Properties

    /// The persistent container with CloudKit sync
    let container: NSPersistentCloudKitContainer

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
        // Use CloudKit container for sync between iOS and macOS
        container = NSPersistentCloudKitContainer(name: "SwiftSpeak")

        // Configure store description
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("No persistent store description found")
        }

        if inMemory {
            // Use in-memory store for previews/testing (no CloudKit)
            description.url = URL(fileURLWithPath: "/dev/null")
            description.cloudKitContainerOptions = nil
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

            // Configure CloudKit container options
            let cloudKitOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.pawelgawliczek.SwiftSpeak"
            )
            description.cloudKitContainerOptions = cloudKitOptions

            // Enable history tracking for CloudKit sync
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }

        // Load persistent stores
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // Log error but don't crash - allow app to run with potential data issues
                #if os(iOS)
                appLog("Core Data load error: \(error.localizedDescription)", category: "CoreData", level: .error)
                #elseif os(macOS)
                macLog("Core Data load error: \(error.localizedDescription)", category: "CoreData", level: .error)
                #endif

                // In development, you might want to crash to catch issues early
                #if DEBUG
                fatalError("Core Data load error: \(error)")
                #endif
            } else {
                #if os(iOS)
                appLog("Core Data store loaded with CloudKit: \(storeDescription.url?.lastPathComponent ?? "unknown")", category: "CoreData")
                #elseif os(macOS)
                macLog("Core Data store loaded with CloudKit: \(storeDescription.url?.lastPathComponent ?? "unknown")", category: "CoreData")
                #endif
            }
        }

        // Configure view context for CloudKit
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Set query generation to keep a stable view of data
        try? container.viewContext.setQueryGenerationFrom(.current)

        // Listen for remote change notifications from CloudKit
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )
    }

    // MARK: - CloudKit Sync

    @objc private func handleRemoteChange(_ notification: Notification) {
        // Post notification for UI to refresh (silently - no logging to avoid spam)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .coreDataDidSyncFromCloud, object: nil)
        }
    }

    // MARK: - Save Helpers

    /// Save the view context if there are changes
    func save() {
        let context = viewContext
        guard context.hasChanges else { return }

        do {
            try context.save()
            // Success is silent - only log errors
        } catch {
            #if os(iOS)
            appLog("Core Data save error: \(error.localizedDescription)", category: "CoreData", level: .error)
            #elseif os(macOS)
            macLog("Core Data save error: \(error.localizedDescription)", category: "CoreData", level: .error)
            #endif
        }
    }

    /// Save a background context
    func saveBackground(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            #if os(iOS)
            appLog("Core Data background save error: \(error.localizedDescription)", category: "CoreData", level: .error)
            #elseif os(macOS)
            macLog("Core Data background save error: \(error.localizedDescription)", category: "CoreData", level: .error)
            #endif
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
                    #if os(iOS)
                    appLog("Core Data background task save error: \(error.localizedDescription)", category: "CoreData", level: .error)
                    #elseif os(macOS)
                    macLog("Core Data background task save error: \(error.localizedDescription)", category: "CoreData", level: .error)
                    #endif
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
                #if os(iOS)
                appLog("Failed to delete \(entityName): \(error)", category: "CoreData", level: .error)
                #elseif os(macOS)
                macLog("Failed to delete \(entityName): \(error)", category: "CoreData", level: .error)
                #endif
            }
        }

        save()
        #if os(iOS)
        appLog("All Core Data deleted", category: "CoreData")
        #elseif os(macOS)
        macLog("All Core Data deleted", category: "CoreData")
        #endif
    }
    #endif
}

// MARK: - Notifications

extension Notification.Name {
    /// Posted when Core Data receives changes from iCloud via CloudKit
    static let coreDataDidSyncFromCloud = Notification.Name("coreDataDidSyncFromCloud")
}
