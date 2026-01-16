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

// MARK: - Quick Suggestion

/// A quick reply suggestion generated from screen context
struct QuickSuggestion: Identifiable, Equatable {
    let id = UUID()
    let type: SuggestionType
    let text: String
    let shortLabel: String

    enum SuggestionType: String, CaseIterable {
        case positive = "positive"
        case neutral = "neutral"
        case negative = "negative"

        var icon: String {
            switch self {
            case .positive: return "hand.thumbsup.fill"
            case .neutral: return "hand.raised.fill"
            case .negative: return "hand.thumbsdown.fill"
            }
        }

        var color: Color {
            switch self {
            case .positive: return .green
            case .neutral: return .orange
            case .negative: return .red
            }
        }

        var label: String {
            switch self {
            case .positive: return "Positive"
            case .neutral: return "Neutral"
            case .negative: return "Decline"
            }
        }
    }
}

// MARK: - Power Mode Overlay View Model

@MainActor
final class MacPowerModeOverlayViewModel: ObservableObject {

    // MARK: - Published State

    @Published var state: OverlayState = .contextPreview

    /// Window context captured from active app
    @Published var windowContext: WindowContext?

    // MARK: - Quick Suggestions State

    /// Whether quick suggestions are enabled (global setting)
    var quickSuggestionsEnabled: Bool {
        settings.quickSuggestionsEnabled && !settings.quickActions.filter { $0.isEnabled }.isEmpty
    }

    /// The configured quick actions (global setting)
    var configuredQuickActions: [QuickAction] {
        settings.quickActions.filter { $0.isEnabled }.sorted { $0.order < $1.order }
    }

    /// Navigation mode for keyboard controls
    enum NavigationMode {
        case powerMode      // Left/Right cycles power modes, Down enters input field
        case inputField     // Typing in prediction input, Down enters predictions, Up goes to power mode
        case prediction     // Up/Down cycles predictions, Left=shorter, Right=longer
    }

    /// Current navigation mode
    @Published var navigationMode: NavigationMode = .powerMode

    /// Whether the prediction input field should be focused
    @Published var isInputFieldFocused: Bool = false

    /// Active SwiftSpeak Context (for style/formatting) - press C to cycle
    @Published var activeContext: ConversationContext?

    /// Generated quick suggestions based on screen context
    @Published var quickSuggestions: [QuickSuggestion] = []

    /// Currently selected suggestion index (nil = none selected, 0+ = selected)
    @Published var selectedSuggestionIndex: Int? = nil

    /// Input text for prediction steering
    /// - If empty: generate predictions normally
    /// - If starts with "CMD ": use rest as instruction to modify predictions
    /// - Otherwise: use as prefix/start of the response
    @Published var predictionInputText: String = ""

    /// Whether the prediction input is in command mode (starts with "CMD ")
    var isCommandMode: Bool {
        predictionInputText.uppercased().hasPrefix("CMD ")
    }

    /// The command/instruction text (without "CMD " prefix)
    var commandText: String {
        guard isCommandMode else { return "" }
        return String(predictionInputText.dropFirst(4)).trimmingCharacters(in: .whitespaces)
    }

    /// Whether suggestions are being generated
    @Published var isGeneratingSuggestions: Bool = false

    /// Error message for suggestions (e.g., model refused)
    @Published var suggestionsError: String?

    /// Whether a specific suggestion is being regenerated (shorter/longer)
    @Published var isRegeneratingSuggestion: Bool = false

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

    // Phase 17: Action executors
    private var inputActionExecutor: MacInputActionExecutor?
    private var outputActionExecutor: MacOutputActionExecutor?

    // Phase 17: Action results storage
    private var inputActionResults: [InputActionResult] = []
    private var outputActionResults: [OutputActionResult] = []

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

        // Initialize active context from settings
        self.activeContext = settings.activeContext

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

        // Phase 17: Initialize action executors
        self.inputActionExecutor = MacInputActionExecutor(
            settings: settings,
            windowContextService: windowContextService
        )
        self.outputActionExecutor = MacOutputActionExecutor(
            settings: settings,
            textInsertionService: textInsertion
        )
    }

    // MARK: - Pre-captured Context

    /// Pre-captured window context (captured before overlay shows)
    private var preCapturedWindowContext: WindowContext?
    private var preCapturedClipboard: String?
    /// Source app PID for async text capture
    private var sourcePid: pid_t = 0

    /// Set pre-captured context (call BEFORE showing overlay)
    func setPreCapturedContext(windowContext: WindowContext?, clipboard: String?, sourcePid: pid_t = 0) {
        self.preCapturedWindowContext = windowContext
        self.preCapturedClipboard = clipboard
        self.sourcePid = sourcePid
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
    /// - Parameter regenerateSuggestions: If false, skip suggestion generation (useful when cycling power modes)
    func loadContext(regenerateSuggestions: Bool = true) async {
        let inputConfig = currentPowerMode.inputConfig

        // Use pre-captured window context (captured before overlay opened)
        if inputConfig.includeSelectedText || inputConfig.includeActiveAppText {
            if let preCaptured = preCapturedWindowContext {
                windowContext = preCaptured
                print("[CONTEXT] Pre-captured from \(preCaptured.appName), contextText empty: \(preCaptured.contextText.isEmpty), sourcePid: \(sourcePid)")
                macLog("Using pre-captured window context from \(preCaptured.appName)", category: "PowerMode")

                // If we have no text content and have source PID, try to capture visibleText async (with OCR fallback)
                if preCaptured.contextText.isEmpty && sourcePid > 0 {
                    print("[CONTEXT] Trying async capture from PID \(sourcePid)...")
                    macLog("No context text, trying async capture from PID \(sourcePid) (with OCR fallback)", category: "PowerMode")
                    if let capturedText = await windowContextService.captureAllVisibleTextWithOCRFallback(from: sourcePid, bundleId: preCaptured.appBundleId) {
                        windowContext = WindowContext(
                            appName: preCaptured.appName,
                            appBundleId: preCaptured.appBundleId,
                            windowTitle: preCaptured.windowTitle,
                            selectedText: preCaptured.selectedText,
                            visibleText: capturedText,
                            capturedAt: Date()
                        )
                        print("[CONTEXT] Async captured: \(capturedText.prefix(100))...")
                        macLog("Async captured visible text: \(capturedText.prefix(100))...", category: "PowerMode")
                    } else {
                        print("[CONTEXT] Async capture returned nil")
                    }
                }
            } else {
                print("[CONTEXT] No pre-captured context!")
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

        // Generate quick suggestions in background if screen context available
        // Use contextText (visibleText OR selectedText) as fallback
        // Only regenerate if explicitly requested (not when cycling power modes)
        if regenerateSuggestions && quickSuggestionsEnabled && !(windowContext?.contextText.isEmpty ?? true) {
            Task {
                await generateQuickSuggestions()
            }
        }
    }

    /// Manually regenerate quick suggestions (called via "R" shortcut)
    func regenerateQuickSuggestions() async {
        guard quickSuggestionsEnabled && !(windowContext?.contextText.isEmpty ?? true) else { return }
        await generateQuickSuggestions()
    }

    /// Handle space press in prediction input field - triggers regeneration
    func handlePredictionInputSpace() {
        // Only regenerate if there's actual content (not just spaces)
        let trimmed = predictionInputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        macLog("Prediction input space pressed: '\(trimmed.prefix(50))...' (CMD mode: \(isCommandMode))", category: "PowerMode")

        Task {
            await generateQuickSuggestions()
        }
    }

    /// Clear prediction input and regenerate fresh suggestions
    func clearPredictionInput() {
        predictionInputText = ""
        Task {
            await generateQuickSuggestions()
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

    // MARK: - Navigation (Two-Mode System)
    // Power mode row: Left/Right cycle modes, Up/Down enter quick replies
    // Quick reply row: Up/Down cycle replies, Left=shorter, Right=longer

    /// Handle arrow down: From powerMode enters predictions, in prediction mode goes to next or wraps to powerMode
    func handleArrowDown() {
        switch navigationMode {
        case .powerMode:
            // Go to input field if quick suggestions enabled
            if quickSuggestionsEnabled {
                navigationMode = .inputField
                isInputFieldFocused = true
            }
        case .inputField:
            // Go to predictions if we have suggestions
            isInputFieldFocused = false
            if !quickSuggestions.isEmpty {
                navigationMode = .prediction
                selectedSuggestionIndex = 0
            } else {
                // No suggestions - wrap back to power mode
                navigationMode = .powerMode
            }
        case .prediction:
            // Go to next suggestion or wrap to power mode
            if let current = selectedSuggestionIndex {
                if current < quickSuggestions.count - 1 {
                    selectedSuggestionIndex = current + 1
                } else {
                    // At last suggestion - wrap back to power mode
                    navigationMode = .powerMode
                    selectedSuggestionIndex = nil
                }
            }
        }
    }

    /// Handle arrow up: powerMode → predictions (last), prediction → input field → powerMode
    func handleArrowUp() {
        switch navigationMode {
        case .powerMode:
            // Go to last prediction (skip input field going up)
            if quickSuggestionsEnabled && !quickSuggestions.isEmpty {
                navigationMode = .prediction
                selectedSuggestionIndex = quickSuggestions.count - 1
            } else if quickSuggestionsEnabled {
                // No suggestions but quick suggestions enabled - go to input field
                navigationMode = .inputField
                isInputFieldFocused = true
            }
        case .inputField:
            // Go back to power mode
            isInputFieldFocused = false
            navigationMode = .powerMode
        case .prediction:
            // Go to previous suggestion or to input field
            if let current = selectedSuggestionIndex {
                if current > 0 {
                    selectedSuggestionIndex = current - 1
                } else {
                    // At first suggestion - go to input field
                    navigationMode = .inputField
                    isInputFieldFocused = true
                    selectedSuggestionIndex = nil
                }
            }
        }
    }

    /// Handle arrow left: In powerMode cycles power modes, in prediction regenerates shorter
    func handleArrowLeft() {
        if navigationMode == .powerMode {
            cycleToPreviousPowerMode()
        } else {
            // Regenerate selected suggestion shorter
            Task {
                await regenerateSelectedSuggestion(shorter: true)
            }
        }
    }

    /// Handle arrow right: In powerMode cycles power modes, in prediction regenerates longer
    func handleArrowRight() {
        if navigationMode == .powerMode {
            cycleToNextPowerMode()
        } else {
            // Regenerate selected suggestion longer
            Task {
                await regenerateSelectedSuggestion(shorter: false)
            }
        }
    }

    /// Cycle to next SwiftSpeak Context (C key when in power mode row)
    func cycleToNextContext() {
        let contexts = settings.contexts
        guard !contexts.isEmpty else { return }

        if let current = activeContext,
           let index = contexts.firstIndex(where: { $0.id == current.id }) {
            // If at last context, cycle back to nil
            if index == contexts.count - 1 {
                activeContext = nil
            } else {
                activeContext = contexts[index + 1]
            }
        } else {
            // No context selected, start with first context
            activeContext = contexts.first
        }

        macLog("Context changed to: \(activeContext?.name ?? "None")", category: "PowerMode")

        // Regenerate suggestions with new context style
        Task {
            await regenerateQuickSuggestions()
        }
    }

    /// Cycle to previous SwiftSpeak Context
    func cycleToPreviousContext() {
        let contexts = settings.contexts
        guard !contexts.isEmpty else { return }

        if let current = activeContext,
           let index = contexts.firstIndex(where: { $0.id == current.id }) {
            // If at first context, cycle back to nil
            if index == 0 {
                activeContext = nil
            } else {
                activeContext = contexts[index - 1]
            }
        } else {
            // No context selected, start with last context
            activeContext = contexts.last
        }

        macLog("Context changed to: \(activeContext?.name ?? "None")", category: "PowerMode")

        // Regenerate suggestions with new context style
        Task {
            await regenerateQuickSuggestions()
        }
    }

    /// Regenerate the selected suggestion (shorter or longer)
    func regenerateSelectedSuggestion(shorter: Bool) async {
        macLog("Regenerate suggestion called: shorter=\(shorter), selectedIndex=\(selectedSuggestionIndex ?? -1)", category: "PowerMode")

        guard let index = selectedSuggestionIndex,
              quickSuggestions.indices.contains(index) else {
            macLog("No suggestion selected for regeneration", category: "PowerMode")
            return
        }

        guard let factory = providerFactory else {
            macLog("No provider factory for regeneration", category: "PowerMode")
            return
        }

        let currentSuggestion = quickSuggestions[index]
        let screenText = windowContext?.contextText ?? ""
        guard !screenText.isEmpty else {
            macLog("Context text empty for regeneration", category: "PowerMode")
            return
        }

        isRegeneratingSuggestion = true
        defer { isRegeneratingSuggestion = false }

        do {
            // Use context-specific formatting provider if set, otherwise fall back to global
            let provider: FormattingProvider?
            if let contextOverride = activeContext?.formattingProviderOverride {
                provider = factory.createFormattingProvider(from: contextOverride)
            } else {
                provider = factory.createSelectedFormattingProvider()
            }

            guard let provider = provider else {
                macLog("Could not create formatting provider for regeneration", category: "PowerMode")
                return
            }

            let currentLength = currentSuggestion.text.count
            let targetLength = shorter
                ? max(10, Int(Double(currentLength) * 0.8))  // 20% shorter, min 10 chars
                : Int(Double(currentLength) * 1.2)  // 20% longer

            let prompt: String
            if shorter {
                prompt = """
                Shorten this text to EXACTLY \(targetLength) characters or less (currently \(currentLength) chars):
                "\(currentSuggestion.text)"

                CRITICAL: Your response MUST be shorter than the original. Remove words, simplify phrases.
                Return ONLY the shortened text.
                """
            } else {
                prompt = """
                Expand this text to approximately \(targetLength) characters (currently \(currentLength) chars):
                "\(currentSuggestion.text)"

                Add more detail or context while keeping the same meaning and tone.
                Return ONLY the expanded text.
                """
            }

            macLog("Regenerating suggestion (\(shorter ? "shorter" : "longer")): \(currentLength) chars → target \(targetLength) chars", category: "PowerMode")

            let revisedText = try await provider.format(
                text: prompt,
                mode: .raw,
                customPrompt: "You are revising a quick reply. Return only the revised text."
            )

            // Update the suggestion in place
            let trimmed = revisedText.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))  // Remove quotes if LLM added them
            if !trimmed.isEmpty {
                let newLength = trimmed.count
                let changePercent = currentLength > 0 ? Int((Double(newLength - currentLength) / Double(currentLength)) * 100) : 0
                macLog("Regenerated: \(currentLength) → \(newLength) chars (\(changePercent > 0 ? "+" : "")\(changePercent)%)", category: "PowerMode")
                quickSuggestions[index] = QuickSuggestion(
                    type: currentSuggestion.type,
                    text: trimmed,
                    shortLabel: currentSuggestion.shortLabel
                )
            } else {
                macLog("Regeneration returned empty text", category: "PowerMode")
            }
        } catch {
            macLog("Failed to regenerate suggestion: \(error)", category: "PowerMode")
        }
    }

    /// Select suggestion at specific index (for click)
    func selectSuggestion(at index: Int) {
        guard quickSuggestions.indices.contains(index) else { return }
        navigationMode = .prediction
        selectedSuggestionIndex = index
    }

    /// Clear suggestion selection and return to power mode navigation
    func clearSuggestionSelection() {
        navigationMode = .powerMode
        selectedSuggestionIndex = nil
    }

    /// Insert the selected suggestion text
    func insertSelectedSuggestion() async -> Bool {
        guard let index = selectedSuggestionIndex,
              quickSuggestions.indices.contains(index),
              let textInsertion = textInsertion else {
            return false
        }

        let suggestion = quickSuggestions[index]
        macLog("Inserting quick suggestion: \(suggestion.type.rawValue)", category: "PowerMode")

        do {
            _ = try await textInsertion.insertText(suggestion.text, replaceSelection: true)
            return true
        } catch {
            macLog("Failed to insert suggestion: \(error)", category: "PowerMode")
            errorMessage = "Failed to insert: \(error.localizedDescription)"
            return false
        }
    }

    /// Generate quick suggestions based on screen context and configured quick actions
    func generateQuickSuggestions() async {
        let actions = configuredQuickActions
        guard !actions.isEmpty,
              windowContext != nil,
              let factory = providerFactory else {
            quickSuggestions = []
            return
        }

        // Use window context text (visibleText OR selectedText)
        let screenText = windowContext?.contextText ?? ""
        guard !screenText.isEmpty else {
            macLog("No context text for predictions", category: "PowerMode")
            quickSuggestions = []
            return
        }

        macLog("Generating suggestions: \(screenText.count) chars, context: \(activeContext?.name ?? "None")", category: "PowerMode")

        isGeneratingSuggestions = true
        suggestionsError = nil  // Clear any previous error
        defer { isGeneratingSuggestions = false }

        // Build comprehensive context prompt (examples, formatting rules, memory, etc.)
        let contextPrompt = buildContextPrompt(from: activeContext)

        // Generate suggestions for each configured quick action
        var suggestions: [QuickSuggestion] = []

        do {
            // Use context-specific formatting provider if set, otherwise fall back to global
            let provider: FormattingProvider?
            let providerName: String

            if let contextOverride = activeContext?.formattingProviderOverride {
                macLog("Using context-specific formatting provider: \(contextOverride.displayName)", category: "PowerMode")
                provider = factory.createFormattingProvider(from: contextOverride)
                providerName = contextOverride.displayName
            } else {
                macLog("Using global formatting provider: \(settings.selectedFormattingProvider.displayName)", category: "PowerMode")
                provider = factory.createSelectedFormattingProvider()
                providerName = settings.selectedFormattingProvider.displayName
            }

            guard let provider = provider else {
                macLog("No formatting provider configured for \(providerName)", category: "PowerMode", level: .warning)
                quickSuggestions = []
                return
            }

            // Build combined prompt for all actions with full context
            let systemPrompt = buildQuickActionsSystemPrompt(actions: actions, contextPrompt: contextPrompt)
            let userPrompt = buildQuickActionsUserPrompt(
                screenText: screenText,
                appName: windowContext?.appName ?? "Unknown",
                actions: actions
            )

            let response = try await provider.format(
                text: userPrompt,
                mode: .raw,
                customPrompt: systemPrompt
            )

            // Log raw response for debugging
            macLog("Raw LLM response (\(response.count) chars): \(response.prefix(500))...", category: "PowerMode")

            // Check for model refusal responses
            // Only consider it a refusal if: (1) response is short AND (2) doesn't contain ACTION_ markers
            // This avoids false positives when one of the generated suggestions is a "polite decline" type
            let hasActionMarkers = response.contains("ACTION_")
            let isShortResponse = response.count < 150

            if !hasActionMarkers || isShortResponse {
                let refusalPatterns = [
                    "Sorry, I can't assist",
                    "I cannot assist",
                    "I'm not able to",
                    "I can't help with",
                    "I cannot help with",
                    "I apologize, but I cannot",
                    "I'm unable to"
                ]
                let containsRefusal = refusalPatterns.contains { response.lowercased().contains($0.lowercased()) }
                if containsRefusal && !hasActionMarkers {
                    macLog("LLM refused to generate suggestions - may be due to content type", category: "PowerMode", level: .warning)
                    suggestionsError = "Quick replies not available for this content"
                    quickSuggestions = []
                    return
                }
            }

            // Parse the response into suggestions
            suggestions = parseQuickActionsResponse(response, actions: actions)
            macLog("Generated \(suggestions.count) quick suggestions from \(actions.count) actions", category: "PowerMode")
        } catch {
            macLog("Failed to generate suggestions: \(error)", category: "PowerMode")
        }

        quickSuggestions = suggestions
    }

    /// Build system prompt for quick actions generation
    private func buildQuickActionsSystemPrompt(actions: [QuickAction], contextPrompt: String) -> String {
        let actionDescriptions = actions.enumerated().map { idx, action in
            "ACTION_\(idx + 1) (\(action.label)): \(action.effectivePrompt)"
        }.joined(separator: "\n")

        // Build user input instruction based on mode
        let userInputInstruction: String
        if isCommandMode && !commandText.isEmpty {
            userInputInstruction = """

            # USER INSTRUCTION (CRITICAL - OVERRIDE)
            The user has provided a specific instruction: "\(commandText)"
            You MUST follow this instruction when generating ALL responses.
            Apply this instruction to each action while still maintaining distinct tones.
            """
        } else if !predictionInputText.trimmingCharacters(in: .whitespaces).isEmpty {
            let prefix = predictionInputText.trimmingCharacters(in: .whitespaces)
            userInputInstruction = """

            # USER PREFIX (CRITICAL - MUST START WITH THIS)
            The user has started typing: "\(prefix)"
            ALL responses MUST start with EXACTLY this text, then continue naturally.
            Do NOT modify the prefix - use it verbatim as the beginning of each response.
            Complete the response in a way that flows naturally from this prefix.
            """
        } else {
            userInputInstruction = ""
        }

        return """
        You are generating NEW, ORIGINAL quick replies for the user to send.

        # CRITICAL: GENERATE NEW TEXT, DO NOT COPY
        - You must CREATE original responses - do NOT copy/extract text from the screen
        - The screen content is for CONTEXT only - to understand what to reply to
        - Your output must be NEW messages the user would send
        - NEVER include timestamps, dates, "Sent to", "Received from", "Delivered" - those are UI artifacts

        # CONVERSATION ANALYSIS
        The screen shows a messaging app. Find the CURRENT conversation:
        1. Look for the contact name in the HEADER (e.g., "Fatma Kamal")
        2. Find THEIR last message to you (what you should reply to)
        3. IGNORE the sidebar - it shows OTHER chats, not the current one
           - Sidebar items have format: "Name, preview text, time"
           - These are NOT part of the current conversation
        4. The MAIN conversation area shows the actual chat with timestamps
        5. Their messages are on the LEFT, your messages on the RIGHT (with ✓✓)

        # YOUR TASK
        Generate NEW replies to the OTHER person's LAST message.
        If their last message is "Have a beautiful day baby!" - reply to THAT.
        \(userInputInstruction)

        # USER'S WRITING STYLE
        \(contextPrompt)

        # ACTIONS TO GENERATE
        \(actionDescriptions)

        # OUTPUT FORMAT
        Respond with EXACTLY \(actions.count) lines, one per action:
        \(actions.enumerated().map { "ACTION_\($0.offset + 1): <write your actual reply here>" }.joined(separator: "\n"))

        EXAMPLE (for a message "Hey, how are you?"):
        ACTION_1: Hey! I'm doing great, thanks for asking! How about you?
        ACTION_2: I'm good! What's up?
        ACTION_3: Sorry, can't chat right now - catch up later?

        # CRITICAL RULES
        - MATCH the user's writing style from examples above
        - Use the same greeting/closing patterns they use
        - Match their emoji usage level exactly
        - Keep their typical message length
        - Sound natural, like the user actually wrote it
        - Each action should produce a distinct response
        - NEVER describe the app or its features - generate ACTUAL replies to the conversation
        - If you see a name at the top (e.g., "Fatma Kamal"), address your reply to them
        """
    }

    /// Build user prompt with screen context
    private func buildQuickActionsUserPrompt(screenText: String, appName: String, actions: [QuickAction]) -> String {
        let maxChars = 2000
        let truncated = screenText.count > maxChars ? String(screenText.prefix(maxChars)) + "..." : screenText

        // Add app-specific hints for better conversation parsing
        let appHint = getAppSpecificHint(for: appName)

        return """
        App: \(appName)
        \(appHint)

        Screen content (may include UI elements - focus on the CONVERSATION only):
        ---
        \(truncated)
        ---

        TASK: Generate \(actions.count) replies to the OTHER person's last message in the conversation.
        IMPORTANT: These should be YOUR responses to THEM, not descriptions of the app or UI.
        """
    }

    /// Get app-specific parsing hints for better conversation detection
    private func getAppSpecificHint(for appName: String) -> String {
        let lowered = appName.lowercased()

        if lowered.contains("whatsapp") {
            return """
            App Type: Messaging (WhatsApp)
            - Left sidebar shows chat list (IGNORE this - it's navigation)
            - Main area shows conversation with the contact named in the header
            - Messages from contact: LEFT side (gray bubbles)
            - User's messages: RIGHT side (green bubbles, with checkmarks ✓✓)
            - Look for the LAST message from the contact to reply to
            """
        } else if lowered.contains("message") || lowered.contains("imessage") {
            return """
            App Type: Messaging (iMessage/Messages)
            - Left sidebar shows conversations list (IGNORE this)
            - Main area shows conversation thread
            - Contact messages: GRAY bubbles (left side)
            - User messages: BLUE bubbles (right side)
            - Reply to the last gray/contact message
            """
        } else if lowered.contains("telegram") {
            return """
            App Type: Messaging (Telegram)
            - Left panel shows chat list (IGNORE this)
            - Main panel shows conversation
            - Contact messages: LEFT side
            - User messages: RIGHT side (with delivery indicators)
            - Reply to the last message from the contact
            """
        } else if lowered.contains("slack") {
            return """
            App Type: Team Chat (Slack)
            - Left sidebar shows channels/DMs (IGNORE this)
            - Main area shows conversation thread
            - Messages show username before content
            - Find the last message NOT from you and reply to it
            """
        } else if lowered.contains("discord") {
            return """
            App Type: Chat (Discord)
            - Left shows servers/channels (IGNORE this)
            - Main shows message thread with usernames
            - Reply to the conversation context
            """
        } else if lowered.contains("mail") || lowered.contains("outlook") || lowered.contains("gmail") {
            return """
            App Type: Email
            - Look for the email body content, sender name, subject
            - Generate appropriate email reply content
            """
        } else {
            return "App Type: General - Look for message/conversation content and generate appropriate response"
        }
    }

    /// Parse response into QuickSuggestions based on configured actions
    private func parseQuickActionsResponse(_ response: String, actions: [QuickAction]) -> [QuickSuggestion] {
        var suggestions: [QuickSuggestion] = []

        // Placeholder patterns to filter out (model echoed the format instead of generating)
        let placeholderPatterns = [
            "[response text]",
            "[response]",
            "<write your actual reply here>",
            "<your reply here>",
            "<reply>",
            "[your response]"
        ]

        // Patterns that indicate the model copied from screen instead of generating
        let copiedFromScreenPatterns = [
            "Sent to",
            "Received from",
            "Received in",
            "Delivered",
            "at\\d{1,2}:\\d{2}",  // timestamps like "at17:40"
            "\\d{1,2}January",    // dates like "11January"
            "\\d{1,2}February",
            "\\d{1,2}March",
            "\\d{1,2}April",
            "\\d{1,2}May",
            "\\d{1,2}June",
            "\\d{1,2}July",
            "\\d{1,2}August",
            "\\d{1,2}September",
            "\\d{1,2}October",
            "\\d{1,2}November",
            "\\d{1,2}December"
        ]

        for (index, action) in actions.enumerated() {
            let prefix = "ACTION_\(index + 1):"
            if let range = response.range(of: prefix, options: .caseInsensitive) {
                var text = String(response[range.upperBound...])
                // Take until next ACTION_ or end of string
                if let nextAction = text.range(of: "ACTION_", options: .caseInsensitive) {
                    text = String(text[..<nextAction.lowerBound])
                }
                text = text.trimmingCharacters(in: .whitespacesAndNewlines)

                // Filter out placeholder responses
                let isPlaceholder = placeholderPatterns.contains { text.lowercased().contains($0.lowercased()) }
                if isPlaceholder {
                    macLog("Filtered placeholder response for ACTION_\(index + 1): '\(text)'", category: "PowerMode", level: .warning)
                    continue
                }

                // Filter out responses copied from screen (contain UI artifacts)
                let isCopiedFromScreen = copiedFromScreenPatterns.contains { pattern in
                    if pattern.contains("\\") {
                        // Regex pattern
                        return text.range(of: pattern, options: .regularExpression) != nil
                    } else {
                        // Simple string match
                        return text.contains(pattern)
                    }
                }
                if isCopiedFromScreen {
                    macLog("Filtered copied-from-screen response for ACTION_\(index + 1): '\(text.prefix(50))...'", category: "PowerMode", level: .warning)
                    continue
                }

                if !text.isEmpty {
                    suggestions.append(QuickSuggestion(
                        type: mapQuickActionTypeToSuggestionType(action.type),
                        text: text,
                        shortLabel: action.label
                    ))
                }
            }
        }

        // If all were filtered out, log warning
        if suggestions.isEmpty && !actions.isEmpty {
            macLog("All suggestions filtered as placeholders - LLM may have returned format instead of content", category: "PowerMode", level: .warning)
        }

        return suggestions
    }

    /// Map QuickActionType to QuickSuggestion.SuggestionType
    private func mapQuickActionTypeToSuggestionType(_ actionType: QuickActionType) -> QuickSuggestion.SuggestionType {
        switch actionType {
        case .positive: return .positive
        case .neutral: return .neutral
        case .negative: return .negative
        case .summarize, .custom: return .neutral
        }
    }

    /// Build a comprehensive context prompt from ConversationContext
    /// Includes examples, formatting rules, memory, and style guidelines
    private func buildContextPrompt(from context: ConversationContext?) -> String {
        guard let context = context else {
            return "Write in a professional and friendly tone."
        }

        var parts: [String] = []

        // 1. EXAMPLES (highest priority - few-shot learning)
        if !context.examples.isEmpty {
            let examplesText = context.examples.enumerated().map { idx, example in
                "Example \(idx + 1):\n\"\"\"\n\(example)\n\"\"\""
            }.joined(separator: "\n\n")
            parts.append("## Writing Examples (MATCH THIS STYLE EXACTLY)\n\(examplesText)")
        }

        // 2. FORMATTING INSTRUCTIONS (from selected chips)
        let instructions = context.formattingInstructions
        if !instructions.isEmpty {
            let rulesText = instructions.map { "- \($0.promptText)" }.joined(separator: "\n")
            parts.append("## Formatting Rules\n\(rulesText)")
        }

        // 3. EMOJI LEVEL
        if context.selectedInstructions.contains("emoji_lots") {
            parts.append("## Emoji Usage\nUse emoji generously throughout - this person loves emoji! 😊🎉✨")
        } else if context.selectedInstructions.contains("emoji_few") {
            parts.append("## Emoji Usage\nUse emoji sparingly, only where they enhance the message.")
        } else if context.selectedInstructions.contains("emoji_never") {
            parts.append("## Emoji Usage\nDo NOT use any emoji. Keep it text-only.")
        }

        // 4. CUSTOM INSTRUCTIONS (user's free-form rules)
        if let custom = context.customInstructions, !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("## Custom Instructions\n\(custom)")
        }

        // 5. CONTEXT MEMORY (facts about this context)
        if context.useContextMemory, let memory = context.contextMemory, !memory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("## Context Knowledge\n\(memory)")
        }

        // 6. DOMAIN INFO
        if context.domainJargon != .none {
            parts.append("## Domain\nThis is \(context.domainJargon.displayName.lowercased()) communication. Use appropriate terminology.")
        }

        // 7. CONTEXT IDENTITY
        parts.append("## Context\nWriting as/for: \(context.name) (\(context.description))")

        if parts.isEmpty {
            return "Write in a professional and friendly tone."
        }

        return parts.joined(separator: "\n\n")
    }

    /// Legacy: Derive a simple tone description (kept for compatibility)
    private func deriveToneDescription(from context: ConversationContext?) -> String {
        guard let context = context else {
            return "professional and friendly"
        }

        var toneWords: [String] = []

        if context.selectedInstructions.contains("formal") {
            toneWords.append("formal")
            toneWords.append("professional")
        }
        if context.selectedInstructions.contains("casual") {
            toneWords.append("casual")
            toneWords.append("friendly")
        }
        if context.selectedInstructions.contains("concise") {
            toneWords.append("concise")
        }
        if context.selectedInstructions.contains("emoji_lots") {
            toneWords.append("expressive with emojis")
        } else if context.selectedInstructions.contains("emoji_never") {
            toneWords.append("without emojis")
        }

        return toneWords.isEmpty ? "professional and friendly" : toneWords.joined(separator: ", ")
    }

    // Legacy prompt building (kept for reference)
    private func buildSuggestionsPrompt(screenText: String, appName: String, toneHint: String, contextName: String) -> String {
        let maxChars = 2000
        let truncated = screenText.count > maxChars ? String(screenText.prefix(maxChars)) + "..." : screenText

        return """
        App: \(appName)
        Context: \(contextName)
        Tone: \(toneHint)

        Recent conversation/content:
        \(truncated)

        Generate 3 quick replies I could send based on this conversation.
        """
    }

    private func parseSuggestionsResponse(_ response: String) -> [QuickSuggestion] {
        var suggestions: [QuickSuggestion] = []

        let lines = response.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("POSITIVE:") {
                let text = trimmed.replacingOccurrences(of: "POSITIVE:", with: "").trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    suggestions.append(QuickSuggestion(type: .positive, text: text, shortLabel: "Yes"))
                }
            } else if trimmed.hasPrefix("NEUTRAL:") {
                let text = trimmed.replacingOccurrences(of: "NEUTRAL:", with: "").trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    suggestions.append(QuickSuggestion(type: .neutral, text: text, shortLabel: "Maybe"))
                }
            } else if trimmed.hasPrefix("NEGATIVE:") {
                let text = trimmed.replacingOccurrences(of: "NEGATIVE:", with: "").trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    suggestions.append(QuickSuggestion(type: .negative, text: text, shortLabel: "No"))
                }
            }
        }

        return suggestions
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

            // Use effectiveTranscriptionLanguage to respect per-context language settings
            userInput = try await transcriptionService.transcribe(
                audioURL: audioURL,
                language: settings.effectiveTranscriptionLanguage,
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
            // Phase 17: Execute input actions (before context gathering)
            inputActionResults = []
            if !currentPowerMode.inputActions.isEmpty, let executor = inputActionExecutor {
                let enabledInputActions = currentPowerMode.inputActions.filter { $0.isEnabled }
                if !enabledInputActions.isEmpty {
                    do {
                        inputActionResults = try await executor.execute(actions: enabledInputActions)
                        macLog("Input actions executed: \(inputActionResults.count) results", category: "PowerMode")
                    } catch {
                        macLog("Input action execution failed: \(error)", category: "PowerMode")
                        throw error
                    }
                }
            }

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
                // Phase 17: Execute output actions (after generation)
                await executeOutputActions()
                state = .result
            }

        } catch {
            errorMessage = error.localizedDescription
            state = .contextPreview
        }
    }

    // MARK: - Phase 17: Output Actions

    /// Execute output actions after AI generation
    private func executeOutputActions() async {
        guard !currentPowerMode.outputActions.isEmpty,
              let executor = outputActionExecutor else { return }

        let enabledOutputActions = currentPowerMode.outputActions.filter { $0.isEnabled }
        guard !enabledOutputActions.isEmpty else { return }

        do {
            outputActionResults = try await executor.execute(
                actions: enabledOutputActions,
                output: aiResponse,
                powerMode: currentPowerMode
            )
            macLog("Output actions executed: \(outputActionResults.count) results", category: "PowerMode")
        } catch {
            macLog("Output action execution failed: \(error)", category: "PowerMode")
            // Don't fail the whole operation - user still has the result
            errorMessage = "Some output actions failed: \(error.localizedDescription)"
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

        // Phase 17: Build input action contexts from results
        let inputActionContexts: [InputActionContextInfo] = inputActionResults.compactMap { result in
            guard result.isSuccess, let content = result.content else { return nil }
            return InputActionContextInfo(
                actionLabel: result.label,
                actionType: result.actionType.rawValue,
                content: content
            )
        }

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
            webhookContexts: [],  // macOS doesn't have webhooks yet
            inputActionContexts: inputActionContexts
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

        // Reload context for new Power Mode (don't regenerate suggestions - user can press R)
        Task {
            await loadContext(regenerateSuggestions: false)
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

        // Reload context for new Power Mode (don't regenerate suggestions - user can press R)
        Task {
            await loadContext(regenerateSuggestions: false)
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
        // Reset navigation state
        navigationMode = .powerMode
        selectedSuggestionIndex = nil
        isInputFieldFocused = false
        quickSuggestions = []
        predictionInputText = ""
        suggestionsError = nil
        // Reset Obsidian search state
        obsidianSearchQuery = ""
        isSearchingObsidian = false
        manualObsidianResults = []
        // Phase 17: Reset action results
        inputActionResults = []
        outputActionResults = []
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

            // Use effectiveTranscriptionLanguage to respect per-context language settings
            let transcribedText = try await transcriptionService.transcribe(
                audioURL: audioURL,
                language: settings.effectiveTranscriptionLanguage,
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
