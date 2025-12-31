 //
//  AppLibrary.swift
//  SwiftSpeak
//
//  Pre-built database of popular apps for context auto-assignment
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation
import SwiftUI

// MARK: - App Category

/// Categories for organizing apps and assigning contexts
enum AppCategory: String, Codable, CaseIterable, Identifiable {
    case messaging = "messaging"
    case email = "email"
    case social = "social"
    case work = "work"
    case personal = "personal"
    case browser = "browser"
    case notes = "notes"
    case finance = "finance"
    case dating = "dating"
    case gaming = "gaming"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .messaging: return "Messaging"
        case .email: return "Email"
        case .social: return "Social Media"
        case .work: return "Work & Productivity"
        case .personal: return "Personal"
        case .browser: return "Browser"
        case .notes: return "Notes & Writing"
        case .finance: return "Finance"
        case .dating: return "Dating"
        case .gaming: return "Gaming"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .messaging: return "message.fill"
        case .email: return "envelope.fill"
        case .social: return "person.2.fill"
        case .work: return "briefcase.fill"
        case .personal: return "heart.fill"
        case .browser: return "globe"
        case .notes: return "note.text"
        case .finance: return "creditcard.fill"
        case .dating: return "heart.circle.fill"
        case .gaming: return "gamecontroller.fill"
        case .other: return "square.grid.2x2.fill"
        }
    }

    var color: Color {
        switch self {
        case .messaging: return .green
        case .email: return .blue
        case .social: return .purple
        case .work: return .orange
        case .personal: return .pink
        case .browser: return .cyan
        case .notes: return .yellow
        case .finance: return .mint
        case .dating: return .red
        case .gaming: return .indigo
        case .other: return .gray
        }
    }
}

// MARK: - App Info

/// Information about a known app
struct AppInfo: Codable, Identifiable, Equatable, Hashable {
    let id: String                  // Bundle ID (e.g., "net.whatsapp.WhatsApp")
    let name: String                // Display name (e.g., "WhatsApp")
    let defaultCategory: AppCategory

    init(bundleId: String, name: String, category: AppCategory) {
        self.id = bundleId
        self.name = name
        self.defaultCategory = category
    }

    /// Search helper - matches name or bundle id
    func matches(query: String) -> Bool {
        let lowercased = query.lowercased()
        return name.lowercased().contains(lowercased) ||
               id.lowercased().contains(lowercased)
    }
}

// MARK: - App Library

/// Pre-built database of 100+ popular apps organized by category
struct AppLibrary {

    /// All known apps
    static let apps: [AppInfo] = messagingApps + emailApps + socialApps +
                                  workApps + browserApps + notesApps +
                                  financeApps + datingApps + gamingApps + otherApps

    // MARK: - Messaging Apps

    static let messagingApps: [AppInfo] = [
        AppInfo(bundleId: "net.whatsapp.WhatsApp", name: "WhatsApp", category: .messaging),
        AppInfo(bundleId: "net.whatsapp.WhatsAppSMB", name: "WhatsApp Business", category: .messaging),
        AppInfo(bundleId: "com.facebook.Messenger", name: "Messenger", category: .messaging),
        AppInfo(bundleId: "ph.telegra.Telegraph", name: "Telegram", category: .messaging),
        AppInfo(bundleId: "org.whispersystems.signal", name: "Signal", category: .messaging),
        AppInfo(bundleId: "com.viber", name: "Viber", category: .messaging),
        AppInfo(bundleId: "com.skype.skype", name: "Skype", category: .messaging),
        AppInfo(bundleId: "com.discord.Discord", name: "Discord", category: .messaging),
        AppInfo(bundleId: "com.apple.MobileSMS", name: "iMessage", category: .messaging),
        AppInfo(bundleId: "com.wechat.xin", name: "WeChat", category: .messaging),
        AppInfo(bundleId: "jp.naver.line", name: "LINE", category: .messaging),
        AppInfo(bundleId: "com.kakao.talk", name: "KakaoTalk", category: .messaging),
        AppInfo(bundleId: "com.snapchat.snapchat", name: "Snapchat", category: .messaging),
        AppInfo(bundleId: "com.imo.imoim", name: "imo", category: .messaging),
        AppInfo(bundleId: "com.google.messages", name: "Google Messages", category: .messaging),
    ]

    // MARK: - Email Apps

    static let emailApps: [AppInfo] = [
        AppInfo(bundleId: "com.apple.mobilemail", name: "Apple Mail", category: .email),
        AppInfo(bundleId: "com.google.Gmail", name: "Gmail", category: .email),
        AppInfo(bundleId: "com.microsoft.Office.Outlook", name: "Outlook", category: .email),
        AppInfo(bundleId: "com.yahoo.Aerogram", name: "Yahoo Mail", category: .email),
        AppInfo(bundleId: "com.readdle.smartemail", name: "Spark", category: .email),
        AppInfo(bundleId: "com.acompli.Acompli", name: "Outlook (Legacy)", category: .email),
        AppInfo(bundleId: "com.readdle.ReaddleDocs", name: "Readdle", category: .email),
        AppInfo(bundleId: "io.canarymail.ios", name: "Canary Mail", category: .email),
        AppInfo(bundleId: "com.superhuman.mail", name: "Superhuman", category: .email),
        AppInfo(bundleId: "com.protonmail.protonmail", name: "Proton Mail", category: .email),
        AppInfo(bundleId: "com.fastmail.FastMail", name: "Fastmail", category: .email),
        AppInfo(bundleId: "com.newton.email", name: "Newton Mail", category: .email),
    ]

    // MARK: - Social Media Apps

    static let socialApps: [AppInfo] = [
        AppInfo(bundleId: "com.burbn.instagram", name: "Instagram", category: .social),
        AppInfo(bundleId: "com.facebook.Facebook", name: "Facebook", category: .social),
        AppInfo(bundleId: "com.twitter.twitter", name: "X (Twitter)", category: .social),
        AppInfo(bundleId: "com.atebits.Tweetie2", name: "Twitter (Legacy)", category: .social),
        AppInfo(bundleId: "com.linkedin.LinkedIn", name: "LinkedIn", category: .social),
        AppInfo(bundleId: "com.zhiliaoapp.musically", name: "TikTok", category: .social),
        AppInfo(bundleId: "com.pinterest", name: "Pinterest", category: .social),
        AppInfo(bundleId: "com.reddit.Reddit", name: "Reddit", category: .social),
        AppInfo(bundleId: "com.tumblr.tumblr", name: "Tumblr", category: .social),
        AppInfo(bundleId: "com.toyopagroup.picaboo", name: "Snapchat", category: .social),
        AppInfo(bundleId: "com.google.ios.youtube", name: "YouTube", category: .social),
        AppInfo(bundleId: "tv.twitch", name: "Twitch", category: .social),
        AppInfo(bundleId: "com.mastodon.app", name: "Mastodon", category: .social),
        AppInfo(bundleId: "com.threads.ios", name: "Threads", category: .social),
        AppInfo(bundleId: "org.joinmastodon.app", name: "Mastodon (Official)", category: .social),
        AppInfo(bundleId: "com.bluesky.app", name: "Bluesky", category: .social),
    ]

    // MARK: - Work & Productivity Apps

    static let workApps: [AppInfo] = [
        AppInfo(bundleId: "com.tinyspeck.chatlyio", name: "Slack", category: .work),
        AppInfo(bundleId: "com.microsoft.teams", name: "Microsoft Teams", category: .work),
        AppInfo(bundleId: "us.zoom.videomeetings", name: "Zoom", category: .work),
        AppInfo(bundleId: "com.google.hangouts", name: "Google Meet", category: .work),
        AppInfo(bundleId: "notion.id", name: "Notion", category: .work),
        AppInfo(bundleId: "com.getdropbox.Dropbox", name: "Dropbox", category: .work),
        AppInfo(bundleId: "com.google.Drive", name: "Google Drive", category: .work),
        AppInfo(bundleId: "com.microsoft.Office.Word", name: "Microsoft Word", category: .work),
        AppInfo(bundleId: "com.microsoft.Office.Excel", name: "Microsoft Excel", category: .work),
        AppInfo(bundleId: "com.microsoft.Office.Powerpoint", name: "PowerPoint", category: .work),
        AppInfo(bundleId: "com.apple.iWork.Pages", name: "Pages", category: .work),
        AppInfo(bundleId: "com.apple.iWork.Numbers", name: "Numbers", category: .work),
        AppInfo(bundleId: "com.apple.iWork.Keynote", name: "Keynote", category: .work),
        AppInfo(bundleId: "com.trello.trello", name: "Trello", category: .work),
        AppInfo(bundleId: "com.asana.Asana", name: "Asana", category: .work),
        AppInfo(bundleId: "com.monday.monday", name: "Monday.com", category: .work),
        AppInfo(bundleId: "com.figma.FigmaPrototype", name: "Figma", category: .work),
        AppInfo(bundleId: "com.agilebits.onepassword-ios", name: "1Password", category: .work),
        AppInfo(bundleId: "com.clickup.app", name: "ClickUp", category: .work),
        AppInfo(bundleId: "com.basecamp.bc3-ios", name: "Basecamp", category: .work),
        AppInfo(bundleId: "com.atlassian.jira.mobile", name: "Jira", category: .work),
        AppInfo(bundleId: "com.miro.Miro", name: "Miro", category: .work),
        AppInfo(bundleId: "com.linear.ios", name: "Linear", category: .work),
        AppInfo(bundleId: "com.webex.meeting", name: "Webex", category: .work),
    ]

    // MARK: - Browser Apps

    static let browserApps: [AppInfo] = [
        AppInfo(bundleId: "com.apple.mobilesafari", name: "Safari", category: .browser),
        AppInfo(bundleId: "com.google.chrome.ios", name: "Chrome", category: .browser),
        AppInfo(bundleId: "org.mozilla.ios.Firefox", name: "Firefox", category: .browser),
        AppInfo(bundleId: "com.opera.OperaTouch", name: "Opera", category: .browser),
        AppInfo(bundleId: "com.brave.ios.browser", name: "Brave", category: .browser),
        AppInfo(bundleId: "com.duckduckgo.mobile.ios", name: "DuckDuckGo", category: .browser),
        AppInfo(bundleId: "com.microsoft.msedge", name: "Edge", category: .browser),
        AppInfo(bundleId: "com.nicegram.nicegram-stable", name: "Arc", category: .browser),
    ]

    // MARK: - Notes & Writing Apps

    static let notesApps: [AppInfo] = [
        AppInfo(bundleId: "com.apple.mobilenotes", name: "Apple Notes", category: .notes),
        AppInfo(bundleId: "com.evernote.iPhone.Evernote", name: "Evernote", category: .notes),
        AppInfo(bundleId: "com.shinyfrogo.bear-iOS", name: "Bear", category: .notes),
        AppInfo(bundleId: "md.obsidian", name: "Obsidian", category: .notes),
        AppInfo(bundleId: "com.automattic.simplenote", name: "Simplenote", category: .notes),
        AppInfo(bundleId: "net.shinyfrog.bear", name: "Bear Notes", category: .notes),
        AppInfo(bundleId: "com.craft.ios", name: "Craft", category: .notes),
        AppInfo(bundleId: "co.noteplan.NotePlan3", name: "NotePlan", category: .notes),
        AppInfo(bundleId: "com.ulyssesapp.ios", name: "Ulysses", category: .notes),
        AppInfo(bundleId: "pro.writer.mac", name: "iA Writer", category: .notes),
        AppInfo(bundleId: "com.google.Keep", name: "Google Keep", category: .notes),
        AppInfo(bundleId: "com.microsoft.onenote", name: "OneNote", category: .notes),
        AppInfo(bundleId: "com.todoist.ios", name: "Todoist", category: .notes),
        AppInfo(bundleId: "com.culturedcode.ThingsiPhone", name: "Things 3", category: .notes),
        AppInfo(bundleId: "com.omnigroup.OmniFocus3.iOS", name: "OmniFocus", category: .notes),
        AppInfo(bundleId: "com.apple.reminders", name: "Reminders", category: .notes),
    ]

    // MARK: - Finance Apps

    static let financeApps: [AppInfo] = [
        AppInfo(bundleId: "com.apple.Passbook", name: "Apple Wallet", category: .finance),
        AppInfo(bundleId: "com.paypal.PPClient", name: "PayPal", category: .finance),
        AppInfo(bundleId: "com.squareup.cashme", name: "Cash App", category: .finance),
        AppInfo(bundleId: "com.venmo.venmo", name: "Venmo", category: .finance),
        AppInfo(bundleId: "com.revolut.revolut", name: "Revolut", category: .finance),
        AppInfo(bundleId: "com.n26", name: "N26", category: .finance),
        AppInfo(bundleId: "com.wise.android", name: "Wise", category: .finance),
        AppInfo(bundleId: "com.robinhood.release", name: "Robinhood", category: .finance),
        AppInfo(bundleId: "com.coinbase.Coinbase", name: "Coinbase", category: .finance),
        AppInfo(bundleId: "com.mint.internal", name: "Mint", category: .finance),
        AppInfo(bundleId: "com.ynab.YNAB", name: "YNAB", category: .finance),
    ]

    // MARK: - Dating Apps

    static let datingApps: [AppInfo] = [
        AppInfo(bundleId: "com.cardify.tinder", name: "Tinder", category: .dating),
        AppInfo(bundleId: "com.bumble.app", name: "Bumble", category: .dating),
        AppInfo(bundleId: "com.hinge.mobile", name: "Hinge", category: .dating),
        AppInfo(bundleId: "com.okcupid.OkCupid", name: "OkCupid", category: .dating),
        AppInfo(bundleId: "com.match.match", name: "Match", category: .dating),
        AppInfo(bundleId: "com.coffeemeetsbagel", name: "Coffee Meets Bagel", category: .dating),
        AppInfo(bundleId: "com.spark.Happn", name: "Happn", category: .dating),
        AppInfo(bundleId: "com.grindr.grindr", name: "Grindr", category: .dating),
    ]

    // MARK: - Gaming Apps

    static let gamingApps: [AppInfo] = [
        AppInfo(bundleId: "com.roblox.robloxmobile", name: "Roblox", category: .gaming),
        AppInfo(bundleId: "com.mojang.minecraftpe", name: "Minecraft", category: .gaming),
        AppInfo(bundleId: "com.supercell.clashofclans", name: "Clash of Clans", category: .gaming),
        AppInfo(bundleId: "com.supercell.brawlstars", name: "Brawl Stars", category: .gaming),
        AppInfo(bundleId: "com.pubg.krmobile", name: "PUBG Mobile", category: .gaming),
        AppInfo(bundleId: "com.garena.game.codm", name: "Call of Duty Mobile", category: .gaming),
        AppInfo(bundleId: "com.epicgames.fortnite", name: "Fortnite", category: .gaming),
        AppInfo(bundleId: "com.miHoYo.GenshinImpact", name: "Genshin Impact", category: .gaming),
        AppInfo(bundleId: "com.steam.steammobile", name: "Steam", category: .gaming),
        AppInfo(bundleId: "com.playstation.PlayStationApp", name: "PlayStation App", category: .gaming),
        AppInfo(bundleId: "com.microsoft.xboxone.smartglass", name: "Xbox", category: .gaming),
        AppInfo(bundleId: "com.nintendo.znca", name: "Nintendo Switch Online", category: .gaming),
    ]

    // MARK: - Other Apps

    static let otherApps: [AppInfo] = [
        AppInfo(bundleId: "com.spotify.client", name: "Spotify", category: .other),
        AppInfo(bundleId: "com.apple.Music", name: "Apple Music", category: .other),
        AppInfo(bundleId: "com.netflix.Netflix", name: "Netflix", category: .other),
        AppInfo(bundleId: "com.amazon.aiv.AIVApp", name: "Prime Video", category: .other),
        AppInfo(bundleId: "com.disney.disneyplus", name: "Disney+", category: .other),
        AppInfo(bundleId: "com.hbo.hbonow", name: "HBO Max", category: .other),
        AppInfo(bundleId: "com.apple.tv", name: "Apple TV", category: .other),
        AppInfo(bundleId: "com.ubercab.UberClient", name: "Uber", category: .other),
        AppInfo(bundleId: "com.lyft.ios.Lyft", name: "Lyft", category: .other),
        AppInfo(bundleId: "com.grubhub.grubhub", name: "Grubhub", category: .other),
        AppInfo(bundleId: "com.ubereats.UberEats", name: "Uber Eats", category: .other),
        AppInfo(bundleId: "com.doordash.DoorDash", name: "DoorDash", category: .other),
        AppInfo(bundleId: "com.airbnb.app", name: "Airbnb", category: .other),
        AppInfo(bundleId: "com.booking.app", name: "Booking.com", category: .other),
        AppInfo(bundleId: "com.expedia.app", name: "Expedia", category: .other),
        AppInfo(bundleId: "com.amazon.Amazon", name: "Amazon", category: .other),
        AppInfo(bundleId: "com.ebay.ebay", name: "eBay", category: .other),
        AppInfo(bundleId: "com.apple.store.Jolly", name: "Apple Store", category: .other),
        AppInfo(bundleId: "com.apple.Health", name: "Health", category: .other),
        AppInfo(bundleId: "com.nike.omega", name: "Nike Run Club", category: .other),
        AppInfo(bundleId: "com.strava.Strava", name: "Strava", category: .other),
    ]

    // MARK: - Lookup Methods

    /// Find app by bundle ID
    static func find(bundleId: String) -> AppInfo? {
        apps.first { $0.id == bundleId }
    }

    /// Search apps by name or bundle ID
    static func search(query: String) -> [AppInfo] {
        guard !query.isEmpty else { return apps }
        return apps.filter { $0.matches(query: query) }
    }

    /// Get apps by category
    static func apps(in category: AppCategory) -> [AppInfo] {
        apps.filter { $0.defaultCategory == category }
    }

    /// Get apps grouped by category
    static func groupedByCategory() -> [(category: AppCategory, apps: [AppInfo])] {
        AppCategory.allCases.compactMap { category in
            let categoryApps = apps(in: category)
            return categoryApps.isEmpty ? nil : (category, categoryApps)
        }
    }
}

// MARK: - User App Category Override

/// Stores user's custom category assignment for an app
struct UserAppCategoryOverride: Codable, Identifiable, Equatable {
    var id: String { bundleId }
    let bundleId: String
    var category: AppCategory
    let updatedAt: Date

    init(bundleId: String, category: AppCategory, updatedAt: Date = Date()) {
        self.bundleId = bundleId
        self.category = category
        self.updatedAt = updatedAt
    }
}

// MARK: - App Assignment

/// Stores which apps and categories are assigned to a Context or PowerMode
struct AppAssignment: Codable, Equatable, Hashable {
    var assignedAppIds: Set<String>         // Specific app bundle IDs
    var assignedCategories: Set<AppCategory> // Entire categories

    init(
        assignedAppIds: Set<String> = [],
        assignedCategories: Set<AppCategory> = []
    ) {
        self.assignedAppIds = assignedAppIds
        self.assignedCategories = assignedCategories
    }

    /// Check if this assignment includes a given bundle ID
    /// Takes into account both specific apps and category assignments
    func includes(bundleId: String, userOverrides: [String: AppCategory]) -> Bool {
        // Check specific app assignment first (highest priority)
        if assignedAppIds.contains(bundleId) {
            return true
        }

        // Check category assignment
        // First check user override, then default category
        if let userCategory = userOverrides[bundleId] {
            return assignedCategories.contains(userCategory)
        }

        // Check default category from app library
        if let app = AppLibrary.find(bundleId: bundleId) {
            return assignedCategories.contains(app.defaultCategory)
        }

        return false
    }

    /// Check if any assignments are configured
    var hasAssignments: Bool {
        !assignedAppIds.isEmpty || !assignedCategories.isEmpty
    }

    /// Get display summary of assignments
    var summary: String {
        var parts: [String] = []

        if !assignedCategories.isEmpty {
            let categoryNames = assignedCategories.map { $0.displayName }.sorted()
            parts.append(categoryNames.joined(separator: ", "))
        }

        if !assignedAppIds.isEmpty {
            let appNames = assignedAppIds.compactMap {
                AppLibrary.find(bundleId: $0)?.name
            }.sorted()
            if !appNames.isEmpty {
                parts.append(appNames.joined(separator: ", "))
            }
        }

        return parts.isEmpty ? "No apps assigned" : parts.joined(separator: " + ")
    }

    static let empty = AppAssignment()
}
