//
//  MacProviderIcon.swift
//  SwiftSpeakMac
//
//  A consistent circular icon component for AI providers on macOS
//

import SwiftUI
import SwiftSpeakCore
import AppKit

// MARK: - macOS Provider Icon

struct MacProviderIcon: View {
    let provider: AIProvider
    let size: IconSize
    let style: IconStyle
    let isDisabled: Bool
    private let hasCustomIcon: Bool

    enum IconSize {
        case small      // 20pt
        case medium     // 28pt
        case large      // 40pt
        case extraLarge // 56pt

        var dimension: CGFloat {
            switch self {
            case .small: return 20
            case .medium: return 28
            case .large: return 40
            case .extraLarge: return 56
            }
        }

        var iconScale: CGFloat {
            switch self {
            case .small: return 0.5
            case .medium: return 0.55
            case .large: return 0.55
            case .extraLarge: return 0.55
            }
        }
    }

    enum IconStyle {
        case filled
        case outline
        case plain
    }

    init(_ provider: AIProvider, size: IconSize = .medium, style: IconStyle = .filled, isDisabled: Bool = false) {
        self.provider = provider
        self.size = size
        self.style = style
        self.isDisabled = isDisabled
        if let assetName = provider.macIconAssetName {
            self.hasCustomIcon = NSImage(named: assetName) != nil
        } else {
            self.hasCustomIcon = false
        }
    }

    private var effectiveColor: Color {
        isDisabled ? .secondary : provider.macBrandColor
    }

    var body: some View {
        ZStack {
            if style == .filled {
                Circle()
                    .fill(effectiveColor.gradient)
            } else if style == .outline {
                Circle()
                    .stroke(effectiveColor, lineWidth: 1.5)
            }

            iconImage
                .frame(width: size.dimension * size.iconScale, height: size.dimension * size.iconScale)
                .foregroundStyle(iconColor)
        }
        .frame(width: size.dimension, height: size.dimension)
    }

    @ViewBuilder
    private var iconImage: some View {
        if hasCustomIcon, let assetName = provider.macIconAssetName {
            Image(assetName)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: provider.macIconSystemName)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }

    private var iconColor: Color {
        switch style {
        case .filled:
            return .white
        case .outline, .plain:
            return effectiveColor
        }
    }
}

// MARK: - AIProvider macOS Extensions

extension AIProvider {
    var macIconAssetName: String? {
        switch self {
        case .openAI: return "openai"
        case .anthropic: return "anthropic"
        case .google: return "gemini"
        case .deepgram: return "deepgram"
        case .deepL: return "deepl"
        case .azure: return "azure"
        case .elevenLabs: return "elevenlabs"
        case .assemblyAI: return nil
        case .local: return nil
        case .appleSpeech: return nil  // Uses SF Symbol
        }
    }

    var macIconSystemName: String {
        switch self {
        case .openAI: return "brain"
        case .anthropic: return "sparkles"
        case .google: return "brain"
        case .elevenLabs: return "waveform"
        case .deepgram: return "mic.fill"
        case .local: return "desktopcomputer"
        case .assemblyAI: return "waveform.circle.fill"
        case .deepL: return "character.book.closed.fill"
        case .azure: return "cloud.fill"
        case .appleSpeech: return "apple.logo"
        }
    }

    var macBrandColor: Color {
        switch self {
        case .openAI: return Color(red: 0.07, green: 0.64, blue: 0.52)
        case .anthropic: return Color(red: 0.82, green: 0.55, blue: 0.35)
        case .google: return Color(red: 0.26, green: 0.52, blue: 0.96)
        case .elevenLabs: return Color.black
        case .deepgram: return Color(red: 0.15, green: 0.85, blue: 0.75)
        case .local: return Color.purple
        case .assemblyAI: return Color(red: 0.0, green: 0.47, blue: 1.0)
        case .deepL: return Color(red: 0.04, green: 0.21, blue: 0.38)
        case .azure: return Color(red: 0.0, green: 0.47, blue: 0.84)
        case .appleSpeech: return Color.gray  // Apple's neutral color
        }
    }

    // capabilities is defined in SwiftSpeakCore/Models/AIProvider.swift

    var pricingInfo: String {
        switch self {
        case .openAI: return "$0.006/min transcription"
        case .anthropic: return "~$3/MTok Claude"
        case .google: return "Free tier available"
        case .deepgram: return "$0.0043/min"
        case .deepL: return "Free tier: 500K chars/mo"
        case .azure: return "Pay as you go"
        case .elevenLabs: return "Varies by plan"
        case .assemblyAI: return "$0.005/min"
        case .local: return "Free (local)"
        case .appleSpeech: return "Free (on-device)"
        }
    }
}

// MARK: - Preview

#Preview("Provider Icons") {
    VStack(spacing: 20) {
        Text("Provider Icons")
            .font(.headline)

        HStack(spacing: 16) {
            ForEach(AIProvider.allCases) { provider in
                VStack {
                    MacProviderIcon(provider, size: .large, style: .filled)
                    Text(provider.shortName)
                        .font(.caption2)
                }
            }
        }

        Text("Sizes")
            .font(.headline)

        HStack(spacing: 16) {
            MacProviderIcon(.openAI, size: .small)
            MacProviderIcon(.openAI, size: .medium)
            MacProviderIcon(.openAI, size: .large)
            MacProviderIcon(.openAI, size: .extraLarge)
        }

        Text("Styles")
            .font(.headline)

        HStack(spacing: 16) {
            MacProviderIcon(.anthropic, size: .large, style: .filled)
            MacProviderIcon(.anthropic, size: .large, style: .outline)
            MacProviderIcon(.anthropic, size: .large, style: .plain)
        }
    }
    .padding()
}
