//
//  TypingKeyboardView.swift
//  SwiftSpeakKeyboard
//
//  Typing keyboard mode wrapper with SwiftSpeak bar and prediction row
//

import SwiftUI

// MARK: - Typing Keyboard View
struct TypingKeyboardView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    let onNextKeyboard: () -> Void
    let onSwitchToVoice: () -> Void
    let onTranslationTap: () -> Void
    let onContextTap: () -> Void
    let onModeTap: () -> Void
    let onSwiftLinkTap: () -> Void
    let onRefreshHeight: (() -> Void)?

    @State private var keyboardSettings: KeyboardSettings = .load()

    var body: some View {
        VStack(spacing: 0) {
            // Phase 13.12: AI Sentence Prediction Panel (replaces keyboard)
            if viewModel.showSentencePredictionPanel {
                SentencePredictionView(
                    viewModel: viewModel,
                    onClose: {
                        viewModel.closeSentencePredictionPanel()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            // Phase 13.10: Show quick settings, emoji panel, clipboard panel, or regular keyboard
            else if viewModel.showQuickSettings {
                QuickSettingsPopover(
                    settings: $keyboardSettings,
                    viewModel: viewModel,
                    onDismiss: {
                        viewModel.showQuickSettings = false
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if viewModel.showEmojiPanel {
                EmojiGIFPanel(
                    viewModel: viewModel,
                    onDismiss: {
                        KeyboardHaptics.lightTap()
                        viewModel.showEmojiPanel = false
                    }
                )
                .transition(.opacity)
            } else if viewModel.showClipboardPanel {
                ClipboardPanel(
                    viewModel: viewModel,
                    onDismiss: {
                        KeyboardHaptics.lightTap()
                        viewModel.showClipboardPanel = false
                    }
                )
                .transition(.opacity)
            } else {
                // SwiftSpeak bar with voice controls (Phase 16: conditionally shown)
                // NOTE: Recording UI is now handled by SwiftLinkStreamingOverlay in KeyboardView.swift
                if keyboardSettings.showSwiftSpeakBar {
                    SwiftSpeakBar(
                        viewModel: viewModel,
                        onTranslationTap: onTranslationTap,
                        onContextTap: onContextTap,
                        onModeTap: onModeTap,
                        onSwiftLinkTap: onSwiftLinkTap,
                        onTranscribeTap: {
                            viewModel.startTranscription()
                        },
                        onAIProcessTap: {
                            viewModel.processTextWithAI()
                        }
                    )
                    .transition(.opacity)
                }

                // Prediction row (Phase 16: conditionally shown)
                if keyboardSettings.showPredictionRow {
                    PredictionRow(viewModel: viewModel, settings: keyboardSettings)
                }

                // Main QWERTY keyboard - fills remaining space
                QWERTYKeyboard(
                    textDocumentProxy: viewModel.textDocumentProxy,
                    onNextKeyboard: onNextKeyboard,
                    viewModel: viewModel,  // Phase 13.6: Pass viewModel for predictions
                    showProgrammableNextToReturn: keyboardSettings.showProgrammableNextToReturn,
                    returnProgrammableAction: keyboardSettings.returnProgrammableAction
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KeyboardTheme.keyboardBackground)  // Fill entire area with keyboard background
        // Reload settings on appear to pick up changes from main app
        .onAppear {
            keyboardSettings = .load()
        }
        // Refresh settings when quick settings closes
        .onChange(of: viewModel.showQuickSettings) { _, isShowing in
            if !isShowing {
                keyboardSettings = .load()
                // Notify parent to refresh keyboard height
                onRefreshHeight?()
            }
        }
    }
}

#Preview {
    TypingKeyboardView(
        viewModel: KeyboardViewModel(),
        onNextKeyboard: { },
        onSwitchToVoice: { },
        onTranslationTap: { },
        onContextTap: { },
        onModeTap: { },
        onSwiftLinkTap: { },
        onRefreshHeight: nil
    )
    .preferredColorScheme(.dark)
}
