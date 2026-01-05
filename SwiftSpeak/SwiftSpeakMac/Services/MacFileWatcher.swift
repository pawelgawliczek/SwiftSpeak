//
//  MacFileWatcher.swift
//  SwiftSpeakMac
//
//  FSEvents-based file system watcher for Obsidian vault changes
//  Detects when .md files are added, modified, or deleted
//

#if os(macOS)
import Foundation
import CoreServices
import SwiftSpeakCore
import os.log
import Combine

private let logger = Logger(subsystem: "SwiftSpeakMac", category: "FileWatcher")

// MARK: - File Watcher

/// FSEvents-based watcher for detecting file system changes in Obsidian vaults
@MainActor
public class MacFileWatcher: ObservableObject {

    // MARK: - Published State

    /// Vault IDs that have detected changes
    @Published public private(set) var vaultsWithChanges: Set<UUID> = []

    /// Paths of changed notes (relative to vault root)
    public private(set) var changedNotePaths: [UUID: Set<String>] = [:]

    // MARK: - Private State

    private var activeStreams: [UUID: FSEventStreamRef] = [:]
    private var vaultPaths: [UUID: String] = [:]
    private var streamToVaultId: [Int: UUID] = [:]

    // MARK: - Public API

    /// Start watching a vault for file system changes
    /// - Parameter vault: The vault to watch
    public func startWatching(vault: ObsidianVault) {
        guard let localPath = vault.localPath else {
            logger.warning("Cannot watch vault without local path: \(vault.name)")
            return
        }

        // Stop existing stream if any
        stopWatching(vault: vault)

        // Store path for change detection
        vaultPaths[vault.id] = localPath

        logger.info("Starting file watcher for vault: \(vault.name) at \(localPath)")

        // Create FSEvent stream
        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let pathsToWatch = [localPath as CFString] as CFArray

        // Store vault ID for lookup in callback
        let vaultId = vault.id

        let callback: FSEventStreamCallback = { (
            streamRef,
            clientCallBackInfo,
            numEvents,
            eventPaths,
            eventFlags,
            eventIds
        ) in
            guard let info = clientCallBackInfo else { return }
            let watcher = Unmanaged<MacFileWatcher>.fromOpaque(info).takeUnretainedValue()

            // Look up vault ID from stream
            let streamKey = Int(bitPattern: UnsafeRawPointer(streamRef))
            guard let vaultId = watcher.streamToVaultId[streamKey] else { return }

            let paths = unsafeBitCast(eventPaths, to: NSArray.self) as! [String]
            let flags = UnsafeBufferPointer(start: eventFlags, count: numEvents)

            Task { @MainActor in
                await watcher.handleEvents(paths: paths, flags: Array(flags), vaultId: vaultId)
            }
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0, // 1 second latency
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        ) else {
            logger.error("Failed to create FSEvent stream for vault: \(vault.name)")
            return
        }

        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)

        activeStreams[vault.id] = stream
        let streamKey = Int(bitPattern: UnsafeRawPointer(stream))
        streamToVaultId[streamKey] = vault.id

        logger.info("File watcher started for vault: \(vault.name)")
    }

    /// Stop watching a specific vault
    /// - Parameter vault: The vault to stop watching
    public func stopWatching(vault: ObsidianVault) {
        guard let stream = activeStreams[vault.id] else { return }

        let streamKey = Int(bitPattern: UnsafeRawPointer(stream))
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)

        activeStreams.removeValue(forKey: vault.id)
        vaultPaths.removeValue(forKey: vault.id)
        streamToVaultId.removeValue(forKey: streamKey)

        logger.info("File watcher stopped for vault: \(vault.name)")
    }

    /// Stop watching all vaults
    public func stopAll() {
        for (vaultId, stream) in activeStreams {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }

        activeStreams.removeAll()
        vaultPaths.removeAll()
        streamToVaultId.removeAll()

        logger.info("All file watchers stopped")
    }

    /// Clear change detection for a vault (after refresh)
    /// - Parameter vaultId: The vault ID
    public func clearChanges(for vaultId: UUID) {
        vaultsWithChanges.remove(vaultId)
        changedNotePaths.removeValue(forKey: vaultId)
    }

    /// Get changed note paths for a vault
    /// - Parameter vaultId: The vault ID
    /// - Returns: Set of relative paths that changed
    public func getChangedPaths(for vaultId: UUID) -> Set<String> {
        changedNotePaths[vaultId] ?? []
    }

    // MARK: - Event Handling

    private func handleEvents(paths: [String], flags: [FSEventStreamEventFlags], vaultId: UUID) async {
        guard let vaultPath = vaultPaths[vaultId] else { return }

        var detectedChanges = false

        for (index, path) in paths.enumerated() {
            let flag = flags[index]

            // Only process .md files
            guard path.hasSuffix(".md") else { continue }

            // Skip .obsidian folder
            if path.contains("/.obsidian/") { continue }

            // Get relative path
            let relativePath = path.replacingOccurrences(of: vaultPath + "/", with: "")

            // Detect change type
            let isCreated = (flag & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated)) != 0
            let isModified = (flag & FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified)) != 0
            let isRemoved = (flag & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved)) != 0

            if isCreated || isModified || isRemoved {
                // Track changed path
                var paths = changedNotePaths[vaultId] ?? []
                paths.insert(relativePath)
                changedNotePaths[vaultId] = paths

                detectedChanges = true

                let changeType = isCreated ? "created" : (isModified ? "modified" : "removed")
                logger.info("Detected \(changeType): \(relativePath)")
            }
        }

        if detectedChanges {
            vaultsWithChanges.insert(vaultId)
        }
    }

    // MARK: - Cleanup

    deinit {
        // Stop all streams
        for stream in activeStreams.values {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }
}

#endif
