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
    private let ragOrchestrator: RAGOrchestrator
    private let webhookExecutor: WebhookExecutor
    private var cancellables = Set<AnyCancellable>()

    // MARK: - RAG State

    /// Last RAG query result (used in prompt building)
    private var lastRAGResult: RAGQueryResult?

    // MARK: - Webhook State

    /// Context fetched from webhooks (used in prompt building)
    private var webhookContextResults: [WebhookExecutor.ContextSourceResult] = []

    // MARK: - Timing

    private var startTime: Date?

    // MARK: - Streaming

    /// Task for active streaming generation (for cancellation support)
    private var generationTask: Task<Void, Never>?

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
            ragOrchestrator: RAGOrchestrator(),
            webhookExecutor: WebhookExecutor(settings: resolvedSettings),
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
        ragOrchestrator: RAGOrchestrator? = nil,
        webhookExecutor: WebhookExecutor? = nil,
        setupBindings: Bool = false
    ) {
        // Initialize all stored properties first
        self.powerMode = powerMode
        self.settings = settings
        self.audioRecorder = audioRecorder
        self.providerFactory = providerFactory
        self.memoryManager = memoryManager
        self.ragOrchestrator = ragOrchestrator ?? RAGOrchestrator()
        self.webhookExecutor = webhookExecutor ?? WebhookExecutor(settings: settings)

        // Setup bindings after all properties are initialized
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

            // Fetch context from webhooks (Phase 4f)
            webhookContextResults = []
            if !powerMode.enabledWebhookIds.isEmpty {
                let contextWebhooks = settings.enabledWebhooks(for: powerMode, ofType: .contextSource)
                if !contextWebhooks.isEmpty {
                    webhookContextResults = await webhookExecutor.fetchContext(for: powerMode)
                }
            }

            // Query knowledge base if configured (Phase 4e - RAG)
            lastRAGResult = nil
            if !powerMode.knowledgeDocumentIds.isEmpty {
                state = .queryingKnowledge
                do {
                    // Configure RAG if needed
                    if !ragOrchestrator.isConfigured,
                       let openAIKey = settings.openAIAPIKey,
                       !openAIKey.isEmpty {
                        try ragOrchestrator.configure(openAIApiKey: openAIKey)
                    }

                    // Query for relevant context
                    if ragOrchestrator.isConfigured {
                        lastRAGResult = try await ragOrchestrator.query(processedInput, powerMode: powerMode)
                    }
                } catch {
                    // RAG failure is non-fatal - continue without RAG context
                    appLog("RAG query failed (non-fatal): \(LogSanitizer.sanitizeError(error))", category: "RAG", level: .warning)
                }
            }

            // Generate response (streaming or blocking)
            let output: String = try await withCheckedThrowingContinuation { continuation in
                generationTask = Task {
                    do {
                        if let streamingOutput = try await generateWithStreaming(userInput: processedInput) {
                            continuation.resume(returning: streamingOutput)
                        } else {
                            await MainActor.run { state = .generating }
                            let result = try await generate(userInput: processedInput)
                            continuation.resume(returning: result)
                        }
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

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

            // Execute output webhooks (Phase 4f - non-blocking)
            if !powerMode.enabledWebhookIds.isEmpty {
                Task {
                    let contextName = activeContext?.name
                    // Send to output destinations
                    _ = await webhookExecutor.sendOutput(
                        for: powerMode,
                        input: processedInput,
                        output: output,
                        contextName: contextName
                    )
                    // Trigger automation webhooks
                    _ = await webhookExecutor.triggerAutomations(
                        for: powerMode,
                        input: processedInput,
                        output: output,
                        contextName: contextName
                    )
                }
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

    /// Update the current result's output text (for manual editing)
    func updateCurrentResultText(_ newText: String) {
        guard let currentResult = session.currentResult else { return }
        guard session.currentVersionIndex < session.results.count else { return }

        let updatedResult = PowerModeResult(
            powerModeId: currentResult.powerModeId,
            powerModeName: currentResult.powerModeName,
            userInput: currentResult.userInput,
            markdownOutput: newText,
            processingDuration: currentResult.processingDuration,
            versionNumber: currentResult.versionNumber,
            usedRAG: currentResult.usedRAG,
            ragDocumentIds: currentResult.ragDocumentIds
        )

        session.results[session.currentVersionIndex] = updatedResult

        // Update clipboard with edited text
        UIPasteboard.general.string = newText
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

        // Phase 10: Check privacy mode - block cloud providers
        if settings.forcePrivacyMode && !provider.providerId.isLocalProvider {
            throw TranscriptionError.privacyModeBlocksCloudProvider(provider.providerId.displayName)
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

    /// Generate with streaming if supported and enabled
    /// Returns nil if streaming is not available or disabled
    private func generateWithStreaming(
        userInput: String,
        isRegeneration: Bool = false,
        isRefinement: Bool = false
    ) async throws -> String? {
        // Check if streaming is enabled in settings
        guard settings.powerModeStreamingEnabled else { return nil }

        // Get provider and check if it supports streaming
        guard let provider = providerFactory.createSelectedTextFormattingProvider(),
              let streamingProvider = provider as? StreamingFormattingProvider,
              streamingProvider.supportsStreaming else {
            return nil
        }

        // Phase 10: Check privacy mode - block cloud providers
        if settings.forcePrivacyMode && !provider.providerId.isLocalProvider {
            throw TranscriptionError.privacyModeBlocksCloudProvider(provider.providerId.displayName)
        }

        // Build system prompt
        let systemPrompt = buildSystemPrompt(isRegeneration: isRegeneration, isRefinement: isRefinement)

        // Start streaming
        var accumulatedText = ""
        await MainActor.run {
            state = .streaming("")
        }

        do {
            for try await chunk in streamingProvider.formatStreaming(
                text: userInput,
                mode: .raw,
                customPrompt: systemPrompt,
                context: buildPromptContext()
            ) {
                // Check for cancellation
                try Task.checkCancellation()

                accumulatedText += chunk
                await MainActor.run {
                    state = .streaming(accumulatedText)
                }
            }

            return accumulatedText

        } catch is CancellationError {
            // Handle cancellation gracefully - return partial result
            if !accumulatedText.isEmpty {
                return accumulatedText + "\n\n*[Generation cancelled]*"
            }
            throw CancellationError()
        } catch {
            // If streaming failed mid-way, return partial result if any
            if !accumulatedText.isEmpty {
                return accumulatedText + "\n\n*[Generation interrupted]*"
            }
            throw error
        }
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

        // 5. RAG context injection (Phase 4e)
        if let ragResult = lastRAGResult, !ragResult.chunks.isEmpty {
            parts.append("\n## Knowledge Base Context")
            parts.append("The following relevant information was retrieved from attached documents:")
            parts.append("Sources: \(ragResult.documentNames.joined(separator: ", "))")
            parts.append("")
            for (index, result) in ragResult.chunks.prefix(5).enumerated() {
                parts.append("### Excerpt \(index + 1) (from \(result.documentName))")
                parts.append(result.chunk.content)
                parts.append("")
            }
            parts.append("Use this information to inform your response when relevant.")
        }

        // 6. Webhook context injection (Phase 4f)
        let successfulWebhookContexts = webhookContextResults.filter { $0.error == nil && $0.content != nil }
        if !successfulWebhookContexts.isEmpty {
            parts.append("\n## External Context (from webhooks)")
            for result in successfulWebhookContexts {
                parts.append("### \(result.webhookName)")
                if let content = result.content {
                    // Truncate very long responses
                    let truncated = content.count > 2000 ? String(content.prefix(2000)) + "..." : content
                    parts.append(truncated)
                }
                parts.append("")
            }
        }

        // 7. Special instructions for regeneration/refinement
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
        case .transcribing, .thinking, .queryingKnowledge, .generating, .streaming:
            return true
        default:
            return false
        }
    }

    /// Whether currently streaming
    var isStreaming: Bool {
        state.isStreaming
    }

    /// Current streaming text (if streaming)
    var streamingText: String? {
        state.streamingText
    }

    /// Cancel active generation (useful during streaming)
    /// The streaming code handles partial results and state transitions
    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
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
