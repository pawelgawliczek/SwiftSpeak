//
//  AppleTranslationService.swift
//  SwiftSpeak
//
//  Phase 10f: On-device translation using Apple Translation framework
//  Available on iOS 17.4+ / iOS 18.0+ for TranslationSession
//

import Foundation
import SwiftSpeakCore

#if canImport(Translation)
import Translation
#endif

/// On-device translation using Apple's Translation framework
///
/// This service uses Apple's built-in translation capabilities which run entirely
/// on-device, ensuring privacy. Languages must be downloaded before use.
///
/// Requirements:
/// - iOS 17.4+ for basic translation
/// - iOS 18.0+ for TranslationSession API
/// - Downloaded language packs
///
/// Usage:
/// ```swift
/// let service = AppleTranslationService(config: settings.appleTranslationConfig)
/// let translated = try await service.translate(text: "Hello", from: .english, to: .spanish)
/// ```
@available(iOS 17.4, *)
@MainActor
final class AppleTranslationService: TranslationProvider {

    // MARK: - TranslationProvider Conformance

    let providerId: AIProvider = .local

    var isConfigured: Bool {
        config.isAvailable && !config.downloadedLanguages.isEmpty
    }

    var model: String {
        "Apple Translation"
    }

    var supportedLanguages: [Language] {
        config.downloadedLanguages.map { $0.language }
    }

    var supportsFormality: Bool {
        // Apple Translation doesn't support formality control
        false
    }

    // MARK: - Properties

    private let config: AppleTranslationConfig

    // MARK: - Initialization

    init(config: AppleTranslationConfig) {
        self.config = config
    }

    // MARK: - TranslationProvider Methods

    func translate(
        text: String,
        from sourceLanguage: Language?,
        to targetLanguage: Language,
        formality: Formality?,
        context: PromptContext?
    ) async throws -> String {
        #if canImport(Translation)
        guard config.isAvailable else {
            throw LocalProviderError.appleTranslationNotAvailable
        }

        // Check if target language is downloaded
        let hasTargetLanguage = config.downloadedLanguages.contains { $0.language == targetLanguage }
        guard hasTargetLanguage else {
            throw LocalProviderError.appleTranslationLanguageNotInstalled(
                language: targetLanguage.displayName
            )
        }

        // If source language specified, check it's downloaded too
        if let source = sourceLanguage {
            let hasSourceLanguage = config.downloadedLanguages.contains { $0.language == source }
            guard hasSourceLanguage else {
                throw LocalProviderError.appleTranslationLanguageNotInstalled(
                    language: source.displayName
                )
            }
        }

        // Use LocalTranslationManager to bridge to SwiftUI's translationTask
        // The manager coordinates with a SwiftUI view that has .localTranslationHandler()
        if #available(iOS 18.0, *) {
            return try await LocalTranslationManager.shared.requestTranslation(
                text: text,
                from: sourceLanguage,
                to: targetLanguage
            )
        } else {
            // iOS 17.4-17.x: TranslationSession requires iOS 18+
            throw LocalProviderError.appleTranslationFailed(
                reason: "On-device translation requires iOS 18.0 or later."
            )
        }
        #else
        throw LocalProviderError.appleTranslationNotAvailable
        #endif
    }

    // MARK: - Language Availability

    /// Check if a language pair is available for translation
    func checkLanguageAvailability(
        from source: Language?,
        to target: Language
    ) -> LanguageAvailabilityStatus {
        // Check if target is downloaded
        let hasTarget = config.downloadedLanguages.contains { $0.language == target }

        if let source = source {
            let hasSource = config.downloadedLanguages.contains { $0.language == source }
            if hasSource && hasTarget {
                return .available
            } else if !hasSource && !hasTarget {
                return .requiresDownload(languages: [source, target])
            } else if !hasSource {
                return .requiresDownload(languages: [source])
            } else {
                return .requiresDownload(languages: [target])
            }
        } else {
            // Auto-detect source
            return hasTarget ? .available : .requiresDownload(languages: [target])
        }
    }

    // MARK: - Helper Methods

    /// Convert Language enum to Locale.Language
    private func localeLanguage(for language: Language) -> Locale.Language {
        Locale.Language(identifier: languageCode(for: language))
    }

    /// Get ISO language code for Language enum
    private func languageCode(for language: Language) -> String {
        switch language {
        case .english: return "en"
        case .spanish: return "es"
        case .french: return "fr"
        case .german: return "de"
        case .italian: return "it"
        case .portuguese: return "pt"
        case .russian: return "ru"
        case .chinese: return "zh-Hans"
        case .japanese: return "ja"
        case .korean: return "ko"
        case .arabic: return "ar"
        case .egyptianArabic: return "ar"  // Use Arabic for Egyptian Arabic
        case .polish: return "pl"
        }
    }
}

// MARK: - Language Availability Status

/// Status of language availability for translation
enum LanguageAvailabilityStatus: Equatable {
    case available
    case requiresDownload(languages: [Language])
    case notSupported

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }
}

// MARK: - SwiftUI Translation Helper

#if canImport(Translation)
import SwiftUI

/// A SwiftUI view modifier that provides translation capabilities
///
/// Usage:
/// ```swift
/// Text(translatedText ?? originalText)
///     .translationTask(source: .english, target: .spanish) { session in
///         let result = try await session.translate(originalText)
///         translatedText = result.targetText
///     }
/// ```
@available(iOS 18.0, *)
struct TranslationHelper {
    /// Translate text using the SwiftUI translation task
    /// This is the recommended way to use Apple Translation
    @MainActor
    static func translate(
        text: String,
        from source: Language?,
        to target: Language,
        using session: TranslationSession
    ) async throws -> String {
        let response = try await session.translate(text)
        return response.targetText
    }
}
#endif
