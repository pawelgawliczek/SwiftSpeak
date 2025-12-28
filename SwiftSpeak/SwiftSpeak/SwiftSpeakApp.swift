//
//  SwiftSpeakApp.swift
//  SwiftSpeak
//
//  Created by Pawel Gawliczek on 26/12/2025.
//

import FirebaseCore
import SwiftUI

@main
struct SwiftSpeakApp: App {
    @StateObject private var settings = SharedSettings.shared
    @State private var showOnboarding = true

    init() {
        // Initialize Firebase for Remote Config
        FirebaseApp.configure()

        // Pre-warm audio session for instant recording (<200ms startup)
        AudioSessionManager.shared.preWarm()

        // Configure subscription service (mock mode for now)
        // TODO: Add your RevenueCat API key to Constants.swift and pass it here
        SubscriptionService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main app content
                ContentView()
                    .environmentObject(settings)

                // Onboarding overlay
                if showOnboarding && !settings.hasCompletedOnboarding {
                    OnboardingView(showOnboarding: $showOnboarding)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                showOnboarding = !settings.hasCompletedOnboarding
            }
        }
    }
}
