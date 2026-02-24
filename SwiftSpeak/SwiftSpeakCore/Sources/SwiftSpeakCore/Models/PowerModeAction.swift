//
//  PowerModeAction.swift
//  SwiftSpeakCore
//
//  Input and Output action types for Power Modes
//  Enables flexible context gathering and result delivery
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakMac targets
//

import Foundation

// MARK: - Input Action Type

/// Types of input actions that can gather context before Power Mode execution
public enum InputActionType: String, Codable, CaseIterable, Sendable {
    // Built-in context sources (unified from legacy Input Context)
    /// Include AI memory (Global, Context, Power Mode)
    case memory = "memory"
    /// Search RAG knowledge base documents
    case ragDocuments = "ragDocuments"
    /// Search Obsidian vault notes
    case obsidianVaults = "obsidianVaults"

    // Dynamic context sources
    /// Read current clipboard content
    case clipboard = "clipboard"
    /// Read selected text (macOS only via accessibility)
    case selectedText = "selectedText"
    /// Fetch and parse URL content
    case urlFetch = "urlFetch"
    /// User selects a file to include as context
    case filePicker = "filePicker"
    /// Run an Apple Shortcut and use its output as context
    case shortcutResult = "shortcutResult"
    /// Run a configured webhook (contextSource type) to fetch external data
    case webhook = "webhook"
    /// Capture screen content via OCR (iOS broadcast extension)
    case screenContext = "screenContext"
    /// Accept audio files via Share Extension
    case shareAudioImport = "shareAudioImport"
    /// Accept text content via Share Extension
    case shareTextImport = "shareTextImport"
    /// Accept images via Share Extension (OCR extraction)
    case shareImageImport = "shareImageImport"
    /// Accept URLs via Share Extension (web content fetch)
    case shareURLImport = "shareURLImport"
    /// Accept PDFs via Share Extension (text extraction)
    case sharePDFImport = "sharePDFImport"

    public var displayName: String {
        switch self {
        case .memory: return "Memory"
        case .ragDocuments: return "RAG Documents"
        case .obsidianVaults: return "Obsidian Vaults"
        case .clipboard: return "Clipboard"
        case .selectedText: return "Selected Text"
        case .urlFetch: return "Fetch URL"
        case .filePicker: return "Pick File"
        case .shortcutResult: return "Run Shortcut"
        case .webhook: return "Webhook"
        case .screenContext: return "Screen Context"
        case .shareAudioImport: return "Share Audio"
        case .shareTextImport: return "Share Text"
        case .shareImageImport: return "Share Image"
        case .shareURLImport: return "Share URL"
        case .sharePDFImport: return "Share PDF"
        }
    }

    public var description: String {
        switch self {
        case .memory: return "Include AI memory context"
        case .ragDocuments: return "Search knowledge base documents"
        case .obsidianVaults: return "Search connected Obsidian notes"
        case .clipboard: return "Read current clipboard content"
        case .selectedText: return "Read selected text from active app"
        case .urlFetch: return "Download and parse webpage content"
        case .filePicker: return "Select a file to include as context"
        case .shortcutResult: return "Run an Apple Shortcut and use its output"
        case .webhook: return "Fetch data from a configured webhook"
        case .screenContext: return "Capture text from your screen via OCR"
        case .shareAudioImport: return "Accept audio files shared from other apps"
        case .shareTextImport: return "Accept text content shared from other apps"
        case .shareImageImport: return "Accept images and extract text via OCR"
        case .shareURLImport: return "Accept URLs and fetch web content"
        case .sharePDFImport: return "Accept PDFs and extract text"
        }
    }

    public var icon: String {
        switch self {
        case .memory: return "brain.head.profile"
        case .ragDocuments: return "doc.text.magnifyingglass"
        case .obsidianVaults: return "note.text"
        case .clipboard: return "doc.on.clipboard"
        case .selectedText: return "text.cursor"
        case .urlFetch: return "globe"
        case .filePicker: return "doc"
        case .shortcutResult: return "apps.iphone"
        case .webhook: return "link"
        case .screenContext: return "text.viewfinder"
        case .shareAudioImport: return "waveform.badge.plus"
        case .shareTextImport: return "doc.text.fill"
        case .shareImageImport: return "photo.badge.plus"
        case .shareURLImport: return "link.badge.plus"
        case .sharePDFImport: return "doc.richtext.fill"
        }
    }

    /// Whether this action type is available on iOS
    public var availableOnIOS: Bool {
        switch self {
        case .selectedText: return false  // macOS only
        default: return true
        }
    }

    /// Whether this action type is available on macOS
    public var availableOnMacOS: Bool {
        // All share import types are available on both platforms
        return true
    }

    /// Whether this is a built-in context source (vs dynamic)
    public var isBuiltInSource: Bool {
        switch self {
        case .memory, .ragDocuments, .obsidianVaults:
            return true
        default:
            return false
        }
    }

    /// Whether this is a share import action type
    public var isShareImport: Bool {
        switch self {
        case .shareAudioImport, .shareTextImport, .shareImageImport, .shareURLImport, .sharePDFImport:
            return true
        default:
            return false
        }
    }

    /// Get the corresponding SharedContentType for share import actions
    public var sharedContentType: SharedContentType? {
        switch self {
        case .shareAudioImport: return .audio
        case .shareTextImport: return .text
        case .shareImageImport: return .image
        case .shareURLImport: return .url
        case .sharePDFImport: return .pdf
        default: return nil
        }
    }

    /// Get InputActionType for a given SharedContentType
    public static func shareImportAction(for contentType: SharedContentType) -> InputActionType {
        switch contentType {
        case .audio: return .shareAudioImport
        case .text: return .shareTextImport
        case .image: return .shareImageImport
        case .url: return .shareURLImport
        case .pdf: return .sharePDFImport
        }
    }
}

// MARK: - Output Action Type

/// Types of output actions that can deliver Power Mode results
public enum OutputActionType: String, Codable, CaseIterable, Sendable {
    // Primary output actions
    /// Copy result to clipboard
    case clipboard = "clipboard"
    /// Insert result at cursor position
    case insertAtCursor = "insertAtCursor"
    /// Insert result at cursor and send (press Enter) - macOS non-sandboxed only
    case insertAndSend = "insertAndSend"
    /// Save result to Obsidian vault
    case obsidianSave = "obsidianSave"

    // Integration actions
    /// Run an Apple Shortcut with the result as input
    case triggerShortcut = "triggerShortcut"
    /// Run a configured webhook (outputDestination/automationTrigger type)
    case webhook = "webhook"
    /// Show result as a system notification
    case notification = "notification"
    /// Speak the result aloud using text-to-speech
    case textToSpeech = "textToSpeech"
    /// Open the share sheet with the result
    case shareSheet = "shareSheet"
    /// Open a URL with the result as a parameter
    case openURL = "openURL"
    /// Chain to another Power Mode with the result as input
    case chainPowerMode = "chainPowerMode"

    public var displayName: String {
        switch self {
        case .clipboard: return "Copy to Clipboard"
        case .insertAtCursor: return "Insert at Cursor"
        case .insertAndSend: return "Insert & Send"
        case .obsidianSave: return "Save to Obsidian"
        case .triggerShortcut: return "Run Shortcut"
        case .webhook: return "Webhook"
        case .notification: return "Notification"
        case .textToSpeech: return "Text to Speech"
        case .shareSheet: return "Share"
        case .openURL: return "Open URL"
        case .chainPowerMode: return "Chain Power Mode"
        }
    }

    public var description: String {
        switch self {
        case .clipboard: return "Copy the result to clipboard"
        case .insertAtCursor: return "Paste result into current text field"
        case .insertAndSend: return "Insert and press Enter to send"
        case .obsidianSave: return "Save result to Obsidian vault"
        case .triggerShortcut: return "Pass result to an Apple Shortcut"
        case .webhook: return "Send result to a configured webhook"
        case .notification: return "Show result as a notification"
        case .textToSpeech: return "Read the result aloud"
        case .shareSheet: return "Open share sheet with result"
        case .openURL: return "Open a URL with result as parameter"
        case .chainPowerMode: return "Pass result to another Power Mode"
        }
    }

    public var icon: String {
        switch self {
        case .clipboard: return "doc.on.doc"
        case .insertAtCursor: return "keyboard"
        case .insertAndSend: return "paperplane.fill"
        case .obsidianSave: return "note.text"
        case .triggerShortcut: return "apps.iphone"
        case .webhook: return "link"
        case .notification: return "bell"
        case .textToSpeech: return "speaker.wave.2"
        case .shareSheet: return "square.and.arrow.up"
        case .openURL: return "globe"
        case .chainPowerMode: return "bolt.horizontal"
        }
    }

    /// Whether this action type is available on iOS
    public var availableOnIOS: Bool {
        switch self {
        case .insertAndSend: return false  // macOS non-sandboxed only
        default: return true
        }
    }

    /// Whether this action type is available on macOS
    public var availableOnMacOS: Bool {
        true  // All types available on macOS
    }

    /// Whether this action requires non-sandboxed macOS
    public var requiresNonSandboxed: Bool {
        switch self {
        case .insertAtCursor, .insertAndSend: return true
        default: return false
        }
    }

    /// Whether this is a primary output action
    public var isPrimaryAction: Bool {
        switch self {
        case .clipboard, .insertAtCursor, .insertAndSend, .obsidianSave:
            return true
        default:
            return false
        }
    }
}

// MARK: - Input Action

/// Represents a configured input action for a Power Mode
public struct InputAction: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var type: InputActionType
    public var isEnabled: Bool
    public var isRequired: Bool  // If true, failure stops Power Mode; if false, continues
    public var label: String     // User-facing name

    // Type-specific configuration
    public var urlToFetch: String?       // For urlFetch
    public var shortcutName: String?     // For shortcutResult
    public var waitForResult: Bool?      // For shortcutResult: true = wait, false = fire-and-forget
    public var fileTypes: [String]?      // For filePicker (UTType identifiers)
    public var webhookId: UUID?          // For webhook: references existing Webhook config

    // Memory action config
    public var includeGlobalMemory: Bool?      // For memory: include global AI memory
    public var includeContextMemory: Bool?     // For memory: include context-specific memory
    public var includePowerModeMemory: Bool?   // For memory: include Power Mode memory

    // RAG action config
    public var ragDocumentIds: [UUID]?         // For ragDocuments: specific documents to query
    public var ragSearchQuery: String?         // For ragDocuments: optional custom query

    // Obsidian input action config
    public var obsidianVaultIds: [UUID]?       // For obsidianVaults: vaults to search
    public var obsidianSearchQuery: String?    // For obsidianVaults: default search query
    public var obsidianMinSimilarity: Double?  // For obsidianVaults: minimum similarity (0.0-1.0)
    public var obsidianMaxResults: Int?        // For obsidianVaults: max notes to return

    public init(
        id: UUID = UUID(),
        type: InputActionType,
        isEnabled: Bool = true,
        isRequired: Bool = false,
        label: String? = nil,
        urlToFetch: String? = nil,
        shortcutName: String? = nil,
        waitForResult: Bool? = nil,
        fileTypes: [String]? = nil,
        webhookId: UUID? = nil,
        includeGlobalMemory: Bool? = nil,
        includeContextMemory: Bool? = nil,
        includePowerModeMemory: Bool? = nil,
        ragDocumentIds: [UUID]? = nil,
        ragSearchQuery: String? = nil,
        obsidianVaultIds: [UUID]? = nil,
        obsidianSearchQuery: String? = nil,
        obsidianMinSimilarity: Double? = nil,
        obsidianMaxResults: Int? = nil
    ) {
        self.id = id
        self.type = type
        self.isEnabled = isEnabled
        self.isRequired = isRequired
        self.label = label ?? type.displayName
        self.urlToFetch = urlToFetch
        self.shortcutName = shortcutName
        self.waitForResult = waitForResult
        self.fileTypes = fileTypes
        self.webhookId = webhookId
        self.includeGlobalMemory = includeGlobalMemory
        self.includeContextMemory = includeContextMemory
        self.includePowerModeMemory = includePowerModeMemory
        self.ragDocumentIds = ragDocumentIds
        self.ragSearchQuery = ragSearchQuery
        self.obsidianVaultIds = obsidianVaultIds
        self.obsidianSearchQuery = obsidianSearchQuery
        self.obsidianMinSimilarity = obsidianMinSimilarity
        self.obsidianMaxResults = obsidianMaxResults
    }

    /// Create a clipboard input action
    public static func clipboard(required: Bool = false) -> InputAction {
        InputAction(type: .clipboard, isRequired: required)
    }

    /// Create a URL fetch input action
    public static func urlFetch(url: String, required: Bool = false) -> InputAction {
        InputAction(type: .urlFetch, isRequired: required, urlToFetch: url)
    }

    /// Create a Shortcut input action
    public static func shortcut(name: String, waitForResult: Bool = true, required: Bool = false) -> InputAction {
        InputAction(
            type: .shortcutResult,
            isRequired: required,
            label: "Shortcut: \(name)",
            shortcutName: name,
            waitForResult: waitForResult
        )
    }

    /// Create a webhook input action
    public static func webhook(id: UUID, label: String, required: Bool = false) -> InputAction {
        InputAction(
            type: .webhook,
            isRequired: required,
            label: label,
            webhookId: id
        )
    }

    /// Create a memory input action
    public static func memory(
        includeGlobal: Bool = true,
        includeContext: Bool = true,
        includePowerMode: Bool = true,
        required: Bool = false
    ) -> InputAction {
        InputAction(
            type: .memory,
            isRequired: required,
            includeGlobalMemory: includeGlobal,
            includeContextMemory: includeContext,
            includePowerModeMemory: includePowerMode
        )
    }

    /// Create a RAG documents input action
    public static func ragDocuments(
        documentIds: [UUID]? = nil,
        searchQuery: String? = nil,
        required: Bool = false
    ) -> InputAction {
        InputAction(
            type: .ragDocuments,
            isRequired: required,
            ragDocumentIds: documentIds,
            ragSearchQuery: searchQuery
        )
    }

    /// Create an Obsidian vaults input action
    public static func obsidianVaults(
        vaultIds: [UUID]? = nil,
        searchQuery: String? = nil,
        minSimilarity: Double = 0.3,
        maxResults: Int = 5,
        required: Bool = false
    ) -> InputAction {
        InputAction(
            type: .obsidianVaults,
            isRequired: required,
            obsidianVaultIds: vaultIds,
            obsidianSearchQuery: searchQuery,
            obsidianMinSimilarity: minSimilarity,
            obsidianMaxResults: maxResults
        )
    }
}

// MARK: - Obsidian Save Action Type

/// How to save content to Obsidian
public enum ObsidianSaveAction: String, Codable, CaseIterable, Sendable {
    /// Append to the daily note
    case appendDaily = "appendDaily"
    /// Append to a specific note
    case appendNote = "appendNote"
    /// Create a new note
    case createNote = "createNote"

    public var displayName: String {
        switch self {
        case .appendDaily: return "Append to Daily Note"
        case .appendNote: return "Append to Note"
        case .createNote: return "Create New Note"
        }
    }

    public var description: String {
        switch self {
        case .appendDaily: return "Add to today's daily note"
        case .appendNote: return "Append to an existing note"
        case .createNote: return "Create a new note with the result"
        }
    }
}

// MARK: - Output Action

/// Represents a configured output action for a Power Mode
public struct OutputAction: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var type: OutputActionType
    public var isEnabled: Bool
    public var isRequired: Bool  // If true, failure stops remaining actions; if false, continues
    public var label: String     // User-facing name
    public var order: Int        // Execution order (1, 2, 3...)

    // Type-specific configuration
    public var shortcutName: String?        // For triggerShortcut
    public var waitForResult: Bool?         // For triggerShortcut: true = wait, false = fire-and-forget
    public var webhookId: UUID?             // For webhook: references existing Webhook config
    public var urlTemplate: String?         // For openURL (use {{output}} placeholder)
    public var chainedPowerModeId: UUID?    // For chainPowerMode
    public var notificationTitle: String?   // For notification
    public var speakVoice: String?          // For textToSpeech (voice identifier)

    // Obsidian save action config
    public var obsidianSaveAction: ObsidianSaveAction?  // How to save (daily/append/create)
    public var obsidianTargetVaultId: UUID?             // Which vault to save to
    public var obsidianTargetNoteName: String?          // Note name (for appendNote/createNote)
    public var obsidianAutoExecute: Bool?               // Execute without confirmation

    public init(
        id: UUID = UUID(),
        type: OutputActionType,
        isEnabled: Bool = true,
        isRequired: Bool = false,
        label: String? = nil,
        order: Int = 1,
        shortcutName: String? = nil,
        waitForResult: Bool? = nil,
        webhookId: UUID? = nil,
        urlTemplate: String? = nil,
        chainedPowerModeId: UUID? = nil,
        notificationTitle: String? = nil,
        speakVoice: String? = nil,
        obsidianSaveAction: ObsidianSaveAction? = nil,
        obsidianTargetVaultId: UUID? = nil,
        obsidianTargetNoteName: String? = nil,
        obsidianAutoExecute: Bool? = nil
    ) {
        self.id = id
        self.type = type
        self.isEnabled = isEnabled
        self.isRequired = isRequired
        self.label = label ?? type.displayName
        self.order = order
        self.shortcutName = shortcutName
        self.waitForResult = waitForResult
        self.webhookId = webhookId
        self.urlTemplate = urlTemplate
        self.chainedPowerModeId = chainedPowerModeId
        self.notificationTitle = notificationTitle
        self.speakVoice = speakVoice
        self.obsidianSaveAction = obsidianSaveAction
        self.obsidianTargetVaultId = obsidianTargetVaultId
        self.obsidianTargetNoteName = obsidianTargetNoteName
        self.obsidianAutoExecute = obsidianAutoExecute
    }

    /// Create a clipboard output action
    public static func clipboard(order: Int = 1, required: Bool = true) -> OutputAction {
        OutputAction(type: .clipboard, isRequired: required, order: order)
    }

    /// Create an insert at cursor output action
    public static func insertAtCursor(order: Int = 1, required: Bool = false) -> OutputAction {
        OutputAction(type: .insertAtCursor, isRequired: required, order: order)
    }

    /// Create a Shortcut output action
    public static func shortcut(name: String, order: Int, waitForResult: Bool = false, required: Bool = false) -> OutputAction {
        OutputAction(
            type: .triggerShortcut,
            isRequired: required,
            label: "Shortcut: \(name)",
            order: order,
            shortcutName: name,
            waitForResult: waitForResult
        )
    }

    /// Create a webhook output action
    public static func webhook(id: UUID, label: String, order: Int, required: Bool = false) -> OutputAction {
        OutputAction(
            type: .webhook,
            isRequired: required,
            label: label,
            order: order,
            webhookId: id
        )
    }

    /// Create a notification output action
    public static func notification(title: String, order: Int, required: Bool = false) -> OutputAction {
        OutputAction(
            type: .notification,
            isRequired: required,
            label: "Notification",
            order: order,
            notificationTitle: title
        )
    }

    /// Create a text-to-speech output action
    public static func textToSpeech(order: Int, voice: String? = nil, required: Bool = false) -> OutputAction {
        OutputAction(
            type: .textToSpeech,
            isRequired: required,
            order: order,
            speakVoice: voice
        )
    }

    /// Create a chain Power Mode output action
    public static func chainPowerMode(id: UUID, name: String, order: Int, required: Bool = false) -> OutputAction {
        OutputAction(
            type: .chainPowerMode,
            isRequired: required,
            label: "Chain: \(name)",
            order: order,
            chainedPowerModeId: id
        )
    }

    /// Create an Obsidian save output action
    public static func obsidianSave(
        order: Int,
        action: ObsidianSaveAction = .appendDaily,
        vaultId: UUID? = nil,
        noteName: String? = nil,
        autoExecute: Bool = false,
        required: Bool = false
    ) -> OutputAction {
        var label: String
        switch action {
        case .appendDaily:
            label = "Save to Daily Note"
        case .appendNote:
            label = "Save to \(noteName ?? "Note")"
        case .createNote:
            label = "Create \(noteName ?? "New Note")"
        }

        return OutputAction(
            type: .obsidianSave,
            isRequired: required,
            label: label,
            order: order,
            obsidianSaveAction: action,
            obsidianTargetVaultId: vaultId,
            obsidianTargetNoteName: noteName,
            obsidianAutoExecute: autoExecute
        )
    }
}

// MARK: - Action Result

/// Result from executing an input action
public struct InputActionResult: Codable, Identifiable, Sendable {
    public let id: UUID
    public let actionId: UUID
    public let actionType: InputActionType
    public let label: String
    public var content: String?
    public var error: String?
    public let executedAt: Date

    public var isSuccess: Bool {
        error == nil && content != nil
    }

    public init(
        id: UUID = UUID(),
        actionId: UUID,
        actionType: InputActionType,
        label: String,
        content: String? = nil,
        error: String? = nil,
        executedAt: Date = Date()
    ) {
        self.id = id
        self.actionId = actionId
        self.actionType = actionType
        self.label = label
        self.content = content
        self.error = error
        self.executedAt = executedAt
    }

    /// Create a successful result
    public static func success(action: InputAction, content: String) -> InputActionResult {
        InputActionResult(
            actionId: action.id,
            actionType: action.type,
            label: action.label,
            content: content
        )
    }

    /// Create a failed result
    public static func failure(action: InputAction, error: String) -> InputActionResult {
        InputActionResult(
            actionId: action.id,
            actionType: action.type,
            label: action.label,
            error: error
        )
    }
}

/// Result from executing an output action
public struct OutputActionResult: Codable, Identifiable, Sendable {
    public let id: UUID
    public let actionId: UUID
    public let actionType: OutputActionType
    public let label: String
    public var success: Bool
    public var error: String?
    public let executedAt: Date

    public init(
        id: UUID = UUID(),
        actionId: UUID,
        actionType: OutputActionType,
        label: String,
        success: Bool,
        error: String? = nil,
        executedAt: Date = Date()
    ) {
        self.id = id
        self.actionId = actionId
        self.actionType = actionType
        self.label = label
        self.success = success
        self.error = error
        self.executedAt = executedAt
    }

    /// Create a successful result
    public static func success(action: OutputAction) -> OutputActionResult {
        OutputActionResult(
            actionId: action.id,
            actionType: action.type,
            label: action.label,
            success: true
        )
    }

    /// Create a failed result
    public static func failure(action: OutputAction, error: String) -> OutputActionResult {
        OutputActionResult(
            actionId: action.id,
            actionType: action.type,
            label: action.label,
            success: false,
            error: error
        )
    }
}

// MARK: - Default Actions

public extension Array where Element == InputAction {
    /// Default input actions for a new Power Mode
    static var defaultActions: [InputAction] {
        []  // Empty by default, user adds as needed
    }
}

public extension Array where Element == OutputAction {
    /// Default output actions for a new Power Mode (clipboard copy)
    static var defaultActions: [OutputAction] {
        [
            .clipboard(order: 1, required: true)
        ]
    }
}

// MARK: - Quick Action (Autocomplete Suggestions)

/// Types of quick actions that generate autocomplete suggestions
public enum QuickActionType: String, Codable, CaseIterable, Sendable {
    /// Positive/agreeable response
    case positive = "positive"
    /// Neutral/balanced response
    case neutral = "neutral"
    /// Polite decline/disagreement
    case negative = "negative"
    /// Summarize the content
    case summarize = "summarize"
    /// Custom prompt (user-defined)
    case custom = "custom"

    public var displayName: String {
        switch self {
        case .positive: return "Positive Response"
        case .neutral: return "Neutral Response"
        case .negative: return "Decline Politely"
        case .summarize: return "Summarize"
        case .custom: return "Custom"
        }
    }

    public var description: String {
        switch self {
        case .positive: return "Generate an enthusiastic, agreeable reply"
        case .neutral: return "Generate a balanced, informational reply"
        case .negative: return "Generate a polite decline or disagreement"
        case .summarize: return "Summarize the screen content concisely"
        case .custom: return "Custom prompt for specific responses"
        }
    }

    public var icon: String {
        switch self {
        case .positive: return "hand.thumbsup.fill"
        case .neutral: return "hand.raised.fill"
        case .negative: return "hand.thumbsdown.fill"
        case .summarize: return "text.alignleft"
        case .custom: return "sparkles"
        }
    }

    public var color: String {
        switch self {
        case .positive: return "green"
        case .neutral: return "orange"
        case .negative: return "red"
        case .summarize: return "blue"
        case .custom: return "purple"
        }
    }

    /// Default prompt for this action type
    public var defaultPrompt: String {
        switch self {
        case .positive:
            return "Generate an enthusiastic and agreeable response that acknowledges the message positively."
        case .neutral:
            return "Generate a balanced, informational response that is neither overly positive nor negative."
        case .negative:
            return "Generate a polite but firm response that declines or expresses disagreement respectfully."
        case .summarize:
            return "Summarize the key points of this content in 1-2 concise sentences."
        case .custom:
            return ""
        }
    }
}

/// Represents a configured quick action (autocomplete suggestion) for a Power Mode
public struct QuickAction: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var type: QuickActionType
    public var isEnabled: Bool
    public var label: String         // User-facing name (short, for UI chip)
    public var prompt: String        // Custom prompt (overrides type default if set)
    public var order: Int            // Display order (0, 1, 2, ...)

    public init(
        id: UUID = UUID(),
        type: QuickActionType,
        isEnabled: Bool = true,
        label: String? = nil,
        prompt: String? = nil,
        order: Int = 0
    ) {
        self.id = id
        self.type = type
        self.isEnabled = isEnabled
        self.label = label ?? type.displayName
        self.prompt = prompt ?? type.defaultPrompt
        self.order = order
    }

    /// Get the effective prompt (custom if set, otherwise type default)
    public var effectivePrompt: String {
        prompt.isEmpty ? type.defaultPrompt : prompt
    }

    // MARK: - Convenience Initializers

    public static func positive(order: Int = 0, label: String? = nil) -> QuickAction {
        QuickAction(type: .positive, label: label, order: order)
    }

    public static func neutral(order: Int = 1, label: String? = nil) -> QuickAction {
        QuickAction(type: .neutral, label: label, order: order)
    }

    public static func negative(order: Int = 2, label: String? = nil) -> QuickAction {
        QuickAction(type: .negative, label: label, order: order)
    }

    public static func summarize(order: Int = 0, label: String? = nil) -> QuickAction {
        QuickAction(type: .summarize, label: label, order: order)
    }

    public static func custom(order: Int = 0, label: String, prompt: String) -> QuickAction {
        QuickAction(type: .custom, label: label, prompt: prompt, order: order)
    }
}

// MARK: - Default Quick Actions

public extension Array where Element == QuickAction {
    /// Default quick actions (positive, neutral, negative responses)
    static var defaultActions: [QuickAction] {
        [
            .positive(order: 0),
            .neutral(order: 1),
            .negative(order: 2)
        ]
    }

    /// Empty quick actions (disabled by default)
    static var empty: [QuickAction] {
        []
    }
}

// MARK: - Quick Suggestion (Generated Prediction)

/// A generated prediction/suggestion based on a QuickAction type
/// Used for displaying AI-generated suggestions in the keyboard and macOS overlay
public struct QuickSuggestion: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let type: QuickActionType
    public let text: String
    public let shortLabel: String

    public init(
        id: UUID = UUID(),
        type: QuickActionType,
        text: String,
        shortLabel: String? = nil
    ) {
        self.id = id
        self.type = type
        self.text = text
        self.shortLabel = shortLabel ?? type.displayName
    }
}
