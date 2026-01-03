//
//  MacSharedSettings.swift
//  SwiftSpeakMac
//
//  macOS settings management (mirrors iOS SharedSettings)
//  Includes iCloud sync for cross-device settings synchronization
//

import Foundation
import Combine

@MainActor
class MacSettings: ObservableObject {
    static let shared = MacSettings()

    private let defaults: UserDefaults?
    private let iCloud = NSUbiquitousKeyValueStore.default
    private var iCloudObserver: NSObjectProtocol?
    private var isSyncing = false

    // iCloud sync keys
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
        }
    }

    // MARK: - Vocabulary

    @Published var vocabulary: [VocabularyEntry] = [] {
        didSet {
            saveVocabulary()
        }
    }

    // MARK: - History

    @Published var transcriptionHistory: [TranscriptionRecord] = [] {
        didSet {
            saveHistory()
        }
    }

    // MARK: - Initialization

    init() {
        self.defaults = UserDefaults.standard
        loadSettings()
        setupiCloudSync()
    }

    deinit {
        if let observer = iCloudObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - iCloud Sync Setup

    private func setupiCloudSync() {
        // Listen for iCloud changes from other devices
        iCloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloud,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let userInfo = notification.userInfo,
                  let reasonNumber = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? NSNumber else {
                return
            }

            let reason = reasonNumber.intValue

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
                print("⚠️ iCloud storage quota exceeded")
            default:
                break
            }
        }

        // Synchronize to get latest changes
        iCloud.synchronize()
    }

    private func loadFromiCloud() {
        // Load providers
        if let data = iCloud.data(forKey: iCloudKeys.configuredAIProviders),
           let providers = try? JSONDecoder().decode([AIProviderConfig].self, from: data) {
            configuredAIProviders = providers
        }

        // Load contexts
        if let data = iCloud.data(forKey: iCloudKeys.contexts),
           let loadedContexts = try? JSONDecoder().decode([ConversationContext].self, from: data) {
            contexts = loadedContexts
        }

        // Load power modes
        if let data = iCloud.data(forKey: iCloudKeys.powerModes),
           let loadedModes = try? JSONDecoder().decode([PowerMode].self, from: data) {
            powerModes = loadedModes
        }

        // Load vocabulary
        if let data = iCloud.data(forKey: iCloudKeys.vocabulary),
           let entries = try? JSONDecoder().decode([VocabularyEntry].self, from: data) {
            vocabulary = entries
        }

        // Load custom templates
        if let data = iCloud.data(forKey: iCloudKeys.customTemplates),
           let templates = try? JSONDecoder().decode([CustomTemplate].self, from: data) {
            customTemplates = templates
        }

        // Load primitive values
        if let providerRaw = iCloud.string(forKey: iCloudKeys.selectedTranscriptionProvider),
           let provider = AIProvider(rawValue: providerRaw) {
            selectedTranscriptionProvider = provider
        }

        if let providerRaw = iCloud.string(forKey: iCloudKeys.selectedTranslationProvider),
           let provider = AIProvider(rawValue: providerRaw) {
            selectedTranslationProvider = provider
        }

        if let providerRaw = iCloud.string(forKey: iCloudKeys.selectedPowerModeProvider),
           let provider = AIProvider(rawValue: providerRaw) {
            selectedPowerModeProvider = provider
        }

        if let modeRaw = iCloud.string(forKey: iCloudKeys.selectedMode),
           let mode = FormattingMode(rawValue: modeRaw) {
            selectedMode = mode
        }

        if let langRaw = iCloud.string(forKey: iCloudKeys.selectedTargetLanguage),
           let lang = Language(rawValue: langRaw) {
            selectedTargetLanguage = lang
        }

        isTranslationEnabled = iCloud.bool(forKey: iCloudKeys.isTranslationEnabled)

        // Load global memory settings
        if let memory = iCloud.string(forKey: iCloudKeys.globalMemory) {
            globalMemory = memory
        }
        globalMemoryEnabled = iCloud.bool(forKey: iCloudKeys.globalMemoryEnabled)
        let limit = iCloud.longLong(forKey: iCloudKeys.globalMemoryLimit)
        if limit > 0 {
            globalMemoryLimit = Int(limit)
        }
    }

    private func syncToiCloud() {
        guard !isSyncing else { return }

        // Sync providers
        if let data = try? JSONEncoder().encode(configuredAIProviders) {
            iCloud.set(data, forKey: iCloudKeys.configuredAIProviders)
        }

        // Sync contexts
        if let data = try? JSONEncoder().encode(contexts) {
            iCloud.set(data, forKey: iCloudKeys.contexts)
        }

        // Sync power modes
        if let data = try? JSONEncoder().encode(powerModes) {
            iCloud.set(data, forKey: iCloudKeys.powerModes)
        }

        // Sync vocabulary
        if let data = try? JSONEncoder().encode(vocabulary) {
            iCloud.set(data, forKey: iCloudKeys.vocabulary)
        }

        // Sync custom templates
        if let data = try? JSONEncoder().encode(customTemplates) {
            iCloud.set(data, forKey: iCloudKeys.customTemplates)
        }

        // Sync primitive values
        iCloud.set(selectedTranscriptionProvider.rawValue, forKey: iCloudKeys.selectedTranscriptionProvider)
        iCloud.set(selectedTranslationProvider.rawValue, forKey: iCloudKeys.selectedTranslationProvider)
        iCloud.set(selectedPowerModeProvider.rawValue, forKey: iCloudKeys.selectedPowerModeProvider)
        iCloud.set(selectedMode.rawValue, forKey: iCloudKeys.selectedMode)
        iCloud.set(selectedTargetLanguage.rawValue, forKey: iCloudKeys.selectedTargetLanguage)
        iCloud.set(isTranslationEnabled, forKey: iCloudKeys.isTranslationEnabled)

        // Sync global memory settings
        if let memory = globalMemory {
            iCloud.set(memory, forKey: iCloudKeys.globalMemory)
        } else {
            iCloud.removeObject(forKey: iCloudKeys.globalMemory)
        }
        iCloud.set(globalMemoryEnabled, forKey: iCloudKeys.globalMemoryEnabled)
        iCloud.set(Int64(globalMemoryLimit), forKey: iCloudKeys.globalMemoryLimit)

        // Set sync timestamp
        iCloud.set(Date().timeIntervalSince1970, forKey: iCloudKeys.lastSyncTimestamp)

        // Trigger synchronization
        iCloud.synchronize()
    }

    /// Force sync settings to iCloud (call after making changes)
    func forceSyncToiCloud() {
        syncToiCloud()
    }

    /// Get last sync timestamp
    var lastSyncTime: Date? {
        let timestamp = iCloud.double(forKey: iCloudKeys.lastSyncTimestamp)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
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
        loadHistoryMemory()
        loadCustomTemplates()
        loadVocabulary()

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

        loadHistory()
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
        transcriptionHistory.insert(record, at: 0)
        if transcriptionHistory.count > 100 {
            transcriptionHistory = Array(transcriptionHistory.prefix(100))
        }
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
        transcriptionHistory = []
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
