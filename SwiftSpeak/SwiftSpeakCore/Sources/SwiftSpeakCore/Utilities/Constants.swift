//
//  Constants.swift
//  SwiftSpeak
//
//  Shared constants between main app and keyboard extension
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

public enum Constants {
    // MARK: - App Group
    public static let appGroupIdentifier = "group.pawelgawliczek.swiftspeak"

    // MARK: - Bundle IDs
    public static let keyboardBundleID = "pawelgawliczek.SwiftSpeak.SwiftSpeakKeyboard"

    // MARK: - URL Scheme
    public static let urlScheme = "swiftspeak"

    // MARK: - UserDefaults Keys
    public enum Keys {
        public static let hasCompletedOnboarding = "hasCompletedOnboarding"
        public static let configuredAIProviders = "configuredAIProviders"
        public static let selectedTranscriptionProvider = "selectedTranscriptionProvider"
        public static let selectedTranslationProvider = "selectedTranslationProvider"
        public static let selectedFormattingProvider = "selectedFormattingProvider"
        public static let selectedPowerModeProvider = "selectedPowerModeProvider"
        public static let openAIAPIKey = "openAIAPIKey"
        public static let anthropicAPIKey = "anthropicAPIKey"
        public static let elevenLabsAPIKey = "elevenLabsAPIKey"
        public static let deepgramAPIKey = "deepgramAPIKey"
        public static let ollamaEndpoint = "ollamaEndpoint"
        public static let selectedMode = "selectedMode"
        public static let selectedTargetLanguage = "selectedTargetLanguage"
        public static let isTranslationEnabled = "isTranslationEnabled"
        public static let selectedDictationLanguage = "selectedDictationLanguage"
        public static let autoReturnEnabled = "autoReturnEnabled"
        public static let lastTranscription = "lastTranscription"
        public static let transcriptionHistory = "transcriptionHistory"
        public static let vocabulary = "vocabulary"
        public static let customTemplates = "customTemplates"

        // Phase 4: Contexts and Power Modes
        public static let contexts = "contexts"
        public static let activeContextId = "activeContextId"
        public static let powerModes = "powerModes"
        public static let historyMemory = "historyMemory"

        // Phase 4a: Global Memory (3-Tier System)
        public static let globalMemory = "globalMemory"
        public static let globalMemoryEnabled = "globalMemoryEnabled"
        public static let globalMemoryLimit = "globalMemoryLimit"  // Character limit (500-2000)
        public static let powerModeStreamingEnabled = "powerModeStreamingEnabled"
        public static let transcriptionStreamingEnabled = "transcriptionStreamingEnabled"

        // Memory Update Tracking (batch memory updates)
        public static let lastGlobalMemoryUpdate = "lastGlobalMemoryUpdate"
        public static let lastContextMemoryUpdates = "lastContextMemoryUpdates"   // [UUID: Date]
        public static let lastPowerModeMemoryUpdates = "lastPowerModeMemoryUpdates" // [UUID: Date]

        // App Library: User app category overrides
        public static let userAppCategoryOverrides = "userAppCategoryOverrides"

        // Phase 4e: RAG Knowledge Documents
        public static let knowledgeDocuments = "knowledgeDocuments"

        // Phase 4f: Webhooks
        public static let webhooks = "webhooks"

        // Phase 6: Security & Privacy
        public static let biometricProtectionEnabled = "biometricProtectionEnabled"
        public static let dataRetentionPeriod = "dataRetentionPeriod"

        // Phase 10: Local Models & Provider Defaults
        public static let whisperKitConfig = "whisperKitConfig"
        public static let appleIntelligenceConfig = "appleIntelligenceConfig"
        public static let appleTranslationConfig = "appleTranslationConfig"
        public static let providerDefaults = "providerDefaults"
        public static let forcePrivacyMode = "forcePrivacyMode"

        // Phase 13.8: Swipe Typing
        public static let swipeTypingEnabled = "swipeTypingEnabled"

        // Phase 16: Keyboard Layout Settings
        public static let keyboardShowSwiftSpeakBar = "keyboardShowSwiftSpeakBar"
        public static let keyboardShowPredictionRow = "keyboardShowPredictionRow"
        public static let keyboardProgrammableAction = "keyboardProgrammableAction"
        public static let keyboardShowProgrammableNextToReturn = "keyboardShowProgrammableNextToReturn"
        public static let keyboardReturnProgrammableAction = "keyboardReturnProgrammableAction"
        public static let keyboardQuickActions = "keyboardQuickActions"

        // SwiftLink: Background Dictation Sessions
        public static let swiftLinkApps = "swiftLinkApps"
        public static let swiftLinkSessionDuration = "swiftLinkSessionDuration"
        public static let swiftLinkLastUsedApp = "swiftLinkLastUsedApp"
        public static let swiftLinkSessionActive = "swiftLinkSessionActive"
        /// Auto-start SwiftLink when using voice input (enabled by default)
        public static let swiftLinkAutoStart = "swiftLinkAutoStart"
        public static let swiftLinkSessionStartTime = "swiftLinkSessionStartTime"
        public static let swiftLinkDictationStartTime = "swiftLinkDictationStartTime"
        public static let swiftLinkDictationEndTime = "swiftLinkDictationEndTime"
        public static let swiftLinkTranscriptionResult = "swiftLinkTranscriptionResult"
        public static let swiftLinkProcessingStatus = "swiftLinkProcessingStatus"
        /// Live streaming transcript for real-time display in keyboard
        public static let swiftLinkStreamingTranscript = "swiftLinkStreamingTranscript"
        /// Real-time audio levels for waveform visualization (12 float values 0-1)
        public static let swiftLinkAudioLevels = "swiftLinkAudioLevels"

        // Widget state keys (for Lock Screen and Home Screen widgets)
        public static let swiftLinkWidgetIsRecording = "swiftLinkWidgetIsRecording"
        public static let swiftLinkWidgetSessionEndTime = "swiftLinkWidgetSessionEndTime"
        public static let swiftLinkWidgetTargetAppName = "swiftLinkWidgetTargetAppName"
        public static let swiftLinkWidgetTargetAppIcon = "swiftLinkWidgetTargetAppIcon"

        // Prediction Settings per Context
        /// Word autocomplete source for active context (WordAutocompleteSource rawValue: "system", "ai", "both", "disabled")
        public static let activeContextWordAutocompleteSource = "activeContextWordAutocompleteSource"
        /// Sentence predictions enabled for active context (Bool)
        public static let activeContextSentencePredictionsEnabled = "activeContextSentencePredictionsEnabled"
        /// Quick Actions for active context (JSON-encoded [QuickAction], nil = use global)
        public static let activeContextQuickActions = "activeContextQuickActions"

        // AI Word Prediction
        /// Current word/prefix being typed for AI prediction
        public static let aiWordPredictionPrefix = "aiWordPredictionPrefix"
        /// Full text context for AI prediction
        public static let aiWordPredictionContext = "aiWordPredictionContext"
        /// Active context name for AI prediction
        public static let aiWordPredictionContextName = "aiWordPredictionContextName"
        /// Language for AI prediction
        public static let aiWordPredictionLanguage = "aiWordPredictionLanguage"
        /// AI prediction results (JSON array of strings)
        public static let aiWordPredictionResults = "aiWordPredictionResults"
        /// Whether AI prediction is in progress
        public static let aiWordPredictionIsProcessing = "aiWordPredictionIsProcessing"
        /// Error message if AI prediction fails
        public static let aiWordPredictionError = "aiWordPredictionError"
        /// Timestamp of last AI prediction request (for debouncing)
        public static let aiWordPredictionTimestamp = "aiWordPredictionTimestamp"
    }

    // MARK: - API Endpoints
    public enum API {
        // OpenAI
        public static let openAIWhisper = "https://api.openai.com/v1/audio/transcriptions"
        public static let openAIChat = "https://api.openai.com/v1/chat/completions"

        // Anthropic
        public static let anthropic = "https://api.anthropic.com/v1/messages"

        // ElevenLabs
        public static let elevenLabs = "https://api.elevenlabs.io/v1/speech-to-text"

        // Deepgram
        public static let deepgram = "https://api.deepgram.com/v1/listen"

        // AssemblyAI
        public static let assemblyAIUpload = "https://api.assemblyai.com/v2/upload"
        public static let assemblyAITranscript = "https://api.assemblyai.com/v2/transcript"

        // Google Cloud
        public static let googleSTT = "https://speech.googleapis.com/v2/projects"
        public static let googleTranslation = "https://translation.googleapis.com/language/translate/v2"
        public static let gemini = "https://generativelanguage.googleapis.com/v1beta/models"

        // DeepL
        public static let deepL = "https://api.deepl.com/v2/translate"
        public static let deepLFree = "https://api-free.deepl.com/v2/translate"

        // Azure
        public static let azureTranslator = "https://api.cognitive.microsofttranslator.com/translate"
    }

    // MARK: - URL Scheme Hosts
    public enum URLHosts {
        public static let record = "record"
        public static let edit = "edit"
        public static let powermode = "powermode"
        public static let swiftlink = "swiftlink"
        public static let swiftlinkEnd = "swiftlink-end"
        public static let swiftlinkToggle = "swiftlink-toggle"
        public static let setup = "setup"
        public static let pending = "pending"
        public static let share = "share"  // Share Extension import
    }

    // MARK: - Share Extension
    public enum ShareExtension {
        /// Directory in App Group container for shared audio files
        public static let sharedAudioDirectory = "shared_audio"
        /// Key for pending share audio file ID in UserDefaults
        public static let pendingShareKey = "pendingShareAudioId"
        /// Key for original filename of shared audio
        public static let originalFilenameKey = "shareOriginalFilename"
        /// Key for share timestamp
        public static let timestampKey = "shareTimestamp"
        /// Bundle ID for Share Extension
        public static let bundleId = "pawelgawliczek.SwiftSpeak.SwiftSpeakShare"
    }

    // MARK: - SwiftLink Darwin Notifications
    public enum SwiftLinkNotifications {
        public static let prefix = "com.swiftspeak.swiftlink."
        public static let startDictation = prefix + "startDictation"
        public static let stopDictation = prefix + "stopDictation"
        public static let resultReady = prefix + "resultReady"
        public static let sessionStarted = prefix + "sessionStarted"
        public static let sessionEnded = prefix + "sessionEnded"

        // Phase 12: Edit Text via SwiftLink
        public static let startEdit = prefix + "startEdit"
        public static let editResultReady = prefix + "editResultReady"

        // Streaming transcription updates
        public static let streamingUpdate = prefix + "streamingUpdate"

        // Phase 13.12: AI Sentence Prediction
        public static let requestSentencePrediction = prefix + "requestSentencePrediction"
        public static let sentencePredictionReady = prefix + "sentencePredictionReady"
    }

    // MARK: - AI Sentence Prediction (Phase 13.12)
    public enum SentencePrediction {
        /// Key for storing typing context for prediction
        public static let context = "sentencePredictionContext"
        /// Key for storing active context name
        public static let activeContextName = "sentencePredictionActiveContextName"
        /// Key for storing active context ID
        public static let activeContextId = "sentencePredictionActiveContextId"
        /// Key for storing prediction results (JSON array of 4 sentences)
        public static let results = "sentencePredictionResults"
        /// Key for storing QuickSuggestions (JSON array, used when Quick Actions are enabled)
        public static let quickSuggestions = "sentencePredictionQuickSuggestions"
        /// Key for storing error message if prediction fails
        public static let error = "sentencePredictionError"
        /// Key for tracking if prediction is in progress
        public static let isProcessing = "sentencePredictionIsProcessing"
        /// Key for storing source app URL scheme for auto-return
        public static let sourceAppURLScheme = "sentencePredictionSourceAppURLScheme"
        /// Key for requesting auto-return after prediction
        public static let autoReturnRequested = "sentencePredictionAutoReturnRequested"
    }

    // MARK: - AI Word Prediction Darwin Notifications
    public enum AIWordPredictionNotifications {
        public static let prefix = "com.swiftspeak.aiword."
        /// Request AI word prediction from keyboard
        public static let requestPrediction = prefix + "requestPrediction"
        /// AI word prediction result ready
        public static let predictionReady = prefix + "predictionReady"
    }

    // MARK: - App Groups Keys for Edit Mode (Phase 12)
    public enum EditMode {
        /// Key for storing original text to edit (in App Groups UserDefaults)
        public static let pendingEditText = "pendingEditText"
        /// Key for storing original text during SwiftLink edit
        public static let swiftLinkEditOriginalText = "swiftLinkEditOriginalText"
        /// Key for tracking if last result was an edit (for keyboard to know to clear field first)
        public static let lastResultWasEdit = "lastResultWasEdit"
    }

    // MARK: - Record Flow (SwiftLink Auto-Start)
    public enum Record {
        /// Key for storing source app URL scheme for auto-return after SwiftLink setup
        public static let sourceAppURLScheme = "recordSourceAppURLScheme"
        /// Key for storing source app name for logging
        public static let sourceAppName = "recordSourceAppName"
        /// Key for storing source app bundle ID
        public static let sourceAppBundleId = "recordSourceAppBundleId"
    }

    // MARK: - AI Context Processing (Phase 13.11)
    public enum AIProcess {
        /// Key for storing text to process
        public static let pendingText = "aiProcessPendingText"
        /// Key for storing context ID
        public static let contextId = "aiProcessContextId"
        /// Key for storing power mode ID (alternative to context)
        public static let powerModeId = "aiProcessPowerModeId"
        /// Key for storing result
        public static let result = "aiProcessResult"
        /// Key for storing status ("processing", "complete", "error")
        public static let status = "aiProcessStatus"
        /// Key for storing source app URL scheme for auto-return
        public static let sourceAppURLScheme = "aiProcessSourceAppURLScheme"
        /// Key for requesting auto-return after processing
        public static let autoReturnRequested = "aiProcessAutoReturnRequested"
        /// Key for requesting SwiftLink to be started along with AI process
        public static let startSwiftLinkWithProcess = "aiProcessStartSwiftLink"
        /// Key for requesting translation (when no context, just translate)
        public static let translateEnabled = "aiProcessTranslateEnabled"
        /// Key for storing target language for translation
        public static let targetLanguage = "aiProcessTargetLanguage"
        /// Darwin notification name for starting AI process (keyboard -> app)
        public static let startProcess = "swiftspeak.aiprocess.startProcess"
        /// Darwin notification name for result ready (app -> keyboard)
        public static let resultReady = "swiftspeak.aiprocess.resultReady"
    }

    // MARK: - SwiftLink Session Duration
    public enum SwiftLinkSessionDuration: Int, CaseIterable, Codable {
        case fiveMinutes = 300
        case fifteenMinutes = 900
        case oneHour = 3600
        case never = 0  // 0 means never auto-end

        public var displayName: String {
            switch self {
            case .fiveMinutes: return "5 minutes"
            case .fifteenMinutes: return "15 minutes"
            case .oneHour: return "1 hour"
            case .never: return "Never (manual)"
            }
        }

        public var timeInterval: TimeInterval? {
            self == .never ? nil : TimeInterval(rawValue)
        }
    }

    // MARK: - Unified Keyboard Action (Phase 13 Refactor)
    /// Unified system for all keyboard-to-app actions
    public enum KeyboardActionKeys {
        /// Current action being processed (JSON-encoded KeyboardAction)
        public static let currentAction = "keyboardCurrentAction"
        /// Status of the current action (KeyboardActionStatus rawValue)
        public static let status = "keyboardActionStatus"
        /// Result of the action (KeyboardActionResult JSON)
        public static let result = "keyboardActionResult"
        /// Error message if action failed
        public static let error = "keyboardActionError"
        /// Timestamp when the action was last updated
        public static let lastUpdate = "keyboardActionLastUpdate"
    }

    /// Unified Darwin notifications for keyboard actions
    public enum KeyboardActionNotifications {
        public static let prefix = "swiftspeak.action."
        /// Keyboard requests an action to be processed
        public static let requestAction = prefix + "request"
        /// Main app acknowledges action received
        public static let actionAcknowledged = prefix + "acknowledged"
        /// Action status changed (processing, streaming, etc.)
        public static let statusChanged = prefix + "statusChanged"
        /// Action completed (success or error)
        public static let actionComplete = prefix + "complete"
        /// Streaming update available (for live transcription)
        public static let streamingUpdate = prefix + "streaming"
    }

    /// URL scheme for unified action entry point
    public enum UnifiedURL {
        /// Single entry point: swiftspeak://action
        public static let host = "action"
        /// Full URL (action details come from App Groups)
        public static var url: URL? { URL(string: "swiftspeak://action") }
    }

    // MARK: - Phase 11j: Audio Validation
    public enum AudioValidation {
        /// Minimum recording duration (seconds) - below this produces garbage
        public static let minDuration: TimeInterval = 0.5

        /// Maximum recording duration (seconds) - providers may timeout
        public static let maxDuration: TimeInterval = 600  // 10 minutes

        /// Warning threshold for long recordings (seconds)
        public static let warnDuration: TimeInterval = 300  // 5 minutes

        /// Maximum file size (bytes) for upload
        public static let maxFileSize: Int64 = 25 * 1024 * 1024  // 25 MB

        /// Validation result - simple type usable by both app and keyboard extension
        public enum ValidationResult: Equatable {
            case valid
            case tooShort(duration: TimeInterval)
            case tooLong(duration: TimeInterval)
            case fileTooLarge(sizeMB: Double, maxSizeMB: Double)
        }

        /// Validate duration is within acceptable range
        public static func validateDuration(_ duration: TimeInterval) -> ValidationResult {
            if duration < minDuration {
                return .tooShort(duration: duration)
            }
            if duration > maxDuration {
                return .tooLong(duration: duration)
            }
            return .valid
        }

        /// Validate file size
        public static func validateFileSize(_ bytes: Int64) -> ValidationResult {
            if bytes > maxFileSize {
                let sizeMB = Double(bytes) / (1024 * 1024)
                let maxMB = Double(maxFileSize) / (1024 * 1024)
                return .fileTooLarge(sizeMB: sizeMB, maxSizeMB: maxMB)
            }
            return .valid
        }

        /// Check if duration warrants a warning (long but not error)
        public static func shouldWarnDuration(_ duration: TimeInterval) -> Bool {
            duration > warnDuration && duration <= maxDuration
        }
    }
}
