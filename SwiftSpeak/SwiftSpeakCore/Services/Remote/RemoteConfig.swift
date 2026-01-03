//
//  RemoteConfig.swift
//  SwiftSpeak
//
//  Created by SwiftSpeak on 2024-12-28.
//

import Foundation

// MARK: - Root Configuration

/// Root structure for remote provider configuration
public struct RemoteProviderConfig: Codable, Equatable {
    public let version: String
    public let lastUpdated: Date
    public let schemaVersion: Int
    public let providers: [String: ProviderRemoteConfig]

    /// Get config for a specific provider
    public func config(for provider: AIProvider) -> ProviderRemoteConfig? {
        providers[provider.rawValue]
    }
}

// MARK: - Provider Configuration

/// Configuration for a single AI provider
public struct ProviderRemoteConfig: Codable, Equatable {
    public let displayName: String
    public let status: ProviderOperationalStatus
    public let transcription: CapabilityRemoteConfig?
    public let translation: CapabilityRemoteConfig?
    public let powerMode: CapabilityRemoteConfig?
    public let pricing: [String: PricingRemoteConfig]
    public let freeCredits: String?
    public let apiKeyUrl: String?
    public let notes: String?

    /// Check if provider supports a capability
    public func supports(_ capability: ProviderUsageCategory) -> Bool {
        switch capability {
        case .transcription:
            return transcription?.enabled ?? false
        case .translation:
            return translation?.enabled ?? false
        case .powerMode:
            return powerMode?.enabled ?? false
        }
    }

    /// Get capability config
    public func capability(_ type: ProviderUsageCategory) -> CapabilityRemoteConfig? {
        switch type {
        case .transcription: return transcription
        case .translation: return translation
        case .powerMode: return powerMode
        }
    }
}

// MARK: - Provider Status

/// Operational status of a provider
public enum ProviderOperationalStatus: String, Codable, Equatable {
    case operational
    case degraded
    case down
    case unknown

    public var displayName: String {
        switch self {
        case .operational: return "Operational"
        case .degraded: return "Degraded"
        case .down: return "Down"
        case .unknown: return "Unknown"
        }
    }

    public var iconName: String {
        switch self {
        case .operational: return "checkmark.circle.fill"
        case .degraded: return "exclamationmark.triangle.fill"
        case .down: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    public var isHealthy: Bool {
        self == .operational
    }
}

// MARK: - Capability Configuration

/// Configuration for a specific capability (transcription, translation, powerMode)
public struct CapabilityRemoteConfig: Codable, Equatable {
    public let enabled: Bool
    public let models: [ModelRemoteConfig]?
    public let languages: [String: String]?  // languageCode -> supportLevel ("excellent", "good", "basic")
    public let features: [String]?

    /// Get default model for this capability
    public var defaultModel: ModelRemoteConfig? {
        models?.first { $0.isDefault == true } ?? models?.first
    }

    /// Get language support level
    public func languageSupport(for language: Language) -> LanguageSupportLevel {
        guard let levelString = languages?[language.rawValue] else {
            return .unsupported
        }
        return LanguageSupportLevel(rawValue: levelString) ?? .limited
    }

    /// Check if language is supported
    public func supportsLanguage(_ language: Language) -> Bool {
        languages?[language.rawValue] != nil
    }

    /// Get all supported languages
    public var supportedLanguages: [Language] {
        guard let languages = languages else { return [] }
        return languages.keys.compactMap { Language(rawValue: $0) }
    }
}

// MARK: - Model Configuration

/// Configuration for a specific model
public struct ModelRemoteConfig: Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let isDefault: Bool?
    public let tier: String?  // "power" for premium-tier-only models

    /// Whether this model requires Power subscription tier
    public var isPowerTier: Bool {
        tier == "power"
    }

    /// Whether this model requires Pro subscription tier
    public var isProTier: Bool {
        tier == "pro"
    }
}

// MARK: - Pricing Configuration

/// Pricing information for a model
public struct PricingRemoteConfig: Codable, Equatable {
    // Per-unit pricing (for transcription, character-based)
    public let unit: String?           // "minute", "second", "character", "15seconds"
    public let cost: Double?

    // Token-based pricing (for LLMs)
    public let inputPerMToken: Double?
    public let outputPerMToken: Double?

    /// Human-readable pricing string
    public var displayString: String {
        if let cost = cost, let unit = unit {
            return String(format: "$%.4f/%@", cost, unit)
        } else if let input = inputPerMToken, let output = outputPerMToken {
            return String(format: "$%.2f/$%.2f per 1M tokens (in/out)", input, output)
        }
        return "Free"
    }

    /// Estimated cost per minute of dictation
    /// Used for rough cost comparisons between providers
    public var estimatedCostPerMinute: Double {
        if let cost = cost, let unit = unit {
            switch unit {
            case "minute": return cost
            case "second": return cost * 60
            case "15seconds": return cost * 4  // 4 x 15-second chunks per minute
            case "character": return cost * 500  // ~500 chars per minute of speech
            default: return cost
            }
        } else if let input = inputPerMToken, let output = outputPerMToken {
            // Estimate ~100 input tokens, ~150 output tokens per minute of dictation
            let inputCost = input * 100 / 1_000_000
            let outputCost = output * 150 / 1_000_000
            return inputCost + outputCost
        }
        return 0
    }

    /// Whether this is a per-unit pricing model (vs token-based)
    public var isUnitBased: Bool {
        unit != nil && cost != nil
    }

    /// Whether this is a token-based pricing model
    public var isTokenBased: Bool {
        inputPerMToken != nil && outputPerMToken != nil
    }
}

// NOTE: LanguageSupportLevel is defined in ProviderLanguageSupport.swift (shared across app)
// NOTE: CostBreakdown is defined in Models.swift (shared with keyboard extension)
// NOTE: Double cost formatting extensions are defined in Models.swift
