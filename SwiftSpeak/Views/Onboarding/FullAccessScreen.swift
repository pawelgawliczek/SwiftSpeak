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

    @State private var contentVisible = false
    @State private var checkmarkScale: CGFloat = 0
    @State private var showConfetti = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Title
            Text("Allow Full Access")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)

            // Subtitle
            Text("Required for voice transcription")
                .font(.body)
                .foregroundStyle(.secondary)

            // Explanation cards
            VStack(spacing: 16) {
                ExplanationCard(
                    icon: "network",
                    title: "Network Access",
                    description: "Needed to send audio to OpenAI for transcription",
                    color: .blue
                )

                ExplanationCard(
                    icon: "lock.shield.fill",
                    title: "Your Privacy",
                    description: "Audio is sent directly to OpenAI, never stored on our servers",
                    color: .green
                )

                ExplanationCard(
                    icon: "xmark.shield.fill",
                    title: "What We Don't Access",
                    description: "Passwords, credit cards, and other keyboard data",
                    color: .purple
                )
            }
            .padding(.horizontal, 24)
            .opacity(contentVisible ? 1 : 0)
            .offset(y: contentVisible ? 0 : 20)

            // Toggle mockup
            FullAccessToggleMockup(isEnabled: isEnabled)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .opacity(contentVisible ? 1 : 0)

            // Success state with confetti
            if isEnabled {
                ZStack {
                    if showConfetti {
                        ConfettiView()
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.green)
                            .scaleEffect(checkmarkScale)

                        Text("Full Access Enabled!")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                }
                .frame(height: 50)
                .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            // Continue button
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
                        .font(.callout.weight(.semibold))

                    Text(isEnabled ? "Continue" : "Open Settings")
                        .font(.callout.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .padding(.vertical, 6)
                .background(
                    isEnabled ?
                        LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .leading, endPoint: .trailing) :
                        AppTheme.accentGradient
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            }
            .padding(.horizontal, 32)

            // Skip for now
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
            withAnimation(AppTheme.smoothSpring.delay(0.2)) {
                contentVisible = true
            }
        }
        .onChange(of: isEnabled) { _, newValue in
            if newValue {
                HapticManager.success()
                withAnimation(AppTheme.smoothSpring) {
                    checkmarkScale = 1.0
                    showConfetti = true
                }
                // Auto-advance after celebration
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
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

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
    }
}

// MARK: - Full Access Toggle Mockup
struct FullAccessToggleMockup: View {
    let isEnabled: Bool

    var body: some View {
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
        .padding(16)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
    }
}

// MARK: - Confetti View
struct ConfettiView: View {
    @State private var particles: [(id: Int, offset: CGSize, rotation: Double, color: Color)] = []

    var body: some View {
        ZStack {
            ForEach(particles, id: \.id) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: 8, height: 8)
                    .offset(particle.offset)
                    .rotationEffect(.degrees(particle.rotation))
            }
        }
        .onAppear {
            createConfetti()
        }
    }

    private func createConfetti() {
        let colors: [Color] = [.blue, .purple, .green, .yellow, .orange, .pink]

        for i in 0..<30 {
            let randomX = CGFloat.random(in: -150...150)
            let randomY = CGFloat.random(in: -200...0)
            let randomRotation = Double.random(in: 0...360)
            let color = colors.randomElement() ?? .blue

            particles.append((id: i, offset: .zero, rotation: 0, color: color))

            withAnimation(.easeOut(duration: 1.5).delay(Double(i) * 0.02)) {
                particles[i].offset = CGSize(width: randomX, height: randomY)
                particles[i].rotation = randomRotation
            }
        }
    }
}

#Preview {
    ZStack {
        AppTheme.darkBase.ignoresSafeArea()
        FullAccessScreen(isEnabled: .constant(false), onContinue: {})
    }
}
