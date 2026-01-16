//
//  SettingsView.swift
//  SwiftSpeak
//
//  App settings and configuration - redesigned with feature-based grouping
//

import AVFoundation
import SwiftUI
import SwiftSpeakCore

struct SettingsView: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var swiftLinkManager = SwiftLinkSessionManager.shared
    @State private var showPaywall = false
    @State private var showResetAllConfirmation = false

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    // MARK: - Biometric Properties

    private var biometricName: String {
        BiometricAuthManager.shared.biometricName
    }

    // MARK: - Subtitle Helpers

    private var swiftLinkSubtitle: String {
        let appCount = settings.swiftLinkApps.count
        if appCount == 0 {
            return "Tap to set up"
        } else {
            return "\(appCount) app\(appCount == 1 ? "" : "s") configured"
        }
    }

    private var voiceLanguageSubtitle: String {
        let dictation = settings.selectedDictationLanguage?.displayName ?? "Auto-detect"
        return dictation
    }

    private var transcriptionAISubtitle: String {
        let cloudCount = settings.configuredAIProviders.count
        var parts: [String] = []
        if cloudCount > 0 {
            parts.append("\(cloudCount) provider\(cloudCount == 1 ? "" : "s")")
        }
        if settings.subscriptionTier == .power {
            if settings.whisperKitConfig.status == .ready {
                parts.append("WhisperKit")
            }
        }
        return parts.isEmpty ? "Configure AI providers" : parts.joined(separator: " + ")
    }

    private var personalizationSubtitle: String {
        let contextCount = settings.contexts.count
        if contextCount > 0 {
            return "\(contextCount) context\(contextCount == 1 ? "" : "s")"
        }
        return "Contexts, memory, apps"
    }

    private var powerModeSubtitle: String {
        let powerModeCount = settings.activePowerModes.count
        if powerModeCount > 0 {
            return "\(powerModeCount) active"
        }
        return "AI agents, RAG"
    }

    private var securitySubtitle: String {
        if settings.biometricProtectionEnabled {
            return "\(biometricName) enabled"
        }
        return "Configure security"
    }

    private var vaultsSubtitle: String {
        let count = settings.obsidianVaults.count
        if count == 0 {
            return "Configure Obsidian vaults"
        }
        return "\(count) vault\(count == 1 ? "" : "s") configured"
    }

    private var keyboardSubtitle: String {
        var parts: [String] = []
        if !settings.keyboardShowSwiftSpeakBar {
            parts.append("Bar hidden")
        }
        if !settings.keyboardShowPredictionRow {
            parts.append("Predictions hidden")
        }
        if parts.isEmpty {
            return "Layout and quick actions"
        }
        return parts.joined(separator: ", ")
    }

    #if DEBUG
    private var microphonePermissionStatus: String {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return "Granted"
        case .denied: return "Denied"
        case .undetermined: return "Not Asked"
        @unknown default: return "Unknown"
        }
    }

    private var microphonePermissionColor: Color {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return .green
        case .denied: return .red
        case .undetermined: return .orange
        @unknown default: return .gray
        }
    }
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                List {
                    // Subscription Card
                    Section {
                        SubscriptionCard(tier: settings.subscriptionTier) {
                            showPaywall = true
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }

                    // SwiftLink Hero Section
                    swiftLinkHeroSection

                    // Main Settings Categories
                    mainCategoriesSection

                    // About Section
                    aboutSection

                    #if DEBUG
                    // Debug Section
                    debugSection
                    #endif
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .onAppear {
                // Reload keyboard settings from App Groups to pick up changes from keyboard extension
                settings.reloadKeyboardSettings()
            }
        }
    }

    // MARK: - SwiftLink Hero Section

    private var swiftLinkHeroSection: some View {
        Section {
            NavigationLink {
                SwiftLinkSetupView()
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "link.circle.fill")
                            .font(.title)
                            .foregroundStyle(AppTheme.accentGradient)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("SwiftLink")
                                .font(.headline)

                            Text(swiftLinkSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if settings.swiftLinkAutoStart {
                            Text("Auto")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .clipShape(Capsule())
                        }
                    }

                    Text("Dictate without leaving your current app")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(rowBackground)

            // SwiftLink Status Card (when session is active)
            if swiftLinkManager.isSessionActive {
                SwiftLinkStatusCard(sessionManager: swiftLinkManager)
                    .listRowBackground(rowBackground)
            }
        }
    }

    // MARK: - Main Categories Section

    private var mainCategoriesSection: some View {
        Section {
            // Voice & Language
            NavigationLink {
                VoiceLanguageSettingsView()
            } label: {
                SettingsRow(
                    icon: "waveform",
                    iconColor: .blue,
                    title: "Voice & Language",
                    subtitle: voiceLanguageSubtitle
                )
            }
            .listRowBackground(rowBackground)

            // Transcription & AI
            NavigationLink {
                TranscriptionAISettingsView()
            } label: {
                SettingsRow(
                    icon: "cpu",
                    iconColor: .purple,
                    title: "Transcription & AI",
                    subtitle: transcriptionAISubtitle
                )
            }
            .listRowBackground(rowBackground)

            // Personalization
            NavigationLink {
                PersonalizationSettingsView()
            } label: {
                SettingsRow(
                    icon: "person.fill",
                    iconColor: .orange,
                    title: "Personalization",
                    subtitle: personalizationSubtitle
                )
            }
            .listRowBackground(rowBackground)

            // Power Mode
            NavigationLink {
                BehaviorSettingsView()
            } label: {
                SettingsRow(
                    icon: "bolt.fill",
                    iconColor: .yellow,
                    title: "Power Mode",
                    subtitle: powerModeSubtitle
                )
            }
            .listRowBackground(rowBackground)

            // Keyboard
            NavigationLink {
                KeyboardSettingsView()
            } label: {
                SettingsRow(
                    icon: "keyboard",
                    iconColor: .indigo,
                    title: "Keyboard",
                    subtitle: keyboardSubtitle
                )
            }
            .listRowBackground(rowBackground)

            // Security & Privacy
            NavigationLink {
                SecurityPrivacyView()
            } label: {
                SettingsRow(
                    icon: "lock.shield.fill",
                    iconColor: .green,
                    title: "Security & Privacy",
                    subtitle: securitySubtitle
                )
            }
            .listRowBackground(rowBackground)

            // Usage & Costs
            NavigationLink {
                CostAnalyticsView()
            } label: {
                SettingsRow(
                    icon: "chart.pie.fill",
                    iconColor: .mint,
                    title: "Usage & Costs",
                    subtitle: "View usage statistics"
                )
            }
            .listRowBackground(rowBackground)

            // Obsidian Vaults
            NavigationLink {
                VaultsSettingsView()
            } label: {
                SettingsRow(
                    icon: "doc.on.doc.fill",
                    iconColor: .purple,
                    title: "Vaults",
                    subtitle: vaultsSubtitle
                )
            }
            .listRowBackground(rowBackground)

            // Diagnostics & Logs
            NavigationLink {
                DiagnosticsView()
            } label: {
                SettingsRow(
                    icon: "stethoscope",
                    iconColor: .teal,
                    title: "Diagnostics & Logs",
                    subtitle: "View and export logs"
                )
            }
            .listRowBackground(rowBackground)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            SettingsRow(
                icon: "info.circle.fill",
                iconColor: .blue,
                title: "Version",
                subtitle: "1.0.0 (Build 1)"
            )
            .listRowBackground(rowBackground)

            Button(action: {
                if let url = URL(string: "https://swiftspeak.app/privacy") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    SettingsRow(
                        icon: "hand.raised.fill",
                        iconColor: .green,
                        title: "Privacy Policy",
                        subtitle: nil
                    )
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .listRowBackground(rowBackground)

            Button(action: {
                if let url = URL(string: "https://swiftspeak.app/terms") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    SettingsRow(
                        icon: "doc.text.fill",
                        iconColor: .gray,
                        title: "Terms of Service",
                        subtitle: nil
                    )
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .listRowBackground(rowBackground)
        } header: {
            Text("About")
        }
    }

    // MARK: - Debug Section

    #if DEBUG
    private var debugSection: some View {
        Section {
            // Microphone Permission
            HStack {
                SettingsRow(
                    icon: "mic.fill",
                    iconColor: microphonePermissionColor,
                    title: "Microphone Permission",
                    subtitle: microphonePermissionStatus
                )
            }
            .listRowBackground(rowBackground)

            // Subscription Override
            Picker(selection: $settings.subscriptionTier) {
                ForEach(SubscriptionTier.allCases, id: \.self) { tier in
                    Text(tier.displayName).tag(tier)
                }
            } label: {
                SettingsRow(
                    icon: "crown.fill",
                    iconColor: .yellow,
                    title: "Subscription (Debug)",
                    subtitle: nil
                )
            }
            .listRowBackground(rowBackground)

            // Add mock transcriptions
            Button(action: addMockTranscriptions) {
                SettingsRow(
                    icon: "doc.text.fill",
                    iconColor: .orange,
                    title: "Add Mock Transcriptions",
                    subtitle: "Add 5 sample entries to history"
                )
            }
            .listRowBackground(rowBackground)

            // Reset all data
            Button(action: {
                showResetAllConfirmation = true
            }) {
                SettingsRow(
                    icon: "trash.fill",
                    iconColor: .red,
                    title: "Reset All Data",
                    subtitle: "Clear all settings and history"
                )
            }
            .listRowBackground(rowBackground)
        } header: {
            Text("Debug")
        }
        .alert("Reset All Data?", isPresented: $showResetAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settings.resetAllSettings()
            }
        } message: {
            Text("This will clear all settings, history, and configured providers. This action cannot be undone.")
        }
    }

    private func addMockTranscriptions() {
        let mockTexts = [
            "Just finished the quarterly report and sent it to the team. Need to follow up with Sarah about the budget review meeting tomorrow.",
            "Note to self: pick up groceries on the way home. Milk, bread, eggs, and coffee.",
            "Great meeting with the client today! They approved the new design mockups and want to proceed with phase two next week.",
            "Reminder: call Mom for her birthday on Saturday. Don't forget to order the flowers from that new shop downtown.",
            "I'll be working from home tomorrow. Please reach out via Slack if you need anything urgent."
        ]

        for (index, text) in mockTexts.enumerated() {
            let record = TranscriptionRecord(
                text: text,
                mode: FormattingMode.allCases[index % FormattingMode.allCases.count],
                provider: .openAI,
                timestamp: Date().addingTimeInterval(-Double(index * 3600)),
                duration: Double.random(in: 10...60)
            )
            settings.addTranscription(record)
        }
    }
    #endif
}

// MARK: - SwiftLink Status Card

struct SwiftLinkStatusCard: View {
    @ObservedObject var sessionManager: SwiftLinkSessionManager
    @ObservedObject var contextCaptureManager = ContextCaptureManager.shared
    @ObservedObject var settings = SharedSettings.shared

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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status header
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)

                Text("SwiftLink Active")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)

                Spacer()
            }

            // Target app
            HStack(spacing: 8) {
                Image(systemName: "app.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(targetAppName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Time remaining
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Time remaining: \(timeRemainingText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .padding(.vertical, 4)

            // Capture status indicators
            VStack(alignment: .leading, spacing: 6) {
                // Microphone status
                HStack(spacing: 8) {
                    Image(systemName: sessionManager.isRecording ? "mic.fill" : "mic.slash.fill")
                        .font(.caption)
                        .foregroundStyle(sessionManager.isRecording ? .green : .secondary)
                    Text("Microphone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(sessionManager.isRecording ? "Active" : "Inactive")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(sessionManager.isRecording ? .green : .secondary)
                }

                // Screen capture status
                HStack(spacing: 8) {
                    Image(systemName: contextCaptureManager.isCapturing ? "rectangle.dashed.badge.record" : "rectangle.dashed")
                        .font(.caption)
                        .foregroundStyle(contextCaptureManager.isCapturing ? .green : .secondary)
                    Text("Screen Context")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !settings.contextCaptureEnabled {
                        Text("Disabled")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    } else if contextCaptureManager.isCapturing {
                        Text("Active")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                    } else {
                        // Tappable broadcast picker button
                        ZStack {
                            Text("Start")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .clipShape(Capsule())

                            // Tappable broadcast picker overlay
                            TappableBroadcastPicker(
                                broadcastExtensionBundleId: "pawelgawliczek.SwiftSpeak.SwiftSpeakBroadcast"
                            )
                        }
                        .frame(width: 60, height: 24)
                    }
                }
            }

            // End Session button
            Button(action: {
                HapticManager.mediumTap()
                sessionManager.endSession()
            }) {
                Text("End Session")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .onAppear {
            contextCaptureManager.refreshState()
        }
    }
}

// MARK: - Preview Helper

struct SettingsPreviewWrapper: View {
    let tier: SubscriptionTier
    let colorScheme: ColorScheme

    @StateObject private var settings = SharedSettings.shared

    var body: some View {
        SettingsView()
            .environmentObject(settings)
            .preferredColorScheme(colorScheme)
            .onAppear {
                settings.subscriptionTier = tier
            }
    }
}

#Preview("Free - Dark") {
    SettingsPreviewWrapper(tier: .free, colorScheme: .dark)
}

#Preview("Free - Light") {
    SettingsPreviewWrapper(tier: .free, colorScheme: .light)
}

#Preview("Pro - Dark") {
    SettingsPreviewWrapper(tier: .pro, colorScheme: .dark)
}

#Preview("Power - Dark") {
    SettingsPreviewWrapper(tier: .power, colorScheme: .dark)
}
