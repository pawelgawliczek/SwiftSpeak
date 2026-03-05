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
    @StateObject private var memoryScheduler = MemoryUpdateScheduler()
    @Environment(\.scenePhase) private var scenePhase

    /// Track if this is the first activation (app launch vs returning from background)
    @State private var hasPerformedInitialMemoryUpdate = false

    init() {
        // Initialize Firebase for Remote Config
        FirebaseApp.configure()

        // Pre-warm audio session for instant recording (<200ms startup)
        AudioSessionManager.shared.preWarm()

        // Initialize SwiftLink session manager to register Darwin notification observers
        // This ensures the app can receive dictation start/stop notifications from the keyboard
        _ = SwiftLinkSessionManager.shared
        appLog("SwiftLink manager initialized (session active: \(SwiftLinkSessionManager.shared.isSessionActive))", category: "Startup")

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
                    .environmentObject(settings)
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .preferredColorScheme(.dark)
            .animation(.easeInOut(duration: 0.3), value: settings.hasCompletedOnboarding)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    // Refresh settings from UserDefaults when app becomes active
                    // This picks up changes made by the keyboard extension
                    settings.refreshSharedSettingsFromDefaults()

                    // Perform memory updates on app start and foreground
                    // The scheduler handles 12h-24h interval logic internally
                    Task {
                        await performMemoryUpdatesIfNeeded()
                    }
                }
            }
        }
    }

    /// Perform scheduled memory updates
    /// Called on app start and when returning to foreground
    @MainActor
    private func performMemoryUpdatesIfNeeded() async {
        // Only log on first activation to avoid spamming logs
        if !hasPerformedInitialMemoryUpdate {
            appLog("Checking for scheduled memory updates on app start", category: "Memory")
            hasPerformedInitialMemoryUpdate = true
        }

        // Let the scheduler handle the timing logic
        let results = await memoryScheduler.performScheduledUpdates()

        // Log results if any updates were performed
        let updatedCount = results.filter { $0.success && $0.recordsProcessed > 0 }.count
        if updatedCount > 0 {
            appLog("Memory update complete: \(updatedCount) tier(s) updated", category: "Memory")
        }
    }
}
