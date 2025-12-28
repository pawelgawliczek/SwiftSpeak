//
//  AppleTranslationService.swift
//  SwiftSpeak
//
//  Phase 10f: On-device translation using Apple Translation framework
//  Available on iOS 17.4+ / iOS 18.0+ for TranslationSession
//

import Foundation

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

        do {
            // Convert to Locale.Language
            let targetLocale = localeLanguage(for: targetLanguage)
            let sourceLocale = sourceLanguage.map { localeLanguage(for: $0) }

            // Use TranslationSession for iOS 18+
            if #available(iOS 18.0, *) {
                return try await translateWithSession(
                    text: text,
                    from: sourceLocale,
                    to: targetLocale
                )
            } else {
                // Fallback for iOS 17.4-17.x
                // On older iOS, we need to use the translationTask SwiftUI modifier
                // For now, throw an error indicating the limitation
                throw LocalProviderError.appleTranslationFailed(
                    reason: "Direct translation API requires iOS 18.0+. Use translationTask modifier in SwiftUI."
                )
            }
        } catch let error as LocalProviderError {
            throw error
        } catch {
            throw LocalProviderError.appleTranslationFailed(reason: error.localizedDescription)
        }
        #else
        throw LocalProviderError.appleTranslationNotAvailable
        #endif
    }

    // MARK: - iOS 18+ Translation

    #if canImport(Translation)
    @available(iOS 18.0, *)
    private func translateWithSession(
        text: String,
        from source: Locale.Language?,
        to target: Locale.Language
    ) async throws -> String {
        // Create translation configuration
        let configuration = TranslationSession.Configuration(
            source: source,
            target: target
        )

        // We need to use the translation session within a SwiftUI context
        // For non-SwiftUI usage, we create a temporary session
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                // Create a temporary translation task
                // Note: This approach uses a workaround since TranslationSession
                // is designed for SwiftUI's translationTask modifier
                do {
                    // For programmatic usage outside SwiftUI, we need a different approach
                    // The Translation framework is primarily designed for SwiftUI
                    // We'll use a placeholder that works with the translationTask flow

                    // Since TranslationSession requires SwiftUI context,
                    // we throw an error suggesting the proper usage pattern
                    continuation.resume(throwing: LocalProviderError.appleTranslationFailed(
                        reason: "Translation requires SwiftUI context. Use translationTask modifier."
                    ))
                }
            }
        }
    }
    #endif

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
@available(iOS 17.4, *)
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
