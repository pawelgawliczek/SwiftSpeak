//
//  SwiftSpeakApp.swift
//  SwiftSpeak
//
//  Created by Pawel Gawliczek on 26/12/2025.
//

import SwiftUI

@main
struct SwiftSpeakApp: App {
    @StateObject private var settings = SharedSettings.shared
    @State private var showOnboarding = true

    init() {
        // Pre-warm audio session for instant recording
        // (Will be implemented in Phase 1)
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
