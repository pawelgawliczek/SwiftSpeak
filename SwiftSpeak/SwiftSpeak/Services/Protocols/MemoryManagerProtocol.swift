//
//  MemoryManagerProtocol.swift
//  SwiftSpeak
//
//  Protocol for memory manager to enable testing
//

import Foundation

/// Protocol for memory management operations
/// Enables dependency injection and testing
@MainActor
protocol MemoryManagerProtocol {
    /// Update memory after a conversation completes
    func updateMemory(
        from transcription: String,
        context: ConversationContext?,
        powerMode: PowerMode?
    ) async -> [MemoryUpdateResult]
}

// MARK: - MemoryManager Conformance

extension MemoryManager: MemoryManagerProtocol {}
