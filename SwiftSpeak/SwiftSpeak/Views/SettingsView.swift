//
//  SettingsView.swift
//  SwiftSpeak
//
//  App settings and configuration
//

import AVFoundation
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme
    @State private var showPaywall = false
    @State private var showAddAIProvider = false
    @State private var showAddLocalModel = false
    @State private var editingAIProviderConfig: AIProviderConfig?
    @State private var isAddingNewAIProvider = false
    @State private var showResetAllConfirmation = false

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    private var webhooksSubtitle: String {
        let count = settings.webhooks.count
        if count == 0 {
            return "No webhooks configured"
        } else {
            return "\(count) webhook\(count == 1 ? "" : "s") configured"
        }
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

    // MARK: - Phase 10: Local Model Helpers

    private var whisperKitSubtitle: String {
        switch settings.whisperKitConfig.status {
        case .notConfigured:
            return "Tap to set up"
        case .downloading:
            let progress = Int(settings.whisperKitConfig.downloadProgress * 100)
            return "Downloading... \(progress)%"
        case .ready:
            return settings.whisperKitConfig.selectedModel.displayName
        case .notAvailable:
            return "Not available on this device"
        case .error:
            return "Error - tap to retry"
        }
    }

    private var appleIntelligenceStatus: LocalModelStatus {
        if !settings.appleIntelligenceConfig.isAvailable {
            return .notAvailable
        }
        return settings.appleIntelligenceConfig.isEnabled ? .ready : .notConfigured
    }

    private var appleIntelligenceSubtitle: String {
        if !settings.appleIntelligenceConfig.isAvailable {
            return settings.appleIntelligenceConfig.unavailableReason ?? "Requires iPhone 15 Pro or later"
        }
        return settings.appleIntelligenceConfig.isEnabled ? "Enabled" : "Tap to enable"
    }

    private var appleTranslationStatus: LocalModelStatus {
        if !settings.appleTranslationConfig.isAvailable {
            return .notAvailable
        }
        let downloadedCount = settings.appleTranslationConfig.downloadedLanguages.count
        return downloadedCount > 0 ? .ready : .notConfigured
    }

    private var appleTranslationSubtitle: String {
        if !settings.appleTranslationConfig.isAvailable {
            return "Requires iOS 17.4+"
        }
        let downloadedCount = settings.appleTranslationConfig.downloadedLanguages.count
        if downloadedCount == 0 {
            return "No languages downloaded"
        }
        return "\(downloadedCount) language\(downloadedCount == 1 ? "" : "s") downloaded"
    }

    private var defaultProvidersSubtitle: String {
        var parts: [String] = []
        if let transcription = settings.providerDefaults.transcription {
            parts.append(transcription.providerType.shortName)
        }
        if parts.isEmpty {
            return "Using defaults"
        }
        return parts.joined(separator: ", ")
    }

    private func localModelTypeFromConfig(_ config: LocalProviderConfig) -> LocalModelType {
        switch config.type {
        case .ollama: return .ollama
        case .lmStudio: return .lmStudio
        case .openAICompatible: return .ollama
        }
    }

    private var hasAnyLocalModel: Bool {
        settings.whisperKitConfig.status == .ready ||
        settings.whisperKitConfig.status == .downloading ||
        settings.appleIntelligenceConfig.isEnabled ||
        !settings.appleTranslationConfig.downloadedLanguages.isEmpty ||
        settings.getAIProviderConfig(for: .local)?.localConfig != nil
    }

    // MARK: - Phase 6: Biometric Properties

    private var biometricAvailable: Bool {
        BiometricAuthManager.shared.isBiometricAvailable
    }

    private var biometricName: String {
        BiometricAuthManager.shared.biometricName
    }

    private var biometricIcon: String {
        BiometricAuthManager.shared.biometricIcon
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                List {
                    // Subscription Section
                    Section {
                        SubscriptionCard(tier: settings.subscriptionTier) {
                            showPaywall = true
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }

                    // Unified AI Models Section
                    aiCloudModelsSection

                    // AI Local Models Section (Phase 10) - Requires Power tier
                    aiLocalModelsSection

                    // Default Providers Section (Phase 10)
                    providerPreferencesSection

                    // Provider Configuration Section (Phase 9)
                    Section {
                        ProviderConfigurationRow()
                            .listRowBackground(rowBackground)
                    } header: {
                        Text("Provider Data")
                    } footer: {
                        Text("Syncs pricing, models, languages, and capabilities from cloud. Auto-updates weekly.")
                    }

                    // Dictation Language Section
                    dictationSection

                    // Language Section - Requires Pro tier
                    translationSection

                    // Vocabulary Section
                    vocabularySection

                    // Memory Section - Requires Power tier
                    memorySection

                    // App Library Section - Requires Pro tier
                    appLibrarySection

                    // Webhooks Section - Requires Power tier
                    webhooksSection

                    // Behavior Section
                    behaviorSection

                    // Advanced Section
                    advancedSection

                    // Usage & Costs Section
                    usageCostsSection

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
            .sheet(isPresented: $showAddAIProvider) {
                AddAIProviderSheet(
                    availableProviders: settings.availableProvidersToAdd,
                    currentTier: settings.subscriptionTier,
                    onSelect: { provider in
                        showAddAIProvider = false
                        isAddingNewAIProvider = true
                        editingAIProviderConfig = AIProviderConfig(provider: provider)
                    },
                    onShowPaywall: {
                        showPaywall = true
                    }
                )
            }
            .sheet(isPresented: $showAddLocalModel) {
                AddLocalModelSheet()
            }
            .sheet(item: $editingAIProviderConfig) { config in
                AIProviderEditorSheet(
                    config: config,
                    isEditing: !isAddingNewAIProvider,
                    onSave: { updatedConfig in
                        if isAddingNewAIProvider {
                            settings.addAIProvider(updatedConfig)
                        } else {
                            settings.updateAIProvider(updatedConfig)
                        }
                        editingAIProviderConfig = nil
                    },
                    onDelete: isAddingNewAIProvider ? nil : {
                        if let config = editingAIProviderConfig {
                            settings.removeAIProvider(config.provider)
                        }
                        editingAIProviderConfig = nil
                    }
                )
            }
        }
    }

    // MARK: - AI Cloud Models Section

    private var aiCloudModelsSection: some View {
        Section {
            if settings.subscriptionTier == .free {
                // Free tier: Show OpenAI and Gemini directly
                let hasConfiguredProvider = settings.configuredAIProviders.contains {
                    ($0.provider == .openAI || $0.provider == .google) && !$0.apiKey.isEmpty
                }
                let configuredProvider = settings.configuredAIProviders.first {
                    ($0.provider == .openAI || $0.provider == .google) && !$0.apiKey.isEmpty
                }?.provider

                // OpenAI row
                FreeProviderRow(
                    provider: .openAI,
                    existingConfig: settings.getAIProviderConfig(for: .openAI),
                    isDisabled: hasConfiguredProvider && configuredProvider != .openAI,
                    colorScheme: colorScheme,
                    onTap: {
                        if hasConfiguredProvider && configuredProvider != .openAI {
                            showPaywall = true
                        } else {
                            isAddingNewAIProvider = settings.getAIProviderConfig(for: .openAI) == nil
                            editingAIProviderConfig = settings.getAIProviderConfig(for: .openAI) ?? AIProviderConfig(provider: .openAI)
                        }
                    }
                )
                .listRowBackground(rowBackground)

                // Gemini row
                FreeProviderRow(
                    provider: .google,
                    existingConfig: settings.getAIProviderConfig(for: .google),
                    isDisabled: hasConfiguredProvider && configuredProvider != .google,
                    colorScheme: colorScheme,
                    onTap: {
                        if hasConfiguredProvider && configuredProvider != .google {
                            showPaywall = true
                        } else {
                            isAddingNewAIProvider = settings.getAIProviderConfig(for: .google) == nil
                            editingAIProviderConfig = settings.getAIProviderConfig(for: .google) ?? AIProviderConfig(provider: .google)
                        }
                    }
                )
                .listRowBackground(rowBackground)
            } else {
                // Pro/Power tier: Show all configured providers + Add button
                ForEach(settings.configuredAIProviders) { config in
                    ConfiguredAIProviderRow(
                        config: config,
                        colorScheme: colorScheme
                    ) {
                        isAddingNewAIProvider = false
                        editingAIProviderConfig = config
                    }
                    .listRowBackground(rowBackground)
                }

                // Add AI Provider button
                if !settings.availableProvidersToAdd.isEmpty {
                    Button(action: {
                        showAddAIProvider = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(AppTheme.accent)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Add AI Provider")
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(.primary)

                                Text("Add transcription, translation & power mode providers")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }
                    .listRowBackground(rowBackground)
                }
            }
        } header: {
            Text("AI Cloud Models")
        } footer: {
            if settings.subscriptionTier == .free {
                Text("Free tier includes one provider. Upgrade to Pro for multiple providers.")
            } else {
                Text("Configure cloud AI providers. Requires internet connection and API keys.")
            }
        }
    }

    // MARK: - AI Local Models Section

    private var aiLocalModelsSection: some View {
        Section {
            if settings.subscriptionTier == .power {
                // Only show WhisperKit if configured (ready or downloading)
                if settings.whisperKitConfig.status == .ready || settings.whisperKitConfig.status == .downloading {
                    NavigationLink {
                        WhisperKitSetupView()
                    } label: {
                        LocalModelRow(
                            type: .whisperKit,
                            status: settings.whisperKitConfig.status,
                            subtitle: whisperKitSubtitle,
                            colorScheme: colorScheme
                        ) { }
                    }
                    .listRowBackground(rowBackground)
                }

                // Only show Apple Intelligence if enabled
                if settings.appleIntelligenceConfig.isEnabled {
                    NavigationLink {
                        AppleIntelligenceSetupView()
                    } label: {
                        LocalModelRow(
                            type: .appleIntelligence,
                            status: appleIntelligenceStatus,
                            subtitle: appleIntelligenceSubtitle,
                            colorScheme: colorScheme
                        ) { }
                    }
                    .listRowBackground(rowBackground)
                }

                // Only show Apple Translation if there are downloaded languages
                if !settings.appleTranslationConfig.downloadedLanguages.isEmpty {
                    NavigationLink {
                        AppleTranslationSetupView()
                    } label: {
                        LocalModelRow(
                            type: .appleTranslation,
                            status: appleTranslationStatus,
                            subtitle: appleTranslationSubtitle,
                            colorScheme: colorScheme
                        ) { }
                    }
                    .listRowBackground(rowBackground)
                }

                // Ollama/LM Studio (if configured)
                if let localConfig = settings.getAIProviderConfig(for: .local)?.localConfig {
                    LocalModelRow(
                        type: localModelTypeFromConfig(localConfig),
                        status: .ready,
                        subtitle: localConfig.baseURL,
                        colorScheme: colorScheme
                    ) {
                        isAddingNewAIProvider = false
                        editingAIProviderConfig = settings.getAIProviderConfig(for: .local)
                    }
                    .listRowBackground(rowBackground)
                }

                // Add Local Model button
                Button(action: {
                    showAddLocalModel = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add Local Model")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.primary)

                            Text("Set up on-device or self-hosted AI")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }
                .listRowBackground(rowBackground)
            } else {
                // Locked state for non-Power users
                Button(action: {
                    showPaywall = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "cpu")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Local Models")
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(.secondary)

                                Text("POWER")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .clipShape(Capsule())
                            }

                            Text("On-device AI for privacy and offline use")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(rowBackground)
            }
        } header: {
            Text("AI Local Models")
        } footer: {
            if settings.subscriptionTier == .power {
                VStack(alignment: .leading, spacing: 4) {
                    if hasAnyLocalModel {
                        Text("Process data on-device for privacy. No internet required once downloaded.")
                        if settings.localModelStorageBytes > 0 {
                            Text("Storage used: \(settings.localModelStorageFormatted)")
                                .fontWeight(.medium)
                        }
                    } else {
                        Text("Add on-device models for privacy and offline use.")
                    }
                }
            } else {
                Text("Upgrade to Power to use on-device AI models for privacy and offline transcription.")
            }
        }
    }

    // MARK: - Provider Preferences Section

    private var providerPreferencesSection: some View {
        Section {
            NavigationLink {
                DefaultProvidersView()
            } label: {
                SettingsRow(
                    icon: "slider.horizontal.3",
                    iconColor: .indigo,
                    title: "Default Providers",
                    subtitle: defaultProvidersSubtitle
                )
            }
            .listRowBackground(rowBackground)

            // Only show Privacy Mode toggle when local providers are available
            if settings.canEnablePrivacyMode {
                Toggle(isOn: $settings.forcePrivacyMode) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Privacy Mode")
                                .font(.callout)
                            Text("Force local-only processing")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.green)
                .listRowBackground(rowBackground)
            }
        } header: {
            Text("Provider Preferences")
        } footer: {
            if settings.forcePrivacyMode {
                Text("All processing will use local models. Cloud providers are disabled.")
            } else {
                Text("Choose which provider to use for each capability. Power Modes can override these settings.")
            }
        }
    }

    // MARK: - Dictation Section

    private var dictationSection: some View {
        Section {
            NavigationLink {
                DictationLanguagePickerView(selectedLanguage: Binding(
                    get: { settings.selectedDictationLanguage },
                    set: { settings.selectedDictationLanguage = $0 }
                ))
            } label: {
                SettingsRow(
                    icon: "mic",
                    iconColor: .blue,
                    title: "Dictation Language",
                    subtitle: settings.selectedDictationLanguage?.displayName ?? "Auto-detect"
                )
            }
            .listRowBackground(rowBackground)
        } header: {
            Text("Dictation")
        } footer: {
            Text("Set your primary speaking language for more accurate transcription. Auto-detect works best for multilingual speakers.")
        }
    }

    // MARK: - Translation Section

    private var translationSection: some View {
        Section {
            if settings.subscriptionTier != .free {
                NavigationLink {
                    LanguagePickerView(selectedLanguage: $settings.selectedTargetLanguage)
                } label: {
                    HStack {
                        SettingsRow(
                            icon: "globe",
                            iconColor: .purple,
                            title: "Translation Language",
                            subtitle: "\(settings.selectedTargetLanguage.flag) \(settings.selectedTargetLanguage.displayName)"
                        )
                    }
                }
                .listRowBackground(rowBackground)
            } else {
                // Locked state for free users
                Button(action: {
                    showPaywall = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Translation")
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(.secondary)

                                Text("PRO")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.accent)
                                    .clipShape(Capsule())
                            }

                            Text("Translate transcriptions to 50+ languages")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(rowBackground)
            }
        } header: {
            Text("Translation")
        } footer: {
            if settings.subscriptionTier == .free {
                Text("Upgrade to Pro to translate your transcriptions to 50+ languages.")
            }
        }
    }

    // MARK: - Vocabulary Section

    private var vocabularySection: some View {
        Section {
            NavigationLink {
                VocabularyView()
            } label: {
                SettingsRow(
                    icon: "character.book.closed.fill",
                    iconColor: .teal,
                    title: "Vocabulary",
                    subtitle: settings.vocabulary.isEmpty ? "Add words to improve recognition" : "\(settings.vocabulary.count) words"
                )
            }
            .listRowBackground(rowBackground)
        } header: {
            Text("Recognition")
        } footer: {
            Text("Add names, companies, acronyms, and slang to improve transcription accuracy.")
        }
    }

    // MARK: - Memory Section

    private var memorySection: some View {
        Section {
            if settings.subscriptionTier == .power {
                NavigationLink {
                    MemoryView()
                } label: {
                    SettingsRow(
                        icon: "brain.head.profile",
                        iconColor: .pink,
                        title: "Memory",
                        subtitle: "History, workflow & context memory"
                    )
                }
                .listRowBackground(rowBackground)
            } else {
                // Locked state for non-Power users
                Button(action: {
                    showPaywall = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Memory")
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(.secondary)

                                Text("POWER")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .clipShape(Capsule())
                            }

                            Text("AI remembers context across conversations")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(rowBackground)
            }
        } header: {
            Text("Memory")
        } footer: {
            if settings.subscriptionTier == .power {
                Text("View and manage AI memory for history, Power Modes, and Contexts.")
            } else {
                Text("Upgrade to Power for AI memory that learns your preferences and context.")
            }
        }
    }

    // MARK: - App Library Section

    private var appLibrarySection: some View {
        Section {
            if settings.subscriptionTier != .free {
                NavigationLink {
                    AppLibraryView()
                } label: {
                    SettingsRow(
                        icon: "square.grid.2x2",
                        iconColor: .indigo,
                        title: "App Library",
                        subtitle: "Manage app categories for auto-enable"
                    )
                }
                .listRowBackground(rowBackground)
            } else {
                // Locked state for free users
                Button(action: {
                    showPaywall = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("App Library")
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(.secondary)

                                Text("PRO")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.accent)
                                    .clipShape(Capsule())
                            }

                            Text("Auto-enable modes based on which app you're in")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(rowBackground)
            }
        } header: {
            Text("Apps")
        } footer: {
            if settings.subscriptionTier != .free {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reassign apps to different categories. Contexts and Power Modes can auto-enable based on app categories.")
                    Text("Manual selection always takes precedence over app auto-enable.")
                        .fontWeight(.medium)
                }
            } else {
                Text("Upgrade to Pro for automatic mode switching based on which app you're using.")
            }
        }
    }

    // MARK: - Webhooks Section

    private var webhooksSection: some View {
        Section {
            if settings.subscriptionTier == .power {
                NavigationLink {
                    WebhooksView()
                } label: {
                    SettingsRow(
                        icon: "link",
                        iconColor: .cyan,
                        title: "Webhooks",
                        subtitle: webhooksSubtitle
                    )
                }
                .listRowBackground(rowBackground)
            } else {
                // Locked state for non-Power users
                Button(action: {
                    showPaywall = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "link")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Webhooks")
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(.secondary)

                                Text("POWER")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .clipShape(Capsule())
                            }

                            Text("Connect to Slack, Notion, Make, or Zapier")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(rowBackground)
            }
        } header: {
            Text("Integrations")
        } footer: {
            if settings.subscriptionTier == .power {
                Text("Connect Power Modes to external services like Slack, Notion, Make, or Zapier.")
            } else {
                Text("Upgrade to Power to automate workflows with webhooks and integrations.")
            }
        }
    }

    // MARK: - Behavior Section

    private var behaviorSection: some View {
        Section {
            Toggle(isOn: $settings.autoReturnEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-return after transcription")
                        .font(.callout)
                    Text("Automatically dismiss after copying to clipboard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(AppTheme.accent)
            .listRowBackground(rowBackground)

            Toggle(isOn: $settings.powerModeStreamingEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stream Power Mode responses")
                        .font(.callout)
                    Text("Show text as it's generated instead of waiting for completion")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(AppTheme.powerAccent)
            .listRowBackground(rowBackground)
        } header: {
            Text("Behavior")
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        Section {
            // Retry Settings
            NavigationLink {
                RetrySettingsView()
            } label: {
                SettingsRow(
                    icon: "arrow.clockwise",
                    iconColor: .blue,
                    title: "Retry Settings",
                    subtitle: settings.autoRetryEnabled ? "Auto-retry enabled" : "Auto-retry disabled"
                )
            }
            .listRowBackground(rowBackground)

            // Token Limits
            NavigationLink {
                AdvancedTokenLimitsView()
            } label: {
                SettingsRow(
                    icon: "slider.horizontal.3",
                    iconColor: .purple,
                    title: "Token Limits",
                    subtitle: "Configure AI context window usage"
                )
            }
            .listRowBackground(rowBackground)

            // Diagnostics
            NavigationLink {
                DiagnosticsView()
            } label: {
                SettingsRow(
                    icon: "stethoscope",
                    iconColor: .teal,
                    title: "Diagnostics",
                    subtitle: "View and export activity logs"
                )
            }
            .listRowBackground(rowBackground)

            // Security & Privacy
            NavigationLink {
                SecurityPrivacyView()
            } label: {
                SettingsRow(
                    icon: "lock.shield",
                    iconColor: .green,
                    title: "Security & Privacy",
                    subtitle: settings.biometricProtectionEnabled ? "\(biometricName) enabled" : "Tap to configure"
                )
            }
            .listRowBackground(rowBackground)
        } header: {
            Text("Advanced")
        } footer: {
            Text("Fine-tune retry behavior, AI limits, diagnostics, and security settings.")
        }
    }

    // MARK: - Usage & Costs Section

    private var usageCostsSection: some View {
        Section {
            NavigationLink {
                CostAnalyticsView()
            } label: {
                SettingsRow(
                    icon: "chart.pie.fill",
                    iconColor: .green,
                    title: "Cost Analytics",
                    subtitle: "View usage costs and statistics"
                )
            }
            .listRowBackground(rowBackground)
        } header: {
            Text("Usage & Costs")
        } footer: {
            Text("Track your API usage costs across providers.")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            SettingsRow(
                icon: "info.circle",
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
                SettingsRow(
                    icon: "hand.raised",
                    iconColor: .green,
                    title: "Privacy Policy",
                    subtitle: nil
                )
            }
            .listRowBackground(rowBackground)

            Button(action: {
                if let url = URL(string: "https://swiftspeak.app/terms") {
                    UIApplication.shared.open(url)
                }
            }) {
                SettingsRow(
                    icon: "doc.plaintext",
                    iconColor: .gray,
                    title: "Terms of Service",
                    subtitle: nil
                )
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
