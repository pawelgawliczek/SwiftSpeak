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

    @State private var contentVisible = false
    @State private var arrowOffset: CGFloat = 0
    @State private var checkmarkScale: CGFloat = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Title
            Text("Enable Keyboard")
                .font(.title.weight(.bold))
                .foregroundStyle(.primary)

            // Subtitle
            Text("Add SwiftSpeak to your keyboards")
                .font(.body)
                .foregroundStyle(.secondary)

            // Instruction card
            VStack(spacing: 20) {
                // Settings mockup
                SettingsMockup(isEnabled: isEnabled)
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 20)

                // Animated arrow pointing to keyboard
                if !isEnabled {
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                            .offset(x: arrowOffset)
                        Text("Tap Keyboards")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(AppTheme.accent)
                        Spacer()
                    }
                    .padding(.top, 8)
                }

                // Success state
                if isEnabled {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.green)
                            .scaleEffect(checkmarkScale)

                        Text("Keyboard Enabled!")
                            .font(.headline)
                            .foregroundStyle(.green)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(24)
            .glassBackground(cornerRadius: AppTheme.cornerRadiusLarge, includeShadow: false)
            .padding(.horizontal, 24)

            Spacer()

            // Open Settings / Continue button
            Button(action: {
                HapticManager.mediumTap()
                if isEnabled {
                    onContinue()
                } else {
                    openKeyboardSettings()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: isEnabled ? "arrow.right" : "gear")
                    Text(isEnabled ? "Continue" : "Open Settings")
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .padding(.vertical, 6)
                .background(isEnabled ? Color.green : AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)

            // Skip for now (development only)
            Button("Skip for now") {
                onContinue()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 8)

            Spacer()
                .frame(height: 60)
        }
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

        // Pulsing arrow animation
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            arrowOffset = 10
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

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "chevron.left")
                    .foregroundStyle(AppTheme.accent)
                Text("General")
                    .foregroundStyle(AppTheme.accent)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.1))

            // Keyboards row
            HStack {
                Image(systemName: "keyboard")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Text("Keyboards")
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.05))

            Divider()

            // SwiftSpeak row
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Text("SwiftSpeak")
                    .foregroundStyle(.primary)

                Spacer()

                if isEnabled {
                    Image(systemName: "checkmark")
                        .foregroundStyle(AppTheme.accent)
                        .font(.callout.weight(.semibold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isEnabled ? AppTheme.accent.opacity(0.1) : Color.primary.opacity(0.05))
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        AppTheme.darkBase.ignoresSafeArea()
        EnableKeyboardScreen(isEnabled: .constant(false), onContinue: {})
    }
}
