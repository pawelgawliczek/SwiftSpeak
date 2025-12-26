//
//  HowItWorksScreen.swift
//  SwiftSpeak
//
//  Screen 2: 3-step carousel explaining how the app works
//

import SwiftUI

struct HowItWorksScreen: View {
    let onContinue: () -> Void
    @Environment(\.colorScheme) var colorScheme

    @State private var currentStep = 0
    @State private var stepsVisible = false

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private let steps: [(icon: String, title: String, description: String)] = [
        (
            icon: "keyboard",
            title: "Switch Keyboard",
            description: "Tap the globe button to switch to SwiftSpeak keyboard"
        ),
        (
            icon: "mic.fill",
            title: "Tap & Speak",
            description: "Tap the microphone and speak naturally"
        ),
        (
            icon: "text.cursor",
            title: "Text Appears",
            description: "Your words are transcribed and formatted instantly"
        ),
        (
            icon: "sparkles",
            title: "Use Modes & Skills",
            description: "Enable modes for smart formatting, translations, and use templates for common tasks"
        )
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 24)

                // Animated waveform - same position as other onboarding screens
                SwiftSpeakWaveTextView(isActive: true, fontSize: 28)
                    .frame(height: 60)

                // Title
                Text("How It Works")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)

                // Subtitle
                Text("Three simple steps to voice typing")
                    .font(.body)
                    .foregroundStyle(.secondary)

                // Steps carousel
                TabView(selection: $currentStep) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        StepCard(
                            step: index + 1,
                            icon: steps[index].icon,
                            title: steps[index].title,
                            description: steps[index].description,
                            colorScheme: colorScheme
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 280)
                .opacity(stepsVisible ? 1 : 0)
                .offset(y: stepsVisible ? 0 : 30)

                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(currentStep == index ? AppTheme.accent : Color.secondary.opacity(0.4))
                            .frame(width: 8, height: 8)
                            .scaleEffect(currentStep == index ? 1.2 : 1.0)
                            .animation(AppTheme.quickSpring, value: currentStep)
                    }
                }

                Spacer()
                    .frame(height: 20)

                // Continue button
                Button(action: {
                    HapticManager.mediumTap()
                    onContinue()
                }) {
                    HStack(spacing: 10) {
                        Text("Continue")
                            .font(.body.weight(.semibold))
                        Image(systemName: "arrow.right")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: AppTheme.accent.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)

                Spacer()
                    .frame(height: 50)
            }
        }
        .background(backgroundColor.ignoresSafeArea())
        .onAppear {
            withAnimation(AppTheme.smoothSpring.delay(0.2)) {
                stepsVisible = true
            }

            // Auto-advance carousel
            startAutoAdvance()
        }
    }

    private func startAutoAdvance() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(AppTheme.smoothSpring) {
                currentStep = (currentStep + 1) % steps.count
            }
        }
    }
}

// MARK: - Step Card
struct StepCard: View {
    let step: Int
    let icon: String
    let title: String
    let description: String
    let colorScheme: ColorScheme

    @State private var iconScale: CGFloat = 0.8
    @State private var iconRotation: Double = -10

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }

    var body: some View {
        VStack(spacing: 20) {
            // Step number badge
            Text("Step \(step)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.accent.opacity(0.15))
                .clipShape(Capsule())

            // Icon with animation
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(colorScheme == .dark ? 0.15 : 0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.accent)
                    .scaleEffect(iconScale)
                    .rotationEffect(.degrees(iconRotation))
            }

            // Title
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            // Description
            Text(description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 20)
        .onAppear {
            withAnimation(AppTheme.smoothSpring) {
                iconScale = 1.0
                iconRotation = 0
            }
        }
    }
}

#Preview("Dark") {
    HowItWorksScreen(onContinue: {})
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    HowItWorksScreen(onContinue: {})
        .preferredColorScheme(.light)
}
