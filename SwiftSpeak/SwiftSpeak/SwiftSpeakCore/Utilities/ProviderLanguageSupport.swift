//
//  ProviderLanguageSupport.swift
//  SwiftSpeak
//
//  Language support data model and database for provider compatibility
//
//  SINGLE SOURCE OF TRUTH: All language support data comes from RemoteConfigManager
//  which loads from:
//    1. Cached config (from last successful Firebase fetch)
//    2. Firebase Remote Config (fetched on app launch)
//    3. Bundled fallback-provider-config.json (if no cache/network)
//

import SwiftUI

// MARK: - Language Support Level

/// Language support level for a provider
public enum LanguageSupportLevel: String, Codable, CaseIterable, Comparable {
    case excellent    // Native-level quality
    case good         // Minor occasional errors
    case limited      // Works but not recommended
    case unsupported  // Does not work

    public var icon: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .limited: return "exclamationmark.triangle.fill"
        case .unsupported: return "xmark.circle.fill"
        }
    }

    public var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .limited: return .orange
        case .unsupported: return .red
        }
    }

    public var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .limited: return "Limited"
        case .unsupported: return "Not Supported"
        }
    }

    public var shortLabel: String {
        switch self {
        case .excellent: return "Best"
        case .good: return "Good"
        case .limited: return "Limited"
        case .unsupported: return "N/A"
        }
    }

    public var stars: Int {
        switch self {
        case .excellent: return 3
        case .good: return 2
        case .limited: return 1
        case .unsupported: return 0
        }
    }

    // Comparable conformance for sorting
    public static func < (lhs: LanguageSupportLevel, rhs: LanguageSupportLevel) -> Bool {
        lhs.stars < rhs.stars
    }
}

// MARK: - Provider Language Capability

/// Provider capabilities for a specific language
public struct ProviderLanguageCapability: Identifiable {
    public let id = UUID()
    public let provider: AIProvider
    public let language: Language
    public let transcriptionSupport: LanguageSupportLevel
    public let translationSupport: LanguageSupportLevel
    public let notes: String?  // e.g., "Best for formal Japanese"

    public init(
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
    public func supportLevel(for capability: ProviderUsageCategory) -> LanguageSupportLevel {
        switch capability {
        case .transcription: return transcriptionSupport
        case .translation, .powerMode: return translationSupport
        }
    }
}

// MARK: - Provider Language Database

/// Data access layer for language support information
/// All data comes from RemoteConfigManager (single source of truth)
///
/// Note: This is only available in the main app, not the keyboard extension.
/// The keyboard extension doesn't need language support lookups.
#if !KEYBOARD_EXTENSION

public struct ProviderLanguageDatabase {

    // MARK: - Lookup Methods

    /// Get support level for a provider + language + capability combo
    @MainActor
    public static func supportLevel(
        provider: AIProvider,
        language: Language,
        for capability: ProviderUsageCategory
    ) -> LanguageSupportLevel {
        // Query RemoteConfigManager (single source of truth)
        return RemoteConfigManager.shared.languageSupport(
            for: provider,
            capability: capability,
            language: language
        )
    }

    /// Get all providers that support a language for a capability
    @MainActor
    public static func providers(
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
    @MainActor
    public static func recommendedProvider(
        for language: Language,
        capability: ProviderUsageCategory
    ) -> AIProvider? {
        // Find the provider with the best support for this language
        let ranked = AIProvider.allCases
            .filter { provider in
                RemoteConfigManager.shared.providerSupports(provider, capability: capability)
            }
            .map { provider in
                (provider, supportLevel(provider: provider, language: language, for: capability))
            }
            .sorted { $0.1 > $1.1 }

        return ranked.first?.0
    }

    /// Get all languages supported by a provider for a capability
    @MainActor
    public static func languages(
        supportedBy provider: AIProvider,
        for capability: ProviderUsageCategory,
        minimumLevel: LanguageSupportLevel = .limited
    ) -> [Language] {
        return Language.allCases.filter { language in
            let level = supportLevel(provider: provider, language: language, for: capability)
            return level >= minimumLevel
        }
    }

    /// Get notes for a specific provider (from remote config)
    @MainActor
    public static func notes(for provider: AIProvider) -> String? {
        return RemoteConfigManager.shared.providerConfig(for: provider)?.notes
    }

    /// Get all capabilities for a language (for the language support view)
    @MainActor
    public static func capabilities(for language: Language) -> [ProviderLanguageCapability] {
        return AIProvider.allCases.map { provider in
            ProviderLanguageCapability(
                provider: provider,
                language: language,
                transcription: supportLevel(provider: provider, language: language, for: .transcription),
                translation: supportLevel(provider: provider, language: language, for: .translation),
                notes: notes(for: provider)
            )
        }
    }

    /// Check if a language is a "popular" language (for featured display)
    public static func isPopularLanguage(_ language: Language) -> Bool {
        popularLanguages.contains(language)
    }

    // MARK: - Static Configuration

    /// Popular languages to feature at the top (UI preference, not from remote config)
    public static let popularLanguages: [Language] = [
        .english, .spanish, .french, .german, .chinese, .japanese, .korean, .arabic, .polish
    ]
}

#endif

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
