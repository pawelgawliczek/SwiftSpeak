//
//  OnboardingView.swift
//  SwiftSpeak
//
//  Main onboarding container with 6 screens
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var settings = SharedSettings.shared
    @State private var currentPage = 0
    @State private var isKeyboardEnabled = false
    @State private var isFullAccessEnabled = false
    @Binding var showOnboarding: Bool

    private let totalPages = 6

    var body: some View {
        ZStack {
            // Background - themed
            AppTheme.darkBase
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                ProgressBar(progress: Double(currentPage + 1) / Double(totalPages))
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                // Skip button (hidden on last page)
                HStack {
                    Spacer()
                    if currentPage < totalPages - 1 {
                        Button("Skip") {
                            withAnimation(AppTheme.smoothSpring) {
                                currentPage = totalPages - 1
                            }
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 24)
                        .padding(.top, 8)
                    }
                }
                .frame(height: 44)

                // Page content
                TabView(selection: $currentPage) {
                    WelcomeScreen(onContinue: nextPage)
                        .tag(0)

                    HowItWorksScreen(onContinue: nextPage)
                        .tag(1)

                    EnableKeyboardScreen(
                        isEnabled: $isKeyboardEnabled,
                        onContinue: nextPage
                    )
                    .tag(2)

                    FullAccessScreen(
                        isEnabled: $isFullAccessEnabled,
                        onContinue: nextPage
                    )
                    .tag(3)

                    APIKeyScreen(onContinue: nextPage)
                        .tag(4)

                    AllSetScreen(onComplete: completeOnboarding)
                        .tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(AppTheme.smoothSpring, value: currentPage)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            checkKeyboardStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            checkKeyboardStatus()
        }
    }

    private func nextPage() {
        withAnimation(AppTheme.smoothSpring) {
            if currentPage < totalPages - 1 {
                currentPage += 1
            }
        }
    }

    private func completeOnboarding() {
        settings.hasCompletedOnboarding = true
        withAnimation(AppTheme.smoothSpring) {
            showOnboarding = false
        }
    }

    private func checkKeyboardStatus() {
        // Check if keyboard is enabled (mock for now)
        // In real implementation, check UserDefaults for AppleKeyboards
        isKeyboardEnabled = false // Will be true when actually enabled
        isFullAccessEnabled = false
    }
}

// MARK: - Progress Bar
struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary.opacity(0.2))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(AppTheme.accentGradient)
                    .frame(width: geometry.size.width * progress, height: 4)
                    .animation(AppTheme.smoothSpring, value: progress)
            }
        }
        .frame(height: 4)
    }
}

#Preview {
    OnboardingView(showOnboarding: .constant(true))
}
