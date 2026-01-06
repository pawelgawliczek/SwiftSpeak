//
//  AIProviderEditorSheet.swift
//  SwiftSpeak
//
//  AI provider configuration editor
//

import SwiftUI
import SwiftSpeakCore

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

    // Provider-specific configuration
    @State private var googleProjectId: String = ""
    @State private var azureRegion: AzureRegion = .eastUS
    // Refresh models state
    @State private var isRefreshingModels = false
    @State private var refreshedSTTModels: [String]? = nil
    @State private var refreshedLLMModels: [String]? = nil
    @State private var refreshError: String? = nil

    // Local provider configuration state
    @State private var localProviderType: LocalProviderType = .ollama
    @State private var localServerURL: String = ""
    @State private var localAuthToken: String = ""
    @State private var useAuthToken: Bool = false
    @State private var streamingEnabled: Bool = true
    @State private var timeoutSeconds: Int = 10
    @State private var showAdvancedOptions: Bool = false

    // Connection test state
    @State private var isTestingConnection = false
    @State private var connectionTestResult: LocalProviderConnectionResult? = nil
    @State private var cachedModels: [String] = []

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
        // Must have at least one capability enabled
        guard !usageCategories.isEmpty else { return false }

        if config.provider.isLocalProvider {
            // For local providers, need a valid URL
            return !localServerURL.isEmpty
        } else if config.provider.requiresAPIKey {
            guard !apiKey.isEmpty else { return false }
        }

        // Provider-specific validation
        switch config.provider {
        case .google:
            // Google STT requires Project ID
            if usageCategories.contains(.transcription) && googleProjectId.isEmpty {
                return false
            }
        case .azure:
            // Azure always has a region selected (has default), so no additional validation needed
            break
        default:
            break
        }

        return true
    }

    // MARK: - Body (broken into sub-views for type-checker performance)

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                List {
                    providerInfoHeaderSection
                    configurationSection
                    // Only show capabilities after API key is validated
                    if isAPIKeyValidated || config.provider.isLocalProvider {
                        capabilitiesSection
                    }
                    deleteSection
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

    // MARK: - Provider Info Header Section

    private var providerInfoHeaderSection: some View {
        Section {
            HStack(spacing: 16) {
                ProviderIcon(config.provider, size: .extraLarge, style: .filled)

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
    }

    // MARK: - Configuration Section

    @ViewBuilder
    private var configurationSection: some View {
        if config.provider.isLocalProvider {
            localProviderTypeSection
            serverConfigurationSection
            testConnectionSection
            advancedOptionsSection
        } else {
            cloudProviderConfigSection
        }
    }

    // MARK: - Local Provider Type Section

    private var localProviderTypeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(LocalProviderType.allCases) { type in
                    localProviderTypeButton(for: type)
                }
            }
            .listRowBackground(rowBackground)
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        } header: {
            Text("Provider Type")
        }
    }

    private func localProviderTypeButton(for type: LocalProviderType) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                localProviderType = type
                if localServerURL.isEmpty || localServerURL == LocalProviderType.ollama.defaultEndpoint ||
                   localServerURL == LocalProviderType.lmStudio.defaultEndpoint ||
                   localServerURL == LocalProviderType.openAICompatible.defaultEndpoint {
                    localServerURL = type.defaultEndpoint
                }
                connectionTestResult = nil
                cachedModels = []
            }
            HapticManager.selection()
        } label: {
            localProviderTypeButtonLabel(for: type)
        }
        .buttonStyle(.plain)
    }

    private func localProviderTypeButtonLabel(for type: LocalProviderType) -> some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.body.weight(.medium))
                .foregroundStyle(localProviderType == type ? .white : .secondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(localProviderType == type ? AppTheme.accentGradient : LinearGradient(colors: [Color.secondary.opacity(0.15)], startPoint: .top, endPoint: .bottom))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(type.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(colorScheme == .dark ? .white : .primary)

                Text(type.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if localProviderType == type {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.accent)
                    .font(.body)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(localProviderType == type ?
                      (colorScheme == .dark ? Color.white.opacity(0.06) : AppTheme.accent.opacity(0.08)) :
                      (colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.02)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(localProviderType == type ? AppTheme.accent.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
    }

    // MARK: - Server Configuration Section

    private var serverConfigurationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                TextField(localProviderType.placeholderEndpoint, text: $localServerURL)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .font(.body)

                Text("IP address or hostname with port (e.g., 192.168.1.50:11434)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .listRowBackground(rowBackground)

            Toggle(isOn: $useAuthToken) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use API Token")
                        .font(.callout)
                    Text("For secured servers requiring authentication")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(AppTheme.accent)
            .listRowBackground(rowBackground)

            if useAuthToken {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("Bearer token", text: $localAuthToken)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .font(.body)
                }
                .listRowBackground(rowBackground)
            }
        } header: {
            Text("Server URL")
        }
    }

    // MARK: - Test Connection Section

    private var testConnectionSection: some View {
        Section {
            Button(action: {
                testConnection()
            }) {
                HStack {
                    if isTestingConnection {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "network")
                    }
                    Text("Test Connection")
                    Spacer()

                    connectionTestResultIndicator
                }
            }
            .disabled(isTestingConnection || localServerURL.isEmpty)
            .listRowBackground(rowBackground)

            connectionErrorRow
            connectionModelsRow
        } header: {
            Text("Connection")
        } footer: {
            Text("Test your connection to fetch available models. Models will be auto-populated after a successful connection.")
        }
    }

    @ViewBuilder
    private var connectionTestResultIndicator: some View {
        if let result = connectionTestResult {
            if result.success {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    if let latency = result.latencyMs {
                        Text("\(latency) ms")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var connectionErrorRow: some View {
        if let result = connectionTestResult, !result.success, let error = result.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(rowBackground)
        }
    }

    @ViewBuilder
    private var connectionModelsRow: some View {
        if let result = connectionTestResult, result.success, !result.availableModels.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(result.availableModels.count) models available")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)

                Text(result.availableModels.prefix(5).joined(separator: ", ") +
                     (result.availableModels.count > 5 ? "..." : ""))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .listRowBackground(rowBackground)
        }
    }

    // MARK: - Advanced Options Section

    private var advancedOptionsSection: some View {
        Section {
            DisclosureGroup("Advanced Options", isExpanded: $showAdvancedOptions) {
                Toggle(isOn: $streamingEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Streaming")
                            .font(.callout)
                        Text("Stream responses in real-time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Request Timeout")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Picker("Timeout", selection: $timeoutSeconds) {
                        ForEach(LocalProviderConfig.timeoutOptions, id: \.self) { seconds in
                            Text("\(seconds)s").tag(seconds)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.top, 8)
            }
        }
        .listRowBackground(rowBackground)
    }

    /// Whether the API key has been validated successfully
    private var isAPIKeyValidated: Bool {
        refreshedLLMModels != nil || refreshedSTTModels != nil
    }

    // MARK: - Cloud Provider Config Section

    private var cloudProviderConfigSection: some View {
        Section {
            // API Key field
            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack {
                    SecureField("Enter your API key", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()

                    if isAPIKeyValidated {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .listRowBackground(rowBackground)

            // Instructions (always visible)
            VStack(alignment: .leading, spacing: 12) {
                Text("How to get your API key:")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(config.provider.setupInstructions)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let helpURL = config.provider.apiKeyHelpURL {
                    Button(action: {
                        UIApplication.shared.open(helpURL)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.square")
                            Text("Open \(config.provider.shortName) Dashboard")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.accent)
                    }
                }
            }
            .padding(.vertical, 4)
            .listRowBackground(rowBackground)

            // Validate button
            Button(action: {
                refreshModels()
            }) {
                HStack {
                    if isRefreshingModels {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: isAPIKeyValidated ? "checkmark.shield.fill" : "checkmark.shield")
                            .foregroundStyle(isAPIKeyValidated ? .green : .primary)
                    }
                    Text(isAPIKeyValidated ? "API Key Validated" : "Validate API Key")
                        .foregroundStyle(isAPIKeyValidated ? .green : .primary)
                    Spacer()
                }
            }
            .disabled(isRefreshingModels || apiKey.isEmpty)
            .listRowBackground(rowBackground)

            // Validation error
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

            // Google Cloud - Project ID (required for STT)
            if config.provider == .google {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Project ID")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        Text("Required for Transcription")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    TextField("your-gcp-project-id", text: $googleProjectId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text("Find this in Google Cloud Console → Project Settings")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .listRowBackground(rowBackground)
            }

            // Azure - Region (required for Translator)
            if config.provider == .azure {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Region")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        Text("Required")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Picker("Azure Region", selection: $azureRegion) {
                        ForEach(AzureRegion.allCases) { region in
                            Text(region.displayName).tag(region)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Select the region where your Azure Translator resource is deployed")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .listRowBackground(rowBackground)
            }
        } header: {
            Text("Configuration")
        }
    }

    // MARK: - Capabilities Section

    private var capabilitiesSection: some View {
        Section {
            ForEach(ProviderUsageCategory.allCases) { category in
                if config.provider.supportedCategories.contains(category) {
                    categoryRow(for: category)
                }
            }
        } header: {
            Text("Capabilities & Models")
        } footer: {
            Text("Enable the capabilities you want to use and select the model for each.")
        }
    }

    private func categoryRow(for category: ProviderUsageCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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

            if usageCategories.contains(category) {
                Picker("Model", selection: modelBinding(for: category)) {
                    ForEach(availableModels(for: category), id: \.self) { model in
                        if category == .transcription && config.provider.supportsStreamingTranscription {
                            HStack {
                                Text(model)
                                if config.provider.modelSupportsStreaming(model) {
                                    Text("⚡")
                                }
                            }.tag(model)
                        } else {
                            Text(model).tag(model)
                        }
                    }
                }
                .pickerStyle(.menu)
                .padding(.leading, 32)

                // Show streaming info for transcription
                if category == .transcription && config.provider.supportsStreamingTranscription {
                    let currentModel = modelBinding(for: category).wrappedValue
                    let supportsStreaming = config.provider.modelSupportsStreaming(currentModel)

                    HStack(spacing: 6) {
                        Image(systemName: supportsStreaming ? "bolt.fill" : "bolt.slash")
                            .foregroundStyle(supportsStreaming ? .green : .secondary)
                            .font(.caption)
                        Text(supportsStreaming ? "Streaming supported" : "Batch only (no streaming)")
                            .font(.caption)
                            .foregroundStyle(supportsStreaming ? .green : .secondary)
                    }
                    .padding(.leading, 32)
                }
            }
        }
        .listRowBackground(rowBackground)
    }

    // MARK: - Delete Section

    @ViewBuilder
    private var deleteSection: some View {
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
        endpoint = config.endpoint ?? ""
        usageCategories = config.usageCategories
        transcriptionModel = config.transcriptionModel ?? config.provider.defaultSTTModel ?? ""
        translationModel = config.translationModel ?? config.provider.defaultLLMModel ?? ""
        powerModeModel = config.powerModeModel ?? config.provider.defaultLLMModel ?? ""

        // Load provider-specific configuration
        googleProjectId = config.googleProjectId ?? ""
        if let regionString = config.azureRegion,
           let region = AzureRegion(rawValue: regionString) {
            azureRegion = region
        }

        // Load local provider config
        if config.provider.isLocalProvider {
            if let localConfig = config.localConfig {
                localProviderType = localConfig.type
                localServerURL = localConfig.baseURL
                localAuthToken = localConfig.authToken ?? ""
                useAuthToken = localConfig.authToken?.isEmpty == false
                streamingEnabled = localConfig.streamingEnabled
                timeoutSeconds = localConfig.timeoutSeconds
            } else {
                localProviderType = .ollama
                localServerURL = LocalProviderType.ollama.defaultEndpoint
            }
            // Load cached models
            cachedModels = config.cachedModels ?? []
        }
    }

    private func saveProvider() {
        var updatedConfig = config
        updatedConfig.apiKey = apiKey
        updatedConfig.usageCategories = usageCategories
        updatedConfig.transcriptionModel = usageCategories.contains(.transcription) ? transcriptionModel : nil
        updatedConfig.translationModel = usageCategories.contains(.translation) ? translationModel : nil
        updatedConfig.powerModeModel = usageCategories.contains(.powerMode) ? powerModeModel : nil

        // Save provider-specific configuration
        if config.provider == .google {
            updatedConfig.googleProjectId = googleProjectId.isEmpty ? nil : googleProjectId
        }
        if config.provider == .azure {
            updatedConfig.azureRegion = azureRegion.rawValue
        }

        if config.provider.isLocalProvider {
            // Save local provider configuration
            updatedConfig.localConfig = LocalProviderConfig(
                type: localProviderType,
                baseURL: localServerURL,
                authToken: useAuthToken ? localAuthToken : nil,
                defaultModel: nil,
                streamingEnabled: streamingEnabled,
                timeoutSeconds: timeoutSeconds
            )
            // Save cached models from connection test
            if !cachedModels.isEmpty {
                updatedConfig.cachedModels = cachedModels
            }
            // Legacy endpoint for backward compatibility
            updatedConfig.endpoint = localServerURL
        }

        onSave(updatedConfig)
        dismiss()
    }

    // MARK: - Test Connection

    private func testConnection() {
        isTestingConnection = true
        connectionTestResult = nil

        Task {
            let startTime = Date()

            do {
                let models = try await fetchLocalModels()
                let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)

                await MainActor.run {
                    cachedModels = models
                    connectionTestResult = .success(latencyMs: latencyMs, models: models)
                    isTestingConnection = false
                    HapticManager.success()

                    // Auto-select first model if none selected
                    if transcriptionModel.isEmpty, let firstSTT = models.first(where: { $0.lowercased().contains("whisper") }) ?? models.first {
                        transcriptionModel = firstSTT
                    }
                    if translationModel.isEmpty, let firstLLM = models.first(where: { !$0.lowercased().contains("whisper") }) ?? models.first {
                        translationModel = firstLLM
                    }
                    if powerModeModel.isEmpty, let firstLLM = models.first(where: { !$0.lowercased().contains("whisper") }) ?? models.first {
                        powerModeModel = firstLLM
                    }
                }
            } catch {
                await MainActor.run {
                    connectionTestResult = .failure(error.localizedDescription)
                    isTestingConnection = false
                    HapticManager.error()
                }
            }
        }
    }

    private func fetchLocalModels() async throws -> [String] {
        let baseURL = localServerURL.trimmingCharacters(in: .whitespaces)
        guard !baseURL.isEmpty else {
            throw NSError(domain: "LocalProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "Server URL is empty"])
        }

        let endpoint = localProviderType.modelsEndpoint
        guard let url = URL(string: baseURL + endpoint) else {
            throw NSError(domain: "LocalProvider", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = TimeInterval(timeoutSeconds)

        // Add auth header if configured
        if useAuthToken && !localAuthToken.isEmpty {
            request.setValue("Bearer \(localAuthToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "LocalProvider", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "LocalProvider", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned \(httpResponse.statusCode)"])
        }

        // Parse response based on provider type
        switch localProviderType {
        case .ollama:
            return try parseOllamaModels(data)
        case .lmStudio, .openAICompatible:
            return try parseOpenAICompatibleModels(data)
        }
    }

    private func parseOllamaModels(_ data: Data) throws -> [String] {
        struct OllamaModelsResponse: Codable {
            struct Model: Codable {
                let name: String
            }
            let models: [Model]
        }

        let response = try JSONDecoder().decode(OllamaModelsResponse.self, from: data)
        return response.models.map { $0.name }
    }

    private func parseOpenAICompatibleModels(_ data: Data) throws -> [String] {
        struct OpenAIModelsResponse: Codable {
            struct Model: Codable {
                let id: String
            }
            let data: [Model]
        }

        let response = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
        return response.data.map { $0.id }
    }

    /// Get available models for a category, preferring refreshed/cached models if available
    private func availableModels(for category: ProviderUsageCategory) -> [String] {
        // For local providers, use cached models from connection test
        if config.provider.isLocalProvider && !cachedModels.isEmpty {
            switch category {
            case .transcription:
                let whisperModels = cachedModels.filter { $0.lowercased().contains("whisper") }
                return whisperModels.isEmpty ? cachedModels : whisperModels
            case .translation, .powerMode:
                let llmModels = cachedModels.filter { !$0.lowercased().contains("whisper") }
                return llmModels.isEmpty ? cachedModels : llmModels
            }
        }

        // For cloud providers, use refreshed models if available
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
        case .local:
            return try await fetchLocalProviderModels()
        case .elevenLabs:
            // ElevenLabs doesn't expose models via API
            return (config.provider.availableSTTModels, [])
        case .deepgram:
            // Deepgram models are documented, not via API
            return (config.provider.availableSTTModels, [])
        case .assemblyAI:
            // AssemblyAI models are documented, not via API
            return (config.provider.availableSTTModels, [])
        case .deepL:
            // DeepL doesn't have model selection
            return ([], config.provider.availableLLMModels)
        case .azure:
            // Azure Translator doesn't have model selection
            return ([], config.provider.availableLLMModels)
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

        // Filter STT models (whisper and gpt-4o-transcribe variants)
        var sttModels = allModels.filter {
            $0.contains("whisper") || $0.contains("transcribe")
        }.sorted()

        // If API doesn't return transcribe models yet (new models), add them from defaults
        let expectedStreamingModels = ["gpt-4o-transcribe", "gpt-4o-mini-transcribe"]
        for model in expectedStreamingModels {
            if !sttModels.contains(model) {
                sttModels.insert(model, at: 0)  // Add streaming models at the top
            }
        }

        // Filter LLM models (gpt, o1, but not transcribe models)
        let llmModels = allModels.filter {
            ($0.hasPrefix("gpt-") || $0.hasPrefix("o1") || $0.hasPrefix("o3") || $0.hasPrefix("chatgpt-")) &&
            !$0.contains("transcribe")
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

    private func fetchLocalProviderModels() async throws -> (sttModels: [String], llmModels: [String]) {
        // Use the local provider config
        let baseURL = localServerURL.isEmpty ? localProviderType.defaultEndpoint : localServerURL
        let modelsEndpoint = localProviderType.modelsEndpoint

        guard let url = URL(string: "\(baseURL)\(modelsEndpoint)") else {
            throw NSError(domain: "LocalProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = TimeInterval(timeoutSeconds)

        // Add auth header if configured
        if useAuthToken && !localAuthToken.isEmpty {
            request.setValue("Bearer \(localAuthToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "LocalProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch models"])
        }

        var allModels: [String] = []

        switch localProviderType {
        case .ollama:
            allModels = try parseOllamaModels(data)
        case .lmStudio, .openAICompatible:
            allModels = try parseOpenAICompatibleModels(data)
        }

        // Filter models for STT (whisper) and LLM
        let sttModels = allModels.filter { $0.lowercased().contains("whisper") }
        let llmModels = allModels.filter { !$0.lowercased().contains("whisper") }

        return (sttModels, llmModels)
    }
}

#Preview("AI Provider Editor - OpenAI") {
    AIProviderEditorSheet(
        config: AIProviderConfig(provider: .openAI),
        isEditing: false,
        onSave: { _ in }
    )
}

#Preview("AI Provider Editor - Local") {
    AIProviderEditorSheet(
        config: AIProviderConfig(provider: .local),
        isEditing: false,
        onSave: { _ in }
    )
}
