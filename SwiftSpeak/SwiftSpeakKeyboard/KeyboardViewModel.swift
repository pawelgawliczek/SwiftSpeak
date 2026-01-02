//
//  KeyboardViewModel.swift
//  SwiftSpeakKeyboard
//
//  Extracted from KeyboardView.swift for better organization
//

import SwiftUI
import UIKit
import Combine

// MARK: - ViewModel
class KeyboardViewModel: ObservableObject {
    @Published var selectedMode: FormattingMode = .raw
    @Published var selectedCustomTemplateId: UUID?
    @Published var selectedLanguage: Language = .spanish
    @Published var isTranslationEnabled: Bool = false
    @Published var lastTranscription: String?
    @Published var isPro: Bool = false
    @Published var isPower: Bool = false
    @Published var powerModes: [KeyboardPowerMode] = []
    @Published var customTemplates: [KeyboardCustomTemplate] = []
    @Published var transcriptionProvider: KeyboardAIProviderInfo?
    @Published var contexts: [KeyboardContext] = []
    @Published var activeContext: KeyboardContext?
    @Published var processingStatus: KeyboardProcessingStatus = KeyboardProcessingStatus()
    @Published var pendingAudioCount: Int = 0

    // SwiftLink state
    @Published var isSwiftLinkSessionActive: Bool = false
    @Published var isSwiftLinkRecording: Bool = false
    @Published var swiftLinkProcessingStatus: String = ""
    @Published var swiftLinkApps: [KeyboardSwiftLinkApp] = []
    /// Whether SwiftLink is currently streaming (live transcription)
    @Published var isSwiftLinkStreaming: Bool = false
    /// Live streaming transcript from SwiftLink
    @Published var swiftLinkStreamingTranscript: String = ""
    /// Flag to prevent streaming updates from overwriting "processing" status after stop
    private var isWaitingForResult: Bool = false
    /// Real-time audio levels for waveform visualization
    @Published var swiftLinkAudioLevels: [Float] = []
    /// Recording duration for display
    @Published var swiftLinkRecordingDuration: TimeInterval = 0
    /// Timer for reading audio levels from App Groups
    private var audioLevelReadTimer: Timer?
    /// Recording start time for duration calculation
    private var recordingStartTime: Date?

    // Edit Mode Toggle (long press to switch between transcription and edit)
    @Published var isEditModeEnabled: Bool = false

    // Phase 13.6: AI Predictions
    /// Current typing context for predictions
    @Published var currentTypingContext: String = ""

    // Phase 13.9: Emoji Panel
    @Published var showEmojiPanel = false

    // Phase 13.10: Quick Settings Popover
    @Published var showQuickSettings = false

    // Phase 13.11: AI Context Processing
    @Published var isAIProcessing = false

    // Phase 13.12: AI Sentence Prediction
    @Published var showSentencePredictionPanel = false
    @Published var sentencePredictions: [String] = []
    @Published var isLoadingSentencePredictions = false
    @Published var sentencePredictionError: String?

    // Phase 13: Undo Stack (Gboard-style, AI-aware)
    @Published var undoStack: [UndoItem] = []  // Stack of undoable operations
    private let maxUndoItems = 10

    // Phase 13: Clipboard Panel
    @Published var showClipboardPanel = false
    @Published var clipboardItems: [ClipboardItem] = []
    @Published var pinnedClipboardItems: [ClipboardItem] = []

    weak var textDocumentProxy: UITextDocumentProxy?
    weak var hostViewController: UIViewController?

    private let darwinManager = DarwinNotificationManager.shared

    // SwiftLink timeout handling
    private var swiftLinkTimeoutTimer: Timer?
    private var swiftLinkStatusCheckTimer: Timer?
    private static let swiftLinkTimeoutSeconds: TimeInterval = 30.0  // 30 seconds to allow transcription to complete
    private static let swiftLinkMaxSessionAge: TimeInterval = 600.0  // 10 minutes max session age
    private static let swiftLinkStatusCheckInterval: TimeInterval = 30.0  // Check every 30 seconds

    /// Returns true if there's any text in the current text field
    var hasTextInField: Bool {
        guard let proxy = textDocumentProxy else { return false }
        let before = proxy.documentContextBeforeInput ?? ""
        let after = proxy.documentContextAfterInput ?? ""
        return !before.isEmpty || !after.isEmpty
    }

    /// Returns the existing text in the text field (Phase 12)
    var existingTextInField: String? {
        guard let proxy = textDocumentProxy else { return nil }
        let before = proxy.documentContextBeforeInput ?? ""
        let after = proxy.documentContextAfterInput ?? ""
        let combined = before + after
        return combined.isEmpty ? nil : combined
    }

    init() {
        loadSettings()
        setupSwiftLinkObservers()
    }

    private func setupSwiftLinkObservers() {
        // Check initial SwiftLink session state
        keyboardLog("Setting up SwiftLink observers", category: "SwiftLink")
        checkSwiftLinkSession()
        keyboardLog("Initial SwiftLink state: \(isSwiftLinkSessionActive)", category: "SwiftLink")

        // Observe session started
        darwinManager.observeSessionStarted { [weak self] in
            DispatchQueue.main.async {
                keyboardLog("Darwin: Session started notification received", category: "SwiftLink")
                self?.isSwiftLinkSessionActive = true
                self?.checkSwiftLinkSession()
            }
        }

        // Observe session ended
        darwinManager.observeSessionEnded { [weak self] in
            DispatchQueue.main.async {
                self?.isSwiftLinkSessionActive = false
                self?.isSwiftLinkRecording = false
                keyboardLog("SwiftLink session ended notification received", category: "SwiftLink")
            }
        }

        // Observe result ready
        darwinManager.observeResultReady { [weak self] in
            DispatchQueue.main.async {
                self?.handleSwiftLinkResult()
            }
        }

        // Observe streaming updates
        darwinManager.observeStreamingUpdate { [weak self] in
            DispatchQueue.main.async {
                self?.handleStreamingUpdate()
            }
        }
    }

    /// Handle streaming transcript update from main app
    private func handleStreamingUpdate() {
        // Cancel timeout - we're receiving streaming updates, so main app is responsive
        cancelSwiftLinkTimeout()

        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        defaults?.synchronize()

        let status = defaults?.string(forKey: Constants.Keys.swiftLinkProcessingStatus) ?? ""
        let transcript = defaults?.string(forKey: Constants.Keys.swiftLinkStreamingTranscript) ?? ""

        // If we're waiting for the final result, DON'T let streaming updates
        // overwrite the "processing" status - just update the transcript for display
        if isWaitingForResult {
            // Still update transcript for display but keep status as "processing"
            if !transcript.isEmpty && transcript != swiftLinkStreamingTranscript {
                swiftLinkStreamingTranscript = transcript
                keyboardLog("Streaming transcript (waiting): \(transcript.count) chars", category: "SwiftLink")
            }
            // Keep swiftLinkProcessingStatus as "processing"
            return
        }

        if status == "streaming" {
            // Only log when transcript actually changes
            if transcript != swiftLinkStreamingTranscript {
                keyboardLog("Streaming transcript: \(transcript.count) chars", category: "SwiftLink")
            }
            isSwiftLinkStreaming = true
            swiftLinkStreamingTranscript = transcript
            swiftLinkProcessingStatus = "streaming"
        } else if status == "processing" {
            // Processing started - keep overlay visible with processing state
            keyboardLog("Streaming update: now processing", category: "SwiftLink")
            isSwiftLinkStreaming = false
            swiftLinkProcessingStatus = "processing"  // Sync local state with main app
        } else {
            // Streaming ended (unknown status)
            if isSwiftLinkStreaming {
                keyboardLog("Streaming ended (status: \(status))", category: "SwiftLink")
            }
            isSwiftLinkStreaming = false
            // Keep current swiftLinkProcessingStatus to avoid hiding overlay prematurely
        }
    }

    private func checkSwiftLinkSession() {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        // Force sync to get latest data from main app
        defaults?.synchronize()
        let wasActive = isSwiftLinkSessionActive
        isSwiftLinkSessionActive = defaults?.bool(forKey: Constants.Keys.swiftLinkSessionActive) ?? false
        if wasActive != isSwiftLinkSessionActive {
            keyboardLog("SwiftLink session state changed: \(wasActive) -> \(isSwiftLinkSessionActive)", category: "SwiftLink")
        }
    }

    private func handleSwiftLinkResult() {
        // Cancel any pending timeout - we got a response
        cancelSwiftLinkTimeout()

        // Clear the waiting flag - we got the result
        isWaitingForResult = false

        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        // Force sync to ensure we have latest data from main app
        defaults?.synchronize()

        let status = defaults?.string(forKey: Constants.Keys.swiftLinkProcessingStatus) ?? ""
        let wasEdit = defaults?.bool(forKey: Constants.EditMode.lastResultWasEdit) ?? false

        keyboardLog("SwiftLink result received (status: \(status), wasEdit: \(wasEdit))", category: "SwiftLink")

        // DON'T update swiftLinkProcessingStatus yet - keep showing "processing" overlay
        // until text is inserted (better UX - no jarring disappearance)
        isSwiftLinkRecording = false

        if status == "complete", let result = defaults?.string(forKey: Constants.Keys.swiftLinkTranscriptionResult) {
            keyboardLog("SwiftLink result received (\(result.count) chars, edit: \(wasEdit))", category: "SwiftLink")

            // Phase 12: If this was an edit, clear existing text first
            if wasEdit {
                keyboardLog("Clearing existing text for edit replacement", category: "SwiftLink")
                deleteAllTextInField()
            }

            // Insert the result - verify proxy is available
            if let proxy = textDocumentProxy {
                keyboardLog("Inserting result text via proxy", category: "SwiftLink")
                proxy.insertText(result)
                keyboardLog("Text insertion completed: '\(result.prefix(30))...'", category: "SwiftLink")
            } else {
                keyboardLog("ERROR: textDocumentProxy is nil, cannot insert text!", category: "SwiftLink", level: .error)
                // Try to copy to clipboard as fallback
                UIPasteboard.general.string = result
                keyboardLog("Copied result to clipboard as fallback", category: "SwiftLink")
            }

            // NOW show "complete" state briefly, then clear
            swiftLinkProcessingStatus = "complete"
            isSwiftLinkStreaming = false
            swiftLinkStreamingTranscript = ""

            // Clear the result and edit flag from App Groups
            defaults?.removeObject(forKey: Constants.Keys.swiftLinkTranscriptionResult)
            defaults?.removeObject(forKey: Constants.Keys.swiftLinkProcessingStatus)
            defaults?.removeObject(forKey: Constants.EditMode.lastResultWasEdit)
            defaults?.removeObject(forKey: Constants.EditMode.swiftLinkEditOriginalText)
            defaults?.synchronize()

            // Update last transcription
            lastTranscription = result

            // Auto-dismiss "complete" overlay after a brief moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self = self else { return }
                // Only clear if still in complete state (user hasn't started new recording)
                if self.swiftLinkProcessingStatus == "complete" {
                    self.swiftLinkProcessingStatus = ""
                    keyboardLog("SwiftLink overlay auto-dismissed", category: "SwiftLink")
                }
            }
        } else if status == "error" {
            let errorMsg = defaults?.string(forKey: Constants.Keys.swiftLinkTranscriptionResult) ?? "Unknown error"
            keyboardLog("SwiftLink error: \(errorMsg)", category: "SwiftLink", level: .error)

            // Clear streaming state on error
            isSwiftLinkStreaming = false
            swiftLinkStreamingTranscript = ""

            // Check if session expired - mark SwiftLink as inactive and fall back to app
            if errorMsg.contains("expired") || errorMsg.contains("not active") || errorMsg.contains("Session") {
                keyboardLog("SwiftLink session is invalid - marking as inactive", category: "SwiftLink", level: .warning)
                isSwiftLinkSessionActive = false

                // Clear the stale session flag in App Groups
                defaults?.set(false, forKey: Constants.Keys.swiftLinkSessionActive)
            }

            // Clear error state
            defaults?.removeObject(forKey: Constants.Keys.swiftLinkTranscriptionResult)
            defaults?.removeObject(forKey: Constants.Keys.swiftLinkProcessingStatus)
            defaults?.removeObject(forKey: Constants.EditMode.lastResultWasEdit)
            defaults?.removeObject(forKey: Constants.EditMode.swiftLinkEditOriginalText)
            defaults?.synchronize()
        } else {
            // Status not recognized - don't clear streaming state yet, wait for proper result
            keyboardLog("SwiftLink result not ready yet (status: '\(status)')", category: "SwiftLink", level: .warning)
        }
    }

    /// Delete all text in the current text field (Phase 12: for edit mode replacement)
    private func deleteAllTextInField() {
        guard let proxy = textDocumentProxy else {
            keyboardLog("No textDocumentProxy available for deletion", category: "Action", level: .error)
            return
        }

        var totalDeleted = 0
        var iterations = 0
        let maxIterations = 100  // Safety limit

        // Keep deleting until no more text is available
        // documentContextBeforeInput/AfterInput only return a limited window,
        // so we need to loop until all text is deleted
        while iterations < maxIterations {
            // Get current text context
            let beforeText = proxy.documentContextBeforeInput ?? ""
            let afterText = proxy.documentContextAfterInput ?? ""
            let beforeCount = beforeText.count
            let afterCount = afterText.count

            if beforeCount == 0 && afterCount == 0 {
                break  // All text deleted
            }

            // Move to end of available text first
            if afterCount > 0 {
                proxy.adjustTextPosition(byCharacterOffset: afterCount)
            }

            // Delete all text before cursor
            let currentBefore = (proxy.documentContextBeforeInput ?? "").count
            if currentBefore > 0 {
                for _ in 0..<currentBefore {
                    proxy.deleteBackward()
                }
                totalDeleted += currentBefore
            }

            iterations += 1
        }

        keyboardLog("Deleted \(totalDeleted) chars in \(iterations) iterations for edit replacement", category: "Action")
    }

    /// Public method to clear all text in the field
    func clearAllText() {
        KeyboardHaptics.mediumTap()
        deleteAllTextInField()
        // Force view to re-check hasTextInField by sending objectWillChange
        objectWillChange.send()
    }

    func toggleSwiftLinkRecording() {
        if isSwiftLinkRecording {
            stopSwiftLinkRecording()
        } else {
            // Start recording
            isSwiftLinkRecording = true
            isWaitingForResult = false  // Clear any stale waiting state
            swiftLinkAudioLevels = []
            darwinManager.postDictationStart()
            swiftLinkProcessingStatus = "recording"
            startAudioLevelReading()  // This sets recordingStartTime and duration
            // NOTE: Don't start timeout during recording - user may record for longer than 5 seconds
            // Timeout will start when we STOP recording and wait for processing result
            keyboardLog("SwiftLink dictation started", category: "SwiftLink")
        }
    }

    /// Stop SwiftLink recording and trigger processing
    func stopSwiftLinkRecording() {
        guard isSwiftLinkRecording || isSwiftLinkStreaming else { return }

        isSwiftLinkRecording = false
        isSwiftLinkStreaming = false
        isWaitingForResult = true  // Prevent streaming updates from overwriting processing status
        stopAudioLevelReading()
        cancelSwiftLinkTimeout()
        darwinManager.postDictationStop()
        swiftLinkProcessingStatus = "processing"
        startSwiftLinkTimeout()  // Start timeout for processing phase
        keyboardLog("SwiftLink dictation stopped, waiting for result", category: "SwiftLink")
    }

    // MARK: - Audio Level Reading

    /// Start reading audio levels from App Groups for waveform visualization
    private func startAudioLevelReading() {
        stopAudioLevelReading()  // Clear any existing timer

        // Set recording start time for duration calculation
        recordingStartTime = Date()
        swiftLinkRecordingDuration = 0

        // Create timer on main run loop for UI updates
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.readAudioLevels()
        }
        RunLoop.main.add(timer, forMode: .common)
        audioLevelReadTimer = timer
    }

    /// Stop reading audio levels
    private func stopAudioLevelReading() {
        audioLevelReadTimer?.invalidate()
        audioLevelReadTimer = nil
        // Don't reset recordingStartTime here - keep final duration visible
    }

    /// Read audio levels from App Groups
    private func readAudioLevels() {
        // Update recording duration
        if let startTime = recordingStartTime {
            swiftLinkRecordingDuration = Date().timeIntervalSince(startTime)
        }

        // Read audio levels from App Groups
        guard let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier) else { return }
        defaults.synchronize()

        if let data = defaults.data(forKey: Constants.Keys.swiftLinkAudioLevels),
           let levels = try? JSONDecoder().decode([Float].self, from: data) {
            swiftLinkAudioLevels = levels
        }
    }

    // MARK: - SwiftLink Timeout Handling

    private func startSwiftLinkTimeout() {
        cancelSwiftLinkTimeout()

        keyboardLog("SwiftLink timeout started (\(Self.swiftLinkTimeoutSeconds)s)", category: "SwiftLink")

        swiftLinkTimeoutTimer = Timer.scheduledTimer(withTimeInterval: Self.swiftLinkTimeoutSeconds, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleSwiftLinkTimeout()
            }
        }
    }

    private func cancelSwiftLinkTimeout() {
        if swiftLinkTimeoutTimer != nil {
            keyboardLog("SwiftLink timeout cancelled", category: "SwiftLink")
        }
        swiftLinkTimeoutTimer?.invalidate()
        swiftLinkTimeoutTimer = nil
    }

    private func handleSwiftLinkTimeout() {
        keyboardLog("SwiftLink TIMEOUT - no response from main app after \(Self.swiftLinkTimeoutSeconds)s", category: "SwiftLink", level: .warning)
        keyboardLog("Session state before timeout: active=\(isSwiftLinkSessionActive), recording=\(isSwiftLinkRecording)", category: "SwiftLink", level: .warning)

        // Mark session as inactive
        markSwiftLinkAsStale(reason: "Timeout - no response from main app")
    }

    /// Verify SwiftLink session is still valid before using it.
    /// Returns true if session is valid, false if stale (and marks it inactive).
    private func verifySwiftLinkSession() -> Bool {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        defaults?.synchronize()

        // Check if session is marked active
        guard defaults?.bool(forKey: Constants.Keys.swiftLinkSessionActive) == true else {
            keyboardLog("SwiftLink verify: session not marked active", category: "SwiftLink")
            isSwiftLinkSessionActive = false
            return false
        }

        // Check session start timestamp
        let sessionStartTime = defaults?.double(forKey: Constants.Keys.swiftLinkSessionStartTime) ?? 0
        guard sessionStartTime > 0 else {
            keyboardLog("SwiftLink verify: no session start timestamp", category: "SwiftLink", level: .warning)
            markSwiftLinkAsStale(reason: "No session timestamp")
            return false
        }

        // Check if session is too old
        let sessionAge = Date().timeIntervalSince1970 - sessionStartTime
        if sessionAge > Self.swiftLinkMaxSessionAge {
            keyboardLog("SwiftLink verify: session too old (\(Int(sessionAge))s > \(Int(Self.swiftLinkMaxSessionAge))s)", category: "SwiftLink", level: .warning)
            markSwiftLinkAsStale(reason: "Session expired (\(Int(sessionAge/60)) minutes old)")
            return false
        }

        keyboardLog("SwiftLink verify: session valid (age: \(Int(sessionAge))s)", category: "SwiftLink")
        return true
    }

    /// Mark SwiftLink session as stale and clean up
    private func markSwiftLinkAsStale(reason: String) {
        keyboardLog("SwiftLink marked as stale: \(reason)", category: "SwiftLink", level: .warning)

        isSwiftLinkSessionActive = false
        isSwiftLinkRecording = false
        isWaitingForResult = false
        swiftLinkProcessingStatus = ""

        // Clear the stale session flag in App Groups
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        defaults?.set(false, forKey: Constants.Keys.swiftLinkSessionActive)
        defaults?.removeObject(forKey: Constants.Keys.swiftLinkSessionStartTime)
        defaults?.removeObject(forKey: Constants.EditMode.swiftLinkEditOriginalText)
        defaults?.removeObject(forKey: Constants.EditMode.lastResultWasEdit)
        defaults?.synchronize()

        // Provide haptic feedback
        KeyboardHaptics.warning()
    }

    // MARK: - SwiftLink Periodic Status Check

    /// Start periodic SwiftLink status checks
    private func startSwiftLinkStatusChecks() {
        stopSwiftLinkStatusChecks()

        // Immediate check
        performSwiftLinkStatusCheck()

        // Schedule periodic checks
        swiftLinkStatusCheckTimer = Timer.scheduledTimer(withTimeInterval: Self.swiftLinkStatusCheckInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.performSwiftLinkStatusCheck()
            }
        }

        keyboardLog("SwiftLink status checks started (every \(Int(Self.swiftLinkStatusCheckInterval))s)", category: "SwiftLink")
    }

    /// Stop periodic SwiftLink status checks
    private func stopSwiftLinkStatusChecks() {
        swiftLinkStatusCheckTimer?.invalidate()
        swiftLinkStatusCheckTimer = nil
    }

    /// Perform a SwiftLink status check and update UI
    private func performSwiftLinkStatusCheck() {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        defaults?.synchronize()

        let wasActive = isSwiftLinkSessionActive

        // Check if session is still valid
        if defaults?.bool(forKey: Constants.Keys.swiftLinkSessionActive) == true {
            let sessionStartTime = defaults?.double(forKey: Constants.Keys.swiftLinkSessionStartTime) ?? 0

            if sessionStartTime > 0 {
                let sessionAge = Date().timeIntervalSince1970 - sessionStartTime

                if sessionAge > Self.swiftLinkMaxSessionAge {
                    // Session is too old
                    keyboardLog("SwiftLink status check: session expired (\(Int(sessionAge))s old)", category: "SwiftLink", level: .warning)
                    markSwiftLinkAsStale(reason: "Session expired during status check")
                } else {
                    // Session is valid
                    if !wasActive {
                        keyboardLog("SwiftLink status check: session now active (age: \(Int(sessionAge))s)", category: "SwiftLink")
                    }
                    isSwiftLinkSessionActive = true
                }
            } else {
                // No timestamp but marked active - stale
                if wasActive {
                    keyboardLog("SwiftLink status check: no timestamp, marking stale", category: "SwiftLink", level: .warning)
                    markSwiftLinkAsStale(reason: "No session timestamp")
                }
                isSwiftLinkSessionActive = false
            }
        } else {
            // Not marked active
            if wasActive {
                keyboardLog("SwiftLink status check: session no longer active", category: "SwiftLink")
            }
            isSwiftLinkSessionActive = false
        }
    }

    func checkAutoInsert() {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        defaults?.synchronize()

        if let data = defaults?.data(forKey: "processingStatus"),
           let status = try? JSONDecoder().decode(KeyboardProcessingStatus.self, from: data) {
            processingStatus = status

            if status.pendingAutoInsert, let text = status.lastCompletedText, !text.isEmpty {
                // Phase 12: Check if this was an edit mode result
                let wasEdit = defaults?.bool(forKey: Constants.EditMode.lastResultWasEdit) ?? false
                keyboardLog("Auto-inserting text (\(text.count) chars, edit: \(wasEdit))", category: "Action")

                // If edit mode, clear existing text first
                if wasEdit {
                    keyboardLog("Clearing existing text for edit replacement", category: "Action")
                    deleteAllTextInField()
                    // Clear the edit flag
                    defaults?.removeObject(forKey: Constants.EditMode.lastResultWasEdit)
                    defaults?.synchronize()
                }

                textDocumentProxy?.insertText(text)

                var updatedStatus = status
                updatedStatus.pendingAutoInsert = false
                updatedStatus.lastCompletedText = nil
                saveProcessingStatus(updatedStatus)
                processingStatus = updatedStatus

                // Auto-dismiss "Done" banner after 1 second
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.dismissStatus()
                }
            }
        }
    }

    private func saveProcessingStatus(_ status: KeyboardProcessingStatus) {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        if let data = try? JSONEncoder().encode(status) {
            defaults?.set(data, forKey: "processingStatus")
        }
    }

    func dismissError() {
        var updatedStatus = processingStatus
        updatedStatus.isProcessing = false
        updatedStatus.currentStep = "idle"
        updatedStatus.errorMessage = nil
        saveProcessingStatus(updatedStatus)
        processingStatus = updatedStatus
    }

    func dismissStatus() {
        var updatedStatus = processingStatus
        updatedStatus.isProcessing = false
        updatedStatus.currentStep = "idle"
        updatedStatus.errorMessage = nil
        saveProcessingStatus(updatedStatus)
        processingStatus = updatedStatus
        keyboardLog("Status banner auto-dismissed", category: "Action")
    }

    var modeOptions: [(icon: String, title: String, value: String)] {
        var options = FormattingMode.allCases.map { mode in
            (mode.icon, mode.displayName, mode.rawValue)
        }

        if isPro && !customTemplates.isEmpty {
            for template in customTemplates {
                options.append((template.icon, template.name, "custom:\(template.id.uuidString)"))
            }
        }

        return options
    }

    var currentModeDisplayName: String {
        if let templateId = selectedCustomTemplateId,
           let template = customTemplates.first(where: { $0.id == templateId }) {
            return template.name
        }
        return selectedMode.displayName
    }

    var currentModeIcon: String {
        if let templateId = selectedCustomTemplateId,
           let template = customTemplates.first(where: { $0.id == templateId }) {
            return template.icon
        }
        return selectedMode.icon
    }

    func loadSettings() {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        if let modeRaw = defaults?.string(forKey: Constants.Keys.selectedMode),
           let mode = FormattingMode(rawValue: modeRaw) {
            selectedMode = mode
        }

        if let langRaw = defaults?.string(forKey: Constants.Keys.selectedTargetLanguage),
           let lang = Language(rawValue: langRaw) {
            selectedLanguage = lang
        }

        lastTranscription = defaults?.string(forKey: Constants.Keys.lastTranscription)

        if let tierRaw = defaults?.string(forKey: Constants.Keys.subscriptionTier) {
            isPro = tierRaw == "pro" || tierRaw == "power"
            isPower = tierRaw == "power"
        }

        loadAIProviders(from: defaults)
        loadCustomTemplates(from: defaults)

        powerModes = [
            KeyboardPowerMode(id: UUID(), name: "Research", icon: "magnifyingglass"),
            KeyboardPowerMode(id: UUID(), name: "Email", icon: "envelope.fill"),
            KeyboardPowerMode(id: UUID(), name: "Planner", icon: "calendar"),
            KeyboardPowerMode(id: UUID(), name: "Ideas", icon: "lightbulb.fill")
        ]

        // Load contexts for all users (presets available to everyone)
        loadContexts(from: defaults)

        loadPendingAudioCount(from: defaults)
        loadSwiftLinkApps(from: defaults)

        // Refresh SwiftLink session state
        checkSwiftLinkSession()
    }

    private func loadSwiftLinkApps(from defaults: UserDefaults?) {
        guard let data = defaults?.data(forKey: Constants.Keys.swiftLinkApps) else {
            // Load default popular apps if none configured
            swiftLinkApps = defaultSwiftLinkApps
            return
        }

        do {
            let apps = try JSONDecoder().decode([KeyboardSwiftLinkApp].self, from: data)
            swiftLinkApps = apps.isEmpty ? defaultSwiftLinkApps : apps
        } catch {
            swiftLinkApps = defaultSwiftLinkApps
        }
    }

    private var defaultSwiftLinkApps: [KeyboardSwiftLinkApp] {
        [
            KeyboardSwiftLinkApp(bundleId: "net.whatsapp.WhatsApp", name: "WhatsApp", urlScheme: "whatsapp://", iconName: "message.fill"),
            KeyboardSwiftLinkApp(bundleId: "com.apple.MobileSMS", name: "Messages", urlScheme: "sms://", iconName: "message.fill"),
            KeyboardSwiftLinkApp(bundleId: "com.apple.mobilemail", name: "Mail", urlScheme: "mailto://", iconName: "envelope.fill"),
            KeyboardSwiftLinkApp(bundleId: "com.slack.Slack", name: "Slack", urlScheme: "slack://", iconName: "number"),
            KeyboardSwiftLinkApp(bundleId: "org.telegram.Telegram", name: "Telegram", urlScheme: "telegram://", iconName: "paperplane.fill"),
        ]
    }

    /// Called when keyboard appears to refresh all state
    func refreshState() {
        keyboardLog("Keyboard appeared - refreshing state", category: "Lifecycle")
        loadSettings()
        checkSwiftLinkSession()
        keyboardLog("After refresh - SwiftLink active: \(isSwiftLinkSessionActive)", category: "SwiftLink")
        startSwiftLinkStatusChecks()  // Start periodic status checks
    }

    /// Called when keyboard disappears to clean up
    func cleanup() {
        stopSwiftLinkStatusChecks()
        cancelSwiftLinkTimeout()
    }

    private func loadPendingAudioCount(from defaults: UserDefaults?) {
        guard let data = defaults?.data(forKey: "pendingAudioQueue") else {
            pendingAudioCount = 0
            return
        }

        struct SimplePendingAudio: Codable { let id: UUID }

        do {
            let queue = try JSONDecoder().decode([SimplePendingAudio].self, from: data)
            pendingAudioCount = queue.count
        } catch {
            pendingAudioCount = 0
        }
    }

    private func loadContexts(from defaults: UserDefaults?) {
        // Structure to decode full context from shared defaults
        struct FullContext: Codable {
            let id: UUID
            let name: String
            let icon: String
            let isPreset: Bool?
            let enterSendsMessage: Bool?
            let enterRunsContext: Bool?
            let aiAutocorrectEnabled: Bool?
        }

        // Try to load all contexts from shared defaults first
        var loadedContextMap: [UUID: FullContext] = [:]
        if let data = defaults?.data(forKey: Constants.Keys.contexts) {
            do {
                let loadedContexts = try JSONDecoder().decode([FullContext].self, from: data)
                for ctx in loadedContexts {
                    loadedContextMap[ctx.id] = ctx
                }
            } catch {
                // Failed to decode, will use defaults
            }
        }

        // Preset context IDs
        let workId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let personalId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let creativeId = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

        // Create preset contexts with settings from loaded data or defaults
        let presetContexts: [KeyboardContext] = [
            KeyboardContext(
                id: workId,
                name: "Work",
                icon: "💼",
                enterSendsMessage: loadedContextMap[workId]?.enterSendsMessage ?? true,
                enterRunsContext: loadedContextMap[workId]?.enterRunsContext ?? false,
                aiAutocorrectEnabled: loadedContextMap[workId]?.aiAutocorrectEnabled ?? true
            ),
            KeyboardContext(
                id: personalId,
                name: "Personal",
                icon: "😊",
                enterSendsMessage: loadedContextMap[personalId]?.enterSendsMessage ?? true,
                enterRunsContext: loadedContextMap[personalId]?.enterRunsContext ?? false,
                aiAutocorrectEnabled: loadedContextMap[personalId]?.aiAutocorrectEnabled ?? true
            ),
            KeyboardContext(
                id: creativeId,
                name: "Creative",
                icon: "✨",
                enterSendsMessage: loadedContextMap[creativeId]?.enterSendsMessage ?? true,
                enterRunsContext: loadedContextMap[creativeId]?.enterRunsContext ?? false,
                aiAutocorrectEnabled: loadedContextMap[creativeId]?.aiAutocorrectEnabled ?? false
            )
        ]

        // Load custom contexts from shared defaults
        let customContexts: [KeyboardContext] = loadedContextMap.values
            .filter { $0.isPreset != true }
            .map { ctx in
                KeyboardContext(
                    id: ctx.id,
                    name: ctx.name,
                    icon: ctx.icon,
                    enterSendsMessage: ctx.enterSendsMessage ?? true,
                    enterRunsContext: ctx.enterRunsContext ?? false,
                    aiAutocorrectEnabled: ctx.aiAutocorrectEnabled ?? false
                )
            }

        // Combine presets + custom
        contexts = presetContexts + customContexts

        // Set active context if one is selected
        if let activeIdString = defaults?.string(forKey: Constants.Keys.activeContextId),
           let activeId = UUID(uuidString: activeIdString),
           let context = contexts.first(where: { $0.id == activeId }) {
            activeContext = context
        } else {
            activeContext = nil
        }
    }

    func selectContext(_ context: KeyboardContext?) {
        activeContext = context
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        if let context = context {
            defaults?.set(context.id.uuidString, forKey: Constants.Keys.activeContextId)
        } else {
            defaults?.removeObject(forKey: Constants.Keys.activeContextId)
        }
    }

    private func loadCustomTemplates(from defaults: UserDefaults?) {
        guard isPro, let data = defaults?.data(forKey: Constants.Keys.customTemplates) else {
            customTemplates = []
            return
        }

        struct SimpleCustomTemplate: Codable {
            let id: UUID
            let name: String
            let icon: String
        }

        do {
            let templates = try JSONDecoder().decode([SimpleCustomTemplate].self, from: data)
            customTemplates = templates.map { KeyboardCustomTemplate(id: $0.id, name: $0.name, icon: $0.icon) }
        } catch {
            customTemplates = []
        }
    }

    private func loadAIProviders(from defaults: UserDefaults?) {
        guard let data = defaults?.data(forKey: Constants.Keys.configuredAIProviders) else {
            transcriptionProvider = nil
            return
        }

        struct SimpleAIProviderConfig: Codable {
            let provider: String
            let apiKey: String
            let transcriptionModel: String?
            let usageCategories: [String]
        }

        do {
            let configs = try JSONDecoder().decode([SimpleAIProviderConfig].self, from: data)

            if let config = configs.first(where: { $0.usageCategories.contains("transcription") }) {
                transcriptionProvider = KeyboardAIProviderInfo(
                    name: config.provider.capitalized,
                    model: config.transcriptionModel,
                    isConfigured: !config.apiKey.isEmpty
                )
            } else {
                transcriptionProvider = nil
            }
        } catch {
            transcriptionProvider = nil
        }
    }

    var isProviderConfigured: Bool {
        transcriptionProvider?.isConfigured == true
    }

    func saveSettings() {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        defaults?.set(selectedMode.rawValue, forKey: Constants.Keys.selectedMode)
        defaults?.set(selectedLanguage.rawValue, forKey: Constants.Keys.selectedTargetLanguage)
    }

    func selectMode(value: String) {
        if value.hasPrefix("custom:") {
            let uuidString = String(value.dropFirst(7))
            if let uuid = UUID(uuidString: uuidString) {
                selectedCustomTemplateId = uuid
                selectedMode = .raw
            }
        } else {
            selectedCustomTemplateId = nil
            if let mode = FormattingMode(rawValue: value) {
                selectedMode = mode
            }
        }
    }

    /// Toggle between transcription and edit mode (called on long press)
    func toggleEditMode() {
        guard isPro else {
            keyboardLog("Edit mode requires Pro subscription", category: "Action")
            return
        }

        isEditModeEnabled.toggle()
        KeyboardHaptics.mediumTap()
        keyboardLog("Edit mode toggled: \(isEditModeEnabled)", category: "Action")
    }

    func startTranscription() {
        // If no provider configured, open setup instead
        guard isProviderConfigured else {
            keyboardLog("No provider configured, opening setup", category: "Action")
            if let url = URL(string: "swiftspeak://setup") {
                openURL(url)
            }
            return
        }

        // Edit mode is based on toggle (long press) and Pro status
        // Also requires text in field for edit to make sense
        let isEditMode = isEditModeEnabled && isPro && hasTextInField

        if isEditModeEnabled && !isPro {
            keyboardLog("Edit mode requires Pro - using normal transcription", category: "Action")
        } else if isEditModeEnabled && !hasTextInField {
            keyboardLog("Edit mode enabled but no text in field - using normal transcription", category: "Action")
        }

        // Check for active SwiftLink session - use inline dictation
        if isSwiftLinkSessionActive {
            // If already recording, stop it (regardless of edit mode)
            if isSwiftLinkRecording {
                keyboardLog("Stopping SwiftLink recording", category: "SwiftLink")
                toggleSwiftLinkRecording()
                return
            }

            // Verify session is still valid before starting new recording
            guard verifySwiftLinkSession() else {
                keyboardLog("SwiftLink session invalid - falling back to app workflow", category: "SwiftLink", level: .warning)
                // Session is stale, continue to normal app workflow below
                saveSettings()
                startNormalTranscription(isEditMode: isEditMode)
                return
            }

            // Start new recording
            if isEditMode {
                keyboardLog("Using SwiftLink inline edit mode", category: "SwiftLink")
                startSwiftLinkEdit()
            } else {
                keyboardLog("Using SwiftLink inline dictation", category: "SwiftLink")
                toggleSwiftLinkRecording()
            }
            return
        }

        saveSettings()
        startNormalTranscription(isEditMode: isEditMode)
    }

    /// Start normal transcription flow via main app (non-SwiftLink)
    private func startNormalTranscription(isEditMode: Bool) {
        // Phase 12: Edit mode via URL scheme
        if isEditMode {
            startEditModeViaURL()
            return
        }

        // Normal transcription flow
        let translate = isTranslationEnabled && isPro
        keyboardLog("Transcription requested via app (translate: \(translate))", category: "Action")

        // Store source app info for auto-return (used when swiftLinkAutoStart is enabled)
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        if let lastAppData = defaults?.data(forKey: "lastUsedSwiftLinkApp"),
           let lastApp = try? JSONDecoder().decode(KeyboardSwiftLinkApp.self, from: lastAppData) {
            defaults?.set(lastApp.urlScheme, forKey: Constants.Record.sourceAppURLScheme)
            defaults?.set(lastApp.name, forKey: Constants.Record.sourceAppName)
            defaults?.set(lastApp.bundleId, forKey: Constants.Record.sourceAppBundleId)
            keyboardLog("Stored source app for auto-return: \(lastApp.name)", category: "Action")
        }
        defaults?.synchronize()

        var urlString = "swiftspeak://record?mode=\(selectedMode.rawValue)&translate=\(translate)"
        if translate {
            urlString += "&target=\(selectedLanguage.rawValue)"
        }
        if let templateId = selectedCustomTemplateId {
            urlString += "&template=\(templateId.uuidString)"
        }

        if let url = URL(string: urlString) { openURL(url) }
    }

    // MARK: - Phase 12: Edit Mode

    /// Start edit mode by opening main app with original text (non-SwiftLink flow)
    private func startEditModeViaURL() {
        guard let originalText = existingTextInField else { return }

        // Store original text in App Groups (URL encoding large text is problematic)
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        defaults?.set(originalText, forKey: Constants.EditMode.pendingEditText)

        keyboardLog("Edit mode requested (\(originalText.count) chars)", category: "Action")

        // Open main app in edit mode
        if let url = URL(string: "swiftspeak://\(Constants.URLHosts.edit)") {
            openURL(url)
        }
    }

    /// Start edit mode via SwiftLink (stays in keyboard)
    private func startSwiftLinkEdit() {
        guard let originalText = existingTextInField else { return }

        // Store original text in App Groups
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        defaults?.set(originalText, forKey: Constants.EditMode.swiftLinkEditOriginalText)
        defaults?.set(true, forKey: Constants.EditMode.lastResultWasEdit)
        defaults?.synchronize()

        // Update UI state
        isSwiftLinkRecording = true
        swiftLinkAudioLevels = []
        swiftLinkProcessingStatus = "recording"
        startAudioLevelReading()  // Start timer for duration and audio levels

        // NOTE: Don't start timeout during recording - user may record for longer than 5 seconds
        // Timeout will start when we STOP recording and wait for processing result

        // Send startEdit notification (different from startDictation)
        darwinManager.post(name: Constants.SwiftLinkNotifications.startEdit)

        keyboardLog("SwiftLink edit started (\(originalText.count) chars)", category: "SwiftLink")
    }

    // Keep for backward compatibility
    func startTranslation() {
        guard isPro else { return }
        isTranslationEnabled = true
        saveSettings()
        keyboardLog("Translation requested", category: "Action")

        var urlString = "swiftspeak://record?mode=\(selectedMode.rawValue)&translate=true&target=\(selectedLanguage.rawValue)"
        if let templateId = selectedCustomTemplateId {
            urlString += "&template=\(templateId.uuidString)"
        }

        if let url = URL(string: urlString) { openURL(url) }
    }

    func startPowerMode(_ powerMode: KeyboardPowerMode) {
        guard isPower else { return }
        keyboardLog("Power Mode: \(powerMode.name)", category: "Action")

        let urlString = "swiftspeak://powermode?id=\(powerMode.id.uuidString)&autostart=true"
        if let url = URL(string: urlString) { openURL(url) }
    }

    func startSwiftLinkSession(with app: KeyboardSwiftLinkApp) {
        keyboardLog("Starting SwiftLink session for \(app.name)", category: "SwiftLink")

        // Open main app with SwiftLink start request
        // URL encode parameters properly
        let encodedName = app.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? app.name
        var urlString = "swiftspeak://swiftlink?action=start&bundleId=\(app.bundleId)&app=\(encodedName)"
        if let scheme = app.urlScheme {
            // URL encode the scheme parameter since it contains :// which can confuse URL parsing
            let encodedScheme = scheme.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scheme
            urlString += "&scheme=\(encodedScheme)"
        }

        keyboardLog("SwiftLink URL: \(urlString)", category: "SwiftLink")
        if let url = URL(string: urlString) { openURL(url) }
    }

    func insertLastTranscription() {
        if let text = lastTranscription {
            keyboardLog("Insert last (\(text.count) chars)", category: "Action")
            textDocumentProxy?.insertText(text)
        }
    }

    func deleteBackward() {
        textDocumentProxy?.deleteBackward()
        updateTypingContext()  // Update predictions when deleting
    }

    // MARK: - Phase 13.11: Return Key Handling

    /// Handle Return key press with context-aware behavior
    /// Returns true if the key was handled specially, false to proceed with normal Return
    func handleReturnKey() -> Bool {
        // If no active context, use normal Return behavior
        guard let context = activeContext else {
            keyboardLog("Return: No active context, using normal behavior", category: "Action")
            return false
        }

        // Check if context has Enter key processing enabled
        guard context.enterRunsContext else {
            keyboardLog("Return: Context '\(context.name)' has enterRunsContext=false", category: "Action")
            // Still check if we should auto-send
            if context.enterSendsMessage {
                // Just insert newline - iOS handles submit automatically
                textDocumentProxy?.insertText("\n")
                return true
            }
            return false
        }

        // Check if there's text to process
        guard let text = existingTextInField, !text.isEmpty else {
            keyboardLog("Return: No text to process", category: "Action")
            return false
        }

        keyboardLog("Return: Processing with context '\(context.name)' (\(text.count) chars)", category: "Action")

        // Process text with AI
        processTextWithAI()

        // If enterSendsMessage is true, the processed text will be auto-submitted
        // after AI processing completes (handled in handleAIProcessResult)

        return true
    }

    func openAppURL(_ url: URL) {
        openURL(url)
    }

    // MARK: - Phase 13.6: Prediction Support

    /// Update the current typing context from the text field
    func updateTypingContext() {
        guard let proxy = textDocumentProxy else {
            currentTypingContext = ""
            return
        }

        let before = proxy.documentContextBeforeInput ?? ""
        // Get last ~100 characters for prediction context
        let context = String(before.suffix(100))
        currentTypingContext = context
    }

    // MARK: - Phase 13.12: AI Sentence Prediction

    /// Trigger AI sentence prediction - shows panel with 4 sentence options
    func triggerAISentencePrediction() {
        keyboardLog("AI Sentence Prediction triggered", category: "AI")

        // Show the panel immediately
        showSentencePredictionPanel = true
        isLoadingSentencePredictions = true
        sentencePredictionError = nil
        sentencePredictions = []

        // Get current typing context
        updateTypingContext()
        keyboardLog("Typing context: \(currentTypingContext.prefix(50))...", category: "AI")

        Task {
            await performSentencePrediction()
        }
    }

    /// Request sentence prediction via SwiftLink (main app handles API call)
    private func performSentencePrediction() async {
        keyboardLog("Starting sentence prediction via SwiftLink...", category: "AI")

        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        // Write context to App Groups for main app to read
        let typingContext = currentTypingContext
        defaults?.set(typingContext, forKey: Constants.SentencePrediction.context)

        // Write active context info if available
        if let context = activeContext {
            defaults?.set(context.name, forKey: Constants.SentencePrediction.activeContextName)
            defaults?.set(context.id.uuidString, forKey: Constants.SentencePrediction.activeContextId)
            keyboardLog("Active context: \(context.name)", category: "AI")
        } else {
            defaults?.removeObject(forKey: Constants.SentencePrediction.activeContextName)
            defaults?.removeObject(forKey: Constants.SentencePrediction.activeContextId)
        }

        // Clear previous results
        defaults?.removeObject(forKey: Constants.SentencePrediction.results)
        defaults?.removeObject(forKey: Constants.SentencePrediction.error)
        defaults?.set(true, forKey: Constants.SentencePrediction.isProcessing)
        defaults?.synchronize()

        // Check if SwiftLink session is active
        if isSwiftLinkSessionActive {
            keyboardLog("SwiftLink active, posting Darwin notification", category: "AI")
            darwinManager.post(name: Constants.SwiftLinkNotifications.requestSentencePrediction)
        } else {
            // Check if auto-start is enabled
            let autoStartEnabled = defaults?.bool(forKey: Constants.Keys.swiftLinkAutoStart) ?? true

            if autoStartEnabled {
                keyboardLog("SwiftLink not active, opening main app (auto-start enabled)", category: "AI")

                // Store source app URL scheme for auto-return (use last used SwiftLink app if available)
                if let lastAppData = defaults?.data(forKey: "lastUsedSwiftLinkApp"),
                   let lastApp = try? JSONDecoder().decode(KeyboardSwiftLinkApp.self, from: lastAppData),
                   let urlScheme = lastApp.urlScheme {
                    defaults?.set(urlScheme, forKey: Constants.SentencePrediction.sourceAppURLScheme)
                    keyboardLog("Source app URL scheme stored: \(urlScheme)", category: "AI")
                }

                // Request auto-return after processing
                defaults?.set(true, forKey: Constants.SentencePrediction.autoReturnRequested)
                defaults?.synchronize()

                // Open main app via URL scheme - it will auto-start SwiftLink and process prediction
                await MainActor.run {
                    if let url = URL(string: "swiftspeak://sentenceprediction") {
                        openURL(url)
                    }
                }
            } else {
                keyboardLog("SwiftLink not active and auto-start disabled", category: "AI", level: .error)
                await MainActor.run {
                    isLoadingSentencePredictions = false
                    sentencePredictionError = "SwiftLink not active. Enable auto-start in Settings or start SwiftLink manually."
                }
                return
            }
        }

        // Start polling for results (main app will write to App Groups)
        await pollForSentencePredictionResults()
    }

    /// Poll for sentence prediction results from main app
    private func pollForSentencePredictionResults() async {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        let maxAttempts = 100  // 10 seconds max (100 * 100ms)

        for attempt in 0..<maxAttempts {
            try? await Task.sleep(for: .milliseconds(100))

            defaults?.synchronize()

            // Check if processing is complete
            let isProcessing = defaults?.bool(forKey: Constants.SentencePrediction.isProcessing) ?? false
            if !isProcessing {
                // Check for error
                if let error = defaults?.string(forKey: Constants.SentencePrediction.error), !error.isEmpty {
                    keyboardLog("Sentence prediction error: \(error)", category: "AI", level: .error)
                    await MainActor.run {
                        isLoadingSentencePredictions = false
                        sentencePredictionError = error
                    }
                    return
                }

                // Check for results
                if let resultsData = defaults?.data(forKey: Constants.SentencePrediction.results),
                   let results = try? JSONDecoder().decode([String].self, from: resultsData) {
                    keyboardLog("Received \(results.count) predictions from main app", category: "AI")
                    await MainActor.run {
                        sentencePredictions = results
                        isLoadingSentencePredictions = false
                    }
                    return
                }
            }
        }

        // Timeout
        keyboardLog("Sentence prediction timed out", category: "AI", level: .error)
        await MainActor.run {
            isLoadingSentencePredictions = false
            sentencePredictionError = "Request timed out. Make sure SwiftSpeak app is running."
        }
    }

    /// Build the prompt for sentence prediction
    private func buildSentencePredictionPrompt(
        typingContext: String,
        globalMemory: String,
        contextMemory: String,
        contextName: String
    ) -> String {
        var systemContext = ""

        if !globalMemory.isEmpty {
            systemContext += "User information:\n\(globalMemory)\n\n"
        }

        if !contextName.isEmpty && !contextMemory.isEmpty {
            systemContext += "Context (\(contextName)):\n\(contextMemory)\n\n"
        }

        let conversationContext = typingContext.isEmpty
            ? "The user is starting a new message."
            : "Current text: \"\(typingContext)\""

        return """
        \(systemContext)\(conversationContext)

        Generate exactly 4 natural sentence completions or responses the user might want to send next. Each should be a complete, standalone sentence that continues naturally from the context.

        Rules:
        - Make sentences varied in tone and approach
        - Keep sentences concise (under 20 words each)
        - Make them contextually appropriate
        - If starting fresh, provide common greeting/opener options

        Respond with exactly 4 sentences, one per line, no numbering or bullets.
        """
    }

    /// Get the API key for formatting provider
    /// Falls back to legacy openAIAPIKey if configuredAIProviders doesn't have a valid key
    private func getFormattingAPIKey() -> String? {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        // Try to get from configured providers first
        if let data = defaults?.data(forKey: Constants.Keys.configuredAIProviders) {
            struct SimpleAIProviderConfig: Codable {
                let provider: String
                let apiKey: String
                let usageCategories: [String]
            }

            do {
                let configs = try JSONDecoder().decode([SimpleAIProviderConfig].self, from: data)

                // Look for formatting provider first
                if let config = configs.first(where: { $0.usageCategories.contains("formatting") }),
                   !config.apiKey.isEmpty,
                   config.apiKey != "configured" {  // Skip placeholder values
                    return config.apiKey
                }

                // Fall back to any OpenAI provider
                if let openAIConfig = configs.first(where: { $0.provider.lowercased().contains("openai") }),
                   !openAIConfig.apiKey.isEmpty,
                   openAIConfig.apiKey != "configured" {
                    return openAIConfig.apiKey
                }

                // Fall back to first available with valid key
                if let config = configs.first(where: { !$0.apiKey.isEmpty && $0.apiKey != "configured" }) {
                    return config.apiKey
                }
            } catch {
                // Fall through to legacy key
            }
        }

        // Fall back to legacy OpenAI key stored directly in UserDefaults
        return defaults?.string(forKey: Constants.Keys.openAIAPIKey)
    }

    /// Call OpenAI API for sentence predictions
    private func callAIForSentencePredictions(prompt: String, apiKey: String) async throws -> [String] {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "You are a helpful assistant that predicts what the user wants to type next. Be concise and natural."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 200,
            "temperature": 0.8
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        keyboardLog("API response status: \(httpResponse.statusCode)", category: "AI")

        if httpResponse.statusCode != 200 {
            // Try to parse error message from response
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                keyboardLog("API error: \(message)", category: "AI", level: .error)
                throw NSError(domain: "AI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
            }
            throw NSError(domain: "AI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API request failed with status \(httpResponse.statusCode)"])
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "AI", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
        }

        // Split response into lines and take first 4 non-empty ones
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(4)
            .map { String($0) }

        if lines.isEmpty {
            throw NSError(domain: "AI", code: -3, userInfo: [NSLocalizedDescriptionKey: "No predictions generated"])
        }

        return Array(lines)
    }

    /// Insert a selected sentence prediction
    func insertSentencePrediction(_ sentence: String) {
        // Insert the sentence
        textDocumentProxy?.insertText(sentence + " ")

        // Update typing context
        updateTypingContext()

        // Close the panel
        showSentencePredictionPanel = false
        sentencePredictions = []

        keyboardLog("Inserted sentence prediction (\(sentence.count) chars)", category: "AI")
    }

    /// Close the sentence prediction panel
    func closeSentencePredictionPanel() {
        showSentencePredictionPanel = false
        sentencePredictions = []
        sentencePredictionError = nil
        isLoadingSentencePredictions = false
    }

    // MARK: - Phase 13.11: AI Context Processing

    /// Process current text through the active context, translation, or both
    func processTextWithAI() {
        // Must have either context or translation enabled
        guard activeContext != nil || isTranslationEnabled else {
            keyboardLog("AI Process: No active context or translation", category: "AI", level: .warning)
            return
        }

        guard let text = existingTextInField, !text.isEmpty else {
            keyboardLog("AI Process: No text in field", category: "AI", level: .warning)
            return
        }

        let contextName = activeContext?.name ?? "none"
        let translationInfo = isTranslationEnabled ? " + translate to \(selectedLanguage.displayName)" : ""
        keyboardLog("AI Process: Starting (context: \(contextName)\(translationInfo), \(text.count) chars)", category: "AI")

        isAIProcessing = true

        // Store text and processing info in App Groups
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        defaults?.set(text, forKey: Constants.AIProcess.pendingText)

        // Store context if active
        if let context = activeContext {
            defaults?.set(context.id.uuidString, forKey: Constants.AIProcess.contextId)
        } else {
            defaults?.removeObject(forKey: Constants.AIProcess.contextId)
        }

        // Store translation settings
        defaults?.set(isTranslationEnabled, forKey: Constants.AIProcess.translateEnabled)
        if isTranslationEnabled {
            defaults?.set(selectedLanguage.rawValue, forKey: Constants.AIProcess.targetLanguage)
        }
        defaults?.synchronize()

        // Set up observer for result first
        setupAIProcessResultObserver()

        // If SwiftLink is active, use Darwin notification (stays in background)
        // Otherwise, open main app with URL scheme and request SwiftLink start + auto-return
        if isSwiftLinkSessionActive {
            keyboardLog("AI Process: Using Darwin notification (SwiftLink active)", category: "AI")
            darwinManager.post(name: Constants.AIProcess.startProcess)
        } else {
            keyboardLog("AI Process: Opening main app with auto-return (SwiftLink not active)", category: "AI")

            // Get source app URL scheme for auto-return (use last used SwiftLink app if available)
            if let lastAppData = defaults?.data(forKey: "lastUsedSwiftLinkApp"),
               let lastApp = try? JSONDecoder().decode(KeyboardSwiftLinkApp.self, from: lastAppData),
               let urlScheme = lastApp.urlScheme {
                defaults?.set(urlScheme, forKey: Constants.AIProcess.sourceAppURLScheme)
            }

            // Request SwiftLink to be started so future AI requests work in background
            defaults?.set(true, forKey: Constants.AIProcess.startSwiftLinkWithProcess)
            // Request auto-return after processing
            defaults?.set(true, forKey: Constants.AIProcess.autoReturnRequested)
            defaults?.synchronize()

            if let url = URL(string: "swiftspeak://aiprocess") {
                openURL(url)
            }
        }
    }

    /// Set up observer for AI process result
    private func setupAIProcessResultObserver() {
        // Use Darwin notification to know when result is ready
        darwinManager.startObserving(name: Constants.AIProcess.resultReady) { [weak self] in
            DispatchQueue.main.async {
                self?.handleAIProcessResult()
            }
        }

        // Timeout after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self = self, self.isAIProcessing else { return }
            self.isAIProcessing = false
            keyboardLog("AI Process: Timeout", category: "AI", level: .error)
        }
    }

    /// Handle AI process result from main app
    private func handleAIProcessResult() {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        defaults?.synchronize()

        let status = defaults?.string(forKey: Constants.AIProcess.status) ?? ""

        if status == "complete", let result = defaults?.string(forKey: Constants.AIProcess.result) {
            keyboardLog("AI Process: Complete (\(result.count) chars)", category: "AI")

            // Get original text before replacing (for undo support)
            let originalText = defaults?.string(forKey: Constants.AIProcess.pendingText) ?? ""

            // Push AI operation to undo stack (allows reverting to original text)
            if !originalText.isEmpty {
                pushAIOperationToUndoStack(originalText: originalText)
            }

            // Replace text in field
            deleteAllTextInField()
            textDocumentProxy?.insertText(result)

            // Check if we should auto-send (context has enterSendsMessage enabled)
            if let context = activeContext, context.enterSendsMessage && context.enterRunsContext {
                keyboardLog("AI Process: Auto-sending message", category: "AI")
                // Insert newline to trigger send in most apps
                textDocumentProxy?.insertText("\n")
            }

            // Clear state
            defaults?.removeObject(forKey: Constants.AIProcess.pendingText)
            defaults?.removeObject(forKey: Constants.AIProcess.contextId)
            defaults?.removeObject(forKey: Constants.AIProcess.result)
            defaults?.removeObject(forKey: Constants.AIProcess.status)
            defaults?.synchronize()

            KeyboardHaptics.success()
        } else if status == "error" {
            let error = defaults?.string(forKey: Constants.AIProcess.result) ?? "Unknown error"
            keyboardLog("AI Process: Error - \(error)", category: "AI", level: .error)
            KeyboardHaptics.warning()
        }

        isAIProcessing = false
    }

    // MARK: - Phase 13: Undo Stack (AI-aware)

    /// Push deleted text onto the undo stack
    func pushToUndoStack(_ text: String) {
        guard !text.isEmpty else { return }
        pushUndoItem(.deletion(text))
    }

    /// Push an AI operation onto the undo stack (stores original text before AI processing)
    func pushAIOperationToUndoStack(originalText: String) {
        guard !originalText.isEmpty else { return }
        pushUndoItem(.aiOperation(originalText: originalText))
        keyboardLog("Undo stack: AI operation saved (\(originalText.count) chars)", category: "Action")
    }

    /// Internal: push any undo item
    private func pushUndoItem(_ item: UndoItem) {
        undoStack.insert(item, at: 0)

        // Keep stack limited
        if undoStack.count > maxUndoItems {
            undoStack = Array(undoStack.prefix(maxUndoItems))
        }

        keyboardLog("Undo stack push: \(item.description) (stack size: \(undoStack.count))", category: "Action")
    }

    /// Undo last operation - handles both deletions and AI operations
    func undo() {
        guard !undoStack.isEmpty else {
            keyboardLog("Undo: stack empty", category: "Action")
            KeyboardHaptics.warning()
            return
        }

        let item = undoStack.removeFirst()

        switch item {
        case .deletion(let text):
            // Simple deletion: just insert the text back
            textDocumentProxy?.insertText(text)
            keyboardLog("Undo: restored deletion (\(text.count) chars)", category: "Action")

        case .aiOperation(let originalText):
            // AI operation: delete current text and insert original
            deleteAllTextInField()
            textDocumentProxy?.insertText(originalText)
            keyboardLog("Undo: reverted AI operation (\(originalText.count) chars)", category: "Action")
        }

        KeyboardHaptics.success()
    }

    /// Check if undo is available
    var canUndo: Bool {
        !undoStack.isEmpty
    }

    /// Clear the undo stack
    func clearUndoStack() {
        undoStack.removeAll()
    }

    // MARK: - Phase 13: Clipboard Panel

    /// Load clipboard items from transcription history and pinned items
    func loadClipboardItems() {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        // Load pinned items
        if let data = defaults?.data(forKey: "pinnedClipboardItems"),
           let items = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            pinnedClipboardItems = items
        }

        // Load from transcription history
        if let data = defaults?.data(forKey: Constants.Keys.transcriptionHistory),
           let history = try? JSONDecoder().decode([ClipboardHistoryRecord].self, from: data) {
            // Convert to clipboard items (most recent first, limit to 20)
            clipboardItems = history.prefix(20).map { record in
                ClipboardItem(
                    id: record.id,
                    text: record.text,
                    timestamp: record.timestamp,
                    source: .transcription,
                    isPinned: false
                )
            }
        }

        keyboardLog("Loaded \(clipboardItems.count) clipboard items, \(pinnedClipboardItems.count) pinned", category: "Clipboard")
    }

    /// Insert a clipboard item into the text field
    func insertClipboardItem(_ item: ClipboardItem) {
        textDocumentProxy?.insertText(item.text)
        KeyboardHaptics.lightTap()
        keyboardLog("Inserted clipboard item (\(item.text.count) chars)", category: "Clipboard")
    }

    /// Pin a clipboard item
    func pinClipboardItem(_ item: ClipboardItem) {
        var pinned = item
        pinned.isPinned = true

        // Remove from regular items if present
        clipboardItems.removeAll { $0.id == item.id }

        // Add to pinned if not already there
        if !pinnedClipboardItems.contains(where: { $0.id == item.id }) {
            pinnedClipboardItems.insert(pinned, at: 0)
        }

        savePinnedItems()
        KeyboardHaptics.success()
        keyboardLog("Pinned clipboard item", category: "Clipboard")
    }

    /// Unpin a clipboard item
    func unpinClipboardItem(_ item: ClipboardItem) {
        pinnedClipboardItems.removeAll { $0.id == item.id }
        savePinnedItems()
        KeyboardHaptics.lightTap()
        keyboardLog("Unpinned clipboard item", category: "Clipboard")
    }

    /// Add custom text to clipboard (pinned)
    func addCustomClipboardItem(text: String) {
        guard !text.isEmpty else { return }

        let item = ClipboardItem(
            id: UUID(),
            text: text,
            timestamp: Date(),
            source: .custom,
            isPinned: true
        )

        pinnedClipboardItems.insert(item, at: 0)
        savePinnedItems()
        KeyboardHaptics.success()
        keyboardLog("Added custom clipboard item (\(text.count) chars)", category: "Clipboard")
    }

    /// Delete a pinned clipboard item
    func deletePinnedItem(_ item: ClipboardItem) {
        pinnedClipboardItems.removeAll { $0.id == item.id }
        savePinnedItems()
        KeyboardHaptics.lightTap()
    }

    private func savePinnedItems() {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        if let data = try? JSONEncoder().encode(pinnedClipboardItems) {
            defaults?.set(data, forKey: "pinnedClipboardItems")
        }
    }

    // MARK: - Unified Keyboard Action Dispatch

    /// Dispatch a unified keyboard action to the main app
    /// This is the new unified system for all keyboard-to-app transitions
    func dispatchUnifiedAction(_ action: KeyboardAction) {
        keyboardLog("Dispatching unified action: \(action.type.rawValue)", category: "UnifiedAction")

        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        // Encode and store the action
        if let actionData = try? JSONEncoder().encode(action) {
            defaults?.set(actionData, forKey: Constants.KeyboardActionKeys.currentAction)
            defaults?.set(KeyboardActionStatus.pending.rawValue, forKey: Constants.KeyboardActionKeys.status)
            defaults?.set(Date().timeIntervalSince1970, forKey: Constants.KeyboardActionKeys.lastUpdate)
            defaults?.synchronize()

            // Open the unified URL to trigger main app
            if let url = Constants.UnifiedURL.url {
                openURL(url)
            }
        } else {
            keyboardLog("Failed to encode action", category: "UnifiedAction", level: .error)
        }
    }

    /// Create and dispatch a transcription action
    func dispatchTranscriptionAction(isEditMode: Bool = false, originalText: String? = nil) {
        // Get source app info for auto-return
        let sourceApp = getSourceAppInfo()

        var action: KeyboardAction
        if isEditMode, let text = originalText {
            action = KeyboardAction.edit(
                originalText: text,
                mode: selectedMode,
                sourceApp: sourceApp,
                autoReturn: true
            )
        } else {
            action = KeyboardAction.transcription(
                mode: selectedMode,
                translate: isTranslationEnabled && isPro,
                targetLanguage: isTranslationEnabled ? selectedLanguage : nil,
                customTemplateId: selectedCustomTemplateId,
                sourceApp: sourceApp,
                autoReturn: true
            )
        }

        dispatchUnifiedAction(action)
    }

    /// Create and dispatch an AI process action
    func dispatchAIProcessAction() {
        guard let text = existingTextInField, !text.isEmpty else {
            keyboardLog("No text to process", category: "UnifiedAction", level: .warning)
            return
        }

        let sourceApp = getSourceAppInfo()

        let action = KeyboardAction.aiProcess(
            text: text,
            contextId: activeContext?.id,
            contextName: activeContext?.name,
            powerModeId: nil,
            powerModeName: nil,
            translate: isTranslationEnabled,
            targetLanguage: isTranslationEnabled ? selectedLanguage : nil,
            sourceApp: sourceApp,
            autoReturn: true
        )

        dispatchUnifiedAction(action)
    }

    /// Create and dispatch a prediction action
    func dispatchPredictionAction() {
        updateTypingContext()
        let sourceApp = getSourceAppInfo()

        let action = KeyboardAction.prediction(
            typingContext: currentTypingContext,
            activeContextId: activeContext?.id,
            activeContextName: activeContext?.name,
            sourceApp: sourceApp,
            autoReturn: true
        )

        dispatchUnifiedAction(action)
    }

    /// Create and dispatch a SwiftLink enable action
    func dispatchEnableSwiftLinkAction() {
        let sourceApp = getSourceAppInfo()

        let action = KeyboardAction.enableSwiftLink(
            sourceApp: sourceApp,
            autoReturn: true
        )

        dispatchUnifiedAction(action)
    }

    /// Get source app info for auto-return
    private func getSourceAppInfo() -> (urlScheme: String?, bundleId: String?, name: String?) {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        // Try to get last used SwiftLink app
        if let lastAppData = defaults?.data(forKey: "lastUsedSwiftLinkApp"),
           let lastApp = try? JSONDecoder().decode(KeyboardSwiftLinkApp.self, from: lastAppData) {
            return (lastApp.urlScheme, lastApp.bundleId, lastApp.name)
        }

        return (nil, nil, nil)
    }

    private func openURL(_ url: URL) {
        // Method 1: Try to get UIApplication.shared via KVC (works in extensions)
        guard let application = UIApplication.value(forKeyPath: "sharedApplication") as? UIApplication else {
            keyboardLog("Could not get shared application", category: "Action", level: .error)
            return
        }

        application.open(url, options: [:]) { success in
            if success {
                keyboardLog("URL opened successfully", category: "Action")
            } else {
                keyboardLog("Failed to open URL", category: "Action", level: .error)
            }
        }
    }
}

// MARK: - Clipboard Models

// MARK: - Undo Item Type

/// Represents an undoable operation
enum UndoItem {
    /// Simple text deletion - just insert the text back
    case deletion(String)
    /// AI operation - stores original text before AI processing
    /// On undo: delete current text, insert original
    case aiOperation(originalText: String)

    var description: String {
        switch self {
        case .deletion(let text):
            return "deletion(\(text.count) chars)"
        case .aiOperation(let text):
            return "aiOperation(\(text.count) chars)"
        }
    }
}

enum ClipboardItemSource: String, Codable {
    case transcription  // From transcription history
    case custom        // User-added custom text
    case system        // From system clipboard
}

struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let source: ClipboardItemSource
    var isPinned: Bool

    var preview: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 50 {
            return String(trimmed.prefix(47)) + "..."
        }
        return trimmed
    }

    var timeAgo: String {
        let interval = Date().timeIntervalSince(timestamp)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

/// Simplified record for decoding transcription history
struct ClipboardHistoryRecord: Codable {
    let id: UUID
    let text: String
    let timestamp: Date
}
