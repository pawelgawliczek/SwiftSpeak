//
//  MemoryUpdateCoordinator.swift
//  SwiftSpeak
//
//  LEGACY: This file is deprecated and kept for reference only
//  Replaced by: MemoryUpdateScheduler.swift on 2025-01
//  Reason: Memory updates now use batch processing instead of per-transcription updates.
//          The new system collects messages and processes them on app start (12h-24h intervals)
//          using MemoryUpdateScheduler for better performance and reduced API costs.
//  DO NOT USE - Will be removed in future cleanup
//
//  Original purpose: Phase 11c - Serialize memory updates to prevent race conditions
//  Wraps MemoryManager with actor-based serialization
//

import Foundation
import SwiftSpeakCore

// MARK: - LEGACY CODE COMMENTED OUT
// The implementation below has been commented out because it references
// types and methods (MemoryUpdateResult, updateMemory) that were removed
// during the memory system redesign. The new batch-based memory update
// system is in MemoryUpdateScheduler.swift.

/*
/// Coordinates memory updates to prevent race conditions from rapid transcriptions
/// Uses Swift actor to ensure serial execution of memory operations
actor MemoryUpdateCoordinator {

    // MARK: - Types

    /// Pending memory update request
    struct PendingUpdate: Identifiable {
        let id: UUID
        let text: String
        let context: ConversationContext?
        let powerMode: PowerMode?
        let timestamp: Date
    }

    /// Result of processing the queue
    struct QueueProcessingResult {
        let processedCount: Int
        let failedCount: Int
        let results: [MemoryUpdateResult]
    }

    // MARK: - State

    /// Queue of pending updates (for batch processing if needed)
    private var pendingUpdates: [PendingUpdate] = []

    /// Whether currently processing
    private var isProcessing = false

    /// Callback to get MemoryManager (lazy to avoid actor isolation issues)
    private let memoryManagerProvider: @MainActor @Sendable () -> MemoryManager

    /// Maximum queue size before oldest items are dropped
    private let maxQueueSize = 20

    /// Debounce interval for rapid updates
    private let debounceInterval: TimeInterval = 0.5

    /// Last update timestamp (for debouncing)
    private var lastUpdateTime: Date?

    // MARK: - Initialization

    /// Initialize with a memory manager provider closure
    /// - Parameter memoryManagerProvider: Closure that returns a MemoryManager instance
    init(memoryManagerProvider: @escaping @MainActor @Sendable () -> MemoryManager) {
        self.memoryManagerProvider = memoryManagerProvider
    }

    // MARK: - Public API

    /// Queue a memory update (serial execution guaranteed by actor)
    /// - Parameters:
    ///   - text: The text to remember
    ///   - context: Active conversation context (if any)
    ///   - powerMode: Active power mode (if any)
    /// - Returns: Results from the memory update
    @discardableResult
    func updateMemory(
        text: String,
        context: ConversationContext?,
        powerMode: PowerMode?
    ) async -> [MemoryUpdateResult] {
        // Skip empty text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        // Apply debouncing for rapid updates
        if let lastTime = lastUpdateTime,
           Date().timeIntervalSince(lastTime) < debounceInterval {
            // Instead of skipping, we queue it (actor serializes anyway)
            // but we could merge similar updates in the future
        }

        lastUpdateTime = Date()

        // Get memory manager on the main actor
        let memoryManager = await MainActor.run {
            memoryManagerProvider()
        }

        // Execute the update (actor ensures this is serial)
        let results = await memoryManager.updateMemory(
            from: text,
            context: context,
            powerMode: powerMode
        )

        return results
    }

    /// Queue an update for deferred processing
    /// Use this when you don't need to wait for results
    func queueUpdate(
        text: String,
        context: ConversationContext?,
        powerMode: PowerMode?
    ) {
        // Skip empty text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let update = PendingUpdate(
            id: UUID(),
            text: text,
            context: context,
            powerMode: powerMode,
            timestamp: Date()
        )

        pendingUpdates.append(update)

        // Trim queue if too large (drop oldest)
        if pendingUpdates.count > maxQueueSize {
            pendingUpdates.removeFirst(pendingUpdates.count - maxQueueSize)
        }
    }

    /// Process all queued updates
    /// - Returns: Results from processing the queue
    func processQueue() async -> QueueProcessingResult {
        guard !pendingUpdates.isEmpty else {
            return QueueProcessingResult(processedCount: 0, failedCount: 0, results: [])
        }

        guard !isProcessing else {
            return QueueProcessingResult(processedCount: 0, failedCount: 0, results: [])
        }

        isProcessing = true
        defer { isProcessing = false }

        // Take all pending updates
        let updates = pendingUpdates
        pendingUpdates = []

        var allResults: [MemoryUpdateResult] = []
        var failedCount = 0

        // Get memory manager
        let memoryManager = await MainActor.run {
            memoryManagerProvider()
        }

        // Process each update serially
        for update in updates {
            let results = await memoryManager.updateMemory(
                from: update.text,
                context: update.context,
                powerMode: update.powerMode
            )

            allResults.append(contentsOf: results)

            // Count failures
            failedCount += results.filter { !$0.success }.count
        }

        return QueueProcessingResult(
            processedCount: updates.count,
            failedCount: failedCount,
            results: allResults
        )
    }

    /// Clear the pending queue without processing
    func clearQueue() {
        pendingUpdates = []
    }

    /// Get the number of pending updates
    var pendingCount: Int {
        pendingUpdates.count
    }

    /// Check if currently processing
    var isBusy: Bool {
        isProcessing
    }
}

// MARK: - Convenience Factory

extension MemoryUpdateCoordinator {
    /// Create a coordinator with the shared memory manager
    @MainActor
    static func shared() -> MemoryUpdateCoordinator {
        MemoryUpdateCoordinator {
            MemoryManager()
        }
    }
}

// MARK: - Protocol for Testing

/// Protocol for memory update coordination
protocol MemoryUpdateCoordinatorProtocol: Sendable {
    func updateMemory(
        text: String,
        context: ConversationContext?,
        powerMode: PowerMode?
    ) async -> [MemoryUpdateResult]

    func queueUpdate(
        text: String,
        context: ConversationContext?,
        powerMode: PowerMode?
    ) async

    func processQueue() async -> MemoryUpdateCoordinator.QueueProcessingResult
    func clearQueue() async
    var pendingCount: Int { get async }
}

// MARK: - Actor Conformance

extension MemoryUpdateCoordinator: MemoryUpdateCoordinatorProtocol {
    // Actor methods already conform
}
*/
