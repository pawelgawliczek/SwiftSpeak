//
//  ConcurrencyTests.swift
//  SwiftSpeakTests
//
//  Tests for concurrent access and thread safety
//

import Testing
import Foundation
@testable import SwiftSpeak

// MARK: - Concurrency Tests

@Suite("Concurrency Tests")
@MainActor
struct ConcurrencyTests {

    // MARK: - Concurrent Settings Access

    @Test("Concurrent settings reads are safe")
    func concurrentSettingsReadsAreSafe() async {
        let settings = SharedSettings.shared

        // Perform multiple concurrent reads
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<10 {
                group.addTask { @MainActor in
                    _ = settings.selectedTargetLanguage
                    _ = settings.powerModes
                    _ = settings.contexts
                    _ = settings.selectedTranscriptionProvider
                    return true
                }
            }

            for await result in group {
                #expect(result == true)
            }
        }
    }

    @Test("Provider selection can be changed safely")
    func providerSelectionCanBeChangedSafely() async {
        let settings = SharedSettings.shared
        let originalProvider = settings.selectedTranscriptionProvider

        // Sequential writes (MainActor ensures serialization)
        for provider in [AIProvider.openAI, AIProvider.deepgram, AIProvider.assemblyAI] {
            settings.selectedTranscriptionProvider = provider
            #expect(settings.selectedTranscriptionProvider == provider)
        }

        settings.selectedTranscriptionProvider = originalProvider
    }

    // MARK: - Orchestrator State Tests

    @Test("Orchestrator initial state is idle")
    func orchestratorInitialStateIsIdle() {
        let orchestrator = TranscriptionOrchestrator()
        #expect(orchestrator.state == .idle)
    }

    @Test("Cancel brings orchestrator back to idle")
    func cancelBringsOrchestratorBackToIdle() {
        let orchestrator = TranscriptionOrchestrator()

        // Cancel should always return to idle
        orchestrator.cancel()
        #expect(orchestrator.state == .idle)
    }

    @Test("Reset clears orchestrator state")
    func resetClearsOrchestratorState() {
        let orchestrator = TranscriptionOrchestrator()

        // Reset should return to clean state
        orchestrator.reset()
        #expect(orchestrator.state == .idle)
        #expect(orchestrator.transcribedText.isEmpty)
        #expect(orchestrator.formattedText.isEmpty)
        #expect(orchestrator.errorMessage == nil)
    }

    // MARK: - Context Concurrent Access

    @Test("Context list access is safe")
    func contextListAccessIsSafe() async {
        let settings = SharedSettings.shared
        let originalContexts = settings.contexts

        // Concurrent reads of contexts
        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<5 {
                group.addTask { @MainActor in
                    return settings.contexts.count
                }
            }

            var counts: [Int] = []
            for await count in group {
                counts.append(count)
            }

            // All reads should return the same count
            if let first = counts.first {
                #expect(counts.allSatisfy { $0 == first })
            }
        }

        settings.contexts = originalContexts
    }

    // MARK: - PowerMode Concurrent Access

    @Test("PowerMode list access is safe")
    func powerModeListAccessIsSafe() async {
        let settings = SharedSettings.shared
        let originalModes = settings.powerModes

        // Concurrent reads of power modes
        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<5 {
                group.addTask { @MainActor in
                    return settings.powerModes.count
                }
            }

            var counts: [Int] = []
            for await count in group {
                counts.append(count)
            }

            // All reads should return the same count
            if let first = counts.first {
                #expect(counts.allSatisfy { $0 == first })
            }
        }

        settings.powerModes = originalModes
    }

    // MARK: - History Concurrent Access

    @Test("History access is safe")
    func historyAccessIsSafe() async {
        let settings = SharedSettings.shared

        // Concurrent reads of history
        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<5 {
                group.addTask { @MainActor in
                    return settings.transcriptionHistory.count
                }
            }

            var counts: [Int] = []
            for await count in group {
                counts.append(count)
            }

            // All reads should return the same count
            if let first = counts.first {
                #expect(counts.allSatisfy { $0 == first })
            }
        }
    }
}

// MARK: - Memory Safety Tests

@Suite("Memory Safety Tests")
@MainActor
struct MemorySafetyTests {

    @Test("Global memory can be set and read")
    func globalMemoryCanBeSetAndRead() {
        let settings = SharedSettings.shared
        let original = settings.globalMemory

        settings.globalMemory = "Test memory content"
        #expect(settings.globalMemory == "Test memory content")

        settings.globalMemory = original
    }

    @Test("Context memory is isolated")
    func contextMemoryIsIsolated() {
        var context1 = ConversationContext(
            name: "Context 1",
            icon: "1.circle",
            color: .blue,
            description: "First context"
        )
        var context2 = ConversationContext(
            name: "Context 2",
            icon: "2.circle",
            color: .green,
            description: "Second context"
        )

        context1.memory = "Memory for context 1"
        context2.memory = "Memory for context 2"

        #expect(context1.memory == "Memory for context 1")
        #expect(context2.memory == "Memory for context 2")
        #expect(context1.memory != context2.memory)
    }

    @Test("PowerMode memory is isolated")
    func powerModeMemoryIsIsolated() {
        var mode1 = PowerMode(name: "Mode 1")
        var mode2 = PowerMode(name: "Mode 2")

        mode1.memory = "Memory for mode 1"
        mode2.memory = "Memory for mode 2"

        #expect(mode1.memory == "Memory for mode 1")
        #expect(mode2.memory == "Memory for mode 2")
        #expect(mode1.memory != mode2.memory)
    }
}

// MARK: - Provider Configuration Safety Tests

@Suite("Provider Configuration Safety Tests")
@MainActor
struct ProviderConfigurationSafetyTests {

    @Test("Provider configurations can be modified safely")
    func providerConfigurationsCanBeModifiedSafely() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        // Add a new configuration
        let newConfig = AIProviderConfig(
            provider: .openAI,
            apiKey: "test-key",
            usageCategories: [.transcription]
        )

        settings.configuredAIProviders = [newConfig]
        #expect(settings.configuredAIProviders.count == 1)

        // Restore original
        settings.configuredAIProviders = originalProviders
    }

    @Test("Multiple providers can be configured")
    func multipleProvidersCanBeConfigured() {
        let settings = SharedSettings.shared
        let originalProviders = settings.configuredAIProviders

        let configs = [
            AIProviderConfig(
                provider: .openAI,
                apiKey: "openai-key",
                usageCategories: [.transcription]
            ),
            AIProviderConfig(
                provider: .anthropic,
                apiKey: "anthropic-key",
                usageCategories: [.powerMode]
            ),
        ]

        settings.configuredAIProviders = configs
        #expect(settings.configuredAIProviders.count == 2)

        // Restore original
        settings.configuredAIProviders = originalProviders
    }
}
