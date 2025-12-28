//
//  APIKeyScreen.swift
//  SwiftSpeak
//
//  Screen 5: API key setup with validation
//

import SwiftUI

struct APIKeyScreen: View {
    let onContinue: () -> Void
    @Environment(\.colorScheme) var colorScheme

    @StateObject private var settings = SharedSettings.shared
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
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 24)

                // Animated waveform - same position as other onboarding screens
                CircularWaveformView(isActive: true)
                    .frame(width: 60, height: 60)
                    .frame(height: 60)

                // Title
                Text("Almost There!")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)

                // Subtitle
                Text("Enter your OpenAI API key to enable transcription")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // API Key input section
                VStack(spacing: 16) {
                    // Text field
                    HStack {
                        Image(systemName: "key.fill")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        SecureField("sk-proj-...", text: $apiKey)
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
                                    isTextFieldFocused ? AppTheme.accent : Color.clear,
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

                        Text("Getting an API key is super easy and takes less than a minute!")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)

                    Divider()
                        .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 10) {
                        // Step 1
                        CompactInstructionStep(number: "1", text: "Go to platform.openai.com/api-keys")

                        // Step 2
                        CompactInstructionStep(number: "2", text: "Sign in or create account")

                        // Step 3
                        CompactInstructionStep(number: "3", text: "Click \"Create new secret key\"")

                        // Step 4
                        CompactInstructionStep(number: "4", text: "Copy the key (starts with sk-proj-...)")

                        // Open link button - smaller, secondary style
                        Button(action: openOpenAIPage) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption)
                                Text("Open OpenAI Platform")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.accent.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)

                        // Pricing note
                        Text("~$0.006/min • Typical user: ~$0.30/month")
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
                    .frame(height: 20)

                // Action buttons
                VStack(spacing: 12) {
                    if apiKey.isEmpty {
                        // Skip button when no key entered
                        Button(action: { onContinue() }) {
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
                                .background(AppTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }

                        // Skip option below
                        Button("Skip without saving") {
                            onContinue()
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
                    .frame(height: 50)
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

        // Validate API key and fetch available models
        Task {
            do {
                // Fetch models from OpenAI - this validates the key AND gets models
                let (sttModels, llmModels) = try await fetchOpenAIModels()

                await MainActor.run {
                    withAnimation(AppTheme.quickSpring) {
                        isValidating = false
                        isValid = true
                        HapticManager.success()

                        // Cache the models in the provider config
                        cacheModels(sttModels: sttModels, llmModels: llmModels)
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

        // Filter STT models (whisper)
        let sttModels = allModels.filter { $0.contains("whisper") }.sorted()

        // Filter LLM models (gpt, o1, o3, chatgpt)
        let llmModels = allModels.filter {
            $0.hasPrefix("gpt-") || $0.hasPrefix("o1") || $0.hasPrefix("o3") || $0.hasPrefix("chatgpt-")
        }.sorted().reversed().map { String($0) }

        return (sttModels, Array(llmModels))
    }

    /// Cache fetched models in the OpenAI provider config
    private func cacheModels(sttModels: [String], llmModels: [String]) {
        // Combine all models for caching
        let allModels = sttModels + llmModels

        // Update or create OpenAI provider config with cached models
        if var config = settings.getAIProviderConfig(for: .openAI) {
            config.cachedModels = allModels
            // Auto-select best models if not already set
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
        settings.openAIAPIKey = apiKey
        onContinue()
    }

    private func openOpenAIPage() {
        HapticManager.lightTap()
        if let url = URL(string: "https://platform.openai.com/api-keys") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Compact Instruction Step
struct CompactInstructionStep: View {
    let number: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            // Small number badge
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
