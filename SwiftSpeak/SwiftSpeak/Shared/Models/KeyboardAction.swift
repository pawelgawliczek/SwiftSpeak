//
//  KeyboardAction.swift
//  SwiftSpeak
//
//  Unified keyboard-to-app action model
//  All keyboard actions (transcription, edit, AI, prediction, SwiftLink)
//  flow through this single model for consistent handling.
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation
import SwiftSpeakCore

// MARK: - Keyboard Action Type

/// All possible actions that can be triggered from the keyboard
enum KeyboardActionType: String, Codable, CaseIterable {
    case transcription = "transcription"      // Voice-to-text recording
    case edit = "edit"                        // Edit existing text via voice
    case aiProcess = "aiProcess"              // Process text with AI context/power mode
    case prediction = "prediction"            // AI sentence prediction
    case enableSwiftLink = "enableSwiftLink"  // Start SwiftLink background session

    var displayName: String {
        switch self {
        case .transcription: return "Recording"
        case .edit: return "Editing"
        case .aiProcess: return "Processing"
        case .prediction: return "Predicting"
        case .enableSwiftLink: return "Enabling SwiftLink"
        }
    }

    var processingMessage: String {
        switch self {
        case .transcription: return "Transcribing..."
        case .edit: return "Editing text..."
        case .aiProcess: return "Processing with AI..."
        case .prediction: return "Generating predictions..."
        case .enableSwiftLink: return "Starting SwiftLink..."
        }
    }

    var completedMessage: String {
        switch self {
        case .transcription: return "Transcription complete"
        case .edit: return "Edit complete"
        case .aiProcess: return "Processing complete"
        case .prediction: return "Predictions ready"
        case .enableSwiftLink: return "SwiftLink active"
        }
    }

    var icon: String {
        switch self {
        case .transcription: return "waveform"
        case .edit: return "pencil"
        case .aiProcess: return "sparkles"
        case .prediction: return "text.bubble"
        case .enableSwiftLink: return "link"
        }
    }

    /// Whether this action requires SwiftLink to be active
    var requiresSwiftLink: Bool {
        switch self {
        case .enableSwiftLink: return false
        default: return true
        }
    }

    /// Whether this action should auto-return to source app after completion
    var supportsAutoReturn: Bool {
        switch self {
        case .transcription, .edit, .aiProcess, .prediction: return true
        case .enableSwiftLink: return true  // Return after session started
        }
    }
}

// MARK: - Keyboard Action Status

/// Status of an ongoing keyboard action
enum KeyboardActionStatus: String, Codable {
    case pending = "pending"          // Action queued, not started
    case starting = "starting"        // Setting up (e.g., starting SwiftLink)
    case recording = "recording"      // For transcription/edit: actively recording
    case processing = "processing"    // AI is processing
    case streaming = "streaming"      // Streaming results (if supported)
    case complete = "complete"        // Action finished successfully
    case error = "error"              // Action failed
    case cancelled = "cancelled"      // User cancelled

    var isActive: Bool {
        switch self {
        case .pending, .starting, .recording, .processing, .streaming:
            return true
        case .complete, .error, .cancelled:
            return false
        }
    }

    var shouldShowOverlay: Bool {
        switch self {
        case .starting, .recording, .processing, .streaming:
            return true
        case .pending, .complete, .error, .cancelled:
            return false
        }
    }
}

// MARK: - Keyboard Action

/// Unified model for all keyboard-to-app actions
struct KeyboardAction: Codable, Identifiable {
    let id: UUID
    let type: KeyboardActionType
    let timestamp: Date

    // MARK: - Source App Info (for auto-return)

    /// URL scheme of the app to return to (e.g., "maps://", "whatsapp://")
    var sourceAppURLScheme: String?

    /// Bundle ID of the source app (for tracking)
    var sourceAppBundleId: String?

    /// Display name of the source app
    var sourceAppName: String?

    /// Whether to automatically return to source app after completion
    var autoReturnRequested: Bool

    // MARK: - Transcription Options

    /// Formatting mode for transcription
    var formattingMode: FormattingMode?

    /// Whether to translate the transcription
    var translateEnabled: Bool

    /// Target language for translation
    var targetLanguage: Language?

    /// Custom template UUID (if using custom template)
    var customTemplateId: UUID?

    // MARK: - Edit Mode Options

    /// Original text to be edited (for edit action)
    var originalText: String?

    // MARK: - AI Process Options

    /// Text to process with AI (for aiProcess action)
    var textToProcess: String?

    /// Context UUID to use for processing
    var contextId: UUID?

    /// Context name (cached for display)
    var contextName: String?

    /// Power mode UUID to use for processing
    var powerModeId: UUID?

    /// Power mode name (cached for display)
    var powerModeName: String?

    // MARK: - Prediction Options

    /// Typing context for prediction (last ~100 chars before cursor)
    var typingContext: String?

    /// Active context name for prediction
    var activeContextName: String?

    /// Active context ID for prediction
    var activeContextId: UUID?

    // MARK: - Initializers

    init(
        id: UUID = UUID(),
        type: KeyboardActionType,
        timestamp: Date = Date(),
        sourceAppURLScheme: String? = nil,
        sourceAppBundleId: String? = nil,
        sourceAppName: String? = nil,
        autoReturnRequested: Bool = true,
        formattingMode: FormattingMode? = nil,
        translateEnabled: Bool = false,
        targetLanguage: Language? = nil,
        customTemplateId: UUID? = nil,
        originalText: String? = nil,
        textToProcess: String? = nil,
        contextId: UUID? = nil,
        contextName: String? = nil,
        powerModeId: UUID? = nil,
        powerModeName: String? = nil,
        typingContext: String? = nil,
        activeContextName: String? = nil,
        activeContextId: UUID? = nil
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.sourceAppURLScheme = sourceAppURLScheme
        self.sourceAppBundleId = sourceAppBundleId
        self.sourceAppName = sourceAppName
        self.autoReturnRequested = autoReturnRequested
        self.formattingMode = formattingMode
        self.translateEnabled = translateEnabled
        self.targetLanguage = targetLanguage
        self.customTemplateId = customTemplateId
        self.originalText = originalText
        self.textToProcess = textToProcess
        self.contextId = contextId
        self.contextName = contextName
        self.powerModeId = powerModeId
        self.powerModeName = powerModeName
        self.typingContext = typingContext
        self.activeContextName = activeContextName
        self.activeContextId = activeContextId
    }

    // MARK: - Convenience Initializers

    /// Create a transcription action
    static func transcription(
        mode: FormattingMode,
        translate: Bool = false,
        targetLanguage: Language? = nil,
        customTemplateId: UUID? = nil,
        sourceApp: (urlScheme: String?, bundleId: String?, name: String?)? = nil,
        autoReturn: Bool = true
    ) -> KeyboardAction {
        KeyboardAction(
            type: .transcription,
            sourceAppURLScheme: sourceApp?.urlScheme,
            sourceAppBundleId: sourceApp?.bundleId,
            sourceAppName: sourceApp?.name,
            autoReturnRequested: autoReturn,
            formattingMode: mode,
            translateEnabled: translate,
            targetLanguage: targetLanguage,
            customTemplateId: customTemplateId
        )
    }

    /// Create an edit action
    static func edit(
        originalText: String,
        mode: FormattingMode? = nil,
        sourceApp: (urlScheme: String?, bundleId: String?, name: String?)? = nil,
        autoReturn: Bool = true
    ) -> KeyboardAction {
        KeyboardAction(
            type: .edit,
            sourceAppURLScheme: sourceApp?.urlScheme,
            sourceAppBundleId: sourceApp?.bundleId,
            sourceAppName: sourceApp?.name,
            autoReturnRequested: autoReturn,
            formattingMode: mode,
            originalText: originalText
        )
    }

    /// Create an AI process action
    static func aiProcess(
        text: String,
        contextId: UUID? = nil,
        contextName: String? = nil,
        powerModeId: UUID? = nil,
        powerModeName: String? = nil,
        translate: Bool = false,
        targetLanguage: Language? = nil,
        sourceApp: (urlScheme: String?, bundleId: String?, name: String?)? = nil,
        autoReturn: Bool = true
    ) -> KeyboardAction {
        KeyboardAction(
            type: .aiProcess,
            sourceAppURLScheme: sourceApp?.urlScheme,
            sourceAppBundleId: sourceApp?.bundleId,
            sourceAppName: sourceApp?.name,
            autoReturnRequested: autoReturn,
            translateEnabled: translate,
            targetLanguage: targetLanguage,
            textToProcess: text,
            contextId: contextId,
            contextName: contextName,
            powerModeId: powerModeId,
            powerModeName: powerModeName
        )
    }

    /// Create a prediction action
    static func prediction(
        typingContext: String,
        activeContextId: UUID? = nil,
        activeContextName: String? = nil,
        sourceApp: (urlScheme: String?, bundleId: String?, name: String?)? = nil,
        autoReturn: Bool = true
    ) -> KeyboardAction {
        KeyboardAction(
            type: .prediction,
            sourceAppURLScheme: sourceApp?.urlScheme,
            sourceAppBundleId: sourceApp?.bundleId,
            sourceAppName: sourceApp?.name,
            autoReturnRequested: autoReturn,
            typingContext: typingContext,
            activeContextName: activeContextName,
            activeContextId: activeContextId
        )
    }

    /// Create a SwiftLink enable action
    static func enableSwiftLink(
        sourceApp: (urlScheme: String?, bundleId: String?, name: String?)? = nil,
        autoReturn: Bool = true
    ) -> KeyboardAction {
        KeyboardAction(
            type: .enableSwiftLink,
            sourceAppURLScheme: sourceApp?.urlScheme,
            sourceAppBundleId: sourceApp?.bundleId,
            sourceAppName: sourceApp?.name,
            autoReturnRequested: autoReturn
        )
    }
}

// MARK: - Keyboard Action Result

/// Result of a completed keyboard action
struct KeyboardActionResult: Codable {
    let actionId: UUID
    let type: KeyboardActionType
    let status: KeyboardActionStatus
    let timestamp: Date

    /// The result text (transcription, edited text, AI output, etc.)
    var resultText: String?

    /// For predictions: array of prediction strings
    var predictions: [String]?

    /// Error message if status is .error
    var errorMessage: String?

    /// Processing duration in seconds
    var duration: TimeInterval?

    /// Cost breakdown if available
    var estimatedCost: Double?

    init(
        actionId: UUID,
        type: KeyboardActionType,
        status: KeyboardActionStatus,
        timestamp: Date = Date(),
        resultText: String? = nil,
        predictions: [String]? = nil,
        errorMessage: String? = nil,
        duration: TimeInterval? = nil,
        estimatedCost: Double? = nil
    ) {
        self.actionId = actionId
        self.type = type
        self.status = status
        self.timestamp = timestamp
        self.resultText = resultText
        self.predictions = predictions
        self.errorMessage = errorMessage
        self.duration = duration
        self.estimatedCost = estimatedCost
    }

    /// Whether the action completed successfully
    var isSuccess: Bool {
        status == .complete && errorMessage == nil
    }
}
