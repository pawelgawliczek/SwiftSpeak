//
//  Context.swift
//  SwiftSpeak
//
//  Conversation context and memory models
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

// MARK: - Context Formality (Phase 4)

/// Explicit formality setting for translation providers
/// When set to .auto, formality is inferred from tone description
enum ContextFormality: String, Codable, CaseIterable, Identifiable {
    case auto = "auto"          // Infer from tone description
    case formal = "formal"      // Professional, respectful, business tone
    case informal = "informal"  // Casual, friendly, conversational
    case neutral = "neutral"    // No preference (provider default)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .formal: return "Formal"
        case .informal: return "Informal"
        case .neutral: return "Neutral"
        }
    }

    var description: String {
        switch self {
        case .auto: return "Automatically inferred from your tone description"
        case .formal: return "Professional and respectful language"
        case .informal: return "Casual and friendly language"
        case .neutral: return "Standard language, no preference"
        }
    }

    var icon: String {
        switch self {
        case .auto: return "sparkles"
        case .formal: return "briefcase.fill"
        case .informal: return "face.smiling.fill"
        case .neutral: return "equal.circle.fill"
        }
    }
}

// MARK: - Conversation Context (Phase 4)

/// A named context that customizes tone, language, and behavior
struct ConversationContext: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String                    // "Fatma", "Work", "Family"
    var icon: String                    // Emoji or SF Symbol
    var color: PowerModeColorPreset
    var description: String             // Short description for list view
    var toneDescription: String         // Detailed tone guidance for AI
    var formality: ContextFormality     // Explicit formality for translation (esp. DeepL)
    var languageHints: [Language]       // Expected languages in this context
    var customInstructions: String      // Injected into all prompts
    var memoryEnabled: Bool             // Context-level memory toggle
    var memory: String?                 // Stored memory for this context
    var lastMemoryUpdate: Date?
    var isActive: Bool                  // Currently selected context
    var appAssignment: AppAssignment    // Apps/categories that auto-enable this context
    var isPreset: Bool                  // Preset contexts available to all users (free tier)
    var aiAutocorrectEnabled: Bool      // Phase 13.11: AI autocorrection when processing text
    var enterSendsMessage: Bool         // Phase 13.11: Enter key sends/submits after inserting
    var enterRunsContext: Bool          // Phase 13.11: Enter key runs context AI processing before inserting
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        color: PowerModeColorPreset,
        description: String,
        toneDescription: String = "",
        formality: ContextFormality = .auto,
        languageHints: [Language] = [],
        customInstructions: String = "",
        memoryEnabled: Bool = false,
        memory: String? = nil,
        lastMemoryUpdate: Date? = nil,
        isActive: Bool = false,
        appAssignment: AppAssignment = AppAssignment(),
        isPreset: Bool = false,
        aiAutocorrectEnabled: Bool = false,
        enterSendsMessage: Bool = true,
        enterRunsContext: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.description = description
        self.toneDescription = toneDescription
        self.formality = formality
        self.languageHints = languageHints
        self.customInstructions = customInstructions
        self.memoryEnabled = memoryEnabled
        self.memory = memory
        self.lastMemoryUpdate = lastMemoryUpdate
        self.isActive = isActive
        self.appAssignment = appAssignment
        self.isPreset = isPreset
        self.aiAutocorrectEnabled = aiAutocorrectEnabled
        self.enterSendsMessage = enterSendsMessage
        self.enterRunsContext = enterRunsContext
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static var empty: ConversationContext {
        ConversationContext(
            name: "",
            icon: "person.circle",
            color: PowerModeColorPreset.blue,
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
                color: PowerModeColorPreset.blue,
                description: "Professional business communication",
                toneDescription: "Professional formatting with proper punctuation.",
                formality: ContextFormality.formal,
                customInstructions: "IMPORTANT: Preserve the exact wording and meaning. Only adjust formatting: use proper punctuation, capitalize appropriately. Do NOT rephrase, summarize, or change the content.",
                isPreset: true,
                aiAutocorrectEnabled: true  // Fixes grammar and punctuation
            ),
            ConversationContext(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                name: "Personal",
                icon: "😊",
                color: PowerModeColorPreset.green,
                description: "Casual, friendly conversations",
                toneDescription: "Casual and friendly formatting.",
                formality: ContextFormality.informal,
                customInstructions: "IMPORTANT: Preserve the exact wording and meaning. Only adjust formatting: use relaxed punctuation, add emoticons like 😊 🙂 👍 at the end of sentences. Do NOT rephrase, summarize, or change the content.",
                isPreset: true,
                aiAutocorrectEnabled: true  // Fixes grammar
            ),
            ConversationContext(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                name: "Creative",
                icon: "✨",
                color: PowerModeColorPreset.purple,
                description: "Creative writing and brainstorming",
                toneDescription: "Expressive formatting.",
                formality: ContextFormality.auto,
                customInstructions: "IMPORTANT: Preserve the exact wording and meaning. Only adjust formatting: use expressive punctuation (em dashes, ellipses). Do NOT rephrase, summarize, or change the content.",
                isPreset: true,
                aiAutocorrectEnabled: false  // No grammar changes - preserve creative intent
            )
        ]
    }

    /// Sample contexts for previews and mock-ups
    static var samples: [ConversationContext] {
        [
            ConversationContext(
                name: "Fatma",
                icon: "💕",
                color: PowerModeColorPreset.pink,
                description: "Casual, loving conversation with my wife",
                toneDescription: "Casual and loving. We often joke around and use pet names. She speaks Polish primarily but we mix in English words sometimes. Keep translations warm and natural.",
                formality: ContextFormality.informal,  // Explicitly informal for DeepL
                languageHints: [Language.polish, Language.english],
                customInstructions: "When translating to Polish, use informal \"ty\" form. Add endearments where appropriate.",
                memoryEnabled: true,
                memory: "Fatma mentioned she has a meeting on Tuesday afternoon. We're planning dinner for Friday. She prefers Italian food lately.",
                lastMemoryUpdate: Date().addingTimeInterval(-3600),
                isActive: true
            ),
            ConversationContext(
                name: "Work",
                icon: "💼",
                color: PowerModeColorPreset.blue,
                description: "Professional, formal business communication",
                toneDescription: "Professional and formal. Use proper business language and avoid casual expressions.",
                formality: ContextFormality.formal,  // Explicitly formal for DeepL
                languageHints: [Language.english],
                customInstructions: "Maintain professional tone. Use formal salutations and sign-offs in emails.",
                memoryEnabled: true,
                memory: "Last email was to client about project delay.",
                lastMemoryUpdate: Date().addingTimeInterval(-86400)
            ),
            ConversationContext(
                name: "Family",
                icon: "👨‍👩‍👧",
                color: PowerModeColorPreset.green,
                description: "Warm, friendly family conversations",
                toneDescription: "Warm and friendly. Family talks are casual but respectful.",
                formality: ContextFormality.auto,  // Auto-infer from tone description
                languageHints: [Language.polish],
                customInstructions: "Use familiar Polish expressions common in family settings."
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
