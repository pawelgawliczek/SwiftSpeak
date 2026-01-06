//
//  PowerMode.swift
//  SwiftSpeak
//
//  Power Mode models and related types
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation
import SwiftSpeakCore
import SwiftUI

// MARK: - Power Mode Color Preset
enum PowerModeColorPreset: String, Codable, CaseIterable, Identifiable {
    case orange = "orange"
    case blue = "blue"
    case purple = "purple"
    case pink = "pink"
    case green = "green"
    case red = "red"
    case teal = "teal"
    case indigo = "indigo"
    case yellow = "yellow"
    case mint = "mint"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .orange: return .orange
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .green: return .green
        case .red: return .red
        case .teal: return .teal
        case .indigo: return .indigo
        case .yellow: return .yellow
        case .mint: return .mint
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .orange: return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .blue: return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .purple: return LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .pink: return LinearGradient(colors: [.pink, .red.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .green: return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .red: return LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .teal: return LinearGradient(colors: [.teal, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .indigo: return LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .yellow: return LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .mint: return LinearGradient(colors: [.mint, .green], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Power Mode
struct PowerMode: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var iconColor: PowerModeColorPreset
    var iconBackgroundColor: PowerModeColorPreset
    var instruction: String
    var outputFormat: String
    let createdAt: Date
    var updatedAt: Date
    var usageCount: Int

    // Phase 4: Memory support
    var memoryEnabled: Bool
    var memory: String?
    var memoryLimit: Int                    // Character limit (500-2000)
    var lastMemoryUpdate: Date?

    // Phase 4: Knowledge base document IDs (RAG)
    var knowledgeDocumentIds: [UUID]

    // Phase 4e: RAG configuration (per Power Mode)
    var ragConfiguration: RAGConfiguration

    // Phase 4: Archive support for swipe actions
    var isArchived: Bool

    // App auto-enable assignment
    var appAssignment: AppAssignment    // Apps/categories that auto-enable this power mode

    // Phase 4f: Enabled webhook IDs (global webhooks enabled for this Power Mode)
    var enabledWebhookIds: [UUID]

    // Phase 10: Provider override (nil = use global default)
    var providerOverride: ProviderSelection?

    // Phase 13.11: AI autocorrection when processing text
    var aiAutocorrectEnabled: Bool

    // Phase 13.11: Enter key behavior
    var enterSendsMessage: Bool         // Enter key sends/submits after inserting
    var enterRunsContext: Bool          // Enter key runs power mode AI processing before inserting

    // Obsidian Integration (Phase 3)
    var obsidianVaultIds: [UUID]           // Which vaults to query
    var includeWindowContext: Bool          // macOS: capture window text (DEPRECATED - use inputConfig)
    var maxObsidianChunks: Int              // 1-10, default 3
    var obsidianAction: ObsidianActionConfig?  // What to do with output (DEPRECATED - use outputConfig)

    // Input/Output Configuration (Phase 16)
    var inputConfig: PowerModeInputConfig
    var outputConfig: PowerModeOutputConfig

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "bolt.fill",
        iconColor: PowerModeColorPreset = .orange,
        iconBackgroundColor: PowerModeColorPreset = .orange,
        instruction: String = "",
        outputFormat: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        usageCount: Int = 0,
        memoryEnabled: Bool = false,
        memory: String? = nil,
        memoryLimit: Int = 2000,
        lastMemoryUpdate: Date? = nil,
        knowledgeDocumentIds: [UUID] = [],
        ragConfiguration: RAGConfiguration = .default,
        isArchived: Bool = false,
        appAssignment: AppAssignment = AppAssignment(),
        enabledWebhookIds: [UUID] = [],
        providerOverride: ProviderSelection? = nil,
        aiAutocorrectEnabled: Bool = false,
        enterSendsMessage: Bool = true,
        enterRunsContext: Bool = false,
        obsidianVaultIds: [UUID] = [],
        includeWindowContext: Bool = false,
        maxObsidianChunks: Int = 3,
        obsidianAction: ObsidianActionConfig? = nil,
        inputConfig: PowerModeInputConfig = .default,
        outputConfig: PowerModeOutputConfig = .default
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.iconColor = iconColor
        self.iconBackgroundColor = iconBackgroundColor
        self.instruction = instruction
        self.outputFormat = outputFormat
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.usageCount = usageCount
        self.memoryEnabled = memoryEnabled
        self.memory = memory
        self.memoryLimit = memoryLimit
        self.lastMemoryUpdate = lastMemoryUpdate
        self.knowledgeDocumentIds = knowledgeDocumentIds
        self.ragConfiguration = ragConfiguration
        self.isArchived = isArchived
        self.appAssignment = appAssignment
        self.enabledWebhookIds = enabledWebhookIds
        self.providerOverride = providerOverride
        self.aiAutocorrectEnabled = aiAutocorrectEnabled
        self.enterSendsMessage = enterSendsMessage
        self.enterRunsContext = enterRunsContext
        self.obsidianVaultIds = obsidianVaultIds
        self.includeWindowContext = includeWindowContext
        self.maxObsidianChunks = maxObsidianChunks
        self.obsidianAction = obsidianAction
        self.inputConfig = inputConfig
        self.outputConfig = outputConfig
    }

    /// Preset power modes for new users
    static let presets: [PowerMode] = [
        PowerMode(
            name: "Research Assistant",
            icon: "magnifyingglass.circle.fill",
            iconColor: .blue,
            iconBackgroundColor: .blue,
            instruction: """
            You are a research assistant. Help me find accurate, up-to-date information on the topic I describe.
            Cite sources when possible. Be thorough but concise.
            Focus on factual accuracy, recent developments, and multiple perspectives.
            """,
            outputFormat: "Use headers (##) for main topics. Include bullet points for key findings. Add a \"Sources\" section at the end."
        ),
        PowerMode(
            name: "Email Composer",
            icon: "envelope.fill",
            iconColor: .purple,
            iconBackgroundColor: .purple,
            instruction: """
            You are an email writing assistant. Help me compose professional emails based on my voice input.
            Understand the context and tone I want to convey. Ask clarifying questions if needed.
            """,
            outputFormat: "Format as a proper email with Subject line, greeting, body paragraphs, and professional sign-off."
        ),
        PowerMode(
            name: "Daily Planner",
            icon: "calendar",
            iconColor: .green,
            iconBackgroundColor: .green,
            instruction: """
            You are a daily planning assistant. Help me organize my day based on what I tell you.
            Consider priorities, time constraints, and suggest optimal scheduling.
            """,
            outputFormat: "Create a structured daily schedule with time blocks. Include priorities and any notes."
        ),
        PowerMode(
            name: "Idea Expander",
            icon: "lightbulb.fill",
            iconColor: .yellow,
            iconBackgroundColor: .yellow,
            instruction: """
            You are a creative brainstorming partner. Take my initial idea and help expand it.
            Explore different angles, potential challenges, and opportunities.
            """,
            outputFormat: "Start with the core idea summary, then list expansions, variations, and actionable next steps."
        )
    ]

    // MARK: - Codable (Backward Compatible)

    private enum CodingKeys: String, CodingKey {
        case id, name, icon, iconColor, iconBackgroundColor
        case instruction, outputFormat
        case createdAt, updatedAt, usageCount
        case memoryEnabled, memory, memoryLimit, lastMemoryUpdate
        case knowledgeDocumentIds, ragConfiguration
        case isArchived, appAssignment, enabledWebhookIds
        case providerOverride, aiAutocorrectEnabled
        case enterSendsMessage, enterRunsContext
        case obsidianVaultIds, includeWindowContext, maxObsidianChunks, obsidianAction
        case inputConfig, outputConfig
        // Legacy
        case systemPrompt  // Migrate to instruction
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "bolt.fill"
        iconColor = try container.decodeIfPresent(PowerModeColorPreset.self, forKey: .iconColor) ?? .orange
        iconBackgroundColor = try container.decodeIfPresent(PowerModeColorPreset.self, forKey: .iconBackgroundColor) ?? .orange

        // Migrate systemPrompt to instruction if present
        if let systemPrompt = try container.decodeIfPresent(String.self, forKey: .systemPrompt) {
            instruction = try container.decodeIfPresent(String.self, forKey: .instruction) ?? systemPrompt
        } else {
            instruction = try container.decodeIfPresent(String.self, forKey: .instruction) ?? ""
        }

        outputFormat = try container.decodeIfPresent(String.self, forKey: .outputFormat) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        usageCount = try container.decodeIfPresent(Int.self, forKey: .usageCount) ?? 0

        memoryEnabled = try container.decodeIfPresent(Bool.self, forKey: .memoryEnabled) ?? false
        memory = try container.decodeIfPresent(String.self, forKey: .memory)
        // Default memoryLimit for existing power modes without the field
        memoryLimit = try container.decodeIfPresent(Int.self, forKey: .memoryLimit) ?? 2000
        lastMemoryUpdate = try container.decodeIfPresent(Date.self, forKey: .lastMemoryUpdate)

        knowledgeDocumentIds = try container.decodeIfPresent([UUID].self, forKey: .knowledgeDocumentIds) ?? []
        ragConfiguration = try container.decodeIfPresent(RAGConfiguration.self, forKey: .ragConfiguration) ?? .default
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        appAssignment = try container.decodeIfPresent(AppAssignment.self, forKey: .appAssignment) ?? AppAssignment()
        enabledWebhookIds = try container.decodeIfPresent([UUID].self, forKey: .enabledWebhookIds) ?? []
        providerOverride = try container.decodeIfPresent(ProviderSelection.self, forKey: .providerOverride)
        aiAutocorrectEnabled = try container.decodeIfPresent(Bool.self, forKey: .aiAutocorrectEnabled) ?? false
        enterSendsMessage = try container.decodeIfPresent(Bool.self, forKey: .enterSendsMessage) ?? true
        enterRunsContext = try container.decodeIfPresent(Bool.self, forKey: .enterRunsContext) ?? false
        obsidianVaultIds = try container.decodeIfPresent([UUID].self, forKey: .obsidianVaultIds) ?? []
        includeWindowContext = try container.decodeIfPresent(Bool.self, forKey: .includeWindowContext) ?? false
        maxObsidianChunks = try container.decodeIfPresent(Int.self, forKey: .maxObsidianChunks) ?? 3
        obsidianAction = try container.decodeIfPresent(ObsidianActionConfig.self, forKey: .obsidianAction)

        // Input/Output config with migration from legacy fields
        if let inputCfg = try container.decodeIfPresent(PowerModeInputConfig.self, forKey: .inputConfig) {
            inputConfig = inputCfg
        } else {
            // Migrate from legacy fields
            var cfg = PowerModeInputConfig.default
            cfg.includePowerModeMemory = memoryEnabled
            cfg.includeRAGDocuments = !knowledgeDocumentIds.isEmpty
            cfg.includeObsidianVaults = !obsidianVaultIds.isEmpty
            cfg.includeActiveAppText = includeWindowContext
            inputConfig = cfg
        }

        if let outputCfg = try container.decodeIfPresent(PowerModeOutputConfig.self, forKey: .outputConfig) {
            outputConfig = outputCfg
        } else {
            // Migrate from legacy fields
            var cfg = PowerModeOutputConfig.default
            cfg.autoSendAfterInsert = enterSendsMessage
            cfg.webhookEnabled = !enabledWebhookIds.isEmpty
            cfg.webhookIds = enabledWebhookIds
            cfg.obsidianAction = obsidianAction
            outputConfig = cfg
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(icon, forKey: .icon)
        try container.encode(iconColor, forKey: .iconColor)
        try container.encode(iconBackgroundColor, forKey: .iconBackgroundColor)
        try container.encode(instruction, forKey: .instruction)
        try container.encode(outputFormat, forKey: .outputFormat)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(usageCount, forKey: .usageCount)
        try container.encode(memoryEnabled, forKey: .memoryEnabled)
        try container.encodeIfPresent(memory, forKey: .memory)
        try container.encode(memoryLimit, forKey: .memoryLimit)
        try container.encodeIfPresent(lastMemoryUpdate, forKey: .lastMemoryUpdate)
        try container.encode(knowledgeDocumentIds, forKey: .knowledgeDocumentIds)
        try container.encode(ragConfiguration, forKey: .ragConfiguration)
        try container.encode(isArchived, forKey: .isArchived)
        try container.encode(appAssignment, forKey: .appAssignment)
        try container.encode(enabledWebhookIds, forKey: .enabledWebhookIds)
        try container.encodeIfPresent(providerOverride, forKey: .providerOverride)
        try container.encode(aiAutocorrectEnabled, forKey: .aiAutocorrectEnabled)
        try container.encode(enterSendsMessage, forKey: .enterSendsMessage)
        try container.encode(enterRunsContext, forKey: .enterRunsContext)
        try container.encode(obsidianVaultIds, forKey: .obsidianVaultIds)
        try container.encode(includeWindowContext, forKey: .includeWindowContext)
        try container.encode(maxObsidianChunks, forKey: .maxObsidianChunks)
        try container.encodeIfPresent(obsidianAction, forKey: .obsidianAction)
        try container.encode(inputConfig, forKey: .inputConfig)
        try container.encode(outputConfig, forKey: .outputConfig)
    }
}

// MARK: - Power Mode Input Configuration

/// Configuration for what context sources to include in the Power Mode prompt
struct PowerModeInputConfig: Codable, Equatable, Hashable, Sendable {
    /// Include global memory in context
    var includeGlobalMemory: Bool

    /// Include power mode-specific memory
    var includePowerModeMemory: Bool

    /// Include RAG document embeddings
    var includeRAGDocuments: Bool

    /// Include Obsidian vault embeddings
    var includeObsidianVaults: Bool

    /// (macOS only) Include currently selected text
    var includeSelectedText: Bool

    /// (macOS only) Include text from active application window
    var includeActiveAppText: Bool

    /// (macOS only) Include text from clipboard
    var includeClipboard: Bool

    init(
        includeGlobalMemory: Bool = true,
        includePowerModeMemory: Bool = true,
        includeRAGDocuments: Bool = false,
        includeObsidianVaults: Bool = false,
        includeSelectedText: Bool = true,
        includeActiveAppText: Bool = false,
        includeClipboard: Bool = false
    ) {
        self.includeGlobalMemory = includeGlobalMemory
        self.includePowerModeMemory = includePowerModeMemory
        self.includeRAGDocuments = includeRAGDocuments
        self.includeObsidianVaults = includeObsidianVaults
        self.includeSelectedText = includeSelectedText
        self.includeActiveAppText = includeActiveAppText
        self.includeClipboard = includeClipboard
    }

    static let `default` = PowerModeInputConfig()
}

// MARK: - Power Mode Output Action

/// How to deliver the Power Mode output
enum PowerModeOutputAction: String, Codable, CaseIterable, Sendable {
    case clipboard              // Copy to clipboard only
    case clipboardAndTextField  // Copy to clipboard + insert in active text field
    case textFieldOnly          // Insert in active text field only

    var displayName: String {
        switch self {
        case .clipboard: return "Copy to Clipboard"
        case .clipboardAndTextField: return "Clipboard + Text Field"
        case .textFieldOnly: return "Text Field Only"
        }
    }

    var description: String {
        switch self {
        case .clipboard: return "Copies the result to your clipboard"
        case .clipboardAndTextField: return "Copies to clipboard and inserts at cursor"
        case .textFieldOnly: return "Inserts directly at cursor position"
        }
    }

    var icon: String {
        switch self {
        case .clipboard: return "doc.on.clipboard"
        case .clipboardAndTextField: return "doc.on.clipboard.fill"
        case .textFieldOnly: return "text.cursor"
        }
    }
}

// MARK: - Power Mode Output Configuration

/// Configuration for how to handle Power Mode output
struct PowerModeOutputConfig: Codable, Equatable, Hashable, Sendable {
    /// Primary output action (clipboard, text field, or both)
    var primaryAction: PowerModeOutputAction

    /// Auto-send after inserting (press Enter/Return)
    var autoSendAfterInsert: Bool

    /// Enable webhook output
    var webhookEnabled: Bool

    /// Webhook IDs to trigger (if webhookEnabled)
    var webhookIds: [UUID]

    /// Obsidian action configuration
    var obsidianAction: ObsidianActionConfig?

    init(
        primaryAction: PowerModeOutputAction = .clipboardAndTextField,
        autoSendAfterInsert: Bool = false,
        webhookEnabled: Bool = false,
        webhookIds: [UUID] = [],
        obsidianAction: ObsidianActionConfig? = nil
    ) {
        self.primaryAction = primaryAction
        self.autoSendAfterInsert = autoSendAfterInsert
        self.webhookEnabled = webhookEnabled
        self.webhookIds = webhookIds
        self.obsidianAction = obsidianAction
    }

    static let `default` = PowerModeOutputConfig()
}

// MARK: - Obsidian Action Configuration

struct ObsidianActionConfig: Codable, Equatable, Hashable, Sendable {
    var action: ObsidianAction
    var targetVaultId: UUID
    var targetNoteName: String?
    var autoExecute: Bool

    init(
        action: ObsidianAction,
        targetVaultId: UUID,
        targetNoteName: String? = nil,
        autoExecute: Bool = false
    ) {
        self.action = action
        self.targetVaultId = targetVaultId
        self.targetNoteName = targetNoteName
        self.autoExecute = autoExecute
    }
}

// MARK: - Obsidian Action

enum ObsidianAction: String, Codable, CaseIterable, Sendable {
    case appendToDaily     // Append to daily note
    case appendToNote      // Append to specific note
    case createNote        // Create new note
    case none              // No action

    var displayName: String {
        switch self {
        case .appendToDaily: return "Append to Daily Note"
        case .appendToNote: return "Append to Note"
        case .createNote: return "Create New Note"
        case .none: return "No Action"
        }
    }

    var icon: String {
        switch self {
        case .appendToDaily: return "calendar.badge.plus"
        case .appendToNote: return "doc.badge.plus"
        case .createNote: return "doc.fill.badge.plus"
        case .none: return "minus.circle"
        }
    }

    var description: String {
        switch self {
        case .appendToDaily: return "Add output to today's daily note"
        case .appendToNote: return "Add output to a specific note"
        case .createNote: return "Create a new note with the output"
        case .none: return "No automatic action"
        }
    }
}

// MARK: - Power Mode Question Option
struct PowerModeQuestionOption: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let description: String?
    let value: String

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        value: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.value = value ?? title
    }
}

// MARK: - Power Mode Question
struct PowerModeQuestion: Codable, Identifiable, Equatable {
    let id: UUID
    let questionText: String
    let options: [PowerModeQuestionOption]
    let allowFreeform: Bool

    init(
        id: UUID = UUID(),
        questionText: String,
        options: [PowerModeQuestionOption],
        allowFreeform: Bool = true
    ) {
        self.id = id
        self.questionText = questionText
        self.options = options
        self.allowFreeform = allowFreeform
    }

    /// Sample question for UI mockups
    static let sample = PowerModeQuestion(
        questionText: "What time period should I focus the research on?",
        options: [
            PowerModeQuestionOption(
                title: "Last 24 hours",
                description: "Most recent information and breaking news",
                value: "24h"
            ),
            PowerModeQuestionOption(
                title: "Last week",
                description: "Recent developments and trends",
                value: "week"
            ),
            PowerModeQuestionOption(
                title: "Last month",
                description: "Broader context and major stories",
                value: "month"
            ),
            PowerModeQuestionOption(
                title: "All time",
                description: "Comprehensive historical overview",
                value: "all"
            )
        ]
    )
}

// MARK: - Power Mode Result
struct PowerModeResult: Codable, Identifiable, Equatable {
    let id: UUID
    let powerModeId: UUID
    let powerModeName: String
    let userInput: String
    let markdownOutput: String
    let timestamp: Date
    let processingDuration: TimeInterval
    let versionNumber: Int

    // Phase 4: Track what context/memory was used
    var usedRAG: Bool
    var ragDocumentIds: [UUID]

    // Memory tracking - capture state for batch memory updates
    var globalMemoryEnabled: Bool
    var contextMemoryEnabled: Bool
    var powerModeMemoryEnabled: Bool
    var usedForGlobalMemory: Bool
    var usedForContextMemory: Bool
    var usedForPowerModeMemory: Bool

    init(
        id: UUID = UUID(),
        powerModeId: UUID,
        powerModeName: String,
        userInput: String,
        markdownOutput: String,
        timestamp: Date = Date(),
        processingDuration: TimeInterval = 0,
        versionNumber: Int = 1,
        usedRAG: Bool = false,
        ragDocumentIds: [UUID] = [],
        globalMemoryEnabled: Bool = false,
        contextMemoryEnabled: Bool = false,
        powerModeMemoryEnabled: Bool = false,
        usedForGlobalMemory: Bool = false,
        usedForContextMemory: Bool = false,
        usedForPowerModeMemory: Bool = false
    ) {
        self.id = id
        self.powerModeId = powerModeId
        self.powerModeName = powerModeName
        self.userInput = userInput
        self.markdownOutput = markdownOutput
        self.timestamp = timestamp
        self.processingDuration = processingDuration
        self.versionNumber = versionNumber
        self.usedRAG = usedRAG
        self.ragDocumentIds = ragDocumentIds
        self.globalMemoryEnabled = globalMemoryEnabled
        self.contextMemoryEnabled = contextMemoryEnabled
        self.powerModeMemoryEnabled = powerModeMemoryEnabled
        self.usedForGlobalMemory = usedForGlobalMemory
        self.usedForContextMemory = usedForContextMemory
        self.usedForPowerModeMemory = usedForPowerModeMemory
    }

    /// Sample result for UI mockups
    static let sample = PowerModeResult(
        powerModeId: UUID(),
        powerModeName: "Research Assistant",
        userInput: "Find me the latest news about artificial intelligence and summarize the key points",
        markdownOutput: """
        # AI News Summary - December 2024

        ## Key Developments

        - **OpenAI's Latest Release**: The company announced significant improvements to their reasoning models with enhanced capabilities for complex tasks.

        - **Google DeepMind**: New breakthroughs in protein folding prediction showing 95% accuracy.

        - **Anthropic Claude**: Released updated safety guidelines and constitutional AI improvements.

        ## Industry Trends

        1. Increased focus on AI safety and alignment
        2. Growing adoption in enterprise applications
        3. Regulatory frameworks taking shape globally

        ## Sources

        - TechCrunch: AI Weekly Roundup
        - MIT Technology Review
        - The Verge: AI Coverage
        """,
        processingDuration: 6.2
    )
}

// MARK: - Power Mode Session
struct PowerModeSession: Codable, Identifiable, Equatable {
    let id: UUID
    var results: [PowerModeResult]
    var currentVersionIndex: Int

    init(
        id: UUID = UUID(),
        results: [PowerModeResult] = [],
        currentVersionIndex: Int = 0
    ) {
        self.id = id
        self.results = results
        self.currentVersionIndex = results.isEmpty ? 0 : results.count - 1
    }

    var currentResult: PowerModeResult? {
        guard !results.isEmpty, currentVersionIndex < results.count else { return nil }
        return results[currentVersionIndex]
    }

    var hasMultipleVersions: Bool {
        results.count > 1
    }

    var canGoToPrevious: Bool {
        currentVersionIndex > 0
    }

    var canGoToNext: Bool {
        currentVersionIndex < results.count - 1
    }

    mutating func goToPrevious() {
        if canGoToPrevious {
            currentVersionIndex -= 1
        }
    }

    mutating func goToNext() {
        if canGoToNext {
            currentVersionIndex += 1
        }
    }

    mutating func addResult(_ result: PowerModeResult) {
        results.append(result)
        currentVersionIndex = results.count - 1
    }
}

// MARK: - Power Mode Execution State
enum PowerModeExecutionState: Equatable {
    case idle
    case recording
    case transcribing
    case thinking              // Building context, fetching webhooks
    case queryingKnowledge     // Phase 4: RAG query
    case askingQuestion(PowerModeQuestion)
    case generating            // LLM response (blocking mode)
    case streaming(String)     // LLM response (streaming mode) - partial text
    case complete(PowerModeSession)
    case error(String)

    var statusText: String {
        switch self {
        case .idle: return "Tap to speak"
        case .recording: return "Listening..."
        case .transcribing: return "Transcribing..."
        case .thinking: return "Thinking..."
        case .queryingKnowledge: return "Searching knowledge base..."
        case .askingQuestion: return "Question"
        case .generating: return "Generating..."
        case .streaming: return "Generating..."
        case .complete: return "Complete"
        case .error(let message): return message
        }
    }

    var isProcessing: Bool {
        switch self {
        case .transcribing, .thinking, .queryingKnowledge, .generating, .streaming:
            return true
        default:
            return false
        }
    }

    /// Whether this state represents active streaming
    var isStreaming: Bool {
        if case .streaming = self { return true }
        return false
    }

    /// Get partial text if in streaming state
    var streamingText: String? {
        if case .streaming(let text) = self { return text }
        return nil
    }
}
