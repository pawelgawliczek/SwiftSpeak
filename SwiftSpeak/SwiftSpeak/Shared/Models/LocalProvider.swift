//
//  LocalProvider.swift
//  SwiftSpeak
//
//  Local/on-device AI provider models (WhisperKit, Apple Intelligence, etc.)
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

// MARK: - Phase 10: Local Provider Types

/// Types of local/on-device AI providers
enum LocalModelType: String, Codable, CaseIterable, Identifiable {
    case whisperKit = "whisperkit"
    case appleIntelligence = "apple_intelligence"
    case appleTranslation = "apple_translation"
    case ollama = "ollama"
    case lmStudio = "lm_studio"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .whisperKit: return "WhisperKit"
        case .appleIntelligence: return "Apple Intelligence"
        case .appleTranslation: return "Apple Translation"
        case .ollama: return "Ollama"
        case .lmStudio: return "LM Studio"
        }
    }

    var icon: String {
        switch self {
        case .whisperKit: return "mic.fill"
        case .appleIntelligence: return "brain.head.profile"
        case .appleTranslation: return "globe"
        case .ollama: return "desktopcomputer"
        case .lmStudio: return "display"
        }
    }

    var description: String {
        switch self {
        case .whisperKit: return "On-device speech recognition"
        case .appleIntelligence: return "On-device text processing"
        case .appleTranslation: return "On-device translation"
        case .ollama: return "Self-hosted open-source LLMs"
        case .lmStudio: return "Local AI server with GUI"
        }
    }

    /// Whether this type runs on-device (vs self-hosted on network)
    var isOnDevice: Bool {
        switch self {
        case .whisperKit, .appleIntelligence, .appleTranslation: return true
        case .ollama, .lmStudio: return false
        }
    }

    /// Capabilities this local model type supports
    var supportedCategories: Set<ProviderUsageCategory> {
        switch self {
        case .whisperKit: return [.transcription]
        case .appleIntelligence: return [.powerMode]  // Formatting
        case .appleTranslation: return [.translation]
        case .ollama, .lmStudio: return [.transcription, .translation, .powerMode]
        }
    }
}

/// Status of a local model
enum LocalModelStatus: String, Codable {
    case notConfigured = "not_configured"
    case downloading = "downloading"
    case ready = "ready"
    case notAvailable = "not_available"  // Device/OS doesn't support
    case error = "error"

    var displayName: String {
        switch self {
        case .notConfigured: return "Not Set Up"
        case .downloading: return "Downloading"
        case .ready: return "Ready"
        case .notAvailable: return "Not Available"
        case .error: return "Error"
        }
    }

    var icon: String {
        switch self {
        case .notConfigured: return "circle.dashed"
        case .downloading: return "arrow.down.circle"
        case .ready: return "checkmark.circle.fill"
        case .notAvailable: return "xmark.circle"
        case .error: return "exclamationmark.triangle"
        }
    }
}

// MARK: - Phase 10: WhisperKit Models

/// Available WhisperKit model sizes
enum WhisperModel: String, Codable, CaseIterable, Identifiable {
    case tinyEn = "tiny.en"
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"
    case large = "large"
    case largeV2 = "large-v2"
    case largeV3 = "large-v3"
    case largeV3Turbo = "large-v3-turbo"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tinyEn: return "tiny.en"
        case .tiny: return "tiny"
        case .base: return "base"
        case .small: return "small"
        case .medium: return "medium"
        case .large: return "large"
        case .largeV2: return "large-v2"
        case .largeV3: return "large-v3"
        case .largeV3Turbo: return "large-v3-turbo"
        }
    }

    var description: String {
        switch self {
        case .tinyEn: return "English only · Fastest"
        case .tiny: return "All languages · Fastest"
        case .base: return "All languages · Fast"
        case .small: return "All languages · Balanced"
        case .medium: return "All languages · Good accuracy"
        case .large: return "All languages · High accuracy"
        case .largeV2: return "All languages · Higher accuracy"
        case .largeV3: return "All languages · Best accuracy"
        case .largeV3Turbo: return "All languages · Fast & accurate"
        }
    }

    /// Approximate model size in bytes
    var sizeBytes: Int {
        switch self {
        case .tinyEn: return 39 * 1024 * 1024      // 39 MB
        case .tiny: return 39 * 1024 * 1024        // 39 MB
        case .base: return 142 * 1024 * 1024       // 142 MB
        case .small: return 466 * 1024 * 1024      // 466 MB
        case .medium: return 1500 * 1024 * 1024    // 1.5 GB
        case .large: return 2900 * 1024 * 1024     // 2.9 GB
        case .largeV2: return 2900 * 1024 * 1024   // 2.9 GB
        case .largeV3: return 1500 * 1024 * 1024   // 1.5 GB (optimized)
        case .largeV3Turbo: return 809 * 1024 * 1024 // 809 MB
        }
    }

    var sizeFormatted: String {
        let mb = Double(sizeBytes) / (1024 * 1024)
        if mb >= 1000 {
            return String(format: "%.1f GB", mb / 1024)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }

    /// Whether this model supports English only
    var isEnglishOnly: Bool {
        self == .tinyEn
    }

    /// Minimum chip generation recommended for this model
    /// A12 = iPhone XR/XS, A14 = iPhone 12, A15 = iPhone 13, A16 = iPhone 14 Pro, A17 = iPhone 15 Pro
    var minimumChipGeneration: Int {
        switch self {
        case .tinyEn, .tiny: return 12    // A12+
        case .base: return 12             // A12+
        case .small: return 14            // A14+
        case .medium: return 15           // A15+
        case .large, .largeV2: return 17  // A17 Pro+
        case .largeV3: return 16          // A16+
        case .largeV3Turbo: return 15     // A15+
        }
    }

    /// Whether this model is recommended for the current device
    func isRecommendedForChip(_ chipGeneration: Int) -> Bool {
        chipGeneration >= minimumChipGeneration
    }

    /// Whether this model may have performance issues on the device
    func mayHavePerformanceIssues(_ chipGeneration: Int) -> Bool {
        chipGeneration < minimumChipGeneration && chipGeneration >= minimumChipGeneration - 1
    }

    /// Whether this model is not recommended for the device
    func isNotRecommended(_ chipGeneration: Int) -> Bool {
        chipGeneration < minimumChipGeneration - 1
    }

    /// Default model for a given chip generation
    static func recommendedModel(forChipGeneration chipGeneration: Int) -> WhisperModel {
        switch chipGeneration {
        case 17...: return .largeV3        // A17 Pro+
        case 16: return .largeV3           // A16
        case 15: return .largeV3Turbo      // A15
        case 14: return .small             // A14
        default: return .tinyEn            // A12-A13
        }
    }

    // MARK: - Language Support

    /// Languages supported by this model
    /// Whisper supports 99 languages, but quality varies
    /// English-only models only support English
    var supportedLanguages: [Language] {
        if isEnglishOnly {
            return [.english]
        }
        return Language.allCases
    }

    /// Get support level for a specific language
    /// Based on OpenAI Whisper model benchmarks
    func languageSupportLevel(for language: Language) -> LanguageSupportLevel {
        if isEnglishOnly {
            return language == .english ? .excellent : .unsupported
        }

        // Larger models have better accuracy across all languages
        let baseLevel = modelQualityTier

        // Language-specific adjustments based on Whisper training data representation
        switch language {
        case .english:
            return .excellent  // English is always excellent for non-EN models too
        case .spanish, .french, .german, .italian, .portuguese:
            return baseLevel   // Well-represented in training
        case .chinese, .japanese, .korean:
            return baseLevel == .excellent ? .excellent : .good
        case .russian, .polish:
            return baseLevel == .excellent ? .excellent : .good
        case .arabic:
            return baseLevel == .excellent ? .good : .limited
        case .egyptianArabic:
            return baseLevel == .excellent ? .limited : .limited
        }
    }

    /// Quality tier based on model size
    private var modelQualityTier: LanguageSupportLevel {
        switch self {
        case .tinyEn, .tiny:
            return .limited
        case .base:
            return .limited
        case .small:
            return .good
        case .medium:
            return .good
        case .large, .largeV2, .largeV3, .largeV3Turbo:
            return .excellent
        }
    }

    /// Check if a language is supported
    func supportsLanguage(_ language: Language) -> Bool {
        languageSupportLevel(for: language) != .unsupported
    }

    /// All languages with at least limited support
    var languagesWithSupport: [Language] {
        Language.allCases.filter { languageSupportLevel(for: $0) != .unsupported }
    }

    /// Languages with excellent or good support (recommended for use)
    var recommendedLanguages: [Language] {
        Language.allCases.filter {
            let level = languageSupportLevel(for: $0)
            return level == .excellent || level == .good
        }
    }
}

/// Configuration for WhisperKit on-device transcription
/// Note: Named "Settings" to avoid conflict with WhisperKit library's WhisperKitConfig class
struct WhisperKitSettings: Codable, Equatable {
    var selectedModel: WhisperModel
    var status: LocalModelStatus
    var downloadProgress: Double  // 0.0 - 1.0
    var downloadedBytes: Int
    var lastDownloadDate: Date?
    var isEnabled: Bool

    init(
        selectedModel: WhisperModel = .largeV3,
        status: LocalModelStatus = .notConfigured,
        downloadProgress: Double = 0,
        downloadedBytes: Int = 0,
        lastDownloadDate: Date? = nil,
        isEnabled: Bool = false
    ) {
        self.selectedModel = selectedModel
        self.status = status
        self.downloadProgress = downloadProgress
        self.downloadedBytes = downloadedBytes
        self.lastDownloadDate = lastDownloadDate
        self.isEnabled = isEnabled
    }

    static var `default`: WhisperKitSettings {
        WhisperKitSettings()
    }
}

// MARK: - Phase 10: Apple Intelligence

/// Configuration for Apple Intelligence on-device text processing
struct AppleIntelligenceConfig: Codable, Equatable {
    var isEnabled: Bool
    var isAvailable: Bool  // Determined by device/OS check
    var unavailableReason: String?  // "Requires iPhone 15 Pro" etc.

    init(
        isEnabled: Bool = false,
        isAvailable: Bool = false,
        unavailableReason: String? = nil
    ) {
        self.isEnabled = isEnabled
        self.isAvailable = isAvailable
        self.unavailableReason = unavailableReason
    }

    static var `default`: AppleIntelligenceConfig {
        AppleIntelligenceConfig()
    }
}

// MARK: - Phase 10: Apple Translation

/// Downloaded language for Apple Translation
struct DownloadedTranslationLanguage: Codable, Identifiable, Equatable {
    var id: String { language.rawValue }
    var language: Language
    var sizeBytes: Int
    var isSystem: Bool  // System language, can't be removed

    var sizeFormatted: String {
        let mb = Double(sizeBytes) / (1024 * 1024)
        return String(format: "%.0f MB", mb)
    }
}

/// Configuration for Apple Translation
struct AppleTranslationConfig: Codable, Equatable {
    var isAvailable: Bool  // iOS 17.4+
    var downloadedLanguages: [DownloadedTranslationLanguage]

    init(
        isAvailable: Bool = true,
        downloadedLanguages: [DownloadedTranslationLanguage] = []
    ) {
        self.isAvailable = isAvailable
        self.downloadedLanguages = downloadedLanguages
    }

    static var `default`: AppleTranslationConfig {
        AppleTranslationConfig()
    }
}
