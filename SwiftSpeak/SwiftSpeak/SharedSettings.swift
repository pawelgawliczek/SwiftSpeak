//
//  SharedSettings.swift
//  SwiftSpeak
//
//  App Groups data sharing between main app and keyboard extension
//

import Foundation
import Combine
import SwiftSpeakCore

@MainActor
class SharedSettings: ObservableObject {
    static let shared = SharedSettings()

    private let defaults: UserDefaults?

    // MARK: - Phase 6: Security Services

    /// Keychain manager for secure API key storage
    private let keychainManager: SecureStorageProtocol

    // MARK: - iCloud Sync

    /// iCloud Key-Value Store for syncing settings between iOS and macOS
    private let iCloud: NSUbiquitousKeyValueStore? = NSUbiquitousKeyValueStore.default
    private var iCloudObserver: NSObjectProtocol?
    private var isSyncing = false
    private var isInitializing = true  // Prevent syncing during init

    /// iCloud sync keys - MUST match MacSharedSettings.swift for cross-platform sync
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
        static let selectedFormattingProvider = "icloud_selectedFormattingProvider"
        static let selectedPowerModeProvider = "icloud_selectedPowerModeProvider"
        static let selectedMode = "icloud_selectedMode"
        static let selectedTargetLanguage = "icloud_selectedTargetLanguage"
        static let isTranslationEnabled = "icloud_isTranslationEnabled"
        static let transcriptionHistory = "icloud_transcriptionHistory"
        static let historyMemory = "icloud_historyMemory"
        static let lastSyncTimestamp = "icloud_lastSyncTimestamp"
        // Keyboard Layout Settings (Phase 16)
        static let keyboardShowSwiftSpeakBar = "icloud_keyboard_showSwiftSpeakBar"
        static let keyboardShowPredictionRow = "icloud_keyboard_showPredictionRow"
        static let keyboardProgrammableAction = "icloud_keyboard_programmableAction"
        static let keyboardShowProgrammableNextToReturn = "icloud_keyboard_showProgrammableNextToReturn"
        static let keyboardReturnProgrammableAction = "icloud_keyboard_returnProgrammableAction"
        // Streaming settings
        static let transcriptionStreamingEnabled = "icloud_transcriptionStreamingEnabled"
        // Hidden contexts
        static let hiddenContextIds = "icloud_hiddenContextIds"
        // Subscription tier
        static let subscriptionTier = "icloud_subscriptionTier"
        // Quick Actions (Autocomplete Suggestions)
        static let quickSuggestionsEnabled = "icloud_quickSuggestionsEnabled"
        static let quickActions = "icloud_quickActions"
    }

    // MARK: - Published Properties

    @Published var hasCompletedOnboarding: Bool = false {
        didSet {
            defaults?.set(hasCompletedOnboarding, forKey: Constants.Keys.hasCompletedOnboarding)
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
            defaults?.set(selectedTranscriptionProvider.rawValue, forKey: Constants.Keys.selectedTranscriptionProvider)
            syncToiCloud()
        }
    }

    @Published var selectedTranslationProvider: AIProvider = .openAI {
        didSet {
            defaults?.set(selectedTranslationProvider.rawValue, forKey: Constants.Keys.selectedTranslationProvider)
            syncToiCloud()
        }
    }

    @Published var selectedFormattingProvider: AIProvider = .openAI {
        didSet {
            defaults?.set(selectedFormattingProvider.rawValue, forKey: Constants.Keys.selectedFormattingProvider)
            syncToiCloud()
        }
    }

    @Published var selectedPowerModeProvider: AIProvider = .openAI {
        didSet {
            defaults?.set(selectedPowerModeProvider.rawValue, forKey: Constants.Keys.selectedPowerModeProvider)
            syncToiCloud()
        }
    }

    @Published var selectedMode: FormattingMode = .raw {
        didSet {
            defaults?.set(selectedMode.rawValue, forKey: Constants.Keys.selectedMode)
            syncToiCloud()
        }
    }

    @Published var selectedTargetLanguage: Language = .spanish {
        didSet {
            defaults?.set(selectedTargetLanguage.rawValue, forKey: Constants.Keys.selectedTargetLanguage)
            syncToiCloud()
        }
    }

    /// Source language for dictation/transcription (nil = auto-detect)
    @Published var selectedDictationLanguage: Language? = nil {
        didSet {
            if let lang = selectedDictationLanguage {
                defaults?.set(lang.rawValue, forKey: Constants.Keys.selectedDictationLanguage)
            } else {
                defaults?.removeObject(forKey: Constants.Keys.selectedDictationLanguage)
            }
        }
    }

    /// Effective transcription language: context override > global setting > auto-detect
    /// Use this for all transcription requests to respect per-context language settings
    var effectiveTranscriptionLanguage: Language? {
        if let context = activeContext {
            // Context explicitly set to auto-detect
            if context.autoDetectInputLanguage {
                return nil
            }
            // Context has a specific language override
            if let contextLanguage = context.defaultInputLanguage {
                return contextLanguage
            }
        }
        // Fall back to global setting (nil = auto-detect)
        return selectedDictationLanguage
    }

    /// Output transcription in Arabizi (Franco-Arabic) format
    /// Converts Arabic script to Latin alphabet with number substitutions (e.g., 3=ع, 7=ح)
    /// Only applies when language is Arabic or Egyptian Arabic
    @Published var outputArabizi: Bool = false {
        didSet {
            defaults?.set(outputArabizi, forKey: "outputArabizi")
            syncToiCloud()
        }
    }

    /// Effective Arabizi output setting: context override > global setting
    /// Use this to determine if Arabizi formatting should be applied
    /// Note: Power mode override is handled by the orchestrator when a power mode is active
    var effectiveOutputArabizi: Bool {
        // Check active context override
        if let contextArabizi = activeContext?.outputArabizi {
            return contextArabizi
        }
        // Fall back to global setting
        return outputArabizi
    }

    /// Check if Arabizi output option should be visible
    /// Only show when effective language is Arabic or Egyptian Arabic
    var shouldShowArabiziOption: Bool {
        guard let language = effectiveTranscriptionLanguage else { return false }
        return language == .arabic || language == .egyptianArabic
    }

    @Published var isTranslationEnabled: Bool = false {
        didSet {
            defaults?.set(isTranslationEnabled, forKey: Constants.Keys.isTranslationEnabled)
            syncToiCloud()
        }
    }

    @Published var autoReturnEnabled: Bool = true {
        didSet {
            defaults?.set(autoReturnEnabled, forKey: Constants.Keys.autoReturnEnabled)
        }
    }

    /// Audio quality mode for transcription
    @Published var audioQuality: AudioQualityMode = .auto {
        didSet {
            defaults?.set(audioQuality.rawValue, forKey: "audioQuality")
        }
    }

    @Published var subscriptionTier: SubscriptionTier = .free {
        didSet {
            defaults?.set(subscriptionTier.rawValue, forKey: Constants.Keys.subscriptionTier)
            syncToiCloud()
        }
    }

    @Published var customTemplates: [CustomTemplate] = [] {
        didSet {
            saveCustomTemplates()
        }
    }

    /// Currently selected custom template (set from keyboard URL scheme)
    @Published var selectedCustomTemplate: CustomTemplate?

    // MARK: - Phase 4: Contexts

    @Published var contexts: [ConversationContext] = [] {
        didSet {
            saveContexts()
        }
    }

    @Published var activeContextId: UUID? {
        didSet {
            if let id = activeContextId {
                defaults?.set(id.uuidString, forKey: Constants.Keys.activeContextId)
                // Find context for logging and prediction settings sync
                let context = contexts.first(where: { $0.id == id }) ?? ConversationContext.presets.first(where: { $0.id == id })
                let contextName = context?.name ?? "unknown"
                appLog("activeContextId didSet: changed to '\(contextName)' (id: \(id.uuidString.prefix(8))...)", category: "Context", level: .debug)

                // Sync prediction settings for keyboard extension
                syncPredictionSettingsToAppGroups(context: context)
            } else {
                defaults?.removeObject(forKey: Constants.Keys.activeContextId)
                appLog("activeContextId didSet: cleared to nil", category: "Context", level: .debug)

                // Clear prediction settings (use defaults)
                syncPredictionSettingsToAppGroups(context: nil)
            }
        }
    }

    // MARK: - Phase 4: Power Modes

    @Published var powerModes: [PowerMode] = [] {
        didSet {
            savePowerModes()
        }
    }

    // MARK: - Quick Actions (Autocomplete Suggestions)

    /// Whether quick suggestions are enabled for the prediction button
    @Published var quickSuggestionsEnabled: Bool = true {
        didSet {
            defaults?.set(quickSuggestionsEnabled, forKey: "quickSuggestionsEnabled")
            syncToiCloud()
        }
    }

    /// Quick actions for generating typed predictions (positive, neutral, negative, etc.)
    @Published var quickActions: [QuickAction] = .defaultActions {
        didSet {
            saveQuickActions()
        }
    }

    // MARK: - Obsidian Vaults

    @Published var obsidianVaults: [ObsidianVault] = [] {
        didSet {
            saveObsidianVaults()
        }
    }

    // MARK: - Phase 4: History Memory (Global)

    @Published var historyMemory: HistoryMemory? {
        didSet {
            saveHistoryMemory()
            syncToiCloud()
        }
    }

    // MARK: - Phase 4a: Global Memory (3-Tier System)

    /// Global memory - always injected into prompts when enabled
    @Published var globalMemory: String? {
        didSet {
            defaults?.set(globalMemory, forKey: Constants.Keys.globalMemory)
            syncToiCloud()
        }
    }

    /// Whether global memory injection is enabled
    @Published var globalMemoryEnabled: Bool = true {
        didSet {
            defaults?.set(globalMemoryEnabled, forKey: Constants.Keys.globalMemoryEnabled)
            syncToiCloud()
        }
    }

    /// Maximum character limit for global memory (500-2000, default 2000)
    @Published var globalMemoryLimit: Int = 2000 {
        didSet {
            // Clamp to valid range
            let clamped = min(max(globalMemoryLimit, 500), 2000)
            if clamped != globalMemoryLimit {
                globalMemoryLimit = clamped
            }
            defaults?.set(globalMemoryLimit, forKey: Constants.Keys.globalMemoryLimit)
            syncToiCloud()
        }
    }

    // MARK: - Memory Update Tracking (batch updates)

    /// Last time global memory was updated by the batch process
    @Published var lastGlobalMemoryUpdate: Date? {
        didSet {
            defaults?.set(lastGlobalMemoryUpdate, forKey: Constants.Keys.lastGlobalMemoryUpdate)
        }
    }

    /// Last update times for each context's memory [contextId: Date]
    @Published var lastContextMemoryUpdates: [UUID: Date] = [:] {
        didSet {
            saveContextMemoryUpdates()
        }
    }

    /// Last update times for each power mode's memory [powerModeId: Date]
    @Published var lastPowerModeMemoryUpdates: [UUID: Date] = [:] {
        didSet {
            savePowerModeMemoryUpdates()
        }
    }

    /// Whether Power Mode streaming is enabled (progressive text rendering)
    /// Only affects Power Mode LLM responses, NOT transcription or translation
    @Published var powerModeStreamingEnabled: Bool = true {
        didSet {
            defaults?.set(powerModeStreamingEnabled, forKey: Constants.Keys.powerModeStreamingEnabled)
        }
    }

    /// Whether transcription streaming is enabled (live text as you speak)
    /// Requires a streaming-capable provider (OpenAI Realtime, Deepgram, AssemblyAI)
    @Published var transcriptionStreamingEnabled: Bool = false {
        didSet {
            defaults?.set(transcriptionStreamingEnabled, forKey: Constants.Keys.transcriptionStreamingEnabled)
            syncToiCloud()
        }
    }

    // MARK: - Hidden Contexts

    /// Set of context IDs (preset or custom) that the user has hidden
    @Published var hiddenContextIds: Set<UUID> = [] {
        didSet {
            saveHiddenContextIds()
            syncToiCloud()
        }
    }

    /// Hide a context from the main view
    func hideContext(_ contextId: UUID) {
        hiddenContextIds.insert(contextId)
    }

    /// Show a previously hidden context
    func showContext(_ contextId: UUID) {
        hiddenContextIds.remove(contextId)
    }

    /// Check if a context is hidden
    func isContextHidden(_ contextId: UUID) -> Bool {
        hiddenContextIds.contains(contextId)
    }

    private func saveHiddenContextIds() {
        let uuidStrings = hiddenContextIds.map { $0.uuidString }
        defaults?.set(uuidStrings, forKey: "hiddenContextIds")
    }

    private func loadHiddenContextIds() {
        // Try loading from new key first, then fall back to old key for migration
        if let uuidStrings = defaults?.stringArray(forKey: "hiddenContextIds") {
            hiddenContextIds = Set(uuidStrings.compactMap { UUID(uuidString: $0) })
        } else if let uuidStrings = defaults?.stringArray(forKey: "hiddenPresetContextIds") {
            // Migrate from old key
            hiddenContextIds = Set(uuidStrings.compactMap { UUID(uuidString: $0) })
            // Save to new key and remove old key
            saveHiddenContextIds()
            defaults?.removeObject(forKey: "hiddenPresetContextIds")
        }
    }

    // MARK: - Phase 6: Security & Privacy

    /// Whether biometric protection (Face ID/Touch ID) is required for Settings and History
    @Published var biometricProtectionEnabled: Bool = false {
        didSet {
            defaults?.set(biometricProtectionEnabled, forKey: Constants.Keys.biometricProtectionEnabled)
        }
    }

    /// Auto-delete transcription history after specified period
    @Published var dataRetentionPeriod: DataRetentionPeriod = .never {
        didSet {
            defaults?.set(dataRetentionPeriod.rawValue, forKey: Constants.Keys.dataRetentionPeriod)
        }
    }

    // MARK: - App Library: User Category Overrides

    /// User overrides for app categories (e.g., moving Notion from Work to Personal)
    @Published var userAppCategoryOverrides: [UserAppCategoryOverride] = [] {
        didSet {
            saveUserAppCategoryOverrides()
        }
    }

    // MARK: - Phase 4e: RAG Knowledge Documents

    /// Knowledge documents for Power Mode RAG
    @Published var knowledgeDocuments: [KnowledgeDocument] = [] {
        didSet {
            saveKnowledgeDocuments()
        }
    }

    // MARK: - Phase 4f: Webhooks

    /// Global webhook configurations (enabled per Power Mode)
    @Published var webhooks: [Webhook] = [] {
        didSet {
            saveWebhooks()
        }
    }

    // MARK: - Phase 10: Local Model Configuration

    /// WhisperKit on-device transcription configuration
    @Published var whisperKitConfig: WhisperKitSettings = .default {
        didSet {
            saveWhisperKitConfig()
        }
    }

    /// Apple Intelligence on-device text processing configuration
    @Published var appleIntelligenceConfig: AppleIntelligenceConfig = .default {
        didSet {
            saveAppleIntelligenceConfig()
        }
    }

    /// Apple Translation on-device translation configuration
    @Published var appleTranslationConfig: AppleTranslationConfig = .default {
        didSet {
            saveAppleTranslationConfig()
        }
    }

    /// Global default provider settings per capability
    @Published var providerDefaults: ProviderDefaults = .default {
        didSet {
            saveProviderDefaults()
        }
    }

    /// Force all processing to use local-only models (privacy mode)
    @Published var forcePrivacyMode: Bool = false {
        didSet {
            defaults?.set(forcePrivacyMode, forKey: Constants.Keys.forcePrivacyMode)
        }
    }

    // MARK: - Phase 13.8: Swipe Typing

    /// Enable swipe/glide typing on QWERTY keyboard
    @Published var swipeTypingEnabled: Bool = true {
        didSet {
            defaults?.set(swipeTypingEnabled, forKey: Constants.Keys.swipeTypingEnabled)
        }
    }

    // MARK: - Phase 16: Keyboard Layout Settings

    /// Whether to show the SwiftSpeakBar in typing mode (saves ~50pt height when hidden)
    @Published var keyboardShowSwiftSpeakBar: Bool = true {
        didSet {
            defaults?.set(keyboardShowSwiftSpeakBar, forKey: Constants.Keys.keyboardShowSwiftSpeakBar)
            syncToiCloud()
        }
    }

    /// Whether to show the PredictionRow in typing mode (saves ~36pt height when hidden)
    @Published var keyboardShowPredictionRow: Bool = true {
        didSet {
            defaults?.set(keyboardShowPredictionRow, forKey: Constants.Keys.keyboardShowPredictionRow)
            syncToiCloud()
        }
    }

    /// The action assigned to the programmable button in PredictionRow
    @Published var keyboardProgrammableAction: ProgrammableButtonAction = .aiSparkles {
        didSet {
            defaults?.set(keyboardProgrammableAction.rawValue, forKey: Constants.Keys.keyboardProgrammableAction)
            syncToiCloud()
        }
    }

    /// Whether to show a programmable button next to the Return key (shrinks Return slightly)
    @Published var keyboardShowProgrammableNextToReturn: Bool = false {
        didSet {
            defaults?.set(keyboardShowProgrammableNextToReturn, forKey: Constants.Keys.keyboardShowProgrammableNextToReturn)
            syncToiCloud()
        }
    }

    /// The action assigned to the programmable button next to Return key
    @Published var keyboardReturnProgrammableAction: ProgrammableButtonAction = .transcribe {
        didSet {
            defaults?.set(keyboardReturnProgrammableAction.rawValue, forKey: Constants.Keys.keyboardReturnProgrammableAction)
            syncToiCloud()
        }
    }

    // MARK: - Autocomplete Suggestions (Keyboard) - LEGACY
    // NOTE: These local properties are LEGACY. Use iCloud-synced quickSuggestionsEnabled
    // and quickActions instead. These are kept for backwards compatibility only.
    // Will be removed in a future cleanup.

    /// LEGACY: Use quickSuggestionsEnabled instead (iCloud synced)
    @Published var keyboardQuickSuggestionsEnabled: Bool = false {
        didSet {
            defaults?.set(keyboardQuickSuggestionsEnabled, forKey: "keyboardQuickSuggestionsEnabled")
        }
    }

    /// LEGACY: Use quickActions instead (iCloud synced)
    @Published var keyboardQuickActions: [QuickAction] = [] {
        didSet {
            saveKeyboardQuickActions()
        }
    }

    private func saveKeyboardQuickActions() {
        if let data = try? JSONEncoder().encode(keyboardQuickActions) {
            defaults?.set(data, forKey: Constants.Keys.keyboardQuickActions)
        }
    }

    private func loadKeyboardQuickActions() {
        guard let data = defaults?.data(forKey: Constants.Keys.keyboardQuickActions),
              let actions = try? JSONDecoder().decode([QuickAction].self, from: data) else {
            return
        }
        keyboardQuickActions = actions
    }

    /// Reload keyboard settings from App Groups (call when view appears to pick up keyboard changes)
    func reloadKeyboardSettings() {
        if let showBar = defaults?.object(forKey: Constants.Keys.keyboardShowSwiftSpeakBar) as? Bool,
           showBar != keyboardShowSwiftSpeakBar {
            keyboardShowSwiftSpeakBar = showBar
        }
        if let showPrediction = defaults?.object(forKey: Constants.Keys.keyboardShowPredictionRow) as? Bool,
           showPrediction != keyboardShowPredictionRow {
            keyboardShowPredictionRow = showPrediction
        }
        if let actionRaw = defaults?.string(forKey: Constants.Keys.keyboardProgrammableAction),
           let action = ProgrammableButtonAction(rawValue: actionRaw),
           action != keyboardProgrammableAction {
            keyboardProgrammableAction = action
        }
        if let showNextToReturn = defaults?.object(forKey: Constants.Keys.keyboardShowProgrammableNextToReturn) as? Bool,
           showNextToReturn != keyboardShowProgrammableNextToReturn {
            keyboardShowProgrammableNextToReturn = showNextToReturn
        }
        if let returnActionRaw = defaults?.string(forKey: Constants.Keys.keyboardReturnProgrammableAction),
           let returnAction = ProgrammableButtonAction(rawValue: returnActionRaw),
           returnAction != keyboardReturnProgrammableAction {
            keyboardReturnProgrammableAction = returnAction
        }
    }

    // MARK: - SwiftLink: Background Dictation Sessions

    /// Apps configured for SwiftLink
    @Published var swiftLinkApps: [SwiftLinkApp] = [] {
        didSet {
            saveSwiftLinkApps()
        }
    }

    /// SwiftLink session duration setting
    @Published var swiftLinkSessionDuration: Constants.SwiftLinkSessionDuration = .fifteenMinutes {
        didSet {
            defaults?.set(swiftLinkSessionDuration.rawValue, forKey: Constants.Keys.swiftLinkSessionDuration)
        }
    }

    /// Auto-start SwiftLink when using voice input (enabled by default)
    @Published var swiftLinkAutoStart: Bool = true {
        didSet {
            defaults?.set(swiftLinkAutoStart, forKey: Constants.Keys.swiftLinkAutoStart)
        }
    }

    /// Enable screen context capture for better transcription formatting
    /// When enabled, captures screen text during SwiftLink sessions via ReplayKit
    @Published var contextCaptureEnabled: Bool = false {
        didSet {
            defaults?.set(contextCaptureEnabled, forKey: "contextCaptureEnabled")
        }
    }

    // MARK: - Phase 11: Retry & Processing Status

    /// Enable automatic retry on network/provider failure
    @Published var autoRetryEnabled: Bool = true {
        didSet {
            defaults?.set(autoRetryEnabled, forKey: "autoRetryEnabled")
        }
    }

    /// Maximum number of retry attempts
    @Published var maxRetryCount: Int = 3 {
        didSet {
            defaults?.set(maxRetryCount, forKey: "maxRetryCount")
        }
    }

    /// Keep audio files for failed transcriptions (for manual retry)
    @Published var keepFailedRecordings: Bool = true {
        didSet {
            defaults?.set(keepFailedRecordings, forKey: "keepFailedRecordings")
        }
    }

    /// Days to retain pending audio before auto-cleanup (0 = never)
    @Published var pendingAudioRetentionDays: Int = 7 {
        didSet {
            defaults?.set(pendingAudioRetentionDays, forKey: "pendingAudioRetentionDays")
        }
    }

    /// Queue of audio files awaiting retry
    @Published var pendingAudioQueue: [PendingAudio] = [] {
        didSet {
            savePendingAudioQueue()
        }
    }

    /// Current processing status (shared with keyboard extension)
    var processingStatus: ProcessingStatus {
        get {
            guard let data = defaults?.data(forKey: "processingStatus"),
                  let status = try? JSONDecoder().decode(ProcessingStatus.self, from: data) else {
                return .idle
            }
            return status
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults?.set(data, forKey: "processingStatus")
            }
        }
    }

    // MARK: - Phase 11: Advanced Token Limits

    /// Maximum tokens for global memory in prompts
    @Published var tokenLimitGlobalMemory: Int = 500 {
        didSet {
            defaults?.set(tokenLimitGlobalMemory, forKey: "tokenLimitGlobalMemory")
        }
    }

    /// Maximum tokens for context memory in prompts
    @Published var tokenLimitContextMemory: Int = 400 {
        didSet {
            defaults?.set(tokenLimitContextMemory, forKey: "tokenLimitContextMemory")
        }
    }

    /// Maximum tokens for RAG chunks in prompts
    @Published var tokenLimitRAGChunks: Int = 2000 {
        didSet {
            defaults?.set(tokenLimitRAGChunks, forKey: "tokenLimitRAGChunks")
        }
    }

    /// Maximum tokens for user input
    @Published var tokenLimitUserInput: Int = 4000 {
        didSet {
            defaults?.set(tokenLimitUserInput, forKey: "tokenLimitUserInput")
        }
    }

    // MARK: - Non-Published Properties

    var openAIAPIKey: String? {
        get { defaults?.string(forKey: Constants.Keys.openAIAPIKey) }
        set { defaults?.set(newValue, forKey: Constants.Keys.openAIAPIKey) }
    }

    var anthropicAPIKey: String? {
        get { defaults?.string(forKey: Constants.Keys.anthropicAPIKey) }
        set { defaults?.set(newValue, forKey: Constants.Keys.anthropicAPIKey) }
    }

    var elevenLabsAPIKey: String? {
        get { defaults?.string(forKey: Constants.Keys.elevenLabsAPIKey) }
        set { defaults?.set(newValue, forKey: Constants.Keys.elevenLabsAPIKey) }
    }

    var deepgramAPIKey: String? {
        get { defaults?.string(forKey: Constants.Keys.deepgramAPIKey) }
        set { defaults?.set(newValue, forKey: Constants.Keys.deepgramAPIKey) }
    }

    /// Legacy property - use localConfig in AIProviderConfig instead
    @available(*, deprecated, message: "Use localConfig in AIProviderConfig instead")
    var ollamaEndpoint: String? {
        get { defaults?.string(forKey: Constants.Keys.ollamaEndpoint) }
        set { defaults?.set(newValue, forKey: Constants.Keys.ollamaEndpoint) }
    }

    /// Get the local provider configuration
    var localProviderConfig: LocalProviderConfig? {
        getAIProviderConfig(for: .local)?.localConfig
    }

    /// Get the self-hosted LLM configuration (Ollama, LM Studio)
    /// Alias for localProviderConfig, used by LocalModelSettingsProvider protocol
    var selfHostedLLMConfig: LocalProviderConfig? {
        localProviderConfig
    }

    var lastTranscription: String? {
        get { defaults?.string(forKey: Constants.Keys.lastTranscription) }
        set { defaults?.set(newValue, forKey: Constants.Keys.lastTranscription) }
    }

    // Transcription history is now stored in Core Data with CloudKit sync (unlimited records)
    // This computed property delegates to CoreDataManager for reading
    // Note: For backwards compatibility, we also maintain a small cache in UserDefaults
    // for the keyboard extension which can't easily access Core Data
    var transcriptionHistory: [TranscriptionRecord] {
        get {
            // Use Core Data as source of truth (syncs via CloudKit)
            return CoreDataManager.shared.transcriptionHistory
        }
        set {
            // This setter is mainly for compatibility - prefer addTranscription()
            // We don't sync full history to iCloud KVS (too large)
        }
    }

    /// Published wrapper for UI binding (Core Data updates this automatically)
    @Published private var _transcriptionHistoryUpdateTrigger = Date()

    private func saveTranscriptionHistory() {
        // No longer saving to UserDefaults - Core Data handles persistence
        // Keep a small cache for keyboard extension (last 20 records only)
        let recentRecords = Array(transcriptionHistory.prefix(20))
        if let data = try? JSONEncoder().encode(recentRecords) {
            defaults?.set(data, forKey: Constants.Keys.transcriptionHistory)
        }
    }

    private func loadTranscriptionHistory() {
        // Core Data loads automatically via CoreDataManager
        // Just trigger a UI update
        _transcriptionHistoryUpdateTrigger = Date()
    }

    var vocabulary: [VocabularyEntry] {
        get {
            guard let data = defaults?.data(forKey: Constants.Keys.vocabulary),
                  let entries = try? JSONDecoder().decode([VocabularyEntry].self, from: data) else {
                return []
            }
            return entries
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults?.set(data, forKey: Constants.Keys.vocabulary)
            }
            syncToiCloud()
        }
    }

    /// Alias for vocabulary - used by PromptContext
    var vocabularyEntries: [VocabularyEntry] {
        vocabulary
    }

    // MARK: - Private Initialization

    private init() {
        self.keychainManager = KeychainManager.shared
        defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        loadFromDefaults()
        setupiCloudSync()

        // Mark initialization complete - now syncToiCloud() will work
        isInitializing = false

        // Phase 6: Perform data retention cleanup on launch
        performDataRetentionCleanup()
    }

    /// For testing with mock dependencies
    init(keychainManager: SecureStorageProtocol, defaults: UserDefaults?) {
        self.keychainManager = keychainManager
        self.defaults = defaults
        loadFromDefaults()
        // Don't setup iCloud sync in tests
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
            appLog("iCloud KVS disabled, skipping sync setup", category: "iCloud")
            return
        }

        appLog("Setting up iCloud KVS sync...", category: "iCloud")

        // Check if iCloud is available
        let testKey = "icloud_test_\(Date().timeIntervalSince1970)"
        iCloud?.set("test", forKey: testKey)
        let syncResult = iCloud?.synchronize() ?? false
        appLog("iCloud KVS sync test: synchronize() returned \(syncResult)", category: "iCloud")
        iCloud?.removeObject(forKey: testKey)

        // Log current iCloud state
        if let allKeys = iCloud?.dictionaryRepresentation.keys {
            appLog("iCloud KVS current keys: \(Array(allKeys).joined(separator: ", "))", category: "iCloud")
        } else {
            appLog("iCloud KVS: Not available", category: "iCloud")
        }

        // Listen for iCloud changes from other devices (e.g., macOS)
        iCloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloud,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            appLog("iCloud KVS: Received external change notification!", category: "iCloud")

            guard let userInfo = notification.userInfo,
                  let reasonNumber = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? NSNumber else {
                appLog("iCloud KVS: No reason in notification userInfo", category: "iCloud", level: .error)
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
            appLog("iCloud KVS change reason: \(reasonName)", category: "iCloud")

            if let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
                appLog("iCloud KVS changed keys: \(changedKeys.joined(separator: ", "))", category: "iCloud")
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
                appLog("iCloud storage quota exceeded", category: "iCloud", level: .error)
            default:
                break
            }
        }

        // Synchronize to get latest changes
        let initialSync = iCloud?.synchronize()
        appLog("iCloud sync initialized, initial synchronize() returned \(initialSync)", category: "iCloud")

        // Try to load any existing data
        loadFromiCloud()
    }

    private func loadFromiCloud() {
        appLog("loadFromiCloud: Starting to load from iCloud KVS...", category: "iCloud")

        // Load providers WITH API keys from iCloud (cross-platform sync)
        if let data = iCloud?.data(forKey: iCloudKeys.configuredAIProviders) {
            appLog("loadFromiCloud: Found providers data (\(data.count) bytes)", category: "iCloud")
            if let providers = try? JSONDecoder().decode([AIProviderConfig].self, from: data) {
                // Save API keys to local Keychain for offline access
                for config in providers where !config.apiKey.isEmpty {
                    let keychainKey = KeychainKeys.key(for: config.provider)
                    try? keychainManager.save(key: keychainKey, value: config.apiKey)
                }
                configuredAIProviders = providers
                appLog("loadFromiCloud: Loaded \(providers.count) providers: \(providers.map { $0.provider.displayName }.joined(separator: ", "))", category: "iCloud")
            } else {
                appLog("loadFromiCloud: Failed to decode providers data", category: "iCloud", level: .error)
            }
        } else {
            appLog("loadFromiCloud: No providers data in iCloud KVS", category: "iCloud")
        }

        // Load contexts
        if let data = iCloud?.data(forKey: iCloudKeys.contexts),
           let loadedContexts = try? JSONDecoder().decode([ConversationContext].self, from: data) {
            contexts = loadedContexts
            appLog("loadFromiCloud: Loaded \(loadedContexts.count) contexts", category: "iCloud")
        } else {
            appLog("loadFromiCloud: No contexts data in iCloud KVS", category: "iCloud")
        }

        // Load power modes
        if let data = iCloud?.data(forKey: iCloudKeys.powerModes),
           let loadedModes = try? JSONDecoder().decode([PowerMode].self, from: data) {
            powerModes = loadedModes
        }

        // Load quick actions
        if iCloud?.object(forKey: iCloudKeys.quickSuggestionsEnabled) != nil {
            quickSuggestionsEnabled = iCloud?.bool(forKey: iCloudKeys.quickSuggestionsEnabled) ?? true
        }
        if let data = iCloud?.data(forKey: iCloudKeys.quickActions),
           let loadedActions = try? JSONDecoder().decode([QuickAction].self, from: data) {
            quickActions = loadedActions
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

        // NOTE: Provider defaults (selectedTranscriptionProvider, selectedTranslationProvider, etc.)
        // are intentionally NOT synced between iOS and macOS because provider availability
        // differs between platforms (e.g., Ollama/LM Studio only available on macOS)

        if let modeRaw = iCloud?.string(forKey: iCloudKeys.selectedMode),
           let mode = FormattingMode(rawValue: modeRaw) {
            selectedMode = mode
        }

        if let langRaw = iCloud?.string(forKey: iCloudKeys.selectedTargetLanguage),
           let lang = Language(rawValue: langRaw) {
            selectedTargetLanguage = lang
        }

        isTranslationEnabled = iCloud?.bool(forKey: iCloudKeys.isTranslationEnabled) ?? isTranslationEnabled

        // Load global memory settings
        if let memory = iCloud?.string(forKey: iCloudKeys.globalMemory) {
            globalMemory = memory
        }
        globalMemoryEnabled = iCloud?.bool(forKey: iCloudKeys.globalMemoryEnabled) ?? globalMemoryEnabled
        let limit = iCloud?.longLong(forKey: iCloudKeys.globalMemoryLimit) ?? 0
        if limit > 0 {
            globalMemoryLimit = Int(limit)
        }

        // Load keyboard layout settings
        if let showBar = iCloud?.object(forKey: iCloudKeys.keyboardShowSwiftSpeakBar) as? Bool {
            keyboardShowSwiftSpeakBar = showBar
        }
        if let showPrediction = iCloud?.object(forKey: iCloudKeys.keyboardShowPredictionRow) as? Bool {
            keyboardShowPredictionRow = showPrediction
        }
        if let actionRaw = iCloud?.string(forKey: iCloudKeys.keyboardProgrammableAction),
           let action = ProgrammableButtonAction(rawValue: actionRaw) {
            keyboardProgrammableAction = action
        }
        if let showNextToReturn = iCloud?.object(forKey: iCloudKeys.keyboardShowProgrammableNextToReturn) as? Bool {
            keyboardShowProgrammableNextToReturn = showNextToReturn
        }
        if let returnActionRaw = iCloud?.string(forKey: iCloudKeys.keyboardReturnProgrammableAction),
           let returnAction = ProgrammableButtonAction(rawValue: returnActionRaw) {
            keyboardReturnProgrammableAction = returnAction
        }

        // Load streaming settings
        if let streamingEnabled = iCloud?.object(forKey: iCloudKeys.transcriptionStreamingEnabled) as? Bool {
            transcriptionStreamingEnabled = streamingEnabled
        }

        // Load hidden contexts
        if let hiddenStrings = iCloud?.array(forKey: iCloudKeys.hiddenContextIds) as? [String] {
            hiddenContextIds = Set(hiddenStrings.compactMap { UUID(uuidString: $0) })
        }

        // Transcription history is now synced via Core Data + CloudKit (unlimited records)
        // No longer using iCloud KVS for history due to size limits

        // Load history memory
        if let data = iCloud?.data(forKey: iCloudKeys.historyMemory),
           let memory = try? JSONDecoder().decode(HistoryMemory.self, from: data) {
            // Use iCloud version if newer or local is nil
            if historyMemory == nil || memory.lastUpdated > (historyMemory?.lastUpdated ?? .distantPast) {
                historyMemory = memory
                appLog("loadFromiCloud: Loaded history memory from iCloud", category: "iCloud")
            }
        }

        // Load subscription tier
        if let tierRaw = iCloud?.string(forKey: iCloudKeys.subscriptionTier),
           let tier = SubscriptionTier(rawValue: tierRaw) {
            subscriptionTier = tier
            appLog("loadFromiCloud: Loaded subscription tier: \(tier.displayName)", category: "iCloud")
        }
    }

    private func syncToiCloud() {
        guard !isInitializing else {
            // Don't sync during initialization - we're still loading
            return
        }
        guard !isSyncing else {
            appLog("syncToiCloud: Skipped (already syncing)", category: "iCloud")
            return
        }

        appLog("syncToiCloud: Starting sync to iCloud KVS...", category: "iCloud")

        // Sync providers WITH API keys for cross-platform sync (iOS <-> macOS)
        // API keys are also stored in local Keychain for offline access
        if let data = try? JSONEncoder().encode(configuredAIProviders) {
            iCloud?.set(data, forKey: iCloudKeys.configuredAIProviders)
            appLog("syncToiCloud: Synced \(configuredAIProviders.count) providers (\(data.count) bytes)", category: "iCloud")
        }

        // Sync contexts
        if let data = try? JSONEncoder().encode(contexts) {
            iCloud?.set(data, forKey: iCloudKeys.contexts)
        }

        // Sync power modes
        if let data = try? JSONEncoder().encode(powerModes) {
            iCloud?.set(data, forKey: iCloudKeys.powerModes)
        }

        // Sync quick actions
        iCloud?.set(quickSuggestionsEnabled, forKey: iCloudKeys.quickSuggestionsEnabled)
        if let data = try? JSONEncoder().encode(quickActions) {
            iCloud?.set(data, forKey: iCloudKeys.quickActions)
        }

        // Sync vocabulary
        if let data = try? JSONEncoder().encode(vocabulary) {
            iCloud?.set(data, forKey: iCloudKeys.vocabulary)
        }

        // Sync custom templates
        if let data = try? JSONEncoder().encode(customTemplates) {
            iCloud?.set(data, forKey: iCloudKeys.customTemplates)
        }

        // NOTE: Provider defaults (selectedTranscriptionProvider, selectedTranslationProvider, etc.)
        // are intentionally NOT synced between iOS and macOS because provider availability
        // differs between platforms (e.g., Ollama/LM Studio only available on macOS)

        // Sync other primitive values
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

        // Sync keyboard layout settings
        iCloud?.set(keyboardShowSwiftSpeakBar, forKey: iCloudKeys.keyboardShowSwiftSpeakBar)
        iCloud?.set(keyboardShowPredictionRow, forKey: iCloudKeys.keyboardShowPredictionRow)
        iCloud?.set(keyboardProgrammableAction.rawValue, forKey: iCloudKeys.keyboardProgrammableAction)
        iCloud?.set(keyboardShowProgrammableNextToReturn, forKey: iCloudKeys.keyboardShowProgrammableNextToReturn)
        iCloud?.set(keyboardReturnProgrammableAction.rawValue, forKey: iCloudKeys.keyboardReturnProgrammableAction)

        // Sync streaming settings
        iCloud?.set(transcriptionStreamingEnabled, forKey: iCloudKeys.transcriptionStreamingEnabled)

        // Sync hidden contexts
        let hiddenContextStrings = hiddenContextIds.map { $0.uuidString }
        iCloud?.set(hiddenContextStrings, forKey: iCloudKeys.hiddenContextIds)

        // Transcription history is synced via Core Data + CloudKit (unlimited records)
        // No longer using iCloud KVS for history due to size limits

        // Sync history memory
        if let memory = historyMemory, let data = try? JSONEncoder().encode(memory) {
            iCloud?.set(data, forKey: iCloudKeys.historyMemory)
        } else {
            iCloud?.removeObject(forKey: iCloudKeys.historyMemory)
        }

        // Sync subscription tier
        iCloud?.set(subscriptionTier.rawValue, forKey: iCloudKeys.subscriptionTier)

        // Set sync timestamp
        iCloud?.set(Date().timeIntervalSince1970, forKey: iCloudKeys.lastSyncTimestamp)

        // Trigger synchronization
        let syncResult = iCloud?.synchronize()
        appLog("syncToiCloud: synchronize() returned \(syncResult)", category: "iCloud")
    }

    /// Force sync settings to iCloud (call after making changes)
    func forceSyncToiCloud() {
        syncToiCloud()
    }

    /// Get last sync timestamp
    var lastSyncTime: Date? {
        let timestamp = iCloud?.double(forKey: iCloudKeys.lastSyncTimestamp) ?? 0
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }

    /// Refresh settings from UserDefaults (call when app returns to foreground)
    /// This picks up any changes made by the keyboard extension
    func refreshFromDefaults() {
        // Reload dictation language (most likely to be changed by keyboard)
        if let dictLangRaw = defaults?.string(forKey: Constants.Keys.selectedDictationLanguage),
           let dictLang = Language(rawValue: dictLangRaw) {
            if selectedDictationLanguage != dictLang {
                selectedDictationLanguage = dictLang
                appLog("Refreshed dictation language from keyboard: \(dictLang.displayName)", category: "Settings")
            }
        } else if selectedDictationLanguage != nil {
            selectedDictationLanguage = nil
            appLog("Refreshed dictation language to auto-detect", category: "Settings")
        }

        // Reload mode (can be changed by keyboard)
        if let modeRaw = defaults?.string(forKey: Constants.Keys.selectedMode),
           let mode = FormattingMode(rawValue: modeRaw) {
            if selectedMode != mode {
                selectedMode = mode
            }
        }

        // Reload translation settings
        let newTranslationEnabled = defaults?.bool(forKey: Constants.Keys.isTranslationEnabled) ?? false
        if isTranslationEnabled != newTranslationEnabled {
            isTranslationEnabled = newTranslationEnabled
        }

        if let targetLangRaw = defaults?.string(forKey: Constants.Keys.selectedTargetLanguage),
           let targetLang = Language(rawValue: targetLangRaw) {
            if selectedTargetLanguage != targetLang {
                selectedTargetLanguage = targetLang
            }
        }
    }

    private func loadFromDefaults() {
        // Load hasCompletedOnboarding
        hasCompletedOnboarding = defaults?.bool(forKey: Constants.Keys.hasCompletedOnboarding) ?? false

        // Load mode
        if let modeRaw = defaults?.string(forKey: Constants.Keys.selectedMode),
           let mode = FormattingMode(rawValue: modeRaw) {
            selectedMode = mode
        }

        // Load target language
        if let langRaw = defaults?.string(forKey: Constants.Keys.selectedTargetLanguage),
           let lang = Language(rawValue: langRaw) {
            selectedTargetLanguage = lang
        }

        // Load dictation language (nil = auto-detect)
        if let dictLangRaw = defaults?.string(forKey: Constants.Keys.selectedDictationLanguage),
           let dictLang = Language(rawValue: dictLangRaw) {
            selectedDictationLanguage = dictLang
        }

        // Load translation enabled
        isTranslationEnabled = defaults?.bool(forKey: Constants.Keys.isTranslationEnabled) ?? false

        // Load Arabizi output setting (default: false)
        outputArabizi = defaults?.bool(forKey: "outputArabizi") ?? false

        // Load auto-return enabled (default: true)
        if defaults?.object(forKey: Constants.Keys.autoReturnEnabled) != nil {
            autoReturnEnabled = defaults?.bool(forKey: Constants.Keys.autoReturnEnabled) ?? true
        }

        // Load audio quality (default: auto)
        if let qualityRaw = defaults?.string(forKey: "audioQuality"),
           let quality = AudioQualityMode(rawValue: qualityRaw) {
            audioQuality = quality
        }

        // Load subscription tier
        if let tierRaw = defaults?.string(forKey: Constants.Keys.subscriptionTier),
           let tier = SubscriptionTier(rawValue: tierRaw) {
            subscriptionTier = tier
        }

        // Load custom templates
        loadCustomTemplates()

        // Load configured AI providers
        loadConfiguredAIProviders()

        // Load contexts and power modes
        loadContexts()
        loadPowerModes()
        loadQuickActions()
        loadHiddenContextIds()
        loadObsidianVaults()
        loadHistoryMemory()

        // Load transcription history (cached, not computed on every access)
        loadTranscriptionHistory()

        // Load global memory (3-tier system)
        globalMemory = defaults?.string(forKey: Constants.Keys.globalMemory)
        if defaults?.object(forKey: Constants.Keys.globalMemoryEnabled) != nil {
            globalMemoryEnabled = defaults?.bool(forKey: Constants.Keys.globalMemoryEnabled) ?? true
        }
        if defaults?.object(forKey: Constants.Keys.globalMemoryLimit) != nil {
            globalMemoryLimit = defaults?.integer(forKey: Constants.Keys.globalMemoryLimit) ?? 2000
        }

        // Load memory update timestamps
        lastGlobalMemoryUpdate = defaults?.object(forKey: Constants.Keys.lastGlobalMemoryUpdate) as? Date
        loadContextMemoryUpdates()
        loadPowerModeMemoryUpdates()

        // Load streaming settings
        if defaults?.object(forKey: Constants.Keys.powerModeStreamingEnabled) != nil {
            powerModeStreamingEnabled = defaults?.bool(forKey: Constants.Keys.powerModeStreamingEnabled) ?? true
        }
        if defaults?.object(forKey: Constants.Keys.transcriptionStreamingEnabled) != nil {
            transcriptionStreamingEnabled = defaults?.bool(forKey: Constants.Keys.transcriptionStreamingEnabled) ?? false
        }

        // Load user app category overrides
        loadUserAppCategoryOverrides()

        // Load knowledge documents (Phase 4e RAG)
        loadKnowledgeDocuments()

        // Load webhooks (Phase 4f)
        loadWebhooks()

        // Load Phase 10: Local models and provider defaults
        loadWhisperKitConfig()
        loadAppleIntelligenceConfig()
        loadAppleTranslationConfig()
        loadProviderDefaults()
        forcePrivacyMode = defaults?.bool(forKey: Constants.Keys.forcePrivacyMode) ?? false

        // Load Phase 13.8: Swipe typing
        if defaults?.object(forKey: Constants.Keys.swipeTypingEnabled) != nil {
            swipeTypingEnabled = defaults?.bool(forKey: Constants.Keys.swipeTypingEnabled) ?? true
        }

        // Load Phase 16: Keyboard Layout Settings
        if defaults?.object(forKey: Constants.Keys.keyboardShowSwiftSpeakBar) != nil {
            keyboardShowSwiftSpeakBar = defaults?.bool(forKey: Constants.Keys.keyboardShowSwiftSpeakBar) ?? true
        }
        if defaults?.object(forKey: Constants.Keys.keyboardShowPredictionRow) != nil {
            keyboardShowPredictionRow = defaults?.bool(forKey: Constants.Keys.keyboardShowPredictionRow) ?? true
        }
        if let actionRaw = defaults?.string(forKey: Constants.Keys.keyboardProgrammableAction),
           let action = ProgrammableButtonAction(rawValue: actionRaw) {
            keyboardProgrammableAction = action
        }
        if defaults?.object(forKey: Constants.Keys.keyboardShowProgrammableNextToReturn) != nil {
            keyboardShowProgrammableNextToReturn = defaults?.bool(forKey: Constants.Keys.keyboardShowProgrammableNextToReturn) ?? false
        }
        if let returnActionRaw = defaults?.string(forKey: Constants.Keys.keyboardReturnProgrammableAction),
           let returnAction = ProgrammableButtonAction(rawValue: returnActionRaw) {
            keyboardReturnProgrammableAction = returnAction
        }

        // Load Autocomplete Suggestions settings
        keyboardQuickSuggestionsEnabled = defaults?.bool(forKey: "keyboardQuickSuggestionsEnabled") ?? false
        loadKeyboardQuickActions()

        // Load security settings (Phase 6)
        biometricProtectionEnabled = defaults?.bool(forKey: Constants.Keys.biometricProtectionEnabled) ?? false
        if let retentionRaw = defaults?.string(forKey: Constants.Keys.dataRetentionPeriod),
           let retention = DataRetentionPeriod(rawValue: retentionRaw) {
            dataRetentionPeriod = retention
        }

        // Load active context ID (default to Work preset if not set)
        let savedContextIdString = defaults?.string(forKey: Constants.Keys.activeContextId)
        appLog("loadFromDefaults: saved activeContextId string = '\(savedContextIdString ?? "nil")'", category: "Context", level: .debug)
        if let contextIdString = savedContextIdString,
           let contextId = UUID(uuidString: contextIdString) {
            appLog("loadFromDefaults: parsed UUID = \(contextId.uuidString.prefix(8))...", category: "Context", level: .debug)
            activeContextId = contextId
        } else {
            // Default to Work preset context
            appLog("loadFromDefaults: no valid saved context, defaulting to Work", category: "Context", level: .debug)
            activeContextId = ConversationContext.presets.first(where: { $0.name == "Work" })?.id
        }

        // Load selected providers
        if let transcriptionProviderRaw = defaults?.string(forKey: Constants.Keys.selectedTranscriptionProvider),
           let provider = AIProvider(rawValue: transcriptionProviderRaw) {
            selectedTranscriptionProvider = provider
        }

        if let translationProviderRaw = defaults?.string(forKey: Constants.Keys.selectedTranslationProvider),
           let provider = AIProvider(rawValue: translationProviderRaw) {
            selectedTranslationProvider = provider
        }

        if let formattingProviderRaw = defaults?.string(forKey: Constants.Keys.selectedFormattingProvider),
           let provider = AIProvider(rawValue: formattingProviderRaw) {
            selectedFormattingProvider = provider
        }

        if let powerModeProviderRaw = defaults?.string(forKey: Constants.Keys.selectedPowerModeProvider),
           let provider = AIProvider(rawValue: powerModeProviderRaw) {
            selectedPowerModeProvider = provider
        }

        // Phase 11: Load retry settings
        if defaults?.object(forKey: "autoRetryEnabled") != nil {
            autoRetryEnabled = defaults?.bool(forKey: "autoRetryEnabled") ?? true
        }
        maxRetryCount = defaults?.integer(forKey: "maxRetryCount") ?? 3
        if maxRetryCount == 0 { maxRetryCount = 3 } // Handle unset defaults

        if defaults?.object(forKey: "keepFailedRecordings") != nil {
            keepFailedRecordings = defaults?.bool(forKey: "keepFailedRecordings") ?? true
        }
        pendingAudioRetentionDays = defaults?.integer(forKey: "pendingAudioRetentionDays") ?? 7
        if pendingAudioRetentionDays == 0 && defaults?.object(forKey: "pendingAudioRetentionDays") == nil {
            pendingAudioRetentionDays = 7
        }

        // Phase 11: Load token limits
        tokenLimitGlobalMemory = defaults?.integer(forKey: "tokenLimitGlobalMemory") ?? 500
        if tokenLimitGlobalMemory == 0 { tokenLimitGlobalMemory = 500 }

        tokenLimitContextMemory = defaults?.integer(forKey: "tokenLimitContextMemory") ?? 400
        if tokenLimitContextMemory == 0 { tokenLimitContextMemory = 400 }

        tokenLimitRAGChunks = defaults?.integer(forKey: "tokenLimitRAGChunks") ?? 2000
        if tokenLimitRAGChunks == 0 { tokenLimitRAGChunks = 2000 }

        tokenLimitUserInput = defaults?.integer(forKey: "tokenLimitUserInput") ?? 4000
        if tokenLimitUserInput == 0 { tokenLimitUserInput = 4000 }

        // Load pending audio queue
        loadPendingAudioQueue()

        // Clean up expired pending audio on launch
        cleanupExpiredPendingAudio()

        // Load SwiftLink settings
        loadSwiftLinkApps()
        if let durationRaw = defaults?.integer(forKey: Constants.Keys.swiftLinkSessionDuration),
           durationRaw != 0 || defaults?.object(forKey: Constants.Keys.swiftLinkSessionDuration) != nil,
           let duration = Constants.SwiftLinkSessionDuration(rawValue: durationRaw) {
            swiftLinkSessionDuration = duration
        }

        // Load SwiftLink auto-start (defaults to true if not set)
        if defaults?.object(forKey: Constants.Keys.swiftLinkAutoStart) != nil {
            swiftLinkAutoStart = defaults?.bool(forKey: Constants.Keys.swiftLinkAutoStart) ?? true
        } else {
            swiftLinkAutoStart = true  // Default to enabled
        }

        // Load Context Capture setting (defaults to false)
        contextCaptureEnabled = defaults?.bool(forKey: "contextCaptureEnabled") ?? false
    }

    // MARK: - AI Provider Management

    private func loadConfiguredAIProviders() {
        if let data = defaults?.data(forKey: Constants.Keys.configuredAIProviders),
           var providers = try? JSONDecoder().decode([AIProviderConfig].self, from: data) {
            // Phase 6: Hydrate API keys from Keychain
            for i in providers.indices {
                let keychainKey = KeychainKeys.key(for: providers[i].provider)
                if let apiKey = try? keychainManager.retrieve(key: keychainKey), !apiKey.isEmpty {
                    providers[i].apiKey = apiKey
                }
            }
            configuredAIProviders = providers
        } else {
            // No saved providers - check for legacy API key migration
            // If user has a legacy OpenAI key, migrate it to the new system
            var legacyApiKey = ""
            if let keychainKey = try? keychainManager.retrieve(key: KeychainKeys.openAI), !keychainKey.isEmpty {
                legacyApiKey = keychainKey
            } else if let legacyKey = openAIAPIKey, !legacyKey.isEmpty {
                legacyApiKey = legacyKey
            }

            // Only add OpenAI by default if there's an existing API key (migration case)
            // New users start with an empty list and choose their first provider
            if !legacyApiKey.isEmpty {
                let defaultConfig = AIProviderConfig(
                    provider: .openAI,
                    apiKey: legacyApiKey,
                    usageCategories: [.transcription, .translation, .powerMode]
                )
                configuredAIProviders = [defaultConfig]
            } else {
                // New users: start with empty list, let them choose OpenAI or Gemini
                configuredAIProviders = []
            }
        }
    }

    private func saveConfiguredAIProviders() {
        // Phase 6: Save API keys to Keychain, store empty keys in UserDefaults
        for config in configuredAIProviders {
            let keychainKey = KeychainKeys.key(for: config.provider)
            if !config.apiKey.isEmpty {
                try? keychainManager.save(key: keychainKey, value: config.apiKey)
            } else {
                try? keychainManager.delete(key: keychainKey)
            }
        }

        // Save configs without API keys to UserDefaults
        // Use "configured" marker so keyboard can detect configured providers
        var sanitizedConfigs = configuredAIProviders
        for i in sanitizedConfigs.indices {
            sanitizedConfigs[i].apiKey = sanitizedConfigs[i].apiKey.isEmpty ? "" : "configured"
        }
        if let data = try? JSONEncoder().encode(sanitizedConfigs) {
            defaults?.set(data, forKey: Constants.Keys.configuredAIProviders)
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
        if selectedFormattingProvider == provider {
            if let first = formattingProviders.first {
                selectedFormattingProvider = first.provider
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

    /// Formatting providers (for Context AI formatting) - same as powerMode providers
    var formattingProviders: [AIProviderConfig] {
        configuredAIProviders.filter { $0.isConfiguredForPowerMode }
    }

    var powerModeProviders: [AIProviderConfig] {
        configuredAIProviders.filter { $0.isConfiguredForPowerMode }
    }

    /// Get the currently selected transcription provider config
    var selectedTranscriptionProviderConfig: AIProviderConfig? {
        configuredAIProviders.first { $0.provider == selectedTranscriptionProvider }
    }

    /// Get the currently selected translation provider config
    var selectedTranslationProviderConfig: AIProviderConfig? {
        configuredAIProviders.first { $0.provider == selectedTranslationProvider }
    }

    /// Get the currently selected power mode provider config
    var selectedPowerModeProviderConfig: AIProviderConfig? {
        configuredAIProviders.first { $0.provider == selectedPowerModeProvider }
    }

    // MARK: - Custom Templates Management

    private func loadCustomTemplates() {
        if let data = defaults?.data(forKey: Constants.Keys.customTemplates),
           let templates = try? JSONDecoder().decode([CustomTemplate].self, from: data) {
            customTemplates = templates
        }
    }

    private func saveCustomTemplates() {
        if let data = try? JSONEncoder().encode(customTemplates) {
            defaults?.set(data, forKey: Constants.Keys.customTemplates)
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

    func getCustomTemplate(id: UUID) -> CustomTemplate? {
        customTemplates.first { $0.id == id }
    }

    // MARK: - Helper Methods

    func addTranscription(_ record: TranscriptionRecord) {
        // Store in Core Data (syncs to CloudKit automatically, no limit)
        CoreDataManager.shared.addTranscription(record)

        // Also save a small cache to UserDefaults for keyboard extension
        saveTranscriptionHistory()

        // Trigger UI update
        _transcriptionHistoryUpdateTrigger = Date()
    }

    func removeTranscription(id: UUID) {
        // Delete from Core Data (syncs to CloudKit automatically)
        CoreDataManager.shared.deleteTranscription(id: id)

        // Update local cache
        saveTranscriptionHistory()

        // Trigger UI update
        _transcriptionHistoryUpdateTrigger = Date()
    }

    func clearHistory() {
        // Clear from Core Data (and CloudKit)
        CoreDataManager.shared.clearTranscriptionHistory()

        // Clear local cache
        defaults?.removeObject(forKey: Constants.Keys.transcriptionHistory)

        // Trigger UI update
        _transcriptionHistoryUpdateTrigger = Date()
    }

    // MARK: - Phase 6: Data Retention

    /// Automatically delete transcription history older than the configured retention period
    /// Called on app launch
    private func performDataRetentionCleanup() {
        guard let days = dataRetentionPeriod.days else { return }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let originalCount = transcriptionHistory.count

        transcriptionHistory = transcriptionHistory.filter { $0.timestamp > cutoffDate }

        let deletedCount = originalCount - transcriptionHistory.count
        if deletedCount > 0 {
            appLog("Data retention cleanup: deleted \(deletedCount) records older than \(days) days", category: "Data")
        }
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        // Also reset the persisted onboarding page
        UserDefaults.standard.removeObject(forKey: "onboardingCurrentPage")
    }

    /// Reset all settings to defaults (for debugging)
    func resetAllSettings() {
        // Clear all API keys from keychain
        for provider in AIProvider.allCases where !provider.isLocalProvider {
            let key = KeychainKeys.key(for: provider)
            try? keychainManager.delete(key: key)
        }

        // Reset all published properties to defaults
        hasCompletedOnboarding = false
        configuredAIProviders = []
        selectedMode = .raw
        selectedTargetLanguage = .spanish
        isTranslationEnabled = false
        autoReturnEnabled = true
        audioQuality = .auto
        transcriptionHistory = []
        vocabulary = []
        customTemplates = []
        webhooks = []
        contexts = []
        activeContextId = nil
        powerModes = []
        globalMemory = nil
        globalMemoryEnabled = true
        biometricProtectionEnabled = false
        dataRetentionPeriod = .never
        whisperKitConfig = .default
        appleIntelligenceConfig = .default
        appleTranslationConfig = .default
        forcePrivacyMode = false
        knowledgeDocuments = []
        pendingAudioQueue = []
        userAppCategoryOverrides = []

        // Clear UserDefaults
        if let bundleId = Bundle.main.bundleIdentifier {
            defaults?.removePersistentDomain(forName: bundleId)
        }

        // Clear shared App Group defaults
        if let sharedDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier) {
            sharedDefaults.removePersistentDomain(forName: Constants.appGroupIdentifier)
        }

        appLog("All settings have been reset", category: "Data")
    }

    func hasValidAPIKey(for provider: AIProvider) -> Bool {
        guard let config = getAIProviderConfig(for: provider) else { return false }
        if provider.isLocalProvider {
            return config.isLocalProviderConfigured
        }
        return config.apiKey.isEmpty == false
    }

    // MARK: - Vocabulary Management

    func addVocabularyEntry(_ entry: VocabularyEntry) {
        var entries = vocabulary
        // Check for duplicate recognized word
        if entries.contains(where: { $0.recognizedWord.lowercased() == entry.recognizedWord.lowercased() }) {
            return
        }
        entries.append(entry)
        vocabulary = entries
    }

    func updateVocabularyEntry(_ entry: VocabularyEntry) {
        var entries = vocabulary
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            vocabulary = entries
        }
    }

    func removeVocabularyEntry(_ entry: VocabularyEntry) {
        var entries = vocabulary
        entries.removeAll { $0.id == entry.id }
        vocabulary = entries
    }

    func toggleVocabularyEntry(_ entry: VocabularyEntry) {
        var updatedEntry = entry
        updatedEntry.isEnabled.toggle()
        updatedEntry.updatedAt = Date()
        updateVocabularyEntry(updatedEntry)
    }

    /// Apply vocabulary replacements to text
    func applyVocabulary(to text: String) -> String {
        var result = text
        for entry in vocabulary where entry.isEnabled {
            // Case-insensitive replacement
            result = result.replacingOccurrences(
                of: entry.recognizedWord,
                with: entry.replacementWord,
                options: .caseInsensitive
            )
        }
        return result
    }

    // MARK: - Context Management

    private func loadContexts() {
        if let data = defaults?.data(forKey: Constants.Keys.contexts),
           let loadedContexts = try? JSONDecoder().decode([ConversationContext].self, from: data),
           !loadedContexts.isEmpty {
            contexts = loadedContexts
        } else {
            // Initialize with preset contexts if none saved
            contexts = ConversationContext.presets
        }
    }

    private func saveContexts() {
        if let data = try? JSONEncoder().encode(contexts) {
            defaults?.set(data, forKey: Constants.Keys.contexts)
        }
        syncToiCloud()
    }

    /// Sync prediction settings for the keyboard extension via App Groups
    /// Called when active context changes
    private func syncPredictionSettingsToAppGroups(context: ConversationContext?) {
        guard let defaults = defaults else { return }

        if let context = context {
            // Sync word autocomplete source
            defaults.set(context.wordAutocompleteSettings.source.rawValue, forKey: Constants.Keys.activeContextWordAutocompleteSource)

            // Sync sentence predictions enabled
            defaults.set(context.sentencePredictionSettings.enabled, forKey: Constants.Keys.activeContextSentencePredictionsEnabled)

            // Sync Quick Actions (nil = use global)
            if let quickActions = context.sentencePredictionSettings.quickActions,
               let data = try? JSONEncoder().encode(quickActions) {
                defaults.set(data, forKey: Constants.Keys.activeContextQuickActions)
            } else {
                defaults.removeObject(forKey: Constants.Keys.activeContextQuickActions)
            }

            appLog("syncPredictionSettingsToAppGroups: source=\(context.wordAutocompleteSettings.source.rawValue), sentencePredictions=\(context.sentencePredictionSettings.enabled)", category: "Context", level: .debug)
        } else {
            // Clear context-specific settings (keyboard will use defaults)
            defaults.set(WordAutocompleteSource.system.rawValue, forKey: Constants.Keys.activeContextWordAutocompleteSource)
            defaults.set(true, forKey: Constants.Keys.activeContextSentencePredictionsEnabled)
            defaults.removeObject(forKey: Constants.Keys.activeContextQuickActions)
            appLog("syncPredictionSettingsToAppGroups: cleared (using defaults)", category: "Context", level: .debug)
        }
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
        // Check user-created contexts first, then presets
        contexts.first { $0.id == id } ?? ConversationContext.presets.first { $0.id == id }
    }

    var activeContext: ConversationContext? {
        guard let id = activeContextId else {
            return nil
        }
        // Check user-created contexts first, then presets
        if let found = contexts.first(where: { $0.id == id }) {
            return found
        }
        if let found = ConversationContext.presets.first(where: { $0.id == id }) {
            return found
        }
        appLog("activeContext: id \(id.uuidString.prefix(8))... not found anywhere, returning nil", category: "Context", level: .error)
        return nil
    }

    func setActiveContext(_ context: ConversationContext?) {
        if let context = context {
            appLog("setActiveContext: setting to '\(context.name)' (id: \(context.id.uuidString.prefix(8))...)", category: "Context", level: .debug)
            activeContextId = context.id
            // Update isActive flags
            for i in contexts.indices {
                contexts[i].isActive = (contexts[i].id == context.id)
            }
        } else {
            appLog("setActiveContext: setting to nil", category: "Context", level: .debug)
            activeContextId = nil
            for i in contexts.indices {
                contexts[i].isActive = false
            }
        }
    }

    /// Refreshes the activeContextId from UserDefaults.
    /// Call this before SwiftLink dictation to pick up changes made by the keyboard extension.
    func refreshActiveContextFromDefaults() {
        let savedContextIdString = defaults?.string(forKey: Constants.Keys.activeContextId)
        let previousId = activeContextId

        if let contextIdString = savedContextIdString,
           let contextId = UUID(uuidString: contextIdString) {
            if contextId != previousId {
                activeContextId = contextId
                appLog("refreshActiveContextFromDefaults: context changed from \(previousId?.uuidString.prefix(8) ?? "nil") to \(contextId.uuidString.prefix(8))", category: "Context", level: .debug)
            }
        } else if previousId != nil {
            activeContextId = nil
            appLog("refreshActiveContextFromDefaults: context cleared (was \(previousId?.uuidString.prefix(8) ?? "nil"))", category: "Context", level: .debug)
        }
    }

    /// Refreshes all shared settings from UserDefaults.
    /// Call this when the app becomes active (foregrounded) to pick up changes made by keyboard.
    func refreshSharedSettingsFromDefaults() {
        appLog("Refreshing shared settings from UserDefaults...", category: "Settings", level: .debug)

        // Refresh context
        refreshActiveContextFromDefaults()

        // Refresh formatting mode
        if let modeRaw = defaults?.string(forKey: Constants.Keys.selectedMode),
           let mode = FormattingMode(rawValue: modeRaw) {
            if selectedMode != mode {
                appLog("Refreshed selectedMode: \(mode.rawValue)", category: "Settings")
                selectedMode = mode
            }
        }

        // Refresh translation settings
        if let translationEnabled = defaults?.object(forKey: Constants.Keys.isTranslationEnabled) as? Bool {
            if isTranslationEnabled != translationEnabled {
                appLog("Refreshed isTranslationEnabled: \(translationEnabled)", category: "Settings")
                isTranslationEnabled = translationEnabled
            }
        }

        // Refresh target language
        if let langRaw = defaults?.string(forKey: Constants.Keys.selectedTargetLanguage),
           let lang = Language(rawValue: langRaw) {
            if selectedTargetLanguage != lang {
                appLog("Refreshed selectedTargetLanguage: \(lang.rawValue)", category: "Settings")
                selectedTargetLanguage = lang
            }
        }

        // Refresh dictation language
        if let langRaw = defaults?.string(forKey: Constants.Keys.selectedDictationLanguage),
           let lang = Language(rawValue: langRaw) {
            if selectedDictationLanguage != lang {
                appLog("Refreshed selectedDictationLanguage: \(lang.rawValue)", category: "Settings")
                selectedDictationLanguage = lang
            }
        }
    }

    // MARK: - Power Mode Management

    private func loadPowerModes() {
        if let data = defaults?.data(forKey: Constants.Keys.powerModes),
           let loadedModes = try? JSONDecoder().decode([PowerMode].self, from: data) {
            powerModes = loadedModes
        } else {
            // Default to presets if no saved modes
            powerModes = PowerMode.presets
        }
    }

    private func savePowerModes() {
        if let data = try? JSONEncoder().encode(powerModes) {
            defaults?.set(data, forKey: Constants.Keys.powerModes)
        }
        syncToiCloud()
    }

    // MARK: - Quick Actions Methods

    private func saveQuickActions() {
        if let data = try? JSONEncoder().encode(quickActions) {
            defaults?.set(data, forKey: "quickActions")
        }
        syncToiCloud()
    }

    private func loadQuickActions() {
        // Load enabled state
        if defaults?.object(forKey: "quickSuggestionsEnabled") != nil {
            quickSuggestionsEnabled = defaults?.bool(forKey: "quickSuggestionsEnabled") ?? true
        }

        // Load quick actions
        guard let data = defaults?.data(forKey: "quickActions"),
              let actions = try? JSONDecoder().decode([QuickAction].self, from: data) else {
            return
        }
        quickActions = actions
    }

    /// Get enabled quick actions sorted by order
    var configuredQuickActions: [QuickAction] {
        quickActions.filter { $0.isEnabled }.sorted { $0.order < $1.order }
    }

    /// Refresh Quick Actions from iCloud (call before predictions to ensure latest data)
    func refreshQuickActionsFromiCloud() {
        guard let iCloud = iCloud else { return }
        _ = iCloud.synchronize()  // Force pull latest from iCloud

        if let data = iCloud.data(forKey: iCloudKeys.quickActions),
           let loadedActions = try? JSONDecoder().decode([QuickAction].self, from: data) {
            if loadedActions != quickActions {
                quickActions = loadedActions
                appLog("refreshQuickActionsFromiCloud: Updated \(loadedActions.count) quick actions from iCloud", category: "iCloud")
            }
        }

        if iCloud.object(forKey: iCloudKeys.quickSuggestionsEnabled) != nil {
            let newValue = iCloud.bool(forKey: iCloudKeys.quickSuggestionsEnabled)
            if newValue != quickSuggestionsEnabled {
                quickSuggestionsEnabled = newValue
            }
        }
    }

    // MARK: - Obsidian Vaults Methods

    private func saveObsidianVaults() {
        if let data = try? JSONEncoder().encode(obsidianVaults) {
            defaults?.set(data, forKey: "obsidianVaults")
        }
        syncToiCloud()
    }

    private func loadObsidianVaults() {
        if let data = defaults?.data(forKey: "obsidianVaults"),
           let vaults = try? JSONDecoder().decode([ObsidianVault].self, from: data) {
            self.obsidianVaults = vaults
        }
    }

    func addObsidianVault(_ vault: ObsidianVault) {
        obsidianVaults.append(vault)
    }

    func updateObsidianVault(_ vault: ObsidianVault) {
        if let index = obsidianVaults.firstIndex(where: { $0.id == vault.id }) {
            obsidianVaults[index] = vault
        }
    }

    func deleteObsidianVault(id: UUID) {
        obsidianVaults.removeAll { $0.id == id }
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

    func archivePowerMode(id: UUID) {
        if let index = powerModes.firstIndex(where: { $0.id == id }) {
            powerModes[index].isArchived = true
            powerModes[index].updatedAt = Date()
        }
    }

    func unarchivePowerMode(id: UUID) {
        if let index = powerModes.firstIndex(where: { $0.id == id }) {
            powerModes[index].isArchived = false
            powerModes[index].updatedAt = Date()
        }
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

    func incrementPowerModeUsage(id: UUID) {
        if let index = powerModes.firstIndex(where: { $0.id == id }) {
            // Create a copy, modify it, and reassign to ensure didSet triggers
            var updatedMode = powerModes[index]
            updatedMode.usageCount += 1
            updatedMode.updatedAt = Date()
            powerModes[index] = updatedMode
            appLog("Power Mode '\(updatedMode.name)' usage incremented to \(updatedMode.usageCount)", category: "PowerMode")
        }
    }

    // MARK: - History Memory Management

    private func loadHistoryMemory() {
        if let data = defaults?.data(forKey: Constants.Keys.historyMemory),
           let memory = try? JSONDecoder().decode(HistoryMemory.self, from: data) {
            historyMemory = memory
        }
    }

    private func saveHistoryMemory() {
        if let data = try? JSONEncoder().encode(historyMemory) {
            defaults?.set(data, forKey: Constants.Keys.historyMemory)
        }
    }

    func updateHistoryMemory(summary: String, topic: String? = nil) {
        var memory = historyMemory ?? HistoryMemory(
            summary: "",
            lastUpdated: Date(),
            conversationCount: 0,
            recentTopics: []
        )

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

    // MARK: - Power Mode Memory Management

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

    // MARK: - Context Memory Management

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

    // MARK: - Filtered History by PowerMode/Context

    func transcriptionHistory(forPowerModeId id: UUID) -> [TranscriptionRecord] {
        transcriptionHistory.filter { $0.powerModeId == id }
    }

    func transcriptionHistory(forContextId id: UUID) -> [TranscriptionRecord] {
        transcriptionHistory.filter { $0.contextId == id }
    }

    func usageCount(forPowerModeId id: UUID) -> Int {
        transcriptionHistory(forPowerModeId: id).count
    }

    func usageCount(forContextId id: UUID) -> Int {
        transcriptionHistory(forContextId: id).count
    }

    // MARK: - App Category Override Management

    private func loadUserAppCategoryOverrides() {
        if let data = defaults?.data(forKey: Constants.Keys.userAppCategoryOverrides),
           let overrides = try? JSONDecoder().decode([UserAppCategoryOverride].self, from: data) {
            userAppCategoryOverrides = overrides
        }
    }

    private func saveUserAppCategoryOverrides() {
        if let data = try? JSONEncoder().encode(userAppCategoryOverrides) {
            defaults?.set(data, forKey: Constants.Keys.userAppCategoryOverrides)
        }
    }

    /// Get the effective category for an app (user override or default)
    func effectiveCategory(for bundleId: String) -> AppCategory? {
        // Check for user override first
        if let override = userAppCategoryOverrides.first(where: { $0.bundleId == bundleId }) {
            return override.category
        }
        // Fall back to default category from AppLibrary
        return AppLibrary.find(bundleId: bundleId)?.defaultCategory
    }

    /// Set a category override for an app
    func setAppCategoryOverride(bundleId: String, category: AppCategory) {
        // Remove existing override if any
        userAppCategoryOverrides.removeAll { $0.bundleId == bundleId }
        // Add new override
        let override = UserAppCategoryOverride(bundleId: bundleId, category: category, updatedAt: Date())
        userAppCategoryOverrides.append(override)
    }

    /// Remove a category override (revert to default)
    func removeAppCategoryOverride(bundleId: String) {
        userAppCategoryOverrides.removeAll { $0.bundleId == bundleId }
    }

    /// Check if an app has a user category override
    func hasAppCategoryOverride(bundleId: String) -> Bool {
        userAppCategoryOverrides.contains { $0.bundleId == bundleId }
    }

    /// Get all apps in a category (including user overrides)
    func apps(in category: AppCategory) -> [AppInfo] {
        // Get all apps from library
        let allApps = AppLibrary.apps
        return allApps.filter { app in
            effectiveCategory(for: app.id) == category
        }
    }

    // MARK: - Context/PowerMode Auto-Enable Matching

    /// Find the context that should be auto-enabled for a given bundle ID
    /// Priority: 1) Specific app ID assignment, 2) Category assignment
    func contextForApp(bundleId: String) -> ConversationContext? {
        // First pass: check for specific app ID assignment (highest priority)
        for context in contexts {
            if context.appAssignment.assignedAppIds.contains(bundleId) {
                return context
            }
        }

        // Second pass: check for category assignment
        let appCategory = effectiveCategory(for: bundleId)
        for context in contexts {
            if let category = appCategory, context.appAssignment.assignedCategories.contains(category) {
                return context
            }
        }

        return nil
    }

    /// Find the power mode that should be auto-enabled for a given bundle ID
    /// Priority: 1) Specific app ID assignment, 2) Category assignment
    func powerModeForApp(bundleId: String) -> PowerMode? {
        // First pass: check for specific app ID assignment (highest priority)
        for powerMode in activePowerModes {
            if powerMode.appAssignment.assignedAppIds.contains(bundleId) {
                return powerMode
            }
        }

        // Second pass: check for category assignment
        let appCategory = effectiveCategory(for: bundleId)
        for powerMode in activePowerModes {
            if let category = appCategory, powerMode.appAssignment.assignedCategories.contains(category) {
                return powerMode
            }
        }

        return nil
    }

    // MARK: - Effective Resolution with Manual Precedence

    /// Resolves the effective context for an app, considering manual selection precedence.
    /// Manual selection (activeContextId) always takes precedence over app auto-enable.
    /// - Parameter bundleId: The bundle ID of the app
    /// - Returns: The manually selected context if set, otherwise the auto-enabled context for the app
    func effectiveContextForApp(bundleId: String) -> ConversationContext? {
        // Manual selection takes precedence
        if let manualContext = activeContext {
            return manualContext
        }
        // Fall back to app auto-enable
        return contextForApp(bundleId: bundleId)
    }

    /// Resolves the effective power mode for an app, considering manual selection precedence.
    /// Manual selection always takes precedence over app auto-enable.
    /// - Parameter bundleId: The bundle ID of the app
    /// - Parameter selectedPowerModeId: The manually selected power mode ID (if any)
    /// - Returns: The manually selected power mode if set, otherwise the auto-enabled power mode for the app
    func effectivePowerModeForApp(bundleId: String, selectedPowerModeId: UUID?) -> PowerMode? {
        // Manual selection takes precedence
        if let selectedId = selectedPowerModeId,
           let manualMode = activePowerModes.first(where: { $0.id == selectedId }) {
            return manualMode
        }
        // Fall back to app auto-enable
        return powerModeForApp(bundleId: bundleId)
    }

    /// Clears the manually selected context, allowing app auto-enable to take effect
    func clearManualContextSelection() {
        activeContextId = nil
    }

    // MARK: - Knowledge Document Management (Phase 4e RAG)

    private func loadKnowledgeDocuments() {
        if let data = defaults?.data(forKey: Constants.Keys.knowledgeDocuments),
           let docs = try? JSONDecoder().decode([KnowledgeDocument].self, from: data) {
            knowledgeDocuments = docs
        }
    }

    private func saveKnowledgeDocuments() {
        if let data = try? JSONEncoder().encode(knowledgeDocuments) {
            defaults?.set(data, forKey: Constants.Keys.knowledgeDocuments)
        }
    }

    /// Add a new knowledge document
    func addKnowledgeDocument(_ document: KnowledgeDocument) {
        knowledgeDocuments.append(document)
    }

    /// Remove a knowledge document by ID
    func removeKnowledgeDocument(_ id: UUID) {
        knowledgeDocuments.removeAll { $0.id == id }
    }

    /// Update an existing knowledge document
    func updateKnowledgeDocument(_ document: KnowledgeDocument) {
        if let index = knowledgeDocuments.firstIndex(where: { $0.id == document.id }) {
            knowledgeDocuments[index] = document
        }
    }

    /// Get a knowledge document by ID
    func getKnowledgeDocument(id: UUID) -> KnowledgeDocument? {
        knowledgeDocuments.first { $0.id == id }
    }

    // MARK: - Webhook Management (Phase 4f)

    private func loadWebhooks() {
        if let data = defaults?.data(forKey: Constants.Keys.webhooks),
           let loaded = try? JSONDecoder().decode([Webhook].self, from: data) {
            webhooks = loaded
        }
    }

    private func saveWebhooks() {
        if let data = try? JSONEncoder().encode(webhooks) {
            defaults?.set(data, forKey: Constants.Keys.webhooks)
        }
    }

    /// Add a new webhook
    func addWebhook(_ webhook: Webhook) {
        webhooks.append(webhook)
    }

    /// Update an existing webhook
    func updateWebhook(_ webhook: Webhook) {
        if let index = webhooks.firstIndex(where: { $0.id == webhook.id }) {
            var updated = webhook
            updated.updatedAt = Date()
            webhooks[index] = updated
        }
    }

    /// Delete a webhook by ID
    func deleteWebhook(_ id: UUID) {
        webhooks.removeAll { $0.id == id }
        // Also remove from all Power Modes
        for i in powerModes.indices {
            powerModes[i].enabledWebhookIds.removeAll { $0 == id }
        }
    }

    /// Get a webhook by ID
    func getWebhook(id: UUID) -> Webhook? {
        webhooks.first { $0.id == id }
    }

    /// Get webhooks by type
    func webhooks(ofType type: WebhookType) -> [Webhook] {
        webhooks.filter { $0.type == type }
    }

    /// Get enabled webhooks for a Power Mode
    func enabledWebhooks(for powerMode: PowerMode) -> [Webhook] {
        webhooks.filter { powerMode.enabledWebhookIds.contains($0.id) && $0.isEnabled }
    }

    /// Get enabled webhooks of a specific type for a Power Mode
    func enabledWebhooks(for powerMode: PowerMode, ofType type: WebhookType) -> [Webhook] {
        enabledWebhooks(for: powerMode).filter { $0.type == type }
    }

    /// Update webhook status after execution
    func updateWebhookStatus(id: UUID, status: String) {
        if let index = webhooks.firstIndex(where: { $0.id == id }) {
            webhooks[index].lastTriggered = Date()
            webhooks[index].lastStatus = status
        }
    }

    // MARK: - Phase 10: WhisperKit Configuration

    private func loadWhisperKitConfig() {
        if let data = defaults?.data(forKey: Constants.Keys.whisperKitConfig),
           let config = try? JSONDecoder().decode(WhisperKitSettings.self, from: data) {
            whisperKitConfig = config
        }
    }

    private func saveWhisperKitConfig() {
        if let data = try? JSONEncoder().encode(whisperKitConfig) {
            defaults?.set(data, forKey: Constants.Keys.whisperKitConfig)
        }
    }

    // MARK: - Phase 10: Apple Intelligence Configuration

    private func loadAppleIntelligenceConfig() {
        if let data = defaults?.data(forKey: Constants.Keys.appleIntelligenceConfig),
           let config = try? JSONDecoder().decode(AppleIntelligenceConfig.self, from: data) {
            appleIntelligenceConfig = config
        }
    }

    private func saveAppleIntelligenceConfig() {
        if let data = try? JSONEncoder().encode(appleIntelligenceConfig) {
            defaults?.set(data, forKey: Constants.Keys.appleIntelligenceConfig)
        }
    }

    // MARK: - Phase 10: Apple Translation Configuration

    private func loadAppleTranslationConfig() {
        if let data = defaults?.data(forKey: Constants.Keys.appleTranslationConfig),
           let config = try? JSONDecoder().decode(AppleTranslationConfig.self, from: data) {
            appleTranslationConfig = config
        }
    }

    private func saveAppleTranslationConfig() {
        if let data = try? JSONEncoder().encode(appleTranslationConfig) {
            defaults?.set(data, forKey: Constants.Keys.appleTranslationConfig)
        }
    }

    // MARK: - Phase 10: Provider Defaults Configuration

    private func loadProviderDefaults() {
        if let data = defaults?.data(forKey: Constants.Keys.providerDefaults),
           let config = try? JSONDecoder().decode(ProviderDefaults.self, from: data) {
            providerDefaults = config
        }
    }

    private func saveProviderDefaults() {
        if let data = try? JSONEncoder().encode(providerDefaults) {
            defaults?.set(data, forKey: Constants.Keys.providerDefaults)
        }
    }

    // MARK: - Phase 11: Pending Audio Queue Persistence

    private func savePendingAudioQueue() {
        if let data = try? JSONEncoder().encode(pendingAudioQueue) {
            defaults?.set(data, forKey: "pendingAudioQueue")
        }
    }

    private func loadPendingAudioQueue() {
        guard let data = defaults?.data(forKey: "pendingAudioQueue"),
              let queue = try? JSONDecoder().decode([PendingAudio].self, from: data) else {
            return
        }
        pendingAudioQueue = queue
    }

    /// Add audio to pending queue
    func addToPendingQueue(_ audio: PendingAudio) {
        var queue = pendingAudioQueue
        queue.append(audio)
        pendingAudioQueue = queue
    }

    /// Remove audio from pending queue
    func removeFromPendingQueue(_ id: UUID) {
        pendingAudioQueue.removeAll { $0.id == id }
    }

    /// Update status of pending audio
    func updatePendingAudioStatus(_ id: UUID, status: PendingAudioStatus, error: String? = nil) {
        if let index = pendingAudioQueue.firstIndex(where: { $0.id == id }) {
            var audio = pendingAudioQueue[index]
            audio.status = status
            audio.lastError = error
            audio.lastAttemptAt = Date()
            audio.retryCount += 1
            pendingAudioQueue[index] = audio
        }
    }

    /// Clean up old pending audio files based on retention settings
    func cleanupExpiredPendingAudio() {
        guard pendingAudioRetentionDays > 0 else { return }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -pendingAudioRetentionDays, to: Date()) ?? Date()
        let expiredIds = pendingAudioQueue.filter { $0.createdAt < cutoffDate }.map { $0.id }

        for id in expiredIds {
            if let audio = pendingAudioQueue.first(where: { $0.id == id }) {
                // Delete the audio file
                try? FileManager.default.removeItem(at: audio.audioFileURL)
            }
            removeFromPendingQueue(id)
        }
    }

    // MARK: - Phase 10: Local Model Helpers

    /// Whether WhisperKit is ready to use
    var isWhisperKitReady: Bool {
        whisperKitConfig.status == .ready && whisperKitConfig.isEnabled
    }

    /// Parakeet MLX is not available on iOS (macOS only)
    var parakeetMLXConfig: ParakeetMLXSettings {
        get { .notAvailable }
        set { /* No-op on iOS */ }
    }

    /// Parakeet MLX is never ready on iOS
    var isParakeetMLXReady: Bool { false }

    /// Whether Apple Intelligence is ready to use
    var isAppleIntelligenceReady: Bool {
        appleIntelligenceConfig.isAvailable && appleIntelligenceConfig.isEnabled
    }

    /// Whether any local transcription provider is available
    var hasLocalTranscription: Bool {
        isWhisperKitReady
    }

    /// Whether any local formatting provider is available
    var hasLocalFormatting: Bool {
        isAppleIntelligenceReady || (getAIProviderConfig(for: .local)?.isLocalProviderConfigured ?? false)
    }

    /// Whether any local translation provider is available
    var hasLocalTranslation: Bool {
        appleTranslationConfig.isAvailable && !appleTranslationConfig.downloadedLanguages.isEmpty
    }

    /// Whether privacy mode can be enabled (requires local providers)
    var canEnablePrivacyMode: Bool {
        hasLocalTranscription && (hasLocalFormatting || hasLocalTranslation)
    }

    /// Get the list of configured local model types
    var configuredLocalModels: [LocalModelType] {
        var models: [LocalModelType] = []

        if whisperKitConfig.status == .ready {
            models.append(.whisperKit)
        }
        if appleIntelligenceConfig.isAvailable && appleIntelligenceConfig.isEnabled {
            models.append(.appleIntelligence)
        }
        if appleTranslationConfig.isAvailable && !appleTranslationConfig.downloadedLanguages.isEmpty {
            models.append(.appleTranslation)
        }
        if getAIProviderConfig(for: .local)?.isLocalProviderConfigured ?? false {
            if let localConfig = localProviderConfig {
                switch localConfig.type {
                case .ollama: models.append(.ollama)
                case .lmStudio: models.append(.lmStudio)
                case .openAICompatible: models.append(.ollama) // Group as Ollama
                }
            }
        }

        return models
    }

    /// Current device's local provider availability for context compatibility checking
    /// This is used to determine if a context's provider overrides are available on this device
    var localProviderAvailability: ConversationContext.LocalProviderAvailability {
        ConversationContext.LocalProviderAvailability(
            whisperKitAvailable: whisperKitConfig.status == .ready,
            appleIntelligenceAvailable: appleIntelligenceConfig.isAvailable,
            appleIntelligenceReason: appleIntelligenceConfig.unavailableReason,
            appleTranslationAvailable: appleTranslationConfig.isAvailable,
            ollamaAvailable: false,   // iOS doesn't support Ollama
            lmStudioAvailable: false  // iOS doesn't support LM Studio
        )
    }

    /// Calculate total storage used by local models in bytes
    var localModelStorageBytes: Int {
        var total = 0

        // WhisperKit model size
        if whisperKitConfig.status == .ready {
            total += whisperKitConfig.selectedModel.sizeBytes
        }

        // Apple Translation languages
        for lang in appleTranslationConfig.downloadedLanguages where !lang.isSystem {
            total += lang.sizeBytes
        }

        return total
    }

    var localModelStorageFormatted: String {
        let bytes = Double(localModelStorageBytes)
        if bytes < 1024 * 1024 {
            return String(format: "%.0f KB", bytes / 1024)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        } else {
            return String(format: "%.1f GB", bytes / (1024 * 1024 * 1024))
        }
    }

    // MARK: - SwiftLink App Management

    private func loadSwiftLinkApps() {
        if let data = defaults?.data(forKey: Constants.Keys.swiftLinkApps),
           let apps = try? JSONDecoder().decode([SwiftLinkApp].self, from: data) {
            swiftLinkApps = apps
        }
    }

    private func saveSwiftLinkApps() {
        if let data = try? JSONEncoder().encode(swiftLinkApps) {
            defaults?.set(data, forKey: Constants.Keys.swiftLinkApps)
        }
    }

    /// Add an app to SwiftLink
    func addSwiftLinkApp(_ app: SwiftLinkApp) {
        guard !swiftLinkApps.contains(where: { $0.bundleId == app.bundleId }) else { return }
        swiftLinkApps.append(app)
    }

    /// Add an app to SwiftLink from AppInfo
    func addSwiftLinkApp(from appInfo: AppInfo) {
        let app = SwiftLinkApp(from: appInfo)
        addSwiftLinkApp(app)
    }

    /// Remove an app from SwiftLink
    func removeSwiftLinkApp(bundleId: String) {
        swiftLinkApps.removeAll { $0.bundleId == bundleId }
    }

    /// Check if an app is configured for SwiftLink
    func isSwiftLinkApp(bundleId: String) -> Bool {
        swiftLinkApps.contains { $0.bundleId == bundleId }
    }

    /// Get SwiftLink app by bundle ID
    func getSwiftLinkApp(bundleId: String) -> SwiftLinkApp? {
        swiftLinkApps.first { $0.bundleId == bundleId }
    }

    /// Get last used SwiftLink app
    var lastUsedSwiftLinkApp: SwiftLinkApp? {
        guard let data = defaults?.data(forKey: Constants.Keys.swiftLinkLastUsedApp),
              let app = try? JSONDecoder().decode(SwiftLinkApp.self, from: data)
        else { return nil }
        return app
    }

    /// Save last used SwiftLink app
    func setLastUsedSwiftLinkApp(_ app: SwiftLinkApp) {
        if let data = try? JSONEncoder().encode(app) {
            defaults?.set(data, forKey: Constants.Keys.swiftLinkLastUsedApp)
        }
    }

    // MARK: - Memory Update Tracking (batch updates)

    private func loadContextMemoryUpdates() {
        guard let data = defaults?.data(forKey: Constants.Keys.lastContextMemoryUpdates),
              let dict = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return
        }
        // Convert String keys back to UUIDs
        lastContextMemoryUpdates = dict.reduce(into: [:]) { result, pair in
            if let uuid = UUID(uuidString: pair.key) {
                result[uuid] = pair.value
            }
        }
    }

    private func saveContextMemoryUpdates() {
        // Convert UUID keys to Strings for JSON encoding
        let stringDict = lastContextMemoryUpdates.reduce(into: [String: Date]()) { result, pair in
            result[pair.key.uuidString] = pair.value
        }
        if let data = try? JSONEncoder().encode(stringDict) {
            defaults?.set(data, forKey: Constants.Keys.lastContextMemoryUpdates)
        }
    }

    private func loadPowerModeMemoryUpdates() {
        guard let data = defaults?.data(forKey: Constants.Keys.lastPowerModeMemoryUpdates),
              let dict = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return
        }
        // Convert String keys back to UUIDs
        lastPowerModeMemoryUpdates = dict.reduce(into: [:]) { result, pair in
            if let uuid = UUID(uuidString: pair.key) {
                result[uuid] = pair.value
            }
        }
    }

    private func savePowerModeMemoryUpdates() {
        // Convert UUID keys to Strings for JSON encoding
        let stringDict = lastPowerModeMemoryUpdates.reduce(into: [String: Date]()) { result, pair in
            result[pair.key.uuidString] = pair.value
        }
        if let data = try? JSONEncoder().encode(stringDict) {
            defaults?.set(data, forKey: Constants.Keys.lastPowerModeMemoryUpdates)
        }
    }

    /// Record that global memory was updated
    func recordGlobalMemoryUpdate() {
        lastGlobalMemoryUpdate = Date()
    }

    /// Record that a context's memory was updated
    func recordContextMemoryUpdate(contextId: UUID) {
        lastContextMemoryUpdates[contextId] = Date()
    }

    /// Record that a power mode's memory was updated
    func recordPowerModeMemoryUpdate(powerModeId: UUID) {
        lastPowerModeMemoryUpdates[powerModeId] = Date()
    }

    /// Mark transcription records as used for a specific memory tier
    /// This updates the history records to prevent re-processing
    func markRecordsAsUsedForMemory(recordIds: [UUID], tier: MemoryTier) {
        for i in transcriptionHistory.indices {
            if recordIds.contains(transcriptionHistory[i].id) {
                switch tier {
                case .global:
                    transcriptionHistory[i].usedForGlobalMemory = true
                case .context:
                    transcriptionHistory[i].usedForContextMemory = true
                case .powerMode:
                    transcriptionHistory[i].usedForPowerModeMemory = true
                }
            }
        }
        saveTranscriptionHistory()
    }

    /// Get transcription records that need to be processed for a memory tier
    func getUnprocessedRecordsForMemory(tier: MemoryTier, contextId: UUID? = nil, powerModeId: UUID? = nil) -> [TranscriptionRecord] {
        transcriptionHistory.filter { record in
            switch tier {
            case .global:
                return record.globalMemoryEnabled && !record.usedForGlobalMemory
            case .context:
                guard let targetContextId = contextId else { return false }
                return record.contextId == targetContextId &&
                       record.contextMemoryEnabled &&
                       !record.usedForContextMemory
            case .powerMode:
                guard let targetPowerModeId = powerModeId else { return false }
                return record.powerModeId == targetPowerModeId &&
                       record.powerModeMemoryEnabled &&
                       !record.usedForPowerModeMemory
            }
        }
    }
}

// MARK: - ContextProviderManager Conformance

extension SharedSettings: ContextProviderManager {
    // Protocol requirements are already implemented in SharedSettings:
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

// MARK: - LocalModelSettingsProvider Conformance

extension SharedSettings: LocalModelSettingsProvider {
    // Protocol requirements are already implemented in SharedSettings:
    // - whisperKitConfig: WhisperKitSettings
    // - parakeetMLXConfig: ParakeetMLXSettings (stub - not available on iOS)
    // - appleIntelligenceConfig: AppleIntelligenceConfig
    // - appleTranslationConfig: AppleTranslationConfig
    // - selfHostedLLMConfig: LocalProviderConfig?
    // - isWhisperKitReady: Bool
    // - isParakeetMLXReady: Bool (always false on iOS)
    // - isAppleIntelligenceReady: Bool
    // - hasLocalTranslation: Bool
    // - localModelStorageBytes: Int
    // - localModelStorageFormatted: String
}

/// Memory tier for update tracking
enum MemoryTier {
    case global
    case context
    case powerMode
}

/// Programmable button actions for the keyboard PredictionRow
/// The last button in PredictionRow can be assigned any of these actions
enum ProgrammableButtonAction: String, Codable, CaseIterable, Identifiable {
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

    var description: String {
        switch self {
        case .aiSparkles: return "Show AI sentence predictions"
        case .transcribe: return "Start voice transcription"
        case .translate: return "Translate selected text"
        case .aiFormat: return "Apply context/Power Mode formatting"
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
