//
//  KeyboardSettings.swift
//  SwiftSpeakKeyboard
//
//  Phase 13.10: Keyboard-specific settings model
//

import Foundation

/// Keyboard-specific settings (separate from main app settings)
struct KeyboardSettings {
    // MARK: - Keyboard Behavior

    /// Enable/disable haptic feedback on key presses
    var hapticFeedback: Bool = true

    /// Enable/disable AI predictions
    var aiPredictions: Bool = true

    /// Enable/disable autocorrect
    var autocorrect: Bool = true

    /// Enable/disable swipe typing
    var swipeTyping: Bool = true

    /// Enable/disable smart punctuation
    var smartPunctuation: Bool = true

    /// Remember last mode (voice vs typing)
    var rememberLastMode: Bool = true

    // MARK: - Voice Settings (mirror from main app)

    /// Spoken language for transcription
    var spokenLanguage: String = "en"

    /// Default formatting mode
    var defaultMode: String = "raw"

    // MARK: - Translation Settings

    /// Auto-translate enabled
    var autoTranslate: Bool = false

    /// Target translation language
    var targetLanguage: String = "es"

    // MARK: - Provider Info (read-only, from main app)

    /// Current transcription provider name (display only)
    var transcriptionProvider: String = "Not configured"

    /// Current formatting provider name (display only)
    var formattingProvider: String = "Not configured"

    /// Current translation provider name (display only)
    var translationProvider: String = "Not configured"

    /// Active context name (display only)
    var activeContextName: String?

    /// Subscription tier (display only)
    var subscriptionTier: String = "free"

    /// SwiftLink status (display only)
    var swiftLinkActive: Bool = false

    // MARK: - Persistence

    /// Load settings from App Groups
    static func load() -> KeyboardSettings {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        var settings = KeyboardSettings()

        // Keyboard behavior - use object(forKey:) to properly detect missing keys
        // bool(forKey:) returns false for missing keys, so ?? defaultValue never works
        settings.hapticFeedback = (defaults?.object(forKey: "keyboardHapticFeedback") as? Bool) ?? true
        settings.aiPredictions = (defaults?.object(forKey: "keyboardAIPredictions") as? Bool) ?? true
        settings.autocorrect = (defaults?.object(forKey: "keyboardAutocorrect") as? Bool) ?? true
        settings.swipeTyping = (defaults?.object(forKey: Constants.Keys.swipeTypingEnabled) as? Bool) ?? true
        settings.smartPunctuation = (defaults?.object(forKey: "keyboardSmartPunctuation") as? Bool) ?? true
        settings.rememberLastMode = (defaults?.object(forKey: "keyboardRememberLastMode") as? Bool) ?? true

        // Voice settings (from main app)
        if let langRaw = defaults?.string(forKey: Constants.Keys.selectedDictationLanguage) {
            settings.spokenLanguage = langRaw
        }
        if let modeRaw = defaults?.string(forKey: Constants.Keys.selectedMode) {
            settings.defaultMode = modeRaw
        }

        // Translation settings
        settings.autoTranslate = (defaults?.object(forKey: Constants.Keys.isTranslationEnabled) as? Bool) ?? false
        if let targetLang = defaults?.string(forKey: Constants.Keys.selectedTargetLanguage) {
            settings.targetLanguage = targetLang
        }

        // Provider info (read-only)
        settings.loadProviderInfo(from: defaults)
        settings.loadActiveContext(from: defaults)

        // Subscription tier
        if let tierRaw = defaults?.string(forKey: Constants.Keys.subscriptionTier) {
            settings.subscriptionTier = tierRaw
        }

        // SwiftLink status
        settings.swiftLinkActive = (defaults?.object(forKey: Constants.Keys.swiftLinkSessionActive) as? Bool) ?? false

        return settings
    }

    /// Save settings to App Groups
    func save() {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        // Keyboard behavior
        defaults?.set(hapticFeedback, forKey: "keyboardHapticFeedback")
        defaults?.set(aiPredictions, forKey: "keyboardAIPredictions")
        defaults?.set(autocorrect, forKey: "keyboardAutocorrect")
        defaults?.set(swipeTyping, forKey: Constants.Keys.swipeTypingEnabled)
        defaults?.set(smartPunctuation, forKey: "keyboardSmartPunctuation")
        defaults?.set(rememberLastMode, forKey: "keyboardRememberLastMode")

        // Voice settings (update main app settings too)
        defaults?.set(spokenLanguage, forKey: Constants.Keys.selectedDictationLanguage)
        defaults?.set(defaultMode, forKey: Constants.Keys.selectedMode)

        // Translation settings
        defaults?.set(autoTranslate, forKey: Constants.Keys.isTranslationEnabled)
        defaults?.set(targetLanguage, forKey: Constants.Keys.selectedTargetLanguage)

        defaults?.synchronize()
    }

    // MARK: - Provider Info Loading

    private mutating func loadProviderInfo(from defaults: UserDefaults?) {
        guard let data = defaults?.data(forKey: Constants.Keys.configuredAIProviders) else {
            return
        }

        struct SimpleAIProviderConfig: Codable {
            let provider: String
            let usageCategories: [String]
        }

        guard let configs = try? JSONDecoder().decode([SimpleAIProviderConfig].self, from: data) else {
            return
        }

        // Find transcription provider
        if let config = configs.first(where: { $0.usageCategories.contains("transcription") }) {
            transcriptionProvider = config.provider.capitalized
        }

        // Find formatting provider (usually same as transcription for now)
        if let config = configs.first(where: { $0.usageCategories.contains("powerMode") }) {
            formattingProvider = config.provider.capitalized
        } else if let config = configs.first {
            formattingProvider = config.provider.capitalized
        }

        // Find translation provider
        if let config = configs.first(where: { $0.usageCategories.contains("translation") }) {
            translationProvider = config.provider.capitalized
        }
    }

    private mutating func loadActiveContext(from defaults: UserDefaults?) {
        guard let contextIdString = defaults?.string(forKey: Constants.Keys.activeContextId),
              let contextId = UUID(uuidString: contextIdString) else {
            return
        }

        // Load contexts and find active one
        guard let data = defaults?.data(forKey: Constants.Keys.contexts) else {
            return
        }

        struct SimpleContext: Codable {
            let id: UUID
            let name: String
        }

        guard let contexts = try? JSONDecoder().decode([SimpleContext].self, from: data),
              let context = contexts.first(where: { $0.id == contextId }) else {
            return
        }

        activeContextName = context.name
    }
}
