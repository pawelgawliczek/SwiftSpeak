//
//  CloudKitLogSync.swift
//  SwiftSpeak
//
//  Syncs logs to CloudKit for cross-device debugging.
//  iOS: Uploads logs to CloudKit periodically
//  macOS: Reads logs from CloudKit for viewing iOS logs during development
//
//  SHARED: This file is used by both SwiftSpeak (iOS) and SwiftSpeakMac targets
//

import Foundation
import CoreData
import Combine

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Cloud log entry model (synced via CloudKit)
struct CloudLogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let source: String      // "App", "Keyboard", "MacApp"
    let category: String
    let level: String       // "DEBUG", "INFO", "WARN", "ERROR"
    let message: String
    let deviceId: String
    let deviceName: String

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: timestamp)
    }

    var levelColor: String {
        switch level {
        case "ERROR": return "red"
        case "WARN": return "orange"
        case "DEBUG": return "gray"
        default: return "primary"
        }
    }
}

/// Manages CloudKit log synchronization
@MainActor
final class CloudKitLogSync: ObservableObject {

    // MARK: - Shared Instance

    static let shared = CloudKitLogSync()

    // MARK: - Published Properties

    @Published private(set) var cloudLogs: [CloudLogEntry] = []
    @Published private(set) var isUploading = false
    @Published private(set) var lastSyncTime: Date?
    @Published var isCloudLoggingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isCloudLoggingEnabled, forKey: "cloudLoggingEnabled")
        }
    }

    // MARK: - Private Properties

    private let persistence: PersistenceController
    private var viewContext: NSManagedObjectContext {
        persistence.viewContext
    }

    /// Device identifier (persisted for consistency)
    private let deviceId: String

    /// Device name for display
    private let deviceName: String

    /// Maximum logs to keep in cloud (per device)
    private let maxCloudLogs = 500

    /// Minimum interval between uploads (seconds)
    private let uploadInterval: TimeInterval = 5

    /// Last upload time
    private var lastUploadTime: Date?

    /// Pending logs to upload
    private var pendingLogs: [LogEntry] = []

    // MARK: - Initialization

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence

        // Load cloud logging preference
        self.isCloudLoggingEnabled = UserDefaults.standard.bool(forKey: "cloudLoggingEnabled")

        // Get or create persistent device ID
        if let existingId = UserDefaults.standard.string(forKey: "cloudLogDeviceId") {
            self.deviceId = existingId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "cloudLogDeviceId")
            self.deviceId = newId
        }

        // Get device name
        #if os(iOS)
        self.deviceName = UIDevice.current.name
        #elseif os(macOS)
        self.deviceName = Host.current().localizedName ?? "Mac"
        #endif

        // Listen for iCloud sync updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudSync),
            name: .coreDataDidSyncFromCloud,
            object: nil
        )

        // Load existing cloud logs
        loadCloudLogs()
    }

    @objc private func handleCloudSync() {
        loadCloudLogs()
    }

    // MARK: - Log Upload (iOS)

    /// Queue a log entry for cloud upload
    func queueLogForUpload(_ entry: LogEntry) {
        guard isCloudLoggingEnabled else { return }

        pendingLogs.append(entry)

        // Batch uploads to reduce API calls
        if pendingLogs.count >= 10 || shouldUploadNow() {
            Task {
                await uploadPendingLogs()
            }
        }
    }

    private func shouldUploadNow() -> Bool {
        guard let lastUpload = lastUploadTime else { return true }
        return Date().timeIntervalSince(lastUpload) >= uploadInterval
    }

    /// Upload pending logs to CloudKit
    func uploadPendingLogs() async {
        guard !pendingLogs.isEmpty, !isUploading else { return }

        isUploading = true
        let logsToUpload = pendingLogs
        pendingLogs = []

        for entry in logsToUpload {
            let cloudEntry = CloudLogEntryEntity(context: viewContext)
            cloudEntry.id = UUID()
            cloudEntry.timestamp = entry.timestamp
            cloudEntry.source = entry.source.rawValue
            cloudEntry.category = entry.category
            cloudEntry.level = entry.level.rawValue
            cloudEntry.message = entry.message
            cloudEntry.deviceId = deviceId
            cloudEntry.deviceName = deviceName
        }

        persistence.save()
        lastUploadTime = Date()
        lastSyncTime = Date()
        isUploading = false

        // Prune old logs
        await pruneOldCloudLogs()

        // Reload to update UI
        loadCloudLogs()
    }

    /// Force upload any pending logs
    func flushLogs() async {
        await uploadPendingLogs()
    }

    // MARK: - Log Reading

    /// Load cloud logs from Core Data
    func loadCloudLogs() {
        let request = CloudLogEntryEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CloudLogEntryEntity.timestamp, ascending: false)]
        request.fetchLimit = 1000  // Reasonable limit for viewing

        do {
            let entities = try viewContext.fetch(request)
            cloudLogs = entities.compactMap { entity -> CloudLogEntry? in
                guard let id = entity.id,
                      let timestamp = entity.timestamp,
                      let source = entity.source,
                      let category = entity.category,
                      let level = entity.level,
                      let message = entity.message,
                      let deviceId = entity.deviceId,
                      let deviceName = entity.deviceName else {
                    return nil
                }

                return CloudLogEntry(
                    id: id,
                    timestamp: timestamp,
                    source: source,
                    category: category,
                    level: level,
                    message: message,
                    deviceId: deviceId,
                    deviceName: deviceName
                )
            }
            lastSyncTime = Date()
        } catch {
            // Can't use appLog here - would cause recursion
            print("CloudKitLogSync: Failed to load cloud logs: \(error)")
        }
    }

    /// Get logs filtered by device
    func logs(forDevice deviceId: String? = nil) -> [CloudLogEntry] {
        if let deviceId = deviceId {
            return cloudLogs.filter { $0.deviceId == deviceId }
        }
        return cloudLogs
    }

    /// Get unique device IDs
    var availableDevices: [(id: String, name: String)] {
        var seen = Set<String>()
        var devices: [(id: String, name: String)] = []

        for log in cloudLogs {
            if !seen.contains(log.deviceId) {
                seen.insert(log.deviceId)
                devices.append((log.deviceId, log.deviceName))
            }
        }

        return devices.sorted { $0.name < $1.name }
    }

    /// Get logs filtered by level
    func logs(minLevel: String) -> [CloudLogEntry] {
        let levels = ["DEBUG", "INFO", "WARN", "ERROR"]
        guard let minIndex = levels.firstIndex(of: minLevel) else {
            return cloudLogs
        }
        let allowedLevels = Set(levels[minIndex...])
        return cloudLogs.filter { allowedLevels.contains($0.level) }
    }

    // MARK: - Cleanup

    /// Remove old logs to stay within limits
    private func pruneOldCloudLogs() async {
        let request = CloudLogEntryEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CloudLogEntryEntity.timestamp, ascending: false)]

        do {
            let entities = try viewContext.fetch(request)

            // Group by device
            var deviceLogs: [String: [CloudLogEntryEntity]] = [:]
            for entity in entities {
                let key = entity.deviceId ?? "unknown"
                deviceLogs[key, default: []].append(entity)
            }

            // Keep only maxCloudLogs per device
            for (_, logs) in deviceLogs {
                if logs.count > maxCloudLogs {
                    for entity in logs.suffix(from: maxCloudLogs) {
                        viewContext.delete(entity)
                    }
                }
            }

            // Also remove logs older than 7 days
            let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            for entity in entities {
                if let timestamp = entity.timestamp, timestamp < cutoff {
                    viewContext.delete(entity)
                }
            }

            persistence.save()
        } catch {
            print("CloudKitLogSync: Failed to prune logs: \(error)")
        }
    }

    /// Clear all cloud logs
    func clearAllCloudLogs() {
        let request = CloudLogEntryEntity.fetchRequest()

        do {
            let entities = try viewContext.fetch(request)
            for entity in entities {
                viewContext.delete(entity)
            }
            persistence.save()
            cloudLogs = []
        } catch {
            print("CloudKitLogSync: Failed to clear logs: \(error)")
        }
    }

    /// Clear logs for a specific device
    func clearLogs(forDevice deviceId: String) {
        let request = CloudLogEntryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "deviceId == %@", deviceId)

        do {
            let entities = try viewContext.fetch(request)
            for entity in entities {
                viewContext.delete(entity)
            }
            persistence.save()
            loadCloudLogs()
        } catch {
            print("CloudKitLogSync: Failed to clear device logs: \(error)")
        }
    }
}

// MARK: - CloudLogEntryEntity Extension
// Note: fetchRequest() is auto-generated by CoreData
