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
    @State private var translateOnRecord = false
    @State private var showPowerModeExecution = false
    @State private var selectedPowerModeId: UUID?

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home / Recording
            HomeView(showRecording: $showRecording, translateOnRecord: $translateOnRecord)
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

            // Power Mode
            PowerModeListView()
                .tabItem {
                    Image(systemName: "bolt.fill")
                    Text("Power")
                }
                .tag(2)

            // Settings
            SettingsView()
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
    @Binding var translateOnRecord: Bool
    @Environment(\.colorScheme) var colorScheme

    @State private var showModePicker = false
    @State private var showDefaultsSettings = false
    @State private var showProviderSetup = false

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
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

    private var settingsSummary: String {
        let provider = settings.selectedProvider.shortName
        let language = settings.selectedTargetLanguage.flag
        return "\(provider) → \(language)"
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
                                // Translate + Transcribe button (pink)
                                ActionButton(
                                    icon: "globe",
                                    label: "Translate",
                                    color: .pink,
                                    size: 72
                                ) {
                                    HapticManager.mediumTap()
                                    translateOnRecord = true
                                    showRecording = true
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

                            // Settings summary with gear button
                            HStack(spacing: 12) {
                                Text(settingsSummary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Button(action: {
                                    HapticManager.lightTap()
                                    showDefaultsSettings = true
                                }) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .padding(8)
                                        .background(
                                            Circle()
                                                .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                                        )
                                }
                            }
                        }
                    } else {
                        // Empty state - no API key configured
                        SetupRequiredView(
                            provider: settings.selectedProvider,
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
            .sheet(isPresented: $showModePicker) {
                ModePickerSheet(selectedMode: $settings.selectedMode)
                    .presentationDetents([.height(320)])
            }
            .sheet(isPresented: $showDefaultsSettings) {
                DefaultsSettingsSheet()
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showProviderSetup) {
                ProviderEditorSheet(
                    config: settings.getSTTProviderConfig(for: settings.selectedProvider) ?? STTProviderConfig(provider: settings.selectedProvider),
                    isEditing: true,
                    onSave: { updatedConfig in
                        settings.updateSTTProvider(updatedConfig)
                    },
                    onDelete: nil
                )
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
                    // Transcription Provider
                    Section {
                        HStack {
                            Label {
                                Text("Provider")
                            } icon: {
                                Image(systemName: settings.selectedProvider.icon)
                                    .foregroundStyle(AppTheme.accent)
                            }

                            Spacer()

                            Text(settings.selectedProvider.displayName)
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(rowBackground)
                    } header: {
                        Text("Transcription")
                    }

                    // Translation Settings
                    Section {
                        // Target Language
                        NavigationLink {
                            LanguagePickerView(selectedLanguage: $settings.selectedTargetLanguage)
                        } label: {
                            HStack {
                                Label {
                                    Text("Target Language")
                                } icon: {
                                    Text(settings.selectedTargetLanguage.flag)
                                }

                                Spacer()

                                Text(settings.selectedTargetLanguage.displayName)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(rowBackground)

                        // Translation LLM
                        Picker(selection: $settings.selectedTranslationProvider) {
                            ForEach(LLMProvider.allCases) { provider in
                                Text(provider.displayName).tag(provider)
                            }
                        } label: {
                            Label {
                                Text("AI Model")
                            } icon: {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.purple)
                            }
                        }
                        .listRowBackground(rowBackground)
                    } header: {
                        Text("Translation")
                    }

                    // Mode Settings
                    Section {
                        Picker(selection: $settings.selectedModeProvider) {
                            ForEach(LLMProvider.allCases) { provider in
                                Text(provider.displayName).tag(provider)
                            }
                        } label: {
                            Label {
                                Text("AI Model")
                            } icon: {
                                Image(systemName: "text.badge.star")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .listRowBackground(rowBackground)
                    } header: {
                        Text("Formatting Mode")
                    } footer: {
                        Text("Used when applying Email, Formal, or Casual formatting to your transcription.")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
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
        }
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

#Preview("Home - Email Mode") {
    let settings = SharedSettings.shared
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
