//
//  SwiftLinkSetupView.swift
//  SwiftSpeak
//
//  Settings view for configuring SwiftLink background dictation sessions.
//  Users can manage their app list and configure session duration.
//

import SwiftUI

struct SwiftLinkSetupView: View {
    @EnvironmentObject var settings: SharedSettings
    @StateObject private var sessionManager = SwiftLinkSessionManager.shared
    @Environment(\.colorScheme) var colorScheme

    @State private var showAppPicker = false
    @State private var showStartSession = false
    @State private var selectedCategory: AppCategory?

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            List {
                // Info Section
                infoSection

                // Session Status Section
                if sessionManager.isSessionActive {
                    sessionStatusSection
                }

                // Session Duration Section
                sessionDurationSection

                // Apps Section
                appsSection

                // Start Session Section
                if !sessionManager.isSessionActive && !settings.swiftLinkApps.isEmpty {
                    startSessionSection
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("SwiftLink")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAppPicker) {
            SwiftLinkAppPickerSheet(
                selectedCategory: $selectedCategory,
                onSelectApp: { appInfo in
                    settings.addSwiftLinkApp(from: appInfo)
                    showAppPicker = false
                }
            )
        }
        .sheet(isPresented: $showStartSession) {
            SwiftLinkStartSheet(
                apps: settings.swiftLinkApps,
                onSelectApp: { app in
                    Task {
                        await startSession(with: app)
                    }
                    showStartSession = false
                }
            )
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "link.circle.fill")
                        .font(.title)
                        .foregroundStyle(AppTheme.accentGradient)

                    Text("SwiftLink")
                        .font(.headline)
                }

                Text("Start a background recording session, then dictate from the keyboard without leaving your current app. Just like Wispr Flow!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                Label("Works best with apps that have URL schemes", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Session Status Section

    private var sessionStatusSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle()
                        .fill(.green)
                        .frame(width: 12, height: 12)

                    Text("Session Active")
                        .font(.headline)
                        .foregroundStyle(.green)

                    Spacer()

                    if let remaining = sessionManager.sessionTimeRemaining {
                        Text(formatTimeRemaining(remaining))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                if sessionManager.isRecording {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundStyle(.red)
                        Text("Recording...")
                            .foregroundStyle(.red)
                        Spacer()
                        Text(String(format: "%.1fs", sessionManager.currentDictationDuration))
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                }

                Button(role: .destructive) {
                    sessionManager.endSession()
                } label: {
                    HStack {
                        Spacer()
                        Label("End Session", systemImage: "stop.circle.fill")
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Current Session")
        }
    }

    // MARK: - Session Duration Section

    private var sessionDurationSection: some View {
        Section {
            Picker("Auto-End After", selection: $settings.swiftLinkSessionDuration) {
                ForEach(Constants.SwiftLinkSessionDuration.allCases, id: \.self) { duration in
                    Text(duration.displayName)
                        .tag(duration)
                }
            }
        } header: {
            Text("Session Duration")
        } footer: {
            Text("Sessions automatically end after this duration to preserve battery. Choose 'Never' for manual control only.")
        }
    }

    // MARK: - Apps Section

    private var appsSection: some View {
        Section {
            if settings.swiftLinkApps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "app.badge.checkmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("No Apps Added")
                        .font(.headline)

                    Text("Add apps you frequently use for dictation. When you start a SwiftLink session, you'll pick which app to return to.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(settings.swiftLinkApps) { app in
                    SwiftLinkAppRow(app: app) {
                        settings.removeSwiftLinkApp(bundleId: app.bundleId)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let app = settings.swiftLinkApps[index]
                        settings.removeSwiftLinkApp(bundleId: app.bundleId)
                    }
                }
            }

            Button {
                showAppPicker = true
            } label: {
                Label("Add App", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("SwiftLink Apps (\(settings.swiftLinkApps.count))")
        } footer: {
            if !settings.swiftLinkApps.isEmpty {
                Text("Swipe left on an app to remove it from the list.")
            }
        }
    }

    // MARK: - Start Session Section

    private var startSessionSection: some View {
        Section {
            Button {
                showStartSession = true
            } label: {
                HStack {
                    Spacer()
                    Label("Start SwiftLink Session", systemImage: "play.circle.fill")
                        .font(.headline)
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .listRowBackground(Color.clear)
        } footer: {
            Text("Start a session, pick an app, then dictate from your keyboard without switching apps.")
        }
    }

    // MARK: - Helpers

    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d remaining", minutes, secs)
    }

    private func startSession(with app: SwiftLinkApp) async {
        do {
            if let urlScheme = try await sessionManager.startSession(targetApp: app) {
                // Open the target app
                if let url = URL(string: "\(urlScheme)://") {
                    await UIApplication.shared.open(url)
                }
            }
        } catch {
            appLog("Failed to start SwiftLink session: \(error.localizedDescription)", category: "SwiftLink", level: .error)
        }
    }
}

// MARK: - SwiftLink App Row

struct SwiftLinkAppRow: View {
    let app: SwiftLinkApp
    let onDelete: () -> Void

    /// Look up AppInfo from AppLibrary to get the icon
    private var appInfo: AppInfo? {
        AppLibrary.apps.first { $0.id == app.bundleId }
    }

    var body: some View {
        HStack(spacing: 12) {
            // App icon - use real icon from AppLibrary if available
            if let appInfo = appInfo {
                AppIcon(appInfo, size: .large, style: .filled)
            } else {
                // Fallback for apps not in library
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.3))
                    Image(systemName: "app.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 40, height: 40)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.body)

                if let urlScheme = app.urlScheme {
                    Text("\(urlScheme)://")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No URL scheme")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()
        }
    }
}

// MARK: - SwiftLink App Picker Sheet

struct SwiftLinkAppPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedCategory: AppCategory?
    let onSelectApp: (AppInfo) -> Void

    @State private var searchText = ""

    private var filteredApps: [AppInfo] {
        var apps = AppLibrary.apps

        if let category = selectedCategory {
            apps = apps.filter { $0.defaultCategory == category }
        }

        if !searchText.isEmpty {
            apps = apps.filter { $0.matches(query: searchText) }
        }

        return apps
    }

    var body: some View {
        NavigationStack {
            List {
                // Category filter
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            CategoryChip(
                                category: nil,
                                isSelected: selectedCategory == nil,
                                onTap: { selectedCategory = nil }
                            )

                            ForEach(AppCategory.allCases) { category in
                                CategoryChip(
                                    category: category,
                                    isSelected: selectedCategory == category,
                                    onTap: { selectedCategory = category }
                                )
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                // Apps list
                Section {
                    ForEach(filteredApps) { app in
                        Button {
                            onSelectApp(app)
                        } label: {
                            HStack(spacing: 12) {
                                AppIcon(app, size: .medium, style: .filled)

                                VStack(alignment: .leading) {
                                    Text(app.name)
                                        .foregroundStyle(.primary)
                                    Text(app.id)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                } header: {
                    Text("\(filteredApps.count) Apps")
                }
            }
            .searchable(text: $searchText, prompt: "Search apps...")
            .navigationTitle("Add App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let category: AppCategory?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if let category = category {
                    Image(systemName: category.icon)
                        .font(.caption)
                    Text(category.displayName)
                } else {
                    Image(systemName: "square.grid.2x2")
                        .font(.caption)
                    Text("All")
                }
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color.white.opacity(0.1))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

// MARK: - SwiftLink Start Sheet

struct SwiftLinkStartSheet: View {
    @Environment(\.dismiss) var dismiss
    let apps: [SwiftLinkApp]
    let onSelectApp: (SwiftLinkApp) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(AppTheme.accentGradient)

                        Text("Start SwiftLink Session")
                            .font(.headline)

                        Text("Select an app to return to. You'll be able to dictate from the keyboard without leaving that app.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }

                Section("Select App") {
                    ForEach(apps) { app in
                        Button {
                            onSelectApp(app)
                        } label: {
                            HStack(spacing: 12) {
                                // Look up AppInfo from AppLibrary to get the icon
                                if let appInfo = AppLibrary.apps.first(where: { $0.id == app.bundleId }) {
                                    AppIcon(appInfo, size: .medium, style: .filled)
                                } else {
                                    // Fallback for apps not in library
                                    ZStack {
                                        Circle()
                                            .fill(Color.secondary.opacity(0.3))
                                        Image(systemName: "app.fill")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(width: 28, height: 28)
                                }

                                Text(app.name)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if app.urlScheme != nil {
                                    Image(systemName: "arrow.up.forward.app.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("SwiftLink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SwiftLinkSetupView()
            .environmentObject(SharedSettings.shared)
    }
}
