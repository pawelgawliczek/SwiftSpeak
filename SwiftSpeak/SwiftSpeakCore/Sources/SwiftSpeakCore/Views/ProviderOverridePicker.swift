//
//  ProviderOverridePicker.swift
//  SwiftSpeak
//
//  Shared SwiftUI component for selecting provider overrides in contexts
//  Used by both iOS and macOS
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakMac targets
//

import SwiftUI

// MARK: - Provider Overrides Section

/// Complete section for configuring provider overrides in a context
/// Has a master toggle and individual provider dropdowns
public struct ProviderOverridesSection: View {
    @Binding public var transcriptionOverride: ProviderSelection?
    @Binding public var translationOverride: ProviderSelection?
    @Binding public var aiOverride: ProviderSelection?

    public let transcriptionProviders: [AIProvider]
    public let translationProviders: [AIProvider]
    public let aiProviders: [AIProvider]

    public let globalTranscription: AIProvider
    public let globalTranslation: AIProvider
    public let globalAI: AIProvider

    public let isStreamingEnabled: Bool

    /// Whether custom overrides are enabled
    @State private var useCustomProviders: Bool = false

    public init(
        transcriptionOverride: Binding<ProviderSelection?>,
        translationOverride: Binding<ProviderSelection?>,
        aiOverride: Binding<ProviderSelection?>,
        transcriptionProviders: [AIProvider],
        translationProviders: [AIProvider],
        aiProviders: [AIProvider],
        globalTranscription: AIProvider,
        globalTranslation: AIProvider,
        globalAI: AIProvider,
        isStreamingEnabled: Bool
    ) {
        self._transcriptionOverride = transcriptionOverride
        self._translationOverride = translationOverride
        self._aiOverride = aiOverride
        self.transcriptionProviders = transcriptionProviders
        self.translationProviders = translationProviders
        self.aiProviders = aiProviders
        self.globalTranscription = globalTranscription
        self.globalTranslation = globalTranslation
        self.globalAI = globalAI
        self.isStreamingEnabled = isStreamingEnabled

        // Initialize state based on whether any override is set
        _useCustomProviders = State(initialValue:
            transcriptionOverride.wrappedValue != nil ||
            translationOverride.wrappedValue != nil ||
            aiOverride.wrappedValue != nil
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Master toggle
            Toggle(isOn: $useCustomProviders) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use Custom Providers")
                        .font(.body)
                    Text("Override global defaults for this context")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .onChange(of: useCustomProviders) { enabled in
                if !enabled {
                    // Clear all overrides when disabled
                    transcriptionOverride = nil
                    translationOverride = nil
                    aiOverride = nil
                }
            }

            // Provider dropdowns (only shown when custom is enabled)
            if useCustomProviders {
                VStack(spacing: 12) {
                    // Transcription
                    ProviderDropdown(
                        label: "Transcription",
                        icon: "waveform",
                        color: .blue,
                        selection: $transcriptionOverride,
                        providers: transcriptionProviders,
                        globalDefault: globalTranscription
                    )

                    // Streaming warning
                    if isStreamingEnabled {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.orange)
                            Text("Streaming mode uses global provider")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 4)
                    }

                    // Translation
                    ProviderDropdown(
                        label: "Translation",
                        icon: "globe",
                        color: .purple,
                        selection: $translationOverride,
                        providers: translationProviders,
                        globalDefault: globalTranslation
                    )

                    // AI / Power Mode
                    ProviderDropdown(
                        label: "AI / Power Mode",
                        icon: "bolt.fill",
                        color: .orange,
                        selection: $aiOverride,
                        providers: aiProviders,
                        globalDefault: globalAI
                    )
                }
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Provider Dropdown

/// Individual dropdown for selecting a provider or using global default
private struct ProviderDropdown: View {
    let label: String
    let icon: String
    let color: Color
    @Binding var selection: ProviderSelection?
    let providers: [AIProvider]
    let globalDefault: AIProvider

    /// Special value to represent "use global default"
    private enum DropdownValue: Hashable {
        case globalDefault
        case provider(AIProvider)
    }

    private var currentValue: DropdownValue {
        if let sel = selection, case .cloud(let provider) = sel.providerType {
            return .provider(provider)
        }
        return .globalDefault
    }

    var body: some View {
        HStack {
            // Label
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 20)
                Text(label)
                    .font(.subheadline)
            }

            Spacer()

            // Picker
            Picker("", selection: Binding(
                get: { currentValue },
                set: { newValue in
                    switch newValue {
                    case .globalDefault:
                        selection = nil
                    case .provider(let provider):
                        selection = ProviderSelection(providerType: .cloud(provider))
                    }
                }
            )) {
                // Global default option
                HStack {
                    Text("Global Default")
                    Text("(\(globalDefault.shortName))")
                        .foregroundStyle(.secondary)
                }
                .tag(DropdownValue.globalDefault)

                Divider()

                // Available providers
                ForEach(providers, id: \.self) { provider in
                    Text(provider.shortName)
                        .tag(DropdownValue.provider(provider))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ProviderOverridesSection_Previews: PreviewProvider {
    static var previews: some View {
        Form {
            Section("Provider Overrides") {
                ProviderOverridesSection(
                    transcriptionOverride: .constant(nil),
                    translationOverride: .constant(nil),
                    aiOverride: .constant(nil),
                    transcriptionProviders: [.openAI, .deepgram, .assemblyAI],
                    translationProviders: [.openAI, .deepL, .azure],
                    aiProviders: [.openAI, .anthropic, .google],
                    globalTranscription: .assemblyAI,
                    globalTranslation: .openAI,
                    globalAI: .openAI,
                    isStreamingEnabled: false
                )
            }
        }
    }
}
#endif
