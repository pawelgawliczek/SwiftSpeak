//
//  SwiftSpeakBar.swift
//  SwiftSpeakKeyboard
//
//  Top control bar with SwiftSpeak features: translation, context, mode, SwiftLink, and transcribe button
//

import SwiftUI

struct SwiftSpeakBar: View {
    @ObservedObject var viewModel: KeyboardViewModel
    let onTranslationTap: () -> Void
    let onContextTap: () -> Void
    let onModeTap: () -> Void
    let onSwiftLinkTap: () -> Void
    let onTranscribeTap: () -> Void
    var onAIProcessTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            // Translation toggle pill
            if viewModel.isPro {
                TranslationPill(
                    isEnabled: viewModel.isTranslationEnabled,
                    language: viewModel.selectedLanguage,
                    action: onTranslationTap
                )
            }

            // Context pill
            ContextPill(
                activeContext: viewModel.activeContext,
                action: onContextTap
            )

            // Mode pill
            ModePill(
                mode: viewModel.currentModeDisplayName,
                icon: viewModel.currentModeIcon,
                action: onModeTap
            )

            Spacer()

            // SwiftLink pill - enables background processing (tap first to enable AI in background)
            SwiftLinkPill(
                isActive: viewModel.isSwiftLinkSessionActive,
                action: onSwiftLinkTap
            )

            // AI Process pill - runs context/translation on current text (requires SwiftLink for seamless background)
            if viewModel.hasTextInField && (viewModel.activeContext != nil || viewModel.isTranslationEnabled) {
                AIProcessPill(
                    isProcessing: viewModel.isAIProcessing,
                    action: { onAIProcessTap?() }
                )
            }

            // Transcribe button
            TranscribeButton(
                isConfigured: viewModel.isProviderConfigured,
                isEditMode: viewModel.hasTextInField && viewModel.isPro,
                action: onTranscribeTap
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(Color(white: 0.10))
    }
}

// MARK: - Translation Pill
private struct TranslationPill: View {
    let isEnabled: Bool
    let language: Language
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.lightTap()
            action()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: 10, weight: .semibold))
                if isEnabled {
                    Text("→\(language.flag)")
                        .font(.system(size: 12))
                } else {
                    Text("OFF")
                        .font(.system(size: 9, weight: .semibold))
                }
            }
            .foregroundStyle(isEnabled ? .white : .white.opacity(0.5))
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                isEnabled ? Color.blue.opacity(0.3) : Color.white.opacity(0.1),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Context Pill
private struct ContextPill: View {
    let activeContext: KeyboardContext?
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.lightTap()
            action()
        }) {
            HStack(spacing: 4) {
                if let context = activeContext {
                    Text(context.icon)
                        .font(.system(size: 10))
                    Text(context.name)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                } else {
                    Image(systemName: "circle.slash")
                        .font(.system(size: 9, weight: .semibold))
                    Text("None")
                        .font(.system(size: 10, weight: .medium))
                }
            }
            .foregroundStyle(.white.opacity(activeContext != nil ? 1.0 : 0.5))
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                activeContext != nil ? Color.purple.opacity(0.3) : Color.white.opacity(0.1),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mode Pill
private struct ModePill: View {
    let mode: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.lightTap()
            action()
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(mode)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AI Process Pill
private struct AIProcessPill: View {
    let isProcessing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.mediumTap()
            action()
        }) {
            HStack(spacing: 4) {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .semibold))
                }
                Text("AI")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: isProcessing ? [.purple.opacity(0.6), .blue.opacity(0.6)] : [.purple.opacity(0.4), .blue.opacity(0.4)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
    }
}

// MARK: - SwiftLink Pill
private struct SwiftLinkPill: View {
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.lightTap()
            action()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text("Link")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(isActive ? .white : .white.opacity(0.6))
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                isActive ? Color.orange.opacity(0.4) : Color.white.opacity(0.1),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Transcribe Button (Circular with SwiftSpeak Logo)
private struct TranscribeButton: View {
    let isConfigured: Bool
    let isEditMode: Bool
    let action: () -> Void

    @State private var isPressed = false

    private var buttonColor: LinearGradient {
        if isEditMode {
            return LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if isConfigured {
            return LinearGradient(colors: [KeyboardTheme.accent, KeyboardTheme.accent.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: [.orange, .red.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var glowColor: Color {
        if isEditMode {
            return .green
        } else if isConfigured {
            return KeyboardTheme.accent
        } else {
            return .orange
        }
    }

    var body: some View {
        Button(action: {
            HapticManager.mediumTap()
            action()
        }) {
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [glowColor.opacity(0.4), .clear],
                            center: .center,
                            startRadius: 12,
                            endRadius: 30
                        )
                    )
                    .frame(width: 56, height: 56)

                // Main button
                Circle()
                    .fill(buttonColor)
                    .frame(width: 42, height: 42)
                    .shadow(color: glowColor.opacity(0.5), radius: 4, y: 2)

                // Content - SwiftSpeak logo or edit icon
                if isEditMode {
                    Image(systemName: "pencil")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                } else if !isConfigured {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    // SwiftSpeak logo with mic fallback
                    SwiftSpeakLogoView()
                        .frame(width: 56, height: 56)
                        .foregroundStyle(.white)
                }
            }
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Preview
#Preview {
    VStack {
        SwiftSpeakBar(
            viewModel: {
                let vm = KeyboardViewModel()
                vm.isPro = true
                vm.isTranslationEnabled = true
                vm.selectedLanguage = .spanish
                vm.activeContext = KeyboardContext(id: UUID(), name: "Work", icon: "💼")
                return vm
            }(),
            onTranslationTap: { },
            onContextTap: { },
            onModeTap: { },
            onSwiftLinkTap: { },
            onTranscribeTap: { }
        )

        SwiftSpeakBar(
            viewModel: {
                let vm = KeyboardViewModel()
                vm.isSwiftLinkSessionActive = true
                return vm
            }(),
            onTranslationTap: { },
            onContextTap: { },
            onModeTap: { },
            onSwiftLinkTap: { },
            onTranscribeTap: { }
        )
    }
    .preferredColorScheme(.dark)
}
