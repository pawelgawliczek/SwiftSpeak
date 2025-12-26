//
//  ContentView.swift
//  SwiftSpeak
//
//  Main app navigation after onboarding
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: SharedSettings
    @State private var selectedTab = 0
    @State private var showRecording = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home / Recording
            HomeView(showRecording: $showRecording)
                .tabItem {
                    Image(systemName: "mic.fill")
                    Text("Record")
                }
                .tag(0)

            // History
            HistoryView()
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("History")
                }
                .tag(1)

            // Settings
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(2)
        }
        .tint(AppTheme.accent)
        .fullScreenCover(isPresented: $showRecording) {
            RecordingView(isPresented: $showRecording)
        }
        .onOpenURL { url in
            handleURLScheme(url)
        }
    }

    private func handleURLScheme(_ url: URL) {
        // Handle swiftspeak:// URL scheme from keyboard
        guard url.scheme == Constants.urlScheme else { return }

        // Parse parameters
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        // Extract mode
        if let modeString = queryItems.first(where: { $0.name == "mode" })?.value,
           let mode = FormattingMode(rawValue: modeString) {
            settings.selectedMode = mode
        }

        // Extract translate flag (Phase 2)
        _ = queryItems.first(where: { $0.name == "translate" })?.value == "true"

        // Extract target language
        if let targetString = queryItems.first(where: { $0.name == "target" })?.value,
           let language = Language(rawValue: targetString) {
            settings.selectedTargetLanguage = language
        }

        // Show recording view
        showRecording = true
    }
}

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject var settings: SharedSettings
    @Binding var showRecording: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                // Background - themed dark/light
                (colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase)
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    // Mode selector
                    VStack(spacing: 16) {
                        Text("Select Mode")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)

                        ModeSelector(selectedMode: $settings.selectedMode)
                    }

                    // Main record button
                    Button(action: {
                        HapticManager.mediumTap()
                        showRecording = true
                    }) {
                        ZStack {
                            // Outer ring
                            Circle()
                                .stroke(AppTheme.accentGradient, lineWidth: 4)
                                .frame(width: 140, height: 140)

                            // Inner circle
                            Circle()
                                .fill(AppTheme.accentGradient)
                                .frame(width: 120, height: 120)
                                .shadow(color: AppTheme.accent.opacity(0.5), radius: 20)

                            // Mic icon
                            Image(systemName: "mic.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.white)
                        }
                    }

                    Text("Tap to Record")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Quick stats
                    QuickStatsCard()
                        .padding(.horizontal, 24)

                    Spacer()
                        .frame(height: 20)
                }
            }
            .navigationTitle("SwiftSpeak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        // Reset onboarding for testing
                        settings.resetOnboarding()
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Mode Selector
struct ModeSelector: View {
    @Binding var selectedMode: FormattingMode

    var body: some View {
        HStack(spacing: 12) {
            ForEach(FormattingMode.allCases) { mode in
                Button(action: {
                    HapticManager.selection()
                    withAnimation(AppTheme.quickSpring) {
                        selectedMode = mode
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: mode.icon)
                            .font(.title3)

                        Text(mode.displayName)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(selectedMode == mode ? .white : .secondary)
                    .frame(width: 70, height: 70)
                    .background(
                        selectedMode == mode ?
                        AnyShapeStyle(AppTheme.accentGradient) :
                        AnyShapeStyle(Color.primary.opacity(0.08))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Quick Stats Card
struct QuickStatsCard: View {
    @EnvironmentObject var settings: SharedSettings

    var body: some View {
        HStack(spacing: 24) {
            ThemedStatItem(
                icon: "waveform",
                value: "\(settings.transcriptionHistory.count)",
                label: "Transcriptions"
            )

            Divider()
                .frame(height: 40)

            ThemedStatItem(
                icon: "clock",
                value: formattedDuration,
                label: "Total Time"
            )

            Divider()
                .frame(height: 40)

            ThemedStatItem(
                icon: "star.fill",
                value: settings.subscriptionTier.displayName,
                label: "Plan"
            )
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .glassBackground(cornerRadius: AppTheme.cornerRadiusLarge, includeShadow: false)
    }

    private var formattedDuration: String {
        let totalSeconds = settings.transcriptionHistory.reduce(0) { $0 + $1.duration }
        let minutes = Int(totalSeconds) / 60
        if minutes < 1 {
            return "0m"
        } else if minutes < 60 {
            return "\(minutes)m"
        } else {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SharedSettings.shared)
        .preferredColorScheme(.dark)
}
