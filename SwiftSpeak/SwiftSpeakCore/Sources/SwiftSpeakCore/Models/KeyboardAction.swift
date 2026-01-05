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

// MARK: - Keyboard Action Type

/// All possible actions that can be triggered from the keyboard
public enum KeyboardActionType: String, Codable, CaseIterable {
    case transcription = "transcription"      // Voice-to-text recording
    case edit = "edit"                        // Edit existing text via voice
    case aiProcess = "aiProcess"              // Process text with AI context/power mode
    case prediction = "prediction"            // AI sentence prediction
    case enableSwiftLink = "enableSwiftLink"  // Start SwiftLink background session

    public var displayName: String {
        switch self {
        case .transcription: return "Recording"
        case .edit: return "Editing"
        case .aiProcess: return "Processing"
        case .prediction: return "Predicting"
        case .enableSwiftLink: return "Enabling SwiftLink"
        }
    }

    public var processingMessage: String {
        switch self {
        case .transcription: return "Transcribing..."
        case .edit: return "Editing text..."
        case .aiProcess: return "Processing with AI..."
        case .prediction: return "Generating predictions..."
        case .enableSwiftLink: return "Starting SwiftLink..."
        }
    }

    public var completedMessage: String {
        switch self {
        case .transcription: return "Transcription complete"
        case .edit: return "Edit complete"
        case .aiProcess: return "Processing complete"
        case .prediction: return "Predictions ready"
        case .enableSwiftLink: return "SwiftLink active"
        }
    }

    public var icon: String {
        switch self {
        case .transcription: return "waveform"
        case .edit: return "pencil"
        case .aiProcess: return "sparkles"
        case .prediction: return "text.bubble"
        case .enableSwiftLink: return "link"
        }
    }

    /// Whether this action requires SwiftLink to be active
    public var requiresSwiftLink: Bool {
        switch self {
        case .enableSwiftLink: return false
        default: return true
        }
    }

    /// Whether this action should auto-return to source app after completion
    public var supportsAutoReturn: Bool {
        switch self {
        case .transcription, .edit, .aiProcess, .prediction: return true
        case .enableSwiftLink: return true  // Return after session started
        }
    }
}

// MARK: - Keyboard Action Status

/// Status of an ongoing keyboard action
public enum KeyboardActionStatus: String, Codable {
    case pending = "pending"          // Action queued, not started
    case starting = "starting"        // Setting up (e.g., starting SwiftLink)
    case recording = "recording"      // For transcription/edit: actively recording
    case processing = "processing"    // AI is processing
    case streaming = "streaming"      // Streaming results (if supported)
    case complete = "complete"        // Action finished successfully
    case error = "error"              // Action failed
    case cancelled = "cancelled"      // User cancelled

    public var isActive: Bool {
        switch self {
        case .pending, .starting, .recording, .processing, .streaming:
            return true
        case .complete, .error, .cancelled:
            return false
        }
    }

    public var shouldShowOverlay: Bool {
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
public struct KeyboardAction: Codable, Identifiable {
    public let id: UUID
    public let type: KeyboardActionType
    public let timestamp: Date

    // MARK: - Source App Info (for auto-return)

    /// URL scheme of the app to return to (e.g., "maps://", "whatsapp://")
    public var sourceAppURLScheme: String?

    /// Bundle ID of the source app (for tracking)
    public var sourceAppBundleId: String?

    /// Display name of the source app
    public var sourceAppName: String?

    /// Whether to automatically return to source app after completion
    public var autoReturnRequested: Bool

    // MARK: - Transcription Options

    /// Formatting mode for transcription
    public var formattingMode: FormattingMode?

    /// Whether to translate the transcription
    public var translateEnabled: Bool

    /// Target language for translation
    public var targetLanguage: Language?

    /// Custom template UUID (if using custom template)
    public var customTemplateId: UUID?

    // MARK: - Edit Mode Options

    /// Original text to be edited (for edit action)
    public var originalText: String?

    // MARK: - AI Process Options

    /// Text to process with AI (for aiProcess action)
    public var textToProcess: String?

    /// Context UUID to use for processing
    public var contextId: UUID?

    /// Context name (cached for display)
    public var contextName: String?

    /// Power mode UUID to use for processing
    public var powerModeId: UUID?

    /// Power mode name (cached for display)
    public var powerModeName: String?

    // MARK: - Prediction Options

    /// Typing context for prediction (last ~100 chars before cursor)
    public var typingContext: String?

    /// Active context name for prediction
    public var activeContextName: String?

    /// Active context ID for prediction
    public var activeContextId: UUID?

    // MARK: - Initializers

    public init(
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
    public static func transcription(
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
    public static func edit(
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
    public static func aiProcess(
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
    public static func prediction(
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
    public static func enableSwiftLink(
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
public struct KeyboardActionResult: Codable {
    public let actionId: UUID
    public let type: KeyboardActionType
    public let status: KeyboardActionStatus
    public let timestamp: Date

    /// The result text (transcription, edited text, AI output, etc.)
    public var resultText: String?

    /// For predictions: array of prediction strings
    public var predictions: [String]?

    /// Error message if status is .error
    public var errorMessage: String?

    /// Processing duration in seconds
    public var duration: TimeInterval?

    /// Cost breakdown if available
    public var estimatedCost: Double?

    public init(
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
    public var isSuccess: Bool {
        status == .complete && errorMessage == nil
    }
}
