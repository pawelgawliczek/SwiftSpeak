//
//  OnboardingView.swift
//  SwiftSpeak
//
//  Main onboarding container with 6 screens
//

import SwiftUI
import SwiftSpeakCore

struct OnboardingView: View {
    @StateObject private var settings = SharedSettings.shared
    @State private var isKeyboardEnabled = false
    @State private var isFullAccessEnabled = false
    @Binding var isComplete: Bool

    private let totalPages = 6
    @State private var showPaywall = false

    // Persist current page to survive app backgrounding
    @AppStorage("onboardingCurrentPage") private var currentPage = 0

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

                // Skip button (hidden on upsell screen and after - upsell is mandatory)
                HStack {
                    Spacer()
                    // Upsell is page 4, hide skip on page 4 and after
                    if currentPage < 4 {
                        Button("Skip") {
                            withAnimation(AppTheme.smoothSpring) {
                                // Skip to upsell screen (page 4), not past it
                                currentPage = 4
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

                    // Combined keyboard + full access screen
                    KeyboardSetupScreen(
                        isKeyboardEnabled: $isKeyboardEnabled,
                        isFullAccessEnabled: $isFullAccessEnabled,
                        onContinue: nextPage
                    )
                    .tag(2)

                    APIKeyScreen(onContinue: nextPage)
                        .tag(3)

                    OnboardingUpsellScreen(
                        onStartTrial: {
                            showPaywall = true
                        },
                        onContinueFree: nextPage
                    )
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Also check when app becomes active (returning from Settings)
            checkKeyboardStatus()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .onDisappear {
                    // After paywall dismissed, continue to AllSetScreen
                    if settings.subscriptionTier != .free {
                        nextPage()
                    }
                }
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
        // Reset persisted page for next time
        currentPage = 0
        withAnimation(AppTheme.smoothSpring) {
            isComplete = true
        }
    }

    private func checkKeyboardStatus() {
        // Check if our keyboard extension is enabled in system settings
        let keyboardBundleID = Constants.keyboardBundleID

        // Method 1: Check AppleKeyboards in standard UserDefaults
        if let keyboards = UserDefaults.standard.array(forKey: "AppleKeyboards") as? [String] {
            isKeyboardEnabled = keyboards.contains(keyboardBundleID)
        } else {
            isKeyboardEnabled = false
        }

        // Method 2: Check shared App Group for keyboard status flag
        // The keyboard extension writes this when it loads
        let sharedDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        // Keyboard enabled flag (written by keyboard extension on load)
        if let keyboardActive = sharedDefaults?.bool(forKey: "keyboardIsActive"), keyboardActive {
            isKeyboardEnabled = true
        }

        // Full Access flag (written by keyboard extension when it has full access)
        isFullAccessEnabled = sharedDefaults?.bool(forKey: "keyboardHasFullAccess") ?? false
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
    OnboardingView(isComplete: .constant(false))
}
