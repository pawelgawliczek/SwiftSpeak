//
//  MemoryManagerProtocol.swift
//  SwiftSpeak
//
//  Protocol for memory manager to enable testing
//  NOTE: Per-transcription memory updates removed - now uses batch updates via MemoryUpdateScheduler
//

import Foundation

/// Protocol for memory management operations
/// Enables dependency injection and testing
///
/// NOTE: Memory updates are now handled by MemoryUpdateScheduler.
/// This protocol provides access to memory for prompt injection and clearing.
@MainActor
public protocol MemoryManagerProtocol {
    /// Get combined memory for prompt injection
    public func getCombinedMemory(
        context: ConversationContext?,
        powerMode: PowerMode?
    ) -> String?

    /// Clear memory for a specific tier
    public func clearMemory(tier: MemoryTierTarget)

    /// Get the current memory for a tier
    public func getMemory(for tier: MemoryTierTarget) -> String?

    /// Check if memory is enabled for a tier
    public func isMemoryEnabled(for tier: MemoryTierTarget) -> Bool
}

// MARK: - MemoryManager Conformance

public extension MemoryManager: MemoryManagerProtocol {}
