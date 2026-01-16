//
//  SwiftLinkSetupView.swift
//  SwiftSpeak
//
//  Settings view for configuring SwiftLink background dictation sessions.
//  Users can manage their app list and configure session duration.
//

import SwiftUI
import SwiftSpeakCore

struct SwiftLinkSetupView: View {
    @EnvironmentObject var settings: SharedSettings
    @StateObject private var sessionManager = SwiftLinkSessionManager.shared
    @StateObject private var contextCaptureManager = ContextCaptureManager.shared
    @Environment(\.colorScheme) var colorScheme

    @State private var showAppPicker = false
    @State private var showStartSession = false
    @State private var showBroadcastPrompt = false

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var groupedSwiftLinkApps: [(category: AppCategory, apps: [SwiftLinkApp])] {
        var groups: [AppCategory: [SwiftLinkApp]] = [:]

        for app in settings.swiftLinkApps {
            let appInfo = AppLibrary.apps.first(where: { $0.id == app.bundleId })
            let category = appInfo?.defaultCategory ?? .other
            groups[category, default: []].append(app)
        }

        return AppCategory.allCases.compactMap { category in
            guard let apps = groups[category], !apps.isEmpty else { return nil }
            return (category: category, apps: apps.sorted { $0.name < $1.name })
        }
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

                // Context Capture Section
                contextCaptureSection

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
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showAppPicker) {
            SwiftLinkAppPickerSheet(
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
            .environmentObject(settings)
        }
        .sheet(isPresented: $showBroadcastPrompt) {
            BroadcastPromptSheet()
                .presentationDetents([.medium])
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

    // MARK: - Context Capture Section

    private var contextCaptureSection: some View {
        Section {
            Toggle(isOn: $settings.contextCaptureEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "text.viewfinder")
                        .font(.title2)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Context Capture")
                            .font(.body)

                        Text("Capture screen text for smarter formatting")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .tint(AppTheme.accent)

            // Status when capturing
            if contextCaptureManager.isCapturing {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)

                    Text("Capturing active")
                        .font(.subheadline)
                        .foregroundStyle(.green)

                    Spacer()

                    if contextCaptureManager.framesCaptured > 0 {
                        Text("\(contextCaptureManager.framesCaptured) frames")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Screen Context")
        } footer: {
            Text("When enabled, SwiftLink will offer to capture your screen using iOS Screen Recording. This helps AI understand what you're looking at for better transcription formatting. No data is stored or sent anywhere.")
        }
    }

    // MARK: - Apps Section

    @ViewBuilder
    private var appsSection: some View {
        if settings.swiftLinkApps.isEmpty {
            Section {
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

                Button {
                    showAppPicker = true
                } label: {
                    Label("Add App", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("SwiftLink Apps")
            }
        } else {
            ForEach(groupedSwiftLinkApps, id: \.category) { group in
                Section {
                    ForEach(group.apps) { app in
                        SwiftLinkAppRow(app: app) {
                            settings.removeSwiftLinkApp(bundleId: app.bundleId)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let app = group.apps[index]
                            settings.removeSwiftLinkApp(bundleId: app.bundleId)
                        }
                    }
                } header: {
                    Label(group.category.displayName, systemImage: group.category.icon)
                        .foregroundStyle(group.category.color)
                }
            }

            Section {
                Button {
                    showAppPicker = true
                } label: {
                    Label("Add App", systemImage: "plus.circle.fill")
                }
            } footer: {
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
            // Check if we need to prompt for screen recording after session starts
            let shouldPromptForBroadcast = settings.contextCaptureEnabled && !contextCaptureManager.isCapturing

            if let urlScheme = try await sessionManager.startSession(targetApp: app) {
                // If context capture is enabled but not active, show broadcast prompt
                if shouldPromptForBroadcast {
                    // Show broadcast prompt sheet
                    await MainActor.run {
                        showBroadcastPrompt = true
                    }
                } else {
                    // Open the target app directly
                    if let url = URL(string: "\(urlScheme)://") {
                        await UIApplication.shared.open(url)
                    }
                }
            } else if shouldPromptForBroadcast {
                // Session started but no URL scheme - still prompt for broadcast
                await MainActor.run {
                    showBroadcastPrompt = true
                }
            }
        } catch {
            appLog("Failed to start SwiftLink session: \(error.localizedDescription)", category: "SwiftLink", level: .error)
        }
    }
}

// MARK: - Broadcast Prompt Sheet

struct BroadcastPromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var contextCaptureManager = ContextCaptureManager.shared
    @StateObject private var sessionManager = SwiftLinkSessionManager.shared

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 36))
                        .foregroundStyle(.blue)
                }

                Text("Enable Screen Context")
                    .font(.title2.bold())

                Text("Start screen recording for smarter AI predictions based on what you're viewing.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            // Broadcast Picker Button
            if contextCaptureManager.isCapturing {
                // Already capturing - show success
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.green)

                    Text("Screen Context Active")
                        .font(.headline)
                        .foregroundStyle(.green)
                }
            } else {
                // Show broadcast picker
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.blue)
                        .frame(height: 56)

                    HStack {
                        Image(systemName: "record.circle")
                        Text("Start Screen Recording")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .allowsHitTesting(false)

                    // Tappable broadcast picker
                    TappableBroadcastPicker(
                        broadcastExtensionBundleId: "pawelgawliczek.SwiftSpeak.SwiftSpeakBroadcast"
                    )
                }
                .padding(.horizontal)
            }

            Spacer()

            // Continue/Skip button
            Button(action: {
                returnToTargetApp()
            }) {
                Text(contextCaptureManager.isCapturing ? "Continue to App" : "Skip for Now")
                    .font(.body)
                    .foregroundStyle(contextCaptureManager.isCapturing ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(contextCaptureManager.isCapturing ? Color.green : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .padding(.top, 32)
        .onChange(of: contextCaptureManager.isCapturing) { _, isCapturing in
            if isCapturing {
                // Auto-continue after a brief delay when capture starts
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    returnToTargetApp()
                }
            }
        }
        .onAppear {
            contextCaptureManager.refreshState()
        }
    }

    private func returnToTargetApp() {
        dismiss()
        // Open the target app
        if let app = sessionManager.getLastUsedApp(),
           let urlScheme = app.effectiveURLScheme,
           let url = URL(string: "\(urlScheme)://") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - SwiftLink App Row

struct SwiftLinkAppRow: View {
    let app: SwiftLinkApp
    let onDelete: () -> Void

    @State private var showingDeleteConfirmation = false

    /// Look up AppInfo from AppLibrary to get the icon and category
    private var appInfo: AppInfo? {
        AppLibrary.apps.first { $0.id == app.bundleId }
    }

    private var category: AppCategory {
        appInfo?.defaultCategory ?? .other
    }

    var body: some View {
        HStack(spacing: 12) {
            // App icon - use real icon from AppLibrary if available
            if let appInfo = appInfo {
                AppIcon(appInfo, size: .large, style: .filled)
            } else {
                // Fallback for apps not in library
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(0.1))
                    Image(systemName: "app.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 40, height: 40)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(app.name)
                        .font(.body)
                        .foregroundStyle(.primary)

                    // URL scheme indicator - green if available, orange if not
                    if app.effectiveURLScheme != nil {
                        Image(systemName: "link")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "link.badge.plus")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Text(category.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Delete button
            Button(action: {
                showingDeleteConfirmation = true
            }) {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .confirmationDialog("Remove \(app.name)?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This app will be removed from your SwiftLink list.")
        }
    }
}

// MARK: - SwiftLink App Picker Sheet

struct SwiftLinkAppPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: SharedSettings
    let onSelectApp: (AppInfo) -> Void

    @State private var searchText = ""
    @State private var isSearching = false
    @FocusState private var isSearchFocused: Bool

    private var filteredApps: [AppInfo] {
        if searchText.isEmpty {
            return AppLibrary.apps
        }
        return AppLibrary.search(query: searchText)
    }

    private var groupedApps: [(category: AppCategory, apps: [AppInfo])] {
        let apps = filteredApps
        var groups: [AppCategory: [AppInfo]] = [:]

        for app in apps {
            let category = settings.effectiveCategory(for: app.id) ?? app.defaultCategory
            groups[category, default: []].append(app)
        }

        return AppCategory.allCases.compactMap { category in
            guard let apps = groups[category], !apps.isEmpty else { return nil }
            return (category: category, apps: apps.sorted { $0.name < $1.name })
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                List {
                    ForEach(groupedApps, id: \.category) { group in
                        Section {
                            ForEach(group.apps) { app in
                                Button {
                                    onSelectApp(app)
                                } label: {
                                    HStack(spacing: 12) {
                                        AppIcon(app, size: .large, style: .filled)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(app.name)
                                                .font(.body)
                                                .foregroundStyle(.primary)

                                            Text(group.category.displayName)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Label(group.category.displayName, systemImage: group.category.icon)
                                .foregroundStyle(group.category.color)
                        }
                    }
                }
                .blur(radius: isSearching ? 2 : 0)
                .allowsHitTesting(!isSearching)

                // Search overlay
                if isSearching {
                    OverlaySearchView(
                        searchText: $searchText,
                        isSearching: $isSearching,
                        isSearchFocused: _isSearchFocused,
                        results: filteredApps,
                        onSelectApp: { app in
                            onSelectApp(app)
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.spring(duration: 0.3), value: isSearching)
            .navigationTitle("Add App")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation {
                            isSearching = true
                            isSearchFocused = true
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Overlay Search View

private struct OverlaySearchView: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    @FocusState var isSearchFocused: Bool
    let results: [AppInfo]
    let onSelectApp: (AppInfo) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search apps...", text: $searchText)
                        .focused($isSearchFocused)
                        .textFieldStyle(.plain)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button("Cancel") {
                    withAnimation {
                        searchText = ""
                        isSearching = false
                    }
                }
                .foregroundStyle(.primary)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            // Results
            if !searchText.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results.prefix(20)) { app in
                            Button {
                                onSelectApp(app)
                            } label: {
                                HStack(spacing: 12) {
                                    AppIcon(app, size: .large, style: .filled)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(app.name)
                                            .font(.body)
                                            .foregroundStyle(.primary)

                                        Text(app.defaultCategory.displayName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial)
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .padding(.leading, 68)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding()
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        searchText = ""
                        isSearching = false
                    }
                }
        )
    }
}

// MARK: - SwiftLink Start Sheet

struct SwiftLinkStartSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: SharedSettings
    @StateObject private var contextCaptureManager = ContextCaptureManager.shared
    let apps: [SwiftLinkApp]
    let onSelectApp: (SwiftLinkApp) -> Void

    private var groupedApps: [(category: AppCategory, apps: [SwiftLinkApp])] {
        var groups: [AppCategory: [SwiftLinkApp]] = [:]

        for app in apps {
            let appInfo = AppLibrary.apps.first(where: { $0.id == app.bundleId })
            let category = appInfo?.defaultCategory ?? .other
            groups[category, default: []].append(app)
        }

        return AppCategory.allCases.compactMap { category in
            guard let apps = groups[category], !apps.isEmpty else { return nil }
            return (category: category, apps: apps.sorted { $0.name < $1.name })
        }
    }

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

                        Text("SwiftLink enables voice dictation and screen context capture for smarter AI predictions.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }

                // Context Capture Section - always visible
                Section {
                    contextCaptureRow
                } header: {
                    Text("Screen Context")
                } footer: {
                    if settings.contextCaptureEnabled && !contextCaptureManager.isCapturing {
                        Text("Tap above to start screen capture for context-aware AI predictions.")
                    }
                }

                ForEach(groupedApps, id: \.category) { group in
                    Section {
                        ForEach(group.apps) { app in
                            let appInfo = AppLibrary.apps.first(where: { $0.id == app.bundleId })

                            Button {
                                onSelectApp(app)
                            } label: {
                                HStack(spacing: 12) {
                                    if let appInfo = appInfo {
                                        AppIcon(appInfo, size: .large, style: .filled)
                                    } else {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(Color.secondary.opacity(0.1))
                                            Image(systemName: "app.fill")
                                                .font(.body)
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(width: 40, height: 40)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Text(app.name)
                                                .font(.body)
                                                .foregroundStyle(.primary)

                                            if app.urlScheme == nil {
                                                Image(systemName: "link.badge.plus")
                                                    .font(.caption)
                                                    .foregroundStyle(.orange)
                                            }
                                        }

                                        Text(group.category.displayName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Label(group.category.displayName, systemImage: group.category.icon)
                            .foregroundStyle(group.category.color)
                    }
                }
            }
            .navigationTitle("Start Session")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            contextCaptureManager.refreshState()
        }
    }

    // MARK: - Context Capture Row

    @ViewBuilder
    private var contextCaptureRow: some View {
        if contextCaptureManager.isCapturing {
            // Already capturing - show active status
            HStack(spacing: 12) {
                Image(systemName: "text.viewfinder")
                    .font(.title2)
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Screen Context")
                            .font(.body)

                        Text("Active")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }

                    Text("AI will use screen text for predictions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        } else if settings.contextCaptureEnabled {
            // Enabled but not active - show broadcast picker
            ZStack {
                HStack(spacing: 12) {
                    Image(systemName: "record.circle")
                        .font(.title2)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start Screen Recording")
                            .font(.body)

                        Text("Tap to enable context-aware AI")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("Tap")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }

                // Tappable broadcast picker overlay
                TappableBroadcastPicker(
                    broadcastExtensionBundleId: "pawelgawliczek.SwiftSpeak.SwiftSpeakBroadcast"
                )
            }
        } else {
            // Disabled - offer to enable
            HStack(spacing: 12) {
                Image(systemName: "text.viewfinder")
                    .font(.title2)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Screen Context")
                        .font(.body)

                    Text("Enable for smarter AI predictions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: {
                    HapticManager.lightTap()
                    settings.contextCaptureEnabled = true
                }) {
                    Text("Enable")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .clipShape(Capsule())
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
