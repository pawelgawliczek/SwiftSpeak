//
//  MockMemoryManager.swift
//  SwiftSpeak
//
//  Mock memory manager for testing PowerModeOrchestrator
//

import Foundation

/// Mock memory manager for unit testing
/// Tracks memory update calls without actual LLM operations
@MainActor
final class MockMemoryManager: MemoryManagerProtocol {

    // MARK: - Configuration

    /// Whether memory updates should succeed
    var shouldSucceed: Bool = true

    /// Simulated delay for memory operations
    var delay: TimeInterval = 0

    // MARK: - Call Tracking

    /// Number of times updateMemory was called
    private(set) var updateMemoryCallCount = 0

    /// Last transcription passed to updateMemory
    private(set) var lastTranscription: String?

    /// Last context passed to updateMemory
    private(set) var lastContext: ConversationContext?

    /// Last power mode passed to updateMemory
    private(set) var lastPowerMode: PowerMode?

    // MARK: - Results

    /// Custom results to return
    var customResults: [MemoryUpdateResult]?

    // MARK: - Methods

    func updateMemory(
        from transcription: String,
        context: ConversationContext?,
        powerMode: PowerMode?
    ) async -> [MemoryUpdateResult] {
        updateMemoryCallCount += 1
        lastTranscription = transcription
        lastContext = context
        lastPowerMode = powerMode

        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if let results = customResults {
            return results
        }

        // Generate default successful results based on what was passed
        var results: [MemoryUpdateResult] = []

        // Simulate global memory update
        results.append(MemoryUpdateResult(
            tier: .global,
            previousLength: 0,
            newLength: transcription.count,
            wasCompressed: false,
            success: shouldSucceed,
            error: nil
        ))

        if let ctx = context {
            results.append(MemoryUpdateResult(
                tier: .context(ctx.id),
                previousLength: 0,
                newLength: transcription.count,
                wasCompressed: false,
                success: shouldSucceed,
                error: nil
            ))
        }

        if let pm = powerMode {
            results.append(MemoryUpdateResult(
                tier: .powerMode(pm.id),
                previousLength: 0,
                newLength: transcription.count,
                wasCompressed: false,
                success: shouldSucceed,
                error: nil
            ))
        }

        return results
    }

    // MARK: - Test Helpers

    func reset() {
        updateMemoryCallCount = 0
        lastTranscription = nil
        lastContext = nil
        lastPowerMode = nil
        shouldSucceed = true
        delay = 0
        customResults = nil
    }
}
