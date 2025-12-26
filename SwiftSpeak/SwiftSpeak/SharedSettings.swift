//
//  SharedSettings.swift
//  SwiftSpeak
//
//  App Groups data sharing between main app and keyboard extension
//

import Foundation
import Combine

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

    @Published var subscriptionTier: SubscriptionTier = .free {
        didSet {
            defaults?.set(subscriptionTier.rawValue, forKey: Constants.Keys.subscriptionTier)
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

        // Load subscription tier
        if let tierRaw = defaults?.string(forKey: Constants.Keys.subscriptionTier),
           let tier = SubscriptionTier(rawValue: tierRaw) {
            subscriptionTier = tier
        }

        // Load configured AI providers
        loadConfiguredAIProviders()

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
}
