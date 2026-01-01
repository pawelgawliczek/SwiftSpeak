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
        ragDocumentIds: [UUID] = []
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
