//
//  SwiftLinkQuickStartSheet.swift
//  SwiftSpeak
//
//  Quick-start sheet for SwiftLink background dictation.
//  Shown from RecordingView when no session is active.
//

import SwiftUI

/// Quick-start sheet for SwiftLink - minimal clicks to start a session
struct SwiftLinkQuickStartSheet: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var sessionManager = SwiftLinkSessionManager.shared

    @State private var selectedApp: SwiftLinkApp?
    @State private var showingAppPicker = false
    @State private var isStartingSession = false
    @State private var errorMessage: String?

    /// Callback when session starts successfully with a URL scheme to open
    var onSessionStarted: ((String?) -> Void)?

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header illustration
                headerSection

                // App selection
                appSelectionSection

                // Duration info
                durationInfo

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                // Start button
                startButton
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Start SwiftLink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingAppPicker) {
            SwiftLinkAppPickerForQuickStart(
                existingApps: settings.swiftLinkApps,
                onSelect: { app in
                    // Add to settings if new
                    if !settings.isSwiftLinkApp(bundleId: app.bundleId) {
                        settings.addSwiftLinkApp(app)
                    }
                    selectedApp = app
                    showingAppPicker = false
                }
            )
            .presentationDetents([.large])
        }
        .onAppear {
            // Pre-select the last used app or first app in list
            if selectedApp == nil {
                selectedApp = sessionManager.getLastUsedApp() ?? settings.swiftLinkApps.first
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(AppTheme.accentGradient.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "link.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.accentGradient)
            }

            // Description
            Text("Dictate without leaving your app")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Start a session, then use the keyboard mic button to dictate inline.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - App Selection Section

    private var appSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Return to")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            if settings.swiftLinkApps.isEmpty {
                // No apps configured - show add button
                addAppButton
            } else {
                // App selector
                VStack(spacing: 8) {
                    // Selected app or picker
                    appSelectorButton

                    // Quick access to other apps
                    if settings.swiftLinkApps.count > 1 {
                        quickAppList
                    }

                    // Add more button
                    Button(action: { showingAppPicker = true }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Another App")
                        }
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.accent)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addAppButton: some View {
        Button(action: { showingAppPicker = true }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 50, height: 50)

                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Select an app")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Choose where to return after session starts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var appSelectorButton: some View {
        Button(action: { showingAppPicker = true }) {
            HStack(spacing: 12) {
                // App icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selectedApp != nil ? AppTheme.accent.opacity(0.15) : Color.secondary.opacity(0.1))
                        .frame(width: 50, height: 50)

                    if let app = selectedApp {
                        if let appInfo = AppLibrary.find(bundleId: app.bundleId) {
                            AppIcon(appInfo, size: .large, style: .filled)
                        } else if let iconName = app.iconName {
                            Image(systemName: iconName)
                                .font(.title2)
                                .foregroundStyle(AppTheme.accent)
                        } else {
                            Text(String(app.name.prefix(1)).uppercased())
                                .font(.title2.weight(.bold))
                                .foregroundStyle(AppTheme.accent)
                        }
                    } else {
                        Image(systemName: "questionmark")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let app = selectedApp {
                        Text(app.name)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if app.urlScheme != nil {
                            Text("Will auto-return")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Text("Manual return (no URL scheme)")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Text("Select an app")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var quickAppList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(settings.swiftLinkApps.filter { $0.id != selectedApp?.id }.prefix(4)) { app in
                    Button(action: { selectedApp = app }) {
                        VStack(spacing: 6) {
                            Group {
                                if let appInfo = AppLibrary.find(bundleId: app.bundleId) {
                                    AppIcon(appInfo, size: .large, style: .filled)
                                } else {
                                    ZStack {
                                        Circle()
                                            .fill(Color.secondary.opacity(0.1))
                                            .frame(width: 44, height: 44)

                                        if let iconName = app.iconName {
                                            Image(systemName: iconName)
                                                .font(.body)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text(String(app.name.prefix(1)).uppercased())
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }

                            Text(app.name)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(width: 60)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Duration Info

    private var durationInfo: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundStyle(.secondary)

            Text("Session duration: \(sessionManager.sessionDuration.displayName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button(action: startSession) {
            HStack {
                if isStartingSession {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "play.fill")
                }

                Text(isStartingSession ? "Starting..." : "Start Session")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(selectedApp != nil ? AppTheme.accentGradient : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(selectedApp == nil || isStartingSession)
    }

    // MARK: - Actions

    private func startSession() {
        guard let app = selectedApp else { return }

        isStartingSession = true
        errorMessage = nil
        HapticManager.mediumTap()

        Task {
            do {
                let urlScheme = try await sessionManager.startSession(targetApp: app)

                await MainActor.run {
                    isStartingSession = false
                    HapticManager.success()
                    dismiss()
                    onSessionStarted?(urlScheme)
                }
            } catch {
                await MainActor.run {
                    isStartingSession = false
                    errorMessage = error.localizedDescription
                    HapticManager.error()
                }
            }
        }
    }
}

// MARK: - App Picker for Quick Start

struct SwiftLinkAppPickerForQuickStart: View {
    let existingApps: [SwiftLinkApp]
    let onSelect: (SwiftLinkApp) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText = ""
    @State private var customAppName = ""
    @State private var customUrlScheme = ""
    @State private var showingCustomEntry = false

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95)
    }

    // Popular apps with URL schemes
    private let popularApps: [SwiftLinkApp] = [
        SwiftLinkApp(bundleId: "net.whatsapp.WhatsApp", name: "WhatsApp", urlScheme: "whatsapp://", iconName: "message.fill"),
        SwiftLinkApp(bundleId: "com.burbn.instagram", name: "Instagram", urlScheme: "instagram://", iconName: "camera.fill"),
        SwiftLinkApp(bundleId: "com.facebook.Messenger", name: "Messenger", urlScheme: "fb-messenger://", iconName: "bubble.left.fill"),
        SwiftLinkApp(bundleId: "com.apple.MobileSMS", name: "Messages", urlScheme: "sms://", iconName: "message.fill"),
        SwiftLinkApp(bundleId: "com.apple.mobilemail", name: "Mail", urlScheme: "mailto://", iconName: "envelope.fill"),
        SwiftLinkApp(bundleId: "com.atebits.Tweetie2", name: "Twitter/X", urlScheme: "twitter://", iconName: "at"),
        SwiftLinkApp(bundleId: "com.hammerandchisel.discord", name: "Discord", urlScheme: "discord://", iconName: "bubble.left.and.bubble.right.fill"),
        SwiftLinkApp(bundleId: "com.skype.skype", name: "Skype", urlScheme: "skype://", iconName: "phone.fill"),
        SwiftLinkApp(bundleId: "com.slack.Slack", name: "Slack", urlScheme: "slack://", iconName: "number"),
        SwiftLinkApp(bundleId: "com.microsoft.teams", name: "Teams", urlScheme: "msteams://", iconName: "person.3.fill"),
        SwiftLinkApp(bundleId: "org.telegram.Telegram", name: "Telegram", urlScheme: "telegram://", iconName: "paperplane.fill"),
        SwiftLinkApp(bundleId: "com.linkedin.LinkedIn", name: "LinkedIn", urlScheme: "linkedin://", iconName: "briefcase.fill"),
        SwiftLinkApp(bundleId: "com.google.Gmail", name: "Gmail", urlScheme: "googlegmail://", iconName: "envelope.fill"),
        SwiftLinkApp(bundleId: "com.apple.mobilenotes", name: "Notes", urlScheme: "mobilenotes://", iconName: "note.text"),
        SwiftLinkApp(bundleId: "com.google.Docs", name: "Google Docs", urlScheme: "googledocs://", iconName: "doc.text.fill"),
        SwiftLinkApp(bundleId: "notion.id", name: "Notion", urlScheme: "notion://", iconName: "square.grid.2x2.fill"),
    ]

    private var filteredApps: [SwiftLinkApp] {
        if searchText.isEmpty {
            return popularApps
        }
        return popularApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                // Existing apps section (if any)
                if !existingApps.isEmpty {
                    Section("Your Apps") {
                        ForEach(existingApps) { app in
                            appRow(app, isExisting: true)
                        }
                    }
                }

                // Popular apps section
                Section("Popular Apps") {
                    ForEach(filteredApps.filter { app in !existingApps.contains(where: { $0.bundleId == app.bundleId }) }) { app in
                        appRow(app, isExisting: false)
                    }
                }

                // Custom app section
                Section("Custom App") {
                    if showingCustomEntry {
                        customAppEntry
                    } else {
                        Button(action: { showingCustomEntry = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Add Custom App")
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search apps")
            .scrollContentBackground(.hidden)
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Select App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func appRow(_ app: SwiftLinkApp, isExisting: Bool) -> some View {
        Button(action: { onSelect(app) }) {
            HStack(spacing: 12) {
                // Icon
                Group {
                    if let appInfo = AppLibrary.find(bundleId: app.bundleId) {
                        AppIcon(appInfo, size: .large, style: .filled)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isExisting ? AppTheme.accent.opacity(0.15) : Color.secondary.opacity(0.1))
                                .frame(width: 44, height: 44)

                            if let iconName = app.iconName {
                                Image(systemName: iconName)
                                    .font(.title3)
                                    .foregroundStyle(isExisting ? AppTheme.accent : .secondary)
                            } else {
                                Text(String(app.name.prefix(1)).uppercased())
                                    .font(.headline)
                                    .foregroundStyle(isExisting ? AppTheme.accent : .secondary)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .foregroundStyle(.primary)

                    if app.urlScheme != nil {
                        Text("Auto-return supported")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                if isExisting {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .listRowBackground(Color.primary.opacity(0.05))
    }

    private var customAppEntry: some View {
        VStack(spacing: 12) {
            TextField("App Name", text: $customAppName)
                .textFieldStyle(.roundedBorder)

            TextField("URL Scheme (optional)", text: $customUrlScheme)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .keyboardType(.URL)

            HStack {
                Button("Cancel") {
                    showingCustomEntry = false
                    customAppName = ""
                    customUrlScheme = ""
                }
                .foregroundStyle(.secondary)

                Spacer()

                Button("Add") {
                    let app = SwiftLinkApp(
                        bundleId: "custom.\(UUID().uuidString)",
                        name: customAppName,
                        urlScheme: customUrlScheme.isEmpty ? nil : customUrlScheme
                    )
                    onSelect(app)
                }
                .disabled(customAppName.isEmpty)
            }
            .padding(.top, 8)
        }
        .listRowBackground(Color.primary.opacity(0.05))
    }
}

#Preview {
    SwiftLinkQuickStartSheet()
        .environmentObject(SharedSettings.shared)
}
