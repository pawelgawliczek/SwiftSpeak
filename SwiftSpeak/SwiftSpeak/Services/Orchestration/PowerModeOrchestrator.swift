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
import SwiftSpeakCore

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
    // NOTE: memoryManager removed - memory updates now handled by MemoryUpdateScheduler
    private let ragOrchestrator: RAGOrchestrator
    private let webhookExecutor: WebhookExecutor
    private var cancellables = Set<AnyCancellable>()

    // MARK: - RAG State

    /// Last RAG query result (used in prompt building)
    private var lastRAGResult: RAGQueryResult?

    // MARK: - Obsidian Search State (Manual Search Step)

    /// Search query for manual Obsidian search
    @Published var obsidianSearchQuery: String = ""

    /// Whether currently searching Obsidian
    @Published private(set) var isSearchingObsidian: Bool = false

    /// Manual search results (separate from auto-loaded)
    @Published var manualObsidianResults: [ObsidianSearchResult] = []

    /// Selected result IDs (for filtering which results go to LLM)
    @Published var selectedObsidianResultIds: Set<UUID> = []

    /// Whether currently dictating search query
    @Published private(set) var isDictatingSearchQuery: Bool = false

    // MARK: - Token Counter

    /// Estimated token count for current context configuration
    var contextTokens: TokenCounter.ContextTokens {
        TokenCounter.countContextTokens(
            systemPrompt: powerMode.instruction,
            globalMemory: settings.globalMemoryEnabled ? settings.globalMemory : nil,
            powerModeMemory: powerMode.memoryEnabled ? powerMode.memory : nil,
            ragDocuments: [], // RAG docs loaded at runtime
            obsidianNotes: selectedObsidianResults.map { $0.chunkContent },
            selectedText: nil, // iOS doesn't have window context like macOS
            clipboardText: nil, // Not configured in iOS idle state
            webhookContext: nil // Webhooks loaded at runtime
        )
    }

    // MARK: - Obsidian State (Phase 3)

    /// Obsidian query service (optional)
    private var obsidianQueryService: ObsidianQueryService?

    /// Last combined RAG result (Power Mode docs + Obsidian vaults)
    private var lastCombinedRAGResult: CombinedRAGResult?

    // MARK: - Webhook State

    /// Context fetched from webhooks (used in prompt building)
    private var webhookContextResults: [WebhookExecutor.ContextSourceResult] = []

    // MARK: - Obsidian Action State (Phase 4)

    /// Pending Obsidian action for UI confirmation
    @Published private(set) var pendingObsidianAction: (action: ObsidianActionConfig, content: String)?

    /// Obsidian note writer
    private let noteWriter = ObsidianNoteWriter()

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
        ragOrchestrator: RAGOrchestrator? = nil,
        webhookExecutor: WebhookExecutor? = nil,
        setupBindings: Bool = false
    ) {
        // Initialize all stored properties first
        self.powerMode = powerMode
        self.settings = settings
        self.audioRecorder = audioRecorder
        self.providerFactory = providerFactory
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
        // If Obsidian is enabled and we're in idle, go to search first
        if state == .idle && hasObsidianEnabled {
            startObsidianSearch()
            return
        }

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

            // Query knowledge base if configured (Phase 4e - RAG + Phase 3 - Obsidian)
            lastRAGResult = nil
            lastCombinedRAGResult = nil

            // Check if we have manually selected Obsidian results from search step
            let hasManualObsidianSelection = !selectedObsidianResultIds.isEmpty && !manualObsidianResults.isEmpty

            if !powerMode.knowledgeDocumentIds.isEmpty || (!powerMode.obsidianVaultIds.isEmpty && !hasManualObsidianSelection) {
                state = .queryingKnowledge
                do {
                    // Configure RAG if needed
                    if !ragOrchestrator.isConfigured,
                       let openAIKey = settings.openAIAPIKey,
                       !openAIKey.isEmpty {
                        try ragOrchestrator.configure(openAIApiKey: openAIKey)
                    }

                    // Initialize Obsidian query service if needed
                    if obsidianQueryService == nil, !powerMode.obsidianVaultIds.isEmpty {
                        obsidianQueryService = try await ObsidianQueryService.create(from: settings)
                    }

                    // Query for relevant context (combined Power Mode docs + Obsidian)
                    if ragOrchestrator.isConfigured {
                        lastCombinedRAGResult = try await ragOrchestrator.queryWithObsidian(
                            query: processedInput,
                            powerMode: powerMode,
                            obsidianQueryService: obsidianQueryService
                        )
                    }
                } catch {
                    // RAG failure is non-fatal - continue without RAG context
                    appLog("RAG/Obsidian query failed (non-fatal): \(LogSanitizer.sanitizeError(error))", category: "RAG", level: .warning)
                }
            } else if hasManualObsidianSelection {
                // Use manually selected Obsidian results
                state = .queryingKnowledge
                lastCombinedRAGResult = CombinedRAGResult(
                    documentResults: [],
                    obsidianResults: selectedObsidianResults
                )
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
                ragDocumentIds: powerMode.knowledgeDocumentIds,
                // Memory tracking - capture state for batch memory updates
                globalMemoryEnabled: settings.globalMemoryEnabled,
                contextMemoryEnabled: activeContext?.useContextMemory ?? false,
                powerModeMemoryEnabled: powerMode.memoryEnabled,
                usedForGlobalMemory: false,
                usedForContextMemory: false,
                usedForPowerModeMemory: false
            )

            // Add to session
            session.addResult(result)

            // Update usage count
            settings.incrementPowerModeUsage(id: powerMode.id)

            // Copy to clipboard
            UIPasteboard.general.string = output

            // NOTE: Memory updates removed - now handled by MemoryUpdateScheduler on app start/foreground

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

            // Handle Obsidian action (Phase 4)
            if let action = powerMode.obsidianAction, action.action != .none {
                if action.autoExecute {
                    // Auto-execute: save directly without confirmation
                    Task {
                        await executeObsidianAction(action, content: output)
                    }
                } else {
                    // Store pending action for UI confirmation
                    pendingObsidianAction = (action, output)
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
                ragDocumentIds: powerMode.knowledgeDocumentIds,
                // Memory tracking - capture state for batch memory updates
                globalMemoryEnabled: settings.globalMemoryEnabled,
                contextMemoryEnabled: activeContext?.useContextMemory ?? false,
                powerModeMemoryEnabled: powerMode.memoryEnabled,
                usedForGlobalMemory: false,
                usedForContextMemory: false,
                usedForPowerModeMemory: false
            )

            session.addResult(result)
            settings.incrementPowerModeUsage(id: powerMode.id)
            UIPasteboard.general.string = output

            // NOTE: Memory updates removed - now handled by MemoryUpdateScheduler on app start/foreground

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
                ragDocumentIds: powerMode.knowledgeDocumentIds,
                // Memory tracking - capture state for batch memory updates
                globalMemoryEnabled: settings.globalMemoryEnabled,
                contextMemoryEnabled: activeContext?.useContextMemory ?? false,
                powerModeMemoryEnabled: powerMode.memoryEnabled,
                usedForGlobalMemory: false,
                usedForContextMemory: false,
                usedForPowerModeMemory: false
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
                ragDocumentIds: powerMode.knowledgeDocumentIds,
                // Memory tracking - capture state for batch memory updates
                globalMemoryEnabled: settings.globalMemoryEnabled,
                contextMemoryEnabled: activeContext?.useContextMemory ?? false,
                powerModeMemoryEnabled: powerMode.memoryEnabled,
                usedForGlobalMemory: false,
                usedForContextMemory: false,
                usedForPowerModeMemory: false
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

        // Reset Obsidian search state
        obsidianSearchQuery = ""
        manualObsidianResults = []
        selectedObsidianResultIds = []
        isDictatingSearchQuery = false
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
            ragDocumentIds: currentResult.ragDocumentIds,
            // Preserve memory tracking from original result
            globalMemoryEnabled: currentResult.globalMemoryEnabled,
            contextMemoryEnabled: currentResult.contextMemoryEnabled,
            powerModeMemoryEnabled: currentResult.powerModeMemoryEnabled,
            usedForGlobalMemory: currentResult.usedForGlobalMemory,
            usedForContextMemory: currentResult.usedForContextMemory,
            usedForPowerModeMemory: currentResult.usedForPowerModeMemory
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

        // Build prompt hint from context (domain jargon, vocabulary)
        let promptContext = PromptContext.from(
            context: activeContext,
            powerMode: powerMode,
            globalMemory: settings.globalMemory,
            vocabularyEntries: settings.vocabularyEntries
        )
        let promptHint = promptContext.buildTranscriptionHint()

        return try await provider.transcribe(
            audioURL: audioURL,
            language: nil,
            promptHint: promptHint
        )
    }

    /// Build transcription hint from vocabulary and context
    private func buildTranscriptionHint() -> String? {
        // Use PromptContext for consistent hint building
        let promptContext = PromptContext.from(
            context: activeContext,
            powerMode: powerMode,
            globalMemory: settings.globalMemory,
            vocabularyEntries: settings.vocabularyEntries
        )
        return promptContext.buildTranscriptionHint()
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

            // Add formatting style based on selected instructions
            let styleChips = context.selectedInstructions.intersection(["formal", "casual", "concise"])
            if !styleChips.isEmpty {
                parts.append("Style: \(styleChips.joined(separator: ", "))")
            }

            if let instructions = context.customInstructions, !instructions.isEmpty {
                parts.append("Instructions: \(instructions)")
            }
        }

        // 4. Memory injection
        let memorySection = buildMemorySection()
        if !memorySection.isEmpty {
            parts.append("\n## Relevant Memory")
            parts.append(memorySection)
        }

        // 5. RAG context injection (Phase 4e + Phase 3 - Obsidian)
        if let combined = lastCombinedRAGResult, combined.hasResults {
            // Use formatted combined context from CombinedRAGResult
            parts.append("\n" + combined.combinedContext)
            parts.append("Use this information to inform your response when relevant.")
        } else if let ragResult = lastRAGResult, !ragResult.chunks.isEmpty {
            // Fallback to legacy RAG-only context
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
        if let context = activeContext, context.useContextMemory,
           let contextMem = context.contextMemory, !contextMem.isEmpty {
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
            context: activeContext,
            powerMode: powerMode,
            globalMemory: settings.globalMemory,
            vocabularyEntries: settings.vocabularyEntries
        )
    }

    // NOTE: Memory updates removed - now handled by MemoryUpdateScheduler on app start/foreground

    // MARK: - Error Handling

    private func handleError(_ error: TranscriptionError) {
        let message = error.errorDescription ?? "An error occurred"
        state = .error(message)
        errorMessage = message
        audioRecorder.cancelRecording()
    }
}

// MARK: - Obsidian Search Methods

extension PowerModeOrchestrator {

    /// Check if Power Mode has Obsidian enabled
    var hasObsidianEnabled: Bool {
        powerMode.inputConfig.includeObsidianVaults && !powerMode.obsidianVaultIds.isEmpty
    }

    /// Transition to Obsidian search (from idle or after context)
    func startObsidianSearch() {
        // Pre-fill with default search query from Power Mode
        obsidianSearchQuery = powerMode.defaultObsidianSearchQuery
        manualObsidianResults = []
        selectedObsidianResultIds = []
        state = .obsidianSearch
    }

    /// Perform Obsidian search
    func searchObsidian() async {
        // If empty query, load all notes instead
        if obsidianSearchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            await loadAllObsidianNotes()
            return
        }

        isSearchingObsidian = true
        defer { isSearchingObsidian = false }

        do {
            // Initialize Obsidian query service if needed
            if obsidianQueryService == nil {
                obsidianQueryService = try await ObsidianQueryService.create(from: settings)
            }

            guard let service = obsidianQueryService else { return }

            // Query Obsidian vaults
            manualObsidianResults = try await service.query(
                text: obsidianSearchQuery,
                vaultIds: powerMode.obsidianVaultIds,
                maxChunks: powerMode.maxObsidianChunks
            )

            // Select all results by default
            selectedObsidianResultIds = Set(manualObsidianResults.map { $0.id })

        } catch {
            appLog("Obsidian search failed: \(LogSanitizer.sanitizeError(error))", category: "Obsidian", level: .error)
            errorMessage = error.localizedDescription
        }
    }

    /// Load all Obsidian notes from configured vaults (no filtering)
    func loadAllObsidianNotes() async {
        isSearchingObsidian = true
        defer { isSearchingObsidian = false }

        do {
            // Initialize Obsidian query service if needed
            if obsidianQueryService == nil {
                obsidianQueryService = try await ObsidianQueryService.create(from: settings)
            }

            guard let service = obsidianQueryService else { return }

            // Get all notes from configured vaults
            manualObsidianResults = try await service.getAllNotes(
                vaultIds: powerMode.obsidianVaultIds,
                maxResults: 50 // Limit to prevent overwhelming
            )

            // Select all results by default
            selectedObsidianResultIds = Set(manualObsidianResults.map { $0.id })

        } catch {
            appLog("Failed to load Obsidian notes: \(LogSanitizer.sanitizeError(error))", category: "Obsidian", level: .error)
            // Don't set error message - this is a background operation
        }
    }

    /// Toggle selection of a result
    func toggleResultSelection(_ resultId: UUID) {
        if selectedObsidianResultIds.contains(resultId) {
            selectedObsidianResultIds.remove(resultId)
        } else {
            selectedObsidianResultIds.insert(resultId)
        }
    }

    /// Toggle result by index (1-9 keyboard shortcut)
    func toggleResultByIndex(_ index: Int) {
        guard index > 0, index <= manualObsidianResults.count else { return }
        let result = manualObsidianResults[index - 1]
        toggleResultSelection(result.id)
    }

    /// Select all results
    func selectAllResults() {
        selectedObsidianResultIds = Set(manualObsidianResults.map { $0.id })
    }

    /// Deselect all results
    func deselectAllResults() {
        selectedObsidianResultIds.removeAll()
    }

    /// Selected Obsidian results
    var selectedObsidianResults: [ObsidianSearchResult] {
        manualObsidianResults.filter { selectedObsidianResultIds.contains($0.id) }
    }

    /// Proceed from Obsidian search to recording
    func proceedFromObsidianSearch() async {
        // Store selected results for use in prompt building
        // The lastCombinedRAGResult will be built with these selected results
        await startRecording()
    }

    /// Start voice dictation for search query
    func startSearchDictation() async {
        isDictatingSearchQuery = true
        do {
            try await audioRecorder.startRecording()
        } catch {
            isDictatingSearchQuery = false
            errorMessage = error.localizedDescription
        }
    }

    /// Stop voice dictation and transcribe to search query
    func stopSearchDictation() async {
        guard isDictatingSearchQuery else { return }

        do {
            let audioURL = try audioRecorder.stopRecording()
            let transcribed = try await transcribe(audioURL: audioURL)
            obsidianSearchQuery = settings.applyVocabulary(to: transcribed)
            audioRecorder.deleteRecording()
        } catch {
            errorMessage = error.localizedDescription
        }

        isDictatingSearchQuery = false
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
        if let ctx = activeContext, ctx.useContextMemory && ctx.contextMemory != nil {
            sources.append(ctx.name)
        }
        if powerMode.memoryEnabled && powerMode.memory != nil {
            sources.append(powerMode.name)
        }
        return sources
    }

    // MARK: - Obsidian Action Execution (Phase 4)

    /// Execute a pending Obsidian action (called from UI confirmation)
    func confirmPendingObsidianAction() async {
        guard let pending = pendingObsidianAction else { return }

        await executeObsidianAction(pending.action, content: pending.content)
        pendingObsidianAction = nil
    }

    /// Cancel pending Obsidian action
    func cancelPendingObsidianAction() {
        pendingObsidianAction = nil
    }

    /// Execute an Obsidian action
    private func executeObsidianAction(_ action: ObsidianActionConfig, content: String) async {
        // Find the target vault
        guard let vault = settings.obsidianVaults.first(where: { $0.id == action.targetVaultId }) else {
            appLog("Obsidian action failed: vault not found \(action.targetVaultId)", category: "Obsidian", level: .error)
            return
        }

        do {
            switch action.action {
            case .appendToDaily:
                try await noteWriter.appendToDaily(content: content, vault: vault)
                appLog("Appended to daily note in vault: \(vault.name)", category: "Obsidian")

            case .appendToNote:
                guard let targetNote = action.targetNoteName else {
                    appLog("Obsidian action failed: no target note specified", category: "Obsidian", level: .error)
                    return
                }
                try await noteWriter.appendToNote(
                    content: content,
                    notePath: targetNote,
                    vault: vault,
                    createIfNeeded: false
                )
                appLog("Appended to note '\(targetNote)' in vault: \(vault.name)", category: "Obsidian")

            case .createNote:
                let title = action.targetNoteName ?? "Power Mode Output"
                let createdPath = try await noteWriter.createNote(
                    title: title,
                    content: content,
                    vault: vault
                )
                appLog("Created note '\(createdPath)' in vault: \(vault.name)", category: "Obsidian")

            case .none:
                break
            }
        } catch {
            appLog("Obsidian action failed: \(LogSanitizer.sanitizeError(error))", category: "Obsidian", level: .error)
        }
    }
}
