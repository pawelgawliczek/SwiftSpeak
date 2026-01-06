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

    // MARK: - Dependencies

    let settings: MacSettings
    private let audioRecorder: MacAudioRecorder
    private var providerFactory: ProviderFactory?
    private var textInsertion: MacTextInsertionService?

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

            // Start audio recording
            try await audioRecorder.startRecording()

            // Start timer to update duration
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.recordingDuration = self?.audioRecorder.duration ?? 0
                }
            }

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

    private func processRecording(audioURL: URL) async {
        guard let factory = providerFactory else {
            errorMessage = "Provider factory not configured"
            state = .error("Configuration error")
            return
        }

        state = .transcribing

        do {
            // Get transcription provider
            let selectedProvider = settings.selectedTranscriptionProvider
            macLog("Using transcription provider: \(selectedProvider.displayName)", category: "Transcribe")

            guard let transcriptionProvider = factory.createTranscriptionProvider(
                for: selectedProvider
            ) else {
                macLog("Failed to create provider \(selectedProvider.displayName) - API key missing?", category: "Transcribe", level: .error)
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

            var transcribedText = try await transcriptionProvider.transcribe(
                audioURL: audioURL,
                language: inputLanguage,
                promptHint: promptContext.buildTranscriptionHint()
            )

            // Apply vocabulary corrections
            transcribedText = settings.applyVocabulary(to: transcribedText)

            self.transcribedText = transcribedText
            macLog("Transcription complete: \(transcribedText.prefix(100))...", category: "Transcribe")

            // Apply formatting if context has formatting enabled
            if activeContext?.hasFormatting == true {
                state = .formatting
                transcribedText = try await formatTranscription(transcribedText)
                self.transcribedText = transcribedText
            }

            // Translate if enabled
            if isTranslationEnabled {
                state = .formatting
                transcribedText = try await translateText(transcribedText)
                self.transcribedText = transcribedText
            }

            state = .complete

            // Save to history
            saveToHistory(
                rawText: transcribedText,
                finalText: self.transcribedText,
                wasTranslated: isTranslationEnabled
            )

            // Execute the context's enter key behavior
            await executeEnterKeyBehavior()

        } catch {
            macLog("Processing failed: \(error)", category: "Transcribe", level: .error)
            errorMessage = error.localizedDescription
            state = .error(error.localizedDescription)
        }
    }

    private func formatTranscription(_ text: String) async throws -> String {
        guard let factory = providerFactory,
              let context = activeContext,
              context.hasFormatting else {
            return text
        }

        do {
            // Use Power Mode provider for formatting
            guard let formattingProvider = factory.createFormattingProvider(
                for: settings.selectedPowerModeProvider
            ) else {
                return text
            }

            // Build prompt context
            let promptContext = PromptContext.from(
                context: context,
                globalMemory: settings.globalMemoryEnabled ? settings.globalMemory : nil
            )

            // Get the formatting prompt from context
            guard let formattingPrompt = promptContext.buildFormattingPrompt() else {
                return text
            }

            let formatted = try await formattingProvider.format(
                text: text,
                mode: FormattingMode.raw,
                customPrompt: formattingPrompt,
                context: promptContext
            )

            macLog("Formatting complete", category: "Transcribe")
            return formatted
        } catch {
            macLog("Formatting failed: \(error)", category: "Transcribe", level: .warning)
            // Return original text if formatting fails
            return text
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
        let behavior = activeContext?.enterKeyBehavior ?? .defaultNewLine

        switch behavior {
        case .defaultNewLine:
            // Just insert the text
            await insertText()

        case .formatThenInsert:
            // Already formatted above, just insert
            await insertText()

        case .justSend:
            // Insert text and send (simulate Enter key)
            await insertTextAndSend()

        case .formatAndSend:
            // Already formatted, insert and send
            await insertTextAndSend()
        }
    }

    // MARK: - Text Insertion

    func insertText() async {
        guard !transcribedText.isEmpty else { return }

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

        // Simulate Enter key press
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let source = CGEventSource(stateID: .hidSystemState)
            let enterDown = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true)  // Return key
            let enterUp = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false)

            enterDown?.post(tap: .cghidEventTap)
            enterUp?.post(tap: .cghidEventTap)
        }
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

    private func saveToHistory(rawText: String, finalText: String, wasTranslated: Bool) {
        let record = TranscriptionRecord(
            rawTranscribedText: rawText,
            text: finalText,
            mode: FormattingMode.raw,
            provider: settings.selectedTranscriptionProvider,
            duration: recordingDuration,
            translated: wasTranslated,
            targetLanguage: wasTranslated ? targetLanguage : nil,
            contextId: activeContext?.id,
            contextName: activeContext?.name,
            contextIcon: activeContext?.icon,
            source: .app,
            globalMemoryEnabled: settings.globalMemoryEnabled,
            contextMemoryEnabled: activeContext?.useContextMemory ?? false
        )
        settings.addToHistory(record)
        macLog("Saved transcription to history", category: "Transcribe")
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
