//
//  TranscriptionAISettingsView.swift
//  SwiftSpeak
//
//  Transcription & AI settings subpage - cloud models, local models, and provider defaults
//

import SwiftUI
import SwiftSpeakCore

struct TranscriptionAISettingsView: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme

    @State private var showPaywall = false
    @State private var showAddAIProvider = false
    @State private var showAddLocalModel = false
    @State private var showAppleTranslationSetup = false
    @State private var showSelfHostedLLMSetup = false
    @State private var editingAIProviderConfig: AIProviderConfig?
    @State private var isAddingNewAIProvider = false

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    // MARK: - Local Model Helpers

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

    /// Check if the current transcription provider supports streaming
    private var isStreamingProviderSelected: Bool {
        let provider = settings.selectedTranscriptionProvider
        return provider == .openAI || provider == .deepgram || provider == .assemblyAI || provider == .google || provider == .appleSpeech
    }

    private var networkQualityColor: Color {
        let quality = NetworkQualityMonitor.shared.recommendedQuality
        switch quality {
        case .high: return .green
        case .standard: return .yellow
        case .lowBandwidth: return .orange
        case .auto: return .green
        }
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

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            List {
                // Cloud Models Section
                cloudModelsSection

                // Local Models Section
                localModelsSection

                // Defaults Section
                defaultsSection

                // Recording Section
                recordingSection

                // Provider Data Section
                providerDataSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Transcription & AI")
        .navigationBarTitleDisplayMode(.large)
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
        .sheet(isPresented: $showAppleTranslationSetup) {
            NavigationStack {
                AppleTranslationSetupView()
            }
        }
        .sheet(isPresented: $showSelfHostedLLMSetup) {
            NavigationStack {
                AIProviderEditorSheet(
                    config: settings.getAIProviderConfig(for: .local) ?? AIProviderConfig(provider: .local),
                    isEditing: settings.getAIProviderConfig(for: .local) != nil,
                    onSave: { updatedConfig in
                        if settings.getAIProviderConfig(for: .local) != nil {
                            settings.updateAIProvider(updatedConfig)
                        } else {
                            settings.addAIProvider(updatedConfig)
                        }
                        showSelfHostedLLMSetup = false
                    },
                    onDelete: settings.getAIProviderConfig(for: .local) != nil ? {
                        settings.removeAIProvider(.local)
                        showSelfHostedLLMSetup = false
                    } : nil
                )
            }
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

    // MARK: - Cloud Models Section

    private var cloudModelsSection: some View {
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

                                Text("OpenAI, Anthropic, Gemini, and more")
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
            Text("Cloud Models")
        } footer: {
            if settings.subscriptionTier == .free {
                Text("Free tier includes one provider. Upgrade to Pro for multiple providers.")
            } else {
                Text("Cloud AI providers require internet and API keys. You only pay for what you use.")
            }
        }
    }

    // MARK: - Local Models Section

    private var localModelsSection: some View {
        Section {
            // WhisperKit Card
            WhisperKitCard(
                settings: settings,
                onDownload: { model in
                    startWhisperKitDownload(model: model)
                },
                onDelete: {
                    deleteWhisperKitModel()
                },
                onCancelDownload: {
                    cancelWhisperKitDownload()
                }
            )
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            // Apple Intelligence Card
            AppleIntelligenceCard(settings: settings)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            // Apple Translation Card
            AppleTranslationCard(
                settings: settings,
                onManageLanguages: {
                    showAppleTranslationSetup = true
                }
            )
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            // Self-Hosted LLM Card
            SelfHostedLLMCard(
                settings: settings,
                onConfigure: {
                    showSelfHostedLLMSetup = true
                }
            )
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } header: {
            HStack {
                Text("Local Models")
                Spacer()
                Text("Free")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
            }
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Process data on-device for privacy. No internet required once downloaded.")
                if settings.localModelStorageBytes > 0 {
                    Text("Storage used: \(settings.localModelStorageFormatted)")
                        .fontWeight(.medium)
                }
            }
        }
    }

    // MARK: - WhisperKit Actions

    private func startWhisperKitDownload(model: WhisperModel) {
        var config = settings.whisperKitConfig
        config.selectedModel = model
        config.status = .downloading
        config.downloadProgress = 0
        settings.whisperKitConfig = config

        // TODO: Connect to actual WhisperKit download
        // For now, simulate download progress
        Task { @MainActor in
            while settings.whisperKitConfig.downloadProgress < 1.0 && settings.whisperKitConfig.status == .downloading {
                try? await Task.sleep(nanoseconds: 100_000_000)
                var config = settings.whisperKitConfig
                config.downloadProgress += 0.02
                config.downloadedBytes = Int(Double(model.sizeBytes) * config.downloadProgress)
                settings.whisperKitConfig = config
            }

            if settings.whisperKitConfig.status == .downloading {
                var config = settings.whisperKitConfig
                config.status = .ready
                config.downloadProgress = 1.0
                config.downloadedBytes = model.sizeBytes
                config.lastDownloadDate = Date()
                settings.whisperKitConfig = config
                HapticManager.success()
            }
        }
    }

    private func cancelWhisperKitDownload() {
        var config = settings.whisperKitConfig
        config.status = .notConfigured
        config.downloadProgress = 0
        config.downloadedBytes = 0
        settings.whisperKitConfig = config
    }

    private func deleteWhisperKitModel() {
        var config = settings.whisperKitConfig
        config.status = .notConfigured
        config.isEnabled = false
        config.downloadProgress = 0
        config.downloadedBytes = 0
        config.lastDownloadDate = nil
        settings.whisperKitConfig = config
        HapticManager.lightTap()
    }

    // MARK: - Defaults Section

    private var defaultsSection: some View {
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
                            .font(.callout)
                            .foregroundStyle(.green)
                            .frame(width: 28, height: 28)
                            .background(Color.green.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

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
            Text("Defaults")
        } footer: {
            if settings.forcePrivacyMode {
                Text("All processing uses local models. Cloud providers are disabled.")
            } else {
                Text("Choose which provider to use for each capability. Power Modes can override these settings.")
            }
        }
    }

    // MARK: - Recording Section

    private var recordingSection: some View {
        Section {
            // Transcription Streaming
            Toggle(isOn: $settings.transcriptionStreamingEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Stream transcriptions")
                            .font(.callout)
                        Text("Beta")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppTheme.accent.opacity(0.8))
                            .clipShape(Capsule())
                    }
                    Text("Show transcription in real-time as you speak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if settings.transcriptionStreamingEnabled && !isStreamingProviderSelected {
                        Text("Current provider doesn't support streaming")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .tint(AppTheme.accent)
            .listRowBackground(rowBackground)

            // Auto-return
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

            // Audio Quality
            Picker(selection: $settings.audioQuality) {
                ForEach(AudioQualityMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recording Quality")
                        .font(.callout)
                    Text(settings.audioQuality.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.accent)
            .listRowBackground(rowBackground)

            if settings.audioQuality == .auto {
                HStack(spacing: 8) {
                    Image(systemName: "wifi")
                        .font(.callout)
                        .foregroundStyle(networkQualityColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Network Status")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(NetworkQualityMonitor.shared.networkStatusDescription)
                            .font(.caption)
                            .foregroundStyle(.primary)
                        Text("Current: \(NetworkQualityMonitor.shared.recommendedQuality.displayName)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(rowBackground)
            }
        } header: {
            Text("Recording")
        } footer: {
            Text("Configure how audio is recorded and transcriptions are delivered.")
        }
    }

    // MARK: - Provider Data Section

    private var providerDataSection: some View {
        Section {
            ProviderConfigurationRow()
                .listRowBackground(rowBackground)
        } header: {
            Text("Provider Data")
        } footer: {
            Text("Syncs pricing, models, languages, and capabilities from cloud. Auto-updates weekly.")
        }
    }
}

#Preview("Transcription & AI - Free") {
    NavigationStack {
        TranscriptionAISettingsView()
            .environmentObject({
                let settings = SharedSettings.shared
                settings.subscriptionTier = .free
                return settings
            }())
    }
}

#Preview("Transcription & AI - Power") {
    NavigationStack {
        TranscriptionAISettingsView()
            .environmentObject({
                let settings = SharedSettings.shared
                settings.subscriptionTier = .power
                return settings
            }())
    }
}
