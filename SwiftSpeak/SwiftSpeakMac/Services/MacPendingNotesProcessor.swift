//
//  MacPendingNotesProcessor.swift
//  SwiftSpeakMac
//
//  Processes pending Obsidian notes created by iOS
//  Monitors iCloud container and writes to local vaults
//

import Foundation
import SwiftSpeakCore

// MARK: - Pending Notes Processor

/// Processes pending notes from iOS that need to be written to local vaults
@MainActor
final class MacPendingNotesProcessor {

    static let shared = MacPendingNotesProcessor()

    private let fileManager = FileManager.default
    private var metadataQuery: NSMetadataQuery?
    private var isProcessing = false

    /// iCloud container for pending notes (shared with iOS)
    private var pendingNotesDirectory: URL? {
        guard let container = fileManager.url(forUbiquityContainerIdentifier: nil) else {
            macLog("iCloud container not available", category: "PendingNotes", level: .warning)
            return nil
        }
        return container.appendingPathComponent("Documents/Pending", isDirectory: true)
    }

    // MARK: - Lifecycle

    private init() {}

    /// Start monitoring for pending notes
    func startMonitoring() {
        guard metadataQuery == nil else { return }

        macLog("Starting pending notes monitoring", category: "PendingNotes")

        // Create metadata query for iCloud changes
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K ENDSWITH '.json' AND %K BEGINSWITH 'Pending/'",
                                       NSMetadataItemFSNameKey, NSMetadataItemPathKey)

        // Observe changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidUpdate),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidFinishGathering),
            name: .NSMetadataQueryDidFinishGathering,
            object: query
        )

        query.start()
        metadataQuery = query

        // Also check immediately
        Task {
            await processPendingNotes()
        }
    }

    /// Stop monitoring
    func stopMonitoring() {
        metadataQuery?.stop()
        metadataQuery = nil
        NotificationCenter.default.removeObserver(self)
        macLog("Stopped pending notes monitoring", category: "PendingNotes")
    }

    // MARK: - Query Callbacks

    @objc private func queryDidFinishGathering(_ notification: Notification) {
        Task {
            await processPendingNotes()
        }
    }

    @objc private func queryDidUpdate(_ notification: Notification) {
        Task {
            await processPendingNotes()
        }
    }

    // MARK: - Processing

    /// Process all pending notes in the iCloud container
    func processPendingNotes() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        guard let pendingDir = pendingNotesDirectory else {
            macLog("No pending notes directory", category: "PendingNotes", level: .warning)
            return
        }

        // Ensure directory exists
        if !fileManager.fileExists(atPath: pendingDir.path) {
            macLog("Pending notes directory doesn't exist yet", category: "PendingNotes")
            return
        }

        // Get all pending note files
        do {
            let files = try fileManager.contentsOfDirectory(at: pendingDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }

            if files.isEmpty {
                return
            }

            macLog("Found \(files.count) pending notes to process", category: "PendingNotes")

            for file in files {
                await processPendingNote(at: file)
            }
        } catch {
            macLog("Error reading pending notes: \(error)", category: "PendingNotes", level: .error)
        }
    }

    /// Process a single pending note
    private func processPendingNote(at url: URL) async {
        macLog("Processing pending note: \(url.lastPathComponent)", category: "PendingNotes")

        // Trigger download if needed
        do {
            try fileManager.startDownloadingUbiquitousItem(at: url)
        } catch {
            macLog("Error triggering download: \(error)", category: "PendingNotes", level: .warning)
        }

        // Wait for download with timeout
        var attempts = 0
        while !fileManager.fileExists(atPath: url.path) && attempts < 20 {
            try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
            attempts += 1
        }

        guard fileManager.fileExists(atPath: url.path) else {
            macLog("Pending note not downloaded in time", category: "PendingNotes", level: .warning)
            return
        }

        // Parse pending note
        do {
            let data = try Data(contentsOf: url)
            var pendingNote = try JSONDecoder().decode(PendingObsidianNote.self, from: data)

            // Find the vault
            guard let vault = findVault(id: pendingNote.vaultId) else {
                macLog("Vault not found: \(pendingNote.vaultId)", category: "PendingNotes", level: .warning)
                return
            }

            // Write to vault
            let noteWriter = MacObsidianNoteWriter()
            let result = await noteWriter.write(
                content: pendingNote.content,
                to: vault,
                action: pendingNote.action,
                noteName: extractNoteName(from: pendingNote.targetPath)
            )

            if result.isSuccess {
                macLog("Successfully processed pending note: \(pendingNote.id)", category: "PendingNotes")

                // Mark as processed
                pendingNote.processedAt = Date()

                // Delete the pending note file
                try fileManager.removeItem(at: url)
                macLog("Deleted processed pending note", category: "PendingNotes")
            } else {
                macLog("Failed to process pending note: \(result.message)", category: "PendingNotes", level: .error)
            }
        } catch {
            macLog("Error processing pending note: \(error)", category: "PendingNotes", level: .error)
        }
    }

    // MARK: - Helpers

    /// Find vault by ID from settings
    private func findVault(id: UUID) -> ObsidianVault? {
        return MacSettings.shared.obsidianVaults.first { $0.id == id }
    }

    /// Extract note name from target path
    private func extractNoteName(from path: String) -> String? {
        let filename = (path as NSString).lastPathComponent
        if filename.hasSuffix(".md") {
            return String(filename.dropLast(3))
        }
        return filename
    }

    // MARK: - Manual Trigger

    /// Manually trigger processing (e.g., when app launches)
    func checkForPendingNotes() {
        Task {
            await processPendingNotes()
        }
    }
}
