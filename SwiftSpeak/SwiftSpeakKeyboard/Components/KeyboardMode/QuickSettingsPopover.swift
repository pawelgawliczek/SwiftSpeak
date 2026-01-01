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
                        // Transcription/Spoken Language picker - most important setting
                        PickerRow(
                            title: "Spoken Language",
                            selection: $settings.spokenLanguage,
                            options: spokenLanguageOptions
                        )
                        .onChange(of: settings.spokenLanguage) { _, _ in
                            settings.save()
                            KeyboardHaptics.selection()
                        }

                        InfoRow(
                            title: "Provider",
                            value: settings.transcriptionProvider
                        )

                        if let contextName = settings.activeContextName {
                            InfoRow(
                                title: "Context",
                                value: contextName
                            )
                        }
                    }

                    // SECTION 2: Translation (translates complete transcription, not word-by-word)
                    if viewModel.isPro {
                        SettingsSection(title: "Translation") {
                            ToggleRow(title: "Auto-Translate", isOn: $settings.autoTranslate) {
                                settings.save()
                                KeyboardHaptics.lightTap()
                                viewModel.isTranslationEnabled = settings.autoTranslate
                            }

                            if settings.autoTranslate {
                                PickerRow(
                                    title: "To",
                                    selection: $settings.targetLanguage,
                                    options: languageOptions
                                )
                                .onChange(of: settings.targetLanguage) { _, _ in
                                    settings.save()
                                    KeyboardHaptics.selection()
                                }

                                // Explanation of how translation works
                                Text("Translates your complete transcription after recording")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.bottom, 8)
                            }
                        }
                    }

                    // SECTION 3: Keyboard Behavior
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
                        ToggleRow(title: "Swipe Typing", isOn: $settings.swipeTyping) {
                            settings.save()
                            KeyboardHaptics.lightTap()
                        }
                        ToggleRow(title: "Smart Punctuation", isOn: $settings.smartPunctuation) {
                            settings.save()
                            KeyboardHaptics.lightTap()
                        }
                    }

                    // SECTION 4: System Info
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
        .frame(width: UIScreen.main.bounds.width, height: 235)
        .background(
            LinearGradient(
                colors: [Color(white: 0.12), Color(white: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(0)
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

    private var languageOptions: [(String, String)] {
        [
            ("es", "Spanish"),
            ("fr", "French"),
            ("de", "German"),
            ("it", "Italian"),
            ("pt", "Portuguese"),
            ("ja", "Japanese"),
            ("ko", "Korean"),
            ("zh", "Chinese"),
            ("ru", "Russian"),
            ("ar", "Arabic")
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
