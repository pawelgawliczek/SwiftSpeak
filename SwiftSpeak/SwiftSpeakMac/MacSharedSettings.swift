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

    /// iCloud Key-Value Store for syncing settings between iOS and macOS
    private let iCloud: NSUbiquitousKeyValueStore? = NSUbiquitousKeyValueStore.default
    private var iCloudObserver: NSObjectProtocol?
    private var isSyncing = false
    private var isInitializing = true  // Prevent syncing during init
    private var syncWorkItem: DispatchWorkItem?  // Debounce sync calls

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
        // Phase 16: Keyboard layout settings
        static let keyboardShowSwiftSpeakBar = "icloud_keyboard_showSwiftSpeakBar"
        static let keyboardShowPredictionRow = "icloud_keyboard_showPredictionRow"
        static let keyboardProgrammableAction = "icloud_keyboard_programmableAction"
        static let keyboardShowProgrammableNextToReturn = "icloud_keyboard_showProgrammableNextToReturn"
        static let keyboardReturnProgrammableAction = "icloud_keyboard_returnProgrammableAction"
        // Streaming settings
        static let transcriptionStreamingEnabled = "icloud_transcriptionStreamingEnabled"
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

    /// Whether transcription streaming is enabled (live text as you speak)
    /// When true, context-specific provider overrides for transcription are ignored
    @Published var transcriptionStreamingEnabled: Bool = false {
        didSet {
            defaults?.set(transcriptionStreamingEnabled, forKey: "transcriptionStreamingEnabled")
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

    /// Effective transcription language: context override > global setting > auto-detect
    /// Use this for all transcription requests to respect per-context language settings
    var effectiveTranscriptionLanguage: Language? {
        // Check if active context has a custom input language
        if let contextLanguage = activeContext?.defaultInputLanguage {
            return contextLanguage
        }
        // Fall back to global setting (nil = auto-detect)
        return selectedDictationLanguage
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
            macLog("Failed to load power mode hotkeys: \(error)", category: "Settings", level: .error)
        }
    }

    // MARK: - Context Hotkeys

    /// Dictionary mapping Context IDs to their hotkey combinations
    @Published var contextHotkeys: [UUID: HotkeyCombination] = [:] {
        didSet {
            saveContextHotkeys()
        }
    }

    private func saveContextHotkeys() {
        let encoder = JSONEncoder()
        // Convert to [String: HotkeyCombination] for JSON encoding
        let stringKeyed = Dictionary(uniqueKeysWithValues: contextHotkeys.map { (key, value) in
            (key.uuidString, value)
        })

        if let data = try? encoder.encode(stringKeyed) {
            defaults?.set(data, forKey: "contextHotkeys")
        }
    }

    private func loadContextHotkeys() {
        guard let data = defaults?.data(forKey: "contextHotkeys") else { return }
        let decoder = JSONDecoder()

        do {
            let stringKeyed = try decoder.decode([String: HotkeyCombination].self, from: data)
            // Convert back to [UUID: HotkeyCombination]
            contextHotkeys = Dictionary(uniqueKeysWithValues: stringKeyed.compactMap { (key, value) in
                guard let uuid = UUID(uuidString: key) else { return nil }
                return (uuid, value)
            })
        } catch {
            macLog("Failed to load context hotkeys: \(error)", category: "Settings", level: .error)
        }
    }

    // MARK: - Last Used Context Per App

    /// Dictionary mapping app bundle IDs to the last used context ID
    /// Used when multiple contexts are assigned to the same app
    @Published var lastUsedContextPerApp: [String: UUID] = [:] {
        didSet {
            saveLastUsedContextPerApp()
        }
    }

    /// Remember which context was last used for a specific app
    func setLastUsedContext(_ contextId: UUID, forApp bundleId: String) {
        lastUsedContextPerApp[bundleId] = contextId
    }

    /// Get the last used context for an app, if any
    func getLastUsedContext(forApp bundleId: String) -> UUID? {
        lastUsedContextPerApp[bundleId]
    }

    private func saveLastUsedContextPerApp() {
        // Convert to [String: String] for JSON encoding
        let stringKeyed = Dictionary(uniqueKeysWithValues: lastUsedContextPerApp.map { (key, value) in
            (key, value.uuidString)
        })

        if let data = try? JSONEncoder().encode(stringKeyed) {
            defaults?.set(data, forKey: "lastUsedContextPerApp")
        }
    }

    private func loadLastUsedContextPerApp() {
        guard let data = defaults?.data(forKey: "lastUsedContextPerApp") else { return }

        do {
            let stringKeyed = try JSONDecoder().decode([String: String].self, from: data)
            // Convert back to [String: UUID]
            lastUsedContextPerApp = Dictionary(uniqueKeysWithValues: stringKeyed.compactMap { (key, value) in
                guard let uuid = UUID(uuidString: value) else { return nil }
                return (key, uuid)
            })
        } catch {
            macLog("Failed to load last used context per app: \(error)", category: "Settings", level: .error)
        }
    }

    // MARK: - Phase 16: Keyboard Layout Settings (syncs to iOS)

    @Published var keyboardShowSwiftSpeakBar: Bool = true {
        didSet {
            defaults?.set(keyboardShowSwiftSpeakBar, forKey: "keyboardShowSwiftSpeakBar")
            syncToiCloud()
        }
    }

    @Published var keyboardShowPredictionRow: Bool = true {
        didSet {
            defaults?.set(keyboardShowPredictionRow, forKey: "keyboardShowPredictionRow")
            syncToiCloud()
        }
    }

    @Published var keyboardProgrammableAction: MacProgrammableButtonAction = .aiSparkles {
        didSet {
            defaults?.set(keyboardProgrammableAction.rawValue, forKey: "keyboardProgrammableAction")
            syncToiCloud()
        }
    }

    @Published var keyboardShowProgrammableNextToReturn: Bool = false {
        didSet {
            defaults?.set(keyboardShowProgrammableNextToReturn, forKey: "keyboardShowProgrammableNextToReturn")
            syncToiCloud()
        }
    }

    @Published var keyboardReturnProgrammableAction: MacProgrammableButtonAction = .transcribe {
        didSet {
            defaults?.set(keyboardReturnProgrammableAction.rawValue, forKey: "keyboardReturnProgrammableAction")
            syncToiCloud()
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

    // MARK: - History (via CoreDataManager with CloudKit sync)

    /// Transcription history is managed by CoreDataManager and syncs via CloudKit
    var transcriptionHistory: [TranscriptionRecord] {
        CoreDataManager.shared.transcriptionHistory
    }

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

    @Published var playSoundOnRecordStart: Bool = false {
        didSet {
            defaults?.set(playSoundOnRecordStart, forKey: "playSoundOnRecordStart")
        }
    }

    @Published var playSoundOnRecordEnd: Bool = false {
        didSet {
            defaults?.set(playSoundOnRecordEnd, forKey: "playSoundOnRecordEnd")
        }
    }

    // MARK: - Audio Quality (Network Optimization)

    /// Audio quality setting for transcription - affects file size and upload speed
    @Published var audioQuality: AudioQualityMode = .auto {
        didSet {
            defaults?.set(audioQuality.rawValue, forKey: "audioQuality")
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
        macLog("Initialization complete, sync now enabled", category: "iCloud")
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
            macLog("iCloud KVS disabled, skipping sync setup", category: "iCloud")
            return
        }

        macLog("Setting up iCloud KVS sync...", category: "iCloud")

        // Check if iCloud is available
        let testKey = "icloud_test_\(Date().timeIntervalSince1970)"
        iCloud?.set("test", forKey: testKey)
        let syncResult = iCloud?.synchronize()
        macLog("KVS sync test: synchronize() returned \(String(describing: syncResult))", category: "iCloud")
        iCloud?.removeObject(forKey: testKey)

        // Log current iCloud state
        if let keys = iCloud?.dictionaryRepresentation.keys {
            macLog("KVS current keys: \(Array(keys).joined(separator: ", "))", category: "iCloud")
        } else {
            macLog("KVS not available", category: "iCloud", level: .warning)
        }

        // Listen for iCloud changes from other devices
        iCloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloud,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            macLog("Received external change notification!", category: "iCloud")

            guard let userInfo = notification.userInfo,
                  let reasonNumber = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? NSNumber else {
                macLog("No reason in notification userInfo", category: "iCloud", level: .warning)
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
            macLog("Change reason: \(reasonName)", category: "iCloud")

            if let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
                macLog("Changed keys: \(changedKeys.joined(separator: ", "))", category: "iCloud")
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
                macLog("iCloud storage quota exceeded", category: "iCloud", level: .error)
            default:
                break
            }
        }

        // Synchronize to get latest changes
        let initialSync = iCloud?.synchronize()
        macLog("Sync initialized, initial synchronize() returned \(String(describing: initialSync))", category: "iCloud")

        // Try to load any existing data
        loadFromiCloud()
    }

    private func loadFromiCloud() {
        macLog("loadFromiCloud: Starting to load from iCloud KVS...", category: "iCloud")

        // Load providers
        if let data = iCloud?.data(forKey: iCloudKeys.configuredAIProviders) {
            macLog("loadFromiCloud: Found providers data (\(data.count) bytes)", category: "iCloud")
            if let providers = try? JSONDecoder().decode([AIProviderConfig].self, from: data) {
                configuredAIProviders = providers
                macLog("loadFromiCloud: Loaded \(providers.count) providers:", category: "iCloud")
                for p in providers {
                    macLog("  - \(p.provider.displayName): apiKey=\(!p.apiKey.isEmpty), projectId=\(p.googleProjectId ?? "nil")", category: "iCloud")
                }
            } else {
                macLog("loadFromiCloud: Failed to decode providers data", category: "iCloud", level: .error)
            }
        } else {
            macLog("loadFromiCloud: No providers data in iCloud KVS", category: "iCloud")
        }

        // Load contexts
        if let data = iCloud?.data(forKey: iCloudKeys.contexts),
           let loadedContexts = try? JSONDecoder().decode([ConversationContext].self, from: data) {
            contexts = loadedContexts
            macLog("loadFromiCloud: Loaded \(loadedContexts.count) contexts", category: "iCloud")
        } else {
            macLog("loadFromiCloud: No contexts data in iCloud KVS", category: "iCloud")
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
                macLog("loadFromiCloud: Loaded history memory from iCloud", category: "iCloud")
            }
        }

        // Load keyboard settings (Phase 16)
        if let showBar = iCloud?.object(forKey: iCloudKeys.keyboardShowSwiftSpeakBar) as? Bool {
            keyboardShowSwiftSpeakBar = showBar
        }
        if let showPrediction = iCloud?.object(forKey: iCloudKeys.keyboardShowPredictionRow) as? Bool {
            keyboardShowPredictionRow = showPrediction
        }
        if let actionRaw = iCloud?.string(forKey: iCloudKeys.keyboardProgrammableAction),
           let action = MacProgrammableButtonAction(rawValue: actionRaw) {
            keyboardProgrammableAction = action
        }
        if let showNextToReturn = iCloud?.object(forKey: iCloudKeys.keyboardShowProgrammableNextToReturn) as? Bool {
            keyboardShowProgrammableNextToReturn = showNextToReturn
        }
        if let returnActionRaw = iCloud?.string(forKey: iCloudKeys.keyboardReturnProgrammableAction),
           let returnAction = MacProgrammableButtonAction(rawValue: returnActionRaw) {
            keyboardReturnProgrammableAction = returnAction
        }

        // Load streaming settings
        if let streamingEnabled = iCloud?.object(forKey: iCloudKeys.transcriptionStreamingEnabled) as? Bool {
            transcriptionStreamingEnabled = streamingEnabled
        }
    }

    private func syncToiCloud() {
        guard !isInitializing else {
            // Don't sync during initialization - we're still loading
            return
        }

        // Cancel any pending sync and schedule a new one after debounce delay
        // This coalesces rapid-fire setting changes into a single sync
        syncWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.performSync()
        }
        syncWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func performSync() {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        // Sync providers
        if let data = try? JSONEncoder().encode(configuredAIProviders) {
            iCloud?.set(data, forKey: iCloudKeys.configuredAIProviders)
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

        // Sync keyboard settings (Phase 16)
        iCloud?.set(keyboardShowSwiftSpeakBar, forKey: iCloudKeys.keyboardShowSwiftSpeakBar)
        iCloud?.set(keyboardShowPredictionRow, forKey: iCloudKeys.keyboardShowPredictionRow)
        iCloud?.set(keyboardProgrammableAction.rawValue, forKey: iCloudKeys.keyboardProgrammableAction)
        iCloud?.set(keyboardShowProgrammableNextToReturn, forKey: iCloudKeys.keyboardShowProgrammableNextToReturn)
        iCloud?.set(keyboardReturnProgrammableAction.rawValue, forKey: iCloudKeys.keyboardReturnProgrammableAction)

        // Sync streaming settings
        iCloud?.set(transcriptionStreamingEnabled, forKey: iCloudKeys.transcriptionStreamingEnabled)

        // Set sync timestamp
        iCloud?.set(Date().timeIntervalSince1970, forKey: iCloudKeys.lastSyncTimestamp)

        // Trigger synchronization
        _ = iCloud?.synchronize()
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
        loadContextHotkeys()
        loadLastUsedContextPerApp()
        loadHistoryMemory()
        loadCustomTemplates()
        loadVocabulary()
        loadObsidianVaults()
        loadObsidianAPIConfig()

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
        if defaults?.object(forKey: "transcriptionStreamingEnabled") != nil {
            transcriptionStreamingEnabled = defaults?.bool(forKey: "transcriptionStreamingEnabled") ?? false
        }
        if defaults?.object(forKey: "powerModeStreamingEnabled") != nil {
            powerModeStreamingEnabled = defaults?.bool(forKey: "powerModeStreamingEnabled") ?? true
        }
        if defaults?.object(forKey: "autoReturnEnabled") != nil {
            autoReturnEnabled = defaults?.bool(forKey: "autoReturnEnabled") ?? true
        }
        if defaults?.object(forKey: "playSoundOnRecordStart") != nil {
            playSoundOnRecordStart = defaults?.bool(forKey: "playSoundOnRecordStart") ?? false
        }
        if defaults?.object(forKey: "playSoundOnRecordEnd") != nil {
            playSoundOnRecordEnd = defaults?.bool(forKey: "playSoundOnRecordEnd") ?? false
        }

        // Load audio quality setting
        if let qualityRaw = defaults?.string(forKey: "audioQuality"),
           let quality = AudioQualityMode(rawValue: qualityRaw) {
            audioQuality = quality
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

        // Load keyboard settings (Phase 16)
        if defaults?.object(forKey: "keyboardShowSwiftSpeakBar") != nil {
            keyboardShowSwiftSpeakBar = defaults?.bool(forKey: "keyboardShowSwiftSpeakBar") ?? true
        }
        if defaults?.object(forKey: "keyboardShowPredictionRow") != nil {
            keyboardShowPredictionRow = defaults?.bool(forKey: "keyboardShowPredictionRow") ?? true
        }
        if let actionRaw = defaults?.string(forKey: "keyboardProgrammableAction"),
           let action = MacProgrammableButtonAction(rawValue: actionRaw) {
            keyboardProgrammableAction = action
        }
        if defaults?.object(forKey: "keyboardShowProgrammableNextToReturn") != nil {
            keyboardShowProgrammableNextToReturn = defaults?.bool(forKey: "keyboardShowProgrammableNextToReturn") ?? false
        }
        if let returnActionRaw = defaults?.string(forKey: "keyboardReturnProgrammableAction"),
           let returnAction = MacProgrammableButtonAction(rawValue: returnActionRaw) {
            keyboardReturnProgrammableAction = returnAction
        }

        // History is now loaded from CoreDataManager (CloudKit synced)
        // Migrate any existing UserDefaults history on first launch
        DataMigrationManager.shared.migrateIfNeeded()
    }

    // MARK: - History Management

    func clearTranscriptionHistory() {
        CoreDataManager.shared.clearTranscriptionHistory()
    }

    // MARK: - AI Provider Management

    private func loadConfiguredAIProviders() {
        if let data = defaults?.data(forKey: "configuredAIProviders"),
           let providers = try? JSONDecoder().decode([AIProviderConfig].self, from: data) {
            configuredAIProviders = providers
            macLog("Loaded \(providers.count) providers from UserDefaults: \(providers.map { "\($0.provider.displayName)(key:\(!$0.apiKey.isEmpty), projectId:\($0.googleProjectId ?? "nil"))" })", category: "Settings")
        } else {
            // Default to empty - user adds providers in settings
            configuredAIProviders = []
            macLog("No providers in UserDefaults, starting empty", category: "Settings")
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

    /// Obsidian Local REST API configuration (macOS only)
    /// When enabled, uses direct API calls instead of embeddings for search
    @Published var obsidianAPIConfig: ObsidianAPIConfig = ObsidianAPIConfig() {
        didSet {
            saveObsidianAPIConfig()
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

    private func loadObsidianAPIConfig() {
        if let data = defaults?.data(forKey: "obsidianAPIConfig"),
           let config = try? JSONDecoder().decode(ObsidianAPIConfig.self, from: data) {
            obsidianAPIConfig = config
        }
    }

    private func saveObsidianAPIConfig() {
        if let data = try? JSONEncoder().encode(obsidianAPIConfig) {
            defaults?.set(data, forKey: "obsidianAPIConfig")
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

    // MARK: - History (CoreDataManager with CloudKit sync)

    func addToHistory(_ record: TranscriptionRecord) {
        CoreDataManager.shared.addTranscription(record)
    }

    func deleteFromHistory(id: UUID) {
        CoreDataManager.shared.deleteTranscription(id: id)
    }

    func clearHistory() {
        CoreDataManager.shared.clearTranscriptionHistory()
    }

    // MARK: - Reset

    func resetAllSettings() {
        hasCompletedOnboarding = false
        configuredAIProviders = []
        selectedMode = .raw
        selectedTargetLanguage = .spanish
        isTranslationEnabled = false
        clearHistory() // Uses CoreDataManager
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

// MARK: - ContextProviderManager Conformance

extension MacSettings: ContextProviderManager {
    // Protocol requirements are already implemented in MacSettings:
    // - contexts: [ConversationContext]
    // - activeContextId: UUID?
    // - transcriptionStreamingEnabled: Bool
    // - selectedTranscriptionProvider: AIProvider
    // - selectedTranslationProvider: AIProvider
    // - selectedPowerModeProvider: AIProvider
    //
    // Default implementations from protocol extension provide:
    // - activeContext: ConversationContext?
    // - effectiveTranscriptionProvider: ProviderSelection
    // - effectiveTranslationProvider: ProviderSelection
    // - effectiveAIProvider: ProviderSelection
}

// MARK: - Programmable Button Action (Phase 16)

/// Programmable button actions for the iOS keyboard PredictionRow
/// Syncs via iCloud to iOS devices
enum MacProgrammableButtonAction: String, Codable, CaseIterable, Identifiable {
    case aiSparkles = "ai_sparkles"
    case transcribe = "transcribe"
    case translate = "translate"
    case aiFormat = "ai_format"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aiSparkles: return "AI Sparkles"
        case .transcribe: return "Transcribe"
        case .translate: return "Translate"
        case .aiFormat: return "AI Format"
        }
    }

    var iconName: String {
        switch self {
        case .aiSparkles: return "sparkles"
        case .transcribe: return "mic.fill"
        case .translate: return "globe"
        case .aiFormat: return "wand.and.stars"
        }
    }
}
