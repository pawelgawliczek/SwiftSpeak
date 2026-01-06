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
    @Environment(\.dismiss) private var dismiss
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
        .chinese, .japanese, .korean, .arabic, .russian, .polish
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
        LanguagePickerView(selectedLanguage: .constant(.english))
    }
}

#Preview("Dictation Language Picker") {
    NavigationStack {
        DictationLanguagePickerView(selectedLanguage: .constant(nil))
    }
}
