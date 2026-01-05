//
//  ObsidianCloudDownload.swift
//  SwiftSpeak
//
//  Downloads Obsidian embeddings from iCloud to iOS device
//  Enables offline semantic search on iPhone/iPad
//

import Foundation
import SwiftSpeakCore

#if !os(macOS)

@MainActor
final class ObsidianCloudDownload {

    private let fileManager = FileManager.default

    /// iCloud Drive container for SwiftSpeak Obsidian data
    private var iCloudDirectory: URL? {
        guard let containerURL = fileManager.url(forUbiquityContainerIdentifier: nil) else {
            appLog("iCloud container not available", category: "CloudSync", level: .warning)
            return nil
        }
        let obsidianDir = containerURL.appendingPathComponent("Documents/Obsidian", isDirectory: true)
        return obsidianDir
    }

    /// Local cache directory (App Groups for keyboard extension access)
    private var localDirectory: URL {
        let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.pawelgawliczek.swiftspeak")!
        let obsidianDir = groupURL.appendingPathComponent("Obsidian", isDirectory: true)
        try? fileManager.createDirectory(at: obsidianDir, withIntermediateDirectories: true)
        return obsidianDir
    }

    // MARK: - Download from iCloud

    /// Download vault embeddings from iCloud to local cache
    func downloadVault(_ vaultId: UUID, progress: ((Double) -> Void)? = nil) async throws {
        guard let iCloudDir = iCloudDirectory else {
            throw ObsidianDownloadError.iCloudNotAvailable
        }

        let iCloudVaultDir = iCloudDir.appendingPathComponent(vaultId.uuidString)
        let localVaultDir = localDirectory.appendingPathComponent(vaultId.uuidString)

        // Check iCloud files exist
        let manifestPath = iCloudVaultDir.appendingPathComponent("manifest.json")
        guard fileManager.fileExists(atPath: manifestPath.path) else {
            throw ObsidianDownloadError.vaultNotFound(vaultId)
        }

        // Create local vault directory
        try? fileManager.createDirectory(at: localVaultDir, withIntermediateDirectories: true)

        // Download files
        let files = ["manifest.json", "chunks.json", "embeddings.bin"]
        for (index, file) in files.enumerated() {
            let iCloudPath = iCloudVaultDir.appendingPathComponent(file)
            let localPath = localVaultDir.appendingPathComponent(file)

            // Trigger download if file is in cloud
            try? fileManager.startDownloadingUbiquitousItem(at: iCloudPath)

            // Wait for download with timeout
            var attempts = 0
            while !fileManager.fileExists(atPath: iCloudPath.path) && attempts < 30 {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                attempts += 1
            }

            guard fileManager.fileExists(atPath: iCloudPath.path) else {
                throw ObsidianDownloadError.downloadFailed("Timeout downloading \(file)")
            }

            // Copy to local
            if fileManager.fileExists(atPath: localPath.path) {
                try fileManager.removeItem(at: localPath)
            }
            try fileManager.copyItem(at: iCloudPath, to: localPath)

            progress?(Double(index + 1) / Double(files.count))
            appLog("Downloaded \(file)", category: "CloudSync")
        }

        appLog("Vault \(vaultId) downloaded from iCloud", category: "CloudSync")
    }

    // MARK: - Status

    /// Check if vault is cached locally
    func isVaultCached(_ vaultId: UUID) -> Bool {
        let manifestPath = localDirectory
            .appendingPathComponent(vaultId.uuidString)
            .appendingPathComponent("manifest.json")
        return fileManager.fileExists(atPath: manifestPath.path)
    }

    /// Get list of vault IDs available in iCloud
    func availableCloudVaults() async -> [UUID] {
        guard let iCloudDir = iCloudDirectory else { return [] }

        // Trigger iCloud metadata sync
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: iCloudDir,
                includingPropertiesForKeys: [.isDirectoryKey, .ubiquitousItemDownloadingStatusKey]
            )
            return contents.compactMap { url in
                UUID(uuidString: url.lastPathComponent)
            }
        } catch {
            return []
        }
    }

    /// Get local cache path for a vault (for query service)
    func localVaultPath(_ vaultId: UUID) -> URL {
        localDirectory.appendingPathComponent(vaultId.uuidString)
    }

    // MARK: - Cleanup

    /// Remove vault from local cache
    func removeLocalCache(_ vaultId: UUID) throws {
        let vaultDir = localDirectory.appendingPathComponent(vaultId.uuidString)
        if fileManager.fileExists(atPath: vaultDir.path) {
            try fileManager.removeItem(at: vaultDir)
        }
    }

    /// Get size of local cache
    func localCacheSize() -> Int64 {
        var size: Int64 = 0
        if let enumerator = fileManager.enumerator(at: localDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            while let url = enumerator.nextObject() as? URL {
                if let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    size += Int64(fileSize)
                }
            }
        }
        return size
    }
}

// MARK: - Errors

enum ObsidianDownloadError: Error, LocalizedError {
    case iCloudNotAvailable
    case vaultNotFound(UUID)
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud is not available. Make sure you're signed in to iCloud."
        case .vaultNotFound(let id):
            return "Vault not found in iCloud: \(id)"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        }
    }
}

#endif
