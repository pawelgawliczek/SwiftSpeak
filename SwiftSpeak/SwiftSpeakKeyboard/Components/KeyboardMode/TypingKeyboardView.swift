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

    @State private var keyboardSettings: KeyboardSettings = .load()

    private var isRecording: Bool {
        viewModel.isSwiftLinkRecording ||
        viewModel.processingStatus.currentStep == "transcribing" ||
        viewModel.processingStatus.currentStep == "formatting" ||
        viewModel.processingStatus.currentStep == "translating" ||
        viewModel.swiftLinkProcessingStatus == "processing"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Phase 13.10: Show quick settings, emoji panel, clipboard panel, or regular keyboard
            if viewModel.showQuickSettings {
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
                // Transform between SwiftSpeak bar and Recording bar
                if isRecording {
                    RecordingBar(
                        viewModel: viewModel,
                        onStop: {
                            if viewModel.isSwiftLinkRecording {
                                viewModel.stopSwiftLinkRecording()
                            }
                        }
                    )
                    .transition(.opacity)

                    // Show streaming transcript in bottom row during recording
                    StreamingTranscriptRow(viewModel: viewModel)
                        .transition(.opacity)
                } else {
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

                    // Only show predictions if AI Predictions is enabled
                    if keyboardSettings.aiPredictions {
                        PredictionRow(viewModel: viewModel)
                    }
                }

                // Main QWERTY keyboard - fills remaining space
                QWERTYKeyboard(
                    textDocumentProxy: viewModel.textDocumentProxy,
                    onNextKeyboard: onNextKeyboard,
                    viewModel: viewModel  // Phase 13.6: Pass viewModel for predictions
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KeyboardTheme.keyboardBackground)  // Fill entire area with keyboard background
        // Refresh settings when quick settings closes
        .onChange(of: viewModel.showQuickSettings) { _, isShowing in
            if !isShowing {
                keyboardSettings = .load()
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
        onSwiftLinkTap: { }
    )
    .preferredColorScheme(.dark)
}
