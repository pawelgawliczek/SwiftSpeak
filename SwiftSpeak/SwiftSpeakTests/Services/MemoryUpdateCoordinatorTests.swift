//
//  MemoryUpdateCoordinatorTests.swift
//  SwiftSpeakTests
//
//  LEGACY: This file is deprecated and kept for reference only
//  Replaced by: MemoryUpdateSchedulerTests.swift on 2025-01
//  Reason: Memory updates now use batch processing instead of per-transcription updates.
//          The new system collects messages and processes them on app start (12h-24h intervals)
//          using MemoryUpdateScheduler. Tests for the new system are in MemoryUpdateSchedulerTests.swift.
//  DO NOT USE - Will be removed in future cleanup
//
//  Original purpose: Phase 11c - Tests for memory update serialization
//

import Testing
import Foundation
@testable import SwiftSpeak

// MARK: - LEGACY TESTS COMMENTED OUT
// The tests below have been commented out because the MemoryUpdateCoordinator
// class they test has been replaced by MemoryUpdateScheduler during the
// memory system redesign. See MemoryUpdateSchedulerTests.swift for current tests.

/*
@Suite("MemoryUpdateCoordinator Tests")
struct MemoryUpdateCoordinatorTests {

    // MARK: - Basic Functionality Tests

    @Suite("Basic Functionality")
    struct BasicTests {

        @Test("Coordinator initializes correctly")
        func initialization() async {
            let coordinator = MemoryUpdateCoordinator {
                MemoryManager()
            }

            let pendingCount = await coordinator.pendingCount
            let isBusy = await coordinator.isBusy

            #expect(pendingCount == 0)
            #expect(isBusy == false)
        }

        @Test("Empty text is skipped")
        func emptyTextSkipped() async {
            let coordinator = MemoryUpdateCoordinator {
                MemoryManager()
            }

            let results = await coordinator.updateMemory(
                text: "",
                context: nil,
                powerMode: nil
            )

            #expect(results.isEmpty)
        }

        @Test("Whitespace-only text is skipped")
        func whitespaceSkipped() async {
            let coordinator = MemoryUpdateCoordinator {
                MemoryManager()
            }

            let results = await coordinator.updateMemory(
                text: "   \n\t  ",
                context: nil,
                powerMode: nil
            )

            #expect(results.isEmpty)
        }
    }

    // MARK: - Queue Tests

    @Suite("Queue Management")
    struct QueueTests {

        @Test("Queue update adds to pending")
        func queueAdds() async {
            let coordinator = MemoryUpdateCoordinator {
                MemoryManager()
            }

            await coordinator.queueUpdate(
                text: "Test text",
                context: nil,
                powerMode: nil
            )

            let count = await coordinator.pendingCount
            #expect(count == 1)
        }

        @Test("Multiple queued updates accumulate")
        func multipleQueues() async {
            let coordinator = MemoryUpdateCoordinator {
                MemoryManager()
            }

            await coordinator.queueUpdate(text: "Text 1", context: nil, powerMode: nil)
            await coordinator.queueUpdate(text: "Text 2", context: nil, powerMode: nil)
            await coordinator.queueUpdate(text: "Text 3", context: nil, powerMode: nil)

            let count = await coordinator.pendingCount
            #expect(count == 3)
        }

        @Test("Clear queue removes all pending")
        func clearQueue() async {
            let coordinator = MemoryUpdateCoordinator {
                MemoryManager()
            }

            await coordinator.queueUpdate(text: "Text 1", context: nil, powerMode: nil)
            await coordinator.queueUpdate(text: "Text 2", context: nil, powerMode: nil)

            await coordinator.clearQueue()

            let count = await coordinator.pendingCount
            #expect(count == 0)
        }

        @Test("Empty queue returns empty result")
        func emptyQueueProcess() async {
            let coordinator = MemoryUpdateCoordinator {
                MemoryManager()
            }

            let result = await coordinator.processQueue()

            #expect(result.processedCount == 0)
            #expect(result.failedCount == 0)
            #expect(result.results.isEmpty)
        }

        @Test("Queue size is limited")
        func queueSizeLimit() async {
            let coordinator = MemoryUpdateCoordinator {
                MemoryManager()
            }

            // Add more than max queue size (20)
            for i in 0..<30 {
                await coordinator.queueUpdate(
                    text: "Text \(i)",
                    context: nil,
                    powerMode: nil
                )
            }

            let count = await coordinator.pendingCount
            #expect(count <= 20)
        }
    }

    // MARK: - Serialization Tests

    @Suite("Serialization")
    struct SerializationTests {

        @Test("Concurrent updates are serialized")
        func concurrentSerialization() async {
            var callOrder: [Int] = []
            var callCount = 0

            // Create a mock that tracks call order
            let coordinator = MemoryUpdateCoordinator { @Sendable in
                // Create a real MemoryManager for the test
                MemoryManager()
            }

            // Launch multiple concurrent updates
            await withTaskGroup(of: Void.self) { group in
                for i in 0..<5 {
                    group.addTask {
                        _ = await coordinator.updateMemory(
                            text: "Update \(i)",
                            context: nil,
                            powerMode: nil
                        )
                    }
                }
            }

            // If we get here without crashes, serialization worked
            // Actor ensures no data races
            #expect(true)
        }

        @Test("Rapid updates don't cause race conditions")
        func rapidUpdates() async {
            let coordinator = MemoryUpdateCoordinator {
                MemoryManager()
            }

            // Simulate rapid transcriptions
            let iterations = 10

            await withTaskGroup(of: [MemoryUpdateResult].self) { group in
                for i in 0..<iterations {
                    group.addTask {
                        await coordinator.updateMemory(
                            text: "Rapid transcription \(i)",
                            context: nil,
                            powerMode: nil
                        )
                    }
                }

                var resultCount = 0
                for await results in group {
                    resultCount += 1
                }

                #expect(resultCount == iterations)
            }
        }
    }

    // MARK: - Context and PowerMode Tests

    @Suite("Context Integration")
    struct ContextTests {

        @Test("Context is passed through")
        func contextPassthrough() async {
            let settings = SharedSettings.shared
            let coordinator = MemoryUpdateCoordinator {
                MemoryManager(settings: settings)
            }

            let context = ConversationContext(
                name: "Test Context",
                icon: "folder",
                color: .blue,
                description: "Test"
            )

            // Note: This won't update context memory unless context exists in settings
            // but it tests that the context parameter flows through
            let results = await coordinator.updateMemory(
                text: "Test with context",
                context: context,
                powerMode: nil
            )

            // Global memory should have been attempted if enabled
            #expect(true)  // No crash = success
        }

        @Test("PowerMode is passed through")
        func powerModePassthrough() async {
            let settings = SharedSettings.shared
            let coordinator = MemoryUpdateCoordinator {
                MemoryManager(settings: settings)
            }

            let powerMode = PowerMode(
                name: "Test Power Mode",
                icon: "bolt",
                instruction: "Test prompt"
            )

            let results = await coordinator.updateMemory(
                text: "Test with power mode",
                context: nil,
                powerMode: powerMode
            )

            #expect(true)  // No crash = success
        }
    }

    // MARK: - Processing Tests

    @Suite("Queue Processing")
    struct ProcessingTests {

        @Test("Process queue clears pending")
        func processClears() async {
            let coordinator = MemoryUpdateCoordinator {
                MemoryManager()
            }

            await coordinator.queueUpdate(text: "Text 1", context: nil, powerMode: nil)
            await coordinator.queueUpdate(text: "Text 2", context: nil, powerMode: nil)

            let beforeCount = await coordinator.pendingCount
            #expect(beforeCount == 2)

            _ = await coordinator.processQueue()

            let afterCount = await coordinator.pendingCount
            #expect(afterCount == 0)
        }

        @Test("Process queue returns correct count")
        func processReturnsCount() async {
            let coordinator = MemoryUpdateCoordinator {
                MemoryManager()
            }

            await coordinator.queueUpdate(text: "Text 1", context: nil, powerMode: nil)
            await coordinator.queueUpdate(text: "Text 2", context: nil, powerMode: nil)
            await coordinator.queueUpdate(text: "Text 3", context: nil, powerMode: nil)

            let result = await coordinator.processQueue()

            #expect(result.processedCount == 3)
        }
    }

    // MARK: - Shared Factory Tests

    @Suite("Factory")
    struct FactoryTests {

        @Test("Shared factory creates coordinator")
        @MainActor
        func sharedFactory() async {
            let coordinator = MemoryUpdateCoordinator.shared()

            let count = await coordinator.pendingCount
            #expect(count == 0)
        }
    }
}
*/
