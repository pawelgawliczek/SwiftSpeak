//
//  QuickSettingsPopover.swift
//  SwiftSpeakKeyboard
//
//  Phase 13.10: Quick settings popover accessible from keyboard
//

import SwiftUI
import Combine

// MARK: - Quick Settings Popover
struct QuickSettingsPopover: View {
    @Binding var settings: KeyboardSettings
    @ObservedObject var viewModel: KeyboardViewModel
    let onDismiss: () -> Void

    // Available transcription providers from configured providers
    private var availableProviders: [(String, String)] {
        var providers: [(String, String)] = []
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        let configuredProviders = defaults?.stringArray(forKey: "configuredProviderIds") ?? []

        for providerId in configuredProviders {
            switch providerId {
            case "openAI": providers.append(("openAI", "OpenAI"))
            case "deepgram": providers.append(("deepgram", "Deepgram"))
            case "assemblyAI": providers.append(("assemblyAI", "AssemblyAI"))
            case "elevenLabs": providers.append(("elevenLabs", "ElevenLabs"))
            case "google": providers.append(("google", "Google"))
            case "local": providers.append(("local", "On-Device"))
            default: break
            }
        }

        // If no providers configured, show at least OpenAI as option
        if providers.isEmpty {
            providers.append(("openAI", "OpenAI"))
        }

        return providers
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Quick Settings")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button(action: {
                    KeyboardHaptics.lightTap()
                    settings.save()
                    onDismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))

            ScrollView {
                VStack(spacing: 16) {
                    // SECTION 1: Voice Settings (at top as requested)
                    SettingsSection(title: "Voice") {
                        // Provider picker
                        PickerRow(
                            title: "Provider",
                            selection: Binding(
                                get: { settings.transcriptionProvider.lowercased().replacingOccurrences(of: " ", with: "") },
                                set: { newValue in
                                    settings.transcriptionProvider = availableProviders.first { $0.0 == newValue }?.1 ?? newValue
                                    settings.save()
                                    KeyboardHaptics.selection()
                                }
                            ),
                            options: availableProviders
                        )

                        // Transcription/Spoken Language picker
                        PickerRow(
                            title: "Spoken Language",
                            selection: $settings.spokenLanguage,
                            options: spokenLanguageOptions
                        )
                        .onChange(of: settings.spokenLanguage) { _, _ in
                            settings.save()
                            KeyboardHaptics.selection()
                        }
                    }

                    // SECTION 2: Keyboard Behavior
                    SettingsSection(title: "Keyboard") {
                        ToggleRow(title: "Haptic Feedback", isOn: $settings.hapticFeedback) {
                            settings.save()
                            KeyboardHaptics.lightTap()
                        }
                        ToggleRow(title: "AI Predictions", isOn: $settings.aiPredictions) {
                            settings.save()
                            KeyboardHaptics.lightTap()
                            viewModel.objectWillChange.send()
                        }
                        ToggleRow(title: "Autocorrect", isOn: $settings.autocorrect) {
                            settings.save()
                            KeyboardHaptics.lightTap()
                        }
                        ToggleRow(title: "Smart Punctuation", isOn: $settings.smartPunctuation) {
                            settings.save()
                            KeyboardHaptics.lightTap()
                        }
                    }

                    // SECTION 3: System Info
                    SettingsSection(title: "System") {
                        InfoRow(
                            title: "Subscription",
                            value: settings.subscriptionTier.capitalized
                        )

                        if settings.swiftLinkActive {
                            InfoRow(
                                title: "SwiftLink",
                                value: "Active",
                                valueColor: .green
                            )
                        }
                    }

                    // Open Full Settings button
                    Button(action: openMainAppSettings) {
                        HStack {
                            Image(systemName: "gear")
                                .font(.system(size: 14))
                            Text("Open Full Settings")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundStyle(KeyboardTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(white: 0.12), Color(white: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .shadow(color: .black.opacity(0.3), radius: 10, y: -2)
    }

    private var spokenLanguageOptions: [(String, String)] {
        [
            ("en", "English"),
            ("es", "Spanish"),
            ("fr", "French"),
            ("de", "German"),
            ("it", "Italian"),
            ("pt", "Portuguese"),
            ("pl", "Polish"),
            ("nl", "Dutch"),
            ("ja", "Japanese"),
            ("ko", "Korean"),
            ("zh", "Chinese"),
            ("ru", "Russian"),
            ("ar", "Arabic"),
            ("hi", "Hindi"),
            ("auto", "Auto-detect")
        ]
    }

    private func openMainAppSettings() {
        KeyboardHaptics.mediumTap()
        settings.save()
        if let url = URL(string: "swiftspeak://settings") {
            viewModel.openAppURL(url)
        }
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                content
            }
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

// MARK: - Toggle Row
struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var onChange: (() -> Void)? = nil

    var body: some View {
        Toggle(title, isOn: $isOn)
            .font(.callout)
            .foregroundStyle(.white)
            .tint(KeyboardTheme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .onChange(of: isOn) { _, _ in
                onChange?()
            }
    }
}

// MARK: - Picker Row
struct PickerRow: View {
    let title: String
    @Binding var selection: String
    let options: [(String, String)]  // (value, label)

    var body: some View {
        HStack {
            Text(title)
                .font(.callout)
                .foregroundStyle(.white)

            Spacer()

            Picker("", selection: $selection) {
                ForEach(options, id: \.0) { option in
                    Text(option.1).tag(option.0)
                }
            }
            .pickerStyle(.menu)
            .tint(KeyboardTheme.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let title: String
    let value: String
    var valueColor: Color = .secondary

    var body: some View {
        HStack {
            Text(title)
                .font(.callout)
                .foregroundStyle(.white)

            Spacer()

            Text(value)
                .font(.callout)
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Preview
#Preview {
    QuickSettingsPopover(
        settings: .constant(KeyboardSettings.load()),
        viewModel: KeyboardViewModel(),
        onDismiss: {}
    )
    .preferredColorScheme(.dark)
}
