//
//  ContentView.swift
//  SwiftSpeak
//
//  Main app navigation after onboarding
//

import SwiftUI
import SwiftSpeakCore

struct ContentView: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var configManager = RemoteConfigManager.shared
    @StateObject private var actionHandler = KeyboardActionHandler.shared  // Unified keyboard action handler
    @State private var selectedTab = 0
    @State private var showRecording = false
    @State private var translateOnRecord = false
    @State private var showPowerModeExecution = false
    @State private var selectedPowerModeId: UUID?
    @State private var showConfigUpdateSheet = false
    @State private var editModeOriginalText: String? = nil  // Phase 12: Edit mode
    @State private var showSwiftLinkQuickStart = false  // SwiftLink quick-start sheet
    @State private var swiftLinkPreselectedApp: SwiftLinkApp? = nil  // Pre-selected app from keyboard
    @State private var showSwiftLinkSetupOverlay = false  // Overlay when setting up SwiftLink for AI (legacy)
    @State private var swiftLinkSetupMessage = ""  // Dynamic message for the overlay (legacy)

    // Keyboard status tracking
    @State private var keyboardNeedsFullAccess = false
    @State private var keyboardIsEnabled = false

    var body: some View {
        VStack(spacing: 0) {
            // Full Access warning banner
            if keyboardNeedsFullAccess {
                FullAccessWarningBanner(onOpenSettings: openKeyboardSettings)
            }

            TabView(selection: $selectedTab) {
                // Home / Recording
                HomeView(showRecording: $showRecording, translateOnRecord: $translateOnRecord)
                    .tabItem {
                        Image(systemName: "mic.fill")
                        Text("Record")
                    }
                    .tag(0)

            // History (Phase 6: Protected by biometric auth)
            BiometricGateView(authReason: "Access transcription history") {
                HistoryView()
            }
            .tabItem {
                Image(systemName: "clock.fill")
                Text("History")
            }
            .tag(1)

            // Power (Modes + Contexts)
            PowerTabView()
                .tabItem {
                    Image(systemName: "bolt.fill")
                    Text("Power")
                }
                .tag(2)

            // Settings (Phase 6: Protected by biometric auth)
            BiometricGateView(authReason: "Access settings") {
                SettingsView()
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(3)
        }
        .tint(AppTheme.accent)
        .fullScreenCover(isPresented: $showRecording) {
            RecordingView(
                isPresented: $showRecording,
                translateAfterRecording: translateOnRecord,
                editModeOriginalText: editModeOriginalText
            )
        }
        .onChange(of: showRecording) { _, isShowing in
            // Phase 12: Clear edit mode when recording view is dismissed
            if !isShowing {
                editModeOriginalText = nil

                // Auto-start SwiftLink after recording completes (if enabled and not already active)
                // This allows future dictations to work without opening the main app
                if settings.swiftLinkAutoStart && !SwiftLinkSessionManager.shared.isSessionActive {
                    appLog("Auto-starting SwiftLink after recording completed", category: "SwiftLink")
                    Task {
                        await SwiftLinkSessionManager.shared.startBackgroundSession()
                        appLog("SwiftLink session auto-started for future use", category: "SwiftLink")
                    }
                }
            }
        }
        .onOpenURL { url in
            handleURLScheme(url)
        }
        // Phase 6: Handle app lifecycle events
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                BiometricAuthManager.shared.invalidateSession()
            } else if newPhase == .active {
                // Refresh settings in case keyboard changed them
                settings.refreshFromDefaults()
                // Check keyboard Full Access status
                checkKeyboardStatus()
            }
        }
        .onAppear {
            checkKeyboardStatus()
        }
        // Phase 9: Fetch config on launch and show update sheet if needed
        .task {
            await configManager.fetchConfigIfNeeded()
            // Show update sheet if there are pending changes
            if configManager.pendingChanges?.isEmpty == false {
                showConfigUpdateSheet = true
            }
        }
        .sheet(isPresented: $showConfigUpdateSheet) {
            if let changes = configManager.pendingChanges {
                ConfigUpdateSheet(changes: changes, isPresented: $showConfigUpdateSheet)
            }
        }
        .sheet(isPresented: $showSwiftLinkQuickStart) {
            SwiftLinkQuickStartSheet(
                preselectedApp: swiftLinkPreselectedApp,
                onSessionStarted: { urlScheme in
                    // Return to the target app after session starts
                    if let scheme = urlScheme {
                        let returnURLString = scheme.contains("://") ? scheme : "\(scheme)://"
                        if let returnURL = URL(string: returnURLString) {
                            appLog("Returning to app via: \(returnURLString)", category: "SwiftLink")
                            UIApplication.shared.open(returnURL)
                        }
                    }
                }
            )
            .environmentObject(settings)
        }
        // SwiftLink Setup Overlay - shown when AI button pressed without active SwiftLink (legacy)
        .overlay {
            if showSwiftLinkSetupOverlay {
                SwiftLinkSetupOverlay(message: swiftLinkSetupMessage)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .onTapGesture {
                        withAnimation {
                            showSwiftLinkSetupOverlay = false
                        }
                    }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSwiftLinkSetupOverlay)
        // Unified Keyboard Action Overlay - new unified system for all keyboard actions
        .overlay {
            if actionHandler.showOverlay {
                KeyboardActionOverlay(handler: actionHandler)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: actionHandler.showOverlay)
        // Listen for overlay dismiss notification from SwiftLinkSessionManager
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("dismissSwiftLinkOverlay"))) { _ in
            withAnimation {
                showSwiftLinkSetupOverlay = false
            }
        }
        } // Close VStack
    }

    // MARK: - Keyboard Status Check

    /// Check if keyboard is enabled and has Full Access
    private func checkKeyboardStatus() {
        let sharedDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        sharedDefaults?.synchronize()

        // Check if keyboard has ever been activated
        keyboardIsEnabled = sharedDefaults?.bool(forKey: "keyboardIsActive") ?? false

        // Check if Full Access is granted
        let hasFullAccess = sharedDefaults?.bool(forKey: "keyboardHasFullAccess") ?? false

        // Show warning only if keyboard is enabled but lacks Full Access
        withAnimation(.easeInOut(duration: 0.3)) {
            keyboardNeedsFullAccess = keyboardIsEnabled && !hasFullAccess
        }

        if keyboardNeedsFullAccess {
            appLog("Keyboard Full Access warning: enabled=\(keyboardIsEnabled), fullAccess=\(hasFullAccess)", category: "Keyboard", level: .warning)
        }
    }

    /// Open iOS Settings for SwiftSpeak keyboard
    private func openKeyboardSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func handleURLScheme(_ url: URL) {
        // Handle swiftspeak:// URL scheme from keyboard
        guard url.scheme == Constants.urlScheme else { return }

        appLog("URL scheme received: \(url.host ?? "unknown")", category: "Navigation")

        // UNIFIED HANDLER: Handle all keyboard actions through single entry point
        if url.host == Constants.UnifiedURL.host {
            appLog("Unified action URL received - delegating to KeyboardActionHandler", category: "Navigation")

            // Return to home screen (tab 0) as per user requirement
            selectedTab = 0

            // Dismiss any open sheets/overlays
            showRecording = false
            showSwiftLinkQuickStart = false
            showSwiftLinkSetupOverlay = false

            // Process the unified action
            actionHandler.handleURLAction()
            return
        }

        // LEGACY HANDLERS: Maintained for backward compatibility during transition
        // Track if we need to show the setup overlay
        let needsSwiftLinkSetup = !SwiftLinkSessionManager.shared.isSessionActive
        let isAIProcess = url.host == "aiprocess"
        let isSentencePrediction = url.host == "sentenceprediction"
        let isSwiftLinkRequest = url.host == Constants.URLHosts.swiftlink

        // Show overlay for AI process or sentence prediction when SwiftLink needs setup
        if needsSwiftLinkSetup && (isAIProcess || isSentencePrediction) {
            swiftLinkSetupMessage = isSentencePrediction ? "Generating predictions..." : "Setting up SwiftLink..."
            withAnimation {
                showSwiftLinkSetupOverlay = true
            }
        }

        // Auto-start SwiftLink for aiprocess, sentenceprediction, or swiftlink requests
        // Do NOT auto-start for "record" as it conflicts with RecordingView's audio
        // (SwiftLink will be started AFTER recording completes for record flow)
        if needsSwiftLinkSetup && (isAIProcess || isSentencePrediction || isSwiftLinkRequest) && settings.swiftLinkAutoStart {
            appLog("Auto-starting SwiftLink for background processing", category: "SwiftLink")
            Task {
                await SwiftLinkSessionManager.shared.startBackgroundSession()
                // Update overlay message after SwiftLink is ready
                if isAIProcess || isSentencePrediction {
                    await MainActor.run {
                        swiftLinkSetupMessage = isSentencePrediction ? "Processing predictions..." : "Processing your text..."
                    }
                }
                // Process sentence prediction after SwiftLink is ready
                if isSentencePrediction {
                    SwiftLinkSessionManager.shared.handleSentencePredictionRequest()
                }
            }
        }

        // Parse parameters
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        // Handle SwiftLink start request
        if url.host == Constants.URLHosts.swiftlink {
            appLog("SwiftLink start requested", category: "Navigation")

            // Parse app info from URL parameters
            let appName = queryItems.first(where: { $0.name == "app" })?.value
            let urlScheme = queryItems.first(where: { $0.name == "scheme" })?.value
            let bundleId = queryItems.first(where: { $0.name == "bundleId" })?.value

            // If we have all the info, auto-start the session and return immediately
            if let name = appName, let bundle = bundleId, let scheme = urlScheme {
                let targetApp = SwiftLinkApp(
                    bundleId: bundle,
                    name: name,
                    urlScheme: scheme
                )

                // Auto-start SwiftLink session and return to app
                Task {
                    do {
                        if let returnScheme = try await SwiftLinkSessionManager.shared.startSession(targetApp: targetApp) {
                            // Try to return to the target app immediately
                            let returnURLString = returnScheme.contains("://") ? returnScheme : "\(returnScheme)://"
                            if let returnURL = URL(string: returnURLString) {
                                appLog("SwiftLink auto-started, returning to: \(returnURLString)", category: "SwiftLink")

                                // Use completion handler to detect if open failed
                                await withCheckedContinuation { continuation in
                                    UIApplication.shared.open(returnURL) { success in
                                        if success {
                                            appLog("Successfully returned to \(name)", category: "SwiftLink")
                                        } else {
                                            appLog("Failed to open \(returnURLString) - showing return button", category: "SwiftLink", level: .warning)
                                            // Fall back to showing the quick-start sheet with return button
                                            DispatchQueue.main.async {
                                                self.swiftLinkPreselectedApp = targetApp
                                                self.showSwiftLinkQuickStart = true
                                            }
                                        }
                                        continuation.resume()
                                    }
                                }
                            }
                        } else {
                            // No URL scheme returned - show return button UI
                            appLog("SwiftLink started but no URL scheme - showing return button", category: "SwiftLink")
                            await MainActor.run {
                                swiftLinkPreselectedApp = targetApp
                                showSwiftLinkQuickStart = true
                            }
                        }
                    } catch {
                        appLog("Failed to auto-start SwiftLink: \(error.localizedDescription)", category: "SwiftLink", level: .error)
                        // Fall back to showing the quick-start sheet
                        await MainActor.run {
                            swiftLinkPreselectedApp = targetApp
                            showSwiftLinkQuickStart = true
                        }
                    }
                }
            } else {
                // Missing info - show the quick-start sheet
                if let name = appName, let bundle = bundleId {
                    swiftLinkPreselectedApp = SwiftLinkApp(bundleId: bundle, name: name, urlScheme: urlScheme)
                } else {
                    swiftLinkPreselectedApp = nil
                }
                showSwiftLinkQuickStart = true
            }
            return
        }

        // Handle SwiftLink end request from keyboard (toggle off)
        if url.host == Constants.URLHosts.swiftlinkEnd {
            appLog("SwiftLink end requested from keyboard", category: "SwiftLink")
            SwiftLinkSessionManager.shared.endSession()
            return
        }

        // Handle SwiftLink toggle from widget (start if inactive, stop if active)
        if url.host == Constants.URLHosts.swiftlinkToggle {
            if SwiftLinkSessionManager.shared.isSessionActive {
                appLog("SwiftLink toggle: ending session", category: "SwiftLink")
                SwiftLinkSessionManager.shared.endSession()
            } else {
                appLog("SwiftLink toggle: showing quick start", category: "SwiftLink")
                swiftLinkPreselectedApp = nil
                showSwiftLinkQuickStart = true
            }
            return
        }

        // Phase 12: Handle Edit Text request from keyboard
        if url.host == Constants.URLHosts.edit {
            let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
            let originalText = defaults?.string(forKey: Constants.EditMode.pendingEditText) ?? ""

            // Clear after reading
            defaults?.removeObject(forKey: Constants.EditMode.pendingEditText)

            appLog("Edit mode requested (text: \(originalText.count) chars)", category: "Navigation")

            // Set edit mode and show recording
            editModeOriginalText = originalText
            translateOnRecord = false
            showRecording = true
            return
        }

        // Phase 13.11: Handle AI Process request from keyboard
        if url.host == "aiprocess" {
            handleAIProcessRequest()
            return
        }

        // Phase 13.12: Handle Sentence Prediction request from keyboard
        // Processing is handled in the SwiftLink auto-start block above
        if url.host == "sentenceprediction" {
            appLog("Sentence prediction URL received - processing in background", category: "Navigation")
            return
        }

        // Check if it's a power mode URL
        if url.host == Constants.URLHosts.powermode {
            // Handle power mode launch from keyboard
            if let modeIdString = queryItems.first(where: { $0.name == "id" })?.value,
               let modeId = UUID(uuidString: modeIdString) {
                selectedPowerModeId = modeId
                selectedTab = 2 // Switch to Power tab
                appLog("Power Mode launch requested (from keyboard)", category: "Navigation")
                // The PowerModeListView will handle the autostart
            }
            return
        }

        // Extract mode
        if let modeString = queryItems.first(where: { $0.name == "mode" })?.value,
           let mode = FormattingMode(rawValue: modeString) {
            settings.selectedMode = mode
        }

        // Extract translate flag
        translateOnRecord = queryItems.first(where: { $0.name == "translate" })?.value == "true"

        // Extract target language
        if let targetString = queryItems.first(where: { $0.name == "target" })?.value,
           let language = Language(rawValue: targetString) {
            settings.selectedTargetLanguage = language
        }

        // Extract custom template (if provided)
        if let templateIdString = queryItems.first(where: { $0.name == "template" })?.value,
           let templateId = UUID(uuidString: templateIdString),
           let template = settings.customTemplates.first(where: { $0.id == templateId }) {
            settings.selectedCustomTemplate = template
        } else {
            settings.selectedCustomTemplate = nil
        }

        // Check if we should auto-start SwiftLink instead of showing RecordingView
        // When swiftLinkAutoStart is ON and SwiftLink is not active:
        // 1. If we have source app info (from previous SwiftLink setup) → auto-return
        // 2. If no source app info (first time) → show message to return manually (one-time)
        if settings.swiftLinkAutoStart && !SwiftLinkSessionManager.shared.isSessionActive {
            // Read source app info from App Groups (stored by keyboard from lastUsedSwiftLinkApp)
            let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
            let sourceAppURLScheme = defaults?.string(forKey: Constants.Record.sourceAppURLScheme)
            let sourceAppName = defaults?.string(forKey: Constants.Record.sourceAppName)
            let sourceAppBundleId = defaults?.string(forKey: Constants.Record.sourceAppBundleId)

            // Clear the stored info
            defaults?.removeObject(forKey: Constants.Record.sourceAppURLScheme)
            defaults?.removeObject(forKey: Constants.Record.sourceAppName)
            defaults?.removeObject(forKey: Constants.Record.sourceAppBundleId)
            defaults?.synchronize()

            Task {
                do {
                    // If we have source app info, create target app and auto-return
                    if let bundleId = sourceAppBundleId, let scheme = sourceAppURLScheme, let name = sourceAppName {
                        appLog("SwiftLink auto-start: starting session and returning to \(name)", category: "Navigation")

                        let targetApp = SwiftLinkApp(
                            bundleId: bundleId,
                            name: name,
                            urlScheme: scheme
                        )

                        // Start SwiftLink session with target app
                        _ = try await SwiftLinkSessionManager.shared.startSession(targetApp: targetApp)
                        appLog("SwiftLink session started for \(name)", category: "SwiftLink")

                        // Return to source app
                        let returnURLString = scheme.contains("://") ? scheme : "\(scheme)://"
                        if let returnURL = URL(string: returnURLString) {
                            await MainActor.run {
                                UIApplication.shared.open(returnURL) { success in
                                    if success {
                                        appLog("Returned to \(name) - ready for SwiftLink dictation", category: "SwiftLink")
                                    } else {
                                        appLog("Failed to return to \(name)", category: "SwiftLink", level: .warning)
                                    }
                                }
                            }
                        }
                    } else {
                        // No source app info (first time) - start SwiftLink and show message
                        appLog("SwiftLink auto-start: no source app info (first time setup)", category: "Navigation")

                        await SwiftLinkSessionManager.shared.startBackgroundSession()
                        appLog("SwiftLink session started - user should return manually", category: "SwiftLink")

                        // Show one-time message about Apple limitation
                        await MainActor.run {
                            swiftLinkSetupMessage = "SwiftLink is ready!\n\nDue to Apple's security limitations, keyboard extensions cannot detect which app you're using. Please return to your app manually.\n\nThis is a one-time setup - next time it will work automatically."
                            showSwiftLinkSetupOverlay = true
                        }

                        // Auto-dismiss overlay after 4 seconds
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        await MainActor.run {
                            withAnimation {
                                showSwiftLinkSetupOverlay = false
                            }
                        }
                    }
                } catch {
                    appLog("Failed to start SwiftLink session: \(error.localizedDescription)", category: "SwiftLink", level: .error)
                    // Fall back to showing RecordingView
                    await MainActor.run {
                        showRecording = true
                    }
                }
            }
            return
        }

        // Log the recording request
        appLog("Recording requested (mode: \(settings.selectedMode.rawValue), translate: \(translateOnRecord))", category: "Navigation")

        // Show recording view
        showRecording = true
    }

    // MARK: - AI Process Request Handler (Phase 13.11)

    private func handleAIProcessRequest() {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        defaults?.synchronize()

        guard let pendingText = defaults?.string(forKey: Constants.AIProcess.pendingText),
              !pendingText.isEmpty else {
            appLog("AI Process: No pending text", category: "AI", level: .warning)
            return
        }

        let contextIdString = defaults?.string(forKey: Constants.AIProcess.contextId)
        let powerModeIdString = defaults?.string(forKey: Constants.AIProcess.powerModeId)

        // Check translation settings
        let translateEnabled = defaults?.bool(forKey: Constants.AIProcess.translateEnabled) ?? false
        let targetLanguageString = defaults?.string(forKey: Constants.AIProcess.targetLanguage)
        let targetLanguage = targetLanguageString.flatMap { Language(rawValue: $0) }

        // Check if auto-return was requested
        let shouldAutoReturn = defaults?.bool(forKey: Constants.AIProcess.autoReturnRequested) ?? false
        let sourceAppURLScheme = defaults?.string(forKey: Constants.AIProcess.sourceAppURLScheme)

        // Clear the flags (SwiftLink is now auto-started in handleURLScheme)
        defaults?.removeObject(forKey: Constants.AIProcess.startSwiftLinkWithProcess)
        defaults?.removeObject(forKey: Constants.AIProcess.autoReturnRequested)
        defaults?.removeObject(forKey: Constants.AIProcess.sourceAppURLScheme)
        defaults?.removeObject(forKey: Constants.AIProcess.translateEnabled)
        defaults?.removeObject(forKey: Constants.AIProcess.targetLanguage)
        defaults?.synchronize()

        let translateInfo = translateEnabled ? ", translate to \(targetLanguage?.displayName ?? "unknown")" : ""
        appLog("AI Process: Starting (text: \(pendingText.count) chars\(translateInfo), autoReturn: \(shouldAutoReturn))", category: "AI")

        // Set status to processing
        defaults?.set("processing", forKey: Constants.AIProcess.status)
        defaults?.synchronize()

        Task {
            do {
                var result: String = pendingText

                // Step 1: Process with context or power mode if present
                if let contextIdString = contextIdString,
                   let contextId = UUID(uuidString: contextIdString),
                   let context = settings.contexts.first(where: { $0.id == contextId }) {

                    // Process with context
                    result = try await processTextWithContext(result, context: context)

                } else if let powerModeIdString = powerModeIdString,
                          let powerModeId = UUID(uuidString: powerModeIdString),
                          let powerMode = settings.powerModes.first(where: { $0.id == powerModeId }) {

                    // Process with power mode
                    result = try await processTextWithPowerMode(result, powerMode: powerMode)
                }

                // Step 2: Apply translation if enabled
                if translateEnabled, let language = targetLanguage {
                    appLog("AI Process: Translating to \(language.displayName)", category: "AI")
                    result = try await translateText(result, to: language)
                }

                // Store result
                defaults?.set(result, forKey: Constants.AIProcess.result)
                defaults?.set("complete", forKey: Constants.AIProcess.status)
                defaults?.synchronize()

                // Notify keyboard
                DarwinNotificationManager.shared.post(name: Constants.AIProcess.resultReady)

                appLog("AI Process: Complete (\(result.count) chars)", category: "AI")

                // Auto-return to source app if requested
                if shouldAutoReturn {
                    await autoReturnToSourceApp(urlScheme: sourceAppURLScheme)
                }

            } catch {
                appLog("AI Process: Error - \(error.localizedDescription)", category: "AI", level: .error)
                defaults?.set("error", forKey: Constants.AIProcess.status)
                defaults?.synchronize()

                // Notify keyboard of error
                DarwinNotificationManager.shared.post(name: Constants.AIProcess.resultReady)

                // Still try to auto-return even on error
                if shouldAutoReturn {
                    await autoReturnToSourceApp(urlScheme: sourceAppURLScheme)
                }
            }
        }
    }

    /// Auto-return to the source app after AI processing
    @MainActor
    private func autoReturnToSourceApp(urlScheme: String?) async {
        // Update overlay message
        swiftLinkSetupMessage = "Returning to your app..."

        // Small delay to ensure result is stored and notification is sent
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Hide overlay before returning
        withAnimation {
            showSwiftLinkSetupOverlay = false
        }

        // Try source app URL scheme first
        if let scheme = urlScheme, !scheme.isEmpty {
            var urlString = scheme.trimmingCharacters(in: .whitespacesAndNewlines)
            if !urlString.contains("://") {
                urlString = "\(urlString)://"
            }

            if let url = URL(string: urlString) {
                appLog("AI Process: Auto-returning to source app via: \(urlString)", category: "AI")
                UIApplication.shared.open(url, options: [:]) { success in
                    if !success {
                        appLog("AI Process: Failed to open source app", category: "AI", level: .warning)
                    }
                }
                return
            }
        }

        // Try last used SwiftLink app as fallback
        if let lastApp = settings.lastUsedSwiftLinkApp,
           let scheme = lastApp.effectiveURLScheme {
            var urlString = scheme.trimmingCharacters(in: .whitespacesAndNewlines)
            if !urlString.contains("://") {
                urlString = "\(urlString)://"
            }

            if let url = URL(string: urlString) {
                appLog("AI Process: Auto-returning to last SwiftLink app: \(lastApp.name)", category: "AI")
                UIApplication.shared.open(url, options: [:]) { success in
                    if !success {
                        appLog("AI Process: Failed to open last SwiftLink app", category: "AI", level: .warning)
                    }
                }
            }
        } else {
            appLog("AI Process: No source app to return to", category: "AI", level: .warning)
        }
    }

    private func processTextWithContext(_ text: String, context: ConversationContext) async throws -> String {
        // Use the formatting provider to process
        let provider = settings.selectedPowerModeProvider
        guard settings.getAIProviderConfig(for: provider) != nil else {
            throw TranscriptionError.providerNotConfigured
        }

        let factory = ProviderFactory()
        guard let formattingService = factory.createFormattingProvider(for: provider) else {
            throw TranscriptionError.providerNotConfigured
        }

        // Build prompt using PromptContext for consistent formatting
        let promptContext = PromptContext.from(
            context: context,
            globalMemory: settings.globalMemory,
            vocabularyEntries: settings.vocabularyEntries
        )
        let systemPrompt = promptContext.buildFormattingPrompt()

        // Use the formatting service with custom mode and system prompt
        return try await formattingService.format(text: text, mode: FormattingMode.raw, customPrompt: systemPrompt)
    }

    private func processTextWithPowerMode(_ text: String, powerMode: PowerMode) async throws -> String {
        // Build prompt based on power mode and grammar fix setting
        var instruction = powerMode.instruction

        if powerMode.aiAutocorrectEnabled {
            instruction += "\n\nIMPORTANT: Also fix any grammar and punctuation errors in the text, but preserve the original words and meaning."
        }

        // Get the provider from the override if set
        let aiProvider: AIProvider
        if let override = powerMode.providerOverride {
            switch override.providerType {
            case .cloud(let provider):
                aiProvider = provider
            case .local:
                aiProvider = settings.selectedPowerModeProvider
            }
        } else {
            aiProvider = settings.selectedPowerModeProvider
        }

        guard settings.getAIProviderConfig(for: aiProvider) != nil else {
            throw TranscriptionError.providerNotConfigured
        }

        let factory = ProviderFactory()
        guard let formattingService = factory.createFormattingProvider(for: aiProvider) else {
            throw TranscriptionError.providerNotConfigured
        }

        let fullPrompt = """
        \(instruction)

        Process the following text:

        \(text)
        """

        return try await formattingService.format(text: text, mode: FormattingMode.raw, customPrompt: fullPrompt)
    }

    /// Translate text to target language using the configured translation provider
    private func translateText(_ text: String, to targetLanguage: Language) async throws -> String {
        let factory = ProviderFactory()
        guard let translationProvider = factory.createSelectedTranslationProvider() else {
            throw TranscriptionError.providerNotConfigured
        }

        // Use effectiveTranscriptionLanguage for source language hint (context override > global)
        return try await translationProvider.translate(
            text: text,
            from: settings.effectiveTranscriptionLanguage,
            to: targetLanguage
        )
    }
}

// MARK: - SwiftLink Setup Overlay
/// Full-screen overlay shown when setting up SwiftLink for AI processing
struct SwiftLinkSetupOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            // Dark background
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Animated logo
                Image("SwiftSpeakLogo")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundStyle(AppTheme.accent)

                // Loading spinner
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)

                // Message
                Text(message.isEmpty ? "Setting up SwiftLink..." : message)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                // Subtitle
                Text("Getting you back to your app")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(40)
        }
    }
}

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject var settings: SharedSettings
    @Binding var showRecording: Bool
    @Binding var translateOnRecord: Bool
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var swiftLinkManager = SwiftLinkSessionManager.shared

    @State private var showContextPicker = false
    @State private var showDefaultsSettings = false
    @State private var showPaywall = false
    @State private var providerToSetup: AIProvider? = nil
    @State private var showTranslationPicker = false
    @State private var isTranslationEnabled = false
    @State private var showSwiftLinkQuickStart = false

    /// Whether the user has access to Pro features (contexts, modes, translation)
    private var hasProAccess: Bool {
        settings.subscriptionTier != .free
    }

    /// Whether the user has access to translation (Pro+ tier)
    private var hasTranslationAccess: Bool {
        settings.subscriptionTier != .free
    }

    /// Whether user has Power tier (for Power Modes)
    private var hasPowerAccess: Bool {
        settings.subscriptionTier == .power
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var isProviderConfigured: Bool {
        guard let config = settings.transcriptionProviders.first else {
            return false
        }
        if config.provider.isLocalProvider {
            return config.isLocalProviderConfigured
        }
        return !config.apiKey.isEmpty
    }

    private var currentTranscriptionConfig: AIProviderConfig? {
        settings.transcriptionProviders.first
    }

    private var currentModel: String {
        currentTranscriptionConfig?.transcriptionModel ?? "whisper-1"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Action Buttons Area - Arch Layout (matches keyboard)
                    if isProviderConfigured {
                        VStack(spacing: 20) {
                            // Arch layout container
                            ZStack {
                                // Power Mode button - directly above (12 o'clock)
                                HomeArchButton(
                                    icon: "⚡️",
                                    label: "Power",
                                    isLocked: !hasPowerAccess,
                                    accentColor: .orange
                                ) {
                                    if hasPowerAccess {
                                        HapticManager.lightTap()
                                        // Navigate to Power tab handled by tab bar
                                    } else {
                                        showPaywall = true
                                    }
                                }
                                .offset(y: -100)

                                // Translate button - 10:30 position (lower-left)
                                HomeArchButton(
                                    icon: isTranslationEnabled ? settings.selectedTargetLanguage.flag : "🌐",
                                    label: isTranslationEnabled ? settings.selectedTargetLanguage.displayName : "Translate",
                                    isActive: isTranslationEnabled,
                                    isLocked: !hasTranslationAccess,
                                    accentColor: .pink
                                ) {
                                    if hasTranslationAccess {
                                        HapticManager.lightTap()
                                        showTranslationPicker = true
                                    } else {
                                        showPaywall = true
                                    }
                                }
                                .offset(x: -100, y: -50)

                                // Context button - 1:30 position (lower-right)
                                HomeArchButton(
                                    icon: settings.activeContext?.icon ?? "👤",
                                    label: settings.activeContext?.name ?? "Context",
                                    isActive: settings.activeContext != nil,
                                    accentColor: .purple
                                ) {
                                    HapticManager.lightTap()
                                    showContextPicker = true
                                }
                                .offset(x: 100, y: -50)

                                // Main transcribe button at center - HERO element
                                HomeMainActionButton(isTranslationEnabled: isTranslationEnabled) {
                                    HapticManager.mediumTap()
                                    translateOnRecord = isTranslationEnabled
                                    showRecording = true
                                }
                            }
                            .frame(height: 200) // Give space for arch layout

                            // Provider info (subtle)
                            Button(action: {
                                HapticManager.lightTap()
                                showDefaultsSettings = true
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "waveform")
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.accent)
                                    Text(settings.selectedTranscriptionProvider.shortName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.1), in: Capsule())
                            }
                        }
                    } else {
                        // Empty state - no AI provider configured for transcription
                        SetupRequiredView { provider in
                            providerToSetup = provider
                        }
                    }

                    Spacer()

                    // SwiftLink status/control card
                    SwiftLinkHomeCard(
                        sessionManager: swiftLinkManager,
                        onStartTap: { showSwiftLinkQuickStart = true }
                    )
                    .padding(.horizontal, 24)

                    // Quick stats
                    QuickStatsCard()
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    Spacer()
                        .frame(height: 24)
                }
            }
            .navigationTitle("SwiftSpeak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    PrivacyModeIndicator()
                }
            }
            .sheet(isPresented: $showContextPicker) {
                ContextPickerSheet()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showTranslationPicker) {
                TranslationPickerSheet(
                    isTranslationEnabled: $isTranslationEnabled,
                    selectedLanguage: $settings.selectedTargetLanguage
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showDefaultsSettings) {
                DefaultsSettingsSheet()
                    .presentationDetents([.medium])
            }
            .sheet(item: $providerToSetup) { provider in
                AIProviderEditorSheet(
                    config: AIProviderConfig(provider: provider),
                    isEditing: false,
                    onSave: { updatedConfig in
                        settings.addAIProvider(updatedConfig)
                        settings.selectedTranscriptionProvider = updatedConfig.provider
                        settings.selectedTranslationProvider = updatedConfig.provider
                        settings.selectedPowerModeProvider = updatedConfig.provider
                    },
                    onDelete: nil
                )
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showSwiftLinkQuickStart) {
                SwiftLinkQuickStartSheet()
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

// MARK: - SwiftLink Home Card

struct SwiftLinkHomeCard: View {
    @ObservedObject var sessionManager: SwiftLinkSessionManager
    let onStartTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var targetAppName: String {
        sessionManager.getLastUsedApp()?.name ?? "Unknown App"
    }

    private var timeRemainingText: String {
        guard let remaining = sessionManager.sessionTimeRemaining else {
            return "Active"
        }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: sessionManager.isSessionActive ? "link.circle.fill" : "link.circle")
                .font(.title2)
                .foregroundStyle(sessionManager.isSessionActive ? .green : .orange)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("SwiftLink")
                        .font(.subheadline.weight(.semibold))

                    if sessionManager.isSessionActive {
                        Text("Active")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                }

                if sessionManager.isSessionActive {
                    HStack(spacing: 4) {
                        Text(targetAppName)
                        Text("•")
                        Text(timeRemainingText)
                        if sessionManager.isRecording {
                            Text("•")
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text("Tap Start to enable background dictation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Action button
            Button(action: {
                HapticManager.mediumTap()
                if sessionManager.isSessionActive {
                    sessionManager.endSession()
                } else {
                    onStartTap()
                }
            }) {
                Text(sessionManager.isSessionActive ? "Stop" : "Start")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(sessionManager.isSessionActive ? Color.red : Color.orange)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Context Selector (Beautiful Dropdown)
struct ContextSelector: View {
    let activeContext: ConversationContext?
    var isLocked: Bool = false
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var pillBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)
    }

    private var contextColor: Color {
        if isLocked { return .secondary }
        if let context = activeContext {
            return context.color.color
        }
        return .secondary
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Context icon with color ring
                ZStack {
                    Circle()
                        .stroke(contextColor.opacity(0.3), lineWidth: 2)
                        .frame(width: 32, height: 32)

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else if let context = activeContext {
                        Text(context.icon)
                            .font(.system(size: 16))
                    } else {
                        Image(systemName: "person.crop.circle.dashed")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(isLocked ? "Unlock Contexts" : (activeContext?.name ?? "No Context"))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(isLocked ? .secondary : .primary)

                    Text(isLocked ? "Upgrade to Pro" : (activeContext?.description ?? "Tap to select"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isLocked ? "lock.fill" : "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 280)
            .background(pillBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(activeContext != nil && !isLocked ? contextColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Context Picker Sheet
struct ContextPickerSheet: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // "No Context" option
                        ContextOptionCard(
                            icon: "person.crop.circle.dashed",
                            iconIsEmoji: false,
                            name: "No Context",
                            description: "Use default settings without context",
                            color: .secondary,
                            isSelected: settings.activeContextId == nil,
                            onTap: {
                                HapticManager.selection()
                                settings.setActiveContext(nil)
                                dismiss()
                            }
                        )

                        if !settings.contexts.isEmpty {
                            // Divider with label
                            HStack {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(height: 1)

                                Text("YOUR CONTEXTS")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .tracking(1)

                                Rectangle()
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(height: 1)
                            }
                            .padding(.vertical, 8)

                            // Context list
                            ForEach(settings.contexts) { context in
                                ContextOptionCard(
                                    icon: context.icon,
                                    iconIsEmoji: true,
                                    name: context.name,
                                    description: context.description,
                                    color: context.color.color,
                                    isSelected: settings.activeContextId == context.id,
                                    memoryEnabled: context.useContextMemory,
                                    onTap: {
                                        HapticManager.selection()
                                        settings.setActiveContext(context)
                                        dismiss()
                                    }
                                )
                            }
                        }

                        // Empty state or create new
                        if settings.contexts.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "person.2.circle")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)

                                Text("No Contexts Yet")
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Text("Create contexts for different people or situations")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        }

                        // Create new context link
                        NavigationLink {
                            ContextEditorSheet(
                                context: ConversationContext(
                                    name: "",
                                    icon: "person.circle",
                                    color: .blue,
                                    description: ""
                                ),
                                isNew: true,
                                onSave: { newContext in
                                    settings.addContext(newContext)
                                    settings.setActiveContext(newContext)
                                },
                                onDelete: { }
                            )
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.accent.opacity(0.15))
                                        .frame(width: 44, height: 44)

                                    Image(systemName: "plus")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(AppTheme.accent)
                                }

                                Text("Create New Context")
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(AppTheme.accent)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(16)
                            .background(cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Select Context")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Context Option Card
struct ContextOptionCard: View {
    let icon: String
    let iconIsEmoji: Bool
    let name: String
    let description: String
    let color: Color
    let isSelected: Bool
    var memoryEnabled: Bool = false
    let onTap: () -> Void

    @Environment(\.colorScheme) var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Icon with color ring
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Circle()
                        .stroke(color.opacity(isSelected ? 1 : 0.3), lineWidth: isSelected ? 2.5 : 1.5)
                        .frame(width: 48, height: 48)

                    if iconIsEmoji {
                        Text(icon)
                            .font(.system(size: 22))
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 20))
                            .foregroundStyle(color)
                    }
                }

                // Text content
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(name)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.primary)

                        if memoryEnabled {
                            Image(systemName: "brain")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(color)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(14)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
            .animation(AppTheme.quickSpring, value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mode Selector (Beautiful Dropdown - matching Context style)
struct ModeSelector: View {
    @Binding var selectedMode: FormattingMode
    var isLocked: Bool = false
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var pillBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)
    }

    private var modeColor: Color {
        if isLocked { return .secondary }
        return selectedMode == .raw ? .secondary : AppTheme.accent
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Mode icon with color ring (matching Context style)
                ZStack {
                    Circle()
                        .stroke(modeColor.opacity(0.3), lineWidth: 2)
                        .frame(width: 32, height: 32)

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: selectedMode.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(modeColor)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(isLocked ? "Unlock AI Modes" : selectedMode.displayName)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(isLocked ? .secondary : .primary)

                    Text(isLocked ? "Upgrade to Pro" : modeDescription(selectedMode))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isLocked ? "lock.fill" : "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 280)
            .background(pillBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selectedMode != .raw && !isLocked ? modeColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func modeDescription(_ mode: FormattingMode) -> String {
        switch mode {
        case .raw: return "No AI formatting"
        case .email: return "Professional email format"
        case .formal: return "Business tone"
        case .casual: return "Friendly & conversational"
        }
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let icon: String
    let label: String
    var color: Color? = nil
    var gradient: LinearGradient? = nil
    let size: CGFloat
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            Button(action: action) {
                ZStack {
                    if let gradient = gradient {
                        Circle()
                            .fill(gradient)
                            .frame(width: size, height: size)
                            .shadow(color: AppTheme.accent.opacity(0.4), radius: 16)
                    } else if let color = color {
                        Circle()
                            .fill(color)
                            .frame(width: size, height: size)
                            .shadow(color: color.opacity(0.4), radius: 12)
                    }

                    Image(systemName: icon)
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(.white)
                }
            }

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Defaults Settings Sheet
struct DefaultsSettingsSheet: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var showProviderPicker = false
    @State private var showLanguagePicker = false
    @State private var showTranslationModelPicker = false
    @State private var showModeModelPicker = false

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var currentTranscriptionConfig: AIProviderConfig? {
        settings.transcriptionProviders.first
    }

    private var currentModel: String {
        currentTranscriptionConfig?.transcriptionModel ?? settings.selectedTranscriptionProvider.defaultSTTModel ?? "whisper-1"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Transcription Section
                        SettingsSection(title: "TRANSCRIPTION", icon: "waveform", iconColor: AppTheme.accent) {
                            Button(action: {
                                HapticManager.lightTap()
                                showProviderPicker = true
                            }) {
                                SettingsInfoRow(
                                    label: "Provider",
                                    value: settings.selectedTranscriptionProvider.displayName,
                                    detail: currentModel,
                                    showChevron: true
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        // Translation Section
                        SettingsSection(title: "TRANSLATION", icon: "globe", iconColor: .purple) {
                            VStack(spacing: 12) {
                                Button(action: {
                                    HapticManager.lightTap()
                                    showLanguagePicker = true
                                }) {
                                    SettingsInfoRow(
                                        label: "Language",
                                        value: settings.selectedTargetLanguage.displayName,
                                        detail: settings.selectedTargetLanguage.flag,
                                        showChevron: true
                                    )
                                }
                                .buttonStyle(.plain)

                                Divider()
                                    .padding(.horizontal, 8)

                                Button(action: {
                                    HapticManager.lightTap()
                                    showTranslationModelPicker = true
                                }) {
                                    SettingsInfoRow(
                                        label: "AI Model",
                                        value: settings.selectedTranslationProvider.displayName,
                                        showChevron: true
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Mode Section
                        SettingsSection(title: "MODE", icon: "text.badge.star", iconColor: .orange) {
                            VStack(spacing: 8) {
                                Button(action: {
                                    HapticManager.lightTap()
                                    showModeModelPicker = true
                                }) {
                                    SettingsInfoRow(
                                        label: "AI Model",
                                        value: settings.selectedPowerModeProvider.displayName,
                                        showChevron: true
                                    )
                                }
                                .buttonStyle(.plain)

                                Text("Used for Email, Formal, Casual, and custom modes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 8)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Defaults")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showProviderPicker) {
                TranscriptionProviderPickerSheet(
                    selectedProvider: $settings.selectedTranscriptionProvider,
                    providers: settings.transcriptionProviders
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showLanguagePicker) {
                LanguagePickerSheet(selectedLanguage: $settings.selectedTargetLanguage)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showTranslationModelPicker) {
                AIProviderPickerSheet(
                    title: "Translation AI Model",
                    selectedProvider: $settings.selectedTranslationProvider
                )
                .presentationDetents([.height(280)])
            }
            .sheet(isPresented: $showModeModelPicker) {
                AIProviderPickerSheet(
                    title: "Mode AI Model",
                    selectedProvider: $settings.selectedPowerModeProvider
                )
                .presentationDetents([.height(280)])
            }
        }
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }
            .padding(.leading, 4)

            // Content Card
            VStack(spacing: 0) {
                content
            }
            .padding(16)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

// MARK: - Settings Info Row
struct SettingsInfoRow: View {
    let label: String
    let value: String
    var detail: String? = nil
    var showChevron: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 6) {
                if let detail = detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }

                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - Settings Model Picker
struct SettingsModelPicker: View {
    let label: String
    @Binding var selection: AIProvider
    @Environment(\.colorScheme) var colorScheme

    private var pickerBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Menu {
                ForEach(AIProvider.allCases) { provider in
                    Button(action: {
                        HapticManager.selection()
                        selection = provider
                    }) {
                        HStack {
                            Text(provider.displayName)
                            if selection == provider {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: selection.icon)
                        .font(.caption)
                    Text(selection.shortName)
                        .font(.subheadline.weight(.medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(pickerBackground)
                .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Model Info Pill
struct ModelInfoPill: View {
    let icon: String
    let text: String
    let color: Color

    @Environment(\.colorScheme) var colorScheme

    private var pillBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(pillBackground)
        .clipShape(Capsule())
    }
}

// MARK: - Translate Toggle Button (smaller, for 45° positioning)
struct TranslateToggleButton: View {
    let isActive: Bool
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme

    private var inactiveBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.08)
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.pink : inactiveBackground)
                    .frame(width: 52, height: 52)
                    .shadow(color: isActive ? Color.pink.opacity(0.4) : .clear, radius: 8)

                Image(systemName: "globe")
                    .font(.title3)
                    .foregroundStyle(isActive ? .white : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Setup Required View (Empty State)
struct SetupRequiredView: View {
    let onSetup: (AIProvider) -> Void

    @Environment(\.colorScheme) var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
    }

    var body: some View {
        VStack(spacing: 20) {
            // Icon with warning indicator
            ZStack {
                Circle()
                    .fill(cardBackground)
                    .frame(width: 80, height: 80)

                Image(systemName: "waveform")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)

                // Warning badge
                Circle()
                    .fill(Color.orange)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "exclamationmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    )
                    .offset(x: 28, y: -28)
            }

            // Message
            VStack(spacing: 6) {
                Text("Setup Required")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Choose a provider to start transcribing")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Provider buttons
            VStack(spacing: 12) {
                Button(action: {
                    HapticManager.lightTap()
                    onSetup(.openAI)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "brain")
                            .font(.subheadline)
                        Text("OpenAI")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 12)
                    .background(AppTheme.accentGradient)
                    .clipShape(Capsule())
                }

                Button(action: {
                    HapticManager.lightTap()
                    onSetup(.local)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "iphone")
                            .font(.subheadline)
                        Text("On-Device (Free)")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 12)
                    .background(Color.secondary.opacity(0.2))
                    .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Home Screen Components

/// Compact button for Context/Power Mode selectors
struct HomeCompactButton: View {
    let icon: String
    let title: String
    var isLocked: Bool = false
    var accentColor: Color = .purple
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme

    private var background: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isLocked ? Color.secondary.opacity(0.3) : accentColor.opacity(0.2))
                        .frame(width: 48, height: 48)

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(icon)
                            .font(.system(size: 22))
                    }
                }

                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isLocked ? .secondary : .primary)
                    .lineLimit(1)
            }
            .frame(width: 80)
        }
        .buttonStyle(.plain)
    }
}

/// SwiftSpeak logo view for main app (matches keyboard)
struct SwiftSpeakLogoView: View {
    var body: some View {
        if let uiImage = UIImage(named: "SwiftSpeakLogo") {
            // Use actual logo (rendered as template for tinting)
            Image(uiImage: uiImage)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            // Fallback to mic icon
            Image(systemName: "mic.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}

/// Arch-style button for home screen (matches keyboard layout)
struct HomeArchButton: View {
    let icon: String
    let label: String
    var isActive: Bool = false
    var isLocked: Bool = false
    var accentColor: Color = .white

    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme

    private var background: Color {
        if isActive {
            return accentColor.opacity(0.25)
        }
        return colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(background)
                        .frame(width: 52, height: 52)

                    if icon.count <= 2 {
                        Text(icon)
                            .font(.system(size: 22))
                            .opacity(isLocked ? 0.4 : 1.0)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(isLocked ? .secondary : .primary)
                    }

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .offset(x: 16, y: 16)
                    }
                }

                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isLocked ? .secondary : .primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Main transcribe button - hero element
struct HomeMainActionButton: View {
    var isTranslationEnabled: Bool = false
    let action: () -> Void

    private var buttonGradient: LinearGradient {
        if isTranslationEnabled {
            return LinearGradient(colors: [.pink, .pink.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return AppTheme.accentGradient
    }

    private var glowColor: Color {
        isTranslationEnabled ? .pink : AppTheme.accent
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(glowColor.opacity(0.15))
                    .frame(width: 110, height: 110)
                    .blur(radius: 8)

                // Main button
                Circle()
                    .fill(buttonGradient)
                    .frame(width: 80, height: 80)
                    .shadow(color: glowColor.opacity(0.4), radius: 16, y: 4)

                // Logo
                SwiftSpeakLogoView()
                    .frame(width: 105, height: 105)
                    .foregroundStyle(.white)

                // Translation indicator badge
                if isTranslationEnabled {
                    Circle()
                        .fill(.pink)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "globe")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .offset(x: 30, y: -30)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Translation Picker Sheet
struct TranslationPickerSheet: View {
    @Binding var isTranslationEnabled: Bool
    @Binding var selectedLanguage: Language
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()
                scrollContent
            }
            .navigationTitle("Translation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                noTranslationOption
                dividerLabel
                languageOptions
            }
            .padding(20)
        }
    }

    private var noTranslationOption: some View {
        TranslationOptionCard(
            icon: "xmark.circle",
            iconIsEmoji: false,
            name: "No Translation",
            description: "Transcribe without translation",
            color: .secondary,
            isSelected: !isTranslationEnabled,
            onTap: {
                HapticManager.selection()
                isTranslationEnabled = false
                dismiss()
            }
        )
    }

    private var dividerLabel: some View {
        HStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
            Text("TRANSLATE TO")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.vertical, 8)
    }

    private var languageOptions: some View {
        ForEach(Language.allCases, id: \.self) { language in
            TranslationOptionCard(
                icon: language.flag,
                iconIsEmoji: true,
                name: language.displayName,
                description: "",
                color: .pink,
                isSelected: isTranslationEnabled && selectedLanguage == language,
                onTap: {
                    HapticManager.selection()
                    selectedLanguage = language
                    isTranslationEnabled = true
                    dismiss()
                }
            )
        }
    }
}

// MARK: - Translation Option Card
struct TranslationOptionCard: View {
    let icon: String
    let iconIsEmoji: Bool
    let name: String
    let description: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)

                    if iconIsEmoji {
                        Text(icon)
                            .font(.title2)
                    } else {
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(color)
                    }
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)

                    if !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(color)
                }
            }
            .padding(16)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Secondary action buttons (Translate, Language)
struct HomeSecondaryButton: View {
    let icon: String
    let title: String
    let color: Color
    var isLocked: Bool = false
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme

    private var background: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isLocked ? .secondary : color)

                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isLocked ? .secondary : .primary)
                    .lineLimit(1)

                if isLocked {
                    TierBadge.pro
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Language Picker Sheet
struct LanguagePickerSheet: View {
    @Binding var selectedLanguage: Language
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Language.allCases, id: \.self) { language in
                    Button(action: {
                        HapticManager.selection()
                        selectedLanguage = language
                        dismiss()
                    }) {
                        HStack {
                            Text(language.flag)
                                .font(.title2)

                            Text(language.displayName)
                                .foregroundStyle(.primary)

                            Spacer()

                            if language == selectedLanguage {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AppTheme.accent)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .listRowBackground(backgroundColor)
                }
            }
            .listStyle(.plain)
            .background(backgroundColor)
            .scrollContentBackground(.hidden)
            .navigationTitle("Target Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - AI Provider Picker Sheet
struct AIProviderPickerSheet: View {
    let title: String
    @Binding var selectedProvider: AIProvider
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                List {
                    ForEach(AIProvider.allCases) { provider in
                        Button(action: {
                            HapticManager.selection()
                            selectedProvider = provider
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                ProviderIcon(provider, size: .large, style: .filled)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(provider.displayName)
                                        .font(.callout.weight(.medium))
                                        .foregroundStyle(.primary)
                                }

                                Spacer()

                                if selectedProvider == provider {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.accent)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .listRowBackground(rowBackground)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Pill Dropdown Button
struct PillDropdown: View {
    let icon: String
    let text: String
    let isSystemIcon: Bool
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme

    private var pillBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSystemIcon {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                } else {
                    Text(icon) // For emoji flags
                        .font(.subheadline)
                }

                Text(text)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(pillBackground)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Transcription Provider Picker Sheet
struct TranscriptionProviderPickerSheet: View {
    @Binding var selectedProvider: AIProvider
    let providers: [AIProviderConfig]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                List {
                    ForEach(providers) { config in
                        Button(action: {
                            HapticManager.selection()
                            selectedProvider = config.provider
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                ProviderIcon(config.provider, size: .large, style: .filled)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(config.provider.displayName)
                                        .font(.callout.weight(.medium))
                                        .foregroundStyle(.primary)

                                    Text(config.transcriptionModel ?? config.provider.defaultSTTModel ?? "whisper-1")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if selectedProvider == config.provider {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.accent)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .listRowBackground(rowBackground)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Select Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Mode Picker Sheet
struct ModePickerSheet: View {
    @Binding var selectedMode: FormattingMode
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                List {
                    ForEach(FormattingMode.allCases) { mode in
                        Button(action: {
                            HapticManager.selection()
                            selectedMode = mode
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: mode.icon)
                                    .font(.title3)
                                    .foregroundStyle(mode == .raw ? .secondary : AppTheme.accent)
                                    .frame(width: 36, height: 36)
                                    .background((mode == .raw ? Color.secondary : AppTheme.accent).opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.displayName)
                                        .font(.callout.weight(.medium))
                                        .foregroundStyle(.primary)

                                    Text(modeDescription(mode))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if selectedMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.accent)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .listRowBackground(rowBackground)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Select Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func modeDescription(_ mode: FormattingMode) -> String {
        switch mode {
        case .raw: return "No formatting, just transcribe"
        case .email: return "Format as professional email"
        case .formal: return "Formal, business tone"
        case .casual: return "Friendly, conversational"
        }
    }
}

// MARK: - Quick Stats Card
struct QuickStatsCard: View {
    @EnvironmentObject var settings: SharedSettings

    private var totalPowerModeUsage: Int {
        PowerMode.presets.reduce(0) { $0 + $1.usageCount }
    }

    private var totalWordCount: Int {
        settings.transcriptionHistory.reduce(0) { total, record in
            // Use stored word count if available, otherwise calculate from text
            if let wordCount = record.costBreakdown?.wordCount {
                return total + wordCount
            } else {
                return total + record.text.split(separator: " ").count
            }
        }
    }

    private var formattedWordCount: String {
        if totalWordCount < 1000 {
            return "\(totalWordCount)"
        } else if totalWordCount < 1_000_000 {
            return String(format: "%.1fK", Double(totalWordCount) / 1000)
        } else {
            return String(format: "%.1fM", Double(totalWordCount) / 1_000_000)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ThemedStatItem(
                icon: "waveform",
                value: "\(settings.transcriptionHistory.count)",
                label: "Transcriptions"
            )
            .frame(maxWidth: .infinity)

            statDivider

            ThemedStatItem(
                icon: "bolt.fill",
                value: "\(totalPowerModeUsage)",
                label: "Power Modes"
            )
            .frame(maxWidth: .infinity)

            statDivider

            ThemedStatItem(
                icon: "clock",
                value: formattedDuration,
                label: "Time"
            )
            .frame(maxWidth: .infinity)

            statDivider

            ThemedStatItem(
                icon: "text.word.spacing",
                value: formattedWordCount,
                label: "Words"
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .glassBackground(cornerRadius: AppTheme.cornerRadiusLarge, includeShadow: false)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.3))
            .frame(width: 1, height: 40)
    }

    private var formattedDuration: String {
        let totalSeconds = settings.transcriptionHistory.reduce(0) { $0 + $1.duration }
        let minutes = Int(totalSeconds) / 60
        if minutes < 1 {
            return "0m"
        } else if minutes < 60 {
            return "\(minutes)m"
        } else {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
    }
}

// MARK: - Full Access Warning Banner

/// Warning banner shown when keyboard is enabled but Full Access is not granted
struct FullAccessWarningBanner: View {
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text("Keyboard Full Access Required")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Voice dictation won't work without Full Access")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onOpenSettings) {
                Text("Enable")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.gradient)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.orange.opacity(0.15))
    }
}

#Preview("Home - Dark") {
    let settings = SharedSettings.shared
    // Ensure API key is configured
    if var config = settings.getAIProviderConfig(for: settings.selectedTranscriptionProvider) {
        if config.apiKey.isEmpty {
            config.apiKey = "sk-preview-key"
            settings.updateAIProvider(config)
        }
    }
    return ContentView()
        .environmentObject(settings)
        .preferredColorScheme(.dark)
}

#Preview("Home - Light") {
    let settings = SharedSettings.shared
    // Ensure API key is configured
    if var config = settings.getAIProviderConfig(for: settings.selectedTranscriptionProvider) {
        if config.apiKey.isEmpty {
            config.apiKey = "sk-preview-key"
            settings.updateAIProvider(config)
        }
    }
    return ContentView()
        .environmentObject(settings)
        .preferredColorScheme(.light)
}

#Preview("Home - Email Mode") {
    let settings = SharedSettings.shared
    settings.selectedMode = .email
    // Ensure API key is configured
    if var config = settings.getAIProviderConfig(for: settings.selectedTranscriptionProvider) {
        if config.apiKey.isEmpty {
            config.apiKey = "sk-preview-key"
            settings.updateAIProvider(config)
        }
    }
    return ContentView()
        .environmentObject(settings)
        .preferredColorScheme(.dark)
}

#Preview("Home - No API Key") {
    let settings = SharedSettings.shared
    // Clear the API key for the selected provider
    if var config = settings.getAIProviderConfig(for: settings.selectedTranscriptionProvider) {
        config.apiKey = ""
        settings.updateAIProvider(config)
    }
    return ContentView()
        .environmentObject(settings)
        .preferredColorScheme(.dark)
}

#Preview("Setup Required View") {
    SetupRequiredView { _ in }
    .padding()
    .preferredColorScheme(.dark)
}
