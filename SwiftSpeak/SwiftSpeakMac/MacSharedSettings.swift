//
//  MacSharedSettings.swift
//  SwiftSpeakMac
//
//  macOS settings management (mirrors iOS SharedSettings)
//  Includes iCloud sync for cross-device settings synchronization
//

import Foundation
import Combine
import SwiftSpeakCore

@MainActor
class MacSettings: ObservableObject {
    static let shared = MacSettings()

    private let defaults: UserDefaults?
    // DISABLED: NSUbiquitousKeyValueStore causes CloudKit entitlement crash
    // TODO: Re-enable once iCloud container is properly configured in Developer Portal
    private var iCloud: NSUbiquitousKeyValueStore? { nil }
    private var iCloudObserver: NSObjectProtocol?
    private var isSyncing = false
    private var isInitializing = true  // Prevent syncing during init

    // iCloud sync keys - MUST match iOS SharedSettings.swift
    private enum iCloudKeys {
        static let configuredAIProviders = "icloud_configuredAIProviders"
        static let contexts = "icloud_contexts"
        static let powerModes = "icloud_powerModes"
        static let vocabulary = "icloud_vocabulary"
        static let customTemplates = "icloud_customTemplates"
        static let globalMemory = "icloud_globalMemory"
        static let globalMemoryEnabled = "icloud_globalMemoryEnabled"
        static let globalMemoryLimit = "icloud_globalMemoryLimit"
        static let selectedTranscriptionProvider = "icloud_selectedTranscriptionProvider"
        static let selectedTranslationProvider = "icloud_selectedTranslationProvider"
        static let selectedPowerModeProvider = "icloud_selectedPowerModeProvider"
        static let selectedMode = "icloud_selectedMode"
        static let selectedTargetLanguage = "icloud_selectedTargetLanguage"
        static let isTranslationEnabled = "icloud_isTranslationEnabled"
        static let transcriptionHistory = "icloud_transcriptionHistory"
        static let historyMemory = "icloud_historyMemory"
        static let lastSyncTimestamp = "icloud_lastSyncTimestamp"
    }

    // MARK: - Published Properties

    @Published var hasCompletedOnboarding: Bool = false {
        didSet {
            defaults?.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }

    // MARK: - Unified AI Provider System

    @Published var configuredAIProviders: [AIProviderConfig] = [] {
        didSet {
            saveConfiguredAIProviders()
        }
    }

    @Published var selectedTranscriptionProvider: AIProvider = .openAI {
        didSet {
            defaults?.set(selectedTranscriptionProvider.rawValue, forKey: "selectedTranscriptionProvider")
            syncToiCloud()
        }
    }

    @Published var selectedTranslationProvider: AIProvider = .openAI {
        didSet {
            defaults?.set(selectedTranslationProvider.rawValue, forKey: "selectedTranslationProvider")
            syncToiCloud()
        }
    }

    @Published var selectedPowerModeProvider: AIProvider = .openAI {
        didSet {
            defaults?.set(selectedPowerModeProvider.rawValue, forKey: "selectedPowerModeProvider")
            syncToiCloud()
        }
    }

    @Published var selectedMode: FormattingMode = .raw {
        didSet {
            defaults?.set(selectedMode.rawValue, forKey: "selectedMode")
            syncToiCloud()
        }
    }

    @Published var selectedTargetLanguage: Language = .spanish {
        didSet {
            defaults?.set(selectedTargetLanguage.rawValue, forKey: "selectedTargetLanguage")
            syncToiCloud()
        }
    }

    /// Source language for dictation/transcription (nil = auto-detect)
    @Published var selectedDictationLanguage: Language? = nil {
        didSet {
            if let lang = selectedDictationLanguage {
                defaults?.set(lang.rawValue, forKey: "selectedDictationLanguage")
            } else {
                defaults?.removeObject(forKey: "selectedDictationLanguage")
            }
        }
    }

    @Published var isTranslationEnabled: Bool = false {
        didSet {
            defaults?.set(isTranslationEnabled, forKey: "isTranslationEnabled")
            syncToiCloud()
        }
    }

    @Published var subscriptionTier: SubscriptionTier = .free {
        didSet {
            defaults?.set(subscriptionTier.rawValue, forKey: "subscriptionTier")
        }
    }

    @Published var customTemplates: [CustomTemplate] = [] {
        didSet {
            saveCustomTemplates()
        }
    }

    // MARK: - Contexts

    @Published var contexts: [ConversationContext] = [] {
        didSet {
            saveContexts()
        }
    }

    @Published var activeContextId: UUID? {
        didSet {
            if let id = activeContextId {
                defaults?.set(id.uuidString, forKey: "activeContextId")
            } else {
                defaults?.removeObject(forKey: "activeContextId")
            }
        }
    }

    // MARK: - Power Modes

    @Published var powerModes: [PowerMode] = [] {
        didSet {
            savePowerModes()
        }
    }

    @Published var activePowerModeId: UUID? {
        didSet {
            if let id = activePowerModeId {
                defaults?.set(id.uuidString, forKey: "activePowerModeId")
            } else {
                defaults?.removeObject(forKey: "activePowerModeId")
            }
        }
    }

    // MARK: - Power Mode Hotkeys (macOS only)

    /// Global hotkey to open the Power Mode selector overlay
    @Published var globalPowerModeHotkey: HotkeyCombination? = nil {
        didSet {
            saveGlobalPowerModeHotkey()
        }
    }

    /// Dictionary mapping Power Mode IDs to their hotkey combinations
    @Published var powerModeHotkeys: [UUID: HotkeyCombination] = [:] {
        didSet {
            savePowerModeHotkeys()
        }
    }

    private func saveGlobalPowerModeHotkey() {
        if let hotkey = globalPowerModeHotkey,
           let data = try? JSONEncoder().encode(hotkey) {
            defaults?.set(data, forKey: "globalPowerModeHotkey")
        } else {
            defaults?.removeObject(forKey: "globalPowerModeHotkey")
        }
    }

    private func loadGlobalPowerModeHotkey() {
        guard let data = defaults?.data(forKey: "globalPowerModeHotkey"),
              let hotkey = try? JSONDecoder().decode(HotkeyCombination.self, from: data) else {
            return
        }
        globalPowerModeHotkey = hotkey
    }

    private func savePowerModeHotkeys() {
        let encoder = JSONEncoder()
        // Convert to [String: HotkeyCombination] for JSON encoding
        let stringKeyed = Dictionary(uniqueKeysWithValues: powerModeHotkeys.map { (key, value) in
            (key.uuidString, value)
        })

        if let data = try? encoder.encode(stringKeyed) {
            defaults?.set(data, forKey: "powerModeHotkeys")
        }
    }

    private func loadPowerModeHotkeys() {
        guard let data = defaults?.data(forKey: "powerModeHotkeys") else { return }
        let decoder = JSONDecoder()

        do {
            let stringKeyed = try decoder.decode([String: HotkeyCombination].self, from: data)
            // Convert back to [UUID: HotkeyCombination]
            powerModeHotkeys = Dictionary(uniqueKeysWithValues: stringKeyed.compactMap { (key, value) in
                guard let uuid = UUID(uuidString: key) else { return nil }
                return (uuid, value)
            })
        } catch {
            print("Failed to load power mode hotkeys: \(error)")
        }
    }

    // MARK: - Memory System

    @Published var globalMemory: String? {
        didSet {
            defaults?.set(globalMemory, forKey: "globalMemory")
            syncToiCloud()
        }
    }

    @Published var globalMemoryEnabled: Bool = true {
        didSet {
            defaults?.set(globalMemoryEnabled, forKey: "globalMemoryEnabled")
            syncToiCloud()
        }
    }

    @Published var globalMemoryLimit: Int = 2000 {
        didSet {
            let clamped = min(max(globalMemoryLimit, 500), 2000)
            if clamped != globalMemoryLimit {
                globalMemoryLimit = clamped
            }
            defaults?.set(globalMemoryLimit, forKey: "globalMemoryLimit")
            syncToiCloud()
        }
    }

    @Published var historyMemory: HistoryMemory? {
        didSet {
            saveHistoryMemory()
            syncToiCloud()
        }
    }

    // MARK: - Vocabulary

    @Published var vocabulary: [VocabularyEntry] = [] {
        didSet {
            saveVocabulary()
        }
    }

    // MARK: - History
    // TODO: Add CoreDataManager to SwiftSpeakMac target for CloudKit sync
    // Follow SHARED_FILES_GUIDE.md to add:
    //   - SwiftSpeak/Services/Persistence/PersistenceController.swift
    //   - SwiftSpeak/Services/Persistence/CoreDataManager.swift
    //   - SwiftSpeak/Services/Persistence/CoreDataEntityExtensions.swift
    //   - SwiftSpeak.xcdatamodeld
    // Once added, history will sync via CloudKit (unlimited records)

    @Published var transcriptionHistory: [TranscriptionRecord] = []

    // MARK: - Behavior Settings

    @Published var powerModeStreamingEnabled: Bool = true {
        didSet {
            defaults?.set(powerModeStreamingEnabled, forKey: "powerModeStreamingEnabled")
        }
    }

    @Published var autoReturnEnabled: Bool = true {
        didSet {
            defaults?.set(autoReturnEnabled, forKey: "autoReturnEnabled")
        }
    }

    @Published var playSoundOnRecordStart: Bool = true {
        didSet {
            defaults?.set(playSoundOnRecordStart, forKey: "playSoundOnRecordStart")
        }
    }

    @Published var playSoundOnRecordEnd: Bool = true {
        didSet {
            defaults?.set(playSoundOnRecordEnd, forKey: "playSoundOnRecordEnd")
        }
    }

    // MARK: - Security & Privacy

    @Published var biometricProtectionEnabled: Bool = false {
        didSet {
            defaults?.set(biometricProtectionEnabled, forKey: "biometricProtectionEnabled")
        }
    }

    @Published var historyRetentionDays: Int = 30 {
        didSet {
            defaults?.set(historyRetentionDays, forKey: "historyRetentionDays")
        }
    }

    @Published var analyticsEnabled: Bool = true {
        didSet {
            defaults?.set(analyticsEnabled, forKey: "analyticsEnabled")
        }
    }

    @Published var cloudLogSyncEnabled: Bool = true {
        didSet {
            defaults?.set(cloudLogSyncEnabled, forKey: "cloudLogSyncEnabled")
        }
    }

    // MARK: - Initialization

    init() {
        self.defaults = UserDefaults.standard
        loadSettings()
        setupiCloudSync()

        // Mark initialization complete - now syncToiCloud() will work
        isInitializing = false
        print("[iCloud] Initialization complete, sync now enabled")
    }

    deinit {
        if let observer = iCloudObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - iCloud Sync Setup

    private func setupiCloudSync() {
        // Skip if iCloud is disabled
        guard iCloud != nil else {
            print("[iCloud] iCloud KVS disabled, skipping sync setup")
            return
        }

        print("[iCloud] Setting up iCloud KVS sync...")

        // Check if iCloud is available
        let testKey = "icloud_test_\(Date().timeIntervalSince1970)"
        iCloud?.set("test", forKey: testKey)
        let syncResult = iCloud?.synchronize()
        print("[iCloud] KVS sync test: synchronize() returned \(syncResult)")
        iCloud?.removeObject(forKey: testKey)

        // Log current iCloud state
        if let keys = iCloud?.dictionaryRepresentation.keys {
            print("[iCloud] KVS current keys: \(Array(keys).joined(separator: ", "))")
        } else {
            print("[iCloud] KVS not available")
        }

        // Listen for iCloud changes from other devices
        iCloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloud,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            print("[iCloud] Received external change notification!")

            guard let userInfo = notification.userInfo,
                  let reasonNumber = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? NSNumber else {
                print("[iCloud] No reason in notification userInfo")
                return
            }

            let reason = reasonNumber.intValue
            let reasonName: String
            switch reason {
            case NSUbiquitousKeyValueStoreServerChange: reasonName = "ServerChange"
            case NSUbiquitousKeyValueStoreInitialSyncChange: reasonName = "InitialSyncChange"
            case NSUbiquitousKeyValueStoreAccountChange: reasonName = "AccountChange"
            case NSUbiquitousKeyValueStoreQuotaViolationChange: reasonName = "QuotaViolation"
            default: reasonName = "Unknown(\(reason))"
            }
            print("[iCloud] Change reason: \(reasonName)")

            if let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
                print("[iCloud] Changed keys: \(changedKeys.joined(separator: ", "))")
            }

            switch reason {
            case NSUbiquitousKeyValueStoreServerChange,
                 NSUbiquitousKeyValueStoreInitialSyncChange,
                 NSUbiquitousKeyValueStoreAccountChange:
                // Data changed from another device - reload settings on main actor
                Task { @MainActor [weak self] in
                    self?.isSyncing = true
                    self?.loadFromiCloud()
                    self?.isSyncing = false
                }
            case NSUbiquitousKeyValueStoreQuotaViolationChange:
                print("[iCloud] ⚠️ iCloud storage quota exceeded")
            default:
                break
            }
        }

        // Synchronize to get latest changes
        let initialSync = iCloud?.synchronize()
        print("[iCloud] Sync initialized, initial synchronize() returned \(initialSync)")

        // Try to load any existing data
        loadFromiCloud()
    }

    private func loadFromiCloud() {
        print("[iCloud] loadFromiCloud: Starting to load from iCloud KVS...")

        // Load providers
        if let data = iCloud?.data(forKey: iCloudKeys.configuredAIProviders) {
            print("[iCloud] loadFromiCloud: Found providers data (\(data.count) bytes)")
            if let providers = try? JSONDecoder().decode([AIProviderConfig].self, from: data) {
                configuredAIProviders = providers
                print("[iCloud] loadFromiCloud: Loaded \(providers.count) providers: \(providers.map { $0.provider.displayName }.joined(separator: ", "))")
            } else {
                print("[iCloud] loadFromiCloud: Failed to decode providers data")
            }
        } else {
            print("[iCloud] loadFromiCloud: No providers data in iCloud KVS")
        }

        // Load contexts
        if let data = iCloud?.data(forKey: iCloudKeys.contexts),
           let loadedContexts = try? JSONDecoder().decode([ConversationContext].self, from: data) {
            contexts = loadedContexts
            print("[iCloud] loadFromiCloud: Loaded \(loadedContexts.count) contexts")
        } else {
            print("[iCloud] loadFromiCloud: No contexts data in iCloud KVS")
        }

        // Load power modes
        if let data = iCloud?.data(forKey: iCloudKeys.powerModes),
           let loadedModes = try? JSONDecoder().decode([PowerMode].self, from: data) {
            powerModes = loadedModes
        }

        // Load vocabulary
        if let data = iCloud?.data(forKey: iCloudKeys.vocabulary),
           let entries = try? JSONDecoder().decode([VocabularyEntry].self, from: data) {
            vocabulary = entries
        }

        // Load custom templates
        if let data = iCloud?.data(forKey: iCloudKeys.customTemplates),
           let templates = try? JSONDecoder().decode([CustomTemplate].self, from: data) {
            customTemplates = templates
        }

        // Load primitive values
        if let providerRaw = iCloud?.string(forKey: iCloudKeys.selectedTranscriptionProvider),
           let provider = AIProvider(rawValue: providerRaw) {
            selectedTranscriptionProvider = provider
        }

        if let providerRaw = iCloud?.string(forKey: iCloudKeys.selectedTranslationProvider),
           let provider = AIProvider(rawValue: providerRaw) {
            selectedTranslationProvider = provider
        }

        if let providerRaw = iCloud?.string(forKey: iCloudKeys.selectedPowerModeProvider),
           let provider = AIProvider(rawValue: providerRaw) {
            selectedPowerModeProvider = provider
        }

        if let modeRaw = iCloud?.string(forKey: iCloudKeys.selectedMode),
           let mode = FormattingMode(rawValue: modeRaw) {
            selectedMode = mode
        }

        if let langRaw = iCloud?.string(forKey: iCloudKeys.selectedTargetLanguage),
           let lang = Language(rawValue: langRaw) {
            selectedTargetLanguage = lang
        }

        isTranslationEnabled = iCloud?.bool(forKey: iCloudKeys.isTranslationEnabled) ?? false

        // Load global memory settings
        if let memory = iCloud?.string(forKey: iCloudKeys.globalMemory) {
            globalMemory = memory
        }
        globalMemoryEnabled = iCloud?.bool(forKey: iCloudKeys.globalMemoryEnabled) ?? true
        if let limit = iCloud?.longLong(forKey: iCloudKeys.globalMemoryLimit), limit > 0 {
            globalMemoryLimit = Int(limit)
        }

        // Transcription history is synced via Core Data + CloudKit (unlimited records)
        // No longer using iCloud KVS for history due to size limits

        // Load history memory
        if let data = iCloud?.data(forKey: iCloudKeys.historyMemory),
           let memory = try? JSONDecoder().decode(HistoryMemory.self, from: data) {
            // Use iCloud version if newer or local is nil
            if historyMemory == nil || memory.lastUpdated > (historyMemory?.lastUpdated ?? .distantPast) {
                historyMemory = memory
                print("[iCloud] loadFromiCloud: Loaded history memory from iCloud")
            }
        }
    }

    private func syncToiCloud() {
        guard !isInitializing else {
            // Don't sync during initialization - we're still loading
            return
        }
        guard !isSyncing else {
            print("[iCloud] syncToiCloud: Skipped (already syncing)")
            return
        }

        print("[iCloud] syncToiCloud: Starting sync to iCloud KVS...")

        // Sync providers
        if let data = try? JSONEncoder().encode(configuredAIProviders) {
            iCloud?.set(data, forKey: iCloudKeys.configuredAIProviders)
            print("[iCloud] syncToiCloud: Synced \(configuredAIProviders.count) providers (\(data.count) bytes)")
        }

        // Sync contexts
        if let data = try? JSONEncoder().encode(contexts) {
            iCloud?.set(data, forKey: iCloudKeys.contexts)
        }

        // Sync power modes
        if let data = try? JSONEncoder().encode(powerModes) {
            iCloud?.set(data, forKey: iCloudKeys.powerModes)
        }

        // Sync vocabulary
        if let data = try? JSONEncoder().encode(vocabulary) {
            iCloud?.set(data, forKey: iCloudKeys.vocabulary)
        }

        // Sync custom templates
        if let data = try? JSONEncoder().encode(customTemplates) {
            iCloud?.set(data, forKey: iCloudKeys.customTemplates)
        }

        // Sync primitive values
        iCloud?.set(selectedTranscriptionProvider.rawValue, forKey: iCloudKeys.selectedTranscriptionProvider)
        iCloud?.set(selectedTranslationProvider.rawValue, forKey: iCloudKeys.selectedTranslationProvider)
        iCloud?.set(selectedPowerModeProvider.rawValue, forKey: iCloudKeys.selectedPowerModeProvider)
        iCloud?.set(selectedMode.rawValue, forKey: iCloudKeys.selectedMode)
        iCloud?.set(selectedTargetLanguage.rawValue, forKey: iCloudKeys.selectedTargetLanguage)
        iCloud?.set(isTranslationEnabled, forKey: iCloudKeys.isTranslationEnabled)

        // Sync global memory settings
        if let memory = globalMemory {
            iCloud?.set(memory, forKey: iCloudKeys.globalMemory)
        } else {
            iCloud?.removeObject(forKey: iCloudKeys.globalMemory)
        }
        iCloud?.set(globalMemoryEnabled, forKey: iCloudKeys.globalMemoryEnabled)
        iCloud?.set(Int64(globalMemoryLimit), forKey: iCloudKeys.globalMemoryLimit)

        // Transcription history is synced via Core Data + CloudKit (unlimited records)
        // No longer using iCloud KVS for history due to size limits

        // Sync history memory
        if let memory = historyMemory, let data = try? JSONEncoder().encode(memory) {
            iCloud?.set(data, forKey: iCloudKeys.historyMemory)
        } else {
            iCloud?.removeObject(forKey: iCloudKeys.historyMemory)
        }

        // Set sync timestamp
        iCloud?.set(Date().timeIntervalSince1970, forKey: iCloudKeys.lastSyncTimestamp)

        // Trigger synchronization
        let syncResult = iCloud?.synchronize()
        print("[iCloud] syncToiCloud: synchronize() returned \(syncResult)")
    }

    /// Force sync settings to iCloud (call after making changes)
    func forceSyncToiCloud() {
        syncToiCloud()
    }

    /// Get last sync timestamp
    var lastSyncTime: Date? {
        guard let timestamp = iCloud?.double(forKey: iCloudKeys.lastSyncTimestamp), timestamp > 0 else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    private func loadSettings() {
        hasCompletedOnboarding = defaults?.bool(forKey: "hasCompletedOnboarding") ?? false

        // Load providers
        loadConfiguredAIProviders()

        if let providerRaw = defaults?.string(forKey: "selectedTranscriptionProvider"),
           let provider = AIProvider(rawValue: providerRaw) {
            selectedTranscriptionProvider = provider
        }

        if let providerRaw = defaults?.string(forKey: "selectedTranslationProvider"),
           let provider = AIProvider(rawValue: providerRaw) {
            selectedTranslationProvider = provider
        }

        if let providerRaw = defaults?.string(forKey: "selectedPowerModeProvider"),
           let provider = AIProvider(rawValue: providerRaw) {
            selectedPowerModeProvider = provider
        }

        if let modeRaw = defaults?.string(forKey: "selectedMode"),
           let mode = FormattingMode(rawValue: modeRaw) {
            selectedMode = mode
        }

        if let langRaw = defaults?.string(forKey: "selectedDictationLanguage"),
           let lang = Language(rawValue: langRaw) {
            selectedDictationLanguage = lang
        }

        if let langRaw = defaults?.string(forKey: "selectedTargetLanguage"),
           let lang = Language(rawValue: langRaw) {
            selectedTargetLanguage = lang
        }

        isTranslationEnabled = defaults?.bool(forKey: "isTranslationEnabled") ?? false

        // Load tier
        if let tierRaw = defaults?.string(forKey: "subscriptionTier"),
           let tier = SubscriptionTier(rawValue: tierRaw) {
            subscriptionTier = tier
        }

        // Load contexts and power modes
        loadContexts()
        loadPowerModes()
        loadGlobalPowerModeHotkey()
        loadPowerModeHotkeys()
        loadHistoryMemory()
        loadCustomTemplates()
        loadVocabulary()
        loadObsidianVaults()

        // Load active context
        if let contextIdString = defaults?.string(forKey: "activeContextId"),
           let contextId = UUID(uuidString: contextIdString) {
            activeContextId = contextId
        } else {
            // Default to Work preset
            activeContextId = ConversationContext.presets.first(where: { $0.name == "Work" })?.id
        }

        // Load active power mode
        if let powerModeIdString = defaults?.string(forKey: "activePowerModeId"),
           let powerModeId = UUID(uuidString: powerModeIdString) {
            activePowerModeId = powerModeId
        }

        // Load global memory
        globalMemory = defaults?.string(forKey: "globalMemory")
        if defaults?.object(forKey: "globalMemoryEnabled") != nil {
            globalMemoryEnabled = defaults?.bool(forKey: "globalMemoryEnabled") ?? true
        }
        if defaults?.object(forKey: "globalMemoryLimit") != nil {
            globalMemoryLimit = defaults?.integer(forKey: "globalMemoryLimit") ?? 2000
        }

        // Load behavior settings
        if defaults?.object(forKey: "powerModeStreamingEnabled") != nil {
            powerModeStreamingEnabled = defaults?.bool(forKey: "powerModeStreamingEnabled") ?? true
        }
        if defaults?.object(forKey: "autoReturnEnabled") != nil {
            autoReturnEnabled = defaults?.bool(forKey: "autoReturnEnabled") ?? true
        }
        if defaults?.object(forKey: "playSoundOnRecordStart") != nil {
            playSoundOnRecordStart = defaults?.bool(forKey: "playSoundOnRecordStart") ?? true
        }
        if defaults?.object(forKey: "playSoundOnRecordEnd") != nil {
            playSoundOnRecordEnd = defaults?.bool(forKey: "playSoundOnRecordEnd") ?? true
        }

        // Load security & privacy settings
        if defaults?.object(forKey: "biometricProtectionEnabled") != nil {
            biometricProtectionEnabled = defaults?.bool(forKey: "biometricProtectionEnabled") ?? false
        }
        if defaults?.object(forKey: "historyRetentionDays") != nil {
            historyRetentionDays = defaults?.integer(forKey: "historyRetentionDays") ?? 30
        }
        if defaults?.object(forKey: "analyticsEnabled") != nil {
            analyticsEnabled = defaults?.bool(forKey: "analyticsEnabled") ?? true
        }
        if defaults?.object(forKey: "cloudLogSyncEnabled") != nil {
            cloudLogSyncEnabled = defaults?.bool(forKey: "cloudLogSyncEnabled") ?? true
        }

        loadHistory()
    }

    // MARK: - History Management

    func clearTranscriptionHistory() {
        transcriptionHistory.removeAll()
        defaults?.removeObject(forKey: "transcriptionHistory")
    }

    // MARK: - AI Provider Management

    private func loadConfiguredAIProviders() {
        if let data = defaults?.data(forKey: "configuredAIProviders"),
           let providers = try? JSONDecoder().decode([AIProviderConfig].self, from: data) {
            configuredAIProviders = providers
        } else {
            // Default to empty - user adds providers in settings
            configuredAIProviders = []
        }
    }

    private func saveConfiguredAIProviders() {
        if let data = try? JSONEncoder().encode(configuredAIProviders) {
            defaults?.set(data, forKey: "configuredAIProviders")
        }
        syncToiCloud()
    }

    func addAIProvider(_ config: AIProviderConfig) {
        guard !configuredAIProviders.contains(where: { $0.provider == config.provider }) else { return }
        configuredAIProviders.append(config)
    }

    func updateAIProvider(_ config: AIProviderConfig) {
        if let index = configuredAIProviders.firstIndex(where: { $0.provider == config.provider }) {
            configuredAIProviders[index] = config
        }
    }

    func removeAIProvider(_ provider: AIProvider) {
        configuredAIProviders.removeAll { $0.provider == provider }
        // Update selected providers if removed
        if selectedTranscriptionProvider == provider {
            if let first = transcriptionProviders.first {
                selectedTranscriptionProvider = first.provider
            }
        }
        if selectedTranslationProvider == provider {
            if let first = translationProviders.first {
                selectedTranslationProvider = first.provider
            }
        }
        if selectedPowerModeProvider == provider {
            if let first = powerModeProviders.first {
                selectedPowerModeProvider = first.provider
            }
        }
    }

    func getAIProviderConfig(for provider: AIProvider) -> AIProviderConfig? {
        configuredAIProviders.first { $0.provider == provider }
    }

    var availableProvidersToAdd: [AIProvider] {
        let configuredProviderTypes = Set(configuredAIProviders.map { $0.provider })
        return AIProvider.allCases.filter { !configuredProviderTypes.contains($0) }
    }

    // MARK: - Filtered Provider Lists

    var transcriptionProviders: [AIProviderConfig] {
        configuredAIProviders.filter { $0.isConfiguredForTranscription }
    }

    var translationProviders: [AIProviderConfig] {
        configuredAIProviders.filter { $0.isConfiguredForTranslation }
    }

    var powerModeProviders: [AIProviderConfig] {
        configuredAIProviders.filter { $0.isConfiguredForPowerMode }
    }

    func hasValidAPIKey(for provider: AIProvider) -> Bool {
        guard let config = getAIProviderConfig(for: provider) else { return false }
        if provider.isLocalProvider {
            return true
        }
        return !config.apiKey.isEmpty
    }

    /// Get API key for a provider (used by ProviderFactory)
    func apiKey(for provider: AIProvider) -> String? {
        guard let config = getAIProviderConfig(for: provider),
              !config.apiKey.isEmpty else {
            return nil
        }
        return config.apiKey
    }

    // MARK: - Context Management

    private func loadContexts() {
        if let data = defaults?.data(forKey: "contexts"),
           let loadedContexts = try? JSONDecoder().decode([ConversationContext].self, from: data),
           !loadedContexts.isEmpty {
            contexts = loadedContexts
        } else {
            contexts = ConversationContext.presets
        }
    }

    private func saveContexts() {
        if let data = try? JSONEncoder().encode(contexts) {
            defaults?.set(data, forKey: "contexts")
        }
        syncToiCloud()
    }

    func addContext(_ context: ConversationContext) {
        contexts.append(context)
    }

    func updateContext(_ context: ConversationContext) {
        if let index = contexts.firstIndex(where: { $0.id == context.id }) {
            var updatedContext = context
            updatedContext.updatedAt = Date()
            contexts[index] = updatedContext
        }
    }

    func deleteContext(id: UUID) {
        contexts.removeAll { $0.id == id }
        if activeContextId == id {
            activeContextId = nil
        }
    }

    func getContext(id: UUID) -> ConversationContext? {
        contexts.first { $0.id == id } ?? ConversationContext.presets.first { $0.id == id }
    }

    var activeContext: ConversationContext? {
        guard let id = activeContextId else { return nil }
        return contexts.first(where: { $0.id == id }) ?? ConversationContext.presets.first(where: { $0.id == id })
    }

    func setActiveContext(_ context: ConversationContext?) {
        if let context = context {
            activeContextId = context.id
            for i in contexts.indices {
                contexts[i].isActive = (contexts[i].id == context.id)
            }
        } else {
            activeContextId = nil
            for i in contexts.indices {
                contexts[i].isActive = false
            }
        }
    }

    // MARK: - Obsidian Vaults

    @Published var obsidianVaults: [ObsidianVault] = [] {
        didSet {
            saveObsidianVaults()
        }
    }

    private func loadObsidianVaults() {
        if let data = defaults?.data(forKey: "obsidianVaults"),
           let vaults = try? JSONDecoder().decode([ObsidianVault].self, from: data) {
            obsidianVaults = vaults
        }
    }

    private func saveObsidianVaults() {
        if let data = try? JSONEncoder().encode(obsidianVaults) {
            defaults?.set(data, forKey: "obsidianVaults")
        }
    }

    func addObsidianVault(_ vault: ObsidianVault) {
        guard !obsidianVaults.contains(where: { $0.id == vault.id }) else { return }
        obsidianVaults.append(vault)
    }

    func updateObsidianVault(_ vault: ObsidianVault) {
        if let index = obsidianVaults.firstIndex(where: { $0.id == vault.id }) {
            obsidianVaults[index] = vault
        }
    }

    func removeObsidianVault(id: UUID) {
        obsidianVaults.removeAll { $0.id == id }
    }

    func getObsidianVault(id: UUID) -> ObsidianVault? {
        obsidianVaults.first { $0.id == id }
    }

    // MARK: - Power Mode Management

    private func loadPowerModes() {
        if let data = defaults?.data(forKey: "powerModes"),
           let loadedModes = try? JSONDecoder().decode([PowerMode].self, from: data) {
            powerModes = loadedModes
        } else {
            powerModes = PowerMode.presets
        }
    }

    private func savePowerModes() {
        if let data = try? JSONEncoder().encode(powerModes) {
            defaults?.set(data, forKey: "powerModes")
        }
        syncToiCloud()
    }

    func addPowerMode(_ mode: PowerMode) {
        powerModes.append(mode)
    }

    func updatePowerMode(_ mode: PowerMode) {
        if let index = powerModes.firstIndex(where: { $0.id == mode.id }) {
            var updatedMode = mode
            updatedMode.updatedAt = Date()
            powerModes[index] = updatedMode
        }
    }

    func deletePowerMode(id: UUID) {
        powerModes.removeAll { $0.id == id }
    }

    func getPowerMode(id: UUID) -> PowerMode? {
        powerModes.first { $0.id == id }
    }

    var activePowerModes: [PowerMode] {
        powerModes.filter { !$0.isArchived }
    }

    var archivedPowerModes: [PowerMode] {
        powerModes.filter { $0.isArchived }
    }

    var activePowerMode: PowerMode? {
        guard let id = activePowerModeId else { return nil }
        return powerModes.first(where: { $0.id == id })
    }

    func setActivePowerMode(_ powerMode: PowerMode?) {
        if let powerMode = powerMode {
            activePowerModeId = powerMode.id
        } else {
            activePowerModeId = nil
        }
    }

    // MARK: - Memory Management

    private func loadHistoryMemory() {
        if let data = defaults?.data(forKey: "historyMemory"),
           let memory = try? JSONDecoder().decode(HistoryMemory.self, from: data) {
            historyMemory = memory
        }
    }

    private func saveHistoryMemory() {
        if let data = try? JSONEncoder().encode(historyMemory) {
            defaults?.set(data, forKey: "historyMemory")
        }
    }

    func updateHistoryMemory(summary: String, topic: String? = nil) {
        var memory = historyMemory ?? HistoryMemory()
        memory.summary = summary
        memory.lastUpdated = Date()
        memory.conversationCount += 1

        if let topic = topic {
            memory.recentTopics.insert(topic, at: 0)
            if memory.recentTopics.count > 5 {
                memory.recentTopics = Array(memory.recentTopics.prefix(5))
            }
        }

        historyMemory = memory
    }

    func clearHistoryMemory() {
        historyMemory = nil
    }

    func updateContextMemory(id: UUID, memory: String) {
        if let index = contexts.firstIndex(where: { $0.id == id }) {
            contexts[index].contextMemory = memory
            contexts[index].lastMemoryUpdate = Date()
            contexts[index].updatedAt = Date()
        }
    }

    func clearContextMemory(id: UUID) {
        if let index = contexts.firstIndex(where: { $0.id == id }) {
            contexts[index].contextMemory = nil
            contexts[index].lastMemoryUpdate = nil
            contexts[index].updatedAt = Date()
        }
    }

    func updatePowerModeMemory(id: UUID, memory: String) {
        if let index = powerModes.firstIndex(where: { $0.id == id }) {
            powerModes[index].memory = memory
            powerModes[index].lastMemoryUpdate = Date()
            powerModes[index].updatedAt = Date()
        }
    }

    func clearPowerModeMemory(id: UUID) {
        if let index = powerModes.firstIndex(where: { $0.id == id }) {
            powerModes[index].memory = nil
            powerModes[index].lastMemoryUpdate = nil
            powerModes[index].updatedAt = Date()
        }
    }

    // MARK: - Vocabulary Management

    private func loadVocabulary() {
        if let data = defaults?.data(forKey: "vocabulary"),
           let entries = try? JSONDecoder().decode([VocabularyEntry].self, from: data) {
            vocabulary = entries
        }
    }

    private func saveVocabulary() {
        if let data = try? JSONEncoder().encode(vocabulary) {
            defaults?.set(data, forKey: "vocabulary")
        }
        syncToiCloud()
    }

    func addVocabularyEntry(_ entry: VocabularyEntry) {
        if vocabulary.contains(where: { $0.recognizedWord.lowercased() == entry.recognizedWord.lowercased() }) {
            return
        }
        vocabulary.append(entry)
    }

    func updateVocabularyEntry(_ entry: VocabularyEntry) {
        if let index = vocabulary.firstIndex(where: { $0.id == entry.id }) {
            vocabulary[index] = entry
        }
    }

    func removeVocabularyEntry(_ entry: VocabularyEntry) {
        vocabulary.removeAll { $0.id == entry.id }
    }

    func applyVocabulary(to text: String) -> String {
        var result = text
        for entry in vocabulary where entry.isEnabled {
            result = result.replacingOccurrences(
                of: entry.recognizedWord,
                with: entry.replacementWord,
                options: .caseInsensitive
            )
        }
        return result
    }

    // MARK: - Custom Templates

    private func loadCustomTemplates() {
        if let data = defaults?.data(forKey: "customTemplates"),
           let templates = try? JSONDecoder().decode([CustomTemplate].self, from: data) {
            customTemplates = templates
        }
    }

    private func saveCustomTemplates() {
        if let data = try? JSONEncoder().encode(customTemplates) {
            defaults?.set(data, forKey: "customTemplates")
        }
        syncToiCloud()
    }

    func addCustomTemplate(_ template: CustomTemplate) {
        customTemplates.append(template)
    }

    func updateCustomTemplate(_ template: CustomTemplate) {
        if let index = customTemplates.firstIndex(where: { $0.id == template.id }) {
            var updatedTemplate = template
            updatedTemplate.updatedAt = Date()
            customTemplates[index] = updatedTemplate
        }
    }

    func deleteCustomTemplate(id: UUID) {
        customTemplates.removeAll { $0.id == id }
    }

    // MARK: - History

    func addToHistory(_ record: TranscriptionRecord) {
        // TODO: Use CoreDataManager once added to target for CloudKit sync
        transcriptionHistory.insert(record, at: 0)
        saveHistory()
    }

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(transcriptionHistory) {
            defaults?.set(encoded, forKey: "transcriptionHistory")
        }
    }

    private func loadHistory() {
        if let data = defaults?.data(forKey: "transcriptionHistory"),
           let decoded = try? JSONDecoder().decode([TranscriptionRecord].self, from: data) {
            transcriptionHistory = decoded
        }
    }

    func clearHistory() {
        // TODO: Use CoreDataManager once added to target for CloudKit sync
        transcriptionHistory = []
        defaults?.removeObject(forKey: "transcriptionHistory")
    }

    // MARK: - Reset

    func resetAllSettings() {
        hasCompletedOnboarding = false
        configuredAIProviders = []
        selectedMode = .raw
        selectedTargetLanguage = .spanish
        isTranslationEnabled = false
        transcriptionHistory = []
        vocabulary = []
        customTemplates = []
        contexts = []
        activeContextId = nil
        powerModes = []
        globalMemory = nil
        globalMemoryEnabled = true

        // Clear UserDefaults
        if let bundleId = Bundle.main.bundleIdentifier {
            defaults?.removePersistentDomain(forName: bundleId)
        }
    }
}
