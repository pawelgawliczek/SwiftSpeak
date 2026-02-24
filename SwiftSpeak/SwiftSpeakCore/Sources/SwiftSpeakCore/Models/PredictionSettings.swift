//
//  PredictionSettings.swift
//  SwiftSpeakCore
//
//  Unified prediction settings for per-Context configuration
//  Controls word autocomplete and sentence prediction behavior
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakMac targets
//

import Foundation

// MARK: - Word Autocomplete

/// Source for word autocomplete predictions
public enum WordAutocompleteSource: String, Codable, CaseIterable, Sendable {
    /// N-gram + spelling (local/offline)
    case system
    /// LLM predictions (uses formatting provider)
    case ai
    /// System first, AI supplements
    case both
    /// No word predictions
    case disabled

    public var displayName: String {
        switch self {
        case .system: return "System"
        case .ai: return "AI"
        case .both: return "System + AI"
        case .disabled: return "Disabled"
        }
    }

    public var description: String {
        switch self {
        case .system: return "Local N-gram and spelling predictions"
        case .ai: return "AI-powered predictions using your formatting provider"
        case .both: return "System predictions first, AI fills remaining slots"
        case .disabled: return "No word autocomplete"
        }
    }

    public var icon: String {
        switch self {
        case .system: return "cpu"
        case .ai: return "sparkles"
        case .both: return "cpu.fill"
        case .disabled: return "xmark.circle"
        }
    }
}

/// Settings for word autocomplete behavior
public struct WordAutocompleteSettings: Codable, Equatable, Hashable, Sendable {
    /// Source for word predictions
    public var source: WordAutocompleteSource

    public init(source: WordAutocompleteSource = .system) {
        self.source = source
    }
}

// MARK: - Sentence Predictions

/// Settings for sentence prediction behavior (Quick Actions)
public struct SentencePredictionSettings: Codable, Sendable {
    /// Whether sentence predictions are enabled
    public var enabled: Bool

    /// Quick Actions configured for this context
    /// When nil, uses global Quick Actions (backwards compatibility)
    public var quickActions: [QuickAction]?

    public init(enabled: Bool = true, quickActions: [QuickAction]? = nil) {
        self.enabled = enabled
        self.quickActions = quickActions
    }

    /// Get effective Quick Actions - context-specific or fallback to default
    public func effectiveQuickActions(globalActions: [QuickAction]) -> [QuickAction] {
        quickActions ?? globalActions
    }

    /// Get enabled Quick Actions sorted by order
    public func enabledQuickActions(globalActions: [QuickAction]) -> [QuickAction] {
        effectiveQuickActions(globalActions: globalActions)
            .filter { $0.isEnabled }
            .sorted { $0.order < $1.order }
    }
}

// MARK: - SentencePredictionSettings Conformances

extension SentencePredictionSettings: Equatable {
    public static func == (lhs: SentencePredictionSettings, rhs: SentencePredictionSettings) -> Bool {
        lhs.enabled == rhs.enabled && lhs.quickActions == rhs.quickActions
    }
}

extension SentencePredictionSettings: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(enabled)
        hasher.combine(quickActions)
    }
}
