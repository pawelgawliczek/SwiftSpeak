//
//  Language.swift
//  SwiftSpeak
//
//  Language definitions and provider-specific codes
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

// MARK: - Language
public enum Language: String, Codable, CaseIterable, Identifiable {
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

    public var id: String { rawValue }

    public var displayName: String {
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

    public var flag: String {
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

    // MARK: - Provider-specific language codes

    /// DeepL uses uppercase language codes
    public var deepLCode: String {
        switch self {
        case .english: return "EN"
        case .spanish: return "ES"
        case .french: return "FR"
        case .german: return "DE"
        case .italian: return "IT"
        case .portuguese: return "PT"
        case .chinese: return "ZH"
        case .japanese: return "JA"
        case .korean: return "KO"
        case .arabic: return "AR"
        case .egyptianArabic: return "AR"  // DeepL doesn't distinguish Egyptian Arabic
        case .russian: return "RU"
        case .polish: return "PL"
        }
    }

    /// Google Cloud uses lowercase ISO codes
    public var googleCode: String {
        switch self {
        case .english: return "en"
        case .spanish: return "es"
        case .french: return "fr"
        case .german: return "de"
        case .italian: return "it"
        case .portuguese: return "pt"
        case .chinese: return "zh"
        case .japanese: return "ja"
        case .korean: return "ko"
        case .arabic: return "ar"
        case .egyptianArabic: return "ar"  // Use standard Arabic for Google
        case .russian: return "ru"
        case .polish: return "pl"
        }
    }

    /// Azure Translator uses lowercase ISO codes (same as Google)
    public var azureCode: String {
        googleCode
    }

    /// AssemblyAI language codes - returns nil for unsupported languages
    /// AssemblyAI supports: en, es, fr, de, it, pt, nl, hi, ja, zh, fi, ko, pl, ru, tr, uk, vi
    public var assemblyAICode: String? {
        switch self {
        case .english: return "en"
        case .spanish: return "es"
        case .french: return "fr"
        case .german: return "de"
        case .italian: return "it"
        case .portuguese: return "pt"
        case .chinese: return "zh"
        case .japanese: return "ja"
        case .korean: return "ko"
        case .russian: return "ru"
        case .polish: return "pl"
        case .arabic, .egyptianArabic: return nil  // Not supported by AssemblyAI
        }
    }

    /// Google Cloud Speech-to-Text uses BCP-47 codes
    public var googleSTTCode: String {
        switch self {
        case .english: return "en-US"
        case .spanish: return "es-ES"
        case .french: return "fr-FR"
        case .german: return "de-DE"
        case .italian: return "it-IT"
        case .portuguese: return "pt-BR"
        case .chinese: return "zh-CN"
        case .japanese: return "ja-JP"
        case .korean: return "ko-KR"
        case .arabic: return "ar-SA"
        case .egyptianArabic: return "ar-EG"
        case .russian: return "ru-RU"
        case .polish: return "pl-PL"
        }
    }
}
