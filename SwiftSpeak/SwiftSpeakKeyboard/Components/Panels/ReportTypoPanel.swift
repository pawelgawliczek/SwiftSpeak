//
//  ReportTypoPanel.swift
//  SwiftSpeakKeyboard
//
//  Panel for reporting missed autocorrections.
//  User enters the misspelled word and the correct spelling.
//

import SwiftUI

struct ReportTypoPanel: View {
    @ObservedObject var viewModel: KeyboardViewModel
    let onDismiss: () -> Void

    @State private var misspelledWord: String = ""
    @State private var correctWord: String = ""
    @State private var isSubmitting = false

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Report Missed Correction")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Instructions
            Text("Enter the word you typed and what it should have been")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 16)

            // Input fields
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Typed")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))

                    TextField("misspeled", text: $misspelledWord)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Should be")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))

                    TextField("misspelled", text: $correctWord)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .padding(.horizontal, 16)

            // Buttons
            HStack(spacing: 12) {
                Button(action: onDismiss) {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }

                Button(action: submitReport) {
                    HStack(spacing: 6) {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 12))
                        }
                        Text("Report")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        canSubmit ? Color.orange : Color.orange.opacity(0.3),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
                .disabled(!canSubmit || isSubmitting)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Color(white: 0.12))
        .onAppear {
            // Pre-fill with the word from context if available
            if !viewModel.reportTypoOriginalWord.isEmpty {
                misspelledWord = viewModel.reportTypoOriginalWord
            }
        }
    }

    private var canSubmit: Bool {
        !misspelledWord.trimmingCharacters(in: .whitespaces).isEmpty &&
        !correctWord.trimmingCharacters(in: .whitespaces).isEmpty &&
        misspelledWord.lowercased() != correctWord.lowercased()
    }

    private func submitReport() {
        guard canSubmit else { return }

        isSubmitting = true
        KeyboardHaptics.mediumTap()

        // Get context from the text document proxy
        let fullTextBefore = viewModel.textDocumentProxy?.documentContextBeforeInput ?? ""
        let settings = KeyboardSettings.load()
        let language = settings.spokenLanguage
        let position = fullTextBefore.count

        // Log the reported typo
        CorrectionQualityLogService.shared.logReportedTypo(
            original: misspelledWord.trimmingCharacters(in: .whitespaces),
            correctSpelling: correctWord.trimmingCharacters(in: .whitespaces),
            fullTextBefore: fullTextBefore,
            language: language,
            cursorPosition: position
        )

        // Brief delay to show submission, then close
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isSubmitting = false
            viewModel.reportTypoOriginalWord = ""
            onDismiss()
        }
    }
}

#Preview {
    ReportTypoPanel(
        viewModel: KeyboardViewModel(),
        onDismiss: { }
    )
    .preferredColorScheme(.dark)
}
