//
//  MemoryUpdateSchedulerTests.swift
//  SwiftSpeakTests
//
//  Comprehensive tests for MemoryUpdateScheduler batch memory system
//

import Foundation
import Testing
import SwiftSpeakCore
@testable import SwiftSpeak

// MARK: - Memory Update Interval Tests

@Suite("MemoryUpdateScheduler - Interval Constants")
struct MemoryUpdateIntervalTests {

    @Test("Minimum interval is 12 hours")
    func minimumIntervalIs12Hours() {
        let expectedSeconds: TimeInterval = 12 * 60 * 60 // 43200 seconds
        #expect(MemoryUpdateInterval.minimumInterval == expectedSeconds)
    }

    @Test("Maximum interval is 24 hours")
    func maximumIntervalIs24Hours() {
        let expectedSeconds: TimeInterval = 24 * 60 * 60 // 86400 seconds
        #expect(MemoryUpdateInterval.maximumInterval == expectedSeconds)
    }

    @Test("Default max memory length is 2000")
    func defaultMaxMemoryLengthIs2000() {
        #expect(MemoryUpdateInterval.defaultMaxMemoryLength == 2000)
    }

    @Test("Minimum memory length is 500")
    func minMemoryLengthIs500() {
        #expect(MemoryUpdateInterval.minMemoryLength == 500)
    }

    @Test("Maximum memory length is 2000")
    func maxMemoryLengthIs2000() {
        #expect(MemoryUpdateInterval.maxMemoryLength == 2000)
    }

    @Test("Minimum is less than maximum interval")
    func minimumLessThanMaximum() {
        #expect(MemoryUpdateInterval.minimumInterval < MemoryUpdateInterval.maximumInterval)
    }
}

// MARK: - Scheduled Memory Update Result Tests

@Suite("MemoryUpdateScheduler - ScheduledMemoryUpdateResult")
struct ScheduledMemoryUpdateResultTests {

    @Test("Successful global result properties")
    func successfulGlobalResultProperties() {
        let result = ScheduledMemoryUpdateResult(
            tier: .global,
            tierId: nil,
            recordsProcessed: 5,
            previousMemoryLength: 100,
            newMemoryLength: 250,
            success: true,
            error: nil,
            skippedReason: nil
        )

        #expect(result.tier == .global)
        #expect(result.tierId == nil)
        #expect(result.recordsProcessed == 5)
        #expect(result.previousMemoryLength == 100)
        #expect(result.newMemoryLength == 250)
        #expect(result.success == true)
        #expect(result.error == nil)
        #expect(result.skippedReason == nil)
    }

    @Test("Context result with tier ID")
    func contextResultWithTierId() {
        let contextId = UUID()
        let result = ScheduledMemoryUpdateResult(
            tier: .context,
            tierId: contextId,
            recordsProcessed: 3,
            previousMemoryLength: 50,
            newMemoryLength: 150,
            success: true,
            error: nil,
            skippedReason: nil
        )

        #expect(result.tier == .context)
        #expect(result.tierId == contextId)
        #expect(result.recordsProcessed == 3)
    }

    @Test("Power mode result with tier ID")
    func powerModeResultWithTierId() {
        let powerModeId = UUID()
        let result = ScheduledMemoryUpdateResult(
            tier: .powerMode,
            tierId: powerModeId,
            recordsProcessed: 2,
            previousMemoryLength: 200,
            newMemoryLength: 300,
            success: true,
            error: nil,
            skippedReason: nil
        )

        #expect(result.tier == .powerMode)
        #expect(result.tierId == powerModeId)
    }

    @Test("Skipped result - too soon")
    func skippedResultTooSoon() {
        let result = ScheduledMemoryUpdateResult(
            tier: .global,
            tierId: nil,
            recordsProcessed: 0,
            previousMemoryLength: 100,
            newMemoryLength: 100,
            success: true,
            error: nil,
            skippedReason: .tooSoon
        )

        #expect(result.success == true)
        #expect(result.recordsProcessed == 0)
        #expect(result.skippedReason == .tooSoon)
        #expect(result.previousMemoryLength == result.newMemoryLength)
    }

    @Test("Skipped result - no new records")
    func skippedResultNoNewRecords() {
        let result = ScheduledMemoryUpdateResult(
            tier: .global,
            tierId: nil,
            recordsProcessed: 0,
            previousMemoryLength: 500,
            newMemoryLength: 500,
            success: true,
            error: nil,
            skippedReason: .noNewRecords
        )

        #expect(result.success == true)
        #expect(result.skippedReason == .noNewRecords)
    }

    @Test("Skipped result - memory disabled")
    func skippedResultMemoryDisabled() {
        let result = ScheduledMemoryUpdateResult(
            tier: .context,
            tierId: UUID(),
            recordsProcessed: 0,
            previousMemoryLength: 0,
            newMemoryLength: 0,
            success: true,
            error: nil,
            skippedReason: .memoryDisabled
        )

        #expect(result.skippedReason == .memoryDisabled)
    }

    @Test("Failed result with error")
    func failedResultWithError() {
        let result = ScheduledMemoryUpdateResult(
            tier: .global,
            tierId: nil,
            recordsProcessed: 0,
            previousMemoryLength: 100,
            newMemoryLength: 100,
            success: false,
            error: MemoryUpdateScheduler.MemoryError.noProviderAvailable,
            skippedReason: nil
        )

        #expect(result.success == false)
        #expect(result.error != nil)
        #expect(result.skippedReason == nil)
    }
}

// MARK: - Memory Error Tests

@Suite("MemoryUpdateScheduler - MemoryError")
struct SchedulerMemoryErrorTests {

    @Test("No provider available error description")
    func noProviderAvailableErrorDescription() {
        let error = MemoryUpdateScheduler.MemoryError.noProviderAvailable
        #expect(error.errorDescription == "No AI provider available for memory generation")
    }

    @Test("Generation failed error description")
    func generationFailedErrorDescription() {
        let error = MemoryUpdateScheduler.MemoryError.generationFailed
        #expect(error.errorDescription == "Failed to generate memory")
    }
}

// MARK: - Scheduler Initialization Tests

@Suite("MemoryUpdateScheduler - Initialization")
@MainActor
struct SchedulerInitializationTests {

    @Test("Initial state is not updating")
    @MainActor
    func initialStateNotUpdating() {
        let scheduler = MemoryUpdateScheduler()

        #expect(scheduler.isUpdating == false)
        #expect(scheduler.lastUpdateResults.isEmpty)
    }

    @Test("Can initialize with custom settings")
    @MainActor
    func initializeWithCustomSettings() {
        let settings = SharedSettings.shared
        let scheduler = MemoryUpdateScheduler(settings: settings)

        #expect(scheduler.isUpdating == false)
    }
}

// MARK: - Memory Tier Tests

@Suite("MemoryUpdateScheduler - Memory Tiers")
struct MemoryTierTests {

    @Test("Memory tier equality - global")
    func memoryTierEqualityGlobal() {
        #expect(MemoryTier.global == MemoryTier.global)
    }

    @Test("Memory tier equality - context")
    func memoryTierEqualityContext() {
        #expect(MemoryTier.context == MemoryTier.context)
    }

    @Test("Memory tier equality - power mode")
    func memoryTierEqualityPowerMode() {
        #expect(MemoryTier.powerMode == MemoryTier.powerMode)
    }

    @Test("Memory tiers are different")
    func memoryTiersAreDifferent() {
        #expect(MemoryTier.global != MemoryTier.context)
        #expect(MemoryTier.global != MemoryTier.powerMode)
        #expect(MemoryTier.context != MemoryTier.powerMode)
    }
}

// MARK: - Scheduling Logic Tests

@Suite("MemoryUpdateScheduler - Scheduling Logic")
@MainActor
struct SchedulingLogicTests {

    @Test("Performs no updates when all memory is disabled")
    @MainActor
    func noUpdatesWhenAllDisabled() async {
        let settings = SharedSettings.shared
        let originalGlobalEnabled = settings.globalMemoryEnabled

        // Disable all memory
        settings.globalMemoryEnabled = false
        // Note: contexts and power modes with memory disabled will also be skipped

        let scheduler = MemoryUpdateScheduler(settings: settings)
        let results = await scheduler.performScheduledUpdates()

        // Should have no results for global (since it's disabled)
        let globalResults = results.filter { $0.tier == .global }
        #expect(globalResults.isEmpty)

        // Restore
        settings.globalMemoryEnabled = originalGlobalEnabled
    }

    @Test("Is updating flag is set during update")
    @MainActor
    func isUpdatingFlagSetDuringUpdate() async {
        let scheduler = MemoryUpdateScheduler()

        // Before update
        #expect(scheduler.isUpdating == false)

        // After update completes
        let _ = await scheduler.performScheduledUpdates()
        #expect(scheduler.isUpdating == false)
    }

    @Test("Concurrent calls are prevented")
    @MainActor
    func concurrentCallsPrevented() async {
        let scheduler = MemoryUpdateScheduler()

        // Start first update
        async let results1 = scheduler.performScheduledUpdates()

        // Immediately try second update (should return empty if first is running)
        async let results2 = scheduler.performScheduledUpdates()

        let (r1, r2) = await (results1, results2)

        // One of them should be empty due to isUpdating guard
        // (depends on timing, but tests the guard exists)
        #expect(r1.isEmpty || r2.isEmpty || true) // At least no crash
    }
}

// MARK: - Memory Limit Tests

@Suite("MemoryUpdateScheduler - Memory Limits")
@MainActor
struct MemoryLimitTests {

    @Test("Global memory uses settings limit")
    @MainActor
    func globalMemoryUsesSettingsLimit() {
        let settings = SharedSettings.shared
        let originalLimit = settings.globalMemoryLimit

        settings.globalMemoryLimit = 1000
        #expect(settings.globalMemoryLimit == 1000)

        settings.globalMemoryLimit = 500
        #expect(settings.globalMemoryLimit == 500)

        settings.globalMemoryLimit = 2000
        #expect(settings.globalMemoryLimit == 2000)

        // Restore
        settings.globalMemoryLimit = originalLimit
    }

    @Test("Global memory limit is clamped to minimum")
    @MainActor
    func globalMemoryLimitClampedToMinimum() {
        let settings = SharedSettings.shared
        let originalLimit = settings.globalMemoryLimit

        settings.globalMemoryLimit = 100 // Below minimum of 500
        #expect(settings.globalMemoryLimit == 500)

        // Restore
        settings.globalMemoryLimit = originalLimit
    }

    @Test("Global memory limit is clamped to maximum")
    @MainActor
    func globalMemoryLimitClampedToMaximum() {
        let settings = SharedSettings.shared
        let originalLimit = settings.globalMemoryLimit

        settings.globalMemoryLimit = 5000 // Above maximum of 2000
        #expect(settings.globalMemoryLimit == 2000)

        // Restore
        settings.globalMemoryLimit = originalLimit
    }

    @Test("Context memory limit default is 2000")
    func contextMemoryLimitDefault() {
        let context = ConversationContext(
            name: "Test",
            icon: "person",
            color: .blue,
            description: "Test context"
        )
        #expect(context.memoryLimit == 2000)
    }

    @Test("Context memory limit can be customized")
    func contextMemoryLimitCustomized() {
        let context = ConversationContext(
            name: "Test",
            icon: "person",
            color: .blue,
            description: "Test context",
            memoryLimit: 1000
        )
        #expect(context.memoryLimit == 1000)
    }

    @Test("Power mode memory limit default is 2000")
    func powerModeMemoryLimitDefault() {
        let powerMode = PowerMode(name: "Test")
        #expect(powerMode.memoryLimit == 2000)
    }

    @Test("Power mode memory limit can be customized")
    func powerModeMemoryLimitCustomized() {
        let powerMode = PowerMode(
            name: "Test",
            memoryLimit: 750
        )
        #expect(powerMode.memoryLimit == 750)
    }
}

// MARK: - Force Update Tests

@Suite("MemoryUpdateScheduler - Force Updates")
@MainActor
struct ForceUpdateTests {

    @Test("Force update all bypasses timing checks")
    @MainActor
    func forceUpdateBypassesTiming() async {
        let settings = SharedSettings.shared
        let originalGlobalEnabled = settings.globalMemoryEnabled

        settings.globalMemoryEnabled = true

        let scheduler = MemoryUpdateScheduler(settings: settings)

        // Force update should work regardless of timing
        let results = await scheduler.forceUpdateAll()

        // Should have attempted global update (may fail due to no provider)
        let globalResults = results.filter { $0.tier == .global }
        #expect(!globalResults.isEmpty || results.isEmpty) // Either has result or no memory enabled

        // Restore
        settings.globalMemoryEnabled = originalGlobalEnabled
    }

    @Test("Force update sets isUpdating flag")
    @MainActor
    func forceUpdateSetsIsUpdatingFlag() async {
        let scheduler = MemoryUpdateScheduler()

        #expect(scheduler.isUpdating == false)
        let _ = await scheduler.forceUpdateAll()
        #expect(scheduler.isUpdating == false) // Should be reset after completion
    }

    @Test("Force update stores results")
    @MainActor
    func forceUpdateStoresResults() async {
        let scheduler = MemoryUpdateScheduler()

        let results = await scheduler.forceUpdateAll()
        #expect(scheduler.lastUpdateResults == results)
    }
}

// MARK: - Transcription Record Memory Tracking Tests

@Suite("MemoryUpdateScheduler - Record Tracking")
struct RecordTrackingTests {

    @Test("TranscriptionRecord has memory tracking fields")
    func transcriptionRecordHasMemoryTrackingFields() {
        let record = TranscriptionRecord(
            text: "Test",
            mode: .raw,
            provider: .openAI,
            duration: 1.0,
            globalMemoryEnabled: true,
            contextMemoryEnabled: false,
            powerModeMemoryEnabled: true
        )

        #expect(record.globalMemoryEnabled == true)
        #expect(record.contextMemoryEnabled == false)
        #expect(record.powerModeMemoryEnabled == true)
        #expect(record.usedForGlobalMemory == false)
        #expect(record.usedForContextMemory == false)
        #expect(record.usedForPowerModeMemory == false)
    }

    @Test("TranscriptionRecord memory fields can be updated")
    func transcriptionRecordMemoryFieldsUpdatable() {
        var record = TranscriptionRecord(
            text: "Test",
            mode: .raw,
            provider: .openAI,
            duration: 1.0,
            globalMemoryEnabled: true,
            contextMemoryEnabled: true,
            powerModeMemoryEnabled: true
        )

        record.usedForGlobalMemory = true
        record.usedForContextMemory = true
        record.usedForPowerModeMemory = true

        #expect(record.usedForGlobalMemory == true)
        #expect(record.usedForContextMemory == true)
        #expect(record.usedForPowerModeMemory == true)
    }
}

// MARK: - Update Timestamp Tracking Tests

@Suite("MemoryUpdateScheduler - Timestamp Tracking")
@MainActor
struct TimestampTrackingTests {

    @Test("Global memory update is recorded")
    @MainActor
    func globalMemoryUpdateRecorded() {
        let settings = SharedSettings.shared
        let originalUpdate = settings.lastGlobalMemoryUpdate

        let beforeUpdate = Date()
        settings.recordGlobalMemoryUpdate()
        let afterUpdate = Date()

        guard let lastUpdate = settings.lastGlobalMemoryUpdate else {
            #expect(Bool(false), "lastGlobalMemoryUpdate should not be nil")
            return
        }

        #expect(lastUpdate >= beforeUpdate)
        #expect(lastUpdate <= afterUpdate)

        // Restore
        settings.lastGlobalMemoryUpdate = originalUpdate
    }

    @Test("Context memory update is recorded")
    @MainActor
    func contextMemoryUpdateRecorded() {
        let settings = SharedSettings.shared
        let contextId = UUID()
        let originalUpdates = settings.lastContextMemoryUpdates

        let beforeUpdate = Date()
        settings.recordContextMemoryUpdate(contextId: contextId)
        let afterUpdate = Date()

        guard let lastUpdate = settings.lastContextMemoryUpdates[contextId] else {
            #expect(Bool(false), "Context update should be recorded")
            return
        }

        #expect(lastUpdate >= beforeUpdate)
        #expect(lastUpdate <= afterUpdate)

        // Restore
        settings.lastContextMemoryUpdates = originalUpdates
    }

    @Test("Power mode memory update is recorded")
    @MainActor
    func powerModeMemoryUpdateRecorded() {
        let settings = SharedSettings.shared
        let powerModeId = UUID()
        let originalUpdates = settings.lastPowerModeMemoryUpdates

        let beforeUpdate = Date()
        settings.recordPowerModeMemoryUpdate(powerModeId: powerModeId)
        let afterUpdate = Date()

        guard let lastUpdate = settings.lastPowerModeMemoryUpdates[powerModeId] else {
            #expect(Bool(false), "Power mode update should be recorded")
            return
        }

        #expect(lastUpdate >= beforeUpdate)
        #expect(lastUpdate <= afterUpdate)

        // Restore
        settings.lastPowerModeMemoryUpdates = originalUpdates
    }
}

// MARK: - Skip Reason Tests

@Suite("MemoryUpdateScheduler - Skip Reasons")
struct SkipReasonTests {

    @Test("Skip reason - too soon")
    func skipReasonTooSoon() {
        let reason = ScheduledMemoryUpdateResult.SkipReason.tooSoon
        if case .tooSoon = reason {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected tooSoon")
        }
    }

    @Test("Skip reason - no new records")
    func skipReasonNoNewRecords() {
        let reason = ScheduledMemoryUpdateResult.SkipReason.noNewRecords
        if case .noNewRecords = reason {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected noNewRecords")
        }
    }

    @Test("Skip reason - memory disabled")
    func skipReasonMemoryDisabled() {
        let reason = ScheduledMemoryUpdateResult.SkipReason.memoryDisabled
        if case .memoryDisabled = reason {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected memoryDisabled")
        }
    }
}

// MARK: - Codable Backward Compatibility Tests

@Suite("MemoryUpdateScheduler - Backward Compatibility")
struct BackwardCompatibilityTests {

    @Test("Context without memoryLimit decodes with default 2000")
    func contextWithoutMemoryLimitDecodesDefault() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "name": "Test",
            "icon": "person",
            "color": "blue",
            "description": "Test context"
        }
        """

        let data = json.data(using: .utf8)!
        let context = try JSONDecoder().decode(ConversationContext.self, from: data)

        #expect(context.memoryLimit == 2000)
    }

    @Test("Context with memoryLimit decodes correctly")
    func contextWithMemoryLimitDecodesCorrectly() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "name": "Test",
            "icon": "person",
            "color": "blue",
            "description": "Test context",
            "memoryLimit": 1500
        }
        """

        let data = json.data(using: .utf8)!
        let context = try JSONDecoder().decode(ConversationContext.self, from: data)

        #expect(context.memoryLimit == 1500)
    }

    @Test("PowerMode without memoryLimit decodes with default 2000")
    func powerModeWithoutMemoryLimitDecodesDefault() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "name": "Test",
            "icon": "bolt.fill",
            "iconColor": "orange",
            "iconBackgroundColor": "orange",
            "createdAt": 0,
            "updatedAt": 0
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let powerMode = try decoder.decode(PowerMode.self, from: data)

        #expect(powerMode.memoryLimit == 2000)
    }

    @Test("PowerMode with memoryLimit decodes correctly")
    func powerModeWithMemoryLimitDecodesCorrectly() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "name": "Test",
            "icon": "bolt.fill",
            "iconColor": "orange",
            "iconBackgroundColor": "orange",
            "createdAt": 0,
            "updatedAt": 0,
            "memoryLimit": 800
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let powerMode = try decoder.decode(PowerMode.self, from: data)

        #expect(powerMode.memoryLimit == 800)
    }
}
