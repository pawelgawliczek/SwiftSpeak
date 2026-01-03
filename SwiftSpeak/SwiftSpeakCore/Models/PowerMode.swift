//
//  PowerMode.swift
//  SwiftSpeak
//
//  Power Mode models and related types
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation
import SwiftUI

// MARK: - Power Mode Color Preset
public enum PowerModeColorPreset: String, Codable, CaseIterable, Identifiable {
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

    public var id: String { rawValue }

    public var color: Color {
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

    public var gradient: LinearGradient {
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

    public var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Power Mode
public struct PowerMode: Codable, Identifiable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    public var icon: String
    public var iconColor: PowerModeColorPreset
    public var iconBackgroundColor: PowerModeColorPreset
    public var instruction: String
    public var outputFormat: String
    public let createdAt: Date
    public var updatedAt: Date
    public var usageCount: Int

    // Phase 4: Memory support
    public var memoryEnabled: Bool
    public var memory: String?
    public var memoryLimit: Int                    // Character limit (500-2000)
    public var lastMemoryUpdate: Date?

    // Phase 4: Knowledge base document IDs (RAG)
    public var knowledgeDocumentIds: [UUID]

    // Phase 4e: RAG configuration (per Power Mode)
    public var ragConfiguration: RAGConfiguration

    // Phase 4: Archive support for swipe actions
    public var isArchived: Bool

    // App auto-enable assignment
    public var appAssignment: AppAssignment    // Apps/categories that auto-enable this power mode

    // Phase 4f: Enabled webhook IDs (global webhooks enabled for this Power Mode)
    public var enabledWebhookIds: [UUID]

    // Phase 10: Provider override (nil = use global default)
    public var providerOverride: ProviderSelection?

    // Phase 13.11: AI autocorrection when processing text
    public var aiAutocorrectEnabled: Bool

    // Phase 13.11: Enter key behavior
    public var enterSendsMessage: Bool         // Enter key sends/submits after inserting
    public var enterRunsContext: Bool          // Enter key runs power mode AI processing before inserting

    public init(
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
        enterRunsContext: Bool = false
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
    }

    /// Preset power modes for new users
    public static let presets: [PowerMode] = [
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
        // Legacy
        case systemPrompt  // Migrate to instruction
    }

    public init(from decoder: Decoder) throws {
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
    }

    public func encode(to encoder: Encoder) throws {
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
    }
}

// MARK: - Power Mode Question Option
public struct PowerModeQuestionOption: Codable, Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public let description: String?
    public let value: String

    public init(
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
public struct PowerModeQuestion: Codable, Identifiable, Equatable {
    public let id: UUID
    public let questionText: String
    public let options: [PowerModeQuestionOption]
    public let allowFreeform: Bool

    public init(
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
    public static let sample = PowerModeQuestion(
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
public struct PowerModeResult: Codable, Identifiable, Equatable {
    public let id: UUID
    public let powerModeId: UUID
    public let powerModeName: String
    public let userInput: String
    public let markdownOutput: String
    public let timestamp: Date
    public let processingDuration: TimeInterval
    public let versionNumber: Int

    // Phase 4: Track what context/memory was used
    public var usedRAG: Bool
    public var ragDocumentIds: [UUID]

    // Memory tracking - capture state for batch memory updates
    public var globalMemoryEnabled: Bool
    public var contextMemoryEnabled: Bool
    public var powerModeMemoryEnabled: Bool
    public var usedForGlobalMemory: Bool
    public var usedForContextMemory: Bool
    public var usedForPowerModeMemory: Bool

    public init(
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
    public static let sample = PowerModeResult(
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
public struct PowerModeSession: Codable, Identifiable, Equatable {
    public let id: UUID
    public var results: [PowerModeResult]
    public var currentVersionIndex: Int

    public init(
        id: UUID = UUID(),
        results: [PowerModeResult] = [],
        currentVersionIndex: Int = 0
    ) {
        self.id = id
        self.results = results
        self.currentVersionIndex = results.isEmpty ? 0 : results.count - 1
    }

    public var currentResult: PowerModeResult? {
        guard !results.isEmpty, currentVersionIndex < results.count else { return nil }
        return results[currentVersionIndex]
    }

    public var hasMultipleVersions: Bool {
        results.count > 1
    }

    public var canGoToPrevious: Bool {
        currentVersionIndex > 0
    }

    public var canGoToNext: Bool {
        currentVersionIndex < results.count - 1
    }

    public mutating func goToPrevious() {
        if canGoToPrevious {
            currentVersionIndex -= 1
        }
    }

    public mutating func goToNext() {
        if canGoToNext {
            currentVersionIndex += 1
        }
    }

    public mutating func addResult(_ result: PowerModeResult) {
        results.append(result)
        currentVersionIndex = results.count - 1
    }
}

// MARK: - Power Mode Execution State
public enum PowerModeExecutionState: Equatable {
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

    public var statusText: String {
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

    public var isProcessing: Bool {
        switch self {
        case .transcribing, .thinking, .queryingKnowledge, .generating, .streaming:
            return true
        default:
            return false
        }
    }

    /// Whether this state represents active streaming
    public var isStreaming: Bool {
        if case .streaming = self { return true }
        return false
    }

    /// Get partial text if in streaming state
    public var streamingText: String? {
        if case .streaming(let text) = self { return text }
        return nil
    }
}
