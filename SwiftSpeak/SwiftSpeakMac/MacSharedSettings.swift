//
//  MacSharedSettings.swift
//  SwiftSpeakMac
//
//  macOS settings management (simplified from iOS)
//

import Foundation
import Combine

@MainActor
class MacSettings: ObservableObject {
    static let shared = MacSettings()

    private let defaults: UserDefaults?

    // MARK: - Published Properties

    @Published var hasCompletedOnboarding: Bool = false {
        didSet {
            defaults?.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }

    @Published var selectedTranscriptionProvider: AIProvider = .openAI {
        didSet {
            defaults?.set(selectedTranscriptionProvider.rawValue, forKey: "selectedTranscriptionProvider")
        }
    }

    @Published var selectedFormattingProvider: AIProvider = .openAI {
        didSet {
            defaults?.set(selectedFormattingProvider.rawValue, forKey: "selectedFormattingProvider")
        }
    }

    @Published var defaultMode: FormattingMode = .raw {
        didSet {
            defaults?.set(defaultMode.rawValue, forKey: "defaultMode")
        }
    }

    @Published var transcriptionHistory: [TranscriptionRecord] = []

    // MARK: - API Keys (stored in Keychain in production)

    @Published var openAIApiKey: String = "" {
        didSet {
            defaults?.set(openAIApiKey, forKey: "openAIApiKey")
        }
    }

    @Published var anthropicApiKey: String = "" {
        didSet {
            defaults?.set(anthropicApiKey, forKey: "anthropicApiKey")
        }
    }

    // MARK: - Initialization

    init() {
        self.defaults = UserDefaults.standard
        loadSettings()
    }

    private func loadSettings() {
        hasCompletedOnboarding = defaults?.bool(forKey: "hasCompletedOnboarding") ?? false

        if let providerRaw = defaults?.string(forKey: "selectedTranscriptionProvider"),
           let provider = AIProvider(rawValue: providerRaw) {
            selectedTranscriptionProvider = provider
        }

        if let providerRaw = defaults?.string(forKey: "selectedFormattingProvider"),
           let provider = AIProvider(rawValue: providerRaw) {
            selectedFormattingProvider = provider
        }

        if let modeRaw = defaults?.string(forKey: "defaultMode"),
           let mode = FormattingMode(rawValue: modeRaw) {
            defaultMode = mode
        }

        openAIApiKey = defaults?.string(forKey: "openAIApiKey") ?? ""
        anthropicApiKey = defaults?.string(forKey: "anthropicApiKey") ?? ""

        loadHistory()
    }

    // MARK: - History

    func addToHistory(_ record: TranscriptionRecord) {
        transcriptionHistory.insert(record, at: 0)
        // Keep last 100 records
        if transcriptionHistory.count > 100 {
            transcriptionHistory = Array(transcriptionHistory.prefix(100))
        }
        saveHistory()
    }

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(transcriptionHistory) {
            defaults?.set(encoded, forKey: "transcriptionHistory")
        }
    }

    private func loadHistory() {
        if let data = defaults?.data(forKey: "transcriptionHistory"),
           let decoded = try? JSONDecoder().decode([TranscriptionRecord].self, from: data) {
            transcriptionHistory = decoded
        }
    }

    // MARK: - Provider Configuration

    func apiKey(for provider: AIProvider) -> String? {
        switch provider {
        case .openAI:
            return openAIApiKey.isEmpty ? nil : openAIApiKey
        case .anthropic:
            return anthropicApiKey.isEmpty ? nil : anthropicApiKey
        default:
            return nil
        }
    }
}
