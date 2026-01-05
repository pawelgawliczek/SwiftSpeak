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

/// Power Mode overlay execution states
enum OverlayState: String, Sendable {
    case contextPreview     // Show context sources with toggles
    case recording          // Recording voice input
    case processing         // AI thinking
    case aiQuestion         // AI asking clarification
    case result             // Show result, allow iteration
    case actionComplete     // Saved to Obsidian, auto-close
}

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

    // MARK: - Debug Info (temporary)

    @Published var debugInfo: String = ""

    // MARK: - Configuration

    @Published var currentPowerMode: PowerMode
    var availablePowerModes: [PowerMode]
    let settings: MacSettings  // Exposed for view access to obsidianVaults
    private let windowContextService: MacWindowContextService
    private let audioRecorder: MacAudioRecorder
    private var cancellables = Set<AnyCancellable>()

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

        // DEBUG: Set debug info for display
        var info = "DEBUG:\n"
        if let ctx = windowContext {
            info += "App: \(ctx.appName) (\(ctx.appBundleId))\n"
            info += "Window: \(ctx.windowTitle)\n"
            info += "Selected: \(ctx.selectedText?.prefix(50) ?? "nil")\n"
            info += "Visible: \(ctx.visibleText?.prefix(50) ?? "nil")"
        } else {
            info += "WindowContext: nil"
        }
        self.debugInfo = info
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

        // Query Obsidian if enabled and vaults are selected
        if inputConfig.includeObsidianVaults,
           !currentPowerMode.obsidianVaultIds.isEmpty,
           let obsidianService = obsidianQueryService {
            // Use window context text or power mode name as query
            let queryText = windowContext?.displayText ?? currentPowerMode.name
            do {
                let results = try await obsidianService.search(
                    query: queryText,
                    vaultIds: currentPowerMode.obsidianVaultIds,
                    maxResults: currentPowerMode.maxObsidianChunks
                )
                obsidianResults = results
            } catch {
                macLog("Failed to query Obsidian: \(error)", category: "PowerMode")
                obsidianResults = []
            }
        } else {
            obsidianResults = []
        }

        // Load memory context based on config
        memoryContext = buildMemoryContext()
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
                language: settings.selectedDictationLanguage
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
            // Build prompt with context
            let prompt = buildPrompt()

            // Get LLM provider
            guard let provider = providerFactory,
                  let llmService = provider.createFormattingProvider(for: settings.selectedPowerModeProvider) else {
                throw NSError(domain: "PowerMode", code: 2, userInfo: [NSLocalizedDescriptionKey: "LLM provider not configured"])
            }

            // Call LLM (using format method as proxy for general LLM call)
            aiResponse = try await llmService.format(text: prompt, mode: .raw, customPrompt: nil)

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

    /// Build prompt with all context sources based on inputConfig
    private func buildPrompt() -> String {
        let inputConfig = currentPowerMode.inputConfig
        var parts: [String] = []

        // Power mode instructions
        parts.append("You are a \(currentPowerMode.name) assistant.")
        parts.append("Instructions: \(currentPowerMode.instruction)")

        // Output format (if specified)
        if !currentPowerMode.outputFormat.isEmpty {
            parts.append("Output Format: \(currentPowerMode.outputFormat)")
        }

        // Window context (selected text / active app text)
        if let window = windowContext, !window.displayText.isEmpty {
            if inputConfig.includeSelectedText && inputConfig.includeActiveAppText {
                parts.append("\nWindow Context from \(window.appName):")
            } else if inputConfig.includeSelectedText {
                parts.append("\nSelected Text from \(window.appName):")
            } else if inputConfig.includeActiveAppText {
                parts.append("\nActive Window Content from \(window.appName):")
            }
            parts.append(window.displayText)
        }

        // Clipboard content
        if inputConfig.includeClipboard, !clipboardContent.isEmpty {
            parts.append("\nClipboard Content:")
            parts.append(clipboardContent)
        }

        // Obsidian context
        if inputConfig.includeObsidianVaults, !obsidianResults.isEmpty {
            parts.append("\nRelevant Notes from Obsidian:")
            for result in obsidianResults.prefix(currentPowerMode.maxObsidianChunks) {
                parts.append("[\(result.noteTitle)] \(result.content)")
            }
        }

        // Memory context
        if !memoryContext.isEmpty {
            parts.append("\nMemory Context:")
            parts.append(memoryContext)
        }

        // User input
        parts.append("\nUser Request:")
        parts.append(userInput)

        return parts.joined(separator: "\n")
    }

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
    }
}
