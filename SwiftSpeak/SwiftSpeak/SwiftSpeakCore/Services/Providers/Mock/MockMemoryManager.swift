//
//  MockMemoryManager.swift
//  SwiftSpeak
//
//  Mock memory manager for testing
//  Updated: Memory updates now handled by MemoryUpdateScheduler
//

import Foundation

/// Mock memory manager for unit testing
/// Provides controllable responses for memory operations
@MainActor
final class MockMemoryManager: MemoryManagerProtocol {

    // MARK: - Configuration

    /// Whether memory should be reported as enabled
    public var globalMemoryEnabled: Bool = true
    public var contextMemoryEnabled: Bool = true
    public var powerModeMemoryEnabled: Bool = true

    /// Mock memory content per tier
    public var globalMemory: String?
    public var contextMemories: [UUID: String] = [:]
    public var powerModeMemories: [UUID: String] = [:]

    // MARK: - Call Tracking

    /// Number of times getCombinedMemory was called
    private(set) var getCombinedMemoryCallCount = 0

    /// Number of times clearMemory was called
    private(set) var clearMemoryCallCount = 0

    /// Last tier passed to clearMemory
    private(set) var lastClearedTier: MemoryTierTarget?

    // MARK: - MemoryManagerProtocol

    public func getCombinedMemory(
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

    public func clearMemory(tier: MemoryTierTarget) {
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

    public func getMemory(for tier: MemoryTierTarget) -> String? {
        switch tier {
        case .global:
            return globalMemory
        case .context(let id):
            return contextMemories[id]
        case .powerMode(let id):
            return powerModeMemories[id]
        }
    }

    public func isMemoryEnabled(for tier: MemoryTierTarget) -> Bool {
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

    public func reset() {
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
    public func setContextMemory(_ memory: String, for contextId: UUID) {
        contextMemories[contextId] = memory
    }

    /// Set memory for a specific power mode
    public func setPowerModeMemory(_ memory: String, for powerModeId: UUID) {
        powerModeMemories[powerModeId] = memory
    }
}
