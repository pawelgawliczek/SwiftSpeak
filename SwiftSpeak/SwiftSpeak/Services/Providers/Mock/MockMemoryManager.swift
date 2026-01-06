//
//  MockMemoryManager.swift
//  SwiftSpeak
//
//  Mock memory manager for testing
//  Updated: Memory updates now handled by MemoryUpdateScheduler
//

import Foundation
import SwiftSpeakCore

/// Mock memory manager for unit testing
/// Provides controllable responses for memory operations
@MainActor
final class MockMemoryManager: MemoryManagerProtocol {

    // MARK: - Configuration

    /// Whether memory should be reported as enabled
    var globalMemoryEnabled: Bool = true
    var contextMemoryEnabled: Bool = true
    var powerModeMemoryEnabled: Bool = true

    /// Mock memory content per tier
    var globalMemory: String?
    var contextMemories: [UUID: String] = [:]
    var powerModeMemories: [UUID: String] = [:]

    // MARK: - Call Tracking

    /// Number of times getCombinedMemory was called
    private(set) var getCombinedMemoryCallCount = 0

    /// Number of times clearMemory was called
    private(set) var clearMemoryCallCount = 0

    /// Last tier passed to clearMemory
    private(set) var lastClearedTier: MemoryTierTarget?

    // MARK: - MemoryManagerProtocol

    func getCombinedMemory(
        context: ConversationContext?,
        powerMode: PowerMode?
    ) -> String? {
        getCombinedMemoryCallCount += 1

        var parts: [String] = []

        if globalMemoryEnabled, let global = globalMemory, !global.isEmpty {
            parts.append(global)
        }

        if let ctx = context, contextMemoryEnabled, let ctxMemory = contextMemories[ctx.id], !ctxMemory.isEmpty {
            parts.append(ctxMemory)
        }

        if let pm = powerMode, powerModeMemoryEnabled, let pmMemory = powerModeMemories[pm.id], !pmMemory.isEmpty {
            parts.append(pmMemory)
        }

        return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
    }

    func clearMemory(tier: MemoryTierTarget) {
        clearMemoryCallCount += 1
        lastClearedTier = tier

        switch tier {
        case .global:
            globalMemory = nil
        case .context(let id):
            contextMemories[id] = nil
        case .powerMode(let id):
            powerModeMemories[id] = nil
        }
    }

    func getMemory(for tier: MemoryTierTarget) -> String? {
        switch tier {
        case .global:
            return globalMemory
        case .context(let id):
            return contextMemories[id]
        case .powerMode(let id):
            return powerModeMemories[id]
        }
    }

    func isMemoryEnabled(for tier: MemoryTierTarget) -> Bool {
        switch tier {
        case .global:
            return globalMemoryEnabled
        case .context:
            return contextMemoryEnabled
        case .powerMode:
            return powerModeMemoryEnabled
        }
    }

    // MARK: - Test Helpers

    func reset() {
        getCombinedMemoryCallCount = 0
        clearMemoryCallCount = 0
        lastClearedTier = nil
        globalMemoryEnabled = true
        contextMemoryEnabled = true
        powerModeMemoryEnabled = true
        globalMemory = nil
        contextMemories = [:]
        powerModeMemories = [:]
    }

    /// Set memory for a specific context
    func setContextMemory(_ memory: String, for contextId: UUID) {
        contextMemories[contextId] = memory
    }

    /// Set memory for a specific power mode
    func setPowerModeMemory(_ memory: String, for powerModeId: UUID) {
        powerModeMemories[powerModeId] = memory
    }
}
