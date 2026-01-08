//
//  MacTranscribeOverlayViewModel.swift
//  SwiftSpeakMac
//
//  ViewModel for the Transcribe overlay
//  Handles transcription, context auto-selection, and translation toggle
//

import SwiftUI
import Combine
import SwiftSpeakCore

// MARK: - Transcribe Overlay State

enum TranscribeOverlayState: Equatable {
    case idle              // Overlay not visible
    case ready             // Overlay visible, waiting to record
    case recording         // Recording audio
    case transcribing      // Transcribing audio
    case formatting        // Formatting transcription
    case complete          // Transcription complete
    case error(String)     // Error state

    var statusText: String {
        switch self {
        case .idle: return ""
        case .ready: return "Ready"
        case .recording: return "Recording"
        case .transcribing: return "Transcribing..."
        case .formatting: return "Formatting..."
        case .complete: return "Complete"
        case .error: return "Error"
        }
    }

    var isProcessing: Bool {
        switch self {
        case .transcribing, .formatting:
            return true
        default:
            return false
        }
    }
}

// MARK: - Transcribe Mode

enum TranscribeMode {
    case toggle      // User toggled the overlay (stays open until dismissed)
    case pushToTalk  // User is holding the hotkey (closes on release)
}

// MARK: - MacTranscribeOverlayViewModel

@MainActor
final class MacTranscribeOverlayViewModel: ObservableObject {

    // MARK: - Published State

    @Published var state: TranscribeOverlayState = .idle
    @Published var mode: TranscribeMode = .toggle

    /// Active context (auto-detected or manually selected)
    @Published var activeContext: ConversationContext?

    /// Translation enabled
    @Published var isTranslationEnabled: Bool = false

    /// Target language for translation
    @Published var targetLanguage: Language = .english

    /// Effective input language (from context or system default)
    @Published var inputLanguage: Language?

    /// Live transcript during recording (if streaming available)
    @Published var liveTranscript: String = ""

    /// Final transcribed text
    @Published var transcribedText: String = ""

    /// Recording duration
    @Published var recordingDuration: TimeInterval = 0

    /// Audio level for visualization
    @Published var audioLevel: Float = 0

    /// Error message
    @Published var errorMessage: String?

    /// Source app info (for auto-context detection)
    @Published var sourceAppName: String = ""
    @Published var sourceAppBundleId: String = ""

    /// Signals that insertion is complete and overlay should close
    @Published var shouldAutoClose: Bool = false

    // MARK: - Dependencies

    let settings: MacSettings
    private let audioRecorder: MacAudioRecorder
    private var providerFactory: ProviderFactory?
    private var textInsertion: MacTextInsertionService?

    /// Callback to hide overlay before text insertion (set by controller)
    var onWillInsertText: (() -> Void)?

    // MARK: - Internal State

    private var cancellables = Set<AnyCancellable>()
    private var recordingTimer: Timer?
    private var previousApp: NSRunningApplication?

    /// Pre-captured context from hotkey callback
    private var preCapturedContext: HotkeyContext?

    // MARK: - Initialization

    init(
        settings: MacSettings,
        audioRecorder: MacAudioRecorder
    ) {
        self.settings = settings
        self.audioRecorder = audioRecorder

        setupBindings()
    }

    // MARK: - Dependency Injection

    func setDependencies(
        providerFactory: ProviderFactory,
        textInsertion: MacTextInsertionService
    ) {
        self.providerFactory = providerFactory
        self.textInsertion = textInsertion
    }

    // MARK: - Setup

    private func setupBindings() {
        // Sync translation settings from MacSettings
        isTranslationEnabled = settings.isTranslationEnabled
        targetLanguage = settings.selectedTargetLanguage
        inputLanguage = settings.selectedDictationLanguage

        // Observe audio recorder level
        audioRecorder.$currentLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellables)
    }

    // MARK: - Context Auto-Detection

    /// Set the pre-captured context from hotkey callback and auto-detect context
    func setPreCapturedContext(_ context: HotkeyContext) {
        self.preCapturedContext = context
        self.sourceAppName = context.frontmostAppName
        self.sourceAppBundleId = context.frontmostAppBundleId

        // Store the previous app for focus restoration
        if context.frontmostAppPid > 0 {
            self.previousApp = NSRunningApplication(processIdentifier: context.frontmostAppPid)
            macLog("Stored previous app: \(context.frontmostAppName) (pid: \(context.frontmostAppPid))", category: "Transcribe")
        }

        // Auto-detect context based on app bundle ID
        autoSelectContext(for: context.frontmostAppBundleId)
    }

    /// Auto-select context based on frontmost app's bundle ID
    private func autoSelectContext(for bundleId: String) {
        guard !bundleId.isEmpty else { return }

        macLog("Auto-detecting context for bundleId: '\(bundleId)'", category: "Transcribe")
        macLog("Available contexts: \(settings.contexts.map { "\($0.name) (apps: \($0.appAssignment.assignedAppIds))" })", category: "Transcribe")

        // Find a context that includes this app
        // Check all contexts for app assignment match
        for context in settings.contexts {
            let hasAssignments = context.appAssignment.hasAssignments
            let matches = context.appAssignment.includes(
                bundleId: bundleId,
                userOverrides: [:],  // TODO: Load user category overrides
                appLookup: { _ in nil }  // TODO: Implement app library lookup
            )
            macLog("Context '\(context.name)': hasAssignments=\(hasAssignments), matches=\(matches), assignedApps=\(context.appAssignment.assignedAppIds)", category: "Transcribe", level: .debug)

            if matches {
                activeContext = context
                macLog("Auto-selected context '\(context.name)' for app '\(bundleId)'", category: "Transcribe")

                // Apply context's default input language (only if context has one)
                if let contextLanguage = context.defaultInputLanguage {
                    inputLanguage = contextLanguage
                }
                return
            }
        }

        // No app-specific match - use global active context from settings (if any)
        // But DON'T override inputLanguage - keep the global dictation language
        // The user's global dictation language takes precedence unless a context explicitly sets one
        activeContext = settings.activeContext
        macLog("No app-specific context match, using activeContext: \(activeContext?.name ?? "none"), keeping inputLanguage: \(inputLanguage?.displayName ?? "auto")", category: "Transcribe")
    }

    // MARK: - Recording Control

    func startRecording() async {
        do {
            state = .recording
            recordingDuration = 0
            liveTranscript = ""
            errorMessage = nil

            // Play start sound if enabled
            if settings.playSoundOnRecordStart {
                NSSound(named: "Tink")?.play()
            }

            // Start timer IMMEDIATELY to show responsive UI
            // The timer reads from audioRecorder.duration which starts counting
            // from when startRecording() was called (even during setup)
            let timerStartTime = Date()
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    // Use audioRecorder.duration if available, otherwise calculate from timer start
                    if self.audioRecorder.isRecording {
                        self.recordingDuration = self.audioRecorder.duration
                    } else {
                        // During setup, show elapsed time since we started
                        self.recordingDuration = Date().timeIntervalSince(timerStartTime)
                    }
                }
            }

            // Set recording format based on transcription provider
            // Google STT requires WAV (LINEAR16), other providers work with AAC (smaller files)
            audioRecorder.recordingFormat = RecordingFormat.forProvider(settings.selectedTranscriptionProvider)
            macLog("Using recording format: \(audioRecorder.recordingFormat) for provider: \(settings.selectedTranscriptionProvider.displayName)", category: "Transcribe")

            // Start audio recording (may take time on first call due to audio engine init)
            try await audioRecorder.startRecording()

            macLog("Recording started", category: "Transcribe")
        } catch {
            macLog("Failed to start recording: \(error)", category: "Transcribe", level: .error)
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            state = .error(error.localizedDescription)
        }
    }

    func stopRecording() async {
        guard state == .recording else { return }

        recordingTimer?.invalidate()
        recordingTimer = nil

        // Play stop sound if enabled
        if settings.playSoundOnRecordEnd {
            NSSound(named: "Pop")?.play()
        }

        do {
            let audioURL = try audioRecorder.stopRecording()
            macLog("Recording stopped, audio file: \(audioURL)", category: "Transcribe")

            // Process the recording
            await processRecording(audioURL: audioURL)
        } catch {
            macLog("Failed to stop recording: \(error)", category: "Transcribe", level: .error)
            errorMessage = "Failed to stop recording: \(error.localizedDescription)"
            state = .error(error.localizedDescription)
        }
    }

    func cancelRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioRecorder.cancelRecording()

        state = .idle
        liveTranscript = ""
        transcribedText = ""
        macLog("Recording cancelled", category: "Transcribe")
    }

    /// Clean up all resources - call before deallocation
    func cleanup() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        cancellables.removeAll()
        macLog("Transcribe viewModel cleanup", category: "Transcribe")
    }

    // MARK: - Processing

    /// Result of formatting operation
    private struct FormattingResult {
        let text: String
        let prompt: String
        let startTime: Date
        let endTime: Date
    }

    private func processRecording(audioURL: URL) async {
        guard let factory = providerFactory else {
            errorMessage = "Provider factory not configured"
            state = .error("Configuration error")
            return
        }

        state = .transcribing
        var processingSteps: [ProcessingStepInfo] = []
        let overallStartTime = Date()

        do {
            // Get transcription provider
            let selectedProvider = settings.selectedTranscriptionProvider
            macLog("Using transcription provider: \(selectedProvider.displayName)", category: "Transcribe")

            guard let transcriptionProvider = factory.createTranscriptionProvider(
                for: selectedProvider
            ) else {
                // Log detailed config info for debugging
                if let config = settings.getAIProviderConfig(for: selectedProvider) {
                    macLog("Provider \(selectedProvider.displayName) config exists but failed to create:", category: "Transcribe", level: .error)
                    macLog("  - apiKey empty: \(config.apiKey.isEmpty)", category: "Transcribe", level: .error)
                    if selectedProvider == .google {
                        macLog("  - googleProjectId: \(config.googleProjectId ?? "nil")", category: "Transcribe", level: .error)
                    }
                } else {
                    macLog("No config found for provider \(selectedProvider.displayName)", category: "Transcribe", level: .error)
                    macLog("Configured providers: \(settings.configuredAIProviders.map { $0.provider.displayName })", category: "Transcribe", level: .error)
                }
                throw TranscriptionError.apiKeyMissing
            }

            // Log audio file info
            if let attrs = try? FileManager.default.attributesOfItem(atPath: audioURL.path),
               let fileSize = attrs[.size] as? Int64 {
                macLog("Audio file size: \(fileSize) bytes", category: "Transcribe")
            }

            // Build prompt context with global memory and vocabulary
            let promptContext = PromptContext.from(
                context: activeContext,
                powerMode: nil,
                globalMemory: settings.globalMemoryEnabled ? settings.globalMemory : nil,
                vocabularyEntries: settings.vocabulary
            )

            // Transcribe audio with language and vocabulary hints
            macLog("Transcribing with language: \(inputLanguage?.displayName ?? "auto-detect")", category: "Transcribe")

            let transcriptionStartTime = Date()
            var transcribedText = try await transcriptionProvider.transcribe(
                audioURL: audioURL,
                language: inputLanguage,
                promptHint: promptContext.buildTranscriptionHint()
            )
            let transcriptionEndTime = Date()

            // Apply vocabulary corrections
            transcribedText = settings.applyVocabulary(to: transcribedText)

            self.transcribedText = transcribedText
            let rawTranscription = transcribedText  // Store raw for history
            macLog("Transcription complete: \(transcribedText.prefix(100))...", category: "Transcribe")

            // Create transcription processing step
            let transcriptionStep = ProcessingStepInfo(
                stepType: .transcription,
                provider: selectedProvider,
                modelName: selectedProvider.defaultTranscriptionModel,
                startTime: transcriptionStartTime,
                endTime: transcriptionEndTime,
                cost: 0,  // Cost calculated separately
                prompt: promptContext.buildTranscriptionHint()
            )
            processingSteps.append(transcriptionStep)

            // Track if formatting was actually applied
            var formattingResult: FormattingResult?

            // Apply formatting if context has formatting enabled
            let shouldFormat = activeContext?.hasFormatting == true
            macLog("Context: \(activeContext?.name ?? "none"), hasFormatting: \(shouldFormat), examples: \(activeContext?.examples.count ?? 0), selectedInstructions: \(activeContext?.selectedInstructions ?? []), customInstructions: \(activeContext?.customInstructions?.prefix(50) ?? "")", category: "Transcribe")

            if shouldFormat {
                state = .formatting
                formattingResult = try await formatTranscription(transcribedText)
                if let result = formattingResult {
                    transcribedText = result.text
                    self.transcribedText = transcribedText

                    // Create formatting processing step
                    let formattingStep = ProcessingStepInfo(
                        stepType: .formatting,
                        provider: settings.selectedPowerModeProvider,
                        modelName: settings.selectedPowerModeProvider.defaultLLMModel ?? "default",
                        startTime: result.startTime,
                        endTime: result.endTime,
                        cost: 0,  // Cost calculated separately
                        prompt: result.prompt
                    )
                    processingSteps.append(formattingStep)
                    macLog("Formatting applied", category: "Transcribe")
                }
            }

            // Translate if enabled
            if isTranslationEnabled {
                state = .formatting
                transcribedText = try await translateText(transcribedText)
                self.transcribedText = transcribedText
            }

            state = .complete

            // Build processing metadata
            let overallEndTime = Date()
            let processingMetadata = ProcessingMetadata(
                steps: processingSteps,
                totalProcessingTime: overallEndTime.timeIntervalSince(overallStartTime),
                sourceLanguageHint: inputLanguage,
                vocabularyApplied: settings.vocabulary.isEmpty ? nil : settings.vocabulary.map { $0.recognizedWord }
            )

            // Save to history
            saveToHistory(
                rawText: rawTranscription,
                finalText: self.transcribedText,
                wasTranslated: isTranslationEnabled,
                didFormat: formattingResult != nil,
                processingMetadata: processingMetadata
            )

            // Execute the context's enter key behavior
            await executeEnterKeyBehavior()

        } catch {
            macLog("Processing failed: \(error)", category: "Transcribe", level: .error)

            // Provide user-friendly error messages for common issues
            let userMessage = friendlyErrorMessage(for: error)
            errorMessage = userMessage
            state = .error(userMessage)
        }
    }

    /// Convert technical errors into user-friendly messages with actionable guidance
    private func friendlyErrorMessage(for error: Error) -> String {
        let errorString = String(describing: error)
        let provider = settings.selectedTranscriptionProvider

        // Google Cloud specific errors
        if provider == .google {
            if errorString.contains("403") {
                if errorString.contains("Speech-to-Text API has not been used") || errorString.contains("it is disabled") {
                    return """
                    ❌ Google Speech-to-Text API Not Enabled

                    Fix in Google Cloud Console:
                    1. Go to console.cloud.google.com
                    2. Select your project
                    3. Go to: APIs & Services → Library
                    4. Search "Cloud Speech-to-Text API"
                    5. Click ENABLE
                    6. Wait 1-2 minutes, then retry
                    """
                }
                if errorString.contains("Permission") && errorString.contains("denied") {
                    return """
                    ❌ Google API Permission Denied

                    Your API key cannot access Speech-to-Text. Fix this:

                    1. Go to console.cloud.google.com
                    2. APIs & Services → Credentials
                    3. Click on your API key to edit it
                    4. Under "API restrictions":
                       • Select "Don't restrict key" OR
                       • Select "Restrict key" and ADD "Cloud Speech-to-Text API"
                    5. Click SAVE
                    6. Also verify: Project ID in SwiftSpeak matches the API key's project
                    """
                }
                return "Google API Error (403): Access denied.\n\nCheck API key permissions and project configuration."
            }

            if errorString.contains("404") {
                return """
                ❌ Google API Endpoint Not Found (404)

                The Project ID appears to be incorrect.

                Fix: Go to console.cloud.google.com and copy the correct Project ID from the project selector dropdown.
                """
            }

            if errorString.contains("400") {
                if errorString.contains("enhanced model") || errorString.contains("no enhanced") {
                    return """
                    ❌ Google Model Not Available

                    The selected model doesn't support this language.

                    Try changing the model in Settings → Google Cloud → Transcription Model.
                    Recommended: "default" for broad language support.
                    """
                }
                if errorString.contains("not supported for language") {
                    return """
                    ❌ Language Not Supported by Model

                    The selected Google STT model doesn't support your language.

                    Fix: Go to Settings → Edit Google Cloud provider
                    Change Transcription Model to "default"

                    Model language support:
                    • "default" - Most languages (125+)
                    • "latest_long/short" - English, Spanish, French, German, etc.
                    • "telephony" - Limited languages
                    """
                }
                return """
                ❌ Google API Bad Request (400)

                The request format was invalid.

                Error: \(errorString.prefix(300))
                """
            }
        }

        if errorString.contains("401") {
            return """
            ❌ Invalid API Key (401)

            Your API key is invalid or expired.

            Fix: Get a new API key from your provider's console and update it in SwiftSpeak Settings.
            """
        }

        // Generic transcription errors
        if case TranscriptionError.apiKeyMissing = error {
            return """
            ❌ API Key or Project ID Missing

            Configure your \(provider.displayName) provider in Settings → Transcription & AI.
            """
        }

        if case TranscriptionError.emptyResponse = error {
            return """
            ⚠️ No Speech Detected

            The transcription returned empty. Try:
            • Speaking louder or closer to the mic
            • Checking your microphone settings
            • Recording for longer (at least 1-2 seconds)
            """
        }

        if case TranscriptionError.audioFileNotFound = error {
            return "❌ Audio file not found. Recording may have failed."
        }

        // Network errors
        if errorString.contains("NSURLError") || errorString.contains("network") {
            return """
            ❌ Network Error

            Could not connect to \(provider.displayName). Check your internet connection.
            """
        }

        // Fallback with raw error
        return "❌ Transcription Failed\n\n\(error.localizedDescription)"
    }

    private func formatTranscription(_ text: String) async throws -> FormattingResult? {
        guard let factory = providerFactory,
              let context = activeContext,
              context.hasFormatting else {
            return nil
        }

        let startTime = Date()

        do {
            // Use Power Mode provider for formatting
            guard let formattingProvider = factory.createFormattingProvider(
                for: settings.selectedPowerModeProvider
            ) else {
                return nil
            }

            // Build prompt context
            let promptContext = PromptContext.from(
                context: context,
                globalMemory: settings.globalMemoryEnabled ? settings.globalMemory : nil
            )

            // Get the formatting prompt from context
            guard let formattingPrompt = promptContext.buildFormattingPrompt() else {
                return nil
            }

            let formatted = try await formattingProvider.format(
                text: text,
                mode: FormattingMode.raw,
                customPrompt: formattingPrompt,
                context: promptContext
            )

            let endTime = Date()
            macLog("Formatting complete", category: "Transcribe")

            return FormattingResult(
                text: formatted,
                prompt: formattingPrompt,
                startTime: startTime,
                endTime: endTime
            )
        } catch {
            macLog("Formatting failed: \(error)", category: "Transcribe", level: .warning)
            // Return nil if formatting fails
            return nil
        }
    }

    private func translateText(_ text: String) async throws -> String {
        guard let factory = providerFactory else {
            return text
        }

        do {
            guard let translationProvider = factory.createTranslationProvider(
                for: settings.selectedTranslationProvider
            ) else {
                return text
            }

            let promptContext = PromptContext.from(
                context: activeContext,
                globalMemory: settings.globalMemoryEnabled ? settings.globalMemory : nil
            )

            let translated = try await translationProvider.translate(
                text: text,
                from: inputLanguage,
                to: targetLanguage,
                formality: promptContext.inferFormality(),
                context: promptContext
            )

            macLog("Translation complete to \(targetLanguage.displayName)", category: "Transcribe")
            return translated
        } catch {
            macLog("Translation failed: \(error)", category: "Transcribe", level: .warning)
            return text
        }
    }

    // MARK: - Enter Key Behavior Execution

    private func executeEnterKeyBehavior() async {
        // Default to .defaultNewLine when no context is selected (just insert, no send)
        let behavior = activeContext?.enterKeyBehavior ?? .defaultNewLine

        macLog("Executing enter behavior: \(behavior.displayName) (context: \(activeContext?.name ?? "none"))", category: "Transcribe")

        switch behavior {
        case .defaultNewLine:
            // Just insert the text (no send)
            macLog("Behavior: Insert only (no send)", category: "Transcribe")
            await insertText()

        case .formatThenInsert:
            // Already formatted above, just insert (no send)
            macLog("Behavior: Format + Insert (no send)", category: "Transcribe")
            await insertText()

        case .justSend:
            // Insert text and send (simulate Enter key)
            macLog("Behavior: Insert + Send", category: "Transcribe")
            await insertTextAndSend()

        case .formatAndSend:
            // Already formatted, insert and send
            macLog("Behavior: Format + Insert + Send", category: "Transcribe")
            await insertTextAndSend()
        }

        // Signal that insertion is complete - overlay should auto-close
        shouldAutoClose = true
    }

    // MARK: - Text Insertion

    /// Restore focus to the previous app before text insertion
    private func restoreFocusToPreviousApp() async {
        guard let app = previousApp else {
            macLog("No previous app to restore focus to", category: "Transcribe", level: .warning)
            return
        }

        macLog("Restoring focus to: \(app.localizedName ?? "unknown")", category: "Transcribe")
        app.activate()

        // Wait for app to become frontmost
        try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
    }

    func insertText() async {
        guard !transcribedText.isEmpty else { return }

        // Hide overlay before restoring focus (prevents focus stealing)
        onWillInsertText?()

        // Restore focus to previous app before inserting
        await restoreFocusToPreviousApp()

        if let textService = textInsertion {
            let result = await textService.insertText(transcribedText, replaceSelection: true)

            switch result {
            case .accessibilitySuccess, .clipboardFallback:
                macLog("Text inserted successfully", category: "Transcribe")
            case .failed(let error):
                macLog("Text insertion failed: \(error)", category: "Transcribe", level: .error)
            }
        }
    }

    private func insertTextAndSend() async {
        await insertText()

        // Wait for paste to complete, then simulate Enter key press
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

        macLog("Sending Enter key to target app...", category: "Transcribe")

        let source = CGEventSource(stateID: .hidSystemState)
        let enterDown = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true)  // Return key
        let enterUp = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false)

        // Clear all modifier flags to ensure plain Enter (not Cmd+Enter, etc.)
        enterDown?.flags = []
        enterUp?.flags = []

        enterDown?.post(tap: .cghidEventTap)
        enterUp?.post(tap: .cghidEventTap)

        macLog("Sent Enter key after text insertion", category: "Transcribe")
    }

    func copyToClipboard() {
        guard !transcribedText.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(transcribedText, forType: .string)

        macLog("Copied to clipboard", category: "Transcribe")
    }

    // MARK: - Context Management

    /// Cycle to next context: nil -> context1 -> context2 -> ... -> nil
    func cycleToNextContext() {
        let contexts = settings.contexts
        guard !contexts.isEmpty else { return }

        if let current = activeContext,
           let index = contexts.firstIndex(where: { $0.id == current.id }) {
            // If at last context, cycle back to nil (no context)
            if index == contexts.count - 1 {
                activeContext = nil
            } else {
                activeContext = contexts[index + 1]
            }
        } else {
            // No context selected, start with first context
            activeContext = contexts.first
        }

        // Apply context's language override
        if let ctx = activeContext, let lang = ctx.defaultInputLanguage {
            inputLanguage = lang
        } else {
            inputLanguage = settings.selectedDictationLanguage
        }
    }

    /// Cycle to previous context: nil -> contextN -> ... -> context1 -> nil
    func cycleToPreviousContext() {
        let contexts = settings.contexts
        guard !contexts.isEmpty else { return }

        if let current = activeContext,
           let index = contexts.firstIndex(where: { $0.id == current.id }) {
            // If at first context, cycle back to nil (no context)
            if index == 0 {
                activeContext = nil
            } else {
                activeContext = contexts[index - 1]
            }
        } else {
            // No context selected, start with last context
            activeContext = contexts.last
        }

        // Apply context's language override
        if let ctx = activeContext, let lang = ctx.defaultInputLanguage {
            inputLanguage = lang
        } else {
            inputLanguage = settings.selectedDictationLanguage
        }
    }

    func clearContext() {
        activeContext = nil
        inputLanguage = settings.selectedDictationLanguage
    }

    // MARK: - Translation Toggle

    func toggleTranslation() {
        isTranslationEnabled.toggle()
        settings.isTranslationEnabled = isTranslationEnabled
    }

    func cycleTargetLanguage() {
        let languages = Language.allCases
        if let index = languages.firstIndex(of: targetLanguage) {
            let nextIndex = (index + 1) % languages.count
            targetLanguage = languages[nextIndex]
            settings.selectedTargetLanguage = targetLanguage
        }
    }

    // MARK: - History

    private func saveToHistory(
        rawText: String,
        finalText: String,
        wasTranslated: Bool,
        didFormat: Bool,
        processingMetadata: ProcessingMetadata
    ) {
        // Calculate cost breakdown using shared BaseCostCalculator
        let costCalculator = BaseCostCalculator()
        let transcriptionProvider = settings.selectedTranscriptionProvider
        let translationProvider = wasTranslated ? settings.selectedTranslationProvider : nil

        // Use didFormat flag (actual formatting happened) instead of hasFormatting (would formatting happen)
        let formattingProvider = didFormat ? settings.selectedPowerModeProvider : nil
        let formattingModel = didFormat ? settings.selectedPowerModeProvider.defaultLLMModel : nil

        macLog("Saving to history - didFormat: \(didFormat), formattingProvider: \(formattingProvider?.displayName ?? "none"), formattingModel: \(formattingModel ?? "none")", category: "Transcribe")

        let costBreakdown = costCalculator.calculateCostBreakdown(
            transcriptionProvider: transcriptionProvider,
            transcriptionModel: transcriptionProvider.defaultTranscriptionModel,
            formattingProvider: formattingProvider,
            formattingModel: formattingModel,
            translationProvider: translationProvider,
            translationModel: translationProvider?.defaultLLMModel,
            durationSeconds: recordingDuration,
            textLength: finalText.count,
            text: finalText
        )

        macLog("Cost breakdown - transcription: $\(String(format: "%.6f", costBreakdown.transcriptionCost)), formatting: $\(String(format: "%.6f", costBreakdown.formattingCost)), total: $\(String(format: "%.6f", costBreakdown.total))", category: "Transcribe")
        macLog("Processing steps: \(processingMetadata.steps.map { "\($0.stepType.displayName) (\($0.provider.displayName))" })", category: "Transcribe")

        let record = TranscriptionRecord(
            rawTranscribedText: rawText,
            text: finalText,
            mode: didFormat ? .formal : .raw,  // Set mode based on whether formatting was applied
            provider: transcriptionProvider,
            duration: recordingDuration,
            translated: wasTranslated,
            targetLanguage: wasTranslated ? targetLanguage : nil,
            contextId: activeContext?.id,
            contextName: activeContext?.name,
            contextIcon: activeContext?.icon,
            costBreakdown: costBreakdown,
            processingMetadata: processingMetadata,
            source: .app,
            globalMemoryEnabled: settings.globalMemoryEnabled,
            contextMemoryEnabled: activeContext?.useContextMemory ?? false
        )
        settings.addToHistory(record)
        macLog("Saved transcription to history with cost: $\(String(format: "%.6f", costBreakdown.total))", category: "Transcribe")
    }

    // MARK: - Reset

    func reset() {
        state = .idle
        liveTranscript = ""
        transcribedText = ""
        recordingDuration = 0
        audioLevel = 0
        errorMessage = nil
    }
}
