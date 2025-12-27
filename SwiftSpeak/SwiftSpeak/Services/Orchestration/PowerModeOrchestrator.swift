//
//  PowerModeOrchestrator.swift
//  SwiftSpeak
//
//  Phase 4c: Central coordinator for Power Mode execution
//  Manages: recording → transcription → thinking → generation → complete
//  Respects: Active Context, Global Memory, Context Memory, Power Mode Memory
//

import Combine
import Foundation
import UIKit

// Note: PowerModeExecutionState is defined in Models.swift

/// Central coordinator for Power Mode execution
/// Manages the full workflow: recording → transcription → LLM generation
/// Respects active context and memory settings
@MainActor
final class PowerModeOrchestrator: ObservableObject {

    // MARK: - Published State

    /// Current execution state
    @Published private(set) var state: PowerModeExecutionState = .idle

    /// Current session with results
    @Published private(set) var session: PowerModeSession = PowerModeSession()

    /// Transcribed user input
    @Published private(set) var transcribedText: String = ""

    /// Current recording duration
    @Published private(set) var recordingDuration: TimeInterval = 0

    /// Current audio level (0.0 to 1.0)
    @Published private(set) var audioLevel: Float = 0

    /// Array of audio levels for waveform visualization
    @Published private(set) var audioLevels: [Float] = Array(repeating: 0, count: 12)

    /// Error message if state is .error
    @Published private(set) var errorMessage: String?

    // MARK: - Configuration

    /// The Power Mode being executed
    private(set) var powerMode: PowerMode

    /// Whether this execution was triggered from keyboard
    var isFromKeyboard: Bool = false

    // MARK: - Dependencies

    private let settings: SharedSettings
    private let audioRecorder: any AudioRecorderProtocol
    private let providerFactory: any ProviderFactoryProtocol
    private let memoryManager: any MemoryManagerProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Timing

    private var startTime: Date?

    // MARK: - Initialization

    /// Standard initializer for production use with AudioRecorder bindings
    convenience init(
        powerMode: PowerMode,
        settings: SharedSettings? = nil
    ) {
        let resolvedSettings = settings ?? SharedSettings.shared
        self.init(
            powerMode: powerMode,
            settings: resolvedSettings,
            audioRecorder: AudioRecorder(),
            providerFactory: ProviderFactory(settings: resolvedSettings),
            memoryManager: MemoryManager(settings: resolvedSettings),
            setupBindings: true
        )
    }

    /// Full initializer for dependency injection (used in testing)
    init(
        powerMode: PowerMode,
        settings: SharedSettings,
        audioRecorder: any AudioRecorderProtocol,
        providerFactory: any ProviderFactoryProtocol,
        memoryManager: any MemoryManagerProtocol,
        setupBindings: Bool = false
    ) {
        self.powerMode = powerMode
        self.settings = settings
        self.audioRecorder = audioRecorder
        self.providerFactory = providerFactory
        self.memoryManager = memoryManager

        if setupBindings, let concreteRecorder = audioRecorder as? AudioRecorder {
            setupAudioBindings(recorder: concreteRecorder)
        }
    }

    private func setupAudioBindings(recorder: AudioRecorder) {
        // Bind audio recorder properties
        recorder.$duration
            .assign(to: &$recordingDuration)

        recorder.$currentLevel
            .assign(to: &$audioLevel)

        // Generate audio levels array from current level
        recorder.$currentLevel
            .map { level in
                (0..<12).map { index in
                    let variance = Float.random(in: -0.15...0.15)
                    let phase = sin(Float(index) * 0.5)
                    return max(0, min(1, level + variance * phase * level))
                }
            }
            .assign(to: &$audioLevels)
    }

    // MARK: - Active Context

    /// Get the active context (if any)
    private var activeContext: ConversationContext? {
        guard let activeId = settings.activeContextId else { return nil }
        return settings.contexts.first { $0.id == activeId }
    }

    // MARK: - Workflow Control

    /// Start recording
    func startRecording() async {
        // Reset state
        transcribedText = ""
        errorMessage = nil
        startTime = Date()

        do {
            state = .recording
            try await audioRecorder.startRecording()
        } catch let error as TranscriptionError {
            handleError(error)
        } catch {
            handleError(.recordingFailed(error.localizedDescription))
        }
    }

    /// Stop recording and process
    func stopRecording() async {
        guard state == .recording else { return }

        do {
            // Stop recording and get audio URL
            let audioURL = try audioRecorder.stopRecording()

            // Transcribe
            state = .transcribing
            transcribedText = try await transcribe(audioURL: audioURL)

            // Apply vocabulary replacements
            let processedInput = settings.applyVocabulary(to: transcribedText)
            transcribedText = processedInput

            // Thinking phase
            state = .thinking

            // Query knowledge base if configured (Phase 4e - RAG)
            // TODO: Implement RAG query when Phase 4e is complete
            if !powerMode.knowledgeDocumentIds.isEmpty {
                state = .queryingKnowledge
                // Simulate knowledge retrieval for now
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            }

            // Generate response
            state = .generating
            let output = try await generate(userInput: processedInput)

            // Calculate processing duration
            let processingDuration = Date().timeIntervalSince(startTime ?? Date())

            // Create result
            let result = PowerModeResult(
                powerModeId: powerMode.id,
                powerModeName: powerMode.name,
                userInput: processedInput,
                markdownOutput: output,
                processingDuration: processingDuration,
                versionNumber: session.results.count + 1,
                usedRAG: !powerMode.knowledgeDocumentIds.isEmpty,
                ragDocumentIds: powerMode.knowledgeDocumentIds
            )

            // Add to session
            session.addResult(result)

            // Update usage count
            settings.incrementPowerModeUsage(id: powerMode.id)

            // Copy to clipboard
            UIPasteboard.general.string = output

            // Update memory (async, non-blocking)
            Task {
                await updateMemory(input: processedInput, output: output)
            }

            // Complete
            state = .complete(session)

            // Clean up audio file
            audioRecorder.deleteRecording()

        } catch let error as TranscriptionError {
            handleError(error)
        } catch {
            handleError(.networkError(error.localizedDescription))
        }
    }

    /// Handle question answer
    func handleQuestionAnswer(_ answer: String) async {
        // Append answer to transcribed text for context
        transcribedText += "\n\nUser answered: \(answer)"

        // Continue to generation
        state = .generating

        do {
            let output = try await generate(userInput: transcribedText)
            let processingDuration = Date().timeIntervalSince(startTime ?? Date())

            let result = PowerModeResult(
                powerModeId: powerMode.id,
                powerModeName: powerMode.name,
                userInput: transcribedText,
                markdownOutput: output,
                processingDuration: processingDuration,
                versionNumber: session.results.count + 1,
                usedRAG: !powerMode.knowledgeDocumentIds.isEmpty,
                ragDocumentIds: powerMode.knowledgeDocumentIds
            )

            session.addResult(result)
            settings.incrementPowerModeUsage(id: powerMode.id)
            UIPasteboard.general.string = output

            Task {
                await updateMemory(input: transcribedText, output: output)
            }

            state = .complete(session)
        } catch {
            handleError(.networkError(error.localizedDescription))
        }
    }

    /// Regenerate with same input
    func regenerate() async {
        guard !transcribedText.isEmpty else { return }

        state = .generating

        do {
            let output = try await generate(userInput: transcribedText, isRegeneration: true)
            let processingDuration = Date().timeIntervalSince(startTime ?? Date())

            let result = PowerModeResult(
                powerModeId: powerMode.id,
                powerModeName: powerMode.name,
                userInput: transcribedText,
                markdownOutput: output,
                processingDuration: processingDuration,
                versionNumber: session.results.count + 1,
                usedRAG: !powerMode.knowledgeDocumentIds.isEmpty,
                ragDocumentIds: powerMode.knowledgeDocumentIds
            )

            session.addResult(result)
            UIPasteboard.general.string = output
            state = .complete(session)
        } catch {
            handleError(.networkError(error.localizedDescription))
        }
    }

    /// Refine with additional input
    func refine(additionalInput: String) async {
        guard let currentResult = session.currentResult else { return }

        let refinementPrompt = """
        Original request: \(transcribedText)

        Current output:
        \(currentResult.markdownOutput)

        Refinement request: \(additionalInput)
        """

        state = .generating

        do {
            let output = try await generate(userInput: refinementPrompt, isRefinement: true)
            let processingDuration = Date().timeIntervalSince(startTime ?? Date())

            let result = PowerModeResult(
                powerModeId: powerMode.id,
                powerModeName: powerMode.name,
                userInput: refinementPrompt,
                markdownOutput: output,
                processingDuration: processingDuration,
                versionNumber: session.results.count + 1,
                usedRAG: !powerMode.knowledgeDocumentIds.isEmpty,
                ragDocumentIds: powerMode.knowledgeDocumentIds
            )

            session.addResult(result)
            UIPasteboard.general.string = output
            state = .complete(session)
        } catch {
            handleError(.networkError(error.localizedDescription))
        }
    }

    /// Cancel the current operation
    func cancel() {
        audioRecorder.cancelRecording()
        state = .idle
        transcribedText = ""
        errorMessage = nil
    }

    /// Reset to idle state
    func reset() {
        state = .idle
        session = PowerModeSession()
        transcribedText = ""
        errorMessage = nil
        recordingDuration = 0
        audioLevel = 0
        audioLevels = Array(repeating: 0, count: 12)
        startTime = nil
    }

    /// Retry after error
    func retry() async {
        reset()
        await startRecording()
    }

    // MARK: - Transcription

    private func transcribe(audioURL: URL) async throws -> String {
        guard let provider = providerFactory.createSelectedTranscriptionProvider() else {
            throw TranscriptionError.providerNotConfigured
        }

        // Build prompt hint including context language hints
        let promptHint = buildTranscriptionHint()

        return try await provider.transcribe(
            audioURL: audioURL,
            language: activeContext?.languageHints.first,
            promptHint: promptHint
        )
    }

    /// Build transcription hint from vocabulary and context
    private func buildTranscriptionHint() -> String? {
        var hints: [String] = []

        // Add custom vocabulary (both recognized and replacement words)
        let vocabTerms = settings.vocabulary.flatMap { [$0.recognizedWord, $0.replacementWord] }
        if !vocabTerms.isEmpty {
            hints.append(contentsOf: Array(Set(vocabTerms))) // Dedupe
        }

        // Add context language hints
        if let context = activeContext {
            let langNames = context.languageHints.map { $0.displayName }
            if !langNames.isEmpty {
                hints.append("Languages: \(langNames.joined(separator: ", "))")
            }
        }

        return hints.isEmpty ? nil : hints.joined(separator: ", ")
    }

    // MARK: - Generation

    private func generate(
        userInput: String,
        isRegeneration: Bool = false,
        isRefinement: Bool = false
    ) async throws -> String {
        guard let provider = providerFactory.createSelectedTextFormattingProvider() else {
            throw TranscriptionError.providerNotConfigured
        }

        // Build the full prompt with context and memory injection
        let systemPrompt = buildSystemPrompt(isRegeneration: isRegeneration, isRefinement: isRefinement)

        // Use format method with custom prompt (system prompt)
        // The userInput becomes the "text" to format
        return try await provider.format(
            text: userInput,
            mode: .raw,
            customPrompt: systemPrompt,
            context: buildPromptContext()
        )
    }

    /// Build system prompt with all injections
    private func buildSystemPrompt(isRegeneration: Bool, isRefinement: Bool) -> String {
        var parts: [String] = []

        // 1. Power Mode instruction
        parts.append("## Role and Task")
        parts.append(powerMode.instruction)

        // 2. Output format
        if !powerMode.outputFormat.isEmpty {
            parts.append("\n## Output Format")
            parts.append(powerMode.outputFormat)
        }

        // 3. Active Context (if any)
        if let context = activeContext {
            parts.append("\n## Active Context: \(context.name)")

            if !context.toneDescription.isEmpty {
                parts.append("Tone: \(context.toneDescription)")
            }

            if !context.customInstructions.isEmpty {
                parts.append("Instructions: \(context.customInstructions)")
            }
        }

        // 4. Memory injection
        let memorySection = buildMemorySection()
        if !memorySection.isEmpty {
            parts.append("\n## Relevant Memory")
            parts.append(memorySection)
        }

        // 5. Special instructions for regeneration/refinement
        if isRegeneration {
            parts.append("\n## Note")
            parts.append("This is a regeneration request. Provide a fresh perspective while maintaining quality.")
        }

        if isRefinement {
            parts.append("\n## Note")
            parts.append("This is a refinement request. Focus on the specific refinement requested while preserving the good parts of the original output.")
        }

        return parts.joined(separator: "\n")
    }

    /// Build memory section based on enabled settings
    private func buildMemorySection() -> String {
        var memories: [String] = []

        // 1. Global memory (if enabled)
        if settings.globalMemoryEnabled, let globalMem = settings.globalMemory, !globalMem.isEmpty {
            memories.append("Global context: \(globalMem)")
        }

        // 2. Context memory (if context active and memory enabled)
        if let context = activeContext, context.memoryEnabled,
           let contextMem = context.memory, !contextMem.isEmpty {
            memories.append("Context (\(context.name)): \(contextMem)")
        }

        // 3. Power Mode memory (if enabled)
        if powerMode.memoryEnabled, let pmMem = powerMode.memory, !pmMem.isEmpty {
            memories.append("Workflow (\(powerMode.name)): \(pmMem)")
        }

        return memories.joined(separator: "\n")
    }

    /// Build PromptContext for provider
    private func buildPromptContext() -> PromptContext {
        return PromptContext.from(
            settings: settings,
            context: activeContext,
            powerMode: powerMode
        )
    }

    // MARK: - Memory Update

    /// Update memory after execution completes
    private func updateMemory(input: String, output: String) async {
        let textToRemember = "User: \(input)\nAssistant: \(String(output.prefix(500)))"

        _ = await memoryManager.updateMemory(
            from: textToRemember,
            context: activeContext,
            powerMode: powerMode
        )
    }

    // MARK: - Error Handling

    private func handleError(_ error: TranscriptionError) {
        let message = error.errorDescription ?? "An error occurred"
        state = .error(message)
        errorMessage = message
        audioRecorder.cancelRecording()
    }
}

// MARK: - Convenience Properties

extension PowerModeOrchestrator {
    /// Whether currently recording
    var isRecording: Bool {
        state == .recording
    }

    /// Whether processing
    var isProcessing: Bool {
        switch state {
        case .transcribing, .thinking, .queryingKnowledge, .generating:
            return true
        default:
            return false
        }
    }

    /// Whether complete
    var isComplete: Bool {
        if case .complete = state { return true }
        return false
    }

    /// Whether there was an error
    var hasError: Bool {
        if case .error = state { return true }
        return false
    }

    /// Whether idle
    var isIdle: Bool {
        state == .idle
    }

    /// Current result text
    var resultText: String {
        session.currentResult?.markdownOutput ?? ""
    }

    /// Active context name for display
    var activeContextName: String? {
        activeContext?.name
    }

    /// Whether context is active
    var hasActiveContext: Bool {
        activeContext != nil
    }

    /// Memory sources being used
    var activeMemorySources: [String] {
        var sources: [String] = []
        if settings.globalMemoryEnabled && settings.globalMemory != nil {
            sources.append("Global")
        }
        if let ctx = activeContext, ctx.memoryEnabled && ctx.memory != nil {
            sources.append(ctx.name)
        }
        if powerMode.memoryEnabled && powerMode.memory != nil {
            sources.append(powerMode.name)
        }
        return sources
    }
}
