//
//  Subscription.swift
//  SwiftSpeak
//
//  Data retention models
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

// MARK: - Data Retention

/// Options for automatic transcription history cleanup
public enum DataRetentionPeriod: String, Codable, CaseIterable, Identifiable {
    case never = "never"
    case sevenDays = "7days"
    case thirtyDays = "30days"
    case ninetyDays = "90days"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .never: return "Keep Forever"
        case .sevenDays: return "7 Days"
        case .thirtyDays: return "30 Days"
        case .ninetyDays: return "90 Days"
        }
    }

    /// Number of days before data is deleted, nil for never
    public var days: Int? {
        switch self {
        case .never: return nil
        case .sevenDays: return 7
        case .thirtyDays: return 30
        case .ninetyDays: return 90
        }
    }
}
