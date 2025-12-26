//
//  WelcomeScreen.swift
//  SwiftSpeak
//
//  Screen 1: Welcome with animated logo
//

import SwiftUI

struct WelcomeScreen: View {
    let onContinue: () -> Void
    @Environment(\.colorScheme) var colorScheme

    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var waveformPhase: Double = 0

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated logo with waveform
            ZStack {
                // Pulsing background circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.accent.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .scaleEffect(logoScale * 1.2)

                // Waveform circle
                WaveformCircle(phase: waveformPhase)
                    .stroke(AppTheme.accentGradient, lineWidth: 3)
                    .frame(width: 140, height: 140)

                // Microphone icon
                Image(systemName: "mic.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(AppTheme.accentGradient)
            }
            .scaleEffect(logoScale)
            .opacity(logoOpacity)

            VStack(spacing: 12) {
                // App name
                Text("SwiftSpeak")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)
                    .opacity(titleOpacity)

                // Tagline
                Text("Speak naturally. Type instantly.")
                    .font(.headline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .opacity(taglineOpacity)
            }

            Spacer()

            // Get Started button
            Button(action: {
                HapticManager.mediumTap()
                onContinue()
            }) {
                HStack(spacing: 10) {
                    Text("Get Started")
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
            .opacity(buttonOpacity)
            .scaleEffect(buttonOpacity == 1 ? 1 : 0.9)

            Spacer()
                .frame(height: 50)
        }
        .background(backgroundColor.ignoresSafeArea())
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Logo animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }

        // Title animation
        withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
            titleOpacity = 1.0
        }

        // Tagline animation
        withAnimation(.easeOut(duration: 0.6).delay(0.7)) {
            taglineOpacity = 1.0
        }

        // Button animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(1.0)) {
            buttonOpacity = 1.0
        }

        // Continuous waveform animation
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            waveformPhase = .pi * 2
        }
    }
}

// MARK: - Waveform Circle Shape
struct WaveformCircle: Shape {
    var phase: Double

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        for angle in stride(from: 0.0, to: 360.0, by: 1.0) {
            let radians = angle * .pi / 180
            let waveOffset = sin(radians * 8 + phase) * 5
            let r = radius + waveOffset

            let x = center.x + r * cos(radians)
            let y = center.y + r * sin(radians)

            if angle == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        path.closeSubpath()
        return path
    }
}

#Preview("Dark") {
    WelcomeScreen(onContinue: {})
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    WelcomeScreen(onContinue: {})
        .preferredColorScheme(.light)
}
