//
//  EnableKeyboardScreen.swift
//  SwiftSpeak
//
//  Screen 3: Guide user to enable keyboard in Settings
//

import SwiftUI

struct EnableKeyboardScreen: View {
    @Binding var isEnabled: Bool
    let onContinue: () -> Void
    @Environment(\.colorScheme) var colorScheme

    @State private var contentVisible = false
    @State private var arrowOffset: CGFloat = 0
    @State private var checkmarkScale: CGFloat = 0

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 24)

                // Animated waveform - same position as other onboarding screens
                ZStack {
                    MirroredBarWaveformView(
                        barCount: 20,
                        color: isEnabled ? .green : AppTheme.accent,
                        isActive: true,
                        speed: 0.4
                    )
                    .frame(width: 140, height: 36)

                    // Green checkmark overlay when enabled
                    if isEnabled {
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
                .frame(height: 60)
                .animation(AppTheme.smoothSpring, value: isEnabled)

                // Title
                Text(isEnabled ? "Keyboard Enabled!" : "Enable Keyboard")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)

                // Subtitle
                Text(isEnabled ? "You're all set to use SwiftSpeak" : "Add SwiftSpeak to your keyboards")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Instruction card
                if !isEnabled {
                    VStack(spacing: 0) {
                        // Step indicator
                        HStack {
                            Text("Follow these steps in Settings")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                        // Settings mockup
                        SettingsMockup(isEnabled: isEnabled)

                        // Animated instruction
                        HStack(spacing: 8) {
                            Image(systemName: "hand.tap.fill")
                                .font(.body)
                                .foregroundStyle(AppTheme.accent)

                            Text("Tap")
                                .font(.callout)
                                .foregroundStyle(.secondary)

                            Text("Keyboards")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.primary)

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.accent)
                                .offset(x: arrowOffset)

                            Text("SwiftSpeak")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                        }
                        .padding(.top, 16)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 5)
                    .padding(.horizontal, 24)
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 20)
                }

                Spacer()
                    .frame(height: 20)

                // Open Settings / Continue button
                Button(action: {
                    HapticManager.mediumTap()
                    if isEnabled {
                        onContinue()
                    } else {
                        openKeyboardSettings()
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: isEnabled ? "arrow.right" : "gear")
                            .font(.body.weight(.semibold))
                        Text(isEnabled ? "Continue" : "Open Settings")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .background(isEnabled ? Color.green : AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: (isEnabled ? Color.green : AppTheme.accent).opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)

                // Skip for now
                Button("Skip for now") {
                    onContinue()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

                Spacer()
                    .frame(height: 50)
            }
        }
        .background(backgroundColor.ignoresSafeArea())
        .onAppear {
            startAnimations()
        }
        .onChange(of: isEnabled) { _, newValue in
            if newValue {
                HapticManager.success()
                withAnimation(AppTheme.smoothSpring) {
                    checkmarkScale = 1.0
                }
                // Auto-advance after short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onContinue()
                }
            }
        }
    }

    private func startAnimations() {
        withAnimation(AppTheme.smoothSpring.delay(0.2)) {
            contentVisible = true
        }

        // Arrow bounce animation
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            arrowOffset = 4
        }
    }

    private func openKeyboardSettings() {
        // Deep link to keyboard settings
        if let url = URL(string: "App-prefs:General&path=Keyboard/KEYBOARDS") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Settings Mockup
struct SettingsMockup: View {
    let isEnabled: Bool
    @Environment(\.colorScheme) var colorScheme

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }

    private var headerBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color(UIColor.systemGray6)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Navigation header - looks like iOS Settings
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)

                Text("General")
                    .font(.body)
                    .foregroundStyle(AppTheme.accent)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(headerBackground)

            // Settings rows container
            VStack(spacing: 0) {
                // Keyboards row
                HStack(spacing: 14) {
                    // iOS-style icon
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(
                            LinearGradient(
                                colors: [Color.gray, Color.gray.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                    Text("Keyboards")
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(UIColor.tertiaryLabel))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(rowBackground)

                // Divider with indent
                HStack(spacing: 0) {
                    Color.clear.frame(width: 60)
                    Rectangle()
                        .fill(Color(UIColor.separator))
                        .frame(height: 0.5)
                }

                // SwiftSpeak row
                HStack(spacing: 14) {
                    // App icon
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(AppTheme.accentGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                    Text("SwiftSpeak")
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    if isEnabled {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    isEnabled
                        ? AppTheme.accent.opacity(colorScheme == .dark ? 0.15 : 0.1)
                        : rowBackground
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(UIColor.separator).opacity(0.5), lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
        }
    }
}

#Preview("Dark") {
    EnableKeyboardScreen(isEnabled: .constant(false), onContinue: {})
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    EnableKeyboardScreen(isEnabled: .constant(false), onContinue: {})
        .preferredColorScheme(.light)
}

#Preview("Enabled") {
    EnableKeyboardScreen(isEnabled: .constant(true), onContinue: {})
        .preferredColorScheme(.dark)
}
