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
    @State private var showAddSTTProvider = false
    @State private var editingSTTProviderConfig: STTProviderConfig?
    @State private var isAddingNewSTTProvider = false
    @State private var showAddLLMProvider = false
    @State private var editingLLMProviderConfig: LLMProviderConfig?
    @State private var isAddingNewLLMProvider = false

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

                    // Transcription Providers Section
                    Section {
                        // Configured providers
                        ForEach(settings.configuredSTTProviders) { config in
                            ConfiguredSTTProviderRow(
                                config: config,
                                isSelected: settings.selectedProvider == config.provider,
                                colorScheme: colorScheme
                            ) {
                                settings.selectedProvider = config.provider
                            } onEdit: {
                                isAddingNewSTTProvider = false
                                editingSTTProviderConfig = config
                            }
                            .listRowBackground(rowBackground)
                        }

                        // Add Provider button
                        if !settings.availableSTTProvidersToAdd.isEmpty {
                            Button(action: {
                                if settings.subscriptionTier == .free {
                                    showPaywall = true
                                } else {
                                    showAddSTTProvider = true
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(AppTheme.accent)

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text("Add Provider")
                                                .font(.callout.weight(.medium))
                                                .foregroundStyle(.primary)

                                            Text("PRO")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.purple)
                                                .clipShape(Capsule())
                                        }

                                        Text("Use multiple transcription services")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if settings.subscriptionTier == .free {
                                        Image(systemName: "lock.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .listRowBackground(rowBackground)
                        }
                    } header: {
                        Text("Transcription")
                    }

                    // AI Models Section (Translation & Power Mode)
                    Section {
                        // Configured LLM providers
                        ForEach(settings.configuredLLMProviders) { config in
                            ConfiguredLLMProviderRow(
                                config: config,
                                colorScheme: colorScheme
                            ) {
                                isAddingNewLLMProvider = false
                                editingLLMProviderConfig = config
                            }
                            .listRowBackground(rowBackground)
                        }

                        // Add AI Model button
                        if !settings.availableLLMProvidersToAdd.isEmpty {
                            Button(action: {
                                if settings.subscriptionTier == .free {
                                    showPaywall = true
                                } else {
                                    showAddLLMProvider = true
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.orange)

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text("Add AI Model")
                                                .font(.callout.weight(.medium))
                                                .foregroundStyle(.primary)

                                            Text("PRO")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.purple)
                                                .clipShape(Capsule())
                                        }

                                        Text("Use different models for translation & modes")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if settings.subscriptionTier == .free {
                                        Image(systemName: "lock.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .listRowBackground(rowBackground)
                        }
                    } header: {
                        Text("AI Models")
                    } footer: {
                        Text("Configure which AI models are used for translation and Power Modes. Enable categories for each model when editing.")
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
            // STT Provider Sheets
            .sheet(item: $editingSTTProviderConfig) { config in
                STTProviderEditorSheet(
                    config: config,
                    isEditing: !isAddingNewSTTProvider,
                    onSave: { updatedConfig in
                        if isAddingNewSTTProvider {
                            settings.addSTTProvider(updatedConfig)
                        } else {
                            settings.updateSTTProvider(updatedConfig)
                        }
                    },
                    onDelete: isAddingNewSTTProvider ? nil : {
                        settings.removeSTTProvider(config.provider)
                    }
                )
            }
            .sheet(isPresented: $showAddSTTProvider) {
                AddSTTProviderSheet(
                    availableProviders: settings.availableSTTProvidersToAdd,
                    onSelect: { provider in
                        showAddSTTProvider = false
                        // Small delay to allow sheet dismiss animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isAddingNewSTTProvider = true
                            editingSTTProviderConfig = STTProviderConfig(provider: provider)
                        }
                    }
                )
            }
            // LLM Provider Sheets
            .sheet(item: $editingLLMProviderConfig) { config in
                LLMProviderEditorSheet(
                    config: config,
                    isEditing: !isAddingNewLLMProvider,
                    onSave: { updatedConfig in
                        if isAddingNewLLMProvider {
                            settings.addLLMProvider(updatedConfig)
                        } else {
                            settings.updateLLMProvider(updatedConfig)
                        }
                    },
                    onDelete: isAddingNewLLMProvider ? nil : {
                        settings.removeLLMProvider(config.provider)
                    }
                )
            }
            .sheet(isPresented: $showAddLLMProvider) {
                AddLLMProviderSheet(
                    availableProviders: settings.availableLLMProvidersToAdd,
                    onSelect: { provider in
                        showAddLLMProvider = false
                        // Small delay to allow sheet dismiss animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isAddingNewLLMProvider = true
                            editingLLMProviderConfig = LLMProviderConfig(provider: provider)
                        }
                    }
                )
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

                    HStack(spacing: 8) {
                        Text(tier.displayName)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)

                        if tier != .free {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
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
                } else if tier == .pro {
                    Button(action: {
                        HapticManager.lightTap()
                        onUpgrade()
                    }) {
                        Text("Go Power")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.accent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }

            // Different messages based on tier
            switch tier {
            case .free:
                Text("Unlock unlimited transcriptions, multiple providers, and more!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .pro:
                Text("Unlimited transcriptions & multiple providers unlocked!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .power:
                Text("All features unlocked. Thank you for your support!")
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

// MARK: - Configured STT Provider Row
struct ConfiguredSTTProviderRow: View {
    let config: STTProviderConfig
    let isSelected: Bool
    let colorScheme: ColorScheme
    let onSelect: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator - tappable to select
            Button(action: {
                HapticManager.selection()
                onSelect()
            }) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? AppTheme.accent : Color.secondary.opacity(0.5), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(AppTheme.accent)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .buttonStyle(.plain)

            // Provider icon
            Image(systemName: config.provider.icon)
                .font(.title3)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 32, height: 32)
                .background(AppTheme.accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Provider info - tappable to edit
            Button(action: {
                HapticManager.lightTap()
                onEdit()
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(config.provider.displayName)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.primary)

                        HStack(spacing: 6) {
                            Text(config.model)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if config.provider.requiresAPIKey {
                                Circle()
                                    .fill(config.apiKey.isEmpty ? .orange : .green)
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Configured LLM Provider Row
struct ConfiguredLLMProviderRow: View {
    let config: LLMProviderConfig
    let colorScheme: ColorScheme
    let onEdit: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.lightTap()
            onEdit()
        }) {
            HStack(spacing: 12) {
                // Provider icon
                Image(systemName: config.provider.icon)
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .frame(width: 32, height: 32)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Provider info
                VStack(alignment: .leading, spacing: 2) {
                    Text(config.provider.displayName)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Text(config.model)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if config.provider.requiresAPIKey {
                            Circle()
                                .fill(config.apiKey.isEmpty ? .orange : .green)
                                .frame(width: 6, height: 6)
                        }
                    }

                    // Usage categories
                    HStack(spacing: 4) {
                        ForEach(Array(config.usageCategories).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { category in
                            Text(category.displayName)
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(categoryColor(for: category))
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func categoryColor(for category: ProviderUsageCategory) -> Color {
        switch category {
        case .transcription: return .blue
        case .translation: return .purple
        case .powerMode: return .orange
        }
    }
}

// MARK: - Add STT Provider Sheet
struct AddSTTProviderSheet: View {
    let availableProviders: [STTProvider]
    let onSelect: (STTProvider) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

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
                    Section {
                        ForEach(availableProviders) { provider in
                            Button(action: {
                                HapticManager.selection()
                                onSelect(provider)
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: provider.icon)
                                        .font(.title3)
                                        .foregroundStyle(AppTheme.accent)
                                        .frame(width: 40, height: 40)
                                        .background(AppTheme.accent.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(provider.displayName)
                                            .font(.callout.weight(.medium))
                                            .foregroundStyle(.primary)

                                        Text(provider.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }

                                    Spacer()

                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                            .listRowBackground(rowBackground)
                        }
                    } header: {
                        Text("Available Providers")
                    } footer: {
                        Text("Add a transcription provider to use with SwiftSpeak. Each provider requires an API key.")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Provider")
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

// MARK: - Add LLM Provider Sheet
struct AddLLMProviderSheet: View {
    let availableProviders: [LLMProvider]
    let onSelect: (LLMProvider) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

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
                    Section {
                        ForEach(availableProviders) { provider in
                            Button(action: {
                                HapticManager.selection()
                                onSelect(provider)
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: provider.icon)
                                        .font(.title3)
                                        .foregroundStyle(.orange)
                                        .frame(width: 40, height: 40)
                                        .background(Color.orange.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(provider.displayName)
                                            .font(.callout.weight(.medium))
                                            .foregroundStyle(.primary)

                                        Text(provider.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }

                                    Spacer()

                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.orange)
                                }
                            }
                            .listRowBackground(rowBackground)
                        }
                    } header: {
                        Text("Available AI Models")
                    } footer: {
                        Text("Add an AI model for translation and Power Mode features. You can enable specific categories when configuring the model.")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add AI Model")
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

// MARK: - STT Provider Editor Sheet
struct STTProviderEditorSheet: View {
    let config: STTProviderConfig
    let isEditing: Bool
    let onSave: (STTProviderConfig) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var apiKey: String = ""
    @State private var selectedModel: String = ""
    @State private var endpoint: String = ""
    @State private var showDeleteConfirmation = false
    @State private var showInstructions = false

    init(config: STTProviderConfig, isEditing: Bool, onSave: @escaping (STTProviderConfig) -> Void, onDelete: (() -> Void)? = nil) {
        self.config = config
        self.isEditing = isEditing
        self.onSave = onSave
        self.onDelete = onDelete
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    private var canSave: Bool {
        if config.provider.requiresAPIKey {
            return !apiKey.isEmpty
        } else {
            // Ollama needs endpoint
            return !endpoint.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                List {
                    // Provider Info Header
                    Section {
                        HStack(spacing: 16) {
                            Image(systemName: config.provider.icon)
                                .font(.title)
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 56, height: 56)
                                .background(AppTheme.accent.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(config.provider.displayName)
                                    .font(.title3.weight(.semibold))

                                Text(config.provider.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                    }

                    // API Key or Endpoint Section
                    Section {
                        if config.provider.requiresAPIKey {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("API Key")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)

                                SecureField("Enter your API key", text: $apiKey)
                                    .textContentType(.password)
                                    .autocorrectionDisabled()
                            }
                            .listRowBackground(rowBackground)
                        } else {
                            // Ollama endpoint
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Server Address")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)

                                TextField("http://localhost:11434", text: $endpoint)
                                    .textContentType(.URL)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                            }
                            .listRowBackground(rowBackground)
                        }
                    } header: {
                        Text("Configuration")
                    }

                    // Model Selection
                    Section {
                        Picker("Model", selection: $selectedModel) {
                            ForEach(config.provider.availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .listRowBackground(rowBackground)
                    } header: {
                        Text("Model")
                    } footer: {
                        Text("Select the transcription model to use with this provider.")
                    }

                    // Setup Instructions
                    Section {
                        DisclosureGroup("How to get your API key", isExpanded: $showInstructions) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(config.provider.setupInstructions)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                if let helpURL = config.provider.apiKeyHelpURL {
                                    Button(action: {
                                        UIApplication.shared.open(helpURL)
                                    }) {
                                        HStack {
                                            Image(systemName: "arrow.up.right.square")
                                            Text("Open \(config.provider.shortName) Dashboard")
                                        }
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(AppTheme.accent)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(rowBackground)
                    }

                    // Delete Section (only for existing providers, not OpenAI default)
                    if isEditing && config.provider != .openAI && onDelete != nil {
                        Section {
                            Button(role: .destructive, action: {
                                showDeleteConfirmation = true
                            }) {
                                HStack {
                                    Spacer()
                                    Text("Remove Provider")
                                    Spacer()
                                }
                            }
                            .listRowBackground(rowBackground)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(isEditing ? "Edit Provider" : "Add Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveProvider()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                loadConfig()
            }
            .alert("Remove Provider?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("This will remove \(config.provider.displayName) from your configured providers.")
            }
        }
    }

    private func loadConfig() {
        apiKey = config.apiKey
        selectedModel = config.model
        endpoint = config.endpoint ?? "http://localhost:11434"
    }

    private func saveProvider() {
        var updatedConfig = config
        updatedConfig.apiKey = apiKey
        updatedConfig.model = selectedModel
        if config.provider == .ollama {
            updatedConfig.endpoint = endpoint
        }

        onSave(updatedConfig)
        dismiss()
    }
}

// MARK: - LLM Provider Editor Sheet
struct LLMProviderEditorSheet: View {
    let config: LLMProviderConfig
    let isEditing: Bool
    let onSave: (LLMProviderConfig) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var apiKey: String = ""
    @State private var selectedModel: String = ""
    @State private var endpoint: String = ""
    @State private var usageCategories: Set<ProviderUsageCategory> = []
    @State private var showDeleteConfirmation = false
    @State private var showInstructions = false

    init(config: LLMProviderConfig, isEditing: Bool, onSave: @escaping (LLMProviderConfig) -> Void, onDelete: (() -> Void)? = nil) {
        self.config = config
        self.isEditing = isEditing
        self.onSave = onSave
        self.onDelete = onDelete
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    private var canSave: Bool {
        let hasCredentials: Bool
        if config.provider.requiresAPIKey {
            hasCredentials = !apiKey.isEmpty
        } else {
            hasCredentials = !endpoint.isEmpty
        }
        return hasCredentials && !usageCategories.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                List {
                    // Provider Info Header
                    Section {
                        HStack(spacing: 16) {
                            Image(systemName: config.provider.icon)
                                .font(.title)
                                .foregroundStyle(.orange)
                                .frame(width: 56, height: 56)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(config.provider.displayName)
                                    .font(.title3.weight(.semibold))

                                Text(config.provider.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                    }

                    // API Key or Endpoint Section
                    Section {
                        if config.provider.requiresAPIKey {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("API Key")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)

                                SecureField("Enter your API key", text: $apiKey)
                                    .textContentType(.password)
                                    .autocorrectionDisabled()
                            }
                            .listRowBackground(rowBackground)
                        } else {
                            // Ollama endpoint
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Server Address")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)

                                TextField("http://localhost:11434", text: $endpoint)
                                    .textContentType(.URL)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                            }
                            .listRowBackground(rowBackground)
                        }
                    } header: {
                        Text("Configuration")
                    }

                    // Model Selection
                    Section {
                        Picker("Model", selection: $selectedModel) {
                            ForEach(config.provider.availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .listRowBackground(rowBackground)
                    } header: {
                        Text("Model")
                    }

                    // Usage Categories Section
                    Section {
                        ForEach(ProviderUsageCategory.allCases) { category in
                            Button(action: {
                                HapticManager.selection()
                                if usageCategories.contains(category) {
                                    usageCategories.remove(category)
                                } else {
                                    usageCategories.insert(category)
                                }
                            }) {
                                HStack {
                                    Image(systemName: category.icon)
                                        .font(.body)
                                        .foregroundStyle(categoryColor(for: category))
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(category.displayName)
                                            .font(.callout.weight(.medium))
                                            .foregroundStyle(.primary)

                                        Text(category.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: usageCategories.contains(category) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(usageCategories.contains(category) ? categoryColor(for: category) : Color.secondary.opacity(0.3))
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(rowBackground)
                        }
                    } header: {
                        Text("Use For")
                    } footer: {
                        Text("Select which features should use this AI model. At least one category is required.")
                    }

                    // Setup Instructions
                    Section {
                        DisclosureGroup("How to get your API key", isExpanded: $showInstructions) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(config.provider.setupInstructions)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                if let helpURL = config.provider.apiKeyHelpURL {
                                    Button(action: {
                                        UIApplication.shared.open(helpURL)
                                    }) {
                                        HStack {
                                            Image(systemName: "arrow.up.right.square")
                                            Text("Open \(config.provider.shortName) Dashboard")
                                        }
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.orange)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(rowBackground)
                    }

                    // Delete Section (only for existing providers, not OpenAI default)
                    if isEditing && config.provider != .openAI && onDelete != nil {
                        Section {
                            Button(role: .destructive, action: {
                                showDeleteConfirmation = true
                            }) {
                                HStack {
                                    Spacer()
                                    Text("Remove AI Model")
                                    Spacer()
                                }
                            }
                            .listRowBackground(rowBackground)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(isEditing ? "Edit AI Model" : "Add AI Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveProvider()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                loadConfig()
            }
            .alert("Remove AI Model?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("This will remove \(config.provider.displayName) from your configured AI models.")
            }
        }
    }

    private func categoryColor(for category: ProviderUsageCategory) -> Color {
        switch category {
        case .transcription: return .blue
        case .translation: return .purple
        case .powerMode: return .orange
        }
    }

    private func loadConfig() {
        apiKey = config.apiKey
        selectedModel = config.model
        endpoint = config.endpoint ?? "http://localhost:11434"
        usageCategories = config.usageCategories
    }

    private func saveProvider() {
        var updatedConfig = config
        updatedConfig.apiKey = apiKey
        updatedConfig.model = selectedModel
        updatedConfig.usageCategories = usageCategories
        if config.provider == .ollama {
            updatedConfig.endpoint = endpoint
        }

        onSave(updatedConfig)
        dismiss()
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

// MARK: - Preview Helper
struct SettingsPreviewWrapper: View {
    let tier: SubscriptionTier
    let colorScheme: ColorScheme

    @StateObject private var settings = SharedSettings.shared

    var body: some View {
        SettingsView()
            .environmentObject(settings)
            .preferredColorScheme(colorScheme)
            .onAppear {
                settings.subscriptionTier = tier
                // Add multiple providers for Pro/Power previews
                if tier != .free {
                    if settings.configuredSTTProviders.count == 1 {
                        settings.addSTTProvider(STTProviderConfig(provider: .elevenLabs, apiKey: "el_xxx", model: "scribe_v1"))
                        settings.addSTTProvider(STTProviderConfig(provider: .deepgram, apiKey: "dg_xxx", model: "nova-2"))
                    }
                }
            }
    }
}

#Preview("Free - Dark") {
    SettingsPreviewWrapper(tier: .free, colorScheme: .dark)
}

#Preview("Free - Light") {
    SettingsPreviewWrapper(tier: .free, colorScheme: .light)
}

#Preview("Pro - Dark") {
    SettingsPreviewWrapper(tier: .pro, colorScheme: .dark)
}

#Preview("Pro - Light") {
    SettingsPreviewWrapper(tier: .pro, colorScheme: .light)
}

#Preview("Power - Dark") {
    SettingsPreviewWrapper(tier: .power, colorScheme: .dark)
}

#Preview("Power - Light") {
    SettingsPreviewWrapper(tier: .power, colorScheme: .light)
}

// MARK: - STT Provider Sheet Previews
#Preview("Add STT Provider Sheet") {
    AddSTTProviderSheet(
        availableProviders: [.elevenLabs, .deepgram, .ollama],
        onSelect: { _ in }
    )
}

#Preview("STT Provider Editor - OpenAI") {
    STTProviderEditorSheet(
        config: STTProviderConfig(provider: .openAI, apiKey: "sk-xxx", model: "whisper-1"),
        isEditing: true,
        onSave: { _ in },
        onDelete: nil
    )
}

#Preview("STT Provider Editor - ElevenLabs (New)") {
    STTProviderEditorSheet(
        config: STTProviderConfig(provider: .elevenLabs),
        isEditing: false,
        onSave: { _ in },
        onDelete: nil
    )
}

#Preview("STT Provider Editor - Deepgram") {
    STTProviderEditorSheet(
        config: STTProviderConfig(provider: .deepgram, apiKey: "dg_xxx", model: "nova-2"),
        isEditing: true,
        onSave: { _ in },
        onDelete: { }
    )
}

#Preview("STT Provider Editor - Ollama") {
    STTProviderEditorSheet(
        config: STTProviderConfig(provider: .ollama, endpoint: "http://localhost:11434"),
        isEditing: true,
        onSave: { _ in },
        onDelete: { }
    )
}

// MARK: - LLM Provider Sheet Previews
#Preview("Add LLM Provider Sheet") {
    AddLLMProviderSheet(
        availableProviders: [.anthropic, .google, .ollama],
        onSelect: { _ in }
    )
}

#Preview("LLM Provider Editor - OpenAI") {
    LLMProviderEditorSheet(
        config: LLMProviderConfig(provider: .openAI, apiKey: "sk-xxx", usageCategories: [.translation, .powerMode]),
        isEditing: true,
        onSave: { _ in },
        onDelete: nil
    )
}

#Preview("LLM Provider Editor - Anthropic (New)") {
    LLMProviderEditorSheet(
        config: LLMProviderConfig(provider: .anthropic),
        isEditing: false,
        onSave: { _ in },
        onDelete: nil
    )
}
