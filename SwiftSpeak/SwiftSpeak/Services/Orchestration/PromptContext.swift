//
//  PromptContext.swift
//  SwiftSpeak
//
//  Universal context injection for all AI providers.
//  Builds context-aware prompts with 3-tier memory system.
//

import Foundation

// MARK: - Formality Level

/// Formality level for translation providers
/// Maps to provider-specific parameters (e.g., DeepL's formality)
enum Formality: String, Codable, CaseIterable {
    case formal     // Professional, respectful, business tone
    case informal   // Casual, friendly, conversational
    case neutral    // No preference (provider default)

    /// DeepL API formality parameter
    var deepLValue: String {
        switch self {
        case .formal: return "prefer_more"
        case .informal: return "prefer_less"
        case .neutral: return "default"
        }
    }
}

// MARK: - Memory Tier

/// Memory tier for the 3-tier memory system
enum MemoryTier: String {
    case global     // Always injected (if enabled)
    case context    // Injected when specific context is active
    case powerMode  // Injected only during Power Mode execution
}

// MARK: - Prompt Context

/// Builds context-aware prompts for all AI providers
/// Implements the universal XML-based prompt structure
struct PromptContext {

    // MARK: - Memory Properties

    /// Global memory - always injected if present
    let globalMemory: String?

    /// Context-specific memory
    let contextMemory: String?
    let contextName: String?

    /// Power Mode memory (only for Power Mode operations)
    let powerModeMemory: String?
    let powerModeName: String?

    // MARK: - Style Properties

    /// Tone description (HOW to express)
    let toneDescription: String?

    /// Explicit formality setting from context (nil = auto-infer)
    let explicitFormality: ContextFormality?

    /// Custom instructions (WHAT rules to follow)
    let customInstructions: String?

    // MARK: - Language Properties

    /// Language hints for transcription accuracy
    let languageHints: [Language]

    /// Vocabulary words for transcription hints
    let vocabularyWords: [String]

    /// Domain-specific jargon type for transcription accuracy
    let domainJargon: DomainJargon

    // MARK: - Initialization

    init(
        globalMemory: String? = nil,
        contextMemory: String? = nil,
        contextName: String? = nil,
        powerModeMemory: String? = nil,
        powerModeName: String? = nil,
        toneDescription: String? = nil,
        explicitFormality: ContextFormality? = nil,
        customInstructions: String? = nil,
        languageHints: [Language] = [],
        vocabularyWords: [String] = [],
        domainJargon: DomainJargon = .none
    ) {
        self.globalMemory = globalMemory
        self.contextMemory = contextMemory
        self.contextName = contextName
        self.powerModeMemory = powerModeMemory
        self.powerModeName = powerModeName
        self.toneDescription = toneDescription
        self.explicitFormality = explicitFormality
        self.customInstructions = customInstructions
        self.languageHints = languageHints
        self.vocabularyWords = vocabularyWords
        self.domainJargon = domainJargon
    }

    // MARK: - Factory Methods

    /// Create PromptContext from current settings and active context
    /// - Parameters:
    ///   - settings: Shared settings containing global memory and vocabulary
    ///   - context: Active conversation context (if any)
    ///   - powerMode: Active power mode (if in Power Mode)
    /// - Returns: Configured PromptContext
    static func from(
        settings: SharedSettings,
        context: ConversationContext?,
        powerMode: PowerMode? = nil
    ) -> PromptContext {
        // Collect vocabulary words for transcription hints
        let vocabWords = settings.vocabularyEntries
            .filter { $0.isEnabled }
            .map { $0.replacementWord }

        // Capture explicit formality if not auto
        let formality: ContextFormality? = {
            guard let ctx = context else { return nil }
            return ctx.formality == .auto ? nil : ctx.formality
        }()

        return PromptContext(
            globalMemory: settings.globalMemoryEnabled ? settings.globalMemory : nil,
            contextMemory: context?.memoryEnabled == true ? context?.memory : nil,
            contextName: context?.name,
            powerModeMemory: powerMode?.memoryEnabled == true ? powerMode?.memory : nil,
            powerModeName: powerMode?.name,
            toneDescription: context?.toneDescription,
            explicitFormality: formality,
            customInstructions: context?.customInstructions,
            languageHints: context?.languageHints ?? [],
            vocabularyWords: vocabWords,
            domainJargon: context?.domainJargon ?? .none
        )
    }

    /// Create an empty context (no memory, no tone, no instructions)
    static var empty: PromptContext {
        PromptContext()
    }

    // MARK: - Prompt Building

    /// Build the complete system prompt for LLM providers
    /// Uses XML structure for maximum clarity and robustness
    /// - Parameter task: The main task/instruction (e.g., formatting mode prompt)
    /// - Returns: Complete system prompt with context
    func buildSystemPrompt(task: String) -> String {
        var sections: [String] = []

        // 1. Context section (memory + tone)
        let contextSection = buildContextSection()
        if !contextSection.isEmpty {
            sections.append(contextSection)
        }

        // 2. Task section
        sections.append("<task>\n\(task.indented(by: 2))\n</task>")

        // 3. Guidelines section
        if let instructions = customInstructions, !instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("<guidelines>\n\(instructions.indented(by: 2))\n</guidelines>")
        }

        return sections.joined(separator: "\n\n")
    }

    /// Build the system prompt for translation
    /// - Parameters:
    ///   - targetLanguage: Target language for translation
    ///   - sourceLanguage: Source language (nil for auto-detect)
    /// - Returns: Translation system prompt
    func buildTranslationPrompt(to targetLanguage: Language, from sourceLanguage: Language? = nil) -> String {
        var task = "Translate the following text to \(targetLanguage.displayName)."

        if let source = sourceLanguage {
            task += " The source language is \(source.displayName)."
        }

        task += "\nPreserve the original meaning and intent."
        task += "\nOutput only the translated text, no explanations."

        return buildSystemPrompt(task: task)
    }

    /// Build transcription hint for STT providers (Whisper, etc.)
    /// - Returns: Hint string for transcription, or nil if no hints available
    func buildTranscriptionHint() -> String? {
        var hints: [String] = []

        // Domain-specific jargon (provides terminology context)
        if domainJargon != .none, let domainHint = domainJargon.transcriptionHint {
            hints.append(domainHint)
        }

        // Language hints
        if !languageHints.isEmpty {
            let languages = languageHints.map { $0.displayName }.joined(separator: ", ")
            hints.append("This audio may contain: \(languages)")
        }

        // Vocabulary/proper nouns (limit to 20 to avoid token limits)
        if !vocabularyWords.isEmpty {
            let words = vocabularyWords.prefix(20).joined(separator: ", ")
            hints.append("Common names and terms: \(words)")
        }

        // Context name as potential vocabulary
        if let name = contextName, !name.isEmpty {
            if !hints.contains(where: { $0.contains(name) }) {
                hints.append("Context: \(name)")
            }
        }

        return hints.isEmpty ? nil : hints.joined(separator: ". ") + "."
    }

    /// Get formality level for translation providers.
    /// Uses explicit formality if set, otherwise infers from tone description.
    /// - Returns: Formality for translation providers (mapped to Formality enum)
    func inferFormality() -> Formality {
        // If explicit formality is set (not auto), use it directly
        if let explicit = explicitFormality {
            switch explicit {
            case .formal: return .formal
            case .informal: return .informal
            case .neutral: return .neutral
            case .auto: break // Fall through to inference
            }
        }

        // Auto-infer from tone description
        guard let tone = toneDescription?.lowercased(), !tone.isEmpty else {
            return .neutral
        }

        // Formal indicators
        let formalKeywords = ["formal", "professional", "business", "official", "respectful", "polite", "corporate"]
        if formalKeywords.contains(where: { tone.contains($0) }) {
            return .formal
        }

        // Informal indicators
        let informalKeywords = ["casual", "friendly", "informal", "playful", "relaxed", "conversational", "warm"]
        if informalKeywords.contains(where: { tone.contains($0) }) {
            return .informal
        }

        return .neutral
    }

    // MARK: - Private Helpers

    /// Build the <context> section with memory and tone
    private func buildContextSection() -> String {
        var contextParts: [String] = []

        // Memory subsections
        let memorySection = buildMemorySection()
        if !memorySection.isEmpty {
            contextParts.append(memorySection)
        }

        // Tone subsection
        if let tone = toneDescription, !tone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contextParts.append("  <tone>\n\(tone.indented(by: 4))\n  </tone>")
        }

        if contextParts.isEmpty {
            return ""
        }

        return "<context>\n\(contextParts.joined(separator: "\n"))\n</context>"
    }

    /// Build the memory subsection with all tiers
    private func buildMemorySection() -> String {
        var memories: [String] = []

        // Global memory
        if let global = globalMemory, !global.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            memories.append("  <memory type=\"global\">\n\(global.indented(by: 4))\n  </memory>")
        }

        // Context memory
        if let ctxMem = contextMemory,
           !ctxMem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let name = contextName {
            memories.append("  <memory type=\"context\" name=\"\(name)\">\n\(ctxMem.indented(by: 4))\n  </memory>")
        }

        // Power Mode memory
        if let pmMem = powerModeMemory,
           !pmMem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let name = powerModeName {
            memories.append("  <memory type=\"powerMode\" name=\"\(name)\">\n\(pmMem.indented(by: 4))\n  </memory>")
        }

        return memories.joined(separator: "\n")
    }

    // MARK: - Computed Properties

    /// Whether this context has any memory (any tier)
    var hasMemory: Bool {
        let hasGlobal = globalMemory?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasContext = contextMemory?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasPowerMode = powerModeMemory?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        return hasGlobal || hasContext || hasPowerMode
    }

    /// Whether this context has tone description
    var hasTone: Bool {
        toneDescription?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    /// Whether this context has custom instructions
    var hasInstructions: Bool {
        customInstructions?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    /// Whether this context has any content at all
    var hasContent: Bool {
        hasMemory || hasTone || hasInstructions || !languageHints.isEmpty || !vocabularyWords.isEmpty
    }
}

// MARK: - String Extension

private extension String {
    /// Indent each line by the specified number of spaces
    func indented(by spaces: Int) -> String {
        let indent = String(repeating: " ", count: spaces)
        return self.split(separator: "\n", omittingEmptySubsequences: false)
            .map { indent + $0 }
            .joined(separator: "\n")
    }
}
