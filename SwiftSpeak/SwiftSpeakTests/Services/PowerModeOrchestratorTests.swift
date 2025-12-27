//
//  PowerModeOrchestratorTests.swift
//  SwiftSpeakTests
//
//  Comprehensive tests for PowerModeOrchestrator
//  Tests context injection, memory injection, and all variations
//

import Testing
@testable import SwiftSpeak

// MARK: - Test Helpers

/// Creates a test settings instance with clean state
@MainActor
private func createTestSettings() -> SharedSettings {
    let settings = SharedSettings.shared
    // Clear existing state for tests
    settings.contexts = []
    settings.activeContextId = nil
    settings.powerModes = []
    settings.globalMemory = nil
    settings.globalMemoryEnabled = true
    return settings
}

/// Creates a sample power mode for testing
private func createTestPowerMode(
    name: String = "Test Mode",
    instruction: String = "Test instruction",
    memoryEnabled: Bool = false,
    memory: String? = nil
) -> PowerMode {
    var mode = PowerMode(
        name: name,
        icon: "⚡",
        instruction: instruction,
        outputFormat: "Plain text output"
    )
    mode.memoryEnabled = memoryEnabled
    mode.memory = memory
    return mode
}

/// Creates a sample context for testing
private func createTestContext(
    name: String = "Test Context",
    memoryEnabled: Bool = false,
    memory: String? = nil,
    tone: String = "Professional",
    customInstructions: String = ""
) -> ConversationContext {
    var context = ConversationContext(
        name: name,
        icon: "💼",
        color: .blue,
        toneDescription: tone,
        customInstructions: customInstructions
    )
    context.memoryEnabled = memoryEnabled
    context.memory = memory
    return context
}

// MARK: - State Machine Tests

@Suite("PowerModeOrchestrator - State Machine")
struct PowerModeOrchestratorStateTests {

    @Test("Initial state is idle")
    @MainActor
    func initialStateIsIdle() {
        let settings = createTestSettings()
        let powerMode = createTestPowerMode()
        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: MockProviderFactory.instant,
            memoryManager: MockMemoryManager()
        )

        #expect(orchestrator.state == .idle)
        #expect(orchestrator.isIdle)
        #expect(!orchestrator.isRecording)
        #expect(!orchestrator.isProcessing)
    }

    @Test("State transitions to recording on start")
    @MainActor
    func stateTransitionsToRecording() async {
        let settings = createTestSettings()
        let powerMode = createTestPowerMode()
        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: MockProviderFactory.instant,
            memoryManager: MockMemoryManager()
        )

        await orchestrator.startRecording()

        #expect(orchestrator.state == .recording)
        #expect(orchestrator.isRecording)
    }

    @Test("Cancel returns to idle state")
    @MainActor
    func cancelReturnsToIdle() async {
        let settings = createTestSettings()
        let powerMode = createTestPowerMode()
        let audioRecorder = MockAudioRecorder.instant
        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: audioRecorder,
            providerFactory: MockProviderFactory.instant,
            memoryManager: MockMemoryManager()
        )

        await orchestrator.startRecording()
        orchestrator.cancel()

        #expect(orchestrator.state == .idle)
        #expect(audioRecorder.cancelRecordingCallCount == 1)
    }

    @Test("Reset clears all state")
    @MainActor
    func resetClearsAllState() async {
        let settings = createTestSettings()
        let powerMode = createTestPowerMode()
        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: MockProviderFactory.instant,
            memoryManager: MockMemoryManager()
        )

        await orchestrator.startRecording()
        orchestrator.reset()

        #expect(orchestrator.state == .idle)
        #expect(orchestrator.transcribedText.isEmpty)
        #expect(orchestrator.errorMessage == nil)
        #expect(orchestrator.recordingDuration == 0)
    }
}

// MARK: - Error Handling Tests

@Suite("PowerModeOrchestrator - Error Handling")
struct PowerModeOrchestratorErrorTests {

    @Test("Recording failure transitions to error state")
    @MainActor
    func recordingFailureTransitionsToError() async {
        let settings = createTestSettings()
        let powerMode = createTestPowerMode()
        let audioRecorder = MockAudioRecorder.recordingFailure
        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: audioRecorder,
            providerFactory: MockProviderFactory.instant,
            memoryManager: MockMemoryManager()
        )

        await orchestrator.startRecording()

        #expect(orchestrator.hasError)
        #expect(orchestrator.errorMessage != nil)
    }

    @Test("Provider not configured throws error")
    @MainActor
    func providerNotConfiguredError() async {
        let settings = createTestSettings()
        let powerMode = createTestPowerMode()
        let audioRecorder = MockAudioRecorder.instant
        let providerFactory = MockProviderFactory.unconfigured
        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: audioRecorder,
            providerFactory: providerFactory,
            memoryManager: MockMemoryManager()
        )

        await orchestrator.startRecording()
        await orchestrator.stopRecording()

        #expect(orchestrator.hasError)
        #expect(orchestrator.errorMessage?.contains("not configured") == true || orchestrator.errorMessage != nil)
    }
}

// MARK: - Context Injection Tests

@Suite("PowerModeOrchestrator - Context Injection")
struct PowerModeOrchestratorContextTests {

    @Test("No context when none is active")
    @MainActor
    func noContextWhenNoneActive() {
        let settings = createTestSettings()
        settings.activeContextId = nil

        let powerMode = createTestPowerMode()
        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: MockProviderFactory.instant,
            memoryManager: MockMemoryManager()
        )

        #expect(!orchestrator.hasActiveContext)
        #expect(orchestrator.activeContextName == nil)
    }

    @Test("Context is detected when active")
    @MainActor
    func contextDetectedWhenActive() {
        let settings = createTestSettings()
        let context = createTestContext(name: "Work Context")
        settings.contexts = [context]
        settings.activeContextId = context.id

        let powerMode = createTestPowerMode()
        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: MockProviderFactory.instant,
            memoryManager: MockMemoryManager()
        )

        #expect(orchestrator.hasActiveContext)
        #expect(orchestrator.activeContextName == "Work Context")
    }

    @Test("Context tone injected into system prompt")
    @MainActor
    func contextToneInjectedIntoPrompt() async {
        let settings = createTestSettings()
        let context = createTestContext(
            name: "Formal Context",
            tone: "Very formal and professional"
        )
        settings.contexts = [context]
        settings.activeContextId = context.id

        let powerMode = createTestPowerMode()
        let mockProvider = MockFormattingProvider.instant
        let providerFactory = MockProviderFactory(
            transcriptionProvider: .instant,
            formattingProvider: mockProvider
        )

        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: providerFactory,
            memoryManager: MockMemoryManager()
        )

        await orchestrator.startRecording()
        await orchestrator.stopRecording()

        // Check that the context tone was passed to the provider
        let customPrompt = mockProvider.lastCustomPrompt ?? ""
        #expect(customPrompt.contains("Formal Context"))
        #expect(customPrompt.contains("Very formal and professional"))
    }

    @Test("Context custom instructions injected")
    @MainActor
    func contextCustomInstructionsInjected() async {
        let settings = createTestSettings()
        let context = createTestContext(
            name: "Custom Context",
            customInstructions: "Always use bullet points"
        )
        settings.contexts = [context]
        settings.activeContextId = context.id

        let powerMode = createTestPowerMode()
        let mockProvider = MockFormattingProvider.instant
        let providerFactory = MockProviderFactory(
            transcriptionProvider: .instant,
            formattingProvider: mockProvider
        )

        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: providerFactory,
            memoryManager: MockMemoryManager()
        )

        await orchestrator.startRecording()
        await orchestrator.stopRecording()

        let customPrompt = mockProvider.lastCustomPrompt ?? ""
        #expect(customPrompt.contains("Always use bullet points"))
    }
}

// MARK: - Memory Injection Tests - Global Memory

@Suite("PowerModeOrchestrator - Global Memory")
struct PowerModeOrchestratorGlobalMemoryTests {

    @Test("Global memory NOT injected when disabled")
    @MainActor
    func globalMemoryNotInjectedWhenDisabled() async {
        let settings = createTestSettings()
        settings.globalMemoryEnabled = false
        settings.globalMemory = "User prefers concise answers"

        let powerMode = createTestPowerMode()
        let mockProvider = MockFormattingProvider.instant
        let providerFactory = MockProviderFactory(
            transcriptionProvider: .instant,
            formattingProvider: mockProvider
        )

        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: providerFactory,
            memoryManager: MockMemoryManager()
        )

        await orchestrator.startRecording()
        await orchestrator.stopRecording()

        let customPrompt = mockProvider.lastCustomPrompt ?? ""
        #expect(!customPrompt.contains("User prefers concise answers"))
        #expect(!customPrompt.contains("Global context"))
    }

    @Test("Global memory injected when enabled")
    @MainActor
    func globalMemoryInjectedWhenEnabled() async {
        let settings = createTestSettings()
        settings.globalMemoryEnabled = true
        settings.globalMemory = "User prefers detailed explanations"

        let powerMode = createTestPowerMode()
        let mockProvider = MockFormattingProvider.instant
        let providerFactory = MockProviderFactory(
            transcriptionProvider: .instant,
            formattingProvider: mockProvider
        )

        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: providerFactory,
            memoryManager: MockMemoryManager()
        )

        await orchestrator.startRecording()
        await orchestrator.stopRecording()

        let customPrompt = mockProvider.lastCustomPrompt ?? ""
        #expect(customPrompt.contains("User prefers detailed explanations"))
        #expect(customPrompt.contains("Global context"))
    }

    @Test("Empty global memory not injected")
    @MainActor
    func emptyGlobalMemoryNotInjected() async {
        let settings = createTestSettings()
        settings.globalMemoryEnabled = true
        settings.globalMemory = ""

        let powerMode = createTestPowerMode()
        let mockProvider = MockFormattingProvider.instant
        let providerFactory = MockProviderFactory(
            transcriptionProvider: .instant,
            formattingProvider: mockProvider
        )

        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: providerFactory,
            memoryManager: MockMemoryManager()
        )

        await orchestrator.startRecording()
        await orchestrator.stopRecording()

        let customPrompt = mockProvider.lastCustomPrompt ?? ""
        #expect(!customPrompt.contains("Global context"))
    }
}

// MARK: - Memory Injection Tests - Context Memory

@Suite("PowerModeOrchestrator - Context Memory")
struct PowerModeOrchestratorContextMemoryTests {

    @Test("Context memory NOT injected when memory disabled")
    @MainActor
    func contextMemoryNotInjectedWhenDisabled() async {
        let settings = createTestSettings()
        let context = createTestContext(
            name: "Work",
            memoryEnabled: false,
            memory: "Work-specific context memory"
        )
        settings.contexts = [context]
        settings.activeContextId = context.id
        settings.globalMemoryEnabled = false  // Disable global to isolate test

        let powerMode = createTestPowerMode()
        let mockProvider = MockFormattingProvider.instant
        let providerFactory = MockProviderFactory(
            transcriptionProvider: .instant,
            formattingProvider: mockProvider
        )

        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: providerFactory,
            memoryManager: MockMemoryManager()
        )

        await orchestrator.startRecording()
        await orchestrator.stopRecording()

        let customPrompt = mockProvider.lastCustomPrompt ?? ""
        #expect(!customPrompt.contains("Work-specific context memory"))
    }

    @Test("Context memory injected when enabled")
    @MainActor
    func contextMemoryInjectedWhenEnabled() async {
        let settings = createTestSettings()
        let context = createTestContext(
            name: "Personal",
            memoryEnabled: true,
            memory: "User likes casual tone"
        )
        settings.contexts = [context]
        settings.activeContextId = context.id
        settings.globalMemoryEnabled = false  // Disable global to isolate test

        let powerMode = createTestPowerMode()
        let mockProvider = MockFormattingProvider.instant
        let providerFactory = MockProviderFactory(
            transcriptionProvider: .instant,
            formattingProvider: mockProvider
        )

        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: providerFactory,
            memoryManager: MockMemoryManager()
        )

        await orchestrator.startRecording()
        await orchestrator.stopRecording()

        let customPrompt = mockProvider.lastCustomPrompt ?? ""
        #expect(customPrompt.contains("User likes casual tone"))
        #expect(customPrompt.contains("Context (Personal)"))
    }

    @Test("Context memory NOT injected when context not active")
    @MainActor
    func contextMemoryNotInjectedWhenNotActive() async {
        let settings = createTestSettings()
        let context = createTestContext(
            name: "Inactive",
            memoryEnabled: true,
            memory: "This should not appear"
        )
        settings.contexts = [context]
        settings.activeContextId = nil  // No active context
        settings.globalMemoryEnabled = false

        let powerMode = createTestPowerMode()
        let mockProvider = MockFormattingProvider.instant
        let providerFactory = MockProviderFactory(
            transcriptionProvider: .instant,
            formattingProvider: mockProvider
        )

        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: providerFactory,
            memoryManager: MockMemoryManager()
        )

        await orchestrator.startRecording()
        await orchestrator.stopRecording()

        let customPrompt = mockProvider.lastCustomPrompt ?? ""
        #expect(!customPrompt.contains("This should not appear"))
    }
}

// MARK: - Memory Injection Tests - Power Mode Memory

@Suite("PowerModeOrchestrator - Power Mode Memory")
struct PowerModeOrchestratorPowerModeMemoryTests {

    @Test("Power Mode memory NOT injected when disabled")
    @MainActor
    func powerModeMemoryNotInjectedWhenDisabled() async {
        let settings = createTestSettings()
        settings.globalMemoryEnabled = false

        let powerMode = createTestPowerMode(
            name: "Email Writer",
            memoryEnabled: false,
            memory: "Previous email context"
        )
        let mockProvider = MockFormattingProvider.instant
        let providerFactory = MockProviderFactory(
            transcriptionProvider: .instant,
            formattingProvider: mockProvider
        )

        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: providerFactory,
            memoryManager: MockMemoryManager()
        )

        await orchestrator.startRecording()
        await orchestrator.stopRecording()

        let customPrompt = mockProvider.lastCustomPrompt ?? ""
        #expect(!customPrompt.contains("Previous email context"))
    }

    @Test("Power Mode memory injected when enabled")
    @MainActor
    func powerModeMemoryInjectedWhenEnabled() async {
        let settings = createTestSettings()
        settings.globalMemoryEnabled = false

        let powerMode = createTestPowerMode(
            name: "Code Helper",
            memoryEnabled: true,
            memory: "User prefers Swift code"
        )
        let mockProvider = MockFormattingProvider.instant
        let providerFactory = MockProviderFactory(
            transcriptionProvider: .instant,
            formattingProvider: mockProvider
        )

        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: providerFactory,
            memoryManager: MockMemoryManager()
        )

        await orchestrator.startRecording()
        await orchestrator.stopRecording()

        let customPrompt = mockProvider.lastCustomPrompt ?? ""
        #expect(customPrompt.contains("User prefers Swift code"))
        #expect(customPrompt.contains("Workflow (Code Helper)"))
    }
}

// MARK: - Combined Memory Tests

@Suite("PowerModeOrchestrator - Combined Memory Scenarios")
struct PowerModeOrchestratorCombinedMemoryTests {

    @Test("All three memories injected when all enabled")
    @MainActor
    func allThreeMemoriesInjected() async {
        let settings = createTestSettings()
        settings.globalMemoryEnabled = true
        settings.globalMemory = "GLOBAL_MEMORY_CONTENT"

        let context = createTestContext(
            name: "TestContext",
            memoryEnabled: true,
            memory: "CONTEXT_MEMORY_CONTENT"
        )
        settings.contexts = [context]
        settings.activeContextId = context.id

        let powerMode = createTestPowerMode(
            name: "TestMode",
            memoryEnabled: true,
            memory: "POWERMODE_MEMORY_CONTENT"
        )

        let mockProvider = MockFormattingProvider.instant
        let providerFactory = MockProviderFactory(
            transcriptionProvider: .instant,
            formattingProvider: mockProvider
        )

        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: providerFactory,
            memoryManager: MockMemoryManager()
        )

        await orchestrator.startRecording()
        await orchestrator.stopRecording()

        let customPrompt = mockProvider.lastCustomPrompt ?? ""
        #expect(customPrompt.contains("GLOBAL_MEMORY_CONTENT"))
        #expect(customPrompt.contains("CONTEXT_MEMORY_CONTENT"))
        #expect(customPrompt.contains("POWERMODE_MEMORY_CONTENT"))
    }

    @Test("Only global memory when others disabled")
    @MainActor
    func onlyGlobalMemoryWhenOthersDisabled() async {
        let settings = createTestSettings()
        settings.globalMemoryEnabled = true
        settings.globalMemory = "ONLY_GLOBAL"

        let context = createTestContext(
            name: "NoMem",
            memoryEnabled: false,
            memory: "SHOULD_NOT_APPEAR_1"
        )
        settings.contexts = [context]
        settings.activeContextId = context.id

        let powerMode = createTestPowerMode(
            memoryEnabled: false,
            memory: "SHOULD_NOT_APPEAR_2"
        )

        let mockProvider = MockFormattingProvider.instant
        let providerFactory = MockProviderFactory(
            transcriptionProvider: .instant,
            formattingProvider: mockProvider
        )

        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: providerFactory,
            memoryManager: MockMemoryManager()
        )

        await orchestrator.startRecording()
        await orchestrator.stopRecording()

        let customPrompt = mockProvider.lastCustomPrompt ?? ""
        #expect(customPrompt.contains("ONLY_GLOBAL"))
        #expect(!customPrompt.contains("SHOULD_NOT_APPEAR_1"))
        #expect(!customPrompt.contains("SHOULD_NOT_APPEAR_2"))
    }

    @Test("Only context memory when others disabled")
    @MainActor
    func onlyContextMemoryWhenOthersDisabled() async {
        let settings = createTestSettings()
        settings.globalMemoryEnabled = false
        settings.globalMemory = "SHOULD_NOT_APPEAR_G"

        let context = createTestContext(
            name: "ActiveCtx",
            memoryEnabled: true,
            memory: "ONLY_CONTEXT"
        )
        settings.contexts = [context]
        settings.activeContextId = context.id

        let powerMode = createTestPowerMode(
            memoryEnabled: false,
            memory: "SHOULD_NOT_APPEAR_P"
        )

        let mockProvider = MockFormattingProvider.instant
        let providerFactory = MockProviderFactory(
            transcriptionProvider: .instant,
            formattingProvider: mockProvider
        )

        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: providerFactory,
            memoryManager: MockMemoryManager()
        )

        await orchestrator.startRecording()
        await orchestrator.stopRecording()

        let customPrompt = mockProvider.lastCustomPrompt ?? ""
        #expect(customPrompt.contains("ONLY_CONTEXT"))
        #expect(!customPrompt.contains("SHOULD_NOT_APPEAR_G"))
        #expect(!customPrompt.contains("SHOULD_NOT_APPEAR_P"))
    }

    @Test("Only power mode memory when others disabled")
    @MainActor
    func onlyPowerModeMemoryWhenOthersDisabled() async {
        let settings = createTestSettings()
        settings.globalMemoryEnabled = false
        settings.activeContextId = nil  // No context

        let powerMode = createTestPowerMode(
            name: "Solo",
            memoryEnabled: true,
            memory: "ONLY_POWERMODE"
        )

        let mockProvider = MockFormattingProvider.instant
        let providerFactory = MockProviderFactory(
            transcriptionProvider: .instant,
            formattingProvider: mockProvider
        )

        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: providerFactory,
            memoryManager: MockMemoryManager()
        )

        await orchestrator.startRecording()
        await orchestrator.stopRecording()

        let customPrompt = mockProvider.lastCustomPrompt ?? ""
        #expect(customPrompt.contains("ONLY_POWERMODE"))
        #expect(customPrompt.contains("Workflow (Solo)"))
    }

    @Test("No memory section when all disabled")
    @MainActor
    func noMemorySectionWhenAllDisabled() async {
        let settings = createTestSettings()
        settings.globalMemoryEnabled = false
        settings.globalMemory = "HIDDEN"
        settings.activeContextId = nil

        let powerMode = createTestPowerMode(
            memoryEnabled: false,
            memory: "HIDDEN_TOO"
        )

        let mockProvider = MockFormattingProvider.instant
        let providerFactory = MockProviderFactory(
            transcriptionProvider: .instant,
            formattingProvider: mockProvider
        )

        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: providerFactory,
            memoryManager: MockMemoryManager()
        )

        await orchestrator.startRecording()
        await orchestrator.stopRecording()

        let customPrompt = mockProvider.lastCustomPrompt ?? ""
        #expect(!customPrompt.contains("Relevant Memory"))
        #expect(!customPrompt.contains("HIDDEN"))
    }
}

// MARK: - Active Memory Sources Tests

@Suite("PowerModeOrchestrator - Active Memory Sources")
struct PowerModeOrchestratorActiveMemorySourcesTests {

    @Test("Reports correct active memory sources - all enabled")
    @MainActor
    func reportsAllActiveSources() {
        let settings = createTestSettings()
        settings.globalMemoryEnabled = true
        settings.globalMemory = "exists"

        let context = createTestContext(
            name: "Ctx",
            memoryEnabled: true,
            memory: "exists"
        )
        settings.contexts = [context]
        settings.activeContextId = context.id

        let powerMode = createTestPowerMode(
            name: "PM",
            memoryEnabled: true,
            memory: "exists"
        )

        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: MockProviderFactory.instant,
            memoryManager: MockMemoryManager()
        )

        let sources = orchestrator.activeMemorySources
        #expect(sources.contains("Global"))
        #expect(sources.contains("Ctx"))
        #expect(sources.contains("PM"))
        #expect(sources.count == 3)
    }

    @Test("Reports empty when no memories")
    @MainActor
    func reportsEmptyWhenNoMemories() {
        let settings = createTestSettings()
        settings.globalMemoryEnabled = false
        settings.activeContextId = nil

        let powerMode = createTestPowerMode(memoryEnabled: false)

        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: MockProviderFactory.instant,
            memoryManager: MockMemoryManager()
        )

        #expect(orchestrator.activeMemorySources.isEmpty)
    }
}

// MARK: - Memory Update Tests

@Suite("PowerModeOrchestrator - Memory Update")
struct PowerModeOrchestratorMemoryUpdateTests {

    @Test("Memory manager called after completion")
    @MainActor
    func memoryManagerCalledAfterCompletion() async throws {
        let settings = createTestSettings()
        let context = createTestContext(name: "Ctx", memoryEnabled: true)
        settings.contexts = [context]
        settings.activeContextId = context.id

        let powerMode = createTestPowerMode(memoryEnabled: true)
        settings.powerModes = [powerMode]

        let memoryManager = MockMemoryManager()

        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: MockProviderFactory.instant,
            memoryManager: memoryManager
        )

        await orchestrator.startRecording()
        await orchestrator.stopRecording()

        // Give time for async memory update
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(memoryManager.updateMemoryCallCount >= 1)
        #expect(memoryManager.lastPowerMode?.id == powerMode.id)
    }
}

// MARK: - Prompt Building Tests

@Suite("PowerModeOrchestrator - Prompt Building")
struct PowerModeOrchestratorPromptTests {

    @Test("Power Mode instruction included in prompt")
    @MainActor
    func powerModeInstructionIncluded() async {
        let settings = createTestSettings()
        let powerMode = createTestPowerMode(
            instruction: "UNIQUE_INSTRUCTION_TEXT"
        )

        let mockProvider = MockFormattingProvider.instant
        let providerFactory = MockProviderFactory(
            transcriptionProvider: .instant,
            formattingProvider: mockProvider
        )

        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: providerFactory,
            memoryManager: MockMemoryManager()
        )

        await orchestrator.startRecording()
        await orchestrator.stopRecording()

        let customPrompt = mockProvider.lastCustomPrompt ?? ""
        #expect(customPrompt.contains("UNIQUE_INSTRUCTION_TEXT"))
        #expect(customPrompt.contains("Role and Task"))
    }

    @Test("Output format included when set")
    @MainActor
    func outputFormatIncluded() async {
        let settings = createTestSettings()
        var powerMode = createTestPowerMode()
        powerMode.outputFormat = "CUSTOM_OUTPUT_FORMAT"

        let mockProvider = MockFormattingProvider.instant
        let providerFactory = MockProviderFactory(
            transcriptionProvider: .instant,
            formattingProvider: mockProvider
        )

        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: providerFactory,
            memoryManager: MockMemoryManager()
        )

        await orchestrator.startRecording()
        await orchestrator.stopRecording()

        let customPrompt = mockProvider.lastCustomPrompt ?? ""
        #expect(customPrompt.contains("CUSTOM_OUTPUT_FORMAT"))
        #expect(customPrompt.contains("Output Format"))
    }
}

// MARK: - Full Flow Tests

@Suite("PowerModeOrchestrator - Full Flow")
struct PowerModeOrchestratorFullFlowTests {

    @Test("Complete flow with context and memory")
    @MainActor
    func completeFlowWithContextAndMemory() async {
        let settings = createTestSettings()
        settings.globalMemoryEnabled = true
        settings.globalMemory = "User is a developer"

        let context = createTestContext(
            name: "Work",
            memoryEnabled: true,
            memory: "Working on iOS app",
            tone: "Technical and precise"
        )
        settings.contexts = [context]
        settings.activeContextId = context.id

        let powerMode = createTestPowerMode(
            name: "Code Review",
            instruction: "Review the code",
            memoryEnabled: true,
            memory: "Focus on Swift best practices"
        )
        settings.powerModes = [powerMode]

        let mockTranscription = MockTranscriptionProvider.instant
        mockTranscription.mockResult = "Please review this function"

        let mockFormatting = MockFormattingProvider.instant
        mockFormatting.customResult = "Here is my code review..."

        let providerFactory = MockProviderFactory(
            transcriptionProvider: mockTranscription,
            formattingProvider: mockFormatting
        )

        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: providerFactory,
            memoryManager: MockMemoryManager()
        )

        // Execute flow
        await orchestrator.startRecording()
        #expect(orchestrator.isRecording)

        await orchestrator.stopRecording()

        // Verify completion
        #expect(orchestrator.isComplete)
        #expect(orchestrator.resultText == "Here is my code review...")

        // Verify prompt contained all elements
        let prompt = mockFormatting.lastCustomPrompt ?? ""
        #expect(prompt.contains("Review the code"))  // Instruction
        #expect(prompt.contains("Work"))  // Context name
        #expect(prompt.contains("Technical and precise"))  // Tone
        #expect(prompt.contains("User is a developer"))  // Global memory
        #expect(prompt.contains("Working on iOS app"))  // Context memory
        #expect(prompt.contains("Focus on Swift best practices"))  // PM memory
    }

    @Test("Regeneration includes note in prompt")
    @MainActor
    func regenerationIncludesNote() async {
        let settings = createTestSettings()
        let powerMode = createTestPowerMode()

        let mockFormatting = MockFormattingProvider.instant
        mockFormatting.customResult = "Regenerated output"

        let providerFactory = MockProviderFactory(
            transcriptionProvider: .instant,
            formattingProvider: mockFormatting
        )

        let orchestrator = PowerModeOrchestrator(
            powerMode: powerMode,
            settings: settings,
            audioRecorder: MockAudioRecorder.instant,
            providerFactory: providerFactory,
            memoryManager: MockMemoryManager()
        )

        // First run
        await orchestrator.startRecording()
        await orchestrator.stopRecording()

        // Regenerate
        await orchestrator.regenerate()

        let prompt = mockFormatting.lastCustomPrompt ?? ""
        #expect(prompt.contains("regeneration"))
        #expect(prompt.contains("fresh perspective"))
    }
}
