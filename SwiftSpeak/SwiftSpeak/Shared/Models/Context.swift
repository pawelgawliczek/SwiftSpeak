//
//  Context.swift
//  SwiftSpeak
//
//  Conversation context and memory models
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

// MARK: - Enter Key Behavior

/// What happens when Enter key is pressed in keyboard
enum EnterKeyBehavior: String, Codable, CaseIterable, Identifiable {
    case defaultNewLine = "newLine"       // Normal enter = new line
    case formatThenInsert = "format"      // Enter = format with context, then insert (don't send)
    case justSend = "send"                // Enter = just send (no formatting)
    case formatAndSend = "formatSend"     // Enter = format with context, insert, then send

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .defaultNewLine: return "New line"
        case .formatThenInsert: return "Format + insert"
        case .justSend: return "Send"
        case .formatAndSend: return "Format + send"
        }
    }

    var description: String {
        switch self {
        case .defaultNewLine: return "Enter creates a new line (default keyboard behavior)"
        case .formatThenInsert: return "Format text with this context, then insert it"
        case .justSend: return "Send the message immediately"
        case .formatAndSend: return "Format text with this context, insert, then send"
        }
    }

    var icon: String {
        switch self {
        case .defaultNewLine: return "return"
        case .formatThenInsert: return "text.badge.checkmark"
        case .justSend: return "paperplane"
        case .formatAndSend: return "paperplane.fill"
        }
    }
}

// MARK: - Formatting Instruction

/// A toggleable formatting instruction (chip)
/// Grouped by how invasive they are to the original text
struct FormattingInstruction: Codable, Identifiable, Hashable {
    let id: String
    let displayName: String
    let promptText: String
    let group: InstructionGroup
    let icon: String?

    enum InstructionGroup: String, Codable, CaseIterable {
        case lightTouch = "light"    // Preserves words: punctuation, capitals, spelling
        case grammar = "grammar"      // May adjust phrasing
        case style = "style"          // Will rephrase as needed
        case emoji = "emoji"          // Emoji usage level
    }

    /// All available formatting instructions
    static let all: [FormattingInstruction] = [
        // Light touch - preserves your words
        FormattingInstruction(
            id: "punctuation",
            displayName: "Punctuation",
            promptText: "Fix punctuation (periods, commas, apostrophes).",
            group: .lightTouch,
            icon: "textformat"
        ),
        FormattingInstruction(
            id: "capitals",
            displayName: "Capitals",
            promptText: "Fix capitalization (sentence starts, proper nouns).",
            group: .lightTouch,
            icon: "textformat.size"
        ),
        FormattingInstruction(
            id: "spelling",
            displayName: "Spelling",
            promptText: "Fix spelling mistakes.",
            group: .lightTouch,
            icon: "character.cursor.ibeam"
        ),

        // Grammar - may adjust phrasing
        FormattingInstruction(
            id: "grammar",
            displayName: "Grammar",
            promptText: "Fix grammar errors. You may slightly rephrase awkward constructions.",
            group: .grammar,
            icon: "text.badge.checkmark"
        ),

        // Style - will rephrase as needed
        FormattingInstruction(
            id: "casual",
            displayName: "Casual",
            promptText: "Use a casual, friendly tone. Rephrase to sound conversational.",
            group: .style,
            icon: "face.smiling"
        ),
        FormattingInstruction(
            id: "formal",
            displayName: "Formal",
            promptText: "Use a formal, professional tone. Rephrase to sound business-appropriate.",
            group: .style,
            icon: "briefcase"
        ),
        FormattingInstruction(
            id: "concise",
            displayName: "Concise",
            promptText: "Make it concise. Remove filler words and unnecessary phrases.",
            group: .style,
            icon: "arrow.down.right.and.arrow.up.left"
        ),
        FormattingInstruction(
            id: "bullets",
            displayName: "Bullets",
            promptText: "Format as bullet points where appropriate.",
            group: .style,
            icon: "list.bullet"
        ),

        // Emoji levels (mutually exclusive)
        FormattingInstruction(
            id: "emoji_never",
            displayName: "Never",
            promptText: "Do NOT add any emoji.",
            group: .emoji,
            icon: "xmark.circle"
        ),
        FormattingInstruction(
            id: "emoji_few",
            displayName: "Few",
            promptText: "Add emoji sparingly, only where they enhance the message.",
            group: .emoji,
            icon: "face.smiling"
        ),
        FormattingInstruction(
            id: "emoji_lots",
            displayName: "Lots",
            promptText: "Add emoji generously throughout the message.",
            group: .emoji,
            icon: "sparkles"
        )
    ]

    /// Get instructions by group
    static func instructions(for group: InstructionGroup) -> [FormattingInstruction] {
        all.filter { $0.group == group }
    }

    /// Get instruction by ID
    static func instruction(withId id: String) -> FormattingInstruction? {
        all.first { $0.id == id }
    }

    /// Group display info
    static func groupInfo(_ group: InstructionGroup) -> (title: String, subtitle: String, icon: String) {
        switch group {
        case .lightTouch:
            return ("Light touch", "Preserves your words", "📝")
        case .grammar:
            return ("Grammar", "May adjust phrasing", "✏️")
        case .style:
            return ("Style", "Will rephrase as needed", "🎨")
        case .emoji:
            return ("Emoji", "Emoji usage level", "😊")
        }
    }
}

// MARK: - Domain Jargon Type

/// Domain-specific vocabulary hints for transcription accuracy
/// When enabled, Whisper and other STT providers receive domain hints
/// to improve recognition of technical terminology
enum DomainJargon: String, Codable, CaseIterable, Identifiable {
    case none = "none"              // No specific domain
    case medical = "medical"        // Healthcare, pharmaceutical, clinical terms
    case legal = "legal"            // Law, contracts, litigation terminology
    case technical = "technical"    // Software, engineering, IT terms
    case financial = "financial"    // Banking, investment, accounting terms
    case scientific = "scientific"  // Research, laboratory, academic terms
    case business = "business"      // Corporate, management, strategy terms

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .medical: return "Medical"
        case .legal: return "Legal"
        case .technical: return "Technical"
        case .financial: return "Financial"
        case .scientific: return "Scientific"
        case .business: return "Business"
        }
    }

    var description: String {
        switch self {
        case .none: return "No domain-specific vocabulary hints"
        case .medical: return "Medical, pharmaceutical, and clinical terminology"
        case .legal: return "Legal, contracts, and litigation terminology"
        case .technical: return "Software, engineering, and IT terminology"
        case .financial: return "Banking, investment, and accounting terminology"
        case .scientific: return "Research, laboratory, and academic terminology"
        case .business: return "Corporate, management, and strategy terminology"
        }
    }

    var icon: String {
        switch self {
        case .none: return "text.bubble"
        case .medical: return "cross.case.fill"
        case .legal: return "building.columns.fill"
        case .technical: return "chevron.left.forwardslash.chevron.right"
        case .financial: return "chart.line.uptrend.xyaxis"
        case .scientific: return "atom"
        case .business: return "briefcase.fill"
        }
    }

    /// Whisper prompt hint for this domain
    /// Provides examples of expected vocabulary to improve recognition
    var transcriptionHint: String? {
        switch self {
        case .none:
            return nil
        case .medical:
            return "Medical terminology: diagnosis, prognosis, prescription, symptoms, treatment, dosage, mg, ml, patient, procedure, surgery, medication, chronic, acute"
        case .legal:
            return "Legal terminology: plaintiff, defendant, litigation, contract, clause, jurisdiction, statute, liability, damages, settlement, affidavit, deposition"
        case .technical:
            return "Technical terminology: API, SDK, database, server, deployment, repository, commit, merge, branch, function, variable, algorithm, framework"
        case .financial:
            return "Financial terminology: portfolio, equity, dividend, ROI, P&L, balance sheet, EBITDA, quarterly, fiscal, revenue, margin, valuation"
        case .scientific:
            return "Scientific terminology: hypothesis, methodology, analysis, data, experiment, results, conclusion, peer-reviewed, statistical, correlation"
        case .business:
            return "Business terminology: stakeholder, deliverable, KPI, roadmap, synergy, ROI, quarterly, strategy, initiative, metrics, pipeline"
        }
    }
}

// MARK: - Conversation Context

/// A named context that customizes formatting, memory, and keyboard behavior
struct ConversationContext: Codable, Identifiable, Equatable, Hashable {
    // MARK: - Identity
    let id: UUID
    var name: String                        // "Work", "Personal", "Family"
    var icon: String                        // Emoji or SF Symbol
    var color: PowerModeColorPreset
    var description: String                 // Short description for list view

    // MARK: - Transcription
    var domainJargon: DomainJargon          // Domain vocabulary hints for Whisper

    // MARK: - Formatting
    var examples: [String]                  // Few-shot examples (HIGHEST priority)
    var selectedInstructions: Set<String>   // IDs of selected formatting chips
    var customInstructions: String?         // Free-form additional instructions

    // MARK: - Memory
    var useGlobalMemory: Bool               // Include global memory in prompts
    var useContextMemory: Bool              // Include context-specific memory
    var contextMemory: String?              // The stored memory content
    var lastMemoryUpdate: Date?

    // MARK: - Keyboard Behavior
    var autoSendAfterInsert: Bool           // Auto-tap send after voice input
    var enterKeyBehavior: EnterKeyBehavior  // What Enter key does

    // MARK: - System
    var isActive: Bool                      // Currently selected context
    var appAssignment: AppAssignment        // Apps that auto-enable this context
    var isPreset: Bool                      // Preset contexts (free tier)
    let createdAt: Date
    var updatedAt: Date

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        color: PowerModeColorPreset,
        description: String,
        domainJargon: DomainJargon = .none,
        examples: [String] = [],
        selectedInstructions: Set<String> = [],
        customInstructions: String? = nil,
        useGlobalMemory: Bool = true,
        useContextMemory: Bool = false,
        contextMemory: String? = nil,
        lastMemoryUpdate: Date? = nil,
        autoSendAfterInsert: Bool = false,
        enterKeyBehavior: EnterKeyBehavior = .defaultNewLine,
        isActive: Bool = false,
        appAssignment: AppAssignment = AppAssignment(),
        isPreset: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.description = description
        self.domainJargon = domainJargon
        self.examples = examples
        self.selectedInstructions = selectedInstructions
        self.customInstructions = customInstructions
        self.useGlobalMemory = useGlobalMemory
        self.useContextMemory = useContextMemory
        self.contextMemory = contextMemory
        self.lastMemoryUpdate = lastMemoryUpdate
        self.autoSendAfterInsert = autoSendAfterInsert
        self.enterKeyBehavior = enterKeyBehavior
        self.isActive = isActive
        self.appAssignment = appAssignment
        self.isPreset = isPreset
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Computed Properties

    /// Whether any formatting is enabled (examples, instructions, or custom)
    var hasFormatting: Bool {
        !examples.isEmpty || !selectedInstructions.isEmpty ||
        (customInstructions?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    }

    /// Get the selected FormattingInstruction objects
    var formattingInstructions: [FormattingInstruction] {
        selectedInstructions.compactMap { FormattingInstruction.instruction(withId: $0) }
    }

    // MARK: - Static Properties

    static var empty: ConversationContext {
        ConversationContext(
            name: "",
            icon: "person.circle",
            color: .blue,
            description: ""
        )
    }

    /// Preset contexts available to ALL users (including free tier)
    /// These have fixed UUIDs so they can be identified consistently
    static var presets: [ConversationContext] {
        [
            ConversationContext(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                name: "Work",
                icon: "💼",
                color: .blue,
                description: "Professional business communication",
                domainJargon: .business,
                examples: [
                    "Hi John,\n\nThanks for the update. I'll review it by Friday.\n\nBest regards",
                    "Hi Sarah,\n\nCould we reschedule to 3pm? Let me know.\n\nBest regards"
                ],
                selectedInstructions: ["punctuation", "capitals", "grammar", "formal", "emoji_never"],
                useGlobalMemory: true,
                isPreset: true
            ),
            ConversationContext(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                name: "Personal",
                icon: "😊",
                color: .green,
                description: "Casual, friendly conversations",
                examples: [
                    "Hey! How's it going? 😊",
                    "Thanks for letting me know! See you soon 👍"
                ],
                selectedInstructions: ["punctuation", "grammar", "casual", "emoji_few"],
                useGlobalMemory: true,
                isPreset: true
            ),
            ConversationContext(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                name: "Creative",
                icon: "✨",
                color: .purple,
                description: "Creative writing and brainstorming",
                selectedInstructions: ["punctuation", "spelling"],
                customInstructions: "Preserve creative expression. Use expressive punctuation like em dashes and ellipses where appropriate.",
                useGlobalMemory: true,
                isPreset: true
            )
        ]
    }

    /// Sample contexts for previews and testing
    static var samples: [ConversationContext] {
        [
            ConversationContext(
                name: "Wife",
                icon: "💕",
                color: .pink,
                description: "Casual, loving messages",
                examples: [
                    "Hey love! 💕 Just thinking about you",
                    "Miss you! Can't wait to see you tonight 😘"
                ],
                selectedInstructions: ["punctuation", "casual", "emoji_lots"],
                useGlobalMemory: true,
                useContextMemory: true,
                contextMemory: "Planning dinner for Friday. She prefers Italian food.",
                lastMemoryUpdate: Date().addingTimeInterval(-3600),
                isActive: true
            ),
            ConversationContext(
                name: "Tech Lead",
                icon: "👨‍💻",
                color: .blue,
                description: "Technical discussions",
                domainJargon: .technical,
                selectedInstructions: ["punctuation", "capitals", "grammar", "formal", "concise", "emoji_never"],
                useGlobalMemory: true,
                useContextMemory: true,
                contextMemory: "Working on the API refactor project.",
                lastMemoryUpdate: Date().addingTimeInterval(-86400)
            )
        ]
    }
}

// MARK: - History Memory (Phase 4)

/// Global memory that stores user preferences and recent conversation summaries
struct HistoryMemory: Codable, Equatable {
    var summary: String
    var lastUpdated: Date
    var conversationCount: Int
    var recentTopics: [String]  // Last 5 topics for quick context

    init(
        summary: String = "",
        lastUpdated: Date = Date(),
        conversationCount: Int = 0,
        recentTopics: [String] = []
    ) {
        self.summary = summary
        self.lastUpdated = lastUpdated
        self.conversationCount = conversationCount
        self.recentTopics = recentTopics
    }

    /// Sample history memory for previews
    static var sample: HistoryMemory {
        HistoryMemory(
            summary: "User prefers formal English for work, casual Polish for family. Often discusses Swift programming and AI topics. Prefers concise responses.",
            lastUpdated: Date().addingTimeInterval(-7200),
            conversationCount: 47,
            recentTopics: ["Swift development", "AI news", "Family planning", "Work emails", "Polish translations"]
        )
    }
}
