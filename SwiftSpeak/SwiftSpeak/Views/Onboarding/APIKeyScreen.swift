//
//  APIKeyScreen.swift
//  SwiftSpeak
//
//  Screen for API key setup with provider selection (OpenAI or Gemini)
//

import SwiftUI

// MARK: - Provider Option for Free Tier
enum FreeProviderOption: String, CaseIterable {
    case openAI = "OpenAI"
    case gemini = "Gemini"

    var icon: String {
        // Use same icon for both - generic AI brain icon
        return "brain"
    }

    var color: Color {
        switch self {
        case .openAI: return .green
        case .gemini: return .blue
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .openAI:
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .gemini:
            return LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .openAI: return "sk-proj-..."
        case .gemini: return "AIza..."
        }
    }

    var platformURL: String {
        switch self {
        case .openAI: return "https://platform.openai.com/api-keys"
        case .gemini: return "https://aistudio.google.com/apikey"
        }
    }

    var platformName: String {
        switch self {
        case .openAI: return "OpenAI Platform"
        case .gemini: return "Google AI Studio"
        }
    }

    var instructions: [(step: String, text: String)] {
        switch self {
        case .openAI:
            return [
                ("1", "Go to platform.openai.com/api-keys"),
                ("2", "Sign in or create account"),
                ("3", "Click \"Create new secret key\""),
                ("4", "Copy the key (starts with sk-proj-...)")
            ]
        case .gemini:
            return [
                ("1", "Go to aistudio.google.com/apikey"),
                ("2", "Sign in with Google account"),
                ("3", "Click \"Create API Key\""),
                ("4", "Copy the key (starts with AIza...)")
            ]
        }
    }

    var pricingNote: String {
        switch self {
        case .openAI: return "~$0.006/min transcription • Typical: ~$0.30/month"
        case .gemini: return "Free tier available • Pay-as-you-go after"
        }
    }

    var aiProvider: AIProvider {
        switch self {
        case .openAI: return .openAI
        case .gemini: return .google
        }
    }
}

struct APIKeyScreen: View {
    let onContinue: () -> Void
    @Environment(\.colorScheme) var colorScheme

    @StateObject private var settings = SharedSettings.shared
    @State private var selectedProvider: FreeProviderOption = .openAI
    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var isValid = false
    @State private var showError = false
    @State private var contentVisible = false
    @FocusState private var isTextFieldFocused: Bool

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer()
                    .frame(height: 16)

                // Animated icon based on provider
                ProviderIcon(selectedProvider.aiProvider, size: .extraLarge, style: .filled)
                    .animation(AppTheme.smoothSpring, value: selectedProvider)

                // Title
                Text("Almost There!")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)

                // Subtitle
                Text("Choose your AI provider and enter your API key")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Provider Selector
                ProviderSelector(selectedProvider: $selectedProvider)
                    .padding(.horizontal, 24)
                    .opacity(contentVisible ? 1 : 0)
                    .onChange(of: selectedProvider) { _, _ in
                        // Reset state when switching providers
                        apiKey = ""
                        isValid = false
                        showError = false
                    }

                // API Key input section
                VStack(spacing: 12) {
                    // Text field
                    HStack {
                        Image(systemName: "key.fill")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        SecureField(selectedProvider.keyPlaceholder, text: $apiKey)
                            .textContentType(.password)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(.body)
                            .focused($isTextFieldFocused)

                        if isValidating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if isValid {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .transition(.scale.combined(with: .opacity))
                        } else if showError {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                isValid ? Color.green :
                                    showError ? Color.red :
                                    isTextFieldFocused ? selectedProvider.color : Color.clear,
                                lineWidth: 2
                            )
                    )

                    // Error message
                    if showError {
                        Text("Invalid API key. Please check and try again.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 24)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 20)

                // Instructions card
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 6) {
                        HStack {
                            Image(systemName: "bolt.fill")
                                .font(.body)
                                .foregroundStyle(.orange)

                            Text("Quick Setup")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.primary)

                            Spacer()

                            // Time badge
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text("< 1 min")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                        }

                        Text("Getting an API key is super easy!")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)

                    Divider()
                        .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 10) {
                        // Dynamic instructions based on provider
                        ForEach(selectedProvider.instructions, id: \.step) { instruction in
                            CompactInstructionStep(number: instruction.step, text: instruction.text)
                        }

                        // Open link button
                        Button(action: openProviderPage) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption)
                                Text("Open \(selectedProvider.platformName)")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(selectedProvider.color)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedProvider.color.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)

                        // Pricing note
                        Text(selectedProvider.pricingNote)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 24)
                .opacity(contentVisible ? 1 : 0)

                Spacer()
                    .frame(height: 16)

                // Action buttons
                VStack(spacing: 12) {
                    if apiKey.isEmpty {
                        // Skip button when no key entered
                        Button(action: {
                            // Save provider preference even when skipping
                            saveProviderPreference()
                            onContinue()
                        }) {
                            HStack(spacing: 8) {
                                Text("Skip for now")
                                    .font(.callout.weight(.medium))
                                Image(systemName: "arrow.right")
                                    .font(.callout)
                            }
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Test & Next buttons when key entered
                        HStack(spacing: 12) {
                            // Test button
                            Button(action: validateKey) {
                                HStack(spacing: 6) {
                                    if isValidating {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else if isValid {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    } else {
                                        Image(systemName: "play.circle")
                                    }
                                    Text(isValid ? "Valid!" : "Test")
                                        .font(.callout.weight(.medium))
                                }
                                .foregroundStyle(isValid ? .green : .primary)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(isValidating)

                            // Next button
                            Button(action: saveAndContinue) {
                                HStack(spacing: 6) {
                                    Text("Next")
                                        .font(.callout.weight(.semibold))
                                    Image(systemName: "arrow.right")
                                        .font(.callout.weight(.semibold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                                .background(selectedProvider.gradient)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }

                        // Skip option below
                        Button("Skip without saving") {
                            // Save provider preference even when skipping
                            saveProviderPreference()
                            onContinue()
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
                    .frame(height: 30)
            }
        }
        .background(backgroundColor.ignoresSafeArea())
        .onAppear {
            withAnimation(AppTheme.smoothSpring.delay(0.2)) {
                contentVisible = true
            }
        }
        .onChange(of: apiKey) { _, _ in
            withAnimation {
                isValid = false
                showError = false
            }
        }
    }

    private func validateKey() {
        isTextFieldFocused = false
        HapticManager.mediumTap()

        withAnimation {
            isValidating = true
            showError = false
        }

        Task {
            do {
                switch selectedProvider {
                case .openAI:
                    let (sttModels, llmModels) = try await fetchOpenAIModels()
                    await MainActor.run {
                        cacheOpenAIModels(sttModels: sttModels, llmModels: llmModels)
                    }
                case .gemini:
                    try await validateGeminiKey()
                }

                await MainActor.run {
                    withAnimation(AppTheme.quickSpring) {
                        isValidating = false
                        isValid = true
                        HapticManager.success()
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(AppTheme.quickSpring) {
                        isValidating = false
                        showError = true
                        HapticManager.error()
                    }
                }
            }
        }
    }

    /// Fetch models from OpenAI API - validates key and returns available models
    private func fetchOpenAIModels() async throws -> (sttModels: [String], llmModels: [String]) {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            throw NSError(domain: "OpenAI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "OpenAI", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid API key"])
        }

        struct ModelsResponse: Codable {
            struct Model: Codable {
                let id: String
            }
            let data: [Model]
        }

        let modelsResponse = try JSONDecoder().decode(ModelsResponse.self, from: data)
        let allModels = modelsResponse.data.map { $0.id }

        let sttModels = allModels.filter { $0.contains("whisper") }.sorted()
        let llmModels = allModels.filter {
            $0.hasPrefix("gpt-") || $0.hasPrefix("o1") || $0.hasPrefix("o3") || $0.hasPrefix("chatgpt-")
        }.sorted().reversed().map { String($0) }

        return (sttModels, Array(llmModels))
    }

    /// Validate Gemini API key
    private func validateGeminiKey() async throws {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)") else {
            throw NSError(domain: "Gemini", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "Gemini", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid API key"])
        }
    }

    /// Cache fetched models in the OpenAI provider config
    private func cacheOpenAIModels(sttModels: [String], llmModels: [String]) {
        let allModels = sttModels + llmModels

        if var config = settings.getAIProviderConfig(for: .openAI) {
            config.cachedModels = allModels
            if config.transcriptionModel == nil, let bestSTT = sttModels.first {
                config.transcriptionModel = bestSTT
            }
            if config.translationModel == nil, let bestLLM = llmModels.first {
                config.translationModel = bestLLM
            }
            if config.powerModeModel == nil, let bestLLM = llmModels.first {
                config.powerModeModel = bestLLM
            }
            settings.updateAIProvider(config)
        }
    }

    private func saveAndContinue() {
        HapticManager.mediumTap()

        // Create provider config and save
        var config = AIProviderConfig(provider: selectedProvider.aiProvider)
        config.apiKey = apiKey

        // Set default models based on provider
        switch selectedProvider {
        case .openAI:
            config.transcriptionModel = "whisper-1"
            config.translationModel = "gpt-4o-mini"
            config.powerModeModel = "gpt-4o-mini"
        case .gemini:
            config.transcriptionModel = "long"  // Google Cloud STT model
            config.translationModel = "gemini-2.0-flash-exp"
            config.powerModeModel = "gemini-2.0-flash-exp"
        }

        settings.addAIProvider(config)

        // Set as default provider for all tasks
        settings.selectedTranscriptionProvider = selectedProvider.aiProvider
        settings.selectedTranslationProvider = selectedProvider.aiProvider
        settings.selectedPowerModeProvider = selectedProvider.aiProvider

        onContinue()
    }

    private func openProviderPage() {
        HapticManager.lightTap()
        if let url = URL(string: selectedProvider.platformURL) {
            UIApplication.shared.open(url)
        }
    }

    /// Save provider preference without API key (for when user skips)
    private func saveProviderPreference() {
        // Set the selected provider as default for all tasks
        // This ensures the main screen shows the correct provider name
        settings.selectedTranscriptionProvider = selectedProvider.aiProvider
        settings.selectedTranslationProvider = selectedProvider.aiProvider
        settings.selectedPowerModeProvider = selectedProvider.aiProvider
    }
}

// MARK: - Provider Selector
struct ProviderSelector: View {
    @Binding var selectedProvider: FreeProviderOption
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            ForEach(FreeProviderOption.allCases, id: \.self) { provider in
                ProviderOptionCard(
                    provider: provider,
                    isSelected: selectedProvider == provider,
                    colorScheme: colorScheme
                ) {
                    withAnimation(AppTheme.smoothSpring) {
                        selectedProvider = provider
                        HapticManager.lightTap()
                    }
                }
            }
        }
    }
}

// MARK: - Provider Option Card
struct ProviderOptionCard: View {
    let provider: FreeProviderOption
    let isSelected: Bool
    let colorScheme: ColorScheme
    let onTap: () -> Void

    private var cardBackground: some View {
        Group {
            if isSelected {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(provider.gradient.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(provider.gradient, lineWidth: 2)
                    )
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
        }
    }

    private var iconGradient: LinearGradient {
        isSelected ? provider.gradient : LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                // Icon
                ProviderIcon(provider.aiProvider, size: .large, style: .filled, isDisabled: !isSelected)

                // Name
                Text(provider.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(provider.color)
                } else {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Instruction Step
struct CompactInstructionStep: View {
    let number: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Text(number)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(AppTheme.accent)
                .clipShape(Circle())

            Text(text)
                .font(.footnote)
                .foregroundStyle(.primary)
        }
    }
}

#Preview("Dark") {
    APIKeyScreen(onContinue: {})
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    APIKeyScreen(onContinue: {})
        .preferredColorScheme(.light)
}
