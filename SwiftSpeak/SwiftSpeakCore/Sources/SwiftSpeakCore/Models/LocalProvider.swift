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
public enum LocalModelType: String, Codable, CaseIterable, Identifiable {
    case whisperKit = "whisperkit"
    case appleIntelligence = "apple_intelligence"
    case appleTranslation = "apple_translation"
    case ollama = "ollama"
    case lmStudio = "lm_studio"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .whisperKit: return "WhisperKit"
        case .appleIntelligence: return "Apple Intelligence"
        case .appleTranslation: return "Apple Translation"
        case .ollama: return "Ollama"
        case .lmStudio: return "LM Studio"
        }
    }

    public var icon: String {
        switch self {
        case .whisperKit: return "mic.fill"
        case .appleIntelligence: return "brain.head.profile"
        case .appleTranslation: return "globe"
        case .ollama: return "desktopcomputer"
        case .lmStudio: return "display"
        }
    }

    public var description: String {
        switch self {
        case .whisperKit: return "On-device speech recognition"
        case .appleIntelligence: return "On-device text processing"
        case .appleTranslation: return "On-device translation"
        case .ollama: return "Self-hosted open-source LLMs"
        case .lmStudio: return "Local AI server with GUI"
        }
    }

    /// Whether this type runs on-device (vs self-hosted on network)
    public var isOnDevice: Bool {
        switch self {
        case .whisperKit, .appleIntelligence, .appleTranslation: return true
        case .ollama, .lmStudio: return false
        }
    }

    /// Capabilities this local model type supports
    public var supportedCategories: Set<ProviderUsageCategory> {
        switch self {
        case .whisperKit: return [.transcription]
        case .appleIntelligence: return [.powerMode]  // Formatting
        case .appleTranslation: return [.translation]
        case .ollama, .lmStudio: return [.transcription, .translation, .powerMode]
        }
    }
}

/// Status of a local model
public enum LocalModelStatus: String, Codable {
    case notConfigured = "not_configured"
    case downloading = "downloading"
    case ready = "ready"
    case notAvailable = "not_available"  // Device/OS doesn't support
    case error = "error"

    public var displayName: String {
        switch self {
        case .notConfigured: return "Not Set Up"
        case .downloading: return "Downloading"
        case .ready: return "Ready"
        case .notAvailable: return "Not Available"
        case .error: return "Error"
        }
    }

    public var icon: String {
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
public enum WhisperModel: String, Codable, CaseIterable, Identifiable {
    case tinyEn = "tiny.en"
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"
    case large = "large"
    case largeV2 = "large-v2"
    case largeV3 = "large-v3"
    case largeV3Turbo = "large-v3-turbo"

    public var id: String { rawValue }

    public var displayName: String {
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

    public var description: String {
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
    public var sizeBytes: Int {
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

    public var sizeFormatted: String {
        let mb = Double(sizeBytes) / (1024 * 1024)
        if mb >= 1000 {
            return String(format: "%.1f GB", mb / 1024)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }

    /// Whether this model supports English only
    public var isEnglishOnly: Bool {
        self == .tinyEn
    }

    /// Minimum chip generation recommended for this model
    /// A12 = iPhone XR/XS, A14 = iPhone 12, A15 = iPhone 13, A16 = iPhone 14 Pro, A17 = iPhone 15 Pro
    public var minimumChipGeneration: Int {
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
    public func isRecommendedForChip(_ chipGeneration: Int) -> Bool {
        chipGeneration >= minimumChipGeneration
    }

    /// Whether this model may have performance issues on the device
    public func mayHavePerformanceIssues(_ chipGeneration: Int) -> Bool {
        chipGeneration < minimumChipGeneration && chipGeneration >= minimumChipGeneration - 1
    }

    /// Whether this model is not recommended for the device
    public func isNotRecommended(_ chipGeneration: Int) -> Bool {
        chipGeneration < minimumChipGeneration - 1
    }

    /// Default model for a given chip generation
    public static func recommendedModel(forChipGeneration chipGeneration: Int) -> WhisperModel {
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
    public var supportedLanguages: [Language] {
        if isEnglishOnly {
            return [.english]
        }
        return Language.allCases
    }

    /// Get support level for a specific language
    /// Based on OpenAI Whisper model benchmarks
    public func languageSupportLevel(for language: Language) -> LanguageSupportLevel {
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
    public func supportsLanguage(_ language: Language) -> Bool {
        languageSupportLevel(for: language) != .unsupported
    }

    /// All languages with at least limited support
    public var languagesWithSupport: [Language] {
        Language.allCases.filter { languageSupportLevel(for: $0) != .unsupported }
    }

    /// Languages with excellent or good support (recommended for use)
    public var recommendedLanguages: [Language] {
        Language.allCases.filter {
            let level = languageSupportLevel(for: $0)
            return level == .excellent || level == .good
        }
    }
}

/// Configuration for WhisperKit on-device transcription
/// Note: Named "Settings" to avoid conflict with WhisperKit library's WhisperKitConfig class
public struct WhisperKitSettings: Codable, Equatable {
    public var selectedModel: WhisperModel
    public var status: LocalModelStatus
    public var downloadProgress: Double  // 0.0 - 1.0
    public var downloadedBytes: Int
    public var lastDownloadDate: Date?
    public var isEnabled: Bool

    public init(
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

    public static var `default`: WhisperKitSettings {
        WhisperKitSettings()
    }
}

// MARK: - Parakeet MLX (macOS only)

/// Output format for Parakeet MLX transcription
public enum ParakeetOutputFormat: String, Codable, CaseIterable {
    case text = "txt"
    case json = "json"

    public var displayName: String {
        switch self {
        case .text: return "Plain Text"
        case .json: return "JSON"
        }
    }
}

/// Configuration for Parakeet MLX on-device transcription (macOS only)
/// Uses the parakeet-mlx Python package via CLI
public struct ParakeetMLXSettings: Codable, Equatable {
    public var isEnabled: Bool
    public var status: LocalModelStatus
    public var modelId: String
    public var outputFormat: ParakeetOutputFormat
    public var errorMessage: String?

    public init(
        isEnabled: Bool = false,
        status: LocalModelStatus = .notConfigured,
        modelId: String = "mlx-community/parakeet-tdt-0.6b-v3",
        outputFormat: ParakeetOutputFormat = .text,
        errorMessage: String? = nil
    ) {
        self.isEnabled = isEnabled
        self.status = status
        self.modelId = modelId
        self.outputFormat = outputFormat
        self.errorMessage = errorMessage
    }

    public static var `default`: ParakeetMLXSettings {
        ParakeetMLXSettings()
    }

    /// Default as not available (for iOS where parakeet-mlx cannot run)
    public static var notAvailable: ParakeetMLXSettings {
        ParakeetMLXSettings(status: .notAvailable)
    }
}

// MARK: - Phase 10: Apple Intelligence

/// Configuration for Apple Intelligence on-device text processing
public struct AppleIntelligenceConfig: Codable, Equatable {
    public var isEnabled: Bool
    public var isAvailable: Bool  // Determined by device/OS check
    public var unavailableReason: String?  // "Requires iPhone 15 Pro" etc.

    public init(
        isEnabled: Bool = false,
        isAvailable: Bool = false,
        unavailableReason: String? = nil
    ) {
        self.isEnabled = isEnabled
        self.isAvailable = isAvailable
        self.unavailableReason = unavailableReason
    }

    public static var `default`: AppleIntelligenceConfig {
        AppleIntelligenceConfig()
    }
}

// MARK: - Phase 10: Apple Translation

/// Downloaded language for Apple Translation
public struct DownloadedTranslationLanguage: Codable, Identifiable, Equatable {
    public var id: String { language.rawValue }
    public var language: Language
    public var sizeBytes: Int
    public var isSystem: Bool  // System language, can't be removed

    public init(language: Language, sizeBytes: Int, isSystem: Bool) {
        self.language = language
        self.sizeBytes = sizeBytes
        self.isSystem = isSystem
    }

    public var sizeFormatted: String {
        let mb = Double(sizeBytes) / (1024 * 1024)
        return String(format: "%.0f MB", mb)
    }
}

/// Configuration for Apple Translation
public struct AppleTranslationConfig: Codable, Equatable {
    public var isAvailable: Bool  // iOS 17.4+
    public var downloadedLanguages: [DownloadedTranslationLanguage]

    public init(
        isAvailable: Bool = true,
        downloadedLanguages: [DownloadedTranslationLanguage] = []
    ) {
        self.isAvailable = isAvailable
        self.downloadedLanguages = downloadedLanguages
    }

    public static var `default`: AppleTranslationConfig {
        AppleTranslationConfig()
    }
}
