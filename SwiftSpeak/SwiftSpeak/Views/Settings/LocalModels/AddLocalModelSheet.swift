//
//  AddLocalModelSheet.swift
//  SwiftSpeak
//
//  Sheet for adding local models
//

import SwiftUI
import SwiftSpeakCore

// MARK: - Add Local Model Sheet

struct AddLocalModelSheet: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    // For configuring Ollama/LM Studio
    @State private var showingLocalProviderEditor = false
    @State private var localProviderConfig: AIProviderConfig?

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
                    // On-Device Section
                    Section {
                        // WhisperKit
                        if settings.whisperKitConfig.status != .ready {
                            NavigationLink {
                                WhisperKitSetupView()
                            } label: {
                                AddLocalModelOptionLabel(
                                    type: .whisperKit,
                                    title: "WhisperKit",
                                    description: "On-device speech recognition using OpenAI's Whisper model. Free and private.",
                                    badge: "RECOMMENDED",
                                    badgeColor: .green
                                )
                            }
                            .listRowBackground(rowBackground)
                        }

                        // Apple Intelligence
                        if settings.appleIntelligenceConfig.isAvailable && !settings.appleIntelligenceConfig.isEnabled {
                            NavigationLink {
                                AppleIntelligenceSetupView()
                            } label: {
                                AddLocalModelOptionLabel(
                                    type: .appleIntelligence,
                                    title: "Apple Intelligence",
                                    description: "iOS 18.5+ on-device text processing. No download required.",
                                    badge: nil,
                                    badgeColor: .clear
                                )
                            }
                            .listRowBackground(rowBackground)
                        }

                        // Apple Translation
                        NavigationLink {
                            AppleTranslationSetupView()
                        } label: {
                            AddLocalModelOptionLabel(
                                type: .appleTranslation,
                                title: "Apple Translation",
                                description: "System translation. Download language packs for offline use.",
                                badge: nil,
                                badgeColor: .clear
                            )
                        }
                        .listRowBackground(rowBackground)
                    } header: {
                        Text("On-Device (Recommended)")
                    } footer: {
                        Text("On-device models process data locally on your iPhone. No internet required after download.")
                    }

                    // Self-Hosted Section
                    Section {
                        // Ollama
                        Button(action: {
                            configureLocalProvider(type: .ollama)
                        }) {
                            AddLocalModelOptionLabel(
                                type: .ollama,
                                title: "Ollama",
                                description: "Connect to your self-hosted Ollama server for open-source LLMs.",
                                badge: "POWER",
                                badgeColor: .orange
                            )
                        }
                        .listRowBackground(rowBackground)

                        // LM Studio
                        Button(action: {
                            configureLocalProvider(type: .lmStudio)
                        }) {
                            AddLocalModelOptionLabel(
                                type: .lmStudio,
                                title: "LM Studio",
                                description: "Connect to LM Studio running on your Mac or PC.",
                                badge: "POWER",
                                badgeColor: .orange
                            )
                        }
                        .listRowBackground(rowBackground)

                        // OpenAI Compatible
                        Button(action: {
                            configureLocalProvider(type: .openAICompatible)
                        }) {
                            AddLocalModelOptionLabel(
                                type: .ollama,  // Uses same icon
                                title: "OpenAI Compatible",
                                description: "Connect to any server with OpenAI-compatible API.",
                                badge: "POWER",
                                badgeColor: .orange
                            )
                        }
                        .listRowBackground(rowBackground)
                    } header: {
                        Text("Self-Hosted")
                    } footer: {
                        Text("Self-hosted models require a server running on your local network. Power subscription required.")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Local Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $localProviderConfig) { config in
                AIProviderEditorSheet(
                    config: config,
                    isEditing: false,
                    onSave: { updatedConfig in
                        settings.addAIProvider(updatedConfig)
                        localProviderConfig = nil
                        dismiss()
                    },
                    onDelete: {
                        localProviderConfig = nil
                    }
                )
            }
        }
    }

    private func configureLocalProvider(type: LocalProviderType) {
        HapticManager.selection()
        // Create a new local provider config with the selected type
        var config = AIProviderConfig(provider: .local)
        config.localConfig = LocalProviderConfig(
            type: type,
            baseURL: type.defaultURL,
            defaultModel: type.defaultModel
        )
        // Set default usage categories
        config.usageCategories = [.powerMode]
        localProviderConfig = config
    }
}

// MARK: - Add Local Model Option Label (for NavigationLink)

struct AddLocalModelOptionLabel: View {
    let type: LocalModelType
    let title: String
    let description: String
    let badge: String?
    let badgeColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.title3)
                .foregroundStyle(type.isOnDevice ? .green : .orange)
                .frame(width: 40, height: 40)
                .background((type.isOnDevice ? Color.green : Color.orange).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)

                    if let badge = badge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(badgeColor)
                            .clipShape(Capsule())
                    }
                }

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
    }
}

// MARK: - Add Local Model Option Row

struct AddLocalModelOptionRow: View {
    let type: LocalModelType
    let title: String
    let description: String
    let badge: String?
    let badgeColor: Color
    let colorScheme: ColorScheme
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.selection()
            onTap()
        }) {
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.title3)
                    .foregroundStyle(type.isOnDevice ? .green : .orange)
                    .frame(width: 40, height: 40)
                    .background((type.isOnDevice ? Color.green : Color.orange).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.primary)

                        if let badge = badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(badgeColor)
                                .clipShape(Capsule())
                        }
                    }

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(type.isOnDevice ? .green : .orange)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview("Add Local Model Sheet") {
    AddLocalModelSheet()
        .environmentObject(SharedSettings.shared)
}
