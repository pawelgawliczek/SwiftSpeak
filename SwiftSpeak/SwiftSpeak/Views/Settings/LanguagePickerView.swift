//
//  LanguagePickerView.swift
//  SwiftSpeak
//
//  Language selection views
//

import SwiftUI
import SwiftSpeakCore

// MARK: - Language Picker View

struct LanguagePickerView: View {
    @Binding var selectedLanguage: Language
    var outputArabizi: Binding<Bool>? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    /// Whether to show Arabizi option (only for Arabic languages)
    private var shouldShowArabiziOption: Bool {
        guard outputArabizi != nil else { return false }
        return selectedLanguage == .arabic || selectedLanguage == .egyptianArabic
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            List {
                ForEach(Language.allCases) { language in
                    Button(action: {
                        HapticManager.selection()
                        selectedLanguage = language
                    }) {
                        HStack {
                            Text(language.flag)
                                .font(.title2)

                            Text(language.displayName)
                                .foregroundStyle(.primary)

                            Spacer()

                            if selectedLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }
                    .listRowBackground(rowBackground)
                }

                // Arabizi toggle section (only for Arabic languages)
                if shouldShowArabiziOption, let arabiziBind = outputArabizi {
                    Section {
                        Toggle(isOn: arabiziBind) {
                            HStack(spacing: 12) {
                                Image(systemName: "character.textbox")
                                    .font(.callout)
                                    .foregroundStyle(.green)
                                    .frame(width: 28, height: 28)
                                    .background(Color.green.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Franco-Arabic Output")
                                        .font(.callout)
                                    Text("Convert to Latin letters")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(AppTheme.accent)
                        .listRowBackground(rowBackground)
                    } header: {
                        Text("Output Format")
                    } footer: {
                        Text("Arabizi converts Arabic script to Latin letters with numbers (e.g., 3=ع, 7=ح).")
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Target Language")
    }
}

// MARK: - Dictation Language Picker View

struct DictationLanguagePickerView: View {
    @Binding var selectedLanguage: Language?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    /// Languages supported by both OpenAI Whisper and Google Gemini
    private let supportedLanguages: [Language] = [
        .english, .spanish, .french, .german, .italian, .portuguese,
        .chinese, .japanese, .korean, .arabic, .egyptianArabic, .russian, .polish
    ]

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            List {
                // Auto-detect option
                Button(action: {
                    HapticManager.selection()
                    selectedLanguage = nil
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "waveform")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-detect")
                                .foregroundStyle(.primary)
                            Text("Let AI detect your language")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if selectedLanguage == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                }
                .listRowBackground(rowBackground)

                Section {
                    ForEach(supportedLanguages) { language in
                        Button(action: {
                            HapticManager.selection()
                            selectedLanguage = language
                            dismiss()
                        }) {
                            HStack {
                                Text(language.flag)
                                    .font(.title2)

                                Text(language.displayName)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if selectedLanguage == language {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                        }
                        .listRowBackground(rowBackground)
                    }
                } header: {
                    Text("Specific Language")
                } footer: {
                    Text("Selecting your language improves transcription accuracy and reduces errors.")
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Dictation Language")
    }
}

#Preview("Language Picker") {
    NavigationStack {
        LanguagePickerView(selectedLanguage: .constant(.english), outputArabizi: .constant(false))
    }
}

#Preview("Language Picker - Arabic") {
    NavigationStack {
        LanguagePickerView(selectedLanguage: .constant(.arabic), outputArabizi: .constant(false))
    }
}

#Preview("Dictation Language Picker") {
    NavigationStack {
        DictationLanguagePickerView(selectedLanguage: .constant(nil))
    }
}
