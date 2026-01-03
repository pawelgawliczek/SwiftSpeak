//
//  TranscriptionOrchestrator.swift
//  SwiftSpeak
//
//  Created by Claude Code on 26/12/2025.
//

import Combine
import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Central coordinator for the transcription workflow
/// Manages: recording → transcription → formatting → history
@MainActor
final class TranscriptionOrchestrator: ObservableObject {

    // MARK: - Published State

    /// Current state of the transcription workflow
    @Published private(set) var state: RecordingState = .idle

    /// Raw transcribed text (before formatting)
    @Published private(set) var transcribedText: String = ""

    /// Final formatted text (after applying mode formatting)
    @Published private(set) var formattedText: String = ""

    /// Current recording duration
    @Published private(set) var recordingDuration: TimeInterval = 0

    /// Current audio level (0.0 to 1.0) for waveform
    @Published private(set) var audioLevel: Float = 0

    /// Array of audio levels for waveform visualization
    @Published private(set) var audioLevels: [Float] = Array(repeating: 0, count: 12)

    /// Error message if state is .error
    @Published private(set) var errorMessage: String?

    // MARK: - Configuration

    /// Formatting mode to apply
    public var mode: FormattingMode = .raw

    /// Custom template for formatting (overrides mode if set)
    public var customTemplate: CustomTemplate?

    /// Whether to translate after transcription
    public var translateEnabled: Bool = false

    /// Target language for translation
    public var targetLanguage: Language = .spanish

    /// Source language hint for transcription (nil for auto-detect)
    public var sourceLanguage: Language?

    /// Active conversation context (if any)
    public var activeContext: ConversationContext?

    /// Active power mode (if running in Power Mode)
    public var activePowerMode: PowerMode?

    /// Phase 12: Original text to edit (nil for normal transcription)
    public var editOriginalText: String?

    /// Phase 12: Whether we're in edit mode
    public var isEditMode: Bool {
        editOriginalText != nil && !(editOriginalText?.isEmpty ?? true)
    }

    // MARK: - Dependencies

    private let settings: SharedSettings
    private let audioRecorder: AudioRecorder
    private let providerFactory: ProviderFactory
    // NOTE: memoryManager removed - memory updates now handled by MemoryUpdateScheduler
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Processing Metadata Tracking (Phase 11)

    /// Start time of the entire operation
    private var operationStartTime: Date?

    /// Collected processing steps
    private var processingSteps: [ProcessingStepInfo] = []

    /// Last prompts used for each step (for metadata capture)
    private var lastTranscriptionPromptHint: String?
    private var lastFormattingPrompt: String?
    private var lastTranslationPrompt: String?
    private var lastEditPrompt: String?  // Phase 12

    /// Captured memory sources for metadata
    private var capturedMemorySources: [String]?

    /// Captured vocabulary words applied
    private var capturedVocabularyApplied: [String]?

    // MARK: - Initialization

    public init(
        settings: SharedSettings? = nil,
        audioRecorder: AudioRecorder? = nil,
        providerFactory: ProviderFactory? = nil
    ) {
        let resolvedSettings = settings ?? SharedSettings.shared
        self.settings = resolvedSettings
        self.audioRecorder = audioRecorder ?? AudioRecorder()
        self.providerFactory = providerFactory ?? ProviderFactory(settings: resolvedSettings)

        setupBindings()
    }

    private func setupBindings() {
        // Bind audio recorder properties
        audioRecorder.$duration
            .assign(to: &$recordingDuration)

        audioRecorder.$currentLevel
            .assign(to: &$audioLevel)

        // Generate audio levels array from current level
        audioRecorder.$currentLevel
            .map { level in
                (0..<12).map { index in
                    let variance = Float.random(in: -0.15...0.15)
                    let phase = sin(Float(index) * 0.5)
                    return max(0, min(1, level + variance * phase * level))
                }
            }
            .assign(to: &$audioLevels)
    }

    // MARK: - Workflow Control

    /// Start recording audio
    public func startRecording() async {
        // Reset state
        transcribedText = ""
        formattedText = ""
        errorMessage = nil

        // Reset processing metadata tracking
        operationStartTime = Date()
        processingSteps = []
        lastTranscriptionPromptHint = nil
        lastFormattingPrompt = nil
        lastTranslationPrompt = nil
        lastEditPrompt = nil  // Phase 12
        capturedMemorySources = nil
        capturedVocabularyApplied = nil

        do {
            state = .recording
            let contextInfo = activeContext != nil ? ", context: \(activeContext!.name)" : ""
            appLog("Recording started (mode: \(mode.rawValue)\(contextInfo))", category: "Transcription")
            try await audioRecorder.startRecording()
        } catch let error as TranscriptionError {
            handleError(error)
        } catch {
            handleError(.recordingFailed(error.localizedDescription))
        }
    }

    /// Stop recording and process the audio
    public func stopRecording() async {
        guard state == .recording else { return }

        do {
            // Stop recording and get audio URL
            let audioURL = try audioRecorder.stopRecording()
            appLog("Recording stopped (\(String(format: "%.1f", recordingDuration))s)", category: "Transcription")

            // Phase 11j: Validate audio duration
            if let validationError = validateAudioDuration() {
                throw validationError
            }

            // Transcribe
            state = .processing
            appLog("Transcription started (provider: \(settings.selectedTranscriptionProvider.shortName))", category: "Transcription")
            let rawText = try await transcribe(audioURL: audioURL)
            transcribedText = rawText
            appLog("Transcription complete (\(rawText.count) chars)", category: "Transcription")

            // Phase 12: Edit mode has a separate flow
            if isEditMode, let originalText = editOriginalText {
                appLog("Edit mode: applying edits to original text (\(originalText.count) chars)", category: "Transcription")

                // The transcribed text is the user's instructions
                let instructions = rawText

                // Apply the edit using LLM
                state = .formatting
                appLog("Applying edits...", category: "Transcription")
                formattedText = try await applyEdit(originalText: originalText, instructions: instructions)
                appLog("Edit complete (\(formattedText.count) chars)", category: "Transcription")

                // Save to history with edit context
                saveEditToHistory(originalText: originalText, instructions: instructions)

            } else {
                // Normal transcription flow
                // Apply vocabulary replacements
                let processedText = settings.applyVocabulary(to: rawText)

                // Check if context has content that needs processing
                let contextHasContent = activeContext != nil && buildPromptContext().hasContent

                // Format if needed (custom template, built-in mode, or context with instructions)
                if customTemplate != nil || mode != .raw || contextHasContent {
                    state = .formatting
                    let contextInfo = activeContext != nil ? " with context '\(activeContext!.name)'" : ""
                    appLog("Formatting started (mode: \(mode.rawValue)\(contextInfo))", category: "Transcription")
                    formattedText = try await format(text: processedText)
                    appLog("Formatting complete (\(formattedText.count) chars)", category: "Transcription")
                } else {
                    formattedText = processedText
                }

                // Translate if enabled
                if translateEnabled {
                    state = .translating
                    appLog("Translation started (to: \(targetLanguage.rawValue))", category: "Transcription")
                    formattedText = try await translate(text: formattedText)
                    appLog("Translation complete (\(formattedText.count) chars)", category: "Transcription")
                }

                // Save to history
                saveToHistory()
            }

            // NOTE: Memory updates are now handled by MemoryUpdateScheduler on app start/foreground
            // The memory flags are set on TranscriptionRecord for batch processing

            // Update lastTranscription for keyboard
            settings.lastTranscription = formattedText

            // Copy to clipboard
            copyToClipboard()

            // Set pending auto-insert so keyboard can inject text when user returns
            var status = settings.processingStatus
            status.pendingAutoInsert = true
            status.lastCompletedText = formattedText
            status.currentStep = .complete
            status.isProcessing = false
            status.lastUpdateAt = Date()
            settings.processingStatus = status
            appLog("Set pendingAutoInsert=true for keyboard (editMode: \(isEditMode))", category: "Transcription")

            // Phase 12: Set edit mode flag so keyboard knows to replace text
            if isEditMode {
                let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
                defaults?.set(true, forKey: Constants.EditMode.lastResultWasEdit)
                defaults?.synchronize()
                appLog("Set lastResultWasEdit=true for keyboard", category: "Transcription")
            }

            // Complete
            state = .complete(formattedText)
            appLog("Transcription workflow complete, copied to clipboard", category: "Transcription")

            // Clean up audio file
            audioRecorder.deleteRecording()

        } catch let error as TranscriptionError {
            appLog("Transcription error: \(LogSanitizer.sanitizeError(error))", category: "Transcription", level: .error)
            handleError(error)
        } catch {
            appLog("Transcription error (network): \(LogSanitizer.sanitizeError(error))", category: "Transcription", level: .error)
            handleError(.networkError(error.localizedDescription))
        }
    }

    /// Cancel the current operation
    public func cancel() {
        audioRecorder.cancelRecording()
        state = .idle
        transcribedText = ""
        formattedText = ""
        errorMessage = nil
    }

    /// Reset to idle state
    public func reset() {
        state = .idle
        transcribedText = ""
        formattedText = ""
        errorMessage = nil
        recordingDuration = 0
        audioLevel = 0
        audioLevels = Array(repeating: 0, count: 12)

        // Reset processing metadata
        operationStartTime = nil
        processingSteps = []
        lastTranscriptionPromptHint = nil
        lastFormattingPrompt = nil
        lastTranslationPrompt = nil
        lastEditPrompt = nil  // Phase 12
        capturedMemorySources = nil
        capturedVocabularyApplied = nil

        // Phase 12: Don't reset editOriginalText here - it's set externally before recording starts
    }

    /// Retry after an error
    public func retry() async {
        reset()
        await startRecording()
    }

    // MARK: - Context Building

    /// Build PromptContext from current settings and active context/power mode
    private func buildPromptContext() -> PromptContext {
        // Use the factory method on PromptContext
        return PromptContext.from(
            settings: settings,
            context: activeContext,
            powerMode: activePowerMode
        )
    }

    // MARK: - Transcription

    private func transcribe(audioURL: URL) async throws -> String {
        let stepStart = Date()

        // Get transcription provider via factory
        guard let provider = providerFactory.createSelectedTranscriptionProvider() else {
            throw TranscriptionError.providerNotConfigured
        }

        // Phase 10: Check privacy mode - block cloud providers
        if settings.forcePrivacyMode && !provider.providerId.isLocalProvider {
            throw TranscriptionError.privacyModeBlocksCloudProvider(provider.providerId.displayName)
        }

        // Build prompt hint for transcription (vocabulary + language hints)
        let context = buildPromptContext()
        let promptHint = context.buildTranscriptionHint()
        lastTranscriptionPromptHint = promptHint

        // Capture memory sources being used
        capturedMemorySources = buildMemorySources(from: context)

        let result = try await provider.transcribe(audioURL: audioURL, language: sourceLanguage, promptHint: promptHint)

        let stepEnd = Date()

        // Calculate step cost
        let costCalculator = CostCalculator()
        let transcriptionCost = costCalculator.transcriptionCost(
            provider: provider.providerId,
            model: provider.model,
            durationSeconds: recordingDuration
        )

        // Record step info
        let stepInfo = ProcessingStepInfo(
            stepType: .transcription,
            provider: provider.providerId,
            modelName: provider.model,
            startTime: stepStart,
            endTime: stepEnd,
            inputTokens: nil,  // STT doesn't have tokens
            outputTokens: nil,
            cost: transcriptionCost,
            prompt: promptHint
        )
        processingSteps.append(stepInfo)

        return result
    }

    // MARK: - Formatting

    private func format(text: String) async throws -> String {
        let stepStart = Date()

        // Get formatting provider via factory
        guard let provider = providerFactory.createSelectedTextFormattingProvider() else {
            // If no formatting provider, return original text
            return text
        }

        // Phase 10: Check privacy mode - block cloud providers
        if settings.forcePrivacyMode && !provider.providerId.isLocalProvider {
            throw TranscriptionError.privacyModeBlocksCloudProvider(provider.providerId.displayName)
        }

        // Build context for formatting (includes memory, tone, instructions)
        let context = buildPromptContext()

        // Build and capture the formatting prompt for metadata
        let customPrompt = customTemplate?.prompt
        lastFormattingPrompt = buildFormattingPromptDescription(
            mode: mode,
            customPrompt: customPrompt,
            context: context,
            text: text
        )

        let result = try await provider.format(text: text, mode: mode, customPrompt: customPrompt, context: context)

        let stepEnd = Date()

        // Estimate tokens (rough: 1 token ≈ 4 characters)
        let inputTokens = text.count / 4
        let outputTokens = result.count / 4

        // Calculate step cost
        let costCalculator = CostCalculator()
        let formattingCost = costCalculator.llmCost(
            provider: provider.providerId,
            model: provider.model,
            inputTokens: inputTokens,
            outputTokens: outputTokens
        )

        // Record step info
        let stepInfo = ProcessingStepInfo(
            stepType: .formatting,
            provider: provider.providerId,
            modelName: provider.model,
            startTime: stepStart,
            endTime: stepEnd,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cost: formattingCost,
            prompt: lastFormattingPrompt
        )
        processingSteps.append(stepInfo)

        return result
    }

    // MARK: - Translation

    private func translate(text: String) async throws -> String {
        let stepStart = Date()

        // Get translation provider via factory
        guard let provider = providerFactory.createSelectedTranslationProvider() else {
            throw TranscriptionError.providerNotConfigured
        }

        // Phase 10: Check privacy mode - block cloud providers
        if settings.forcePrivacyMode && !provider.providerId.isLocalProvider {
            throw TranscriptionError.privacyModeBlocksCloudProvider(provider.providerId.displayName)
        }

        // Build context for translation (includes memory, tone for formality inference)
        let context = buildPromptContext()
        let formality = context.inferFormality()

        // Capture translation prompt description
        lastTranslationPrompt = buildTranslationPromptDescription(
            from: sourceLanguage,
            to: targetLanguage,
            formality: formality,
            text: text
        )

        let result = try await provider.translate(
            text: text,
            from: sourceLanguage,
            to: targetLanguage,
            formality: formality,
            context: context
        )

        let stepEnd = Date()

        // Calculate step cost (character-based for DeepL/Azure, token-based for others)
        let costCalculator = CostCalculator()
        let translationCost: Double
        if provider.providerId == .deepL || provider.providerId == .azure {
            translationCost = costCalculator.characterCost(
                provider: provider.providerId,
                model: provider.model,
                characterCount: text.count
            )
        } else {
            let inputTokens = text.count / 4
            let outputTokens = result.count / 4
            translationCost = costCalculator.llmCost(
                provider: provider.providerId,
                model: provider.model,
                inputTokens: inputTokens,
                outputTokens: outputTokens
            )
        }

        // Record step info
        let stepInfo = ProcessingStepInfo(
            stepType: .translation,
            provider: provider.providerId,
            modelName: provider.model,
            startTime: stepStart,
            endTime: stepEnd,
            inputTokens: text.count / 4,
            outputTokens: result.count / 4,
            cost: translationCost,
            prompt: lastTranslationPrompt
        )
        processingSteps.append(stepInfo)

        return result
    }

    // MARK: - Edit Mode (Phase 12)

    /// Apply user's edit instructions to original text using LLM
    private func applyEdit(originalText: String, instructions: String) async throws -> String {
        let stepStart = Date()

        // Get formatting provider via factory
        guard let provider = providerFactory.createSelectedTextFormattingProvider() else {
            throw TranscriptionError.providerNotConfigured
        }

        // Phase 10: Check privacy mode - block cloud providers
        if settings.forcePrivacyMode && !provider.providerId.isLocalProvider {
            throw TranscriptionError.privacyModeBlocksCloudProvider(provider.providerId.displayName)
        }

        // Build the edit prompt
        let systemPrompt = """
        You are a text editor. Modify the provided text according to the user's instructions.
        Return ONLY the modified text, nothing else.
        Preserve the original language unless translation is requested.
        Do not add explanations, prefixes, or commentary.
        """

        let userPrompt = """
        Original text:
        \(originalText)

        Instructions:
        \(instructions)
        """

        // Capture the prompt for metadata
        lastEditPrompt = "System: \(systemPrompt)\n\nUser:\n\(userPrompt)"

        // Use raw mode with custom system prompt
        let result = try await provider.format(
            text: userPrompt,
            mode: .raw,
            customPrompt: systemPrompt,
            context: nil
        )

        let stepEnd = Date()

        // Estimate tokens
        let inputTokens = (systemPrompt.count + userPrompt.count) / 4
        let outputTokens = result.count / 4

        // Calculate step cost
        let costCalculator = CostCalculator()
        let editCost = costCalculator.llmCost(
            provider: provider.providerId,
            model: provider.model,
            inputTokens: inputTokens,
            outputTokens: outputTokens
        )

        // Record step info
        let stepInfo = ProcessingStepInfo(
            stepType: .formatting,  // Edit is a form of formatting
            provider: provider.providerId,
            modelName: provider.model,
            startTime: stepStart,
            endTime: stepEnd,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cost: editCost,
            prompt: lastEditPrompt
        )
        processingSteps.append(stepInfo)

        return result
    }

    /// Save edit operation to history with EditContext
    private func saveEditToHistory(originalText: String, instructions: String) {
        // Calculate cost breakdown
        let costBreakdown = calculateCostBreakdown()

        // Build processing metadata
        let processingMetadata = buildProcessingMetadata()

        // Create edit context
        let editContext = EditContext(
            originalText: originalText,
            instructions: instructions,
            parentEntryId: findParentEntryId(for: originalText)
        )

        let record = TranscriptionRecord(
            id: UUID(),
            rawTranscribedText: instructions,  // The dictated instructions
            text: formattedText,               // The edited result
            mode: .raw,                        // Edit mode uses raw for instructions
            provider: settings.selectedTranscriptionProvider,
            timestamp: Date(),
            duration: recordingDuration,
            translated: false,
            targetLanguage: nil,
            powerModeId: nil,
            powerModeName: nil,
            contextId: activeContext?.id,
            contextName: activeContext?.name,
            contextIcon: activeContext?.icon,
            estimatedCost: costBreakdown?.total,
            costBreakdown: costBreakdown,
            processingMetadata: processingMetadata,
            editContext: editContext,
            // Memory tracking - capture state at transcription time
            globalMemoryEnabled: settings.globalMemoryEnabled,
            contextMemoryEnabled: activeContext?.useContextMemory ?? false,
            powerModeMemoryEnabled: false,  // Edit mode doesn't use power mode
            usedForGlobalMemory: false,
            usedForContextMemory: false,
            usedForPowerModeMemory: false
        )

        settings.addTranscription(record)
        appLog("Edit saved to history (parent: \(editContext.parentEntryId?.uuidString ?? "none"))", category: "Transcription")
    }

    /// Find parent entry if the original text matches a recent transcription
    private func findParentEntryId(for originalText: String) -> UUID? {
        // Look in recent history (last 50 entries, last 24 hours)
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        let recentEntries = settings.transcriptionHistory
            .prefix(50)
            .filter { $0.timestamp > cutoff }

        // Match by exact text first
        for entry in recentEntries {
            if entry.text == originalText {
                return entry.id
            }
        }

        // Fuzzy match (handles minor changes like trailing spaces)
        for entry in recentEntries {
            let trimmedOriginal = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedEntry = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedOriginal == trimmedEntry {
                return entry.id
            }

            // Check if one is a prefix of the other (for partial text selection)
            if trimmedEntry.hasPrefix(trimmedOriginal) || trimmedOriginal.hasPrefix(trimmedEntry) {
                // Only match if at least 80% similar length
                let ratio = Double(min(trimmedEntry.count, trimmedOriginal.count)) / Double(max(trimmedEntry.count, trimmedOriginal.count))
                if ratio > 0.8 {
                    return entry.id
                }
            }
        }

        return nil
    }

    // MARK: - History

    private func saveToHistory() {
        // Calculate cost breakdown (Phase 9)
        let costBreakdown = calculateCostBreakdown()

        // Build processing metadata (Phase 11)
        let processingMetadata = buildProcessingMetadata()

        let record = TranscriptionRecord(
            id: UUID(),
            rawTranscribedText: transcribedText,  // Raw text before formatting
            text: formattedText.isEmpty ? transcribedText : formattedText,
            mode: mode,
            provider: settings.selectedTranscriptionProvider,
            timestamp: Date(),
            duration: recordingDuration,
            translated: translateEnabled,
            targetLanguage: translateEnabled ? targetLanguage : nil,
            powerModeId: activePowerMode?.id,
            powerModeName: activePowerMode?.name,
            contextId: activeContext?.id,
            contextName: activeContext?.name,
            contextIcon: activeContext?.icon,
            estimatedCost: costBreakdown?.total,
            costBreakdown: costBreakdown,
            processingMetadata: processingMetadata,
            // Memory tracking - capture state at transcription time
            globalMemoryEnabled: settings.globalMemoryEnabled,
            contextMemoryEnabled: activeContext?.useContextMemory ?? false,
            powerModeMemoryEnabled: activePowerMode?.memoryEnabled ?? false,
            usedForGlobalMemory: false,
            usedForContextMemory: false,
            usedForPowerModeMemory: false
        )

        settings.addTranscription(record)
    }

    /// Build ProcessingMetadata from captured steps (Phase 11)
    private func buildProcessingMetadata() -> ProcessingMetadata {
        let totalTime = operationStartTime.map { Date().timeIntervalSince($0) } ?? 0

        // Get vocabulary words that were applied
        let vocabularyApplied = settings.vocabularyEntries
            .filter { $0.isEnabled }
            .map { $0.recognizedWord }

        return ProcessingMetadata(
            steps: processingSteps,
            totalProcessingTime: totalTime,
            sourceLanguageHint: sourceLanguage,
            vocabularyApplied: vocabularyApplied.isEmpty ? nil : vocabularyApplied,
            memorySourcesUsed: capturedMemorySources,
            ragDocumentsQueried: nil,  // Not used in regular transcription
            webhooksExecuted: nil       // Not used in regular transcription
        )
    }

    /// Build list of memory sources from PromptContext
    private func buildMemorySources(from context: PromptContext) -> [String]? {
        var sources: [String] = []

        if context.globalMemory != nil {
            sources.append("Global Memory")
        }
        if let contextName = context.contextName, context.contextMemory != nil {
            sources.append("\(contextName) Context")
        }
        if let powerModeName = context.powerModeName, context.powerModeMemory != nil {
            sources.append("\(powerModeName) Memory")
        }

        return sources.isEmpty ? nil : sources
    }

    /// Build a description of the formatting prompt for metadata
    private func buildFormattingPromptDescription(
        mode: FormattingMode,
        customPrompt: String?,
        context: PromptContext,
        text: String
    ) -> String {
        var description = "Mode: \(mode.rawValue)\n"

        if let custom = customPrompt {
            description += "Custom Template:\n\(custom)\n\n"
        }

        if let globalMemory = context.globalMemory {
            description += "Global Memory:\n\(globalMemory)\n\n"
        }

        if let contextMemory = context.contextMemory {
            description += "Context Memory (\(context.contextName ?? "Unknown")):\n\(contextMemory)\n\n"
        }

        if let customInstructions = context.customInstructions {
            description += "Custom Instructions:\n\(customInstructions)\n\n"
        }

        description += "Input Text (\(text.count) chars):\n\(text.prefix(200))..."

        return description
    }

    /// Build a description of the translation prompt for metadata
    private func buildTranslationPromptDescription(
        from sourceLanguage: Language?,
        to targetLanguage: Language,
        formality: Formality,
        text: String
    ) -> String {
        var description = "Source: \(sourceLanguage?.rawValue ?? "auto-detect")\n"
        description += "Target: \(targetLanguage.rawValue)\n"
        description += "Formality: \(formality.rawValue)\n"
        description += "Input Text (\(text.count) chars):\n\(text.prefix(200))..."

        return description
    }

    /// Calculate cost breakdown for the current transcription operation (Phase 9)
    private func calculateCostBreakdown() -> CostBreakdown? {
        let costCalculator = CostCalculator()

        // Get transcription provider and model
        let transcriptionProvider = settings.selectedTranscriptionProvider
        let transcriptionConfig = settings.selectedTranscriptionProviderConfig
        let transcriptionModel = transcriptionConfig?.transcriptionModel ?? transcriptionProvider.defaultSTTModel ?? "default"

        // Determine if formatting was applied
        let formattingProvider: AIProvider?
        let formattingModel: String?
        if mode != .raw {
            formattingProvider = settings.selectedTranslationProvider
            let formattingConfig = settings.selectedTranslationProviderConfig
            formattingModel = formattingConfig?.translationModel ?? settings.selectedTranslationProvider.defaultLLMModel
        } else {
            formattingProvider = nil
            formattingModel = nil
        }

        // Determine if translation was applied
        let translationProvider: AIProvider?
        let translationModel: String?
        if translateEnabled {
            translationProvider = settings.selectedTranslationProvider
            let translationConfig = settings.selectedTranslationProviderConfig
            translationModel = translationConfig?.translationModel ?? settings.selectedTranslationProvider.defaultLLMModel
        } else {
            translationProvider = nil
            translationModel = nil
        }

        // Calculate the text length for cost estimation
        let resultText = formattedText.isEmpty ? transcribedText : formattedText
        let textLength = resultText.count

        return costCalculator.calculateCostBreakdown(
            transcriptionProvider: transcriptionProvider,
            transcriptionModel: transcriptionModel,
            formattingProvider: formattingProvider,
            formattingModel: formattingModel,
            translationProvider: translationProvider,
            translationModel: translationModel,
            durationSeconds: recordingDuration,
            textLength: textLength,
            text: resultText
        )
    }

    // MARK: - Clipboard

    private func copyToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = formattedText
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(formattedText, forType: .string)
        #endif
    }

    // NOTE: Memory updates removed - now handled by MemoryUpdateScheduler on app start/foreground

    // MARK: - Audio Validation (Phase 11j)

    /// Validate audio duration and file size before processing
    private func validateAudioDuration() -> TranscriptionError? {
        let duration = recordingDuration

        // Use Constants.AudioValidation for duration validation
        let durationResult = Constants.AudioValidation.validateDuration(duration)
        switch durationResult {
        case .valid:
            break
        case .tooShort(let dur):
            return .audioTooShort(duration: dur, minDuration: Constants.AudioValidation.minDuration)
        case .tooLong(let dur):
            return .audioTooLong(duration: dur, maxDuration: Constants.AudioValidation.maxDuration)
        case .fileTooLarge(let sizeMB, let maxSizeMB):
            return .fileTooLarge(sizeMB: sizeMB, maxSizeMB: maxSizeMB)
        }

        // Log warning for long recordings (but allow them)
        if Constants.AudioValidation.shouldWarnDuration(duration) {
            appLog("Long recording warning: \(Int(duration))s - may take longer to process", category: "Transcription", level: .warning)
        }

        // Validate file size
        if let fileSizeBytes = audioRecorder.recordingFileSize {
            let sizeResult = Constants.AudioValidation.validateFileSize(Int64(fileSizeBytes))
            switch sizeResult {
            case .valid:
                break
            case .fileTooLarge(let sizeMB, let maxSizeMB):
                return .fileTooLarge(sizeMB: sizeMB, maxSizeMB: maxSizeMB)
            case .tooShort, .tooLong:
                break  // Not applicable for file size
            }
        }

        return nil
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

public extension TranscriptionOrchestrator {
    /// Whether currently recording
    public var isRecording: Bool {
        state == .recording
    }

    /// Whether processing (transcribing or formatting)
    public var isProcessing: Bool {
        state == .processing || state == .formatting
    }

    /// Whether the workflow is complete
    public var isComplete: Bool {
        if case .complete = state { return true }
        return false
    }

    /// Whether there was an error
    public var hasError: Bool {
        if case .error = state { return true }
        return false
    }

    /// Whether idle and ready to start
    public var isIdle: Bool {
        state == .idle
    }

    /// The result text (formatted or raw)
    public var resultText: String {
        formattedText.isEmpty ? transcribedText : formattedText
    }

    /// Provider name for display
    public var transcriptionProviderName: String {
        settings.selectedTranscriptionProvider.displayName
    }

    /// Model name for display
    public var transcriptionModelName: String? {
        settings.getAIProviderConfig(for: settings.selectedTranscriptionProvider)?.transcriptionModel
    }

    /// Formatting provider name for display
    public var formattingProviderName: String? {
        guard mode != .raw else { return nil }
        return settings.selectedTranslationProvider.displayName
    }
}
