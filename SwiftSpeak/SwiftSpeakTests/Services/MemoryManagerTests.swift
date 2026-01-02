//
//  MemoryManagerTests.swift
//  SwiftSpeakTests
//
//  Comprehensive tests for MemoryManager three-tier memory system
//

import Foundation
import Testing
@testable import SwiftSpeak

// MARK: - Initialization Tests

@Suite("MemoryManager - Initialization")
@MainActor
struct MemoryManagerInitTests {

    @Test("Initial state is not updating")
    @MainActor
    func initialStateNotUpdating() {
        let manager = MemoryManager()

        #expect(manager.isUpdating == false)
        #expect(manager.lastError == nil)
    }

    @Test("Compression threshold is 2000")
    func compressionThresholdIs2000() {
        #expect(MemoryManager.compressionThreshold == 2000)
    }

    @Test("Compression target is 1500")
    func compressionTargetIs1500() {
        #expect(MemoryManager.compressionTarget == 1500)
    }

    @Test("Max recent entries is 10")
    func maxRecentEntriesIs10() {
        #expect(MemoryManager.maxRecentEntries == 10)
    }
}

// MARK: - Memory Tier Target Tests

@Suite("MemoryManager - MemoryTierTarget")
@MainActor
struct MemoryTierTargetTests {

    @Test("Global tier target")
    func globalTierTarget() {
        let tier = MemoryTierTarget.global
        if case .global = tier {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected global tier")
        }
    }

    @Test("Context tier target with UUID")
    func contextTierTarget() {
        let uuid = UUID()
        let tier = MemoryTierTarget.context(uuid)
        if case .context(let id) = tier {
            #expect(id == uuid)
        } else {
            #expect(Bool(false), "Expected context tier")
        }
    }

    @Test("PowerMode tier target with UUID")
    func powerModeTierTarget() {
        let uuid = UUID()
        let tier = MemoryTierTarget.powerMode(uuid)
        if case .powerMode(let id) = tier {
            #expect(id == uuid)
        } else {
            #expect(Bool(false), "Expected powerMode tier")
        }
    }
}

// MARK: - Memory Update Result Tests

@Suite("MemoryManager - MemoryUpdateResult")
@MainActor
struct MemoryUpdateResultTests {

    @Test("Successful result properties")
    func successfulResultProperties() {
        let result = MemoryUpdateResult(
            tier: .global,
            previousLength: 100,
            newLength: 150,
            wasCompressed: false,
            success: true,
            error: nil
        )

        #expect(result.previousLength == 100)
        #expect(result.newLength == 150)
        #expect(result.wasCompressed == false)
        #expect(result.success == true)
        #expect(result.error == nil)
    }

    @Test("Failed result with error")
    func failedResultWithError() {
        let result = MemoryUpdateResult(
            tier: .global,
            previousLength: 100,
            newLength: 100,
            wasCompressed: false,
            success: false,
            error: MemoryError.noProviderAvailable
        )

        #expect(result.success == false)
        #expect(result.error != nil)
    }

    @Test("Compressed result")
    func compressedResult() {
        let result = MemoryUpdateResult(
            tier: .global,
            previousLength: 2500,
            newLength: 1400,
            wasCompressed: true,
            success: true,
            error: nil
        )

        #expect(result.wasCompressed == true)
        #expect(result.newLength < result.previousLength)
    }
}

// MARK: - Memory Error Tests

@Suite("MemoryManager - MemoryError")
@MainActor
struct MemoryErrorTests {

    @Test("Context not found error description")
    func contextNotFoundError() {
        let error = MemoryError.contextNotFound
        #expect(error.errorDescription == "Context not found")
    }

    @Test("Power mode not found error description")
    func powerModeNotFoundError() {
        let error = MemoryError.powerModeNotFound
        #expect(error.errorDescription == "Power Mode not found")
    }

    @Test("No provider available error description")
    func noProviderAvailableError() {
        let error = MemoryError.noProviderAvailable
        #expect(error.errorDescription == "No AI provider available for memory operations")
    }

    @Test("Compression failed error description")
    func compressionFailedError() {
        let error = MemoryError.compressionFailed
        #expect(error.errorDescription == "Failed to compress memory")
    }
}

// MARK: - Get Memory Tests

@Suite("MemoryManager - Get Memory")
@MainActor
struct MemoryManagerGetTests {

    @Test("Get global memory returns nil when empty")
    @MainActor
    func getGlobalMemoryEmpty() {
        let settings = SharedSettings.shared
        let originalMemory = settings.globalMemory
        settings.globalMemory = nil

        let manager = MemoryManager(settings: settings)
        let memory = manager.getMemory(for: .global)

        #expect(memory == nil)

        // Restore
        settings.globalMemory = originalMemory
    }

    @Test("Get global memory returns value when set")
    @MainActor
    func getGlobalMemoryWithValue() {
        let settings = SharedSettings.shared
        let originalMemory = settings.globalMemory
        settings.globalMemory = "Test memory content"

        let manager = MemoryManager(settings: settings)
        let memory = manager.getMemory(for: .global)

        #expect(memory == "Test memory content")

        // Restore
        settings.globalMemory = originalMemory
    }

    @Test("Get context memory returns nil for nonexistent context")
    @MainActor
    func getContextMemoryNonexistent() {
        let manager = MemoryManager()
        let memory = manager.getMemory(for: .context(UUID()))

        #expect(memory == nil)
    }

    @Test("Get power mode memory returns nil for nonexistent power mode")
    @MainActor
    func getPowerModeMemoryNonexistent() {
        let manager = MemoryManager()
        let memory = manager.getMemory(for: .powerMode(UUID()))

        #expect(memory == nil)
    }
}

// MARK: - Is Memory Enabled Tests

@Suite("MemoryManager - Is Memory Enabled")
@MainActor
struct MemoryManagerEnabledTests {

    @Test("Global memory enabled reflects settings")
    @MainActor
    func globalMemoryEnabledReflectsSettings() {
        let settings = SharedSettings.shared
        let originalEnabled = settings.globalMemoryEnabled

        settings.globalMemoryEnabled = true
        let manager = MemoryManager(settings: settings)
        #expect(manager.isMemoryEnabled(for: .global) == true)

        settings.globalMemoryEnabled = false
        #expect(manager.isMemoryEnabled(for: .global) == false)

        // Restore
        settings.globalMemoryEnabled = originalEnabled
    }

    @Test("Context memory enabled returns false for nonexistent context")
    @MainActor
    func contextMemoryEnabledNonexistent() {
        let manager = MemoryManager()
        let enabled = manager.isMemoryEnabled(for: .context(UUID()))

        #expect(enabled == false)
    }

    @Test("Power mode memory enabled returns false for nonexistent power mode")
    @MainActor
    func powerModeMemoryEnabledNonexistent() {
        let manager = MemoryManager()
        let enabled = manager.isMemoryEnabled(for: .powerMode(UUID()))

        #expect(enabled == false)
    }
}

// MARK: - Memory Stats Tests

@Suite("MemoryManager - Memory Stats")
@MainActor
struct MemoryManagerStatsTests {

    @Test("Global memory stats with empty memory")
    @MainActor
    func globalMemoryStatsEmpty() {
        let settings = SharedSettings.shared
        let originalMemory = settings.globalMemory
        settings.globalMemory = nil

        let manager = MemoryManager(settings: settings)
        let stats = manager.getMemoryStats(for: .global)

        #expect(stats.length == 0)
        #expect(stats.lastUpdate == nil)

        // Restore
        settings.globalMemory = originalMemory
    }

    @Test("Global memory stats with content")
    @MainActor
    func globalMemoryStatsWithContent() {
        let settings = SharedSettings.shared
        let originalMemory = settings.globalMemory
        settings.globalMemory = "Test content here"

        let manager = MemoryManager(settings: settings)
        let stats = manager.getMemoryStats(for: .global)

        #expect(stats.length == 17) // "Test content here".count
        #expect(stats.lastUpdate == nil) // Global doesn't track lastUpdate

        // Restore
        settings.globalMemory = originalMemory
    }

    @Test("Context memory stats for nonexistent context")
    @MainActor
    func contextMemoryStatsNonexistent() {
        let manager = MemoryManager()
        let stats = manager.getMemoryStats(for: .context(UUID()))

        #expect(stats.length == 0)
        #expect(stats.lastUpdate == nil)
    }

    @Test("Power mode memory stats for nonexistent power mode")
    @MainActor
    func powerModeMemoryStatsNonexistent() {
        let manager = MemoryManager()
        let stats = manager.getMemoryStats(for: .powerMode(UUID()))

        #expect(stats.length == 0)
        #expect(stats.lastUpdate == nil)
    }
}

// MARK: - Clear Memory Tests

@Suite("MemoryManager - Clear Memory")
@MainActor
struct MemoryManagerClearTests {

    @Test("Clear global memory sets to nil")
    @MainActor
    func clearGlobalMemory() {
        let settings = SharedSettings.shared
        let originalMemory = settings.globalMemory
        settings.globalMemory = "Some memory content"

        let manager = MemoryManager(settings: settings)
        manager.clearMemory(tier: .global)

        #expect(settings.globalMemory == nil)

        // Restore
        settings.globalMemory = originalMemory
    }

    @Test("Clear nonexistent context memory is safe")
    @MainActor
    func clearNonexistentContextMemory() {
        let manager = MemoryManager()

        // Should not throw or crash
        manager.clearMemory(tier: .context(UUID()))
        #expect(true) // If we get here, it didn't crash
    }

    @Test("Clear nonexistent power mode memory is safe")
    @MainActor
    func clearNonexistentPowerModeMemory() {
        let manager = MemoryManager()

        // Should not throw or crash
        manager.clearMemory(tier: .powerMode(UUID()))
        #expect(true) // If we get here, it didn't crash
    }
}

// MARK: - Update Memory Tests

@Suite("MemoryManager - Update Memory")
@MainActor
struct MemoryManagerUpdateTests {

    @Test("Empty transcription returns no results")
    @MainActor
    func emptyTranscriptionNoResults() async {
        let manager = MemoryManager()

        let results = await manager.updateMemory(from: "", context: nil, powerMode: nil)

        #expect(results.isEmpty)
    }

    @Test("Whitespace-only transcription returns no results")
    @MainActor
    func whitespaceOnlyNoResults() async {
        let manager = MemoryManager()

        let results = await manager.updateMemory(from: "   \n\t  ", context: nil, powerMode: nil)

        #expect(results.isEmpty)
    }

    @Test("Update sets isUpdating during operation")
    @MainActor
    func updateSetsIsUpdating() async {
        let settings = SharedSettings.shared
        let originalEnabled = settings.globalMemoryEnabled
        settings.globalMemoryEnabled = true

        let manager = MemoryManager(settings: settings)

        // Start update (will complete quickly without provider)
        let _ = await manager.updateMemory(from: "Test", context: nil, powerMode: nil)

        // After completion, isUpdating should be false
        #expect(manager.isUpdating == false)

        // Restore
        settings.globalMemoryEnabled = originalEnabled
    }

    @Test("Update with global memory disabled skips global tier")
    @MainActor
    func updateSkipsDisabledGlobalMemory() async {
        let settings = SharedSettings.shared
        let originalEnabled = settings.globalMemoryEnabled
        settings.globalMemoryEnabled = false

        let manager = MemoryManager(settings: settings)

        let results = await manager.updateMemory(
            from: "Test transcription",
            context: nil,
            powerMode: nil
        )

        // With global disabled and no context/powerMode, should be empty
        #expect(results.isEmpty)

        // Restore
        settings.globalMemoryEnabled = originalEnabled
    }

    @Test("Update with context memory disabled skips context tier")
    @MainActor
    func updateSkipsDisabledContextMemory() async {
        let settings = SharedSettings.shared
        let originalEnabled = settings.globalMemoryEnabled
        settings.globalMemoryEnabled = false

        let context = ConversationContext(
            name: "Test",
            icon: "person",
            color: .blue,
            description: "Test",
            useContextMemory: false, // Disabled
            isActive: true
        )

        let manager = MemoryManager(settings: settings)

        let results = await manager.updateMemory(
            from: "Test transcription",
            context: context,
            powerMode: nil
        )

        // Context memory disabled, so no context tier update
        let hasContextTier = results.contains { result in
            if case .context = result.tier { return true }
            return false
        }
        #expect(hasContextTier == false)

        // Restore
        settings.globalMemoryEnabled = originalEnabled
    }

    @Test("Update with power mode memory disabled skips power mode tier")
    @MainActor
    func updateSkipsDisabledPowerModeMemory() async {
        let settings = SharedSettings.shared
        let originalEnabled = settings.globalMemoryEnabled
        settings.globalMemoryEnabled = false

        let powerMode = PowerMode(
            name: "Test",
            icon: "bolt",
            iconColor: .purple,
            iconBackgroundColor: .purple,
            instruction: "Test",
            memoryEnabled: false // Disabled
        )

        let manager = MemoryManager(settings: settings)

        let results = await manager.updateMemory(
            from: "Test transcription",
            context: nil,
            powerMode: powerMode
        )

        // Power mode memory disabled, so no power mode tier update
        let hasPowerModeTier = results.contains { result in
            if case .powerMode = result.tier { return true }
            return false
        }
        #expect(hasPowerModeTier == false)

        // Restore
        settings.globalMemoryEnabled = originalEnabled
    }
}

// MARK: - Memory Combining Logic Tests

@Suite("MemoryManager - Memory Combining")
@MainActor
struct MemoryManagerCombiningTests {

    @Test("Short text used directly for summary")
    @MainActor
    func shortTextUsedDirectly() async {
        let settings = SharedSettings.shared
        let originalEnabled = settings.globalMemoryEnabled
        let originalMemory = settings.globalMemory
        settings.globalMemoryEnabled = true
        settings.globalMemory = nil

        let manager = MemoryManager(settings: settings)

        // Short text (< 200 chars) should be used directly
        let shortText = "This is a short test."
        let _ = await manager.updateMemory(from: shortText, context: nil, powerMode: nil)

        // Memory should contain the short text (may have timestamp added)
        let memory = settings.globalMemory ?? ""
        #expect(memory.contains("short test"))

        // Restore
        settings.globalMemoryEnabled = originalEnabled
        settings.globalMemory = originalMemory
    }
}
