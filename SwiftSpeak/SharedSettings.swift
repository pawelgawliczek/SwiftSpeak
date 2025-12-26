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

    // MARK: - Published Properties (with explicit storage for proper initialization)
    @Published var hasCompletedOnboarding: Bool = false {
        didSet {
            defaults?.set(hasCompletedOnboarding, forKey: Constants.Keys.hasCompletedOnboarding)
        }
    }

    @Published var selectedProvider: STTProvider = .openAI {
        didSet {
            defaults?.set(selectedProvider.rawValue, forKey: Constants.Keys.selectedProvider)
        }
    }

    @Published var configuredSTTProviders: [STTProviderConfig] = [] {
        didSet {
            saveConfiguredProviders()
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

    @Published var selectedModeProvider: LLMProvider = .openAI {
        didSet {
            defaults?.set(selectedModeProvider.rawValue, forKey: Constants.Keys.selectedModeProvider)
        }
    }

    @Published var selectedTranslationProvider: LLMProvider = .openAI {
        didSet {
            defaults?.set(selectedTranslationProvider.rawValue, forKey: Constants.Keys.selectedTranslationProvider)
        }
    }

    @Published var subscriptionTier: SubscriptionTier = .free {
        didSet {
            defaults?.set(subscriptionTier.rawValue, forKey: Constants.Keys.subscriptionTier)
        }
    }

    // MARK: - Non-Published Properties (computed from UserDefaults)
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

    var ollamaEndpoint: String? {
        get { defaults?.string(forKey: Constants.Keys.ollamaEndpoint) }
        set { defaults?.set(newValue, forKey: Constants.Keys.ollamaEndpoint) }
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

    // MARK: - Private Initialization
    private init() {
        defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        loadFromDefaults()
    }

    private func loadFromDefaults() {
        // Load hasCompletedOnboarding
        hasCompletedOnboarding = defaults?.bool(forKey: Constants.Keys.hasCompletedOnboarding) ?? false

        // Load provider
        if let providerRaw = defaults?.string(forKey: Constants.Keys.selectedProvider),
           let provider = STTProvider(rawValue: providerRaw) {
            selectedProvider = provider
        }

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

        // Load mode provider
        if let modeProviderRaw = defaults?.string(forKey: Constants.Keys.selectedModeProvider),
           let modeProvider = LLMProvider(rawValue: modeProviderRaw) {
            selectedModeProvider = modeProvider
        }

        // Load translation provider
        if let translationProviderRaw = defaults?.string(forKey: Constants.Keys.selectedTranslationProvider),
           let translationProvider = LLMProvider(rawValue: translationProviderRaw) {
            selectedTranslationProvider = translationProvider
        }

        // Load subscription tier
        if let tierRaw = defaults?.string(forKey: Constants.Keys.subscriptionTier),
           let tier = SubscriptionTier(rawValue: tierRaw) {
            subscriptionTier = tier
        }

        // Load configured STT providers
        loadConfiguredProviders()
    }

    // MARK: - STT Provider Management
    private func loadConfiguredProviders() {
        if let data = defaults?.data(forKey: Constants.Keys.configuredSTTProviders),
           let providers = try? JSONDecoder().decode([STTProviderConfig].self, from: data) {
            configuredSTTProviders = providers
        } else {
            // Default: OpenAI Whisper with any existing API key
            let defaultConfig = STTProviderConfig(
                provider: .openAI,
                apiKey: openAIAPIKey ?? "",
                model: STTProvider.openAI.defaultModel
            )
            configuredSTTProviders = [defaultConfig]
        }
    }

    private func saveConfiguredProviders() {
        if let data = try? JSONEncoder().encode(configuredSTTProviders) {
            defaults?.set(data, forKey: Constants.Keys.configuredSTTProviders)
        }
    }

    func addSTTProvider(_ config: STTProviderConfig) {
        // Don't add duplicates
        guard !configuredSTTProviders.contains(where: { $0.provider == config.provider }) else { return }
        configuredSTTProviders.append(config)
    }

    func updateSTTProvider(_ config: STTProviderConfig) {
        if let index = configuredSTTProviders.firstIndex(where: { $0.provider == config.provider }) {
            configuredSTTProviders[index] = config
        }
    }

    func removeSTTProvider(_ provider: STTProvider) {
        configuredSTTProviders.removeAll { $0.provider == provider }
        // If we removed the selected provider, select the first available
        if selectedProvider == provider, let first = configuredSTTProviders.first {
            selectedProvider = first.provider
        }
    }

    func getSTTProviderConfig(for provider: STTProvider) -> STTProviderConfig? {
        configuredSTTProviders.first { $0.provider == provider }
    }

    var availableProvidersToAdd: [STTProvider] {
        let configuredProviderTypes = Set(configuredSTTProviders.map { $0.provider })
        return STTProvider.allCases.filter { !configuredProviderTypes.contains($0) }
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

    func hasValidAPIKey(for provider: STTProvider) -> Bool {
        switch provider {
        case .openAI:
            return openAIAPIKey?.isEmpty == false
        case .elevenLabs:
            return elevenLabsAPIKey?.isEmpty == false
        case .deepgram:
            return deepgramAPIKey?.isEmpty == false
        case .ollama:
            return ollamaEndpoint?.isEmpty == false
        }
    }
}
