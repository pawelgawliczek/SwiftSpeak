//
//  HowItWorksScreen.swift
//  SwiftSpeak
//
//  Screen 2: 3-step carousel explaining how the app works
//

import SwiftUI

struct HowItWorksScreen: View {
    let onContinue: () -> Void

    @State private var currentStep = 0
    @State private var stepsVisible = false

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
        )
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Title
            Text("How It Works")
                .font(.title.weight(.bold))
                .foregroundStyle(.primary)

            // Steps carousel
            TabView(selection: $currentStep) {
                ForEach(0..<steps.count, id: \.self) { index in
                    StepCard(
                        step: index + 1,
                        icon: steps[index].icon,
                        title: steps[index].title,
                        description: steps[index].description
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 320)
            .opacity(stepsVisible ? 1 : 0)
            .offset(y: stepsVisible ? 0 : 30)

            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(currentStep == index ? AppTheme.accent : Color.secondary.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .scaleEffect(currentStep == index ? 1.2 : 1.0)
                        .animation(AppTheme.quickSpring, value: currentStep)
                }
            }
            .padding(.top, 16)

            Spacer()

            // Continue button
            Button(action: {
                HapticManager.mediumTap()
                onContinue()
            }) {
                Text("Continue")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 32)

            Spacer()
                .frame(height: 60)
        }
        .onAppear {
            withAnimation(AppTheme.smoothSpring.delay(0.2)) {
                stepsVisible = true
            }

            // Auto-advance carousel
            startAutoAdvance()
        }
    }

    private func startAutoAdvance() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { timer in
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

    @State private var iconScale: CGFloat = 0.8
    @State private var iconRotation: Double = -10

    var body: some View {
        VStack(spacing: 24) {
            // Step number badge
            ModeBadge(icon: "", text: "Step \(step)")

            // Icon with animation
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent.opacity(0.2), AppTheme.accentSecondary.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: icon)
                    .font(.system(size: 50))
                    .foregroundStyle(AppTheme.accentGradient)
                    .scaleEffect(iconScale)
                    .rotationEffect(.degrees(iconRotation))
            }

            // Title
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            // Description
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .onAppear {
            withAnimation(AppTheme.smoothSpring) {
                iconScale = 1.0
                iconRotation = 0
            }
        }
    }
}

#Preview {
    ZStack {
        AppTheme.darkBase.ignoresSafeArea()
        HowItWorksScreen(onContinue: {})
    }
}
