//
//  MacSharedTypes.swift
//  SwiftSpeakMac
//
//  Shared type definitions for macOS (mirrors iOS types)
//

import Foundation
import SwiftUI

// MARK: - Subscription Tier

enum SubscriptionTier: String, Codable, CaseIterable {
    case free = "free"
    case pro = "pro"
    case power = "power"

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .power: return "Power"
        }
    }
}

// MARK: - Provider Usage Category

enum ProviderUsageCategory: String, Codable, CaseIterable, Identifiable {
    case transcription = "transcription"
    case translation = "translation"
    case powerMode = "power_mode"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .transcription: return "Transcription"
        case .translation: return "Translation"
        case .powerMode: return "Power Mode"
        }
    }

    var icon: String {
        switch self {
        case .transcription: return "waveform"
        case .translation: return "globe"
        case .powerMode: return "bolt.fill"
        }
    }
}

// MARK: - AI Provider

enum AIProvider: String, Codable, CaseIterable, Identifiable, Hashable {
    case openAI = "openai"
    case anthropic = "anthropic"
    case google = "google"
    case elevenLabs = "elevenlabs"
    case deepgram = "deepgram"
    case local = "local"
    case assemblyAI = "assemblyai"
    case deepL = "deepl"
    case azure = "azure"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic Claude"
        case .google: return "Google Cloud"
        case .elevenLabs: return "ElevenLabs"
        case .deepgram: return "Deepgram"
        case .local: return "Local AI"
        case .assemblyAI: return "AssemblyAI"
        case .deepL: return "DeepL"
        case .azure: return "Azure Translator"
        }
    }

    var shortName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Claude"
        case .google: return "Google"
        case .elevenLabs: return "ElevenLabs"
        case .deepgram: return "Deepgram"
        case .local: return "Local"
        case .assemblyAI: return "AssemblyAI"
        case .deepL: return "DeepL"
        case .azure: return "Azure"
        }
    }

    var icon: String {
        switch self {
        case .openAI: return "brain"
        case .anthropic: return "sparkles"
        case .google: return "brain"
        case .elevenLabs: return "waveform"
        case .deepgram: return "mic.fill"
        case .local: return "desktopcomputer"
        case .assemblyAI: return "waveform.circle.fill"
        case .deepL: return "character.book.closed.fill"
        case .azure: return "cloud.fill"
        }
    }

    var requiresAPIKey: Bool {
        self != .local
    }

    var isLocalProvider: Bool {
        self == .local
    }

    var supportsTranscription: Bool {
        switch self {
        case .openAI, .elevenLabs, .deepgram, .local, .assemblyAI, .google: return true
        case .anthropic, .deepL, .azure: return false
        }
    }

    var supportsTranslation: Bool {
        switch self {
        case .openAI, .anthropic, .google, .local, .deepL, .azure: return true
        case .elevenLabs, .deepgram, .assemblyAI: return false
        }
    }

    var supportsPowerMode: Bool {
        switch self {
        case .openAI, .anthropic, .google, .local: return true
        case .elevenLabs, .deepgram, .assemblyAI, .deepL, .azure: return false
        }
    }

    var supportedCategories: Set<ProviderUsageCategory> {
        var categories: Set<ProviderUsageCategory> = []
        if supportsTranscription { categories.insert(.transcription) }
        if supportsTranslation { categories.insert(.translation) }
        if supportsPowerMode { categories.insert(.powerMode) }
        return categories
    }

    var defaultSTTModel: String? {
        switch self {
        case .openAI: return "gpt-4o-transcribe"
        case .elevenLabs: return "scribe_v1"
        case .deepgram: return "nova-2"
        case .local: return nil
        case .assemblyAI: return "default"
        case .google: return "long"
        case .anthropic, .deepL, .azure: return nil
        }
    }

    var defaultLLMModel: String? {
        switch self {
        case .openAI: return "gpt-4o-mini"
        case .anthropic: return "claude-3-5-sonnet-latest"
        case .google: return "gemini-2.0-flash-exp"
        case .local: return nil
        case .deepL: return "default"
        case .azure: return "default"
        case .elevenLabs, .deepgram, .assemblyAI: return nil
        }
    }

    var apiKeyHelpURL: URL? {
        switch self {
        case .openAI: return URL(string: "https://platform.openai.com/api-keys")
        case .anthropic: return URL(string: "https://console.anthropic.com/settings/keys")
        case .google: return URL(string: "https://console.cloud.google.com/apis/credentials")
        case .elevenLabs: return URL(string: "https://elevenlabs.io/app/settings/api-keys")
        case .deepgram: return URL(string: "https://console.deepgram.com/project/api-keys")
        case .local: return URL(string: "https://ollama.ai")
        case .assemblyAI: return URL(string: "https://www.assemblyai.com/app/account")
        case .deepL: return URL(string: "https://www.deepl.com/account/summary")
        case .azure: return URL(string: "https://portal.azure.com")
        }
    }

    static var transcriptionProviders: [AIProvider] {
        [.openAI, .deepgram, .assemblyAI, .google, .elevenLabs, .local]
    }

    static var formattingProviders: [AIProvider] {
        [.openAI, .anthropic, .google, .local]
    }

    static var translationProviders: [AIProvider] {
        [.openAI, .deepL, .google, .anthropic, .azure, .local]
    }
}

// MARK: - Hotkey Types

enum HotkeyAction: String, CaseIterable, Hashable {
    case toggleRecording
    case cancelRecording
    case quickPaste
}

struct HotkeyCombination: Codable, Hashable {
    let keyCode: UInt16
    let modifiers: UInt
    let displayString: String
}

protocol HotkeyManagerProtocol {
    var registeredHotkeys: [HotkeyAction: HotkeyCombination] { get }
    func registerHotkey(_ combination: HotkeyCombination, for action: HotkeyAction) throws
    func unregisterHotkey(for action: HotkeyAction)
    func setHandler(_ handler: @escaping (HotkeyAction) -> Void)
}

// MARK: - Text Insertion Types

enum TextInsertionResult {
    case accessibilitySuccess
    case clipboardFallback
    case failed(Error)
}

protocol TextInsertionProtocol {
    var isAccessibilityAvailable: Bool { get }
    func insertText(_ text: String, replaceSelection: Bool) async -> TextInsertionResult
    func getSelectedText() async -> String?
    func replaceAllText(with text: String) async -> TextInsertionResult
}

// MARK: - Transcription Error

enum TranscriptionError: Error, LocalizedError {
    case apiKeyMissing
    case noProviderAvailable
    case recordingFailed(String)
    case transcriptionFailed(Error)
    case networkError(Error)
    case microphonePermissionDenied
    case noAudioRecorded
    case audioTooShort(duration: TimeInterval, minDuration: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "API key is not configured"
        case .noProviderAvailable:
            return "No transcription provider is available"
        case .recordingFailed(let reason):
            return "Recording failed: \(reason)"
        case .transcriptionFailed(let error):
            return "Transcription failed: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .microphonePermissionDenied:
            return "Microphone access is required for recording"
        case .noAudioRecorded:
            return "No audio was recorded"
        case .audioTooShort(let duration, let minDuration):
            return "Recording too short (\(String(format: "%.1f", duration))s, minimum \(String(format: "%.1f", minDuration))s)"
        }
    }
}

// MARK: - Audio Recorder Protocol

protocol AudioRecorderProtocol: ObservableObject {
    var isRecording: Bool { get }
    var currentLevel: Float { get }
    var duration: TimeInterval { get }
    var recordingURL: URL? { get }
    var recordingFileSize: Int? { get }

    func startRecording() async throws
    func stopRecording() throws -> URL
    func cancelRecording()
    func deleteRecording()
}

// MARK: - Cost Breakdown

struct CostBreakdown: Codable, Equatable {
    let transcriptionCost: Double
    let formattingCost: Double
    let translationCost: Double?
    let powerModeCost: Double?
    let ragCost: Double?
    let predictionCost: Double?

    // Token counts (if available from LLM responses)
    let inputTokens: Int?
    let outputTokens: Int?

    // Word count for analytics
    let wordCount: Int?

    /// Total cost of the operation
    var total: Double {
        transcriptionCost + formattingCost + (translationCost ?? 0) + (powerModeCost ?? 0) + (ragCost ?? 0) + (predictionCost ?? 0)
    }

    /// Check if this breakdown has any costs
    var hasCosts: Bool {
        total > 0
    }

    /// Create a zero-cost breakdown
    static var zero: CostBreakdown {
        CostBreakdown(
            transcriptionCost: 0,
            formattingCost: 0,
            translationCost: nil,
            powerModeCost: nil,
            ragCost: nil,
            predictionCost: nil,
            inputTokens: nil,
            outputTokens: nil,
            wordCount: nil
        )
    }
}

// MARK: - Transcription Record

struct TranscriptionRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let rawTranscription: String
    let formattedText: String
    let formattingMode: FormattingMode
    let duration: TimeInterval
    let transcriptionProvider: AIProvider
    let formattingProvider: AIProvider?

    // Cost tracking
    let costBreakdown: CostBreakdown?

    // Convenience accessors
    var text: String { formattedText }
    var provider: AIProvider { transcriptionProvider }
    var estimatedCost: Double? { costBreakdown?.total }

    init(id: UUID = UUID(),
         timestamp: Date = Date(),
         rawTranscription: String,
         formattedText: String,
         formattingMode: FormattingMode,
         duration: TimeInterval,
         transcriptionProvider: AIProvider,
         formattingProvider: AIProvider? = nil,
         costBreakdown: CostBreakdown? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.rawTranscription = rawTranscription
        self.formattedText = formattedText
        self.formattingMode = formattingMode
        self.duration = duration
        self.transcriptionProvider = transcriptionProvider
        self.formattingProvider = formattingProvider
        self.costBreakdown = costBreakdown
    }

    // Hashable conformance (use id for equality)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TranscriptionRecord, rhs: TranscriptionRecord) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Formatting Mode

enum FormattingMode: String, Codable, CaseIterable, Identifiable {
    case raw = "raw"
    case email = "email"
    case formal = "formal"
    case casual = "casual"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .raw: return "Raw"
        case .email: return "Email"
        case .formal: return "Formal"
        case .casual: return "Casual"
        }
    }

    var icon: String {
        switch self {
        case .raw: return "text.alignleft"
        case .email: return "envelope.fill"
        case .formal: return "briefcase.fill"
        case .casual: return "face.smiling.fill"
        }
    }

    var prompt: String {
        switch self {
        case .raw:
            return ""
        case .email:
            return """
            Format this dictated text as a professional email.
            Add appropriate greeting and sign-off.
            Fix grammar and punctuation. Keep the original meaning.
            """
        case .formal:
            return """
            Rewrite this text in a formal, professional tone.
            Use proper business language. Fix any grammatical errors.
            """
        case .casual:
            return """
            Clean up this text while keeping a casual, friendly tone.
            Fix grammar but maintain conversational style.
            """
        }
    }
}

// MARK: - Language

enum Language: String, Codable, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case russian = "ru"
    case polish = "pl"
    case arabic = "ar"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .chinese: return "Chinese"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .russian: return "Russian"
        case .polish: return "Polish"
        case .arabic: return "Arabic"
        }
    }

    /// ISO 639-1 code for Whisper API
    var whisperCode: String {
        rawValue  // Already ISO 639-1 codes
    }
}

// MARK: - AI Provider Config

/// Configuration for a single AI provider
struct AIProviderConfig: Codable, Identifiable, Equatable {
    let provider: AIProvider
    var apiKey: String
    var selectedSTTModel: String?
    var selectedLLMModel: String?
    var usageCategories: Set<ProviderUsageCategory>

    var id: String { provider.rawValue }

    init(
        provider: AIProvider,
        apiKey: String = "",
        selectedSTTModel: String? = nil,
        selectedLLMModel: String? = nil,
        usageCategories: Set<ProviderUsageCategory> = []
    ) {
        self.provider = provider
        self.apiKey = apiKey
        self.selectedSTTModel = selectedSTTModel ?? provider.defaultSTTModel
        self.selectedLLMModel = selectedLLMModel ?? provider.defaultLLMModel
        self.usageCategories = usageCategories.isEmpty ? provider.supportedCategories : usageCategories
    }

    var isConfigured: Bool {
        !apiKey.isEmpty || provider.isLocalProvider
    }

    var isConfiguredForTranscription: Bool {
        isConfigured && usageCategories.contains(.transcription) && provider.supportsTranscription
    }

    var isConfiguredForTranslation: Bool {
        isConfigured && usageCategories.contains(.translation) && provider.supportsTranslation
    }

    var isConfiguredForPowerMode: Bool {
        isConfigured && usageCategories.contains(.powerMode) && provider.supportsPowerMode
    }
}

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

// MARK: - Enter Key Behavior

enum EnterKeyBehavior: String, Codable, CaseIterable, Identifiable {
    case defaultNewLine = "newLine"
    case formatThenInsert = "format"
    case justSend = "send"
    case formatAndSend = "formatSend"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .defaultNewLine: return "New line"
        case .formatThenInsert: return "Format + insert"
        case .justSend: return "Send"
        case .formatAndSend: return "Format + send"
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

// MARK: - Text Insertion Method

enum TextInsertionMethod: String, Codable, CaseIterable, Identifiable {
    case auto = "auto"
    case accessibility = "accessibility"
    case clipboard = "clipboard"
    case typeCharacters = "type"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto (Recommended)"
        case .accessibility: return "Accessibility API"
        case .clipboard: return "Clipboard Paste"
        case .typeCharacters: return "Type Characters"
        }
    }

    var icon: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .accessibility: return "accessibility"
        case .clipboard: return "doc.on.clipboard"
        case .typeCharacters: return "keyboard"
        }
    }

    var description: String {
        switch self {
        case .auto: return "Automatically choose the best method for the current app"
        case .accessibility: return "Direct text insertion via macOS accessibility (fastest, preserves clipboard)"
        case .clipboard: return "Copy to clipboard and paste (works everywhere, overwrites clipboard)"
        case .typeCharacters: return "Simulate typing characters (slowest, most compatible)"
        }
    }
}

// MARK: - Domain Jargon

enum DomainJargon: String, Codable, CaseIterable, Identifiable {
    case none = "none"
    case medical = "medical"
    case legal = "legal"
    case technical = "technical"
    case financial = "financial"
    case scientific = "scientific"
    case business = "business"

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

    var transcriptionHint: String? {
        switch self {
        case .none: return nil
        case .medical: return "Medical terminology: diagnosis, prognosis, prescription, symptoms"
        case .legal: return "Legal terminology: plaintiff, defendant, litigation, contract"
        case .technical: return "Technical terminology: API, SDK, database, server, deployment"
        case .financial: return "Financial terminology: portfolio, equity, dividend, ROI"
        case .scientific: return "Scientific terminology: hypothesis, methodology, analysis"
        case .business: return "Business terminology: stakeholder, deliverable, KPI, roadmap"
        }
    }
}

// MARK: - Formatting Instruction

struct FormattingInstruction: Codable, Identifiable, Hashable {
    let id: String
    let displayName: String
    let promptText: String
    let group: InstructionGroup
    let icon: String?

    enum InstructionGroup: String, Codable, CaseIterable {
        case lightTouch = "light"
        case grammar = "grammar"
        case style = "style"
        case emoji = "emoji"
    }

    static let all: [FormattingInstruction] = [
        FormattingInstruction(id: "punctuation", displayName: "Punctuation", promptText: "Fix punctuation.", group: .lightTouch, icon: "textformat"),
        FormattingInstruction(id: "capitals", displayName: "Capitals", promptText: "Fix capitalization.", group: .lightTouch, icon: "textformat.size"),
        FormattingInstruction(id: "spelling", displayName: "Spelling", promptText: "Fix spelling mistakes.", group: .lightTouch, icon: "character.cursor.ibeam"),
        FormattingInstruction(id: "grammar", displayName: "Grammar", promptText: "Fix grammar errors.", group: .grammar, icon: "text.badge.checkmark"),
        FormattingInstruction(id: "casual", displayName: "Casual", promptText: "Use a casual, friendly tone.", group: .style, icon: "face.smiling"),
        FormattingInstruction(id: "formal", displayName: "Formal", promptText: "Use a formal, professional tone.", group: .style, icon: "briefcase"),
        FormattingInstruction(id: "concise", displayName: "Concise", promptText: "Make it concise.", group: .style, icon: "arrow.down.right.and.arrow.up.left"),
        FormattingInstruction(id: "bullets", displayName: "Bullets", promptText: "Format as bullet points.", group: .style, icon: "list.bullet"),
        FormattingInstruction(id: "emoji_never", displayName: "Never", promptText: "Do NOT add any emoji.", group: .emoji, icon: "xmark.circle"),
        FormattingInstruction(id: "emoji_few", displayName: "Few", promptText: "Add emoji sparingly.", group: .emoji, icon: "face.smiling"),
        FormattingInstruction(id: "emoji_lots", displayName: "Lots", promptText: "Add emoji generously.", group: .emoji, icon: "sparkles")
    ]

    static func instruction(withId id: String) -> FormattingInstruction? {
        all.first { $0.id == id }
    }
}

// MARK: - App Category

enum AppCategory: String, Codable, CaseIterable, Identifiable {
    case messaging = "messaging"
    case email = "email"
    case social = "social"
    case work = "work"
    case personal = "personal"
    case browser = "browser"
    case notes = "notes"
    case finance = "finance"
    case dating = "dating"
    case gaming = "gaming"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .messaging: return "Messaging"
        case .email: return "Email"
        case .social: return "Social Media"
        case .work: return "Work & Productivity"
        case .personal: return "Personal"
        case .browser: return "Browser"
        case .notes: return "Notes & Writing"
        case .finance: return "Finance"
        case .dating: return "Dating"
        case .gaming: return "Gaming"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .messaging: return "message.fill"
        case .email: return "envelope.fill"
        case .social: return "person.2.fill"
        case .work: return "briefcase.fill"
        case .personal: return "heart.fill"
        case .browser: return "globe"
        case .notes: return "note.text"
        case .finance: return "creditcard.fill"
        case .dating: return "heart.circle.fill"
        case .gaming: return "gamecontroller.fill"
        case .other: return "square.grid.2x2.fill"
        }
    }
}

// MARK: - App Assignment

struct AppAssignment: Codable, Equatable, Hashable {
    var assignedAppIds: Set<String>
    var assignedCategories: Set<AppCategory>

    init(assignedAppIds: Set<String> = [], assignedCategories: Set<AppCategory> = []) {
        self.assignedAppIds = assignedAppIds
        self.assignedCategories = assignedCategories
    }

    var hasAssignments: Bool {
        !assignedAppIds.isEmpty || !assignedCategories.isEmpty
    }

    var summary: String {
        var parts: [String] = []
        if !assignedAppIds.isEmpty {
            let appCount = assignedAppIds.count
            parts.append("\(appCount) app\(appCount == 1 ? "" : "s")")
        }
        if !assignedCategories.isEmpty {
            let categoryNames = assignedCategories.map { $0.displayName }.sorted().joined(separator: ", ")
            parts.append(categoryNames)
        }
        return parts.isEmpty ? "None" : parts.joined(separator: " • ")
    }

    static let empty = AppAssignment()
}

// MARK: - RAG Configuration

struct RAGConfiguration: Codable, Equatable, Hashable, Sendable {
    var chunkingStrategy: RAGChunkingStrategy
    var maxChunkTokens: Int
    var overlapTokens: Int
    var maxContextChunks: Int
    var similarityThreshold: Float
    var embeddingModel: RAGEmbeddingModel

    static var `default`: RAGConfiguration {
        RAGConfiguration(
            chunkingStrategy: .semantic,
            maxChunkTokens: 500,
            overlapTokens: 50,
            maxContextChunks: 5,
            similarityThreshold: 0.7,
            embeddingModel: .openAISmall
        )
    }
}

enum RAGChunkingStrategy: String, Codable, CaseIterable, Hashable, Sendable {
    case semantic
    case fixedSize
    case sentence

    var displayName: String {
        switch self {
        case .semantic: return "Semantic"
        case .fixedSize: return "Fixed Size"
        case .sentence: return "Sentence"
        }
    }
}

enum RAGEmbeddingModel: String, Codable, CaseIterable, Hashable, Sendable {
    case openAISmall = "text-embedding-3-small"
    case openAILarge = "text-embedding-3-large"

    var displayName: String {
        switch self {
        case .openAISmall: return "OpenAI Small"
        case .openAILarge: return "OpenAI Large"
        }
    }
}

// MARK: - Conversation Context

struct ConversationContext: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var color: PowerModeColorPreset
    var description: String

    // Transcription
    var domainJargon: DomainJargon

    // Formatting
    var examples: [String]
    var selectedInstructions: Set<String>
    var customInstructions: String?

    // Memory
    var useGlobalMemory: Bool
    var useContextMemory: Bool
    var contextMemory: String?
    var memoryLimit: Int
    var lastMemoryUpdate: Date?

    // Keyboard Behavior
    var autoSendAfterInsert: Bool
    var enterKeyBehavior: EnterKeyBehavior
    var textInsertionMethod: TextInsertionMethod

    // System
    var isActive: Bool
    var appAssignment: AppAssignment
    var isPreset: Bool
    let createdAt: Date
    var updatedAt: Date

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
        memoryLimit: Int = 2000,
        lastMemoryUpdate: Date? = nil,
        autoSendAfterInsert: Bool = false,
        enterKeyBehavior: EnterKeyBehavior = .defaultNewLine,
        textInsertionMethod: TextInsertionMethod = .auto,
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
        self.memoryLimit = memoryLimit
        self.lastMemoryUpdate = lastMemoryUpdate
        self.autoSendAfterInsert = autoSendAfterInsert
        self.enterKeyBehavior = enterKeyBehavior
        self.textInsertionMethod = textInsertionMethod
        self.isActive = isActive
        self.appAssignment = appAssignment
        self.isPreset = isPreset
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var formattingInstructions: [FormattingInstruction] {
        selectedInstructions.compactMap { FormattingInstruction.instruction(withId: $0) }
    }

    static var empty: ConversationContext {
        ConversationContext(name: "", icon: "person.circle", color: .blue, description: "")
    }

    static var presets: [ConversationContext] {
        [
            ConversationContext(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                name: "Work",
                icon: "💼",
                color: .blue,
                description: "Professional business communication",
                domainJargon: .business,
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
                customInstructions: "Preserve creative expression.",
                useGlobalMemory: true,
                isPreset: true
            )
        ]
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

    // Memory support
    var memoryEnabled: Bool
    var memory: String?
    var memoryLimit: Int
    var lastMemoryUpdate: Date?

    // Knowledge base document IDs (RAG)
    var knowledgeDocumentIds: [UUID]

    // RAG configuration
    var ragConfiguration: RAGConfiguration

    // Archive support
    var isArchived: Bool

    // App auto-enable assignment
    var appAssignment: AppAssignment

    // Enabled webhook IDs
    var enabledWebhookIds: [UUID]

    // Text insertion behavior
    var textInsertionMethod: TextInsertionMethod

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
        textInsertionMethod: TextInsertionMethod = .auto
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
        self.textInsertionMethod = textInsertionMethod
    }

    static let presets: [PowerMode] = [
        PowerMode(
            name: "Research Assistant",
            icon: "magnifyingglass.circle.fill",
            iconColor: .blue,
            iconBackgroundColor: .blue,
            instruction: "Help me find accurate, up-to-date information on the topic I describe.",
            outputFormat: "Use headers for main topics. Include bullet points for key findings."
        ),
        PowerMode(
            name: "Email Composer",
            icon: "envelope.fill",
            iconColor: .purple,
            iconBackgroundColor: .purple,
            instruction: "Help me compose professional emails based on my voice input.",
            outputFormat: "Format as a proper email with subject, greeting, body, and sign-off."
        ),
        PowerMode(
            name: "Daily Planner",
            icon: "calendar",
            iconColor: .green,
            iconBackgroundColor: .green,
            instruction: "Help me organize my day based on what I tell you.",
            outputFormat: "Create a structured daily schedule with time blocks."
        )
    ]
}

// MARK: - History Memory

struct HistoryMemory: Codable, Equatable {
    var summary: String
    var lastUpdated: Date
    var conversationCount: Int
    var recentTopics: [String]

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
}

// MARK: - Vocabulary Entry

struct VocabularyEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var recognizedWord: String
    var replacementWord: String
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        recognizedWord: String,
        replacementWord: String,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.recognizedWord = recognizedWord
        self.replacementWord = replacementWord
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Custom Template

struct CustomTemplate: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    var prompt: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "doc.text",
        prompt: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.prompt = prompt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Cost Formatting Extensions

extension Double {
    /// Format as cost string (e.g., "$0.0012")
    var formattedCost: String {
        if self == 0 {
            return "$0.00"
        } else if self < 0.01 {
            return String(format: "$%.4f", self)
        } else if self < 1 {
            return String(format: "$%.3f", self)
        } else {
            return String(format: "$%.2f", self)
        }
    }

    /// Compact cost format for charts (e.g., "$1.2K")
    var formattedCostCompact: String {
        if self < 0.01 {
            return "$0"
        } else if self < 1 {
            return String(format: "$%.2f", self)
        } else if self < 1000 {
            return String(format: "$%.1f", self)
        } else {
            return String(format: "$%.1fK", self / 1000)
        }
    }
}
