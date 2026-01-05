//
//  LanguageSupportLevel.swift
//  SwiftSpeakCore
//
//  Language support level for transcription providers
//

import SwiftUI

/// Language support level for a provider
public enum LanguageSupportLevel: String, Codable, CaseIterable, Comparable, Sendable {
    case excellent    // Native-level quality
    case good         // Minor occasional errors
    case limited      // Works but not recommended
    case unsupported  // Does not work

    public var icon: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .limited: return "exclamationmark.triangle.fill"
        case .unsupported: return "xmark.circle.fill"
        }
    }

    public var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .limited: return .orange
        case .unsupported: return .red
        }
    }

    public var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .limited: return "Limited"
        case .unsupported: return "Not Supported"
        }
    }

    public var shortLabel: String {
        switch self {
        case .excellent: return "Best"
        case .good: return "Good"
        case .limited: return "Limited"
        case .unsupported: return "N/A"
        }
    }

    public var stars: Int {
        switch self {
        case .excellent: return 3
        case .good: return 2
        case .limited: return 1
        case .unsupported: return 0
        }
    }

    // Comparable conformance for sorting
    public static func < (lhs: LanguageSupportLevel, rhs: LanguageSupportLevel) -> Bool {
        lhs.stars < rhs.stars
    }
}
