//
//  WhisperKitTranscriptionService.swift
//  SwiftSpeak
//
//  Phase 10f: On-device transcription using WhisperKit
//  https://github.com/argmaxinc/WhisperKit
//

import Foundation
import SwiftSpeakCore

#if canImport(WhisperKit)
import WhisperKit
#endif

/// On-device speech-to-text transcription using WhisperKit
///
/// WhisperKit provides fast, accurate on-device transcription using optimized
/// CoreML models. This service wraps WhisperKit to conform to the TranscriptionProvider protocol.
///
/// Requirements:
/// - iOS 17.0+
/// - Apple Silicon (A12+)
/// - Model must be downloaded before use
///
/// Usage:
/// ```swift
/// let service = WhisperKitTranscriptionService(config: settings.whisperKitConfig)
/// try await service.initialize()
/// let text = try await service.transcribe(audioURL: audioFile, language: .english)
/// ```
@MainActor
final class WhisperKitTranscriptionService: TranscriptionProvider {

    // MARK: - TranscriptionProvider Conformance

    let providerId: AIProvider = .local

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

    // MARK: - Initialization

    init(config: WhisperKitSettings) {
        self.config = config
    }

    /// Initialize the WhisperKit pipeline
    ///
    /// This lazily loads the model into memory. Call this before transcription
    /// to ensure the model is ready.
    ///
    /// - Throws: LocalProviderError if initialization fails
    func initialize() async throws {
        #if canImport(WhisperKit)
        guard whisperPipe == nil else { return }
        guard !isInitializing else { return }

        isInitializing = true
        defer { isInitializing = false }

        guard config.status == .ready else {
            throw LocalProviderError.whisperKitModelNotDownloaded(model: config.selectedModel.displayName)
        }

        do {
            // Initialize WhisperKit with the selected model
            let whisperConfig = WhisperKitConfig(model: config.selectedModel.rawValue)
            whisperPipe = try await WhisperKit(whisperConfig)
        } catch {
            throw LocalProviderError.whisperKitInitializationFailed(reason: error.localizedDescription)
        }
        #else
        throw LocalProviderError.deviceNotSupported(requirement: "WhisperKit framework not available")
        #endif
    }

    // MARK: - TranscriptionProvider Methods

    func transcribe(audioURL: URL, language: Language?, promptHint: String?) async throws -> String {
        #if canImport(WhisperKit)
        // Ensure initialized
        if whisperPipe == nil {
            try await initialize()
        }

        guard let pipe = whisperPipe else {
            throw LocalProviderError.whisperKitInitializationFailed(reason: "Pipeline not initialized")
        }

        // Verify audio file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.audioFileNotFound
        }

        do {
            // Build transcription options
            var options = DecodingOptions()

            // Set language if provided
            if let language = language {
                options.language = whisperLanguageCode(for: language)
            }

            // Note: WhisperKit uses promptTokens (tokenized prompt) rather than string prompt
            // The prompt hint would need to be tokenized first, which requires the tokenizer
            // For now, we skip the prompt hint - future enhancement could add tokenization

            // Perform transcription
            let results = try await pipe.transcribe(
                audioPath: audioURL.path,
                decodeOptions: options
            )

            // Extract text from results
            guard let transcription = results.first else {
                throw TranscriptionError.emptyResponse
            }

            let text = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else {
                throw TranscriptionError.emptyResponse
            }

            return text

        } catch let error as LocalProviderError {
            throw error
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw LocalProviderError.whisperKitTranscriptionFailed(reason: error.localizedDescription)
        }
        #else
        throw LocalProviderError.deviceNotSupported(requirement: "WhisperKit framework not available")
        #endif
    }

    func validateAPIKey(_ key: String) async -> Bool {
        // Local provider doesn't need API key validation
        return true
    }

    // MARK: - Helper Methods

    /// Convert Language enum to WhisperKit language code
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
        case .egyptianArabic: return "ar"  // Use Arabic for Egyptian Arabic
        case .polish: return "pl"
        }
    }

    /// Release the model from memory
    func unloadModel() {
        #if canImport(WhisperKit)
        whisperPipe = nil
        #endif
    }

    /// Check if the model supports a given language
    func supportsLanguage(_ language: Language) -> Bool {
        // English-only models only support English
        if config.selectedModel.isEnglishOnly {
            return language == .english
        }
        // Multilingual models support all languages
        return true
    }
}

// MARK: - Model Download Support

extension WhisperKitTranscriptionService {
    /// Download a WhisperKit model
    ///
    /// - Parameters:
    ///   - model: The model to download
    ///   - progress: Progress callback (0.0 - 1.0)
    /// - Returns: Path to downloaded model
    static func downloadModel(
        _ model: WhisperModel,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        #if canImport(WhisperKit)
        do {
            // WhisperKit handles model downloading automatically
            // when initialized with a model name
            let whisperConfig = WhisperKitConfig(model: model.rawValue)

            // This will download the model if not present
            _ = try await WhisperKit(whisperConfig)

            // Return the model directory
            guard let documentsDir = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first else {
                throw LocalProviderError.modelDownloadFailed(reason: "Could not find documents directory")
            }
            let modelDir = documentsDir.appendingPathComponent("whisperkit-models/\(model.rawValue)")

            return modelDir
        } catch {
            throw LocalProviderError.modelDownloadFailed(reason: error.localizedDescription)
        }
        #else
        throw LocalProviderError.deviceNotSupported(requirement: "WhisperKit framework not available")
        #endif
    }

    /// Check available disk space for model download
    static func hasEnoughDiskSpace(for model: WhisperModel) -> Bool {
        let requiredBytes = model.sizeBytes
        let availableBytes = availableDiskSpace()
        // Require 20% extra space for safety
        return availableBytes > Int64(Double(requiredBytes) * 1.2)
    }

    private static func availableDiskSpace() -> Int64 {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory())
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage ?? 0
        } catch {
            return 0
        }
    }
}
