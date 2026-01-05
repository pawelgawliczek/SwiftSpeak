//
//  MacProviderFactory.swift
//  SwiftSpeakMac
//
//  Provider factory for macOS (minimal implementation for initial build)
//

import Foundation
import SwiftSpeakCore

// MARK: - Provider Factory

@MainActor
struct ProviderFactory {
    private let settings: MacSettings

    init(settings: MacSettings) {
        self.settings = settings
    }

    // MARK: - Transcription Providers

    func createTranscriptionProvider(for provider: AIProvider) -> TranscriptionProvider? {
        switch provider {
        case .openAI:
            guard let apiKey = settings.apiKey(for: .openAI) else { return nil }
            return OpenAITranscriptionService(apiKey: apiKey)
        default:
            return nil
        }
    }

    // MARK: - Formatting Providers

    func createFormattingProvider(for provider: AIProvider) -> FormattingProvider? {
        switch provider {
        case .openAI:
            guard let apiKey = settings.apiKey(for: .openAI) else { return nil }
            return OpenAIFormattingService(apiKey: apiKey)
        default:
            return nil
        }
    }

    // MARK: - Translation Providers

    func createTranslationProvider() -> TranslationProvider? {
        let provider = settings.selectedTranslationProvider
        switch provider {
        case .openAI:
            guard let apiKey = settings.apiKey(for: .openAI) else { return nil }
            return OpenAITranslationService(apiKey: apiKey)
        default:
            return nil
        }
    }
}

// MARK: - Translation Provider Protocol (for macOS)

protocol TranslationProvider {
    var providerId: AIProvider { get }
    var isConfigured: Bool { get }
    var model: String { get }
    var supportedLanguages: [Language] { get }

    func translate(
        text: String,
        from sourceLanguage: Language?,
        to targetLanguage: Language
    ) async throws -> String
}

// MARK: - OpenAI Transcription Service (Minimal Implementation)

class OpenAITranscriptionService: TranscriptionProvider {
    let providerId: AIProvider = .openAI
    let model: String = "whisper-1"
    private let apiKey: String

    var isConfigured: Bool { !apiKey.isEmpty }

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func transcribe(audioURL: URL, language: Language?, promptHint: String?) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add file
        let audioData = try Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Add model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)

        // Add language if specified
        if let lang = language {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(lang.rawValue)\r\n".data(using: .utf8)!)
        }

        // Add prompt hint if specified
        if let hint = promptHint {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(hint)\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TranscriptionError.transcriptionFailed("OpenAI API request failed")
        }

        struct TranscriptionResponse: Decodable {
            let text: String
        }

        let result = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return result.text
    }

    func validateAPIKey(_ key: String) async -> Bool {
        // Simple validation - just check format
        return key.hasPrefix("sk-") && key.count > 20
    }
}

// MARK: - OpenAI Formatting Service (Minimal Implementation)

class OpenAIFormattingService: FormattingProvider {
    let providerId: AIProvider = .openAI
    let model: String = "gpt-4o-mini"
    private let apiKey: String

    var isConfigured: Bool { !apiKey.isEmpty }

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func format(text: String, mode: FormattingMode, customPrompt: String?, context: PromptContext?) async throws -> String {
        guard mode != .raw else { return text }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build system prompt with optional context
        var systemPrompt = customPrompt ?? mode.prompt
        if let ctx = context {
            if let globalMemory = ctx.globalMemory, !globalMemory.isEmpty {
                systemPrompt += "\n\nUser context: \(globalMemory)"
            }
            if let contextMemory = ctx.contextMemory, !contextMemory.isEmpty {
                systemPrompt += "\n\nContext: \(contextMemory)"
            }
            if let customInstructions = ctx.customInstructions, !customInstructions.isEmpty {
                systemPrompt += "\n\nInstructions: \(customInstructions)"
            }
        }

        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "max_tokens": 1024
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TranscriptionError.transcriptionFailed("OpenAI API request failed")
        }

        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let result = try JSONDecoder().decode(ChatResponse.self, from: data)
        return result.choices.first?.message.content ?? text
    }
}

// MARK: - OpenAI Translation Service (Minimal Implementation)

class OpenAITranslationService: TranslationProvider {
    let providerId: AIProvider = .openAI
    let model: String = "gpt-4o-mini"
    private let apiKey: String

    var isConfigured: Bool { !apiKey.isEmpty }
    var supportedLanguages: [Language] { Language.allCases }

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func translate(text: String, from sourceLanguage: Language?, to targetLanguage: Language) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let sourceLang = sourceLanguage?.displayName ?? "the source language"
        let systemPrompt = """
        You are a professional translator. Translate the following text from \(sourceLang) to \(targetLanguage.displayName).
        Provide only the translation, with no additional commentary or explanation.
        Maintain the original tone and style while ensuring natural fluency in the target language.
        """

        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "max_tokens": 2048
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TranscriptionError.transcriptionFailed("OpenAI translation failed")
        }

        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let result = try JSONDecoder().decode(ChatResponse.self, from: data)
        return result.choices.first?.message.content ?? text
    }
}
