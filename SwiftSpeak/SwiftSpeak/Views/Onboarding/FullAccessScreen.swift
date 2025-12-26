//
//  FullAccessScreen.swift
//  SwiftSpeak
//
//  Screen 4: Explain and guide Full Access permission
//

import SwiftUI

struct FullAccessScreen: View {
    @Binding var isEnabled: Bool
    let onContinue: () -> Void
    @Environment(\.colorScheme) var colorScheme

    @State private var contentVisible = false
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
                    SoundBarsWaveformView(
                        barCount: 7,
                        color: isEnabled ? .green : AppTheme.accent,
                        isActive: true
                    )
                    .frame(width: 80, height: 50)

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
                Text(isEnabled ? "Full Access Enabled!" : "Allow Full Access")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)

                // Subtitle
                Text(isEnabled ? "You're ready for voice transcription" : "Required for voice transcription")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Explanation cards
                VStack(spacing: 8) {
                    ExplanationCard(
                        icon: "network",
                        title: "Network Access",
                        description: "Needed to send audio to OpenAI for transcription",
                        color: .blue,
                        colorScheme: colorScheme
                    )

                    ExplanationCard(
                        icon: "lock.shield.fill",
                        title: "Your Privacy",
                        description: "Audio is sent directly to OpenAI, never stored on our servers",
                        color: .green,
                        colorScheme: colorScheme
                    )

                    ExplanationCard(
                        icon: "xmark.shield.fill",
                        title: "What We Don't Access",
                        description: "Passwords, credit cards, and other keyboard data",
                        color: .purple,
                        colorScheme: colorScheme
                    )
                }
                .padding(.horizontal, 24)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 20)

                // Toggle mockup
                if !isEnabled {
                    FullAccessToggleMockup(isEnabled: isEnabled, colorScheme: colorScheme)
                        .padding(.horizontal, 24)
                        .opacity(contentVisible ? 1 : 0)
                }

                Spacer()
                    .frame(height: 20)

                // Continue/Open Settings button
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
            withAnimation(AppTheme.smoothSpring.delay(0.2)) {
                contentVisible = true
            }
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

    private func openKeyboardSettings() {
        if let url = URL(string: "App-prefs:General&path=Keyboard/KEYBOARDS") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Explanation Card
struct ExplanationCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let colorScheme: ColorScheme

    private var iconBackground: Color {
        color.opacity(colorScheme == .dark ? 0.2 : 0.15)
    }

    var body: some View {
        HStack(spacing: 10) {
            // Icon with colored background
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Full Access Toggle Mockup
struct FullAccessToggleMockup: View {
    let isEnabled: Bool
    let colorScheme: ColorScheme

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header - looks like iOS Settings
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)

                Text("Keyboards")
                    .font(.body)
                    .foregroundStyle(AppTheme.accent)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color(UIColor.systemGray6))

            // SwiftSpeak settings row
            VStack(spacing: 0) {
                HStack {
                    Text("Allow Full Access")
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    Toggle("", isOn: .constant(isEnabled))
                        .labelsHidden()
                        .tint(.green)
                        .allowsHitTesting(false)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(rowBackground)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(UIColor.separator).opacity(0.5), lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 20, y: 5)
    }
}

#Preview("Dark") {
    FullAccessScreen(isEnabled: .constant(false), onContinue: {})
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    FullAccessScreen(isEnabled: .constant(false), onContinue: {})
        .preferredColorScheme(.light)
}

#Preview("Enabled") {
    FullAccessScreen(isEnabled: .constant(true), onContinue: {})
        .preferredColorScheme(.dark)
}
