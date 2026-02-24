//
//  KeyboardSettings.swift
//  SwiftSpeakKeyboard
//
//  Phase 13.10: Keyboard-specific settings model
//

import Foundation

/// Keyboard theme size options for space optimization
enum KeyboardThemeSize: String, Codable, CaseIterable, Identifiable {
    case normal = "normal"
    case compact = "compact"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .compact: return "Compact"
        }
    }

    var description: String {
        switch self {
        case .normal: return "Standard keyboard size"
        case .compact: return "Reduced size for more screen space"
        }
    }
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

/// Keyboard-specific settings (separate from main app settings)
struct KeyboardSettings {
    // MARK: - Keyboard Layout (Phase 16)

    /// Keyboard theme size - normal or compact
    var themeSize: KeyboardThemeSize = .normal

    /// Show SwiftSpeakBar in typing mode
    var showSwiftSpeakBar: Bool = true

    /// Show PredictionRow in typing mode
    var showPredictionRow: Bool = true

    /// Action for programmable button in PredictionRow
    var programmableAction: ProgrammableButtonAction = .aiSparkles

    /// Show programmable button next to Return key
    var showProgrammableNextToReturn: Bool = false

    /// Action for programmable button next to Return
    var returnProgrammableAction: ProgrammableButtonAction = .transcribe

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

    /// Autocorrect language (en, pl, etc.)
    var autocorrectLanguage: String = "en"

    /// Autocorrect language mode: "sync" (match transcription), "auto" (detect), "manual" (use autocorrectLanguage)
    var autocorrectLanguageMode: String = "sync"

    // MARK: - Voice Settings (mirror from main app)

    /// Spoken language for transcription
    var spokenLanguage: String = "en"

    /// Default formatting mode
    var defaultMode: String = "raw"

    /// Output Arabizi (Franco-Arabic) - converts Arabic to Latin with numbers
    var outputArabizi: Bool = false

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

        // Phase 16: Keyboard Layout Settings
        if let themeSizeRaw = defaults?.string(forKey: "keyboardThemeSize"),
           let themeSize = KeyboardThemeSize(rawValue: themeSizeRaw) {
            settings.themeSize = themeSize
        }
        settings.showSwiftSpeakBar = (defaults?.object(forKey: Constants.Keys.keyboardShowSwiftSpeakBar) as? Bool) ?? true
        settings.showPredictionRow = (defaults?.object(forKey: Constants.Keys.keyboardShowPredictionRow) as? Bool) ?? true
        if let actionRaw = defaults?.string(forKey: Constants.Keys.keyboardProgrammableAction),
           let action = ProgrammableButtonAction(rawValue: actionRaw) {
            settings.programmableAction = action
        }
        settings.showProgrammableNextToReturn = (defaults?.object(forKey: Constants.Keys.keyboardShowProgrammableNextToReturn) as? Bool) ?? false
        if let returnActionRaw = defaults?.string(forKey: Constants.Keys.keyboardReturnProgrammableAction),
           let returnAction = ProgrammableButtonAction(rawValue: returnActionRaw) {
            settings.returnProgrammableAction = returnAction
        }

        // Keyboard behavior - use object(forKey:) to properly detect missing keys
        // bool(forKey:) returns false for missing keys, so ?? defaultValue never works
        settings.hapticFeedback = (defaults?.object(forKey: "keyboardHapticFeedback") as? Bool) ?? true
        settings.aiPredictions = (defaults?.object(forKey: "keyboardAIPredictions") as? Bool) ?? true
        settings.autocorrect = (defaults?.object(forKey: "keyboardAutocorrect") as? Bool) ?? true
        settings.swipeTyping = (defaults?.object(forKey: Constants.Keys.swipeTypingEnabled) as? Bool) ?? true
        settings.smartPunctuation = (defaults?.object(forKey: "keyboardSmartPunctuation") as? Bool) ?? true
        settings.rememberLastMode = (defaults?.object(forKey: "keyboardRememberLastMode") as? Bool) ?? true
        settings.autocorrectLanguage = defaults?.string(forKey: "keyboardAutocorrectLanguage") ?? "en"
        settings.autocorrectLanguageMode = defaults?.string(forKey: "keyboardAutocorrectLanguageMode") ?? "sync"

        // Voice settings (from main app)
        if let langRaw = defaults?.string(forKey: Constants.Keys.selectedDictationLanguage) {
            settings.spokenLanguage = langRaw
        }
        if let modeRaw = defaults?.string(forKey: Constants.Keys.selectedMode) {
            settings.defaultMode = modeRaw
        }
        settings.outputArabizi = (defaults?.object(forKey: "outputArabizi") as? Bool) ?? false

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

        // Phase 16: Keyboard Layout Settings
        defaults?.set(themeSize.rawValue, forKey: "keyboardThemeSize")
        defaults?.set(showSwiftSpeakBar, forKey: Constants.Keys.keyboardShowSwiftSpeakBar)
        defaults?.set(showPredictionRow, forKey: Constants.Keys.keyboardShowPredictionRow)
        defaults?.set(programmableAction.rawValue, forKey: Constants.Keys.keyboardProgrammableAction)
        defaults?.set(showProgrammableNextToReturn, forKey: Constants.Keys.keyboardShowProgrammableNextToReturn)
        defaults?.set(returnProgrammableAction.rawValue, forKey: Constants.Keys.keyboardReturnProgrammableAction)

        // Keyboard behavior
        defaults?.set(hapticFeedback, forKey: "keyboardHapticFeedback")
        defaults?.set(aiPredictions, forKey: "keyboardAIPredictions")
        defaults?.set(autocorrect, forKey: "keyboardAutocorrect")
        defaults?.set(swipeTyping, forKey: Constants.Keys.swipeTypingEnabled)
        defaults?.set(smartPunctuation, forKey: "keyboardSmartPunctuation")
        defaults?.set(rememberLastMode, forKey: "keyboardRememberLastMode")
        defaults?.set(autocorrectLanguage, forKey: "keyboardAutocorrectLanguage")
        defaults?.set(autocorrectLanguageMode, forKey: "keyboardAutocorrectLanguageMode")

        // Voice settings (update main app settings too)
        defaults?.set(spokenLanguage, forKey: Constants.Keys.selectedDictationLanguage)
        defaults?.set(defaultMode, forKey: Constants.Keys.selectedMode)
        defaults?.set(outputArabizi, forKey: "outputArabizi")

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

    // MARK: - Spelling Language

    /// Get the effective spelling language code based on mode
    /// Returns language code like "en", "pl", "es", etc.
    var effectiveSpellingLanguageCode: String {
        switch autocorrectLanguageMode {
        case "sync":
            // Sync with transcription/spoken language
            return spokenLanguage
        case "manual":
            // Use explicitly selected language
            return autocorrectLanguage
        case "auto":
            // Auto-detect - return current setting, actual detection happens at runtime
            return autocorrectLanguage
        default:
            return "en"
        }
    }

    /// Whether auto-detect mode is enabled
    var isAutoDetectEnabled: Bool {
        return autocorrectLanguageMode == "auto" || spokenLanguage == "auto"
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
