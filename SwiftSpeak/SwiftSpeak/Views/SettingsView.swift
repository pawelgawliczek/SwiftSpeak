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
    @State private var showAddAIProvider = false
    @State private var editingAIProviderConfig: AIProviderConfig?
    @State private var isAddingNewAIProvider = false

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

                    // Unified AI Models Section
                    Section {
                        // Configured AI providers
                        ForEach(settings.configuredAIProviders) { config in
                            ConfiguredAIProviderRow(
                                config: config,
                                colorScheme: colorScheme
                            ) {
                                isAddingNewAIProvider = false
                                editingAIProviderConfig = config
                            }
                            .listRowBackground(rowBackground)
                        }

                        // Add AI Provider button
                        if !settings.availableProvidersToAdd.isEmpty {
                            Button(action: {
                                if settings.subscriptionTier == .free && settings.configuredAIProviders.count >= 1 {
                                    showPaywall = true
                                } else {
                                    showAddAIProvider = true
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(AppTheme.accent)

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text("Add AI Provider")
                                                .font(.callout.weight(.medium))
                                                .foregroundStyle(.primary)

                                            if settings.configuredAIProviders.count >= 1 {
                                                Text("PRO")
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.purple)
                                                    .clipShape(Capsule())
                                            }
                                        }

                                        Text("Add transcription, translation & power mode providers")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if settings.subscriptionTier == .free && settings.configuredAIProviders.count >= 1 {
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
                        Text("Configure AI providers for transcription, translation, and Power Modes. Each capability can use a different model.")
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

                    // Vocabulary Section
                    Section {
                        NavigationLink {
                            VocabularyView()
                        } label: {
                            SettingsRow(
                                icon: "character.book.closed.fill",
                                iconColor: .teal,
                                title: "Vocabulary",
                                subtitle: settings.vocabulary.isEmpty ? "Add words to improve recognition" : "\(settings.vocabulary.count) words"
                            )
                        }
                        .listRowBackground(rowBackground)
                    } header: {
                        Text("Recognition")
                    } footer: {
                        Text("Add names, companies, acronyms, and slang to improve transcription accuracy.")
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
            .sheet(item: $editingAIProviderConfig) { config in
                AIProviderEditorSheet(
                    config: config,
                    isEditing: !isAddingNewAIProvider,
                    onSave: { updatedConfig in
                        if isAddingNewAIProvider {
                            settings.addAIProvider(updatedConfig)
                        } else {
                            settings.updateAIProvider(updatedConfig)
                        }
                    },
                    onDelete: isAddingNewAIProvider ? nil : {
                        settings.removeAIProvider(config.provider)
                    }
                )
            }
            .sheet(isPresented: $showAddAIProvider) {
                AddAIProviderSheet(
                    availableProviders: settings.availableProvidersToAdd,
                    currentTier: settings.subscriptionTier,
                    onSelect: { provider in
                        showAddAIProvider = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isAddingNewAIProvider = true
                            editingAIProviderConfig = AIProviderConfig(provider: provider)
                        }
                    },
                    onShowPaywall: {
                        showPaywall = true
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

// MARK: - Configured AI Provider Row
struct ConfiguredAIProviderRow: View {
    let config: AIProviderConfig
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
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.accent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Provider info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(config.provider.displayName)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.primary)

                        if config.provider.requiresPowerTier {
                            Text("POWER")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }

                        if config.provider.requiresAPIKey {
                            Circle()
                                .fill(config.apiKey.isEmpty ? .orange : .green)
                                .frame(width: 6, height: 6)
                        }
                    }

                    // Show model per category
                    HStack(spacing: 6) {
                        ForEach(config.detailedModelSummary, id: \.0) { category, model in
                            HStack(spacing: 3) {
                                Image(systemName: category.icon)
                                    .font(.caption2)
                                Text(model)
                                    .font(.caption2)
                            }
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

// MARK: - Add AI Provider Sheet
struct AddAIProviderSheet: View {
    let availableProviders: [AIProvider]
    let currentTier: SubscriptionTier
    let onSelect: (AIProvider) -> Void
    let onShowPaywall: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    private func isProviderLocked(_ provider: AIProvider) -> Bool {
        provider.requiresPowerTier && currentTier != .power
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                List {
                    Section {
                        ForEach(availableProviders) { provider in
                            let isLocked = isProviderLocked(provider)

                            Button(action: {
                                HapticManager.selection()
                                if isLocked {
                                    dismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        onShowPaywall()
                                    }
                                } else {
                                    onSelect(provider)
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: provider.icon)
                                        .font(.title3)
                                        .foregroundStyle(isLocked ? .secondary : AppTheme.accent)
                                        .frame(width: 40, height: 40)
                                        .background((isLocked ? Color.secondary : AppTheme.accent).opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Text(provider.displayName)
                                                .font(.callout.weight(.medium))
                                                .foregroundStyle(isLocked ? .secondary : .primary)

                                            if provider.requiresPowerTier {
                                                Text("POWER")
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.orange)
                                                    .clipShape(Capsule())
                                            }
                                        }

                                        Text(provider.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)

                                        // Show capabilities
                                        HStack(spacing: 4) {
                                            ForEach(Array(provider.supportedCategories).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { category in
                                                HStack(spacing: 2) {
                                                    Image(systemName: category.icon)
                                                        .font(.caption2)
                                                }
                                                .foregroundStyle(isLocked ? .secondary : categoryColor(for: category))
                                            }
                                        }
                                    }

                                    Spacer()

                                    if isLocked {
                                        Image(systemName: "lock.fill")
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(AppTheme.accent)
                                    }
                                }
                            }
                            .listRowBackground(rowBackground)
                        }
                    } header: {
                        Text("Available Providers")
                    } footer: {
                        Text("Add an AI provider to use for transcription, translation, or Power Mode. Ollama (local AI) requires a Power subscription.")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add AI Provider")
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

    private func categoryColor(for category: ProviderUsageCategory) -> Color {
        switch category {
        case .transcription: return .blue
        case .translation: return .purple
        case .powerMode: return .orange
        }
    }
}

// MARK: - AI Provider Editor Sheet
struct AIProviderEditorSheet: View {
    let config: AIProviderConfig
    let isEditing: Bool
    let onSave: (AIProviderConfig) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var apiKey: String = ""
    @State private var endpoint: String = ""
    @State private var usageCategories: Set<ProviderUsageCategory> = []
    @State private var transcriptionModel: String = ""
    @State private var translationModel: String = ""
    @State private var powerModeModel: String = ""
    @State private var showDeleteConfirmation = false
    @State private var showInstructions = false
    // Refresh models state
    @State private var isRefreshingModels = false
    @State private var refreshedSTTModels: [String]? = nil
    @State private var refreshedLLMModels: [String]? = nil
    @State private var refreshError: String? = nil

    init(config: AIProviderConfig, isEditing: Bool, onSave: @escaping (AIProviderConfig) -> Void, onDelete: (() -> Void)? = nil) {
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

                    // Capabilities Section with Model Selection
                    Section {
                        ForEach(ProviderUsageCategory.allCases) { category in
                            if config.provider.supportedCategories.contains(category) {
                                VStack(alignment: .leading, spacing: 8) {
                                    // Category toggle
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

                                    // Model picker when enabled
                                    if usageCategories.contains(category) {
                                        Picker("Model", selection: modelBinding(for: category)) {
                                            ForEach(availableModels(for: category), id: \.self) { model in
                                                Text(model).tag(model)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .padding(.leading, 32)
                                    }
                                }
                                .listRowBackground(rowBackground)
                            }
                        }

                        // Refresh Models Button
                        Button(action: {
                            refreshModels()
                        }) {
                            HStack {
                                if isRefreshingModels {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text("Refresh Models")
                                Spacer()
                                if refreshedLLMModels != nil || refreshedSTTModels != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .disabled(isRefreshingModels || apiKey.isEmpty)
                        .listRowBackground(rowBackground)

                        // Show refresh error if any
                        if let error = refreshError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .listRowBackground(rowBackground)
                        }
                    } header: {
                        Text("Capabilities & Models")
                    } footer: {
                        Text("Enable capabilities and select which model to use for each. Tap 'Refresh Models' to fetch the latest available models from the provider.")
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

                    // Delete Section
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

    private func categoryColor(for category: ProviderUsageCategory) -> Color {
        switch category {
        case .transcription: return .blue
        case .translation: return .purple
        case .powerMode: return .orange
        }
    }

    private func modelBinding(for category: ProviderUsageCategory) -> Binding<String> {
        switch category {
        case .transcription:
            return $transcriptionModel
        case .translation:
            return $translationModel
        case .powerMode:
            return $powerModeModel
        }
    }

    private func loadConfig() {
        apiKey = config.apiKey
        endpoint = config.endpoint ?? "http://localhost:11434"
        usageCategories = config.usageCategories
        transcriptionModel = config.transcriptionModel ?? config.provider.defaultSTTModel ?? ""
        translationModel = config.translationModel ?? config.provider.defaultLLMModel ?? ""
        powerModeModel = config.powerModeModel ?? config.provider.defaultLLMModel ?? ""
    }

    private func saveProvider() {
        var updatedConfig = config
        updatedConfig.apiKey = apiKey
        updatedConfig.usageCategories = usageCategories
        updatedConfig.transcriptionModel = usageCategories.contains(.transcription) ? transcriptionModel : nil
        updatedConfig.translationModel = usageCategories.contains(.translation) ? translationModel : nil
        updatedConfig.powerModeModel = usageCategories.contains(.powerMode) ? powerModeModel : nil
        if config.provider == .ollama {
            updatedConfig.endpoint = endpoint
        }

        onSave(updatedConfig)
        dismiss()
    }

    /// Get available models for a category, preferring refreshed models if available
    private func availableModels(for category: ProviderUsageCategory) -> [String] {
        switch category {
        case .transcription:
            return refreshedSTTModels ?? config.provider.availableSTTModels
        case .translation, .powerMode:
            return refreshedLLMModels ?? config.provider.availableLLMModels
        }
    }

    /// Fetch available models from the provider's API
    private func refreshModels() {
        isRefreshingModels = true
        refreshError = nil

        Task {
            do {
                let (sttModels, llmModels) = try await fetchModelsFromAPI()
                await MainActor.run {
                    refreshedSTTModels = sttModels.isEmpty ? nil : sttModels
                    refreshedLLMModels = llmModels.isEmpty ? nil : llmModels
                    isRefreshingModels = false
                    HapticManager.success()
                }
            } catch {
                await MainActor.run {
                    refreshError = error.localizedDescription
                    isRefreshingModels = false
                    HapticManager.error()
                }
            }
        }
    }

    /// Fetch models from provider API
    private func fetchModelsFromAPI() async throws -> (sttModels: [String], llmModels: [String]) {
        switch config.provider {
        case .openAI:
            return try await fetchOpenAIModels()
        case .anthropic:
            // Anthropic doesn't have a models endpoint, return defaults
            return ([], config.provider.availableLLMModels)
        case .google:
            return try await fetchGoogleModels()
        case .ollama:
            return try await fetchOllamaModels()
        case .elevenLabs:
            // ElevenLabs doesn't expose models via API
            return (config.provider.availableSTTModels, [])
        case .deepgram:
            // Deepgram models are documented, not via API
            return (config.provider.availableSTTModels, [])
        }
    }

    private func fetchOpenAIModels() async throws -> (sttModels: [String], llmModels: [String]) {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "OpenAI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch models"])
        }

        struct ModelsResponse: Codable {
            struct Model: Codable {
                let id: String
            }
            let data: [Model]
        }

        let modelsResponse = try JSONDecoder().decode(ModelsResponse.self, from: data)
        let allModels = modelsResponse.data.map { $0.id }

        // Filter STT models (whisper)
        let sttModels = allModels.filter { $0.contains("whisper") }.sorted()

        // Filter LLM models (gpt, o1)
        let llmModels = allModels.filter {
            $0.hasPrefix("gpt-") || $0.hasPrefix("o1") || $0.hasPrefix("o3") || $0.hasPrefix("chatgpt-")
        }.sorted().reversed().map { String($0) }

        return (sttModels, Array(llmModels))
    }

    private func fetchGoogleModels() async throws -> (sttModels: [String], llmModels: [String]) {
        let request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1/models?key=\(apiKey)")!)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "Google", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch models"])
        }

        struct ModelsResponse: Codable {
            struct Model: Codable {
                let name: String
            }
            let models: [Model]
        }

        let modelsResponse = try JSONDecoder().decode(ModelsResponse.self, from: data)
        let allModels = modelsResponse.models.map { $0.name.replacingOccurrences(of: "models/", with: "") }

        // Google doesn't have STT, only LLM
        let llmModels = allModels.filter { $0.contains("gemini") }

        return ([], llmModels)
    }

    private func fetchOllamaModels() async throws -> (sttModels: [String], llmModels: [String]) {
        let baseURL = endpoint.isEmpty ? "http://localhost:11434" : endpoint
        let request = URLRequest(url: URL(string: "\(baseURL)/api/tags")!)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "Ollama", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch models"])
        }

        struct ModelsResponse: Codable {
            struct Model: Codable {
                let name: String
            }
            let models: [Model]
        }

        let modelsResponse = try JSONDecoder().decode(ModelsResponse.self, from: data)
        let allModels = modelsResponse.models.map { $0.name }

        // Ollama models can be used for both STT (whisper) and LLM
        let sttModels = allModels.filter { $0.lowercased().contains("whisper") }
        let llmModels = allModels.filter { !$0.lowercased().contains("whisper") }

        return (sttModels, llmModels)
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

// MARK: - Vocabulary View
struct VocabularyView: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme
    @State private var showAddSheet = false
    @State private var editingEntry: VocabularyEntry?
    @State private var showDeleteConfirmation = false
    @State private var entryToDelete: VocabularyEntry?
    @State private var searchText = ""

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    private var filteredEntries: [VocabularyEntry] {
        if searchText.isEmpty {
            return settings.vocabulary.sorted { $0.category.rawValue < $1.category.rawValue }
        }
        return settings.vocabulary.filter {
            $0.recognizedWord.localizedCaseInsensitiveContains(searchText) ||
            $0.replacementWord.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedEntries: [(VocabularyCategory, [VocabularyEntry])] {
        let grouped = Dictionary(grouping: filteredEntries) { $0.category }
        return VocabularyCategory.allCases.compactMap { category in
            guard let entries = grouped[category], !entries.isEmpty else { return nil }
            return (category, entries)
        }
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            if settings.vocabulary.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(groupedEntries, id: \.0) { category, entries in
                        Section {
                            ForEach(entries) { entry in
                                VocabularyEntryRow(
                                    entry: entry,
                                    colorScheme: colorScheme,
                                    onToggle: {
                                        settings.toggleVocabularyEntry(entry)
                                    },
                                    onEdit: {
                                        editingEntry = entry
                                    }
                                )
                                .listRowBackground(rowBackground)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        entryToDelete = entry
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Image(systemName: category.icon)
                                    .font(.caption)
                                    .foregroundStyle(category.color)
                                Text(category.displayName)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .searchable(text: $searchText, prompt: "Search vocabulary")
            }
        }
        .navigationTitle("Vocabulary")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    showAddSheet = true
                }) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            VocabularyEditorSheet(
                entry: nil,
                onSave: { entry in
                    settings.addVocabularyEntry(entry)
                }
            )
        }
        .sheet(item: $editingEntry) { entry in
            VocabularyEditorSheet(
                entry: entry,
                onSave: { updatedEntry in
                    settings.updateVocabularyEntry(updatedEntry)
                }
            )
        }
        .alert("Delete Word?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                entryToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete {
                    settings.removeVocabularyEntry(entry)
                }
                entryToDelete = nil
            }
        } message: {
            if let entry = entryToDelete {
                Text("This will remove \"\(entry.recognizedWord)\" from your vocabulary.")
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "character.book.closed.fill")
                .font(.system(size: 50))
                .foregroundStyle(.teal.opacity(0.5))

            Text("No Vocabulary Words")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Add names, companies, acronyms, and slang\nto improve transcription accuracy")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                showAddSheet = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Word")
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.teal)
                .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .padding()
    }
}

// MARK: - Vocabulary Entry Row
struct VocabularyEntryRow: View {
    let entry: VocabularyEntry
    let colorScheme: ColorScheme
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                // Enable/disable toggle
                Button(action: {
                    HapticManager.selection()
                    onToggle()
                }) {
                    Image(systemName: entry.isEnabled ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(entry.isEnabled ? entry.category.color : Color.secondary.opacity(0.3))
                }
                .buttonStyle(.plain)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(entry.recognizedWord)
                            .font(.callout)
                            .foregroundStyle(entry.isEnabled ? .secondary : .tertiary)
                            .strikethrough(!entry.isEnabled)

                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Text(entry.replacementWord)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(entry.isEnabled ? .primary : .secondary)
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

// MARK: - Vocabulary Editor Sheet
struct VocabularyEditorSheet: View {
    let entry: VocabularyEntry?
    let onSave: (VocabularyEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var recognizedWord: String = ""
    @State private var replacementWord: String = ""
    @State private var selectedCategory: VocabularyCategory = .name
    @State private var isEnabled: Bool = true

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    private var isValid: Bool {
        !recognizedWord.trimmingCharacters(in: .whitespaces).isEmpty &&
        !replacementWord.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isEditing: Bool {
        entry != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                List {
                    // Words Section
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recognized As")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)

                            TextField("e.g., john doe", text: $recognizedWord)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .listRowBackground(rowBackground)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Replace With")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)

                            TextField("e.g., John Doe", text: $replacementWord)
                                .autocorrectionDisabled()
                        }
                        .listRowBackground(rowBackground)
                    } header: {
                        Text("Word Replacement")
                    } footer: {
                        Text("The recognized word is what the transcription might produce. The replacement is the correct form.")
                    }

                    // Category Section
                    Section {
                        ForEach(VocabularyCategory.allCases) { category in
                            Button(action: {
                                HapticManager.selection()
                                selectedCategory = category
                            }) {
                                HStack {
                                    Image(systemName: category.icon)
                                        .font(.body)
                                        .foregroundStyle(category.color)
                                        .frame(width: 24)

                                    Text(category.displayName)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if selectedCategory == category {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.teal)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(rowBackground)
                        }
                    } header: {
                        Text("Category")
                    }

                    // Enable Section
                    Section {
                        Toggle("Enabled", isOn: $isEnabled)
                            .listRowBackground(rowBackground)
                    } footer: {
                        Text("Disabled words will not be replaced during transcription.")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(isEditing ? "Edit Word" : "Add Word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveEntry()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let entry = entry {
                    recognizedWord = entry.recognizedWord
                    replacementWord = entry.replacementWord
                    selectedCategory = entry.category
                    isEnabled = entry.isEnabled
                }
            }
        }
    }

    private func saveEntry() {
        let savedEntry = VocabularyEntry(
            id: entry?.id ?? UUID(),
            recognizedWord: recognizedWord.trimmingCharacters(in: .whitespaces),
            replacementWord: replacementWord.trimmingCharacters(in: .whitespaces),
            category: selectedCategory,
            isEnabled: isEnabled,
            createdAt: entry?.createdAt ?? Date(),
            updatedAt: Date()
        )
        onSave(savedEntry)
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

#Preview("Power - Dark") {
    SettingsPreviewWrapper(tier: .power, colorScheme: .dark)
}

#Preview("AI Provider Editor - OpenAI") {
    AIProviderEditorSheet(
        config: AIProviderConfig(
            provider: .openAI,
            apiKey: "sk-xxx",
            usageCategories: [.transcription, .translation, .powerMode],
            transcriptionModel: "whisper-1",
            translationModel: "gpt-4o-mini",
            powerModeModel: "gpt-4o"
        ),
        isEditing: true,
        onSave: { _ in },
        onDelete: nil
    )
}

#Preview("AI Provider Editor - Anthropic (New)") {
    AIProviderEditorSheet(
        config: AIProviderConfig(provider: .anthropic),
        isEditing: false,
        onSave: { _ in },
        onDelete: nil
    )
}

#Preview("Add AI Provider Sheet") {
    AddAIProviderSheet(
        availableProviders: [.anthropic, .google, .elevenLabs, .deepgram, .ollama],
        currentTier: .power,
        onSelect: { _ in },
        onShowPaywall: { }
    )
}
