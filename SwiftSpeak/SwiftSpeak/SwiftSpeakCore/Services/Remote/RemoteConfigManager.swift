//
//  RemoteConfigManager.swift
//  SwiftSpeak
//
//  Created by SwiftSpeak on 2024-12-28.
//

import Combine
import Foundation
import SwiftUI

// MARK: - Remote Config Manager

/// Manages remote provider configuration with Firebase Remote Config
/// Falls back to bundled config when offline or on first launch
@MainActor
final class RemoteConfigManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = RemoteConfigManager()

    // MARK: - Published State

    /// Current provider configuration
    @Published private(set) var config: RemoteProviderConfig?

    /// Whether config is currently being fetched
    @Published private(set) var isLoading = false

    /// Last successful fetch date
    @Published private(set) var lastFetchDate: Date?

    /// Last error encountered during fetch
    @Published private(set) var lastError: Error?

    /// Pending changes to show to user (detected on fetch)
    @Published var pendingChanges: [ConfigChange]?

    // MARK: - Private Properties

    private let cacheKey = "cached_provider_config"
    private let lastFetchKey = "last_config_fetch_date"
    private let seenChangesKey = "seen_config_changes_version"
    private let staleThreshold: TimeInterval = 7 * 24 * 60 * 60  // 7 days

    // Firebase will be initialized here when SDK is added
    // private let remoteConfig = RemoteConfig.remoteConfig()

    // MARK: - Initialization

    private init() {
        loadCachedConfig()
    }

    // MARK: - Public API

    /// Whether the cached config is stale (older than 7 days)
    public var isConfigStale: Bool {
        guard let lastFetch = lastFetchDate else { return true }
        return Date().timeIntervalSince(lastFetch) > staleThreshold
    }

    /// Fetch latest config (if stale or forced)
    /// - Parameter force: Force fetch even if not stale
    public func fetchConfigIfNeeded(force: Bool = false) async {
        guard force || isConfigStale else { return }
        await fetchConfig()
    }

    /// Fetch latest config from remote
    public func fetchConfig() async {
        isLoading = true
        lastError = nil

        // Store old config for change detection
        let oldConfig = config

        do {
            // TODO: Replace with Firebase Remote Config when SDK is added
            // For now, use bundled config as the "remote" source
            let newConfig = try await fetchFromRemote()

            // Detect changes for user notification
            if let oldConfig = oldConfig {
                let detector = ConfigChangeDetector()
                let userProviders = getUserConfiguredProviders()
                let changes = detector.detectChanges(old: oldConfig, new: newConfig, userProviders: userProviders)

                // Only show if there are changes and they haven't been seen
                if !changes.isEmpty && !hasSeenChanges(version: newConfig.version) {
                    pendingChanges = changes
                }
            }

            config = newConfig
            cacheConfig(newConfig)
            lastFetchDate = Date()
            UserDefaults.standard.set(Date(), forKey: lastFetchKey)

        } catch {
            lastError = error
            // Keep using cached/bundled config on failure
            if config == nil {
                loadBundledConfig()
            }
        }

        isLoading = false
    }

    /// Force refresh (bypasses throttling)
    public func forceRefresh() async {
        await fetchConfig()
    }

    /// Mark pending changes as seen
    public func markChangesAsSeen() {
        if let version = config?.version {
            UserDefaults.standard.set(version, forKey: seenChangesKey)
        }
        pendingChanges = nil
    }

    // MARK: - Config Access Helpers

    /// Get config for a specific provider
    public func providerConfig(for provider: AIProvider) -> ProviderRemoteConfig? {
        config?.providers[provider.rawValue]
    }

    /// Get pricing for a specific model
    public func pricing(for provider: AIProvider, model: String) -> PricingRemoteConfig? {
        providerConfig(for: provider)?.pricing[model]
    }

    /// Get language support level for a provider/capability/language combo
    public func languageSupport(
        for provider: AIProvider,
        capability: ProviderUsageCategory,
        language: Language
    ) -> LanguageSupportLevel {
        guard let providerCfg = providerConfig(for: provider),
              let capabilityCfg = providerCfg.capability(capability),
              let levelString = capabilityCfg.languages?[language.rawValue] else {
            return .unsupported
        }
        return LanguageSupportLevel(rawValue: levelString) ?? .limited
    }

    /// Get available models for a provider/capability
    public func models(
        for provider: AIProvider,
        capability: ProviderUsageCategory
    ) -> [ModelRemoteConfig] {
        guard let providerCfg = providerConfig(for: provider),
              let capabilityCfg = providerCfg.capability(capability) else {
            return []
        }
        return capabilityCfg.models ?? []
    }

    /// Get default model for a provider/capability
    public func defaultModel(
        for provider: AIProvider,
        capability: ProviderUsageCategory
    ) -> ModelRemoteConfig? {
        let models = models(for: provider, capability: capability)
        return models.first { $0.isDefault == true } ?? models.first
    }

    /// Check if provider supports a capability
    public func providerSupports(
        _ provider: AIProvider,
        capability: ProviderUsageCategory
    ) -> Bool {
        providerConfig(for: provider)?.supports(capability) ?? false
    }

    /// Get provider operational status
    public func providerStatus(_ provider: AIProvider) -> ProviderOperationalStatus {
        providerConfig(for: provider)?.status ?? .unknown
    }

    // MARK: - Private Helpers

    /// Fetch from Firebase Remote Config (or bundled for now)
    private func fetchFromRemote() async throws -> RemoteProviderConfig {
        // TODO: Implement Firebase Remote Config fetch
        // For now, simulate network delay and return bundled config
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5s simulated delay

        guard let config = loadBundledConfigData() else {
            throw RemoteConfigError.bundledConfigMissing
        }
        return config
    }

    /// Load cached config from UserDefaults
    private func loadCachedConfig() {
        // Try cached config first
        if let data = UserDefaults.standard.data(forKey: cacheKey) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            if let cached = try? decoder.decode(RemoteProviderConfig.self, from: data) {
                config = cached
                lastFetchDate = UserDefaults.standard.object(forKey: lastFetchKey) as? Date
                return
            }
        }

        // Fall back to bundled config
        loadBundledConfig()
    }

    /// Load bundled fallback config
    private func loadBundledConfig() {
        if let bundled = loadBundledConfigData() {
            config = bundled
        }
    }

    /// Load and decode bundled config JSON
    private func loadBundledConfigData() -> RemoteProviderConfig? {
        guard let url = Bundle.main.url(forResource: "fallback-provider-config", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try? decoder.decode(RemoteProviderConfig.self, from: data)
    }

    /// Cache current config to UserDefaults
    private func cacheConfig(_ config: RemoteProviderConfig) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(config) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    /// Check if changes for a version have been seen
    private func hasSeenChanges(version: String) -> Bool {
        UserDefaults.standard.string(forKey: seenChangesKey) == version
    }

    /// Get user's configured providers from SharedSettings
    private func getUserConfiguredProviders() -> [AIProvider] {
        // Access SharedSettings to get configured providers
        // This is a simplified version - in production, inject SharedSettings
        let defaults = UserDefaults(suiteName: "group.pawelgawliczek.swiftspeak")

        // Get configured providers from stored data
        guard let data = defaults?.data(forKey: "configuredAIProviders"),
              let configs = try? JSONDecoder().decode([AIProviderConfig].self, from: data) else {
            return [.openAI]  // Default fallback
        }

        return configs.map { $0.provider }
    }
}

// MARK: - Remote Config Error

public enum RemoteConfigError: LocalizedError {
    case bundledConfigMissing
    case fetchFailed(underlying: Error)
    case decodingFailed
    case networkUnavailable

    public var errorDescription: String? {
        switch self {
        case .bundledConfigMissing:
            return "Bundled configuration file is missing"
        case .fetchFailed(let error):
            return "Failed to fetch config: \(error.localizedDescription)"
        case .decodingFailed:
            return "Failed to decode configuration"
        case .networkUnavailable:
            return "Network is unavailable"
        }
    }
}

// MARK: - Firebase Integration (To be implemented)

/*
 When adding Firebase SDK:

 1. Add to Package.swift or via Xcode SPM:
    - https://github.com/firebase/firebase-ios-sdk
    - Select FirebaseRemoteConfig product

 2. Add GoogleService-Info.plist to project

 3. Initialize Firebase in SwiftSpeakApp:
    import FirebaseCore
    FirebaseApp.configure()

 4. Update fetchFromRemote() to use:
    public let remoteConfig = RemoteConfig.remoteConfig()
    public let settings = RemoteConfigSettings()
    settings.minimumFetchInterval = 3600  // 1 hour
    remoteConfig.configSettings = settings

    try await remoteConfig.fetchAndActivate()
    public let jsonString = remoteConfig.configValue(forKey: "provider_config").stringValue
    // Decode jsonString to RemoteProviderConfig

 5. Optionally add real-time listener:
    remoteConfig.addOnConfigUpdateListener { update, error in
        // Handle updates
    }
 */
