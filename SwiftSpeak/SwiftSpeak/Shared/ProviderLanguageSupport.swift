//
//  ProviderLanguageSupport.swift
//  SwiftSpeak
//
//  Language support data model and database for provider compatibility
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import SwiftUI

// MARK: - Language Support Level

/// Language support level for a provider
enum LanguageSupportLevel: String, Codable, CaseIterable, Comparable {
    case excellent    // Native-level quality
    case good         // Minor occasional errors
    case limited      // Works but not recommended
    case unsupported  // Does not work

    var icon: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .limited: return "exclamationmark.triangle.fill"
        case .unsupported: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .limited: return .orange
        case .unsupported: return .red
        }
    }

    var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .limited: return "Limited"
        case .unsupported: return "Not Supported"
        }
    }

    var shortLabel: String {
        switch self {
        case .excellent: return "Best"
        case .good: return "Good"
        case .limited: return "Limited"
        case .unsupported: return "N/A"
        }
    }

    var stars: Int {
        switch self {
        case .excellent: return 3
        case .good: return 2
        case .limited: return 1
        case .unsupported: return 0
        }
    }

    // Comparable conformance for sorting
    static func < (lhs: LanguageSupportLevel, rhs: LanguageSupportLevel) -> Bool {
        lhs.stars < rhs.stars
    }
}

// MARK: - Provider Language Capability

/// Provider capabilities for a specific language
struct ProviderLanguageCapability: Identifiable {
    let id = UUID()
    let provider: AIProvider
    let language: Language
    let transcriptionSupport: LanguageSupportLevel
    let translationSupport: LanguageSupportLevel
    let notes: String?  // e.g., "Best for formal Japanese"

    init(
        provider: AIProvider,
        language: Language,
        transcription: LanguageSupportLevel = .unsupported,
        translation: LanguageSupportLevel = .unsupported,
        notes: String? = nil
    ) {
        self.provider = provider
        self.language = language
        self.transcriptionSupport = transcription
        self.translationSupport = translation
        self.notes = notes
    }

    /// Get support level for a specific capability
    func supportLevel(for capability: ProviderUsageCategory) -> LanguageSupportLevel {
        switch capability {
        case .transcription: return transcriptionSupport
        case .translation, .powerMode: return translationSupport
        }
    }
}

// MARK: - Provider Language Database

/// Static data store for language support info
struct ProviderLanguageDatabase {

    // MARK: - Lookup Methods

    /// Get support level for a provider + language + capability combo
    static func supportLevel(
        provider: AIProvider,
        language: Language,
        for capability: ProviderUsageCategory
    ) -> LanguageSupportLevel {
        // Find the capability entry
        if let entry = allCapabilities.first(where: { $0.provider == provider && $0.language == language }) {
            return entry.supportLevel(for: capability)
        }

        // Default based on provider's general support
        switch capability {
        case .transcription:
            return provider.supportsTranscription ? .limited : .unsupported
        case .translation, .powerMode:
            return provider.supportsTranslation ? .limited : .unsupported
        }
    }

    /// Get all providers that support a language for a capability
    static func providers(
        supporting language: Language,
        for capability: ProviderUsageCategory,
        minimumLevel: LanguageSupportLevel = .limited
    ) -> [AIProvider] {
        return AIProvider.allCases.filter { provider in
            let level = supportLevel(provider: provider, language: language, for: capability)
            return level >= minimumLevel
        }
    }

    /// Get recommended provider for a language and capability
    static func recommendedProvider(
        for language: Language,
        capability: ProviderUsageCategory
    ) -> AIProvider? {
        // Find the provider with the best support for this language
        let ranked = AIProvider.allCases
            .filter { provider in
                switch capability {
                case .transcription: return provider.supportsTranscription
                case .translation, .powerMode: return provider.supportsTranslation
                }
            }
            .map { provider in
                (provider, supportLevel(provider: provider, language: language, for: capability))
            }
            .sorted { $0.1 > $1.1 }

        return ranked.first?.0
    }

    /// Get all languages supported by a provider for a capability
    static func languages(
        supportedBy provider: AIProvider,
        for capability: ProviderUsageCategory,
        minimumLevel: LanguageSupportLevel = .limited
    ) -> [Language] {
        return Language.allCases.filter { language in
            let level = supportLevel(provider: provider, language: language, for: capability)
            return level >= minimumLevel
        }
    }

    /// Get notes for a specific provider/language combination
    static func notes(for provider: AIProvider, language: Language) -> String? {
        return allCapabilities
            .first(where: { $0.provider == provider && $0.language == language })?
            .notes
    }

    /// Get all capabilities for a language (for the language support view)
    static func capabilities(for language: Language) -> [ProviderLanguageCapability] {
        return allCapabilities.filter { $0.language == language }
    }

    /// Check if a language is a "popular" language (for featured display)
    static func isPopularLanguage(_ language: Language) -> Bool {
        popularLanguages.contains(language)
    }

    // MARK: - Static Data

    /// Popular languages to feature at the top
    static let popularLanguages: [Language] = [
        .english, .spanish, .french, .german, .chinese, .japanese, .korean, .arabic, .polish
    ]

    /// All provider-language capabilities (hardcoded data)
    static let allCapabilities: [ProviderLanguageCapability] = {
        var caps: [ProviderLanguageCapability] = []

        // OpenAI - Excellent across the board for most languages
        for lang in Language.allCases {
            caps.append(ProviderLanguageCapability(
                provider: .openAI,
                language: lang,
                transcription: openAITranscriptionSupport(for: lang),
                translation: openAITranslationSupport(for: lang),
                notes: openAINotes(for: lang)
            ))
        }

        // Anthropic - Translation only, good for major languages
        for lang in Language.allCases {
            caps.append(ProviderLanguageCapability(
                provider: .anthropic,
                language: lang,
                transcription: .unsupported,
                translation: anthropicTranslationSupport(for: lang),
                notes: nil
            ))
        }

        // Google - Excellent translation, good STT
        for lang in Language.allCases {
            caps.append(ProviderLanguageCapability(
                provider: .google,
                language: lang,
                transcription: googleTranscriptionSupport(for: lang),
                translation: .excellent, // Google has excellent coverage
                notes: nil
            ))
        }

        // Deepgram - Fast transcription, varies by language
        for lang in Language.allCases {
            caps.append(ProviderLanguageCapability(
                provider: .deepgram,
                language: lang,
                transcription: deepgramTranscriptionSupport(for: lang),
                translation: .unsupported,
                notes: nil
            ))
        }

        // ElevenLabs - Speech recognition, 29 languages
        for lang in Language.allCases {
            caps.append(ProviderLanguageCapability(
                provider: .elevenLabs,
                language: lang,
                transcription: elevenLabsTranscriptionSupport(for: lang),
                translation: .unsupported,
                notes: nil
            ))
        }

        // AssemblyAI - Transcription only
        for lang in Language.allCases {
            caps.append(ProviderLanguageCapability(
                provider: .assemblyAI,
                language: lang,
                transcription: assemblyAITranscriptionSupport(for: lang),
                translation: .unsupported,
                notes: nil
            ))
        }

        // DeepL - Translation only, excellent quality
        for lang in Language.allCases {
            caps.append(ProviderLanguageCapability(
                provider: .deepL,
                language: lang,
                transcription: .unsupported,
                translation: deepLTranslationSupport(for: lang),
                notes: lang == .chinese ? "Simplified Chinese" : nil
            ))
        }

        // Azure - Translation with excellent coverage
        for lang in Language.allCases {
            caps.append(ProviderLanguageCapability(
                provider: .azure,
                language: lang,
                transcription: .unsupported,
                translation: .excellent, // Azure has 100+ languages
                notes: nil
            ))
        }

        // Local - Varies by model
        for lang in Language.allCases {
            caps.append(ProviderLanguageCapability(
                provider: .local,
                language: lang,
                transcription: localTranscriptionSupport(for: lang),
                translation: localTranslationSupport(for: lang),
                notes: "Quality varies by model"
            ))
        }

        return caps
    }()

    // MARK: - Provider-Specific Support Helpers

    private static func openAITranscriptionSupport(for language: Language) -> LanguageSupportLevel {
        // Whisper supports 50+ languages with excellent quality
        return .excellent
    }

    private static func openAITranslationSupport(for language: Language) -> LanguageSupportLevel {
        // GPT-4 has excellent translation for most languages
        switch language {
        case .english, .spanish, .french, .german, .italian, .portuguese,
             .chinese, .japanese, .korean, .russian, .arabic, .polish:
            return .excellent
        case .egyptianArabic:
            return .good // Dialect may have minor issues
        }
    }

    private static func openAINotes(for language: Language) -> String? {
        switch language {
        case .japanese: return "Excellent for keigo (formal) and casual"
        case .arabic: return "Full RTL support"
        case .chinese: return "Supports both simplified and traditional"
        default: return nil
        }
    }

    private static func anthropicTranslationSupport(for language: Language) -> LanguageSupportLevel {
        switch language {
        case .english, .spanish, .french, .german, .italian, .portuguese:
            return .excellent
        case .chinese, .japanese, .korean, .russian:
            return .good
        case .arabic, .polish:
            return .good
        case .egyptianArabic:
            return .limited
        }
    }

    private static func googleTranscriptionSupport(for language: Language) -> LanguageSupportLevel {
        // Google Cloud STT has good support
        switch language {
        case .english, .spanish, .french, .german:
            return .excellent
        case .chinese, .japanese, .korean, .italian, .portuguese, .russian:
            return .good
        case .arabic, .egyptianArabic, .polish:
            return .good
        }
    }

    private static func deepgramTranscriptionSupport(for language: Language) -> LanguageSupportLevel {
        switch language {
        case .english:
            return .excellent
        case .spanish, .french, .german, .italian, .portuguese:
            return .excellent
        case .japanese, .korean, .chinese:
            return .good
        case .arabic:
            return .good
        case .russian:
            return .good
        case .polish, .egyptianArabic:
            return .limited
        }
    }

    private static func elevenLabsTranscriptionSupport(for language: Language) -> LanguageSupportLevel {
        switch language {
        case .english, .spanish, .french, .german:
            return .excellent
        case .italian, .portuguese, .japanese, .korean, .chinese:
            return .good
        case .arabic, .russian, .polish:
            return .limited
        case .egyptianArabic:
            return .limited
        }
    }

    private static func assemblyAITranscriptionSupport(for language: Language) -> LanguageSupportLevel {
        // AssemblyAI supports: en, es, fr, de, it, pt, nl, hi, ja, zh, fi, ko, pl, ru, tr, uk, vi
        switch language {
        case .english:
            return .excellent
        case .spanish, .french, .german, .italian, .portuguese:
            return .excellent
        case .japanese, .korean, .chinese, .russian, .polish:
            return .good
        case .arabic, .egyptianArabic:
            return .unsupported // Not in AssemblyAI's supported list
        }
    }

    private static func deepLTranslationSupport(for language: Language) -> LanguageSupportLevel {
        // DeepL has excellent quality but limited language support
        switch language {
        case .english, .spanish, .french, .german, .italian, .portuguese,
             .polish, .russian, .japanese, .chinese, .korean:
            return .excellent
        case .arabic, .egyptianArabic:
            return .unsupported // DeepL doesn't support Arabic
        }
    }

    private static func localTranscriptionSupport(for language: Language) -> LanguageSupportLevel {
        // Local providers (Whisper models) vary
        switch language {
        case .english, .spanish, .french, .german:
            return .good
        default:
            return .limited
        }
    }

    private static func localTranslationSupport(for language: Language) -> LanguageSupportLevel {
        // Local LLMs vary significantly
        switch language {
        case .english, .spanish, .french, .german:
            return .good
        case .chinese, .japanese:
            return .limited
        default:
            return .limited
        }
    }
}

// MARK: - Preview Helpers

#Preview("Language Support Levels") {
    VStack(spacing: 16) {
        ForEach(LanguageSupportLevel.allCases, id: \.self) { level in
            HStack(spacing: 12) {
                Image(systemName: level.icon)
                    .foregroundStyle(level.color)
                    .frame(width: 24)

                Text(level.label)
                    .font(.callout)

                Spacer()

                HStack(spacing: 2) {
                    ForEach(0..<3) { i in
                        Image(systemName: i < level.stars ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundStyle(i < level.stars ? level.color : .secondary.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}
