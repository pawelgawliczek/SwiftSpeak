//
//  TranscriptionAISettingsView.swift
//  SwiftSpeak
//
//  Transcription & AI settings subpage - cloud models, local models, and provider defaults
//

import SwiftUI

struct TranscriptionAISettingsView: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme

    @State private var showPaywall = false
    @State private var showAddAIProvider = false
    @State private var showAddLocalModel = false
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

                            Text("WhisperKit, Apple Intelligence, Ollama")
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
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Local Models")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)

                                TierBadge(tier: .power)
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
            Text("Local Models")
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
                Text("Upgrade to Power to use on-device AI for privacy and offline transcription.")
            }
        }
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
