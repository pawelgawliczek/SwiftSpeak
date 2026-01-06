//
//  OnboardingUpsellScreen.swift
//  SwiftSpeak
//
//  Phase 7: Upsell screen shown before AllSetScreen in onboarding
//

import SwiftUI
import SwiftSpeakCore

struct OnboardingUpsellScreen: View {
    let onStartTrial: () -> Void
    let onContinueFree: () -> Void

    @Environment(\.colorScheme) var colorScheme

    @State private var headerOpacity: Double = 0
    @State private var cardsOffset: CGFloat = 30
    @State private var cardsOpacity: Double = 0
    @State private var buttonsOpacity: Double = 0

    // Theme-aware colors
    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Text("Unlock the Full Experience")
                            .font(.title.weight(.bold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)

                        Text("Get the most out of SwiftSpeak")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .opacity(headerOpacity)
                    .padding(.top, 24)

                    // Feature cards
                    VStack(spacing: 16) {
                        FeatureCard(
                            icon: "infinity",
                            iconColor: .purple,
                            title: "Unlimited Transcriptions",
                            description: "No daily limits - transcribe as much as you need"
                        )

                        FeatureCard(
                            icon: "cpu",
                            iconColor: .blue,
                            title: "Multiple AI Providers",
                            description: "OpenAI, Anthropic, Gemini, and more"
                        )

                        FeatureCard(
                            icon: "bolt.fill",
                            iconColor: .orange,
                            title: "AI Power Modes",
                            description: "Voice-activated AI agents for research, email, and writing"
                        )

                        FeatureCard(
                            icon: "globe",
                            iconColor: .green,
                            title: "Translation",
                            description: "Translate to 50+ languages with DeepL and Google"
                        )
                    }
                    .offset(y: cardsOffset)
                    .opacity(cardsOpacity)
                    .padding(.horizontal, 24)

                    Spacer(minLength: 24)

                    // CTA buttons
                    VStack(spacing: 16) {
                        // Primary: Start Trial
                        Button(action: {
                            HapticManager.mediumTap()
                            onStartTrial()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .font(.body.weight(.semibold))
                                Text("Start 7-Day Free Trial")
                                    .font(.body.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.proGradient)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
                        }

                        // Secondary: Continue Free
                        Button(action: {
                            HapticManager.lightTap()
                            onContinueFree()
                        }) {
                            Text("Continue with Free")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        // Legal text
                        Text("7-day free trial, then $6.99/month. Cancel anytime.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(buttonsOpacity)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        // Header fade in
        withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
            headerOpacity = 1.0
        }

        // Cards slide up
        withAnimation(AppTheme.smoothSpring.delay(0.3)) {
            cardsOffset = 0
            cardsOpacity = 1.0
        }

        // Buttons fade in
        withAnimation(.easeOut(duration: 0.4).delay(0.6)) {
            buttonsOpacity = 1.0
        }
    }
}

// MARK: - Feature Card

private struct FeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(iconColor)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
    }
}

// MARK: - Preview

#Preview("Dark Mode") {
    OnboardingUpsellScreen(
        onStartTrial: {},
        onContinueFree: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    OnboardingUpsellScreen(
        onStartTrial: {},
        onContinueFree: {}
    )
    .preferredColorScheme(.light)
}
