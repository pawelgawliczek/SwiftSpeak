//
//  AppLibrary.swift
//  SwiftSpeakCore
//
//  App category and assignment types for context auto-assignment
//

import Foundation
import SwiftUI

// MARK: - App Category

/// Categories for organizing apps and assigning contexts
public enum AppCategory: String, Codable, CaseIterable, Identifiable, Sendable {
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

    public var id: String { rawValue }

    public var displayName: String {
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

    public var icon: String {
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

    public var color: Color {
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
public struct AppInfo: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String                  // Bundle ID (e.g., "net.whatsapp.WhatsApp")
    public let name: String                // Display name (e.g., "WhatsApp")
    public let defaultCategory: AppCategory

    public init(bundleId: String, name: String, category: AppCategory) {
        self.id = bundleId
        self.name = name
        self.defaultCategory = category
    }

    /// Search helper - matches name or bundle id
    public func matches(query: String) -> Bool {
        let lowercased = query.lowercased()
        return name.lowercased().contains(lowercased) ||
               id.lowercased().contains(lowercased)
    }
}

// MARK: - App Assignment

/// Stores which apps and categories are assigned to a Context or PowerMode
public struct AppAssignment: Codable, Equatable, Hashable, Sendable {
    public var assignedAppIds: Set<String>         // Specific app bundle IDs
    public var assignedCategories: Set<AppCategory> // Entire categories

    public init(
        assignedAppIds: Set<String> = [],
        assignedCategories: Set<AppCategory> = []
    ) {
        self.assignedAppIds = assignedAppIds
        self.assignedCategories = assignedCategories
    }

    /// Check if this assignment includes a given bundle ID
    /// Takes into account both specific apps and category assignments
    public func includes(bundleId: String, userOverrides: [String: AppCategory], appLookup: ((String) -> AppCategory?)? = nil) -> Bool {
        // Check specific app assignment first (highest priority)
        if assignedAppIds.contains(bundleId) {
            return true
        }

        // Check category assignment
        // First check user override, then default category
        if let userCategory = userOverrides[bundleId] {
            return assignedCategories.contains(userCategory)
        }

        // Check default category from app library (if lookup provided)
        if let lookup = appLookup, let category = lookup(bundleId) {
            return assignedCategories.contains(category)
        }

        return false
    }

    /// Check if any assignments are configured
    public var hasAssignments: Bool {
        !assignedAppIds.isEmpty || !assignedCategories.isEmpty
    }

    /// Get display summary of assignments (without app library lookup)
    public var summary: String {
        var parts: [String] = []

        if !assignedCategories.isEmpty {
            let categoryNames = assignedCategories.map { $0.displayName }.sorted()
            parts.append(categoryNames.joined(separator: ", "))
        }

        if !assignedAppIds.isEmpty {
            parts.append("\(assignedAppIds.count) app(s)")
        }

        return parts.isEmpty ? "No apps assigned" : parts.joined(separator: " + ")
    }

    public static let empty = AppAssignment()
}

// MARK: - User App Category Override

/// Stores user's custom category assignment for an app
public struct UserAppCategoryOverride: Codable, Identifiable, Equatable, Sendable {
    public var id: String { bundleId }
    public let bundleId: String
    public var category: AppCategory
    public let updatedAt: Date

    public init(bundleId: String, category: AppCategory, updatedAt: Date = Date()) {
        self.bundleId = bundleId
        self.category = category
        self.updatedAt = updatedAt
    }
}
