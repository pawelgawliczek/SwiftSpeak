//
//  DefaultProvidersView.swift
//  SwiftSpeak
//
//  Default provider selection view
//

import SwiftUI

// MARK: - Default Providers View

struct DefaultProvidersView: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            List {
                // Transcription Section
                Section {
                    ProviderPickerRow(
                        category: .transcription,
                        selection: Binding(
                            get: { settings.providerDefaults.transcription },
                            set: { settings.providerDefaults.transcription = $0 }
                        ),
                        availableProviders: availableProviders(for: .transcription),
                        colorScheme: colorScheme
                    )
                    .listRowBackground(rowBackground)
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.blue)
                        Text("Transcription")
                    }
                } footer: {
                    Text("Provider used for speech-to-text conversion.")
                }

                // Translation Section
                Section {
                    ProviderPickerRow(
                        category: .translation,
                        selection: Binding(
                            get: { settings.providerDefaults.translation },
                            set: { settings.providerDefaults.translation = $0 }
                        ),
                        availableProviders: availableProviders(for: .translation),
                        colorScheme: colorScheme
                    )
                    .listRowBackground(rowBackground)
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .foregroundStyle(.purple)
                        Text("Translation")
                    }
                } footer: {
                    Text("Provider used for translating text between languages.")
                }

                // Power Mode Section
                Section {
                    ProviderPickerRow(
                        category: .powerMode,
                        selection: Binding(
                            get: { settings.providerDefaults.powerMode },
                            set: { settings.providerDefaults.powerMode = $0 }
                        ),
                        availableProviders: availableProviders(for: .powerMode),
                        colorScheme: colorScheme
                    )
                    .listRowBackground(rowBackground)
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.orange)
                        Text("Power Mode")
                    }
                } footer: {
                    Text("Provider used for AI formatting and Power Mode execution. Individual Power Modes can override this setting.")
                }

                // Fallback Settings
                Section {
                    Toggle(isOn: Binding(
                        get: { settings.providerDefaults.useLocalWhenOffline },
                        set: { settings.providerDefaults.useLocalWhenOffline = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use local when offline")
                                .font(.callout)
                            Text("Automatically switch to local models when no internet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(AppTheme.accent)
                    .listRowBackground(rowBackground)
                } header: {
                    Text("Fallback")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Default Providers")
    }

    private func availableProviders(for category: ProviderUsageCategory) -> [ProviderSelection] {
        var selections: [ProviderSelection] = []

        // Add configured cloud providers that support this category
        for config in settings.configuredAIProviders {
            if config.usageCategories.contains(category) {
                let model: String?
                switch category {
                case .transcription: model = config.transcriptionModel
                case .translation: model = config.translationModel
                case .powerMode: model = config.powerModeModel
                }
                selections.append(ProviderSelection(providerType: .cloud(config.provider), model: model))
            }
        }

        // Add local providers
        switch category {
        case .transcription:
            if settings.isWhisperKitReady {
                selections.append(ProviderSelection(
                    providerType: .local(.whisperKit),
                    model: settings.whisperKitConfig.selectedModel.displayName
                ))
            }
        case .translation:
            if settings.hasLocalTranslation {
                selections.append(ProviderSelection(providerType: .local(.appleTranslation)))
            }
        case .powerMode:
            if settings.isAppleIntelligenceReady {
                selections.append(ProviderSelection(providerType: .local(.appleIntelligence)))
            }
            if let localConfig = settings.getAIProviderConfig(for: .local),
               localConfig.usageCategories.contains(.powerMode) {
                selections.append(ProviderSelection(
                    providerType: .local(.ollama),
                    model: localConfig.powerModeModel
                ))
            }
        }

        return selections
    }
}

// MARK: - Provider Picker Row

struct ProviderPickerRow: View {
    let category: ProviderUsageCategory
    @Binding var selection: ProviderSelection?
    let availableProviders: [ProviderSelection]
    let colorScheme: ColorScheme

    private var categoryColor: Color {
        switch category {
        case .transcription: return .blue
        case .translation: return .purple
        case .powerMode: return .orange
        }
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color(.systemGray6)
    }

    var body: some View {
        if availableProviders.isEmpty {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: "exclamationmark.triangle")
                        .font(.body)
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("No providers configured")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Add a provider in AI Cloud Models")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } else {
            Menu {
                // Auto option first (this is the "clear selection" option)
                Button(action: {
                    HapticManager.selection()
                    selection = nil
                }) {
                    Label {
                        Text("Auto (First Available)")
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                }

                Divider()

                // Cloud providers section
                let cloudProviders = availableProviders.filter { !$0.isLocal }
                if !cloudProviders.isEmpty {
                    Section("Cloud") {
                        ForEach(cloudProviders, id: \.self) { providerSelection in
                            Button(action: {
                                HapticManager.selection()
                                selection = providerSelection
                            }) {
                                Label {
                                    Text(providerSelection.displayName)
                                } icon: {
                                    ProviderSelectionIcon(providerSelection, size: .small, style: .filled)
                                }
                            }
                        }
                    }
                }

                // Local providers section
                let localProviders = availableProviders.filter { $0.isLocal }
                if !localProviders.isEmpty {
                    Section("On-Device") {
                        ForEach(localProviders, id: \.self) { providerSelection in
                            Button(action: {
                                HapticManager.selection()
                                selection = providerSelection
                            }) {
                                Label {
                                    Text(providerSelection.displayName)
                                } icon: {
                                    ProviderSelectionIcon(providerSelection, size: .small, style: .filled)
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    // Provider icon with colored background
                    ProviderSelectionIcon(selection, size: .large, style: .filled, fallbackColor: categoryColor)

                    // Provider info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(providerDisplayName)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.primary)

                        if let selected = selection {
                            HStack(spacing: 4) {
                                if selected.isLocal {
                                    Image(systemName: "lock.shield.fill")
                                        .font(.caption2)
                                    Text("Private")
                                        .font(.caption)
                                } else {
                                    Image(systemName: "cloud.fill")
                                        .font(.caption2)
                                    Text("Cloud")
                                        .font(.caption)
                                }
                            }
                            .foregroundStyle(selected.isLocal ? .green : .secondary)
                        } else {
                            Text("Uses first configured provider")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Dropdown indicator pill
                    HStack(spacing: 4) {
                        Text(selection?.providerType.shortName ?? "Auto")
                            .font(.caption.weight(.medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(selection != nil ? .white : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selection != nil ? categoryColor : rowBackground)
                    )
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Computed Properties

    private var providerDisplayName: String {
        selection?.displayName ?? "Automatic"
    }
}

#Preview("Default Providers View") {
    NavigationStack {
        DefaultProvidersView()
            .environmentObject(SharedSettings.shared)
    }
}
