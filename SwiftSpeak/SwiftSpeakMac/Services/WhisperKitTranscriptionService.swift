//
//  WhisperKitTranscriptionService.swift
//  SwiftSpeakMac
//
//  On-device transcription using WhisperKit for macOS
//

import Foundation
import SwiftSpeakCore

#if canImport(WhisperKit)
import WhisperKit
#endif

/// On-device speech-to-text transcription using WhisperKit for macOS
@MainActor
final class WhisperKitTranscriptionService: TranscriptionProvider {

    // MARK: - TranscriptionProvider Conformance

    let providerId: AIProvider = .whisperKit

    var isConfigured: Bool {
        #if canImport(WhisperKit)
        return whisperPipe != nil && config.status == .ready
        #else
        return false
        #endif
    }

    var model: String {
        config.selectedModel.rawValue
    }

    // MARK: - Properties

    private let config: WhisperKitSettings

    #if canImport(WhisperKit)
    private var whisperPipe: WhisperKit?
    #endif

    private var isInitializing = false
    private var initializationTask: Task<Void, Error>?

    // MARK: - Initialization

    init(config: WhisperKitSettings) {
        self.config = config
    }

    /// Initialize the WhisperKit pipeline
    func initialize() async throws {
        #if canImport(WhisperKit)
        // If already initialized, return
        guard whisperPipe == nil else { return }

        // If initialization is in progress, wait for it to complete
        if let existingTask = initializationTask {
            macLog("Waiting for existing WhisperKit initialization...", category: "WhisperKit")
            try await existingTask.value
            return
        }

        guard config.status == .ready else {
            throw TranscriptionError.providerNotConfigured
        }

        // Start new initialization task
        isInitializing = true
        let task = Task { [self] in
            defer {
                isInitializing = false
            }

            // Get the specific model folder where this model's files are stored
            let modelFolder = Self.whisperKitModelFolder(for: config.selectedModel)

            // Configure WhisperKit to use local models without network access
            let whisperConfig = WhisperKitConfig(
                model: config.selectedModel.rawValue,
                modelFolder: modelFolder,
                download: false  // Use local only - don't try to download/verify from network
            )

            macLog("Initializing WhisperKit with model: \(config.selectedModel.rawValue), folder: \(modelFolder)", category: "WhisperKit")
            let pipe = try await WhisperKit(whisperConfig)
            await MainActor.run {
                self.whisperPipe = pipe
            }
            macLog("WhisperKit initialized successfully", category: "WhisperKit")
        }

        initializationTask = task

        do {
            try await task.value
        } catch {
            initializationTask = nil
            macLog("WhisperKit initialization failed: \(error)", category: "WhisperKit", level: .error)
            throw TranscriptionError.recordingFailed(error.localizedDescription)
        }

        initializationTask = nil
        #else
        throw TranscriptionError.providerNotConfigured
        #endif
    }

    /// Get the folder where a specific WhisperKit model is stored
    /// WhisperKit stores models in Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-{model}/
    private static func whisperKitModelFolder(for model: WhisperModel) -> String {
        // Model folder naming: "openai_whisper-tiny.en", "openai_whisper-large-v3", etc.
        let modelFolderName = "openai_whisper-\(model.rawValue)"

        // Get the app's Documents directory (resolves to container path automatically)
        if let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let modelFolder = documentsDir
                .appendingPathComponent("huggingface")
                .appendingPathComponent("models")
                .appendingPathComponent("argmaxinc")
                .appendingPathComponent("whisperkit-coreml")
                .appendingPathComponent(modelFolderName)
            return modelFolder.path
        }
        // Fallback to home directory path
        return NSHomeDirectory() + "/Documents/huggingface/models/argmaxinc/whisperkit-coreml/\(modelFolderName)"
    }

    // MARK: - TranscriptionProvider Methods

    func transcribe(audioURL: URL, language: Language?, promptHint: String?) async throws -> String {
        #if canImport(WhisperKit)
        if whisperPipe == nil {
            try await initialize()
        }

        guard let pipe = whisperPipe else {
            throw TranscriptionError.providerNotConfigured
        }

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.audioFileNotFound
        }

        do {
            var options = DecodingOptions()

            // Set language if provided
            if let language = language {
                options.language = whisperLanguageCode(for: language)
            }

            // Tokenize and set prompt hint for better accuracy
            // Prompt hints help with vocabulary, names, technical terms, etc.
            if let promptHint = promptHint, !promptHint.isEmpty,
               let tokenizer = pipe.tokenizer {
                let tokens = tokenizer.encode(text: promptHint)
                if !tokens.isEmpty {
                    options.promptTokens = tokens
                    macLog("Using prompt hint with \(tokens.count) tokens", category: "WhisperKit")
                }
            }

            let results = try await pipe.transcribe(
                audioPath: audioURL.path,
                decodeOptions: options
            )

            guard let transcription = results.first else {
                throw TranscriptionError.emptyResponse
            }

            let text = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else {
                throw TranscriptionError.emptyResponse
            }

            return text

        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.recordingFailed(error.localizedDescription)
        }
        #else
        throw TranscriptionError.providerNotConfigured
        #endif
    }

    func validateAPIKey(_ key: String) async -> Bool {
        return true
    }

    // MARK: - Helper Methods

    private func whisperLanguageCode(for language: Language) -> String {
        switch language {
        case .english: return "en"
        case .spanish: return "es"
        case .french: return "fr"
        case .german: return "de"
        case .italian: return "it"
        case .portuguese: return "pt"
        case .russian: return "ru"
        case .chinese: return "zh"
        case .japanese: return "ja"
        case .korean: return "ko"
        case .arabic: return "ar"
        case .egyptianArabic: return "ar"
        case .polish: return "pl"
        }
    }

    func unloadModel() {
        #if canImport(WhisperKit)
        whisperPipe = nil
        #endif
    }
}
