//
//  ConfigChangeDetector.swift
//  SwiftSpeak
//
//  Created by SwiftSpeak on 2024-12-28.
//

import Foundation

// MARK: - Config Change Detector

/// Detects meaningful changes between remote config versions
public struct ConfigChangeDetector {

    /// Detect changes between old and new config, filtered by user's providers
    /// - Parameters:
    ///   - old: Previous config (nil on first fetch)
    ///   - new: New config from remote
    ///   - userProviders: Providers the user has configured
    /// - Returns: List of changes relevant to the user
    public func detectChanges(
        old: RemoteProviderConfig?,
        new: RemoteProviderConfig,
        userProviders: [AIProvider]
    ) -> [ConfigChange] {
        guard let old = old else { return [] }

        var changes: [ConfigChange] = []

        for provider in userProviders {
            guard let oldProvider = old.providers[provider.rawValue],
                  let newProvider = new.providers[provider.rawValue] else {
                continue
            }

            // Check status changes
            if oldProvider.status != newProvider.status {
                changes.append(.statusChange(
                    provider: provider,
                    oldStatus: oldProvider.status,
                    newStatus: newProvider.status
                ))
            }

            // Check each capability
            for capability in ProviderUsageCategory.allCases {
                let oldCap = oldProvider.capability(capability)
                let newCap = newProvider.capability(capability)

                // New languages
                changes.append(contentsOf: detectNewLanguages(
                    provider: provider,
                    capability: capability,
                    oldCap: oldCap,
                    newCap: newCap
                ))

                // Language quality improvements
                changes.append(contentsOf: detectLanguageQualityChanges(
                    provider: provider,
                    capability: capability,
                    oldCap: oldCap,
                    newCap: newCap
                ))

                // New models
                changes.append(contentsOf: detectNewModels(
                    provider: provider,
                    capability: capability,
                    oldCap: oldCap,
                    newCap: newCap
                ))
            }

            // Check pricing changes
            changes.append(contentsOf: detectPricingChanges(
                provider: provider,
                oldPricing: oldProvider.pricing,
                newPricing: newProvider.pricing
            ))
        }

        return changes
    }

    // MARK: - Private Detection Helpers

    private func detectNewLanguages(
        provider: AIProvider,
        capability: ProviderUsageCategory,
        oldCap: CapabilityRemoteConfig?,
        newCap: CapabilityRemoteConfig?
    ) -> [ConfigChange] {
        guard let newLanguages = newCap?.languages else { return [] }
        let oldLanguages = oldCap?.languages ?? [:]

        var changes: [ConfigChange] = []

        for (langCode, qualityStr) in newLanguages {
            guard oldLanguages[langCode] == nil,
                  let language = Language(rawValue: langCode) else {
                continue
            }

            let quality = LanguageSupportLevel(rawValue: qualityStr) ?? .limited
            changes.append(.newLanguage(
                provider: provider,
                language: language,
                capability: capability.displayName,
                quality: quality
            ))
        }

        return changes
    }

    private func detectLanguageQualityChanges(
        provider: AIProvider,
        capability: ProviderUsageCategory,
        oldCap: CapabilityRemoteConfig?,
        newCap: CapabilityRemoteConfig?
    ) -> [ConfigChange] {
        guard let oldLanguages = oldCap?.languages,
              let newLanguages = newCap?.languages else {
            return []
        }

        var changes: [ConfigChange] = []

        for (langCode, newQualityStr) in newLanguages {
            guard let oldQualityStr = oldLanguages[langCode],
                  let language = Language(rawValue: langCode),
                  let oldQuality = LanguageSupportLevel(rawValue: oldQualityStr),
                  let newQuality = LanguageSupportLevel(rawValue: newQualityStr),
                  newQuality > oldQuality else {
                continue
            }

            changes.append(.languageQualityImproved(
                provider: provider,
                language: language,
                capability: capability.displayName,
                oldTier: oldQuality,
                newTier: newQuality
            ))
        }

        return changes
    }

    private func detectNewModels(
        provider: AIProvider,
        capability: ProviderUsageCategory,
        oldCap: CapabilityRemoteConfig?,
        newCap: CapabilityRemoteConfig?
    ) -> [ConfigChange] {
        guard let newModels = newCap?.models else { return [] }
        let oldModelIds = Set((oldCap?.models ?? []).map { $0.id })

        var changes: [ConfigChange] = []

        for model in newModels {
            guard !oldModelIds.contains(model.id) else { continue }

            changes.append(.newModel(
                provider: provider,
                model: model,
                capability: capability.displayName
            ))
        }

        return changes
    }

    private func detectPricingChanges(
        provider: AIProvider,
        oldPricing: [String: PricingRemoteConfig],
        newPricing: [String: PricingRemoteConfig]
    ) -> [ConfigChange] {
        var changes: [ConfigChange] = []

        for (modelId, newPrice) in newPricing {
            guard let oldPrice = oldPricing[modelId] else { continue }

            let oldCost = oldPrice.estimatedCostPerMinute
            let newCost = newPrice.estimatedCostPerMinute

            // Only report significant changes (>5%)
            guard oldCost > 0, abs(newCost - oldCost) / oldCost > 0.05 else { continue }

            if newCost > oldCost {
                changes.append(.pricingIncrease(
                    provider: provider,
                    model: modelId,
                    oldCost: oldCost,
                    newCost: newCost
                ))
            } else {
                changes.append(.pricingDecrease(
                    provider: provider,
                    model: modelId,
                    oldCost: oldCost,
                    newCost: newCost
                ))
            }
        }

        return changes
    }
}

// MARK: - Config Change Types

/// Types of changes that can be detected in config updates
public enum ConfigChange: Identifiable, Equatable {
    case newLanguage(provider: AIProvider, language: Language, capability: String, quality: LanguageSupportLevel)
    case languageQualityImproved(provider: AIProvider, language: Language, capability: String, oldTier: LanguageSupportLevel, newTier: LanguageSupportLevel)
    case pricingIncrease(provider: AIProvider, model: String, oldCost: Double, newCost: Double)
    case pricingDecrease(provider: AIProvider, model: String, oldCost: Double, newCost: Double)
    case newModel(provider: AIProvider, model: ModelRemoteConfig, capability: String)
    case statusChange(provider: AIProvider, oldStatus: ProviderOperationalStatus, newStatus: ProviderOperationalStatus)

    public var id: String {
        switch self {
        case .newLanguage(let provider, let language, let capability, _):
            return "lang-\(provider.rawValue)-\(language.rawValue)-\(capability)"
        case .languageQualityImproved(let provider, let language, let capability, _, _):
            return "quality-\(provider.rawValue)-\(language.rawValue)-\(capability)"
        case .pricingIncrease(let provider, let model, _, _):
            return "price-up-\(provider.rawValue)-\(model)"
        case .pricingDecrease(let provider, let model, _, _):
            return "price-down-\(provider.rawValue)-\(model)"
        case .newModel(let provider, let model, let capability):
            return "model-\(provider.rawValue)-\(model.id)-\(capability)"
        case .statusChange(let provider, _, let newStatus):
            return "status-\(provider.rawValue)-\(newStatus.rawValue)"
        }
    }

    /// Category for grouping in UI
    public var category: ConfigChangeCategory {
        switch self {
        case .newLanguage, .languageQualityImproved:
            return .languages
        case .pricingIncrease, .pricingDecrease:
            return .pricing
        case .newModel:
            return .models
        case .statusChange:
            return .status
        }
    }

    /// Icon for display
    public var iconName: String {
        switch self {
        case .newLanguage:
            return "globe"
        case .languageQualityImproved:
            return "star.fill"
        case .pricingIncrease:
            return "arrow.up.circle.fill"
        case .pricingDecrease:
            return "arrow.down.circle.fill"
        case .newModel:
            return "sparkles"
        case .statusChange(_, _, let newStatus):
            return newStatus.iconName
        }
    }

    /// Title for display
    public var title: String {
        switch self {
        case .newLanguage(_, let language, _, _):
            return "\(language.flag) \(language.displayName) now supported"
        case .languageQualityImproved(_, let language, _, _, let newTier):
            return "\(language.flag) \(language.displayName) improved to \(newTier.label)"
        case .pricingIncrease(_, let model, _, _):
            return "\(model) price increased"
        case .pricingDecrease(_, let model, _, _):
            return "\(model) price decreased"
        case .newModel(_, let model, _):
            return "\(model.name) now available"
        case .statusChange(_, _, let newStatus):
            return "Status: \(newStatus.displayName)"
        }
    }

    /// Subtitle for display
    public var subtitle: String {
        switch self {
        case .newLanguage(let provider, _, let capability, let quality):
            return "\(provider.displayName) \(capability) • \(quality.label)"
        case .languageQualityImproved(let provider, _, let capability, let oldTier, let newTier):
            return "\(provider.displayName) \(capability) • \(oldTier.label) → \(newTier.label)"
        case .pricingIncrease(let provider, _, let oldCost, let newCost):
            return "\(provider.displayName) • \(oldCost.formattedCost) → \(newCost.formattedCost)"
        case .pricingDecrease(let provider, _, let oldCost, let newCost):
            return "\(provider.displayName) • \(oldCost.formattedCost) → \(newCost.formattedCost)"
        case .newModel(let provider, _, let capability):
            return "\(provider.displayName) \(capability)"
        case .statusChange(let provider, let oldStatus, _):
            return "\(provider.displayName) • was \(oldStatus.displayName)"
        }
    }

    /// Whether this is a positive change (good for user)
    public var isPositive: Bool {
        switch self {
        case .newLanguage, .languageQualityImproved, .newModel, .pricingDecrease:
            return true
        case .pricingIncrease:
            return false
        case .statusChange(_, _, let newStatus):
            return newStatus == .operational
        }
    }
}

// MARK: - Config Change Category

/// Categories for grouping config changes
public enum ConfigChangeCategory: String, CaseIterable {
    case languages = "Languages"
    case pricing = "Pricing"
    case models = "Models"
    case status = "Status"

    public var iconName: String {
        switch self {
        case .languages: return "globe"
        case .pricing: return "dollarsign.circle"
        case .models: return "cpu"
        case .status: return "antenna.radiowaves.left.and.right"
        }
    }
}
