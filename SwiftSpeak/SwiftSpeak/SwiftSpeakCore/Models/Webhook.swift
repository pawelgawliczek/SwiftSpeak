//
//  Webhook.swift
//  SwiftSpeak
//
//  Webhook configuration models
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

// MARK: - Webhook (Phase 4)

/// Webhook types for different execution points
public enum WebhookType: String, Codable, CaseIterable {
    case contextSource = "context"     // GET before processing
    case outputDestination = "output"  // POST after completion
    case automationTrigger = "trigger" // POST for Make/Zapier

    public var displayName: String {
        switch self {
        case .contextSource: return "Context Source"
        case .outputDestination: return "Output Destination"
        case .automationTrigger: return "Automation Trigger"
        }
    }

    public var description: String {
        switch self {
        case .contextSource: return "Fetch data before processing"
        case .outputDestination: return "Send results after completion"
        case .automationTrigger: return "Trigger external automation"
        }
    }
}

/// Authentication types for webhooks
public enum WebhookAuthType: String, Codable, CaseIterable {
    case none = "none"
    case bearerToken = "bearer"
    case apiKeyHeader = "api_key"
    case basicAuth = "basic"

    public var displayName: String {
        switch self {
        case .none: return "None"
        case .bearerToken: return "Bearer Token"
        case .apiKeyHeader: return "API Key"
        case .basicAuth: return "Basic Auth"
        }
    }
}

/// Webhook template for common services
public enum WebhookTemplate: String, Codable, CaseIterable {
    case slack = "slack"
    case notion = "notion"
    case todoist = "todoist"
    case make = "make"
    case zapier = "zapier"
    case custom = "custom"

    public var displayName: String {
        switch self {
        case .slack: return "Slack"
        case .notion: return "Notion"
        case .todoist: return "Todoist"
        case .make: return "Make"
        case .zapier: return "Zapier"
        case .custom: return "Custom"
        }
    }

    public var icon: String {
        switch self {
        case .slack: return "bubble.left.fill"
        case .notion: return "doc.text.fill"
        case .todoist: return "checkmark.circle.fill"
        case .make: return "bolt.fill"
        case .zapier: return "link"
        case .custom: return "gearshape.fill"
        }
    }
}

/// A webhook configuration
public struct Webhook: Codable, Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var type: WebhookType
    public var template: WebhookTemplate
    public var url: URL
    public var isEnabled: Bool

    // Authentication
    public var authType: WebhookAuthType
    public var authToken: String?
    public var authHeader: String?

    // Payload configuration (for POST)
    public var includeInput: Bool
    public var includeOutput: Bool
    public var includeModeName: Bool
    public var includeContext: Bool
    public var includeTimestamp: Bool

    // Status
    public var lastTriggered: Date?
    public var lastStatus: String?

    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        type: WebhookType,
        template: WebhookTemplate = .custom,
        url: URL,
        isEnabled: Bool = true,
        authType: WebhookAuthType = .none,
        authToken: String? = nil,
        authHeader: String? = nil,
        includeInput: Bool = true,
        includeOutput: Bool = true,
        includeModeName: Bool = true,
        includeContext: Bool = true,
        includeTimestamp: Bool = true,
        lastTriggered: Date? = nil,
        lastStatus: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.template = template
        self.url = url
        self.isEnabled = isEnabled
        self.authType = authType
        self.authToken = authToken
        self.authHeader = authHeader
        self.includeInput = includeInput
        self.includeOutput = includeOutput
        self.includeModeName = includeModeName
        self.includeContext = includeContext
        self.includeTimestamp = includeTimestamp
        self.lastTriggered = lastTriggered
        self.lastStatus = lastStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Sample webhooks for previews
    public static var samples: [Webhook] {
        [
            Webhook(
                name: "Calendar Events",
                type: .contextSource,
                template: .custom,
                url: URL(string: "https://api.calendar.com/today")!,
                authType: .bearerToken,
                authToken: "cal_xxxx",
                lastTriggered: Date().addingTimeInterval(-7200),
                lastStatus: "success"
            ),
            Webhook(
                name: "Slack Channel",
                type: .outputDestination,
                template: .slack,
                url: URL(string: "https://hooks.slack.com/services/xxx")!,
                lastTriggered: Date().addingTimeInterval(-86400),
                lastStatus: "success"
            ),
            Webhook(
                name: "Notion Database",
                type: .outputDestination,
                template: .notion,
                url: URL(string: "https://api.notion.com/v1/pages")!,
                isEnabled: false,
                authType: .bearerToken,
                authToken: "secret_xxx"
            ),
            Webhook(
                name: "Make.com Scenario",
                type: .automationTrigger,
                template: .make,
                url: URL(string: "https://hook.make.com/xxx")!,
                lastTriggered: Date().addingTimeInterval(-259200),
                lastStatus: "success"
            )
        ]
    }
}
