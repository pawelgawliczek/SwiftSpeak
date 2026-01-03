//
//  MacSharedTypes.swift
//  SwiftSpeakMac
//
//  Shared type definitions for macOS (mirrors iOS types)
//

import Foundation

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

    static var transcriptionProviders: [AIProvider] {
        [.openAI, .deepgram, .assemblyAI, .google, .elevenLabs, .local]
    }

    static var formattingProviders: [AIProvider] {
        [.openAI, .anthropic, .google, .local]
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

// MARK: - Transcription Record

struct TranscriptionRecord: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let rawTranscription: String
    let formattedText: String
    let formattingMode: FormattingMode
    let duration: TimeInterval
    let transcriptionProvider: AIProvider
    let formattingProvider: AIProvider?

    init(id: UUID = UUID(),
         timestamp: Date = Date(),
         rawTranscription: String,
         formattedText: String,
         formattingMode: FormattingMode,
         duration: TimeInterval,
         transcriptionProvider: AIProvider,
         formattingProvider: AIProvider? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.rawTranscription = rawTranscription
        self.formattedText = formattedText
        self.formattingMode = formattingMode
        self.duration = duration
        self.transcriptionProvider = transcriptionProvider
        self.formattingProvider = formattingProvider
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
        }
    }
}
