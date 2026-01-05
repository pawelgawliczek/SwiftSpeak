//
//  MacFileBookmarkManager.swift
//  SwiftSpeakMac
//
//  Manages security-scoped bookmarks for persistent folder access
//  Required for Obsidian vault folders selected by the user
//

import Foundation
import AppKit
import os.log

private let logger = Logger(subsystem: "SwiftSpeakMac", category: "FileBookmark")

// MARK: - Bookmark Errors

enum BookmarkError: Error, LocalizedError {
    case creationFailed
    case resolveFailed
    case staleBookmark
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .creationFailed:
            return "Failed to create security-scoped bookmark"
        case .resolveFailed:
            return "Failed to resolve bookmark"
        case .staleBookmark:
            return "Bookmark is stale - please re-select folder"
        case .accessDenied:
            return "Access denied to folder"
        }
    }
}

// MARK: - File Bookmark Manager

@MainActor
final class MacFileBookmarkManager {

    // MARK: - Singleton

    static let shared = MacFileBookmarkManager()

    // MARK: - Properties

    private let defaults = UserDefaults.standard
    private let bookmarksKey = "obsidianVaultBookmarks"

    /// Currently accessed URLs (need to call stopAccessing when done)
    private var accessedURLs: [UUID: URL] = [:]

    // MARK: - Initialization

    private init() {
        logger.info("File bookmark manager initialized")
    }

    // MARK: - Public API

    /// Create and store a security-scoped bookmark for a folder
    func createBookmark(for url: URL, vaultId: UUID) throws {
        // Request security-scoped access
        guard url.startAccessingSecurityScopedResource() else {
            throw BookmarkError.accessDenied
        }
        defer {
            url.stopAccessingSecurityScopedResource()
        }

        // Create bookmark data
        let bookmarkData: Data
        do {
            bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            logger.error("Failed to create bookmark: \(error.localizedDescription)")
            throw BookmarkError.creationFailed
        }

        // Store bookmark
        saveBookmark(bookmarkData, for: vaultId)

        logger.info("Created bookmark for vault \(vaultId) at \(url.path)")
    }

    /// Restore access to a bookmarked folder
    func restoreBookmark(for vaultId: UUID) throws -> URL {
        guard let bookmarkData = loadBookmark(for: vaultId) else {
            throw BookmarkError.resolveFailed
        }

        var isStale = false
        let url: URL

        do {
            url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            logger.error("Failed to resolve bookmark: \(error.localizedDescription)")
            throw BookmarkError.resolveFailed
        }

        if isStale {
            logger.warning("Bookmark is stale for vault \(vaultId)")
            throw BookmarkError.staleBookmark
        }

        // Start accessing the resource
        guard url.startAccessingSecurityScopedResource() else {
            throw BookmarkError.accessDenied
        }

        // Track this URL so we can stop accessing it later
        accessedURLs[vaultId] = url

        logger.info("Restored bookmark for vault \(vaultId) at \(url.path)")
        return url
    }

    /// Stop accessing a bookmarked folder
    func stopAccessing(vaultId: UUID) {
        guard let url = accessedURLs[vaultId] else { return }

        url.stopAccessingSecurityScopedResource()
        accessedURLs.removeValue(forKey: vaultId)

        logger.info("Stopped accessing vault \(vaultId)")
    }

    /// Remove bookmark for a vault
    func removeBookmark(for vaultId: UUID) {
        stopAccessing(vaultId: vaultId)

        var bookmarks = loadAllBookmarks()
        bookmarks.removeValue(forKey: vaultId.uuidString)
        saveAllBookmarks(bookmarks)

        logger.info("Removed bookmark for vault \(vaultId)")
    }

    /// Check if a bookmark exists for a vault
    func hasBookmark(for vaultId: UUID) -> Bool {
        loadBookmark(for: vaultId) != nil
    }

    /// Restore all bookmarks on app launch
    func restoreAllBookmarks(for vaults: [UUID]) {
        logger.info("Restoring bookmarks for \(vaults.count) vaults")

        for vaultId in vaults {
            do {
                _ = try restoreBookmark(for: vaultId)
            } catch {
                logger.warning("Failed to restore bookmark for vault \(vaultId): \(error.localizedDescription)")
            }
        }
    }

    /// Stop accessing all bookmarked folders (call on app termination)
    func stopAccessingAll() {
        let vaultIds = Array(accessedURLs.keys)
        for vaultId in vaultIds {
            stopAccessing(vaultId: vaultId)
        }
        logger.info("Stopped accessing all bookmarked folders")
    }

    // MARK: - Persistence

    private func saveBookmark(_ data: Data, for vaultId: UUID) {
        var bookmarks = loadAllBookmarks()
        bookmarks[vaultId.uuidString] = data
        saveAllBookmarks(bookmarks)
    }

    private func loadBookmark(for vaultId: UUID) -> Data? {
        let bookmarks = loadAllBookmarks()
        return bookmarks[vaultId.uuidString]
    }

    private func loadAllBookmarks() -> [String: Data] {
        guard let data = defaults.data(forKey: bookmarksKey),
              let bookmarks = try? JSONDecoder().decode([String: Data].self, from: data) else {
            return [:]
        }
        return bookmarks
    }

    private func saveAllBookmarks(_ bookmarks: [String: Data]) {
        if let data = try? JSONEncoder().encode(bookmarks) {
            defaults.set(data, forKey: bookmarksKey)
        }
    }
}
