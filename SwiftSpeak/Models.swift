//
//  Models.swift
//  SwiftSpeak
//
//  Shared data models between main app and keyboard extension
//

import Foundation

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

    var price: String {
        switch self {
        case .free: return "$0"
        case .pro: return "$4.99/mo"
        case .power: return "$9.99/mo"
        }
    }
}

// MARK: - STT Provider
enum STTProvider: String, Codable, CaseIterable, Identifiable {
    case openAI = "openai"
    case elevenLabs = "elevenlabs"
    case deepgram = "deepgram"
    case ollama = "ollama"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI Whisper"
        case .elevenLabs: return "ElevenLabs"
        case .deepgram: return "Deepgram"
        case .ollama: return "Ollama (Local)"
        }
    }

    var icon: String {
        switch self {
        case .openAI: return "brain"
        case .elevenLabs: return "waveform"
        case .deepgram: return "mic.fill"
        case .ollama: return "desktopcomputer"
        }
    }

    var requiresAPIKey: Bool {
        self != .ollama
    }

    var costPerMinute: Double {
        switch self {
        case .openAI: return 0.006
        case .elevenLabs: return 0.0 // Free tier
        case .deepgram: return 0.0043
        case .ollama: return 0.0
        }
    }

    var isPro: Bool {
        self != .openAI
    }

    var shortName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .elevenLabs: return "ElevenLabs"
        case .deepgram: return "Deepgram"
        case .ollama: return "Ollama"
        }
    }
}

// MARK: - LLM Provider
enum LLMProvider: String, Codable, CaseIterable, Identifiable {
    case openAI = "openai"
    case anthropic = "anthropic"
    case ollama = "ollama"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI GPT"
        case .anthropic: return "Anthropic Claude"
        case .ollama: return "Ollama (Local)"
        }
    }

    var shortName: String {
        switch self {
        case .openAI: return "GPT"
        case .anthropic: return "Claude"
        case .ollama: return "Ollama"
        }
    }

    var icon: String {
        switch self {
        case .openAI: return "brain"
        case .anthropic: return "sparkles"
        case .ollama: return "desktopcomputer"
        }
    }

    var requiresAPIKey: Bool {
        self != .ollama
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
    case arabic = "ar"
    case egyptianArabic = "arz"
    case russian = "ru"
    case polish = "pl"

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
        case .arabic: return "Arabic"
        case .egyptianArabic: return "Egyptian Arabic"
        case .russian: return "Russian"
        case .polish: return "Polish"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .italian: return "🇮🇹"
        case .portuguese: return "🇵🇹"
        case .chinese: return "🇨🇳"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .arabic: return "🇸🇦"
        case .egyptianArabic: return "🇪🇬"
        case .russian: return "🇷🇺"
        case .polish: return "🇵🇱"
        }
    }
}

// MARK: - Transcription Record
struct TranscriptionRecord: Codable, Identifiable {
    let id: UUID
    let text: String
    let mode: FormattingMode
    let provider: STTProvider
    let timestamp: Date
    let duration: TimeInterval
    let translated: Bool
    let targetLanguage: Language?

    init(
        id: UUID = UUID(),
        text: String,
        mode: FormattingMode,
        provider: STTProvider,
        timestamp: Date = Date(),
        duration: TimeInterval,
        translated: Bool = false,
        targetLanguage: Language? = nil
    ) {
        self.id = id
        self.text = text
        self.mode = mode
        self.provider = provider
        self.timestamp = timestamp
        self.duration = duration
        self.translated = translated
        self.targetLanguage = targetLanguage
    }
}

// MARK: - Recording State
enum RecordingState: Equatable {
    case idle
    case recording
    case processing
    case formatting
    case complete(String)
    case error(String)

    var statusText: String {
        switch self {
        case .idle: return "Tap to record"
        case .recording: return "Listening..."
        case .processing: return "Transcribing..."
        case .formatting: return "Formatting..."
        case .complete: return "Done!"
        case .error(let message): return message
        }
    }
}

// MARK: - Custom Template
struct CustomTemplate: Codable, Identifiable {
    let id: UUID
    var name: String
    var prompt: String
    var icon: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        prompt: String,
        icon: String = "doc.text",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.icon = icon
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
