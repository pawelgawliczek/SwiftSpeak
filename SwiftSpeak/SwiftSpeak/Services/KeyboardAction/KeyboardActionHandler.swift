//
//  KeyboardActionHandler.swift
//  SwiftSpeak
//
//  Unified handler for all keyboard-to-app actions.
//  This is the central coordinator that processes transcription, edit,
//  AI processing, prediction, and SwiftLink enablement requests.
//

import Foundation
import SwiftSpeakCore
import SwiftUI
import Combine

/// Central handler for all keyboard actions
@MainActor
final class KeyboardActionHandler: ObservableObject {

    // MARK: - Singleton

    static let shared = KeyboardActionHandler()

    // MARK: - Published State

    /// Current action being processed (nil if idle)
    @Published private(set) var currentAction: KeyboardAction?

    /// Current status of the action
    @Published private(set) var status: KeyboardActionStatus = .pending

    /// Whether an overlay should be shown
    @Published var showOverlay: Bool = false

    /// Status message for display
    @Published private(set) var statusMessage: String = ""

    /// Whether we're waiting to return to source app
    @Published private(set) var isReturning: Bool = false

    /// Error message if action failed
    @Published private(set) var errorMessage: String?

    /// Live streaming transcript (for transcription)
    @Published private(set) var streamingTranscript: String = ""

    // MARK: - Dependencies

    private let defaults: UserDefaults?
    private let darwinManager = DarwinNotificationManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var actionStartTime: Date?

    // MARK: - Initialization

    private init() {
        self.defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        setupObservers()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Listen for unified action requests from keyboard (new system)
        // This is the ONLY notification this handler observes.
        // Legacy notifications (startDictation, startEdit, startProcess, requestSentencePrediction)
        // are handled directly by SwiftLinkSessionManager to avoid duplicate processing.
        darwinManager.startObserving(name: Constants.KeyboardActionNotifications.requestAction) { [weak self] in
            Task { @MainActor in
                self?.handleActionRequest()
            }
        }
    }

    // MARK: - Public API

    /// Process an action received via URL scheme (swiftspeak://action)
    func handleURLAction() {
        guard let actionData = defaults?.data(forKey: Constants.KeyboardActionKeys.currentAction),
              let action = try? JSONDecoder().decode(KeyboardAction.self, from: actionData) else {
            appLog("No action data found in App Groups", category: "KeyboardAction", level: .error)
            return
        }

        processAction(action)
    }

    /// Manually trigger an action (for internal use)
    func processAction(_ action: KeyboardAction) {
        appLog("Processing action: \(action.type.rawValue)", category: "KeyboardAction")

        // Store action
        currentAction = action
        actionStartTime = Date()
        status = .starting
        statusMessage = action.type.processingMessage
        showOverlay = true
        errorMessage = nil
        streamingTranscript = ""

        // Acknowledge receipt
        darwinManager.post(name: Constants.KeyboardActionNotifications.actionAcknowledged)
        updateAppGroupsStatus(.starting)

        // Process based on type
        Task {
            await executeAction(action)
        }
    }

    /// Cancel the current action
    func cancelAction() {
        guard currentAction != nil else { return }

        appLog("Cancelling current action", category: "KeyboardAction")
        status = .cancelled
        updateAppGroupsStatus(.cancelled)
        darwinManager.post(name: Constants.KeyboardActionNotifications.actionComplete)

        cleanupAndDismiss()
    }

    // MARK: - Action Execution

    private func executeAction(_ action: KeyboardAction) async {
        do {
            // Ensure SwiftLink is active if needed
            if action.type.requiresSwiftLink {
                await ensureSwiftLinkActive()
            }

            // Update status
            status = action.type == .transcription || action.type == .edit ? .recording : .processing
            statusMessage = action.type.processingMessage
            updateAppGroupsStatus(status)
            darwinManager.post(name: Constants.KeyboardActionNotifications.statusChanged)

            // Execute the specific action
            switch action.type {
            case .transcription:
                await executeTranscription(action)
            case .edit:
                await executeEdit(action)
            case .aiProcess:
                await executeAIProcess(action)
            case .prediction:
                await executePrediction(action)
            case .enableSwiftLink:
                await executeEnableSwiftLink(action)
            }

        } catch {
            handleError(error)
        }
    }

    // MARK: - Transcription

    private func executeTranscription(_ action: KeyboardAction) async {
        appLog("Starting transcription via SwiftLink", category: "KeyboardAction")

        // Delegate to SwiftLinkSessionManager for actual recording
        // This integrates with existing recording infrastructure
        SwiftLinkSessionManager.shared.markDictationStart()

        // The recording is handled by SwiftLinkSessionManager
        // Results come back through existing flow
        // We just need to handle the auto-return when complete
    }

    // MARK: - Edit

    private func executeEdit(_ action: KeyboardAction) async {
        appLog("Starting edit mode", category: "KeyboardAction")

        guard let originalText = action.originalText else {
            handleError(KeyboardActionError.missingData("Original text not provided"))
            return
        }

        // Store original text for SwiftLink edit
        defaults?.set(originalText, forKey: Constants.EditMode.swiftLinkEditOriginalText)
        defaults?.set(true, forKey: Constants.EditMode.lastResultWasEdit)
        defaults?.synchronize()

        // Delegate to SwiftLinkSessionManager
        SwiftLinkSessionManager.shared.markEditStart()
    }

    // MARK: - AI Process

    private func executeAIProcess(_ action: KeyboardAction) async {
        appLog("Processing text with AI", category: "KeyboardAction")

        guard let text = action.textToProcess, !text.isEmpty else {
            handleError(KeyboardActionError.missingData("No text to process"))
            return
        }

        status = .processing
        statusMessage = "Processing with AI..."
        updateAppGroupsStatus(.processing)

        do {
            let result: String

            if let contextId = action.contextId {
                // Process with context
                result = try await processWithContext(text: text, contextId: contextId)
            } else if let powerModeId = action.powerModeId {
                // Process with power mode
                result = try await processWithPowerMode(text: text, powerModeId: powerModeId)
            } else if action.translateEnabled, let targetLang = action.targetLanguage {
                // Just translate
                result = try await translateText(text: text, to: targetLang)
            } else {
                // No processing needed, just return the text
                result = text
            }

            // Store result
            completeWithResult(result, for: action)

        } catch {
            handleError(error)
        }
    }

    private func processWithContext(text: String, contextId: UUID) async throws -> String {
        let settings = SharedSettings.shared

        guard let context = settings.contexts.first(where: { $0.id == contextId }) else {
            throw KeyboardActionError.contextNotFound
        }

        // Create provider factory and get formatting provider
        let providerFactory = ProviderFactory()
        guard let formattingProvider = providerFactory.createSelectedFormattingProvider() else {
            throw KeyboardActionError.providerNotConfigured
        }

        // Build context-aware prompt using customInstructions
        var fullPrompt = context.customInstructions ?? ""
        if fullPrompt.isEmpty {
            fullPrompt = "You are a helpful assistant."
        }

        // Add context memory if available
        if context.useContextMemory, let memory = context.contextMemory, !memory.isEmpty {
            fullPrompt += "\n\nContext memory:\n\(memory)"
        }

        // Use formatting provider to process
        return try await formattingProvider.format(text: text, mode: FormattingMode.raw, customPrompt: fullPrompt)
    }

    private func processWithPowerMode(text: String, powerModeId: UUID) async throws -> String {
        let settings = SharedSettings.shared

        guard let powerMode = settings.powerModes.first(where: { $0.id == powerModeId }) else {
            throw KeyboardActionError.powerModeNotFound
        }

        // Create provider factory and get formatting provider
        let providerFactory = ProviderFactory()
        guard let formattingProvider = providerFactory.createSelectedFormattingProvider() else {
            throw KeyboardActionError.providerNotConfigured
        }

        // Use the power mode's instruction
        var fullPrompt = powerMode.instruction
        if fullPrompt.isEmpty {
            fullPrompt = "You are a helpful assistant."
        }

        // Add power mode memory if available
        if powerMode.memoryEnabled, let memory = powerMode.memory, !memory.isEmpty {
            fullPrompt += "\n\nMemory:\n\(memory)"
        }

        return try await formattingProvider.format(text: text, mode: FormattingMode.raw, customPrompt: fullPrompt)
    }

    private func translateText(text: String, to language: Language) async throws -> String {
        let providerFactory = ProviderFactory()
        guard let provider = providerFactory.createSelectedTranslationProvider() else {
            throw KeyboardActionError.providerNotConfigured
        }
        return try await provider.translate(text: text, from: Language.english, to: language)
    }

    // MARK: - Prediction

    private func executePrediction(_ action: KeyboardAction) async {
        appLog("Generating predictions", category: "KeyboardAction")

        guard action.typingContext != nil else {
            handleError(KeyboardActionError.missingData("No typing context"))
            return
        }

        status = .processing
        statusMessage = "Generating predictions..."
        updateAppGroupsStatus(.processing)

        // Store typing context for SwiftLinkSessionManager to use
        if let context = action.typingContext {
            defaults?.set(context, forKey: Constants.SentencePrediction.context)
        }
        if let contextId = action.activeContextId {
            defaults?.set(contextId.uuidString, forKey: Constants.SentencePrediction.activeContextId)
        }
        if let contextName = action.activeContextName {
            defaults?.set(contextName, forKey: Constants.SentencePrediction.activeContextName)
        }
        defaults?.synchronize()

        // Delegate to SwiftLinkSessionManager which has the prediction logic
        SwiftLinkSessionManager.shared.handleSentencePredictionRequest()

        // The prediction result will come through the existing flow
        // Auto-return is handled separately
    }

    // MARK: - Enable SwiftLink

    private func executeEnableSwiftLink(_ action: KeyboardAction) async {
        appLog("Enabling SwiftLink session", category: "KeyboardAction")

        status = .processing
        statusMessage = "Starting SwiftLink..."
        updateAppGroupsStatus(.processing)

        await SwiftLinkSessionManager.shared.startBackgroundSession()

        // Complete and return
        status = .complete
        statusMessage = "SwiftLink active"
        updateAppGroupsStatus(.complete)

        // Auto-return after brief delay
        if action.autoReturnRequested {
            await autoReturnToSourceApp(action: action)
        }

        cleanupAndDismiss()
    }

    // MARK: - SwiftLink Management

    private func ensureSwiftLinkActive() async {
        let isActive = defaults?.bool(forKey: Constants.Keys.swiftLinkSessionActive) ?? false

        if !isActive {
            appLog("SwiftLink not active, starting session", category: "KeyboardAction")
            statusMessage = "Starting SwiftLink..."
            await SwiftLinkSessionManager.shared.startBackgroundSession()
        }
    }

    // MARK: - Result Handling

    private func completeWithResult(_ resultText: String, for action: KeyboardAction) {
        appLog("Action completed successfully", category: "KeyboardAction")

        status = .complete
        statusMessage = action.type.completedMessage
        updateAppGroupsStatus(.complete)

        // Store result
        let result = KeyboardActionResult(
            actionId: action.id,
            type: action.type,
            status: .complete,
            resultText: resultText,
            duration: actionStartTime.map { Date().timeIntervalSince($0) }
        )

        if let resultData = try? JSONEncoder().encode(result) {
            defaults?.set(resultData, forKey: Constants.KeyboardActionKeys.result)
            defaults?.synchronize()
        }

        // Notify keyboard
        darwinManager.post(name: Constants.KeyboardActionNotifications.actionComplete)

        // Also post legacy notification for backward compatibility
        switch action.type {
        case .aiProcess:
            defaults?.set(resultText, forKey: Constants.AIProcess.result)
            defaults?.set("complete", forKey: Constants.AIProcess.status)
            darwinManager.post(name: Constants.AIProcess.resultReady)
        case .prediction:
            // Prediction results handled by SwiftLinkSessionManager
            break
        default:
            break
        }

        // Auto-return if requested
        if action.autoReturnRequested {
            Task {
                await autoReturnToSourceApp(action: action)
            }
        } else {
            cleanupAndDismiss()
        }
    }

    // MARK: - Auto-Return

    private func autoReturnToSourceApp(action: KeyboardAction) async {
        guard let urlScheme = action.sourceAppURLScheme, !urlScheme.isEmpty else {
            appLog("No source app URL scheme, skipping auto-return", category: "KeyboardAction")
            cleanupAndDismiss()
            return
        }

        isReturning = true
        statusMessage = "Returning to app..."

        // Brief delay for user feedback
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s

        // Construct URL
        var urlString = urlScheme
        if !urlString.contains("://") {
            urlString = "\(urlScheme)://"
        }

        if let url = URL(string: urlString) {
            appLog("Auto-returning to: \(urlString)", category: "KeyboardAction")
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    appLog("Failed to open source app URL", category: "KeyboardAction", level: .error)
                }
            }
        }

        // Cleanup after return
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        cleanupAndDismiss()
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        appLog("Action error: \(error.localizedDescription)", category: "KeyboardAction", level: .error)

        status = .error
        errorMessage = error.localizedDescription
        statusMessage = "Error: \(error.localizedDescription)"
        updateAppGroupsStatus(.error, errorMessage: error.localizedDescription)

        darwinManager.post(name: Constants.KeyboardActionNotifications.actionComplete)

        // Keep overlay visible for error display
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.cleanupAndDismiss()
        }
    }

    // MARK: - Cleanup

    private func cleanupAndDismiss() {
        showOverlay = false
        isReturning = false
        currentAction = nil
        errorMessage = nil
        streamingTranscript = ""
    }

    // MARK: - App Groups Updates

    private func updateAppGroupsStatus(_ status: KeyboardActionStatus, errorMessage: String? = nil) {
        defaults?.set(status.rawValue, forKey: Constants.KeyboardActionKeys.status)
        defaults?.set(Date().timeIntervalSince1970, forKey: Constants.KeyboardActionKeys.lastUpdate)
        if let error = errorMessage {
            defaults?.set(error, forKey: Constants.KeyboardActionKeys.error)
        }
        defaults?.synchronize()
    }

    // MARK: - Unified Action Request Handler

    private func handleActionRequest() {
        appLog("Action request notification received", category: "KeyboardAction")
        handleURLAction()
    }
}

// MARK: - Keyboard Action Errors

enum KeyboardActionError: LocalizedError {
    case missingData(String)
    case contextNotFound
    case powerModeNotFound
    case providerNotConfigured
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingData(let detail):
            return "Missing data: \(detail)"
        case .contextNotFound:
            return "Context not found"
        case .powerModeNotFound:
            return "Power Mode not found"
        case .providerNotConfigured:
            return "AI provider not configured"
        case .processingFailed(let reason):
            return "Processing failed: \(reason)"
        }
    }
}
