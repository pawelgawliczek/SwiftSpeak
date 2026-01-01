//
//  Constants.swift
//  SwiftSpeak
//
//  Shared constants between main app and keyboard extension
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

enum Constants {
    // MARK: - App Group
    static let appGroupIdentifier = "group.pawelgawliczek.swiftspeak"

    // MARK: - Bundle IDs
    static let keyboardBundleID = "pawelgawliczek.SwiftSpeak.SwiftSpeakKeyboard"

    // MARK: - URL Scheme
    static let urlScheme = "swiftspeak"

    // MARK: - UserDefaults Keys
    enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let configuredAIProviders = "configuredAIProviders"
        static let selectedTranscriptionProvider = "selectedTranscriptionProvider"
        static let selectedTranslationProvider = "selectedTranslationProvider"
        static let selectedPowerModeProvider = "selectedPowerModeProvider"
        static let openAIAPIKey = "openAIAPIKey"
        static let anthropicAPIKey = "anthropicAPIKey"
        static let elevenLabsAPIKey = "elevenLabsAPIKey"
        static let deepgramAPIKey = "deepgramAPIKey"
        static let ollamaEndpoint = "ollamaEndpoint"
        static let selectedMode = "selectedMode"
        static let selectedTargetLanguage = "selectedTargetLanguage"
        static let isTranslationEnabled = "isTranslationEnabled"
        static let selectedDictationLanguage = "selectedDictationLanguage"
        static let autoReturnEnabled = "autoReturnEnabled"
        static let lastTranscription = "lastTranscription"
        static let transcriptionHistory = "transcriptionHistory"
        static let subscriptionTier = "subscriptionTier"
        static let vocabulary = "vocabulary"
        static let customTemplates = "customTemplates"

        // Phase 4: Contexts and Power Modes
        static let contexts = "contexts"
        static let activeContextId = "activeContextId"
        static let powerModes = "powerModes"
        static let historyMemory = "historyMemory"

        // Phase 4a: Global Memory (3-Tier System)
        static let globalMemory = "globalMemory"
        static let globalMemoryEnabled = "globalMemoryEnabled"
        static let powerModeStreamingEnabled = "powerModeStreamingEnabled"
        static let transcriptionStreamingEnabled = "transcriptionStreamingEnabled"

        // App Library: User app category overrides
        static let userAppCategoryOverrides = "userAppCategoryOverrides"

        // Phase 4e: RAG Knowledge Documents
        static let knowledgeDocuments = "knowledgeDocuments"

        // Phase 4f: Webhooks
        static let webhooks = "webhooks"

        // Phase 6: Security & Privacy
        static let biometricProtectionEnabled = "biometricProtectionEnabled"
        static let dataRetentionPeriod = "dataRetentionPeriod"

        // Phase 10: Local Models & Provider Defaults
        static let whisperKitConfig = "whisperKitConfig"
        static let appleIntelligenceConfig = "appleIntelligenceConfig"
        static let appleTranslationConfig = "appleTranslationConfig"
        static let providerDefaults = "providerDefaults"
        static let forcePrivacyMode = "forcePrivacyMode"

        // Phase 13.8: Swipe Typing
        static let swipeTypingEnabled = "swipeTypingEnabled"

        // SwiftLink: Background Dictation Sessions
        static let swiftLinkApps = "swiftLinkApps"
        static let swiftLinkSessionDuration = "swiftLinkSessionDuration"
        static let swiftLinkLastUsedApp = "swiftLinkLastUsedApp"
        static let swiftLinkSessionActive = "swiftLinkSessionActive"
        /// Auto-start SwiftLink when using voice input (enabled by default)
        static let swiftLinkAutoStart = "swiftLinkAutoStart"
        static let swiftLinkSessionStartTime = "swiftLinkSessionStartTime"
        static let swiftLinkDictationStartTime = "swiftLinkDictationStartTime"
        static let swiftLinkDictationEndTime = "swiftLinkDictationEndTime"
        static let swiftLinkTranscriptionResult = "swiftLinkTranscriptionResult"
        static let swiftLinkProcessingStatus = "swiftLinkProcessingStatus"
        /// Live streaming transcript for real-time display in keyboard
        static let swiftLinkStreamingTranscript = "swiftLinkStreamingTranscript"
    }

    // MARK: - API Endpoints
    enum API {
        // OpenAI
        static let openAIWhisper = "https://api.openai.com/v1/audio/transcriptions"
        static let openAIChat = "https://api.openai.com/v1/chat/completions"

        // Anthropic
        static let anthropic = "https://api.anthropic.com/v1/messages"

        // ElevenLabs
        static let elevenLabs = "https://api.elevenlabs.io/v1/speech-to-text"

        // Deepgram
        static let deepgram = "https://api.deepgram.com/v1/listen"

        // AssemblyAI
        static let assemblyAIUpload = "https://api.assemblyai.com/v2/upload"
        static let assemblyAITranscript = "https://api.assemblyai.com/v2/transcript"

        // Google Cloud
        static let googleSTT = "https://speech.googleapis.com/v2/projects"
        static let googleTranslation = "https://translation.googleapis.com/language/translate/v2"
        static let gemini = "https://generativelanguage.googleapis.com/v1beta/models"

        // DeepL
        static let deepL = "https://api.deepl.com/v2/translate"
        static let deepLFree = "https://api-free.deepl.com/v2/translate"

        // Azure
        static let azureTranslator = "https://api.cognitive.microsofttranslator.com/translate"
    }

    // MARK: - Subscription Product IDs
    enum Products {
        static let proMonthly = "com.swiftspeak.pro.monthly"
        static let proYearly = "com.swiftspeak.pro.yearly"
        static let powerMonthly = "com.swiftspeak.power.monthly"
        static let powerYearly = "com.swiftspeak.power.yearly"
    }

    // MARK: - RevenueCat
    enum RevenueCat {
        // Test API key - replace with production key before App Store release
        static let apiKey = "YOUR_REVENUECAT_API_KEY"

        // Entitlement identifiers (configure in RevenueCat dashboard)
        static let proEntitlement = "pro"
        static let powerEntitlement = "power"
    }

    // MARK: - URL Scheme Hosts (Phase 12)
    enum URLHosts {
        static let record = "record"
        static let edit = "edit"
        static let powermode = "powermode"
        static let swiftlink = "swiftlink"
        static let setup = "setup"
        static let pending = "pending"
    }

    // MARK: - SwiftLink Darwin Notifications
    enum SwiftLinkNotifications {
        static let prefix = "com.swiftspeak.swiftlink."
        static let startDictation = prefix + "startDictation"
        static let stopDictation = prefix + "stopDictation"
        static let resultReady = prefix + "resultReady"
        static let sessionStarted = prefix + "sessionStarted"
        static let sessionEnded = prefix + "sessionEnded"

        // Phase 12: Edit Text via SwiftLink
        static let startEdit = prefix + "startEdit"
        static let editResultReady = prefix + "editResultReady"

        // Streaming transcription updates
        static let streamingUpdate = prefix + "streamingUpdate"
    }

    // MARK: - App Groups Keys for Edit Mode (Phase 12)
    enum EditMode {
        /// Key for storing original text to edit (in App Groups UserDefaults)
        static let pendingEditText = "pendingEditText"
        /// Key for storing original text during SwiftLink edit
        static let swiftLinkEditOriginalText = "swiftLinkEditOriginalText"
        /// Key for tracking if last result was an edit (for keyboard to know to clear field first)
        static let lastResultWasEdit = "lastResultWasEdit"
    }

    // MARK: - AI Context Processing (Phase 13.11)
    enum AIProcess {
        /// Key for storing text to process
        static let pendingText = "aiProcessPendingText"
        /// Key for storing context ID
        static let contextId = "aiProcessContextId"
        /// Key for storing power mode ID (alternative to context)
        static let powerModeId = "aiProcessPowerModeId"
        /// Key for storing result
        static let result = "aiProcessResult"
        /// Key for storing status ("processing", "complete", "error")
        static let status = "aiProcessStatus"
        /// Key for storing source app URL scheme for auto-return
        static let sourceAppURLScheme = "aiProcessSourceAppURLScheme"
        /// Key for requesting auto-return after processing
        static let autoReturnRequested = "aiProcessAutoReturnRequested"
        /// Key for requesting SwiftLink to be started along with AI process
        static let startSwiftLinkWithProcess = "aiProcessStartSwiftLink"
        /// Key for requesting translation (when no context, just translate)
        static let translateEnabled = "aiProcessTranslateEnabled"
        /// Key for storing target language for translation
        static let targetLanguage = "aiProcessTargetLanguage"
        /// Darwin notification name for starting AI process (keyboard -> app)
        static let startProcess = "swiftspeak.aiprocess.startProcess"
        /// Darwin notification name for result ready (app -> keyboard)
        static let resultReady = "swiftspeak.aiprocess.resultReady"
    }

    // MARK: - SwiftLink Session Duration
    enum SwiftLinkSessionDuration: Int, CaseIterable, Codable {
        case fiveMinutes = 300
        case fifteenMinutes = 900
        case oneHour = 3600
        case never = 0  // 0 means never auto-end

        var displayName: String {
            switch self {
            case .fiveMinutes: return "5 minutes"
            case .fifteenMinutes: return "15 minutes"
            case .oneHour: return "1 hour"
            case .never: return "Never (manual)"
            }
        }

        var timeInterval: TimeInterval? {
            self == .never ? nil : TimeInterval(rawValue)
        }
    }

    // MARK: - Phase 11j: Audio Validation
    enum AudioValidation {
        /// Minimum recording duration (seconds) - below this produces garbage
        static let minDuration: TimeInterval = 0.5

        /// Maximum recording duration (seconds) - providers may timeout
        static let maxDuration: TimeInterval = 600  // 10 minutes

        /// Warning threshold for long recordings (seconds)
        static let warnDuration: TimeInterval = 300  // 5 minutes

        /// Maximum file size (bytes) for upload
        static let maxFileSize: Int64 = 25 * 1024 * 1024  // 25 MB

        /// Validation result - simple type usable by both app and keyboard extension
        enum ValidationResult: Equatable {
            case valid
            case tooShort(duration: TimeInterval)
            case tooLong(duration: TimeInterval)
            case fileTooLarge(sizeMB: Double, maxSizeMB: Double)
        }

        /// Validate duration is within acceptable range
        static func validateDuration(_ duration: TimeInterval) -> ValidationResult {
            if duration < minDuration {
                return .tooShort(duration: duration)
            }
            if duration > maxDuration {
                return .tooLong(duration: duration)
            }
            return .valid
        }

        /// Validate file size
        static func validateFileSize(_ bytes: Int64) -> ValidationResult {
            if bytes > maxFileSize {
                let sizeMB = Double(bytes) / (1024 * 1024)
                let maxMB = Double(maxFileSize) / (1024 * 1024)
                return .fileTooLarge(sizeMB: sizeMB, maxSizeMB: maxMB)
            }
            return .valid
        }

        /// Check if duration warrants a warning (long but not error)
        static func shouldWarnDuration(_ duration: TimeInterval) -> Bool {
            duration > warnDuration && duration <= maxDuration
        }
    }
}
