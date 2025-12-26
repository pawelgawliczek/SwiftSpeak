//
//  ContentView.swift
//  SwiftSpeak
//
//  Main app navigation after onboarding
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: SharedSettings
    @State private var selectedTab = 0
    @State private var showRecording = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home / Recording
            HomeView(showRecording: $showRecording)
                .tabItem {
                    Image(systemName: "mic.fill")
                    Text("Record")
                }
                .tag(0)

            // History
            HistoryView()
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("History")
                }
                .tag(1)

            // Settings
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(2)
        }
        .tint(AppTheme.accent)
        .fullScreenCover(isPresented: $showRecording) {
            RecordingView(isPresented: $showRecording)
        }
        .onOpenURL { url in
            handleURLScheme(url)
        }
    }

    private func handleURLScheme(_ url: URL) {
        // Handle swiftspeak:// URL scheme from keyboard
        guard url.scheme == Constants.urlScheme else { return }

        // Parse parameters
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        // Extract mode
        if let modeString = queryItems.first(where: { $0.name == "mode" })?.value,
           let mode = FormattingMode(rawValue: modeString) {
            settings.selectedMode = mode
        }

        // Extract translate flag (Phase 2)
        _ = queryItems.first(where: { $0.name == "translate" })?.value == "true"

        // Extract target language
        if let targetString = queryItems.first(where: { $0.name == "target" })?.value,
           let language = Language(rawValue: targetString) {
            settings.selectedTargetLanguage = language
        }

        // Show recording view
        showRecording = true
    }
}

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject var settings: SharedSettings
    @Binding var showRecording: Bool
    @Environment(\.colorScheme) var colorScheme

    @State private var showProviderPicker = false
    @State private var showModePicker = false
    @State private var showLanguagePicker = false
    @State private var showModeModelPicker = false
    @State private var showTranslationModelPicker = false
    @State private var showProviderSetup = false
    @State private var editingProviderConfig: STTProviderConfig?

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var isPowerUser: Bool {
        settings.subscriptionTier != .free
    }

    private var isProviderConfigured: Bool {
        guard let config = settings.getSTTProviderConfig(for: settings.selectedProvider) else {
            return false
        }
        if settings.selectedProvider == .ollama {
            return !(config.endpoint?.isEmpty ?? true)
        }
        return !config.apiKey.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Dropdowns Section - Full Width, Fixed at top
                    VStack(spacing: 16) {
                        // Transcription Provider
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TRANSCRIPTION")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)

                            PillDropdown(
                                icon: settings.selectedProvider.icon,
                                text: "\(settings.selectedProvider.shortName) · \(currentProviderModel)",
                                isSystemIcon: true
                            ) {
                                HapticManager.lightTap()
                                showProviderPicker = true
                            }
                        }

                        // Mode and Language row
                        HStack(spacing: 12) {
                            // Mode dropdown
                            VStack(alignment: .leading, spacing: 8) {
                                Text("MODE")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)

                                PillDropdown(
                                    icon: settings.selectedMode.icon,
                                    text: settings.selectedMode.displayName,
                                    isSystemIcon: true
                                ) {
                                    HapticManager.lightTap()
                                    showModePicker = true
                                }
                            }

                            // Language dropdown
                            VStack(alignment: .leading, spacing: 8) {
                                Text("LANGUAGE")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)

                                PillDropdown(
                                    icon: settings.selectedTargetLanguage.flag,
                                    text: settings.selectedTargetLanguage.displayName,
                                    isSystemIcon: false
                                ) {
                                    HapticManager.lightTap()
                                    showLanguagePicker = true
                                }
                            }
                        }

                        // Pro/Power: LLM Model selectors - always reserve space
                        HStack(spacing: 12) {
                            // Mode LLM (when mode != raw)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("MODE MODEL")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)

                                PillDropdown(
                                    icon: settings.selectedModeProvider.icon,
                                    text: settings.selectedModeProvider.shortName,
                                    isSystemIcon: true
                                ) {
                                    HapticManager.lightTap()
                                    showModeModelPicker = true
                                }
                            }
                            .opacity(isPowerUser && settings.selectedMode != .raw ? 1 : 0)
                            .allowsHitTesting(isPowerUser && settings.selectedMode != .raw)

                            // Translation LLM (when translation enabled)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("TRANSLATION MODEL")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)

                                PillDropdown(
                                    icon: settings.selectedTranslationProvider.icon,
                                    text: settings.selectedTranslationProvider.shortName,
                                    isSystemIcon: true
                                ) {
                                    HapticManager.lightTap()
                                    showTranslationModelPicker = true
                                }
                            }
                            .opacity(isPowerUser && settings.isTranslationEnabled ? 1 : 0)
                            .allowsHitTesting(isPowerUser && settings.isTranslationEnabled)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    Spacer()

                    // Record Button Area with Translate toggle - Fixed position
                    if isProviderConfigured {
                        // Normal state - provider is configured
                        ZStack {
                            // Main record button - centered, larger
                            Button(action: {
                                HapticManager.mediumTap()
                                showRecording = true
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.accentGradient)
                                        .frame(width: 120, height: 120)
                                        .shadow(color: AppTheme.accent.opacity(0.5), radius: 20)

                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 48))
                                        .foregroundStyle(.white)
                                }
                            }

                            // Translate button - positioned at 45° angle to top-left
                            TranslateToggleButton(
                                isActive: settings.isTranslationEnabled,
                                action: {
                                    HapticManager.selection()
                                    withAnimation(AppTheme.quickSpring) {
                                        settings.isTranslationEnabled.toggle()
                                    }
                                }
                            )
                            .offset(x: -90, y: -60) // 45° angle positioning
                        }
                        .frame(height: 180)
                    } else {
                        // Empty state - no API key configured
                        SetupRequiredView(
                            provider: settings.selectedProvider,
                            onSetup: {
                                showProviderSetup = true
                            }
                        )
                        .frame(height: 180)
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
            .sheet(isPresented: $showProviderPicker) {
                ProviderPickerSheet(
                    selectedProvider: $settings.selectedProvider,
                    providers: settings.configuredSTTProviders
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showModePicker) {
                ModePickerSheet(selectedMode: $settings.selectedMode)
                    .presentationDetents([.height(320)])
            }
            .sheet(isPresented: $showLanguagePicker) {
                LanguagePickerSheet(selectedLanguage: $settings.selectedTargetLanguage)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showModeModelPicker) {
                LLMProviderPickerSheet(
                    title: "Mode Model",
                    selectedProvider: $settings.selectedModeProvider
                )
                .presentationDetents([.height(280)])
            }
            .sheet(isPresented: $showTranslationModelPicker) {
                LLMProviderPickerSheet(
                    title: "Translation Model",
                    selectedProvider: $settings.selectedTranslationProvider
                )
                .presentationDetents([.height(280)])
            }
            .sheet(isPresented: $showProviderSetup) {
                if let config = editingProviderConfig {
                    ProviderEditorSheet(
                        config: config,
                        isEditing: true,
                        onSave: { updatedConfig in
                            settings.updateSTTProvider(updatedConfig)
                        },
                        onDelete: nil
                    )
                }
            }
            .onChange(of: showProviderSetup) { _, isShowing in
                if isShowing && editingProviderConfig == nil {
                    // Create a config for the current provider if none exists
                    if let existingConfig = settings.getSTTProviderConfig(for: settings.selectedProvider) {
                        editingProviderConfig = existingConfig
                    } else {
                        editingProviderConfig = STTProviderConfig(provider: settings.selectedProvider)
                    }
                }
            }
        }
    }

    private var currentProviderModel: String {
        settings.getSTTProviderConfig(for: settings.selectedProvider)?.model ?? settings.selectedProvider.defaultModel
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
    let provider: STTProvider
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

// MARK: - LLM Provider Picker Sheet
struct LLMProviderPickerSheet: View {
    let title: String
    @Binding var selectedProvider: LLMProvider
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
                    ForEach(LLMProvider.allCases) { provider in
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


// MARK: - Provider Picker Sheet
struct ProviderPickerSheet: View {
    @Binding var selectedProvider: STTProvider
    let providers: [STTProviderConfig]
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

                                    Text(config.model)
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

    var body: some View {
        HStack(spacing: 24) {
            ThemedStatItem(
                icon: "waveform",
                value: "\(settings.transcriptionHistory.count)",
                label: "Transcriptions"
            )

            Divider()
                .frame(height: 40)

            ThemedStatItem(
                icon: "clock",
                value: formattedDuration,
                label: "Total Time"
            )

            Divider()
                .frame(height: 40)

            ThemedStatItem(
                icon: "star.fill",
                value: settings.subscriptionTier.displayName,
                label: "Plan"
            )
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
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
    if var config = settings.getSTTProviderConfig(for: settings.selectedProvider) {
        if config.apiKey.isEmpty {
            config.apiKey = "sk-preview-key"
            settings.updateSTTProvider(config)
        }
    }
    return ContentView()
        .environmentObject(settings)
        .preferredColorScheme(.dark)
}

#Preview("Home - Light") {
    let settings = SharedSettings.shared
    // Ensure API key is configured
    if var config = settings.getSTTProviderConfig(for: settings.selectedProvider) {
        if config.apiKey.isEmpty {
            config.apiKey = "sk-preview-key"
            settings.updateSTTProvider(config)
        }
    }
    return ContentView()
        .environmentObject(settings)
        .preferredColorScheme(.light)
}

#Preview("Home - Translation Enabled") {
    let settings = SharedSettings.shared
    settings.isTranslationEnabled = true
    settings.selectedMode = .email
    // Ensure API key is configured
    if var config = settings.getSTTProviderConfig(for: settings.selectedProvider) {
        if config.apiKey.isEmpty {
            config.apiKey = "sk-preview-key"
            settings.updateSTTProvider(config)
        }
    }
    return ContentView()
        .environmentObject(settings)
        .preferredColorScheme(.dark)
}

#Preview("Home - No API Key") {
    let settings = SharedSettings.shared
    // Clear the API key for the selected provider
    if var config = settings.getSTTProviderConfig(for: settings.selectedProvider) {
        config.apiKey = ""
        settings.updateSTTProvider(config)
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
