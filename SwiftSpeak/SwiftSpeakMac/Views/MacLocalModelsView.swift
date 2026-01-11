//
//  MacLocalModelsView.swift
//  SwiftSpeakMac
//
//  macOS view for local models settings
//  Uses shared card components from SwiftSpeakCore
//

import SwiftUI
import SwiftSpeakCore

struct MacLocalModelsView: View {
    @ObservedObject var settings: MacSettings
    @State private var showAppleTranslationSetup = false
    @State private var showSelfHostedLLMSetup = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Local Models")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Free")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.green)
                                .clipShape(Capsule())
                        }

                        Text("On-device AI for privacy and offline use")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.bottom, 8)

                // WhisperKit Card
                WhisperKitCard(
                    settings: settings,
                    onDownload: { model in
                        startWhisperKitDownload(model: model)
                    },
                    onDelete: {
                        deleteWhisperKitModel()
                    },
                    onCancelDownload: {
                        cancelWhisperKitDownload()
                    }
                )

                // Apple Intelligence Card
                AppleIntelligenceCard(settings: settings)

                // Apple Translation Card
                AppleTranslationCard(
                    settings: settings,
                    onManageLanguages: {
                        showAppleTranslationSetup = true
                    }
                )

                // Self-Hosted LLM Card
                SelfHostedLLMCard(
                    settings: settings,
                    onConfigure: {
                        showSelfHostedLLMSetup = true
                    }
                )

                // Storage summary
                if settings.localModelStorageBytes > 0 {
                    Divider()
                        .padding(.vertical, 4)

                    HStack {
                        Image(systemName: "externaldrive")
                            .foregroundStyle(.secondary)
                        Text("Storage used: \(settings.localModelStorageFormatted)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showAppleTranslationSetup) {
            // TODO: Create MacAppleTranslationSetupView
            Text("Apple Translation Setup")
                .frame(width: 400, height: 300)
        }
        .sheet(isPresented: $showSelfHostedLLMSetup) {
            // TODO: Create MacSelfHostedLLMSetupView
            Text("Self-Hosted LLM Setup")
                .frame(width: 400, height: 400)
        }
    }

    // MARK: - WhisperKit Actions

    private func startWhisperKitDownload(model: WhisperModel) {
        var config = settings.whisperKitConfig
        config.selectedModel = model
        config.status = .downloading
        config.downloadProgress = 0
        settings.whisperKitConfig = config

        // TODO: Connect to actual WhisperKit download
        // For now, simulate download progress
        Task { @MainActor in
            while settings.whisperKitConfig.downloadProgress < 1.0 && settings.whisperKitConfig.status == .downloading {
                try? await Task.sleep(nanoseconds: 100_000_000)
                var config = settings.whisperKitConfig
                config.downloadProgress += 0.02
                config.downloadedBytes = Int(Double(model.sizeBytes) * config.downloadProgress)
                settings.whisperKitConfig = config
            }

            if settings.whisperKitConfig.status == .downloading {
                var config = settings.whisperKitConfig
                config.status = .ready
                config.downloadProgress = 1.0
                config.downloadedBytes = model.sizeBytes
                config.lastDownloadDate = Date()
                settings.whisperKitConfig = config
            }
        }
    }

    private func cancelWhisperKitDownload() {
        var config = settings.whisperKitConfig
        config.status = .notConfigured
        config.downloadProgress = 0
        config.downloadedBytes = 0
        settings.whisperKitConfig = config
    }

    private func deleteWhisperKitModel() {
        var config = settings.whisperKitConfig
        config.status = .notConfigured
        config.isEnabled = false
        config.downloadProgress = 0
        config.downloadedBytes = 0
        config.lastDownloadDate = nil
        settings.whisperKitConfig = config
    }
}

#Preview {
    MacLocalModelsView(settings: MacSettings.shared)
        .frame(width: 600, height: 800)
}
