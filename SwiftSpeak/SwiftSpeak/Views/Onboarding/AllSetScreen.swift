//
//  AllSetScreen.swift
//  SwiftSpeak
//
//  Screen 6: Celebration screen with confetti
//

import SwiftUI

struct AllSetScreen: View {
    let onComplete: () -> Void
    @Environment(\.colorScheme) var colorScheme

    @State private var checkmarkScale: CGFloat = 0
    @State private var titleOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var confettiActive = false
    @State private var pulseScale: CGFloat = 1.0

    // Theme-aware colors (following branding guidelines)
    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            // Modern confetti overlay
            if confettiActive {
                ModernConfettiView(colors: AppTheme.confettiColors)
            }

            VStack(spacing: 32) {
                Spacer()

                // Success checkmark - glassmorphic design
                ZStack {
                    // Subtle pulsing rings
                    Circle()
                        .stroke(Color.green.opacity(0.15), lineWidth: 1.5)
                        .frame(width: 130, height: 130)
                        .scaleEffect(pulseScale)

                    Circle()
                        .stroke(Color.green.opacity(0.08), lineWidth: 1)
                        .frame(width: 160, height: 160)
                        .scaleEffect(pulseScale)

                    // Main circle - system green for success
                    Circle()
                        .fill(Color.green)
                        .frame(width: 96, height: 96)
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 5)

                    // Checkmark icon
                    Image(systemName: "checkmark")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(checkmarkScale)

                // Title - using Dynamic Type styles
                VStack(spacing: 8) {
                    Text("You're All Set")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("SwiftSpeak is ready to use")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .opacity(titleOpacity)

                // Quick tip card - glassmorphic material
                VStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.footnote.weight(.medium))
                        Text("Quick Tip")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.accent)

                    Text("Switch to SwiftSpeak keyboard using the globe button, then tap the microphone to start.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)

                    // Globe keyboard screenshot (theme-sensitive)
                    Image("GlobeKeyboard")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.top, 4)
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 5)
                .padding(.horizontal, 24)
                .opacity(contentOpacity)

                Spacer()

                // Start button - accent color, minimum 44pt touch target
                Button(action: {
                    HapticManager.mediumTap()
                    onComplete()
                }) {
                    HStack(spacing: 10) {
                        Text("Get Started")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .opacity(buttonOpacity)
                .scaleEffect(buttonOpacity == 1 ? 1 : 0.95)

                Spacer()
                    .frame(height: 50)
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Success haptic
        HapticManager.success()

        // Checkmark spring animation (dampingFraction 0.7)
        withAnimation(.spring(dampingFraction: 0.7).delay(0.2)) {
            checkmarkScale = 1.0
        }

        // Confetti
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            confettiActive = true
        }

        // Title fade
        withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
            titleOpacity = 1.0
        }

        // Content fade
        withAnimation(.easeOut(duration: 0.4).delay(0.7)) {
            contentOpacity = 1.0
        }

        // Button spring (dampingFraction 0.8)
        withAnimation(.spring(dampingFraction: 0.8).delay(1.0)) {
            buttonOpacity = 1.0
        }

        // Pulse animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.08
        }
    }
}

// MARK: - Modern Confetti View
struct ModernConfettiView: View {
    let colors: [Color]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate

                // Fewer, more elegant particles
                for i in 0..<25 {
                    let seed = Double(i) * 1234.5678
                    let baseX = (sin(seed) * 0.5 + 0.5) * size.width
                    let speed = 0.3 + (sin(seed * 2) * 0.5 + 0.5) * 0.4
                    let startDelay = (sin(seed * 3) * 0.5 + 0.5) * 2.0

                    let adjustedTime = max(0, time - startDelay)
                    let progress = (adjustedTime * speed).truncatingRemainder(dividingBy: 4.0) / 4.0

                    let y = -20 + progress * (size.height + 100)
                    let drift = sin(adjustedTime * 2 + seed) * 30
                    let x = baseX + drift

                    // Fade in and out
                    let fadeIn = min(1, progress * 5)
                    let fadeOut = max(0, 1 - (progress - 0.7) * 3.33)
                    let opacity = fadeIn * fadeOut * 0.8

                    let colorIndex = i % colors.count
                    let particleSize = 4 + sin(seed * 4) * 2

                    let rect = CGRect(
                        x: x - particleSize/2,
                        y: y - particleSize/2,
                        width: particleSize,
                        height: particleSize
                    )

                    context.opacity = opacity
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(colors[colorIndex])
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Previews
#Preview("Dark Mode") {
    AllSetScreen(onComplete: {})
        .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    AllSetScreen(onComplete: {})
        .preferredColorScheme(.light)
}
