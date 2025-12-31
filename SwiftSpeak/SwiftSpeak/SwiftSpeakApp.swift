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

    init() {
        // Initialize Firebase for Remote Config
        FirebaseApp.configure()

        // Pre-warm audio session for instant recording (<200ms startup)
        AudioSessionManager.shared.preWarm()

        // Initialize SwiftLink session manager to register Darwin notification observers
        // This ensures the app can receive dictation start/stop notifications from the keyboard
        _ = SwiftLinkSessionManager.shared
        appLog("SwiftLink manager initialized (session active: \(SwiftLinkSessionManager.shared.isSessionActive))", category: "Startup")

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

                // Onboarding overlay - directly observes settings.hasCompletedOnboarding
                if !settings.hasCompletedOnboarding {
                    OnboardingView(isComplete: Binding(
                        get: { settings.hasCompletedOnboarding },
                        set: { settings.hasCompletedOnboarding = $0 }
                    ))
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .preferredColorScheme(.dark)
            .animation(.easeInOut(duration: 0.3), value: settings.hasCompletedOnboarding)
        }
    }
}
