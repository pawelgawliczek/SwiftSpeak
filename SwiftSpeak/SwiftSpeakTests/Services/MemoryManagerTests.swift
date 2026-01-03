//
//  MemoryManagerTests.swift
//  SwiftSpeakTests
//
//  Comprehensive tests for MemoryManager three-tier memory system
//  Updated: Memory updates now handled by MemoryUpdateScheduler
//

import Foundation
import Testing
@testable import SwiftSpeak

// MARK: - Initialization Tests

@Suite("MemoryManager - Initialization")
@MainActor
struct MemoryManagerInitTests {

    @Test("Manager initializes without settings using shared")
    @MainActor
    func initializesWithSharedSettings() {
        let manager = MemoryManager()

        // Should not crash - using shared settings
        #expect(manager != nil)
    }

    @Test("Manager initializes with custom settings")
    @MainActor
    func initializesWithCustomSettings() {
        let settings = SharedSettings.shared
        let manager = MemoryManager(settings: settings)

        #expect(manager != nil)
    }

    @Test("Max memory length is 2000")
    func maxMemoryLengthIs2000() {
        #expect(MemoryManager.maxMemoryLength == 2000)
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
            #expect(Bool(true))
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

    @Test("Generation failed error description")
    func generationFailedError() {
        let error = MemoryError.generationFailed
        #expect(error.errorDescription == "Failed to generate memory")
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
        let originalUpdate = settings.lastGlobalMemoryUpdate
        settings.globalMemory = nil
        settings.lastGlobalMemoryUpdate = nil

        let manager = MemoryManager(settings: settings)
        let stats = manager.getMemoryStats(for: .global)

        #expect(stats.length == 0)
        #expect(stats.lastUpdate == nil)

        // Restore
        settings.globalMemory = originalMemory
        settings.lastGlobalMemoryUpdate = originalUpdate
    }

    @Test("Global memory stats with content")
    @MainActor
    func globalMemoryStatsWithContent() {
        let settings = SharedSettings.shared
        let originalMemory = settings.globalMemory
        let originalUpdate = settings.lastGlobalMemoryUpdate
        let testDate = Date()
        settings.globalMemory = "Test content here"
        settings.lastGlobalMemoryUpdate = testDate

        let manager = MemoryManager(settings: settings)
        let stats = manager.getMemoryStats(for: .global)

        #expect(stats.length == 17) // "Test content here".count
        #expect(stats.lastUpdate == testDate)

        // Restore
        settings.globalMemory = originalMemory
        settings.lastGlobalMemoryUpdate = originalUpdate
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
        let originalUpdate = settings.lastGlobalMemoryUpdate
        settings.globalMemory = "Some memory content"
        settings.lastGlobalMemoryUpdate = Date()

        let manager = MemoryManager(settings: settings)
        manager.clearMemory(tier: .global)

        #expect(settings.globalMemory == nil)
        #expect(settings.lastGlobalMemoryUpdate == nil)

        // Restore
        settings.globalMemory = originalMemory
        settings.lastGlobalMemoryUpdate = originalUpdate
    }

    @Test("Clear nonexistent context memory is safe")
    @MainActor
    func clearNonexistentContextMemory() {
        let manager = MemoryManager()

        // Should not throw or crash
        manager.clearMemory(tier: .context(UUID()))
        #expect(Bool(true)) // If we get here, it didn't crash
    }

    @Test("Clear nonexistent power mode memory is safe")
    @MainActor
    func clearNonexistentPowerModeMemory() {
        let manager = MemoryManager()

        // Should not throw or crash
        manager.clearMemory(tier: .powerMode(UUID()))
        #expect(Bool(true)) // If we get here, it didn't crash
    }
}

// MARK: - Combined Memory Tests

@Suite("MemoryManager - Combined Memory")
@MainActor
struct MemoryManagerCombinedTests {

    @Test("Combined memory returns nil when all empty")
    @MainActor
    func combinedMemoryEmptyReturnsNil() {
        let settings = SharedSettings.shared
        let originalMemory = settings.globalMemory
        let originalEnabled = settings.globalMemoryEnabled
        settings.globalMemory = nil
        settings.globalMemoryEnabled = true

        let manager = MemoryManager(settings: settings)
        let combined = manager.getCombinedMemory(context: nil, powerMode: nil)

        #expect(combined == nil)

        // Restore
        settings.globalMemory = originalMemory
        settings.globalMemoryEnabled = originalEnabled
    }

    @Test("Combined memory includes global when enabled")
    @MainActor
    func combinedMemoryIncludesGlobal() {
        let settings = SharedSettings.shared
        let originalMemory = settings.globalMemory
        let originalEnabled = settings.globalMemoryEnabled
        settings.globalMemory = "Global memory content"
        settings.globalMemoryEnabled = true

        let manager = MemoryManager(settings: settings)
        let combined = manager.getCombinedMemory(context: nil, powerMode: nil)

        #expect(combined != nil)
        #expect(combined!.contains("Global Memory"))
        #expect(combined!.contains("Global memory content"))

        // Restore
        settings.globalMemory = originalMemory
        settings.globalMemoryEnabled = originalEnabled
    }

    @Test("Combined memory excludes global when disabled")
    @MainActor
    func combinedMemoryExcludesGlobalWhenDisabled() {
        let settings = SharedSettings.shared
        let originalMemory = settings.globalMemory
        let originalEnabled = settings.globalMemoryEnabled
        settings.globalMemory = "Global memory content"
        settings.globalMemoryEnabled = false

        let manager = MemoryManager(settings: settings)
        let combined = manager.getCombinedMemory(context: nil, powerMode: nil)

        #expect(combined == nil)

        // Restore
        settings.globalMemory = originalMemory
        settings.globalMemoryEnabled = originalEnabled
    }

    @Test("Combined memory includes context when enabled")
    @MainActor
    func combinedMemoryIncludesContext() {
        let settings = SharedSettings.shared
        let originalEnabled = settings.globalMemoryEnabled
        settings.globalMemoryEnabled = false

        let context = ConversationContext(
            name: "Test Context",
            icon: "person",
            color: .blue,
            description: "Test",
            useContextMemory: true,
            contextMemory: "Context specific memory",
            isActive: true
        )

        let manager = MemoryManager(settings: settings)
        let combined = manager.getCombinedMemory(context: context, powerMode: nil)

        #expect(combined != nil)
        #expect(combined!.contains("Context: Test Context"))
        #expect(combined!.contains("Context specific memory"))

        // Restore
        settings.globalMemoryEnabled = originalEnabled
    }

    @Test("Combined memory excludes context when disabled")
    @MainActor
    func combinedMemoryExcludesContextWhenDisabled() {
        let settings = SharedSettings.shared
        let originalEnabled = settings.globalMemoryEnabled
        settings.globalMemoryEnabled = false

        let context = ConversationContext(
            name: "Test Context",
            icon: "person",
            color: .blue,
            description: "Test",
            useContextMemory: false, // Disabled
            contextMemory: "Context specific memory",
            isActive: true
        )

        let manager = MemoryManager(settings: settings)
        let combined = manager.getCombinedMemory(context: context, powerMode: nil)

        #expect(combined == nil)

        // Restore
        settings.globalMemoryEnabled = originalEnabled
    }

    @Test("Combined memory includes power mode when enabled")
    @MainActor
    func combinedMemoryIncludesPowerMode() {
        let settings = SharedSettings.shared
        let originalEnabled = settings.globalMemoryEnabled
        settings.globalMemoryEnabled = false

        let powerMode = PowerMode(
            name: "Test Power",
            icon: "bolt",
            iconColor: .purple,
            iconBackgroundColor: .purple,
            instruction: "Test",
            memoryEnabled: true,
            memory: "Power mode memory"
        )

        let manager = MemoryManager(settings: settings)
        let combined = manager.getCombinedMemory(context: nil, powerMode: powerMode)

        #expect(combined != nil)
        #expect(combined!.contains("Power Mode: Test Power"))
        #expect(combined!.contains("Power mode memory"))

        // Restore
        settings.globalMemoryEnabled = originalEnabled
    }

    @Test("Combined memory combines all tiers")
    @MainActor
    func combinedMemoryAllTiers() {
        let settings = SharedSettings.shared
        let originalMemory = settings.globalMemory
        let originalEnabled = settings.globalMemoryEnabled
        settings.globalMemory = "Global memory"
        settings.globalMemoryEnabled = true

        let context = ConversationContext(
            name: "Work",
            icon: "briefcase",
            color: .blue,
            description: "Work context",
            useContextMemory: true,
            contextMemory: "Context memory",
            isActive: true
        )

        let powerMode = PowerMode(
            name: "Assistant",
            icon: "sparkles",
            iconColor: .orange,
            iconBackgroundColor: .orange,
            instruction: "Help",
            memoryEnabled: true,
            memory: "Power memory"
        )

        let manager = MemoryManager(settings: settings)
        let combined = manager.getCombinedMemory(context: context, powerMode: powerMode)

        #expect(combined != nil)
        #expect(combined!.contains("Global Memory"))
        #expect(combined!.contains("Global memory"))
        #expect(combined!.contains("Context: Work"))
        #expect(combined!.contains("Context memory"))
        #expect(combined!.contains("Power Mode: Assistant"))
        #expect(combined!.contains("Power memory"))

        // Restore
        settings.globalMemory = originalMemory
        settings.globalMemoryEnabled = originalEnabled
    }
}

// MARK: - Unprocessed Records Tests

@Suite("MemoryManager - Unprocessed Records")
@MainActor
struct MemoryManagerUnprocessedTests {

    @Test("Has unprocessed records returns false when all processed")
    @MainActor
    func hasUnprocessedRecordsFalseWhenEmpty() {
        let settings = SharedSettings.shared
        let originalEnabled = settings.globalMemoryEnabled
        settings.globalMemoryEnabled = false // Disable to avoid checking

        let manager = MemoryManager(settings: settings)
        let hasUnprocessed = manager.hasUnprocessedRecords()

        // With nothing enabled, should be false
        #expect(hasUnprocessed == false)

        // Restore
        settings.globalMemoryEnabled = originalEnabled
    }
}

// MARK: - Clear All Memory Tests

@Suite("MemoryManager - Clear All Memory")
@MainActor
struct MemoryManagerClearAllTests {

    @Test("Clear all memory clears global")
    @MainActor
    func clearAllClearsGlobal() {
        let settings = SharedSettings.shared
        let originalMemory = settings.globalMemory
        let originalUpdate = settings.lastGlobalMemoryUpdate
        settings.globalMemory = "Test memory"
        settings.lastGlobalMemoryUpdate = Date()

        let manager = MemoryManager(settings: settings)
        manager.clearAllMemory()

        #expect(settings.globalMemory == nil)
        #expect(settings.lastGlobalMemoryUpdate == nil)

        // Restore
        settings.globalMemory = originalMemory
        settings.lastGlobalMemoryUpdate = originalUpdate
    }
}
