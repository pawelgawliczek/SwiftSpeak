//
//  MemoryManager.swift
//  SwiftSpeak
//
//  Phase 4b: Three-tier memory system management.
//  Provides memory access and clearing utilities.
//  NOTE: Memory updates are now handled by MemoryUpdateScheduler (batch updates).
//

import Combine
import Foundation
import SwiftSpeakCore

/// Memory tier for targeting specific memory stores
enum MemoryTierTarget {
    case global
    case context(UUID)
    case powerMode(UUID)
}

/// Manages the three-tier memory system
/// - Global memory: User-wide memory, updated via batch process
/// - Context memory: Per-context, updated via batch process
/// - Power Mode memory: Per-workflow, updated via batch process
///
/// NOTE: Memory updates are no longer done per-transcription.
/// Use MemoryUpdateScheduler for batch updates on app start/foreground.
@MainActor
final class MemoryManager: ObservableObject {

    // MARK: - Configuration

    /// Maximum memory length (2000 characters per tier)
    static let maxMemoryLength = 2000

    // MARK: - Dependencies

    private let settings: SharedSettings

    // MARK: - Initialization

    init(settings: SharedSettings? = nil) {
        self.settings = settings ?? SharedSettings.shared
    }

    // MARK: - Clear Memory

    /// Clear memory for a specific tier
    func clearMemory(tier: MemoryTierTarget) {
        switch tier {
        case .global:
            settings.globalMemory = nil
            settings.lastGlobalMemoryUpdate = nil

        case .context(let id):
            settings.updateContextMemory(id: id, memory: "")
            settings.lastContextMemoryUpdates.removeValue(forKey: id)

        case .powerMode(let id):
            if var powerMode = settings.powerModes.first(where: { $0.id == id }) {
                powerMode.memory = nil
                powerMode.lastMemoryUpdate = nil
                settings.updatePowerMode(powerMode)
            }
            settings.lastPowerModeMemoryUpdates.removeValue(forKey: id)
        }
    }

    /// Clear all memory across all tiers
    func clearAllMemory() {
        // Clear global
        settings.globalMemory = nil
        settings.lastGlobalMemoryUpdate = nil

        // Clear all contexts
        for context in settings.contexts {
            settings.updateContextMemory(id: context.id, memory: "")
        }
        settings.lastContextMemoryUpdates = [:]

        // Clear all power modes
        for powerMode in settings.powerModes {
            var pm = powerMode
            pm.memory = nil
            pm.lastMemoryUpdate = nil
            settings.updatePowerMode(pm)
        }
        settings.lastPowerModeMemoryUpdates = [:]
    }

    // MARK: - Memory Access

    /// Get the current memory for a tier
    func getMemory(for tier: MemoryTierTarget) -> String? {
        switch tier {
        case .global:
            return settings.globalMemory

        case .context(let id):
            return settings.contexts.first(where: { $0.id == id })?.contextMemory

        case .powerMode(let id):
            return settings.powerModes.first(where: { $0.id == id })?.memory
        }
    }

    /// Check if memory is enabled for a tier
    func isMemoryEnabled(for tier: MemoryTierTarget) -> Bool {
        switch tier {
        case .global:
            return settings.globalMemoryEnabled

        case .context(let id):
            return settings.contexts.first(where: { $0.id == id })?.useContextMemory ?? false

        case .powerMode(let id):
            return settings.powerModes.first(where: { $0.id == id })?.memoryEnabled ?? false
        }
    }

    /// Get memory stats for display
    func getMemoryStats(for tier: MemoryTierTarget) -> (length: Int, lastUpdate: Date?) {
        switch tier {
        case .global:
            return (settings.globalMemory?.count ?? 0, settings.lastGlobalMemoryUpdate)

        case .context(let id):
            if let ctx = settings.contexts.first(where: { $0.id == id }) {
                let lastUpdate = settings.lastContextMemoryUpdates[id]
                return (ctx.contextMemory?.count ?? 0, lastUpdate)
            }
            return (0, nil)

        case .powerMode(let id):
            if let pm = settings.powerModes.first(where: { $0.id == id }) {
                let lastUpdate = settings.lastPowerModeMemoryUpdates[id]
                return (pm.memory?.count ?? 0, lastUpdate)
            }
            return (0, nil)
        }
    }

    /// Get combined memory for prompt injection
    /// Returns global + context + power mode memory combined
    func getCombinedMemory(
        context: ConversationContext?,
        powerMode: PowerMode?
    ) -> String? {
        var memoryParts: [String] = []

        // Add global memory if enabled
        if settings.globalMemoryEnabled, let global = settings.globalMemory, !global.isEmpty {
            memoryParts.append("=== Global Memory ===\n\(global)")
        }

        // Add context memory if available
        if let ctx = context, ctx.useContextMemory,
           let contextMemory = ctx.contextMemory, !contextMemory.isEmpty {
            memoryParts.append("=== Context: \(ctx.name) ===\n\(contextMemory)")
        }

        // Add power mode memory if available
        if let pm = powerMode, pm.memoryEnabled,
           let pmMemory = pm.memory, !pmMemory.isEmpty {
            memoryParts.append("=== Power Mode: \(pm.name) ===\n\(pmMemory)")
        }

        return memoryParts.isEmpty ? nil : memoryParts.joined(separator: "\n\n")
    }

    /// Check if any memory tier needs updating
    /// Used to show badge/indicator in UI
    func hasUnprocessedRecords() -> Bool {
        // Check global
        if settings.globalMemoryEnabled {
            let unprocessed = settings.getUnprocessedRecordsForMemory(tier: .global)
            if !unprocessed.isEmpty { return true }
        }

        // Check contexts
        for context in settings.contexts where context.useContextMemory {
            let unprocessed = settings.getUnprocessedRecordsForMemory(
                tier: .context,
                contextId: context.id
            )
            if !unprocessed.isEmpty { return true }
        }

        // Check power modes
        for powerMode in settings.powerModes where powerMode.memoryEnabled {
            let unprocessed = settings.getUnprocessedRecordsForMemory(
                tier: .powerMode,
                powerModeId: powerMode.id
            )
            if !unprocessed.isEmpty { return true }
        }

        return false
    }
}

// MARK: - Memory Errors

enum MemoryError: LocalizedError {
    case contextNotFound
    case powerModeNotFound
    case noProviderAvailable
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .contextNotFound:
            return "Context not found"
        case .powerModeNotFound:
            return "Power Mode not found"
        case .noProviderAvailable:
            return "No AI provider available for memory operations"
        case .generationFailed:
            return "Failed to generate memory"
        }
    }
}
