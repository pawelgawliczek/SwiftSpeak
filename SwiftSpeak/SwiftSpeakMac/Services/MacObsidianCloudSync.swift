//
//  MacObsidianCloudSync.swift
//  SwiftSpeakMac
//
//  Syncs Obsidian embeddings to iCloud Drive for iOS access
//  Transforms local format to iOS-compatible format
//

import Foundation
import SwiftSpeakCore

@MainActor
final class MacObsidianCloudSync {

    private let fileManager = FileManager.default

    /// iCloud container identifier - must match iOS
    private static let iCloudContainerIdentifier = "iCloud.pawelgawliczek.SwiftSpeak"

    /// iCloud Drive container for SwiftSpeak Obsidian data
    private var iCloudDirectory: URL? {
        // iCloud Drive container: ~/Library/Mobile Documents/iCloud~pawelgawliczek~SwiftSpeak/
        guard let containerURL = fileManager.url(forUbiquityContainerIdentifier: Self.iCloudContainerIdentifier) else {
            macLog("iCloud container not available for \(Self.iCloudContainerIdentifier)", category: "CloudSync", level: .warning)
            return nil
        }
        macLog("iCloud container URL: \(containerURL.path)", category: "CloudSync")
        let obsidianDir = containerURL.appendingPathComponent("Documents/Obsidian", isDirectory: true)
        try? fileManager.createDirectory(at: obsidianDir, withIntermediateDirectories: true)
        return obsidianDir
    }

    /// Local Application Support directory (source of truth)
    private var localDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("SwiftSpeak/Obsidian", isDirectory: true)
    }

    // MARK: - Upload to iCloud

    /// Upload vault embeddings to iCloud Drive (transforms to iOS-compatible format)
    func uploadVault(_ vaultId: UUID) async throws {
        macLog("uploadVault called for: \(vaultId)", category: "CloudSync")

        guard let iCloudDir = iCloudDirectory else {
            macLog("Cannot upload - iCloud not available", category: "CloudSync", level: .error)
            throw ObsidianSyncError.iCloudNotAvailable
        }

        macLog("iCloud directory: \(iCloudDir.path)", category: "CloudSync")

        let localVaultDir = localDirectory.appendingPathComponent(vaultId.uuidString)
        let iCloudVaultDir = iCloudDir.appendingPathComponent(vaultId.uuidString)

        macLog("Local directory: \(localVaultDir.path)", category: "CloudSync")

        // Check local files exist
        let requiredFiles = ["manifest.json", "chunks.json", "embeddings.bin"]
        for file in requiredFiles {
            let localPath = localVaultDir.appendingPathComponent(file)
            let exists = fileManager.fileExists(atPath: localPath.path)
            macLog("Checking \(file): exists=\(exists)", category: "CloudSync")
            guard exists else {
                macLog("Missing local file: \(file)", category: "CloudSync", level: .error)
                throw ObsidianSyncError.missingLocalFile(file)
            }
        }

        // Create iCloud vault directory
        try fileManager.createDirectory(at: iCloudVaultDir, withIntermediateDirectories: true)

        // Read local data
        let localManifestData = try Data(contentsOf: localVaultDir.appendingPathComponent("manifest.json"))
        let localChunksData = try Data(contentsOf: localVaultDir.appendingPathComponent("chunks.json"))
        let localEmbeddingsData = try Data(contentsOf: localVaultDir.appendingPathComponent("embeddings.bin"))

        // Parse local manifest
        let localManifest = try JSONDecoder().decode(LocalManifest.self, from: localManifestData)

        // Parse local chunks
        let localChunks = try JSONDecoder().decode([LocalChunk].self, from: localChunksData)

        macLog("Transforming \(localChunks.count) chunks for iOS", category: "CloudSync")

        // Transform chunks to iOS format (chunks_index.json)
        let chunksIndex = ChunksIndex(chunks: localChunks.map { chunk in
            ChunkIndexItem(
                id: chunk.id,
                noteId: chunk.noteId,
                content: chunk.content,
                startOffset: chunk.startOffset ?? 0,
                endOffset: chunk.endOffset ?? chunk.content.count
            )
        })
        let chunksIndexData = try JSONEncoder().encode(chunksIndex)

        // Create iOS-compatible manifest
        let iosManifest = ObsidianVaultManifest(
            vaultId: vaultId,
            indexedAt: Date(timeIntervalSinceReferenceDate: localManifest.indexedAt),
            embeddingModel: localManifest.embeddingModel,
            noteCount: Set(localChunks.map { $0.noteId }).count,
            chunkCount: localManifest.chunkCount,
            embeddingBatchCount: 1, // Single batch for now
            notes: []
        )
        let iosManifestData = try JSONEncoder().encode(iosManifest)

        // Write files using setUbiquitous for proper iCloud tracking
        try writeToICloud(data: iosManifestData, filename: "manifest.json", iCloudDir: iCloudVaultDir)
        try writeToICloud(data: chunksIndexData, filename: "chunks_index.json", iCloudDir: iCloudVaultDir)
        try writeToICloud(data: localEmbeddingsData, filename: "embeddings_0.bin", iCloudDir: iCloudVaultDir)

        macLog("Vault \(vaultId) uploaded to iCloud (iOS format)", category: "CloudSync")

        // Force iCloud to start uploading immediately
        forceICloudSync(directory: iCloudVaultDir)
    }

    /// Force iCloud to sync a directory by touching files and triggering the daemon
    private func forceICloudSync(directory: URL) {
        macLog("Forcing iCloud sync for \(directory.lastPathComponent)", category: "CloudSync")

        // Method 1: Evict and re-download triggers sync state refresh
        // (We skip this as it would delete local copies)

        // Method 2: Request a "published" URL - this wakes up iCloud daemon
        do {
            var expiration: NSDate?
            let _ = try fileManager.url(forPublishingUbiquitousItemAt: directory, expiration: &expiration)
            macLog("Published URL requested for iCloud sync trigger", category: "CloudSync")
        } catch {
            macLog("Could not publish URL (expected): \(error.localizedDescription)", category: "CloudSync", level: .debug)
        }

        // Method 3: Touch all files to update modification date
        if let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for file in contents {
                try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
            }
        }

        // Method 4: Call startDownloadingUbiquitousItem on each file
        // This wakes up the iCloud daemon even though we're "downloading"
        if let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for file in contents {
                try? fileManager.startDownloadingUbiquitousItem(at: file)
            }
            macLog("Triggered iCloud daemon for \(contents.count) files", category: "CloudSync")
        }
    }

    /// Write data to iCloud using NSFileCoordinator for proper ubiquitous tracking
    private func writeToICloud(data: Data, filename: String, iCloudDir: URL) throws {
        let iCloudPath = iCloudDir.appendingPathComponent(filename)

        // Use NSFileCoordinator to write directly to iCloud folder
        // This should properly register the file as ubiquitous
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var writeError: Error?

        coordinator.coordinate(writingItemAt: iCloudPath, options: [.forMerging], error: &coordinatorError) { url in
            do {
                // Write data directly to the coordinated URL
                try data.write(to: url, options: [.atomic])
                macLog("Wrote \(filename) via NSFileCoordinator", category: "CloudSync")
            } catch {
                writeError = error
            }
        }

        if let error = coordinatorError {
            macLog("Coordinator error for \(filename): \(error.localizedDescription)", category: "CloudSync", level: .error)
            throw error
        }
        if let error = writeError {
            macLog("Write error for \(filename): \(error.localizedDescription)", category: "CloudSync", level: .error)
            throw error
        }

        // Force iCloud to recognize the new file
        try? fileManager.startDownloadingUbiquitousItem(at: iCloudPath)
    }

    /// Upload all synced vaults to iCloud
    func uploadAllVaults() async {
        let vaults = MacSettings.shared.obsidianVaults.filter { $0.status == .synced }
        for vault in vaults {
            do {
                try await uploadVault(vault.id)
            } catch {
                macLog("Failed to upload vault \(vault.name): \(error)", category: "CloudSync", level: .error)
            }
        }
    }

    // MARK: - Status Check

    /// Detailed sync status for a vault
    struct VaultSyncStatus {
        let isInCloud: Bool
        let filesUploaded: Int
        let filesPending: Int
        let totalFiles: Int
        let pendingFileNames: [String]
        let syncedToServer: Bool  // Whether files have actually reached iCloud servers

        var isFullyUploaded: Bool { filesPending == 0 && totalFiles > 0 && syncedToServer }

        var statusMessage: String {
            if !isInCloud {
                return "Not in iCloud"
            } else if !syncedToServer {
                return "Pending upload (connect to WiFi)"
            } else if filesPending > 0 {
                return "Uploading... (\(filesUploaded)/\(totalFiles))"
            } else if totalFiles > 0 {
                return "Uploaded ✓"
            } else {
                return "No files"
            }
        }
    }

    /// Get detailed sync status for a vault
    func getVaultSyncStatus(_ vaultId: UUID) -> VaultSyncStatus {
        guard let iCloudDir = iCloudDirectory else {
            return VaultSyncStatus(isInCloud: false, filesUploaded: 0, filesPending: 0, totalFiles: 0, pendingFileNames: [], syncedToServer: false)
        }

        let vaultDir = iCloudDir.appendingPathComponent(vaultId.uuidString)
        guard fileManager.fileExists(atPath: vaultDir.path) else {
            return VaultSyncStatus(isInCloud: false, filesUploaded: 0, filesPending: 0, totalFiles: 0, pendingFileNames: [], syncedToServer: false)
        }

        var uploaded = 0
        var pending = 0
        var pendingNames: [String] = []
        var anyFileIsUbiquitous = false

        let expectedFiles = ["manifest.json", "chunks_index.json", "embeddings_0.bin"]

        for filename in expectedFiles {
            let fileURL = vaultDir.appendingPathComponent(filename)
            if fileManager.fileExists(atPath: fileURL.path) {
                // Check if file is uploaded to iCloud
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [
                        .ubiquitousItemIsUploadedKey,
                        .ubiquitousItemIsUploadingKey,
                        .isUbiquitousItemKey
                    ])

                    // Check if iCloud recognizes this as a ubiquitous item
                    if resourceValues.isUbiquitousItem == true {
                        anyFileIsUbiquitous = true
                    }

                    let isUploaded = resourceValues.ubiquitousItemIsUploaded ?? false
                    let isUploading = resourceValues.ubiquitousItemIsUploading ?? false

                    if isUploaded {
                        uploaded += 1
                    } else {
                        pending += 1
                        pendingNames.append(filename + (isUploading ? " (uploading)" : " (queued)"))
                    }
                } catch {
                    // If we can't read status, assume it needs upload
                    pending += 1
                    pendingNames.append(filename + " (unknown)")
                }
            }
        }

        // Files are synced to server if iCloud recognizes them as ubiquitous AND they're uploaded
        let syncedToServer = anyFileIsUbiquitous && uploaded > 0

        return VaultSyncStatus(
            isInCloud: true,
            filesUploaded: uploaded,
            filesPending: pending,
            totalFiles: uploaded + pending,
            pendingFileNames: pendingNames,
            syncedToServer: syncedToServer
        )
    }

    /// Check if a vault is available in iCloud
    func isVaultInCloud(_ vaultId: UUID) -> Bool {
        guard let iCloudDir = iCloudDirectory else { return false }
        let manifestPath = iCloudDir
            .appendingPathComponent(vaultId.uuidString)
            .appendingPathComponent("manifest.json")
        return fileManager.fileExists(atPath: manifestPath.path)
    }

    /// Get list of vault IDs available in iCloud
    func cloudVaultIds() -> [UUID] {
        guard let iCloudDir = iCloudDirectory else { return [] }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: iCloudDir,
                includingPropertiesForKeys: [.isDirectoryKey]
            )
            return contents.compactMap { url in
                UUID(uuidString: url.lastPathComponent)
            }
        } catch {
            return []
        }
    }

    // MARK: - Cleanup

    /// Remove vault from iCloud
    func removeFromCloud(_ vaultId: UUID) throws {
        guard let iCloudDir = iCloudDirectory else { return }
        let vaultDir = iCloudDir.appendingPathComponent(vaultId.uuidString)
        if fileManager.fileExists(atPath: vaultDir.path) {
            try fileManager.removeItem(at: vaultDir)
            macLog("Removed vault \(vaultId) from iCloud", category: "CloudSync")
        }
    }
}

// MARK: - Errors

enum ObsidianSyncError: Error, LocalizedError {
    case iCloudNotAvailable
    case missingLocalFile(String)
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud is not available"
        case .missingLocalFile(let file):
            return "Missing local file: \(file)"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        }
    }
}

// MARK: - Local File Formats (Mac vector store format)

/// Local manifest format from Mac vector store
private struct LocalManifest: Codable {
    let indexedAt: TimeInterval
    let vaultId: String
    let chunkCount: Int
    let embeddingDimension: Int
    let embeddingModel: String
}

/// Local chunk format from Mac vector store
private struct LocalChunk: Codable {
    let id: String
    let noteId: String
    let content: String
    let chunkIndex: Int
    let notePath: String
    let noteTitle: String
    let vaultId: String
    // These may not be present in local format
    let startOffset: Int?
    let endOffset: Int?
}

// MARK: - iOS File Formats (chunks_index.json)

/// JSON structure for chunks index file (iOS format)
private struct ChunksIndex: Codable {
    let chunks: [ChunkIndexItem]
}

private struct ChunkIndexItem: Codable {
    let id: String
    let noteId: String
    let content: String
    let startOffset: Int
    let endOffset: Int
}
