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

            // Clipboard button
            ClipboardPill(action: {
                KeyboardHaptics.lightTap()
                viewModel.showClipboardPanel = true
            })

            // Undo button (only when available)
            if viewModel.canUndo {
                UndoPill(action: {
                    viewModel.undo()
                })
            }

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

            // Transcribe button (tap to record, long press to toggle edit mode)
            TranscribeButton(
                isConfigured: viewModel.isProviderConfigured,
                isEditMode: viewModel.isEditModeEnabled && viewModel.isPro,
                action: onTranscribeTap,
                onLongPress: { viewModel.toggleEditMode() }
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

    @State private var isPressed = false

    var body: some View {
        Group {
            if isEnabled {
                Text(language.flag)
                    .font(.system(size: 18))
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .foregroundStyle(isEnabled ? .white : .white.opacity(0.5))
        .frame(width: 40, height: 40)
        .background(
            isEnabled ? Color.blue.opacity(isPressed ? 0.5 : 0.3) : Color.white.opacity(isPressed ? 0.2 : 0.1),
            in: Circle()
        )
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            if pressing && !isPressed {
                HapticManager.lightTap()
            }
            isPressed = pressing
        }, perform: {})
        .simultaneousGesture(
            TapGesture().onEnded {
                action()
            }
        )
    }
}

// MARK: - Context Pill
private struct ContextPill: View {
    let activeContext: KeyboardContext?
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Group {
            if let context = activeContext {
                Text(context.icon)
                    .font(.system(size: 18))
            } else {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .foregroundStyle(.white.opacity(activeContext != nil ? 1.0 : 0.5))
        .frame(width: 40, height: 40)
        .background(
            activeContext != nil ? Color.purple.opacity(isPressed ? 0.5 : 0.3) : Color.white.opacity(isPressed ? 0.2 : 0.1),
            in: Circle()
        )
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            if pressing && !isPressed {
                HapticManager.lightTap()
            }
            isPressed = pressing
        }, perform: {})
        .simultaneousGesture(
            TapGesture().onEnded {
                action()
            }
        )
    }
}

// MARK: - Mode Pill
private struct ModePill: View {
    let mode: String
    let icon: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(Color.white.opacity(isPressed ? 0.25 : 0.15), in: Circle())
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isPressed)
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                if pressing && !isPressed {
                    HapticManager.lightTap()
                }
                isPressed = pressing
            }, perform: {})
            .simultaneousGesture(
                TapGesture().onEnded {
                    action()
                }
            )
    }
}

// MARK: - AI Process Pill
private struct AIProcessPill: View {
    let isProcessing: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
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
                colors: isProcessing ? [.purple.opacity(0.6), .blue.opacity(0.6)] : [.purple.opacity(isPressed ? 0.6 : 0.4), .blue.opacity(isPressed ? 0.6 : 0.4)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: Capsule()
        )
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            if pressing && !isPressed && !isProcessing {
                HapticManager.mediumTap()
            }
            isPressed = pressing
        }, perform: {})
        .simultaneousGesture(
            TapGesture().onEnded {
                if !isProcessing {
                    action()
                }
            }
        )
    }
}

// MARK: - Clipboard Pill
private struct ClipboardPill: View {
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Image(systemName: "doc.on.clipboard")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white.opacity(0.6))
            .frame(width: 36, height: 36)
            .background(Color.white.opacity(isPressed ? 0.2 : 0.1), in: Circle())
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isPressed)
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                if pressing && !isPressed {
                    HapticManager.lightTap()
                }
                isPressed = pressing
            }, perform: {})
            .simultaneousGesture(
                TapGesture().onEnded {
                    action()
                }
            )
    }
}

// MARK: - Undo Pill
private struct UndoPill: View {
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Image(systemName: "arrow.uturn.backward")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(Color.orange.opacity(isPressed ? 0.5 : 0.3), in: Circle())
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isPressed)
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                if pressing && !isPressed {
                    HapticManager.lightTap()
                }
                isPressed = pressing
            }, perform: {})
            .simultaneousGesture(
                TapGesture().onEnded {
                    action()
                }
            )
    }
}

// MARK: - SwiftLink Pill
private struct SwiftLinkPill: View {
    let isActive: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Image(systemName: "link.circle.fill")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(isActive ? .white : .white.opacity(0.6))
            .frame(width: 40, height: 40)
            .background(
                isActive ? Color.orange.opacity(isPressed ? 0.6 : 0.4) : Color.white.opacity(isPressed ? 0.2 : 0.1),
                in: Circle()
            )
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isPressed)
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                if pressing && !isPressed {
                    HapticManager.lightTap()
                }
                isPressed = pressing
            }, perform: {})
            .simultaneousGesture(
                TapGesture().onEnded {
                    action()
                }
            )
    }
}

// MARK: - Transcribe Button (Circular with SwiftSpeak Logo)
private struct TranscribeButton: View {
    let isConfigured: Bool
    let isEditMode: Bool
    let action: () -> Void
    var onLongPress: (() -> Void)? = nil  // Long press to toggle edit mode

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
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    // Long press: toggle edit mode
                    HapticManager.mediumTap()
                    onLongPress?()
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .simultaneousGesture(
            TapGesture().onEnded {
                action()
            }
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
