//
//  ProviderIcon.swift
//  SwiftSpeak
//
//  A consistent circular icon component for AI providers and apps
//

import SwiftUI
import SwiftSpeakCore
import UIKit

// MARK: - Provider Icon View

/// Displays an AI provider or app icon in a consistent circular style
/// Uses custom image assets when available, falls back to SF Symbols
struct ProviderIcon: View {
    let provider: AIProvider
    let size: IconSize
    let style: IconStyle
    let isDisabled: Bool
    private let hasCustomIcon: Bool

    enum IconSize {
        case small      // 20pt - for inline text/rows
        case medium     // 28pt - for list rows
        case large      // 40pt - for headers/cards
        case extraLarge // 56pt - for detail views

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

        var padding: CGFloat {
            switch self {
            case .small: return 4
            case .medium: return 6
            case .large: return 8
            case .extraLarge: return 12
            }
        }
    }

    enum IconStyle {
        case filled       // Solid background with white icon
        case outline      // Transparent background with colored border and icon
        case plain        // Just the icon, no background
    }

    init(_ provider: AIProvider, size: IconSize = .medium, style: IconStyle = .filled, isDisabled: Bool = false) {
        self.provider = provider
        self.size = size
        self.style = style
        self.isDisabled = isDisabled
        // Pre-check if custom icon exists to avoid conditional Image init issues
        if let assetName = provider.iconAssetName {
            self.hasCustomIcon = UIImage(named: assetName) != nil
        } else {
            self.hasCustomIcon = false
        }
    }

    private var effectiveColor: Color {
        isDisabled ? .secondary : provider.brandColor
    }

    var body: some View {
        ZStack {
            // Background
            if style == .filled {
                Circle()
                    .fill(effectiveColor.gradient)
            } else if style == .outline {
                Circle()
                    .stroke(effectiveColor, lineWidth: 1.5)
            }

            // Icon
            iconImage
                .frame(width: size.dimension * size.iconScale, height: size.dimension * size.iconScale)
                .foregroundStyle(iconColor)
        }
        .frame(width: size.dimension, height: size.dimension)
    }

    @ViewBuilder
    private var iconImage: some View {
        if hasCustomIcon, let assetName = provider.iconAssetName {
            Image(assetName)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: provider.iconSystemName)
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

// MARK: - Local Provider Icon View

/// Displays a local/on-device provider icon
struct LocalProviderIcon: View {
    let type: LocalModelType
    let size: ProviderIcon.IconSize
    let style: ProviderIcon.IconStyle

    init(_ type: LocalModelType, size: ProviderIcon.IconSize = .medium, style: ProviderIcon.IconStyle = .filled) {
        self.type = type
        self.size = size
        self.style = style
    }

    var body: some View {
        ZStack {
            // Background
            if style == .filled {
                Circle()
                    .fill(type.brandColor.gradient)
            } else if style == .outline {
                Circle()
                    .stroke(type.brandColor, lineWidth: 1.5)
            }

            // Icon - local providers use SF Symbols
            Image(systemName: type.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size.dimension * size.iconScale, height: size.dimension * size.iconScale)
                .foregroundStyle(iconColor)
        }
        .frame(width: size.dimension, height: size.dimension)
    }

    private var iconColor: Color {
        switch style {
        case .filled:
            return .white
        case .outline, .plain:
            return type.brandColor
        }
    }
}

// MARK: - Provider Selection Icon View

/// Displays either a cloud or local provider icon based on ProviderSelection
struct ProviderSelectionIcon: View {
    let selection: ProviderSelection?
    let size: ProviderIcon.IconSize
    let style: ProviderIcon.IconStyle
    let fallbackColor: Color

    init(_ selection: ProviderSelection?, size: ProviderIcon.IconSize = .medium, style: ProviderIcon.IconStyle = .filled, fallbackColor: Color = .blue) {
        self.selection = selection
        self.size = size
        self.style = style
        self.fallbackColor = fallbackColor
    }

    var body: some View {
        if let selection = selection {
            switch selection.providerType {
            case .cloud(let provider):
                ProviderIcon(provider, size: size, style: style)
            case .local(let type):
                LocalProviderIcon(type, size: size, style: style)
            }
        } else {
            // Fallback for "Auto" mode
            ZStack {
                if style == .filled {
                    Circle()
                        .fill(fallbackColor.gradient)
                } else if style == .outline {
                    Circle()
                        .stroke(fallbackColor, lineWidth: 1.5)
                }

                Image(systemName: "sparkles")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.dimension * size.iconScale, height: size.dimension * size.iconScale)
                    .foregroundStyle(style == .filled ? .white : fallbackColor)
            }
            .frame(width: size.dimension, height: size.dimension)
        }
    }
}

// MARK: - App Icon View

/// Displays an app icon from the AppLibrary
/// Shows original brand colors with a subtle background, and a category indicator
struct AppIcon: View {
    let app: AppInfo
    let size: ProviderIcon.IconSize
    let style: ProviderIcon.IconStyle
    let showCategoryBadge: Bool
    private let hasCustomIcon: Bool

    @Environment(\.colorScheme) private var colorScheme

    init(_ app: AppInfo, size: ProviderIcon.IconSize = .medium, style: ProviderIcon.IconStyle = .filled, showCategoryBadge: Bool = false) {
        self.app = app
        self.size = size
        self.style = style
        self.showCategoryBadge = showCategoryBadge
        // Pre-check if custom icon exists to avoid conditional Image init issues
        if let assetName = app.iconAssetName {
            self.hasCustomIcon = UIImage(named: assetName) != nil
        } else {
            self.hasCustomIcon = false
        }
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
    }

    var body: some View {
        ZStack {
            // Subtle neutral background
            if style == .filled {
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            } else if style == .outline {
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            }

            // Icon in original colors
            iconImage
                .frame(width: size.dimension * size.iconScale, height: size.dimension * size.iconScale)
        }
        .frame(width: size.dimension, height: size.dimension)
        .overlay(alignment: .bottomTrailing) {
            // Optional category badge
            if showCategoryBadge && size.dimension >= 40 {
                categoryBadge
            }
        }
    }

    @ViewBuilder
    private var iconImage: some View {
        if hasCustomIcon, let assetName = app.iconAssetName {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            // Fallback: SF Symbol with category color
            Image(systemName: app.defaultCategory.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(app.defaultCategory.color)
        }
    }

    @ViewBuilder
    private var categoryBadge: some View {
        Circle()
            .fill(app.defaultCategory.color)
            .frame(width: size.dimension * 0.3, height: size.dimension * 0.3)
            .overlay {
                Image(systemName: app.defaultCategory.icon)
                    .font(.system(size: size.dimension * 0.15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .offset(x: 2, y: 2)
    }
}

extension ProviderIcon.IconSize {
    var cornerRadius: CGFloat {
        switch self {
        case .small: return 4
        case .medium: return 6
        case .large: return 10
        case .extraLarge: return 14
        }
    }
}

// MARK: - AIProvider Extensions

extension AIProvider {
    /// Image asset name if a custom icon is available
    var iconAssetName: String? {
        switch self {
        case .openAI: return "openai"
        case .anthropic: return "anthropic"
        case .google: return "gemini"  // Use Gemini icon for Google
        case .deepgram: return "deepgram"
        case .deepL: return "deepl"
        case .azure: return "azure"
        case .elevenLabs: return "elevenlabs"
        case .assemblyAI: return nil  // No custom icon, use SF Symbol
        case .local: return nil  // Use SF Symbol
        case .appleSpeech: return nil  // Uses SF Symbol
        }
    }

    /// SF Symbol name for fallback
    var iconSystemName: String {
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

    /// Brand color for the provider
    var brandColor: Color {
        switch self {
        case .openAI: return Color(red: 0.07, green: 0.64, blue: 0.52)  // OpenAI teal
        case .anthropic: return Color(red: 0.82, green: 0.55, blue: 0.35)  // Anthropic orange/tan
        case .google: return Color(red: 0.26, green: 0.52, blue: 0.96)  // Google blue
        case .elevenLabs: return Color(red: 0.0, green: 0.0, blue: 0.0)  // ElevenLabs black
        case .deepgram: return Color(red: 0.15, green: 0.85, blue: 0.75)  // Deepgram teal
        case .local: return Color.purple
        case .assemblyAI: return Color(red: 0.0, green: 0.47, blue: 1.0)  // AssemblyAI blue
        case .deepL: return Color(red: 0.04, green: 0.21, blue: 0.38)  // DeepL dark blue
        case .azure: return Color(red: 0.0, green: 0.47, blue: 0.84)  // Azure blue
        case .appleSpeech: return Color.gray  // Apple's neutral color
        }
    }
}

// MARK: - LocalModelType Extensions

extension LocalModelType {
    /// Brand color for local providers
    var brandColor: Color {
        switch self {
        case .whisperKit: return Color.orange
        case .appleIntelligence: return Color.purple
        case .appleTranslation: return Color.blue
        case .ollama: return Color.gray
        case .lmStudio: return Color.indigo
        }
    }
}

// MARK: - AppInfo Extensions

extension AppInfo {
    /// Image asset name if a custom icon is available
    var iconAssetName: String? {
        // Map bundle ID to asset name
        let iconMap: [String: String] = [
            // Messaging
            "net.whatsapp.WhatsApp": "whatsapp",
            "com.facebook.Messenger": "messenger",
            "ph.telegra.Telegraph": "telegram",
            "org.whispersystems.signal": "signal",
            "com.discord.Discord": "discord",
            "com.skype.skype": "skype",
            "com.wechat.xin": "wechat",
            "jp.naver.line": "line",
            "com.snapchat.snapchat": "snapchat",
            "com.viber": "viber",
            "com.kakao.talk": "kakaotalk",
            "com.google.messages": "googlemessages",

            // Email
            "com.google.Gmail": "gmail",
            "com.microsoft.Office.Outlook": "outlook",
            "com.protonmail.protonmail": "protonmail",

            // Social
            "com.burbn.instagram": "instagram",
            "com.facebook.Facebook": "facebook",
            "com.twitter.twitter": "x",
            "com.atebits.Tweetie2": "x",
            "com.linkedin.LinkedIn": "linkedin",
            "com.zhiliaoapp.musically": "tiktok",
            "com.pinterest": "pinterest",
            "com.reddit.Reddit": "reddit",
            "com.google.ios.youtube": "youtube",
            "tv.twitch": "twitch",
            "com.mastodon.app": "mastodon",
            "org.joinmastodon.app": "mastodon",
            "com.threads.ios": "threads",
            "com.bluesky.app": "bluesky",
            "com.tumblr.tumblr": "tumblr",

            // Work
            "com.tinyspeck.chatlyio": "slack",
            "com.microsoft.teams": "teams",
            "us.zoom.videomeetings": "zoom",
            "com.google.hangouts": "googlemeet",
            "notion.id": "notion",
            "com.getdropbox.Dropbox": "dropbox",
            "com.google.Drive": "googledrive",
            "com.trello.trello": "trello",
            "com.asana.Asana": "asana",
            "com.figma.FigmaPrototype": "figma",
            "com.agilebits.onepassword-ios": "1password",
            "com.atlassian.jira.mobile": "jira",
            "com.miro.Miro": "miro",
            "com.linear.ios": "linear",
            "com.webex.meeting": "webex",
            "com.microsoft.Office.Word": "word",
            "com.microsoft.Office.Excel": "excel",
            "com.microsoft.Office.Powerpoint": "powerpoint",
            "com.microsoft.onenote": "onenote",
            "com.clickup.app": "clickup",
            "com.basecamp.bc3-ios": "basecamp",

            // Browsers
            "com.apple.mobilesafari": "safari",
            "com.google.chrome.ios": "chrome",
            "org.mozilla.ios.Firefox": "firefox",
            "com.opera.OperaTouch": "opera",
            "com.brave.ios.browser": "brave",
            "com.duckduckgo.mobile.ios": "duckduckgo",
            "com.microsoft.msedge": "edge",
            "com.nicegram.nicegram-stable": "arc",

            // Notes
            "com.evernote.iPhone.Evernote": "evernote",
            "md.obsidian": "obsidian",
            "com.google.Keep": "googlekeep",
            "com.todoist.ios": "todoist",
            "com.automattic.simplenote": "simplenote",

            // Finance
            "com.paypal.PPClient": "paypal",
            "com.squareup.cashme": "cashapp",
            "com.venmo.venmo": "venmo",
            "com.revolut.revolut": "revolut",
            "com.coinbase.Coinbase": "coinbase",
            "com.robinhood.release": "robinhood",
            "com.n26": "n26",
            "com.wise.android": "wise",

            // Dating (bumble, hinge, grindr not in SimpleIcons)
            "com.cardify.tinder": "tinder",
            "com.okcupid.OkCupid": "okcupid",

            // Gaming
            "com.roblox.robloxmobile": "roblox",
            "com.steam.steammobile": "steam",
            "com.playstation.PlayStationApp": "playstation",
            "com.microsoft.xboxone.smartglass": "xbox",
            "com.nintendo.znca": "nintendo",
            "com.epicgames.fortnite": "fortnite",
            "com.pubg.krmobile": "pubg",

            // Other (disneyplus not in SimpleIcons)
            "com.spotify.client": "spotify",
            "com.apple.Music": "applemusic",
            "com.netflix.Netflix": "netflix",
            "com.amazon.aiv.AIVApp": "primevideo",
            "com.hbo.hbonow": "hbo",
            "com.apple.tv": "appletv",
            "com.ubercab.UberClient": "uber",
            "com.lyft.ios.Lyft": "lyft",
            "com.doordash.DoorDash": "doordash",
            "com.ubereats.UberEats": "ubereats",
            "com.airbnb.app": "airbnb",
            "com.booking.app": "booking",
            "com.amazon.Amazon": "amazon",
            "com.ebay.ebay": "ebay",
            "com.strava.Strava": "strava",
            "com.nike.omega": "nike",
            "com.expedia.app": "expedia",
            "com.apple.podcasts": "applepodcasts",
        ]

        return iconMap[id]
    }
}

// MARK: - Preview

#Preview("Provider Icons") {
    VStack(spacing: 20) {
        Text("AI Providers")
            .font(.headline)

        HStack(spacing: 16) {
            ForEach(AIProvider.allCases) { provider in
                VStack {
                    ProviderIcon(provider, size: .large, style: .filled)
                    Text(provider.shortName)
                        .font(.caption2)
                }
            }
        }

        Text("Local Providers")
            .font(.headline)

        HStack(spacing: 16) {
            ForEach(LocalModelType.allCases) { type in
                VStack {
                    LocalProviderIcon(type, size: .large, style: .filled)
                    Text(type.displayName)
                        .font(.caption2)
                }
            }
        }

        Text("Icon Sizes")
            .font(.headline)

        HStack(spacing: 16) {
            ProviderIcon(.openAI, size: .small, style: .filled)
            ProviderIcon(.openAI, size: .medium, style: .filled)
            ProviderIcon(.openAI, size: .large, style: .filled)
            ProviderIcon(.openAI, size: .extraLarge, style: .filled)
        }

        Text("Icon Styles")
            .font(.headline)

        HStack(spacing: 16) {
            ProviderIcon(.anthropic, size: .large, style: .filled)
            ProviderIcon(.anthropic, size: .large, style: .outline)
            ProviderIcon(.anthropic, size: .large, style: .plain)
        }
    }
    .padding()
}
