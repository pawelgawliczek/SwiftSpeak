//
//  MacPowerModeOverlayViewModel.swift
//  SwiftSpeakMac
//
//  View model for Power Mode overlay with 6 execution states
//  Phase 5: Manages state, context, and AI interaction
//

import Foundation
import SwiftUI
import Combine
import AppKit
import SwiftSpeakCore

// MARK: - Overlay State

/// Use shared state enum from SwiftSpeakCore
typealias OverlayState = PowerModeExecutionState

// MARK: - Power Mode Overlay View Model

@MainActor
final class MacPowerModeOverlayViewModel: ObservableObject {

    // MARK: - Published State

    @Published var state: OverlayState = .contextPreview

    /// Window context captured from active app
    @Published var windowContext: WindowContext?

    /// Obsidian search results
    @Published var obsidianResults: [ObsidianSearchResult] = []

    /// Memory context (global + context + power mode)
    @Published var memoryContext: String = ""

    /// User's voice/text input
    @Published var userInput: String = ""

    /// AI's response text
    @Published var aiResponse: String = ""

    /// AI's clarifying question (if any)
    @Published var aiQuestion: String?

    /// Answer to AI's question
    @Published var questionAnswer: String = ""

    // MARK: - Context Toggles (derived from PowerMode inputConfig)

    /// Include window context (selected text, active app text)
    var includeWindowContext: Bool {
        currentPowerMode.inputConfig.includeSelectedText ||
        currentPowerMode.inputConfig.includeActiveAppText
    }

    /// Include Obsidian vault search
    var includeObsidian: Bool {
        currentPowerMode.inputConfig.includeObsidianVaults &&
        !currentPowerMode.obsidianVaultIds.isEmpty
    }

    /// Include memory (global + power mode)
    var includeMemory: Bool {
        currentPowerMode.inputConfig.includeGlobalMemory ||
        currentPowerMode.inputConfig.includePowerModeMemory
    }

    /// Include clipboard content
    var includeClipboard: Bool {
        currentPowerMode.inputConfig.includeClipboard
    }

    /// Clipboard content
    @Published var clipboardContent: String = ""

    // MARK: - Recording State

    @Published var isRecording: Bool = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0

    // MARK: - Error State

    @Published var errorMessage: String?

    // MARK: - Loading State

    /// Whether Obsidian notes are being loaded in background
    @Published var isLoadingObsidianContext: Bool = false

    // MARK: - Obsidian Search State

    /// Search query for manual Obsidian search
    @Published var obsidianSearchQuery: String = ""

    /// Whether currently searching Obsidian
    @Published var isSearchingObsidian: Bool = false

    /// Manual search results (separate from auto-loaded results)
    @Published var manualObsidianResults: [ObsidianSearchResult] = []

    /// Selected result IDs (for filtering which results go to LLM)
    @Published var selectedObsidianResultIds: Set<UUID> = []

    /// Whether voice dictation is active for search query
    @Published var isDictatingSearchQuery: Bool = false

    // MARK: - Configuration

    @Published var currentPowerMode: PowerMode
    var availablePowerModes: [PowerMode]
    let settings: MacSettings  // Exposed for view access to obsidianVaults
    private let windowContextService: MacWindowContextService
    private let audioRecorder: MacAudioRecorder
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Token Count

    /// Estimated token count for current context
    var contextTokens: TokenCounter.ContextTokens {
        // Use obsidianResults (from loadContext) in contextPreview, selectedObsidianResults after search
        let obsidianContent: [String]
        if state == .contextPreview {
            obsidianContent = obsidianResults.map { $0.content }
        } else {
            obsidianContent = selectedObsidianResults.map { $0.content }
        }

        return TokenCounter.countContextTokens(
            systemPrompt: currentPowerMode.instruction,
            globalMemory: includeMemory ? settings.globalMemory : nil,
            powerModeMemory: currentPowerMode.memoryEnabled ? currentPowerMode.memory : nil,
            ragDocuments: [], // RAG docs loaded separately
            obsidianNotes: obsidianContent,
            selectedText: windowContext?.selectedText,
            clipboardText: includeClipboard ? clipboardContent : nil,
            webhookContext: nil // Webhooks loaded during execution
        )
    }

    /// Selected Obsidian results (filtered by selection)
    var selectedObsidianResults: [ObsidianSearchResult] {
        manualObsidianResults.filter { selectedObsidianResultIds.contains($0.id) }
    }

    // MARK: - Dependencies (injected later)

    private var providerFactory: ProviderFactory?
    private var obsidianQueryService: MacObsidianQueryService?
    // Note: Using Mac-specific query service - see MacObsidianQueryService.swift
    private var textInsertion: MacTextInsertionService?

    // MARK: - Initialization

    init(
        powerMode: PowerMode,
        allPowerModes: [PowerMode],
        settings: MacSettings,
        windowContextService: MacWindowContextService,
        audioRecorder: MacAudioRecorder
    ) {
        self.currentPowerMode = powerMode
        self.availablePowerModes = allPowerModes.filter { !$0.isArchived }
        self.settings = settings
        self.windowContextService = windowContextService
        self.audioRecorder = audioRecorder

        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Bind recording state
        audioRecorder.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)

        audioRecorder.$duration
            .receive(on: DispatchQueue.main)
            .assign(to: &$recordingDuration)

        audioRecorder.$currentLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)
    }

    /// Set dependencies after initialization
    func setDependencies(
        providerFactory: ProviderFactory,
        obsidianQueryService: MacObsidianQueryService?,
        textInsertion: MacTextInsertionService
    ) {
        self.providerFactory = providerFactory
        self.obsidianQueryService = obsidianQueryService
        self.textInsertion = textInsertion
    }

    // MARK: - Pre-captured Context

    /// Pre-captured window context (captured before overlay shows)
    private var preCapturedWindowContext: WindowContext?
    private var preCapturedClipboard: String?

    /// Set pre-captured context (call BEFORE showing overlay)
    func setPreCapturedContext(windowContext: WindowContext?, clipboard: String?) {
        self.preCapturedWindowContext = windowContext
        self.preCapturedClipboard = clipboard
    }

    /// Update visible text async (called after window text capture completes)
    func updateVisibleText(_ text: String) {
        // Update the window context with the new visible text
        if var ctx = windowContext {
            windowContext = WindowContext(
                appName: ctx.appName,
                appBundleId: ctx.appBundleId,
                windowTitle: ctx.windowTitle,
                selectedText: ctx.selectedText,
                visibleText: text,
                capturedAt: ctx.capturedAt
            )
            macLog("Updated window context with visible text: \(text.prefix(50))...", category: "PowerMode")
        } else if let pre = preCapturedWindowContext {
            // Create new context with visible text
            windowContext = WindowContext(
                appName: pre.appName,
                appBundleId: pre.appBundleId,
                windowTitle: pre.windowTitle,
                selectedText: pre.selectedText,
                visibleText: text,
                capturedAt: Date()
            )
            macLog("Created window context with visible text: \(text.prefix(50))...", category: "PowerMode")
        }
    }

    // MARK: - Context Loading

    /// Load all context sources based on Power Mode inputConfig
    func loadContext() async {
        let inputConfig = currentPowerMode.inputConfig

        // Use pre-captured window context (captured before overlay opened)
        if inputConfig.includeSelectedText || inputConfig.includeActiveAppText {
            if let preCaptured = preCapturedWindowContext {
                windowContext = preCaptured
                macLog("Using pre-captured window context from \(preCaptured.appName)", category: "PowerMode")
            } else {
                // Fallback: try to capture (won't work well since overlay is now frontmost)
                do {
                    windowContext = try await windowContextService.captureWindowContext()
                } catch {
                    macLog("Failed to capture window context: \(error)", category: "PowerMode")
                    windowContext = nil
                }
            }
        } else {
            windowContext = nil
        }

        // Use pre-captured clipboard or capture fresh
        if inputConfig.includeClipboard {
            if let preCaptured = preCapturedClipboard {
                clipboardContent = preCaptured
            } else if let clipboard = NSPasteboard.general.string(forType: .string) {
                clipboardContent = clipboard
            } else {
                clipboardContent = ""
            }
        } else {
            clipboardContent = ""
        }

        // Load memory context based on config (fast, no network)
        memoryContext = buildMemoryContext()

        // Query Obsidian in background (non-blocking) if enabled
        if inputConfig.includeObsidianVaults,
           !currentPowerMode.obsidianVaultIds.isEmpty,
           let obsidianService = obsidianQueryService {
            // Start loading in background
            isLoadingObsidianContext = true
            Task {
                await loadObsidianContext(service: obsidianService)
            }
        } else {
            obsidianResults = []
        }
    }

    /// Load Obsidian context in background
    private func loadObsidianContext(service: MacObsidianQueryService) async {
        defer { isLoadingObsidianContext = false }

        do {
            // If default search query is configured, use it for searching
            if !currentPowerMode.defaultObsidianSearchQuery.isEmpty {
                let results = try await service.search(
                    query: currentPowerMode.defaultObsidianSearchQuery,
                    vaultIds: currentPowerMode.obsidianVaultIds,
                    maxResults: currentPowerMode.maxObsidianChunks
                )
                obsidianResults = results
            } else {
                // No default search = load all notes
                let results = try await service.getAllNotes(
                    vaultIds: currentPowerMode.obsidianVaultIds,
                    maxResults: 50
                )
                obsidianResults = results
            }
        } catch {
            macLog("Failed to query Obsidian: \(error)", category: "PowerMode")
            obsidianResults = []
        }
    }

    /// Build combined memory context based on inputConfig
    private func buildMemoryContext() -> String {
        let inputConfig = currentPowerMode.inputConfig
        var parts: [String] = []

        // Global memory (if enabled in inputConfig)
        if inputConfig.includeGlobalMemory,
           let globalMem = settings.globalMemory, !globalMem.isEmpty {
            parts.append("Global Memory:\n\(globalMem)")
        }

        // Context memory (always included if available and global memory is enabled)
        if inputConfig.includeGlobalMemory,
           let context = settings.activeContext,
           let contextMem = context.contextMemory,
           !contextMem.isEmpty {
            parts.append("Context Memory (\(context.name)):\n\(contextMem)")
        }

        // Power mode memory (if enabled in inputConfig)
        if inputConfig.includePowerModeMemory,
           let memory = currentPowerMode.memory, !memory.isEmpty {
            parts.append("Power Mode Memory (\(currentPowerMode.name)):\n\(memory)")
        }

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Recording

    func startRecording() async {
        // If Obsidian is enabled and we're in contextPreview, go to search first
        if state == .contextPreview && hasObsidianEnabled {
            startObsidianSearch()
            return
        }

        state = .recording
        errorMessage = nil

        do {
            try await audioRecorder.startRecording()
        } catch {
            errorMessage = error.localizedDescription
            state = .contextPreview
        }
    }

    func stopRecording() async {
        guard audioRecorder.isRecording else { return }

        state = .processing

        do {
            let audioURL = try audioRecorder.stopRecording()

            // Transcribe audio
            guard let provider = providerFactory,
                  let transcriptionService = provider.createTranscriptionProvider(for: settings.selectedTranscriptionProvider) else {
                throw NSError(domain: "PowerMode", code: 1, userInfo: [NSLocalizedDescriptionKey: "Transcription provider not configured"])
            }

            userInput = try await transcriptionService.transcribe(
                audioURL: audioURL,
                language: settings.selectedDictationLanguage,
                promptHint: buildVocabularyPrompt()
            )

            // Send to AI
            await sendToAI()

        } catch {
            errorMessage = error.localizedDescription
            state = .contextPreview
        }
    }

    func cancelRecording() {
        audioRecorder.cancelRecording()
        state = .contextPreview
        errorMessage = nil
    }

    // MARK: - AI Interaction

    func sendToAI() async {
        guard !userInput.isEmpty else { return }

        state = .processing
        errorMessage = nil

        do {
            // Build prompts using shared PowerModePromptBuilder
            let promptInput = buildPromptInput()
            let (systemPrompt, userMessage) = PowerModePromptBuilder.buildPrompt(for: promptInput)

            // Get LLM provider
            guard let provider = providerFactory,
                  let llmService = provider.createFormattingProvider(for: settings.selectedPowerModeProvider) else {
                throw NSError(domain: "PowerMode", code: 2, userInfo: [NSLocalizedDescriptionKey: "LLM provider not configured"])
            }

            // Call LLM with system prompt and user message
            aiResponse = try await llmService.format(
                text: userMessage,
                mode: .raw,
                customPrompt: systemPrompt,
                context: nil  // Context is now embedded in userMessage
            )

            // Check if AI is asking a question
            if aiResponse.lowercased().contains("question:") || aiResponse.hasSuffix("?") {
                // Extract question
                aiQuestion = extractQuestion(from: aiResponse)
                state = .aiQuestion
            } else {
                state = .result
            }

        } catch {
            errorMessage = error.localizedDescription
            state = .contextPreview
        }
    }

    /// Build PowerModePromptInput from current view model state
    private func buildPromptInput() -> PowerModePromptInput {
        let inputConfig = currentPowerMode.inputConfig

        // Build Obsidian chunks from search results
        var obsidianChunks: [ObsidianChunkInfo] = []
        if inputConfig.includeObsidianVaults {
            for result in obsidianResults.prefix(currentPowerMode.maxObsidianChunks) {
                obsidianChunks.append(ObsidianChunkInfo(
                    noteTitle: result.noteTitle,
                    vaultName: result.vaultName,
                    content: result.content,
                    similarity: result.similarity
                ))
            }
        }

        // Get memory values based on inputConfig
        let globalMemory: String? = inputConfig.includeGlobalMemory ? settings.globalMemory : nil
        let contextMemory: String? = inputConfig.includeGlobalMemory ? settings.activeContext?.contextMemory : nil
        let powerModeMemory: String? = inputConfig.includePowerModeMemory ? currentPowerMode.memory : nil

        // Get window context if enabled
        let selectedText: String? = inputConfig.includeSelectedText ? windowContext?.selectedText : nil
        let selectedTextSource: String? = inputConfig.includeSelectedText ? windowContext?.appName : nil
        let clipboard: String? = inputConfig.includeClipboard ? clipboardContent : nil

        return PowerModePromptInput(
            powerMode: currentPowerMode,
            userInput: userInput,
            globalMemory: globalMemory,
            contextMemory: contextMemory,
            powerModeMemory: powerModeMemory,
            ragChunks: [],  // macOS doesn't have RAG documents yet
            obsidianChunks: obsidianChunks,
            selectedText: selectedText,
            selectedTextSource: selectedTextSource,
            clipboardText: clipboard,
            webhookContexts: []  // macOS doesn't have webhooks yet
        )
    }

    // MARK: - Power Mode Cycling

    /// Cycle to the previous Power Mode in the list
    func cycleToPreviousPowerMode() {
        guard !availablePowerModes.isEmpty else { return }

        if let currentIndex = availablePowerModes.firstIndex(where: { $0.id == currentPowerMode.id }) {
            let previousIndex = (currentIndex - 1 + availablePowerModes.count) % availablePowerModes.count
            currentPowerMode = availablePowerModes[previousIndex]
        } else if let first = availablePowerModes.first {
            currentPowerMode = first
        }

        // Reload context for new Power Mode
        Task {
            await loadContext()
        }
    }

    /// Cycle to the next Power Mode in the list
    func cycleToNextPowerMode() {
        guard !availablePowerModes.isEmpty else { return }

        if let currentIndex = availablePowerModes.firstIndex(where: { $0.id == currentPowerMode.id }) {
            let nextIndex = (currentIndex + 1) % availablePowerModes.count
            currentPowerMode = availablePowerModes[nextIndex]
        } else if let first = availablePowerModes.first {
            currentPowerMode = first
        }

        // Reload context for new Power Mode
        Task {
            await loadContext()
        }
    }

    // NOTE: Old buildSystemPrompt, buildUserMessage, buildPrompt methods removed
    // Now using shared PowerModePromptBuilder from SwiftSpeakCore

    /// Extract question from AI response
    private func extractQuestion(from response: String) -> String {
        // Simple extraction - look for "Question:" prefix or last sentence ending with "?"
        if let questionRange = response.range(of: "Question:", options: .caseInsensitive) {
            return String(response[questionRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Find last sentence ending with "?"
        let sentences = response.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
        if let lastQuestion = sentences.last(where: { $0.trimmingCharacters(in: .whitespaces).hasSuffix("?") }) {
            return lastQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return response
    }

    // MARK: - Question Handling

    func answerQuestion(_ answer: String) async {
        questionAnswer = answer
        aiQuestion = nil

        // Append answer to user input and re-send
        userInput += "\n\nAdditional info: \(answer)"
        await sendToAI()
    }

    // MARK: - Result Actions

    func refineResult(_ refinement: String) async {
        // Append refinement to input and re-send
        userInput += "\n\nRefinement: \(refinement)"
        await sendToAI()
    }

    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(aiResponse, forType: .string)

        // Show completion state briefly
        state = .actionComplete
    }

    func insertAtCursor() async {
        guard let textInsertion = textInsertion else { return }

        let result = await textInsertion.insertText(aiResponse, replaceSelection: false)

        switch result {
        case .accessibilitySuccess:
            state = .actionComplete
        case .clipboardFallback:
            // Text copied, user needs to paste
            state = .actionComplete
        case .failed(let error):
            errorMessage = error.localizedDescription
        }
    }

    func saveToObsidian() async {
        guard let actionConfig = currentPowerMode.obsidianAction,
              actionConfig.action != .none else {
            // No action configured, just mark as complete
            state = .actionComplete
            return
        }

        // Find the vault
        guard let vault = settings.obsidianVaults.first(where: { $0.id == actionConfig.targetVaultId }) else {
            errorMessage = "Obsidian vault not found"
            return
        }

        // Convert ObsidianAction to NoteAction
        let noteAction: NoteAction
        switch actionConfig.action {
        case .appendToDaily:
            noteAction = .appendToDaily
        case .appendToNote:
            noteAction = .append
        case .createNote:
            noteAction = .create
        case .none:
            state = .actionComplete
            return
        }

        // Write to Obsidian
        let noteWriter = MacObsidianNoteWriter()
        let result = await noteWriter.write(
            content: aiResponse,
            to: vault,
            action: noteAction,
            noteName: actionConfig.targetNoteName
        )

        switch result {
        case .writtenDirectly(let path):
            macLog("Saved to Obsidian: \(path)", category: "PowerMode")
            state = .actionComplete
        case .failed(let error):
            errorMessage = error.localizedDescription
        }
    }

    /// Save to Obsidian with a custom vault and action (for ad-hoc saves)
    func saveToObsidian(vault: ObsidianVault, action: NoteAction, noteName: String? = nil) async {
        let noteWriter = MacObsidianNoteWriter()
        let result = await noteWriter.write(
            content: aiResponse,
            to: vault,
            action: action,
            noteName: noteName
        )

        switch result {
        case .writtenDirectly(let path):
            macLog("Saved to Obsidian: \(path)", category: "PowerMode")
            state = .actionComplete
        case .failed(let error):
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Reset

    func reset() {
        state = .contextPreview
        userInput = ""
        aiResponse = ""
        aiQuestion = nil
        questionAnswer = ""
        errorMessage = nil
        windowContext = nil
        obsidianResults = []
        memoryContext = ""
        preCapturedWindowContext = nil
        preCapturedClipboard = nil
        // Reset Obsidian search state
        obsidianSearchQuery = ""
        isSearchingObsidian = false
        manualObsidianResults = []
        selectedObsidianResultIds = []
        isDictatingSearchQuery = false
    }

    // MARK: - Obsidian Search

    /// Whether the current Power Mode has Obsidian search enabled
    var hasObsidianEnabled: Bool {
        currentPowerMode.inputConfig.includeObsidianVaults &&
        !currentPowerMode.obsidianVaultIds.isEmpty
    }

    /// Transition to Obsidian search step (from contextPreview)
    func startObsidianSearch() {
        // Pre-fill search query: default query from PowerMode (or empty for "all notes")
        obsidianSearchQuery = currentPowerMode.defaultObsidianSearchQuery

        // Reuse results from contextPreview (already loaded via loadContext)
        // This avoids re-executing the same search
        if !obsidianResults.isEmpty {
            manualObsidianResults = obsidianResults
            selectedObsidianResultIds = Set(obsidianResults.map { $0.id })
        } else {
            manualObsidianResults = []
            selectedObsidianResultIds = []
        }

        state = .obsidianSearch
    }

    /// Perform Obsidian search with current query
    func searchObsidian() async {
        guard let service = obsidianQueryService else { return }

        // If empty query, load all notes instead
        if obsidianSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await loadAllObsidianNotes()
            return
        }

        isSearchingObsidian = true
        errorMessage = nil

        do {
            manualObsidianResults = try await service.search(
                query: obsidianSearchQuery,
                vaultIds: currentPowerMode.obsidianVaultIds,
                maxResults: currentPowerMode.maxObsidianChunks,
                minSimilarity: currentPowerMode.obsidianMinSimilarity
            )
            // Auto-select only results above the autoSelectThreshold
            let autoSelectThreshold = currentPowerMode.obsidianAutoSelectThreshold
            selectedObsidianResultIds = Set(
                manualObsidianResults
                    .filter { $0.similarity >= autoSelectThreshold }
                    .map { $0.id }
            )
        } catch {
            errorMessage = error.localizedDescription
            macLog("Obsidian search failed: \(error)", category: "PowerMode")
        }

        isSearchingObsidian = false
    }

    /// Load all Obsidian notes from configured vaults (no filtering)
    func loadAllObsidianNotes() async {
        guard let service = obsidianQueryService else { return }

        isSearchingObsidian = true
        errorMessage = nil

        do {
            manualObsidianResults = try await service.getAllNotes(
                vaultIds: currentPowerMode.obsidianVaultIds,
                maxResults: 50
            )
            // For "all notes" mode, select all by default (no similarity filtering)
            selectedObsidianResultIds = Set(manualObsidianResults.map { $0.id })
        } catch {
            macLog("Failed to load all Obsidian notes: \(error)", category: "PowerMode")
        }

        isSearchingObsidian = false
    }

    /// Toggle selection of a specific result
    func toggleResultSelection(_ resultId: UUID) {
        if selectedObsidianResultIds.contains(resultId) {
            selectedObsidianResultIds.remove(resultId)
        } else {
            selectedObsidianResultIds.insert(resultId)
        }
    }

    /// Toggle result selection by 1-based index (for keyboard shortcuts 1-9)
    func toggleResultByIndex(_ index: Int) {
        guard index > 0, index <= manualObsidianResults.count else { return }
        let result = manualObsidianResults[index - 1]
        toggleResultSelection(result.id)
    }

    /// Select all search results
    func selectAllResults() {
        selectedObsidianResultIds = Set(manualObsidianResults.map { $0.id })
    }

    /// Deselect all search results
    func deselectAllResults() {
        selectedObsidianResultIds.removeAll()
    }

    /// Proceed from Obsidian search to recording
    func proceedFromObsidianSearch() async {
        // Filter to only selected results for the LLM prompt
        obsidianResults = selectedObsidianResults

        // Start recording
        state = .recording
        errorMessage = nil

        do {
            try await audioRecorder.startRecording()
        } catch {
            errorMessage = error.localizedDescription
            state = .obsidianSearch
        }
    }

    /// Start voice dictation for the search query field
    func startSearchDictation() async {
        guard !isDictatingSearchQuery else { return }

        isDictatingSearchQuery = true
        errorMessage = nil

        do {
            try await audioRecorder.startRecording()
        } catch {
            errorMessage = error.localizedDescription
            isDictatingSearchQuery = false
        }
    }

    /// Stop voice dictation and transcribe to search query
    func stopSearchDictation() async {
        guard isDictatingSearchQuery else { return }

        do {
            let audioURL = try audioRecorder.stopRecording()

            // Transcribe audio
            guard let provider = providerFactory,
                  let transcriptionService = provider.createTranscriptionProvider(for: settings.selectedTranscriptionProvider) else {
                throw NSError(domain: "PowerMode", code: 1, userInfo: [NSLocalizedDescriptionKey: "Transcription provider not configured"])
            }

            let transcribedText = try await transcriptionService.transcribe(
                audioURL: audioURL,
                language: settings.selectedDictationLanguage,
                promptHint: buildVocabularyPrompt()
            )

            // Append to search query (or replace if empty)
            if obsidianSearchQuery.isEmpty {
                obsidianSearchQuery = transcribedText
            } else {
                obsidianSearchQuery += " " + transcribedText
            }

            isDictatingSearchQuery = false

            // Auto-search after dictation
            await searchObsidian()

        } catch {
            errorMessage = error.localizedDescription
            isDictatingSearchQuery = false
        }
    }

    // MARK: - Vocabulary Support

    /// Build vocabulary prompt for transcription from vocabulary entries and active context
    /// This helps the transcription provider recognize domain-specific terms
    private func buildVocabularyPrompt() -> String? {
        var vocabWords: [String] = []

        // Add vocabulary replacement words (target words that should be recognized)
        vocabWords.append(contentsOf: settings.vocabulary
            .filter { $0.isEnabled }
            .map { $0.replacementWord }
        )

        // Add domain jargon from active context
        if let context = settings.activeContext {
            vocabWords.append(contentsOf: context.transcriptionVocabulary)
        }

        // Add Power Mode specific vocabulary if available
        if !currentPowerMode.name.isEmpty {
            vocabWords.append(currentPowerMode.name)
        }

        // Return nil if no vocabulary, otherwise comma-separated list
        guard !vocabWords.isEmpty else { return nil }

        // Remove duplicates and join
        let uniqueWords = Array(Set(vocabWords))
        return uniqueWords.joined(separator: ", ")
    }
}
