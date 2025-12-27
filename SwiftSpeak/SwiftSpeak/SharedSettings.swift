//
//  SharedSettings.swift
//  SwiftSpeak
//
//  App Groups data sharing between main app and keyboard extension
//

import Foundation
import Combine

@MainActor
class SharedSettings: ObservableObject {
    static let shared = SharedSettings()

    private let defaults: UserDefaults?

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
        }
    }

    @Published var selectedTranslationProvider: AIProvider = .openAI {
        didSet {
            defaults?.set(selectedTranslationProvider.rawValue, forKey: Constants.Keys.selectedTranslationProvider)
        }
    }

    @Published var selectedPowerModeProvider: AIProvider = .openAI {
        didSet {
            defaults?.set(selectedPowerModeProvider.rawValue, forKey: Constants.Keys.selectedPowerModeProvider)
        }
    }

    @Published var selectedMode: FormattingMode = .raw {
        didSet {
            defaults?.set(selectedMode.rawValue, forKey: Constants.Keys.selectedMode)
        }
    }

    @Published var selectedTargetLanguage: Language = .spanish {
        didSet {
            defaults?.set(selectedTargetLanguage.rawValue, forKey: Constants.Keys.selectedTargetLanguage)
        }
    }

    @Published var isTranslationEnabled: Bool = false {
        didSet {
            defaults?.set(isTranslationEnabled, forKey: Constants.Keys.isTranslationEnabled)
        }
    }

    @Published var autoReturnEnabled: Bool = true {
        didSet {
            defaults?.set(autoReturnEnabled, forKey: Constants.Keys.autoReturnEnabled)
        }
    }

    @Published var subscriptionTier: SubscriptionTier = .free {
        didSet {
            defaults?.set(subscriptionTier.rawValue, forKey: Constants.Keys.subscriptionTier)
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
            } else {
                defaults?.removeObject(forKey: Constants.Keys.activeContextId)
            }
        }
    }

    // MARK: - Phase 4: Power Modes

    @Published var powerModes: [PowerMode] = [] {
        didSet {
            savePowerModes()
        }
    }

    // MARK: - Phase 4: History Memory (Global)

    @Published var historyMemory: HistoryMemory? {
        didSet {
            saveHistoryMemory()
        }
    }

    // MARK: - Phase 4a: Global Memory (3-Tier System)

    /// Global memory - always injected into prompts when enabled
    @Published var globalMemory: String? {
        didSet {
            defaults?.set(globalMemory, forKey: Constants.Keys.globalMemory)
        }
    }

    /// Whether global memory injection is enabled
    @Published var globalMemoryEnabled: Bool = true {
        didSet {
            defaults?.set(globalMemoryEnabled, forKey: Constants.Keys.globalMemoryEnabled)
        }
    }

    /// Whether Power Mode streaming is enabled (progressive text rendering)
    /// Only affects Power Mode LLM responses, NOT transcription or translation
    @Published var powerModeStreamingEnabled: Bool = true {
        didSet {
            defaults?.set(powerModeStreamingEnabled, forKey: Constants.Keys.powerModeStreamingEnabled)
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

    var lastTranscription: String? {
        get { defaults?.string(forKey: Constants.Keys.lastTranscription) }
        set { defaults?.set(newValue, forKey: Constants.Keys.lastTranscription) }
    }

    var transcriptionHistory: [TranscriptionRecord] {
        get {
            guard let data = defaults?.data(forKey: Constants.Keys.transcriptionHistory),
                  let records = try? JSONDecoder().decode([TranscriptionRecord].self, from: data) else {
                return []
            }
            return records
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults?.set(data, forKey: Constants.Keys.transcriptionHistory)
            }
        }
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
        }
    }

    /// Alias for vocabulary - used by PromptContext
    var vocabularyEntries: [VocabularyEntry] {
        vocabulary
    }

    // MARK: - Private Initialization

    private init() {
        defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        loadFromDefaults()
    }

    private func loadFromDefaults() {
        // Load hasCompletedOnboarding
        hasCompletedOnboarding = defaults?.bool(forKey: Constants.Keys.hasCompletedOnboarding) ?? false

        // Load mode
        if let modeRaw = defaults?.string(forKey: Constants.Keys.selectedMode),
           let mode = FormattingMode(rawValue: modeRaw) {
            selectedMode = mode
        }

        // Load language
        if let langRaw = defaults?.string(forKey: Constants.Keys.selectedTargetLanguage),
           let lang = Language(rawValue: langRaw) {
            selectedTargetLanguage = lang
        }

        // Load translation enabled
        isTranslationEnabled = defaults?.bool(forKey: Constants.Keys.isTranslationEnabled) ?? false

        // Load auto-return enabled (default: true)
        if defaults?.object(forKey: Constants.Keys.autoReturnEnabled) != nil {
            autoReturnEnabled = defaults?.bool(forKey: Constants.Keys.autoReturnEnabled) ?? true
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
        loadHistoryMemory()

        // Load global memory (3-tier system)
        globalMemory = defaults?.string(forKey: Constants.Keys.globalMemory)
        if defaults?.object(forKey: Constants.Keys.globalMemoryEnabled) != nil {
            globalMemoryEnabled = defaults?.bool(forKey: Constants.Keys.globalMemoryEnabled) ?? true
        }

        // Load user app category overrides
        loadUserAppCategoryOverrides()

        // Load knowledge documents (Phase 4e RAG)
        loadKnowledgeDocuments()

        // Load active context ID
        if let contextIdString = defaults?.string(forKey: Constants.Keys.activeContextId),
           let contextId = UUID(uuidString: contextIdString) {
            activeContextId = contextId
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

        if let powerModeProviderRaw = defaults?.string(forKey: Constants.Keys.selectedPowerModeProvider),
           let provider = AIProvider(rawValue: powerModeProviderRaw) {
            selectedPowerModeProvider = provider
        }
    }

    // MARK: - AI Provider Management

    private func loadConfiguredAIProviders() {
        if let data = defaults?.data(forKey: Constants.Keys.configuredAIProviders),
           let providers = try? JSONDecoder().decode([AIProviderConfig].self, from: data) {
            configuredAIProviders = providers
        } else {
            // Default: OpenAI with all capabilities
            let defaultConfig = AIProviderConfig(
                provider: .openAI,
                apiKey: openAIAPIKey ?? "",
                usageCategories: [.transcription, .translation, .powerMode]
            )
            configuredAIProviders = [defaultConfig]
        }
    }

    private func saveConfiguredAIProviders() {
        if let data = try? JSONEncoder().encode(configuredAIProviders) {
            defaults?.set(data, forKey: Constants.Keys.configuredAIProviders)
        }
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
        var history = transcriptionHistory
        history.insert(record, at: 0)
        if history.count > 100 {
            history = Array(history.prefix(100))
        }
        transcriptionHistory = history
    }

    func clearHistory() {
        transcriptionHistory = []
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
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
           let loadedContexts = try? JSONDecoder().decode([ConversationContext].self, from: data) {
            contexts = loadedContexts
        }
    }

    private func saveContexts() {
        if let data = try? JSONEncoder().encode(contexts) {
            defaults?.set(data, forKey: Constants.Keys.contexts)
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
        contexts.first { $0.id == id }
    }

    var activeContext: ConversationContext? {
        guard let id = activeContextId else { return nil }
        return contexts.first { $0.id == id }
    }

    func setActiveContext(_ context: ConversationContext?) {
        if let context = context {
            activeContextId = context.id
            // Update isActive flags
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
            powerModes[index].usageCount += 1
            powerModes[index].updatedAt = Date()
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
            contexts[index].memory = memory
            contexts[index].lastMemoryUpdate = Date()
            contexts[index].updatedAt = Date()
        }
    }

    func clearContextMemory(id: UUID) {
        if let index = contexts.firstIndex(where: { $0.id == id }) {
            contexts[index].memory = nil
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
}
