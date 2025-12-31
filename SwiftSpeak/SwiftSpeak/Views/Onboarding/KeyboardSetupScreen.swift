//
//  KeyboardSetupScreen.swift
//  SwiftSpeak
//
//  Combined screen for enabling keyboard and full access
//

import SwiftUI

struct KeyboardSetupScreen: View {
    @Binding var isKeyboardEnabled: Bool
    @Binding var isFullAccessEnabled: Bool
    let onContinue: () -> Void
    @Environment(\.colorScheme) var colorScheme

    @State private var contentVisible = false
    @State private var arrowOffset: CGFloat = 0

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    /// Both requirements are met
    private var isComplete: Bool {
        isKeyboardEnabled && isFullAccessEnabled
    }

    /// At least keyboard is enabled (partial progress)
    private var hasPartialProgress: Bool {
        isKeyboardEnabled && !isFullAccessEnabled
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Spacer()
                    .frame(height: 8)

                // Animated waveform with status indicator
                ZStack {
                    MirroredBarWaveformView(
                        barCount: 20,
                        color: isComplete ? .green : (hasPartialProgress ? .orange : AppTheme.accent),
                        isActive: true,
                        speed: 0.4
                    )
                    .frame(width: 140, height: 36)

                    // Checkmark overlay when complete
                    if isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.green)
                            .background(
                                Circle()
                                    .fill(backgroundColor)
                                    .frame(width: 32, height: 32)
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(height: 50)
                .animation(AppTheme.smoothSpring, value: isComplete)

                // Title
                Text(isComplete ? "All Set!" : "Set Up Keyboard")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)

                // Subtitle
                Text(isComplete ? "SwiftSpeak is ready to use" : "Enable SwiftSpeak keyboard with full access")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Status checklist
                VStack(spacing: 10) {
                    StatusCheckRow(
                        title: "SwiftSpeak Keyboard",
                        subtitle: isKeyboardEnabled ? "Enabled" : "Not enabled yet",
                        isComplete: isKeyboardEnabled,
                        colorScheme: colorScheme
                    )

                    StatusCheckRow(
                        title: "Full Access",
                        subtitle: isFullAccessEnabled ? "Enabled" : (isKeyboardEnabled ? "Tap to enable" : "Enable keyboard first"),
                        isComplete: isFullAccessEnabled,
                        colorScheme: colorScheme
                    )
                }
                .padding(.horizontal, 24)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 20)

                // Instructions (only show if not complete)
                if !isComplete {
                    VStack(spacing: 12) {
                        // Instruction header
                        HStack {
                            Text("In Settings, do the following:")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }

                        // Step 1: Enable keyboard
                        InstructionRow(
                            stepNumber: 1,
                            title: "Keyboards",
                            action: "Enable SwiftSpeak",
                            isComplete: isKeyboardEnabled,
                            colorScheme: colorScheme
                        )

                        // Step 2: Enable full access
                        InstructionRow(
                            stepNumber: 2,
                            title: "SwiftSpeak",
                            action: "Allow Full Access",
                            isComplete: isFullAccessEnabled,
                            colorScheme: colorScheme
                        )

                        // Privacy note
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Text("Full access is needed for voice transcription. Your data is sent directly to your AI provider.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 24)
                    .opacity(contentVisible ? 1 : 0)
                }

                Spacer()
                    .frame(height: 12)

                // Action button
                Button(action: {
                    HapticManager.mediumTap()
                    if isComplete {
                        onContinue()
                    } else {
                        openKeyboardSettings()
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: isComplete ? "arrow.right" : "gear")
                            .font(.body.weight(.semibold))
                        Text(isComplete ? "Continue" : "Open Settings")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .background(isComplete ? Color.green : AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: (isComplete ? Color.green : AppTheme.accent).opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)

                // Secondary actions
                if !isComplete {
                    VStack(spacing: 8) {
                        // If keyboard enabled but full access not detected, show verify hint
                        if isKeyboardEnabled && !isFullAccessEnabled {
                            Text("After enabling Full Access, use the keyboard once to verify")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        // Allow manual confirmation
                        Button("I've enabled both settings") {
                            HapticManager.lightTap()
                            onContinue()
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.accent)

                        Button("Skip for now") {
                            onContinue()
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }

                Spacer()
                    .frame(height: 24)
            }
        }
        .background(backgroundColor.ignoresSafeArea())
        .onAppear {
            withAnimation(AppTheme.smoothSpring.delay(0.2)) {
                contentVisible = true
            }
        }
        .onChange(of: isComplete) { _, newValue in
            if newValue {
                HapticManager.success()
                // Auto-advance after short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onContinue()
                }
            }
        }
        .onChange(of: isKeyboardEnabled) { _, newValue in
            if newValue && !isFullAccessEnabled {
                HapticManager.lightTap()
            }
        }
    }

    private func openKeyboardSettings() {
        if let url = URL(string: "App-prefs:General&path=Keyboard/KEYBOARDS") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Status Check Row
struct StatusCheckRow: View {
    let title: String
    let subtitle: String
    let isComplete: Bool
    let colorScheme: ColorScheme

    private var rowBackground: Color {
        if isComplete {
            return Color.green.opacity(colorScheme == .dark ? 0.15 : 0.1)
        }
        return colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            ZStack {
                Circle()
                    .fill(isComplete ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 28, height: 28)

                Image(systemName: isComplete ? "checkmark" : "circle")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isComplete ? .white : .gray)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(isComplete ? .green : .secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(AppTheme.smoothSpring, value: isComplete)
    }
}

// MARK: - Instruction Row
struct InstructionRow: View {
    let stepNumber: Int
    let title: String
    let action: String
    let isComplete: Bool
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Step number
            ZStack {
                Circle()
                    .fill(isComplete ? Color.green : AppTheme.accent)
                    .frame(width: 24, height: 24)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(stepNumber)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
            }

            Text(title)
                .font(.callout)
                .foregroundStyle(isComplete ? .secondary : .primary)
                .strikethrough(isComplete)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            Text(action)
                .font(.callout.weight(.medium))
                .foregroundStyle(isComplete ? .secondary : AppTheme.accent)
                .strikethrough(isComplete)

            Spacer()
        }
        .opacity(isComplete ? 0.6 : 1.0)
    }
}

#Preview("Not Started") {
    KeyboardSetupScreen(
        isKeyboardEnabled: .constant(false),
        isFullAccessEnabled: .constant(false),
        onContinue: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Keyboard Only") {
    KeyboardSetupScreen(
        isKeyboardEnabled: .constant(true),
        isFullAccessEnabled: .constant(false),
        onContinue: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Complete") {
    KeyboardSetupScreen(
        isKeyboardEnabled: .constant(true),
        isFullAccessEnabled: .constant(true),
        onContinue: {}
    )
    .preferredColorScheme(.dark)
}
