//
//  SettingsView.swift
//  SwiftSpeak
//
//  App settings and configuration
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme
    @State private var showPaywall = false
    @State private var showAPIKeyEditor = false
    @State private var editingProvider: STTProvider?

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                List {
                    // Subscription Section
                    Section {
                        SubscriptionCard(tier: settings.subscriptionTier) {
                            showPaywall = true
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }

                    // Provider Section
                    Section {
                        ForEach(STTProvider.allCases) { provider in
                            ProviderRow(
                                provider: provider,
                                isSelected: settings.selectedProvider == provider,
                                hasAPIKey: settings.hasValidAPIKey(for: provider),
                                isPro: provider.isPro,
                                currentTier: settings.subscriptionTier
                            ) {
                                if provider.isPro && settings.subscriptionTier == .free {
                                    showPaywall = true
                                } else {
                                    settings.selectedProvider = provider
                                }
                            } onEditKey: {
                                editingProvider = provider
                                showAPIKeyEditor = true
                            }
                        }
                        .listRowBackground(rowBackground)
                    } header: {
                        Text("Transcription Provider")
                    }

                    // Templates Section
                    Section {
                        NavigationLink {
                            TemplatesView()
                        } label: {
                            SettingsRow(
                                icon: "doc.text",
                                iconColor: .orange,
                                title: "Custom Templates",
                                subtitle: "Create your own formatting styles"
                            )
                        }
                        .listRowBackground(rowBackground)
                    } header: {
                        Text("Formatting")
                    }

                    // Language Section
                    Section {
                        NavigationLink {
                            LanguagePickerView(selectedLanguage: $settings.selectedTargetLanguage)
                        } label: {
                            HStack {
                                SettingsRow(
                                    icon: "globe",
                                    iconColor: .purple,
                                    title: "Translation Language",
                                    subtitle: "\(settings.selectedTargetLanguage.flag) \(settings.selectedTargetLanguage.displayName)"
                                )
                            }
                        }
                        .listRowBackground(rowBackground)
                    } header: {
                        Text("Translation")
                    }

                    // About Section
                    Section {
                        SettingsRow(
                            icon: "info.circle",
                            iconColor: .blue,
                            title: "Version",
                            subtitle: "1.0.0 (Build 1)"
                        )
                        .listRowBackground(rowBackground)

                        Button(action: {
                            if let url = URL(string: "https://swiftspeak.app/privacy") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            SettingsRow(
                                icon: "hand.raised",
                                iconColor: .green,
                                title: "Privacy Policy",
                                subtitle: nil
                            )
                        }
                        .listRowBackground(rowBackground)

                        Button(action: {
                            if let url = URL(string: "https://swiftspeak.app/terms") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            SettingsRow(
                                icon: "doc.plaintext",
                                iconColor: .gray,
                                title: "Terms of Service",
                                subtitle: nil
                            )
                        }
                        .listRowBackground(rowBackground)
                    } header: {
                        Text("About")
                    }

                    // Debug Section (Development only)
                    Section {
                        Button(action: {
                            settings.resetOnboarding()
                        }) {
                            SettingsRow(
                                icon: "arrow.counterclockwise",
                                iconColor: .red,
                                title: "Reset Onboarding",
                                subtitle: "Show onboarding again"
                            )
                        }
                        .listRowBackground(rowBackground)

                        Button(action: {
                            addMockHistory()
                        }) {
                            SettingsRow(
                                icon: "plus.circle",
                                iconColor: .green,
                                title: "Add Mock History",
                                subtitle: "Add sample transcriptions"
                            )
                        }
                        .listRowBackground(rowBackground)

                        NavigationLink {
                            KeyboardPreviewView()
                        } label: {
                            SettingsRow(
                                icon: "keyboard",
                                iconColor: .blue,
                                title: "Keyboard Preview",
                                subtitle: "See how the keyboard looks"
                            )
                        }
                        .listRowBackground(rowBackground)

                    } header: {
                        Text("Debug")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showAPIKeyEditor) {
                if let provider = editingProvider {
                    APIKeyEditorView(provider: provider)
                }
            }
        }
    }

    private func addMockHistory() {
        let mockTexts = [
            "Hey team, just wanted to follow up on our discussion from yesterday. I think we should move forward with the new design.",
            "Don't forget to pick up milk and eggs from the grocery store on your way home.",
            "The quarterly report shows a 15% increase in user engagement compared to last quarter.",
            "I'll be working from home tomorrow. Please reach out via Slack if you need anything urgent."
        ]

        for (index, text) in mockTexts.enumerated() {
            let record = TranscriptionRecord(
                text: text,
                mode: FormattingMode.allCases[index % FormattingMode.allCases.count],
                provider: .openAI,
                timestamp: Date().addingTimeInterval(-Double(index * 3600)),
                duration: Double.random(in: 10...60)
            )
            settings.addTranscription(record)
        }
    }
}

// MARK: - Subscription Card
struct SubscriptionCard: View {
    let tier: SubscriptionTier
    let onUpgrade: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var cardBackground: LinearGradient {
        if tier == .free {
            return LinearGradient(
                colors: colorScheme == .dark ?
                    [Color.white.opacity(0.1), Color.white.opacity(0.05)] :
                    [Color.black.opacity(0.05), Color.black.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [AppTheme.accent.opacity(0.3), AppTheme.accentSecondary.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Plan")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(tier.displayName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                if tier == .free {
                    Button(action: {
                        HapticManager.lightTap()
                        onUpgrade()
                    }) {
                        Text("Upgrade")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(AppTheme.accentGradient)
                            .clipShape(Capsule())
                    }
                }
            }

            if tier != .power {
                Text("Unlock unlimited transcriptions, multiple providers, and more!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Provider Row
struct ProviderRow: View {
    let provider: STTProvider
    let isSelected: Bool
    let hasAPIKey: Bool
    let isPro: Bool
    let currentTier: SubscriptionTier
    let onSelect: () -> Void
    let onEditKey: () -> Void

    var isLocked: Bool {
        isPro && currentTier == .free
    }

    var body: some View {
        HStack(spacing: 16) {
            // Selection indicator
            ZStack {
                Circle()
                    .stroke(isSelected ? AppTheme.accent : Color.secondary.opacity(0.5), lineWidth: 2)
                    .frame(width: 24, height: 24)

                if isSelected {
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 14, height: 14)
                }
            }

            // Provider info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(provider.displayName)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(isLocked ? .secondary : .primary)

                    if isPro {
                        Text("PRO")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple)
                            .clipShape(Capsule())
                    }
                }

                if provider.requiresAPIKey {
                    Text(hasAPIKey ? "API key configured" : "API key required")
                        .font(.caption)
                        .foregroundStyle(hasAPIKey ? .green : .orange)
                }
            }

            Spacer()

            // Lock or edit button
            if isLocked {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
            } else if provider.requiresAPIKey {
                Button(action: {
                    HapticManager.lightTap()
                    onEditKey()
                }) {
                    Image(systemName: "pencil")
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isLocked {
                HapticManager.selection()
                onSelect()
            }
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .foregroundStyle(.primary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Templates View (Placeholder)
struct TemplatesView: View {
    @Environment(\.colorScheme) var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "doc.text")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)

                Text("Custom Templates")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Coming in Phase 2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Templates")
    }
}

// MARK: - Language Picker View
struct LanguagePickerView: View {
    @Binding var selectedLanguage: Language
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

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
                ForEach(Language.allCases) { language in
                    Button(action: {
                        HapticManager.selection()
                        selectedLanguage = language
                        dismiss()
                    }) {
                        HStack {
                            Text(language.flag)
                                .font(.title2)

                            Text(language.displayName)
                                .foregroundStyle(.primary)

                            Spacer()

                            if selectedLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }
                    .listRowBackground(rowBackground)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Target Language")
    }
}

// MARK: - API Key Editor View
struct APIKeyEditorView: View {
    let provider: STTProvider
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var settings = SharedSettings.shared
    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var isValid = false

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Provider icon
                    Image(systemName: provider.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 80, height: 80)
                        .background(AppTheme.accent.opacity(0.2))
                        .clipShape(Circle())

                    Text(provider.displayName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    // API Key input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        SecureField("Enter API key", text: $apiKey)
                            .textContentType(.password)
                            .padding(16)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    // Save button
                    Button(action: saveKey) {
                        Text("Save")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .padding(.vertical, 6)
                            .background(apiKey.isEmpty ? LinearGradient(colors: [.gray, .gray], startPoint: .leading, endPoint: .trailing) : AppTheme.accentGradient)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                    }
                    .disabled(apiKey.isEmpty)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
                .padding(.top, 32)
            }
            .navigationTitle("Edit API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentKey()
            }
        }
    }

    private func loadCurrentKey() {
        switch provider {
        case .openAI:
            apiKey = settings.openAIAPIKey ?? ""
        case .elevenLabs:
            apiKey = settings.elevenLabsAPIKey ?? ""
        case .deepgram:
            apiKey = settings.deepgramAPIKey ?? ""
        case .ollama:
            apiKey = settings.ollamaEndpoint ?? ""
        }
    }

    private func saveKey() {
        switch provider {
        case .openAI:
            settings.openAIAPIKey = apiKey
        case .elevenLabs:
            settings.elevenLabsAPIKey = apiKey
        case .deepgram:
            settings.deepgramAPIKey = apiKey
        case .ollama:
            settings.ollamaEndpoint = apiKey
        }
        dismiss()
    }
}

#Preview("Dark") {
    SettingsView()
        .environmentObject(SharedSettings.shared)
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    SettingsView()
        .environmentObject(SharedSettings.shared)
        .preferredColorScheme(.light)
}
