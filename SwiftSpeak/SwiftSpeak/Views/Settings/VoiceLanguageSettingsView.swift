//
//  VoiceLanguageSettingsView.swift
//  SwiftSpeak
//
//  Voice & Language settings subpage - dictation, translation, and vocabulary
//

import SwiftUI
import SwiftSpeakCore

struct VoiceLanguageSettingsView: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme
    @State private var showPaywall = false
    @StateObject private var audioDeviceManager = AudioDeviceManager()

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
                // Microphone Section
                microphoneSection

                // Dictation Language Section
                dictationSection

                // Translation Section
                translationSection

                // Vocabulary Section
                vocabularySection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Voice & Language")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Microphone Section

    private var microphoneSection: some View {
        Section {
            Picker("Input Device", selection: $audioDeviceManager.selectedDevice) {
                ForEach(audioDeviceManager.availableDevices) { device in
                    HStack(spacing: 8) {
                        Image(systemName: device.deviceType.iconName)
                            .foregroundStyle(deviceIconColor(for: device))
                        Text(device.name)
                        if device.isDefault && !device.isSystemDefault {
                            Text("(Default)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(device as AudioInputDevice?)
                }
            }
            .listRowBackground(rowBackground)

            // Show current selection
            if let selected = audioDeviceManager.selectedDevice {
                HStack(spacing: 8) {
                    Image(systemName: selected.deviceType.iconName)
                        .foregroundStyle(.teal)
                    Text("Recording from: \(selected.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(rowBackground)
            }

            // Test microphone
            NavigationLink {
                MicrophoneTestView(audioDeviceManager: audioDeviceManager)
            } label: {
                Label("Test Microphone", systemImage: "waveform.badge.mic")
            }
            .listRowBackground(rowBackground)
        } header: {
            Text("Microphone")
        } footer: {
            Text("Select which microphone to use for voice recording. System Default uses the currently active input device.")
        }
    }

    private func deviceIconColor(for device: AudioInputDevice) -> Color {
        switch device.deviceType {
        case .airpods: return .blue
        case .bluetooth: return .purple
        case .builtIn: return .primary
        case .usb: return .green
        default: return .secondary
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
                    icon: "mic.fill",
                    iconColor: .blue,
                    title: "Dictation Language",
                    subtitle: settings.selectedDictationLanguage?.displayName ?? "Auto-detect"
                )
            }
            .listRowBackground(rowBackground)

            // Show Arabizi option only for Arabic/Egyptian Arabic
            if settings.shouldShowArabiziOption {
                Toggle(isOn: $settings.outputArabizi) {
                    SettingsRow(
                        icon: "character.textbox",
                        iconColor: .green,
                        title: "Franco-Arabic Output",
                        subtitle: "Convert Arabic to Latin letters"
                    )
                }
                .listRowBackground(rowBackground)
            }
        } header: {
            Text("Dictation")
        } footer: {
            if settings.shouldShowArabiziOption && settings.outputArabizi {
                Text("Set your primary speaking language for more accurate transcription. Franco-Arabic (Arabizi) converts Arabic script to Latin letters with numbers (e.g., 3=ع, 7=ح).")
            } else {
                Text("Set your primary speaking language for more accurate transcription. Auto-detect works best for multilingual speakers.")
            }
        }
    }

    // MARK: - Translation Section

    private var translationSection: some View {
        Section {
            if settings.subscriptionTier != .free {
                NavigationLink {
                    LanguagePickerView(
                        selectedLanguage: $settings.selectedTargetLanguage,
                        outputArabizi: $settings.outputArabizi
                    )
                } label: {
                    SettingsRow(
                        icon: "globe",
                        iconColor: .purple,
                        title: "Translation Language",
                        subtitle: "\(settings.selectedTargetLanguage.flag) \(settings.selectedTargetLanguage.displayName)"
                    )
                }
                .listRowBackground(rowBackground)
            } else {
                // Locked state for free users
                Button(action: {
                    showPaywall = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Translation Language")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)

                                TierBadge(tier: .pro)
                            }

                            Text("Translate to 50+ languages")
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
            } else {
                Text("Your transcriptions will be translated to this language when translation is enabled.")
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
                    subtitle: vocabularySubtitle
                )
            }
            .listRowBackground(rowBackground)
        } header: {
            Text("Recognition")
        } footer: {
            Text("Add names, companies, acronyms, and technical terms to improve transcription accuracy. The AI will learn to recognize these words.")
        }
    }

    private var vocabularySubtitle: String {
        if settings.vocabulary.isEmpty {
            return "Add words to improve recognition"
        } else {
            let count = settings.vocabulary.count
            return "\(count) word\(count == 1 ? "" : "s")"
        }
    }
}

#Preview("Voice & Language - Free") {
    NavigationStack {
        VoiceLanguageSettingsView()
            .environmentObject({
                let settings = SharedSettings.shared
                settings.subscriptionTier = .free
                return settings
            }())
    }
}

#Preview("Voice & Language - Pro") {
    NavigationStack {
        VoiceLanguageSettingsView()
            .environmentObject({
                let settings = SharedSettings.shared
                settings.subscriptionTier = .pro
                return settings
            }())
    }
}
