//
//  ContentView.swift
//  SwiftSpeak
//
//  Main app navigation after onboarding
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var configManager = RemoteConfigManager.shared
    @State private var selectedTab = 0
    @State private var showRecording = false
    @State private var translateOnRecord = false
    @State private var showPowerModeExecution = false
    @State private var selectedPowerModeId: UUID?
    @State private var showConfigUpdateSheet = false

    var body: some View {
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
            RecordingView(isPresented: $showRecording, translateAfterRecording: translateOnRecord)
        }
        .onOpenURL { url in
            handleURLScheme(url)
        }
        // Phase 6: Invalidate biometric session when app goes to background
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                BiometricAuthManager.shared.invalidateSession()
            }
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
    }

    private func handleURLScheme(_ url: URL) {
        // Handle swiftspeak:// URL scheme from keyboard
        guard url.scheme == Constants.urlScheme else { return }

        // Parse parameters
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        // Check if it's a power mode URL
        if url.host == "powermode" {
            // Handle power mode launch from keyboard
            if let modeIdString = queryItems.first(where: { $0.name == "id" })?.value,
               let modeId = UUID(uuidString: modeIdString) {
                selectedPowerModeId = modeId
                selectedTab = 2 // Switch to Power tab
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

        // Show recording view
        showRecording = true
    }
}

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject var settings: SharedSettings
    @Binding var showRecording: Bool
    @Binding var translateOnRecord: Bool
    @Environment(\.colorScheme) var colorScheme

    @State private var showModePicker = false
    @State private var showDefaultsSettings = false
    @State private var showProviderSetup = false
    @State private var showPaywall = false

    /// Whether the user has access to translation (Pro+ tier)
    private var hasTranslationAccess: Bool {
        settings.subscriptionTier != .free
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var isProviderConfigured: Bool {
        // Check if any AI provider is configured for transcription
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

                    // Mode Selector - Beautiful centered dropdown
                    VStack(spacing: 12) {
                        Text("MODE")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .tracking(1.5)

                        ModeSelector(
                            selectedMode: $settings.selectedMode,
                            onTap: {
                                HapticManager.lightTap()
                                showModePicker = true
                            }
                        )
                    }

                    Spacer()

                    // Action Buttons Area
                    if isProviderConfigured {
                        VStack(spacing: 24) {
                            // Two action buttons side by side
                            HStack(spacing: 32) {
                                // Translate + Transcribe button (pink) - Pro+ feature
                                ZStack(alignment: .topTrailing) {
                                    ActionButton(
                                        icon: "globe",
                                        label: "Translate",
                                        color: .pink,
                                        size: 72
                                    ) {
                                        HapticManager.mediumTap()
                                        if hasTranslationAccess {
                                            translateOnRecord = true
                                            showRecording = true
                                        } else {
                                            showPaywall = true
                                        }
                                    }

                                    // Show PRO badge if not subscribed
                                    if !hasTranslationAccess {
                                        TierBadge.pro
                                            .offset(x: 8, y: -8)
                                    }
                                }

                                // Transcribe only button (accent)
                                ActionButton(
                                    icon: "mic.fill",
                                    label: "Transcribe",
                                    gradient: AppTheme.accentGradient,
                                    size: 100
                                ) {
                                    HapticManager.mediumTap()
                                    translateOnRecord = false
                                    showRecording = true
                                }
                            }

                            // Settings summary
                            VStack(spacing: 8) {
                                // Model info
                                HStack(spacing: 16) {
                                    // Transcription
                                    ModelInfoPill(
                                        icon: "waveform",
                                        text: settings.selectedTranscriptionProvider.shortName,
                                        color: AppTheme.accent
                                    )

                                    // Translation
                                    ModelInfoPill(
                                        icon: "globe",
                                        text: "\(settings.selectedTargetLanguage.flag) \(settings.selectedTranslationProvider.shortName)",
                                        color: .pink
                                    )

                                    // Mode (only when not Raw)
                                    if settings.selectedMode != .raw {
                                        ModelInfoPill(
                                            icon: "text.badge.star",
                                            text: settings.selectedPowerModeProvider.shortName,
                                            color: .orange
                                        )
                                    }
                                }

                                // Edit defaults button
                                Button(action: {
                                    HapticManager.lightTap()
                                    showDefaultsSettings = true
                                }) {
                                    Text("Edit defaults")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        // Empty state - no AI provider configured for transcription
                        SetupRequiredView(
                            provider: currentTranscriptionConfig?.provider ?? .openAI,
                            onSetup: {
                                showProviderSetup = true
                            }
                        )
                    }

                    Spacer()

                    // Quick stats
                    QuickStatsCard()
                        .padding(.horizontal, 24)

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
            .sheet(isPresented: $showModePicker) {
                ModePickerSheet(selectedMode: $settings.selectedMode)
                    .presentationDetents([.height(320)])
            }
            .sheet(isPresented: $showDefaultsSettings) {
                DefaultsSettingsSheet()
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showProviderSetup) {
                AIProviderEditorSheet(
                    config: currentTranscriptionConfig ?? AIProviderConfig(provider: .openAI),
                    isEditing: currentTranscriptionConfig != nil,
                    onSave: { updatedConfig in
                        if currentTranscriptionConfig != nil {
                            settings.updateAIProvider(updatedConfig)
                        } else {
                            settings.addAIProvider(updatedConfig)
                        }
                    },
                    onDelete: nil
                )
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}

// MARK: - Mode Selector (Beautiful Dropdown)
struct ModeSelector: View {
    @Binding var selectedMode: FormattingMode
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var pillBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: selectedMode.icon)
                    .font(.title3)
                    .foregroundStyle(selectedMode == .raw ? .secondary : AppTheme.accent)

                Text(selectedMode.displayName)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(pillBackground)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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
    let provider: AIProvider
    let onSetup: () -> Void

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

                Image(systemName: provider.icon)
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
                Text("API Key Required")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Configure \(provider.shortName) to start transcribing")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Setup Button
            Button(action: {
                HapticManager.lightTap()
                onSetup()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.subheadline)

                    Text("Add API Key")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppTheme.accentGradient)
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
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
                                Image(systemName: provider.icon)
                                    .font(.title3)
                                    .foregroundStyle(AppTheme.accent)
                                    .frame(width: 36, height: 36)
                                    .background(AppTheme.accent.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

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
                                Image(systemName: config.provider.icon)
                                    .font(.title3)
                                    .foregroundStyle(AppTheme.accent)
                                    .frame(width: 36, height: 36)
                                    .background(AppTheme.accent.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

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

// MARK: - Language Picker Sheet
struct LanguagePickerSheet: View {
    @Binding var selectedLanguage: Language
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
                    ForEach(Language.allCases) { language in
                        Button(action: {
                            HapticManager.selection()
                            selectedLanguage = language
                            dismiss()
                        }) {
                            HStack {
                                Text(language.flag)
                                    .font(.title2)

                                Text(language.displayName)
                                    .font(.callout)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if selectedLanguage == language {
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
            .navigationTitle("Translate To")
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

// MARK: - Quick Stats Card
struct QuickStatsCard: View {
    @EnvironmentObject var settings: SharedSettings

    private var totalPowerModeUsage: Int {
        PowerMode.presets.reduce(0) { $0 + $1.usageCount }
    }

    var body: some View {
        HStack(spacing: 16) {
            ThemedStatItem(
                icon: "waveform",
                value: "\(settings.transcriptionHistory.count)",
                label: "Transcriptions"
            )

            Divider()
                .frame(height: 40)

            ThemedStatItem(
                icon: "bolt.fill",
                value: "\(totalPowerModeUsage)",
                label: "Power Modes"
            )

            Divider()
                .frame(height: 40)

            ThemedStatItem(
                icon: "clock",
                value: formattedDuration,
                label: "Time"
            )
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .glassBackground(cornerRadius: AppTheme.cornerRadiusLarge, includeShadow: false)
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
    SetupRequiredView(
        provider: .openAI,
        onSetup: { }
    )
    .padding()
    .preferredColorScheme(.dark)
}
