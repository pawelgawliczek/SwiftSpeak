//
//  ProviderSelection.swift
//  SwiftSpeak
//
//  Provider selection and defaults models
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

// MARK: - Phase 10: Provider Selection

/// A provider + model selection pair
public struct ProviderSelection: Codable, Equatable, Hashable {
    public var providerType: ProviderType
    public var model: String?  // Optional model override, nil = use provider default

    public init(providerType: ProviderType, model: String? = nil) {
        self.providerType = providerType
        self.model = model
    }

    public var displayName: String {
        if let model = model {
            return "\(providerType.displayName) \(model)"
        }
        return providerType.displayName
    }

    public var icon: String {
        providerType.icon
    }

    public var isLocal: Bool {
        providerType.isLocal
    }
}

/// Unified provider type that covers both cloud and local providers
public enum ProviderType: Codable, Equatable, Hashable {
    case cloud(AIProvider)
    case local(LocalModelType)

    public var displayName: String {
        switch self {
        case .cloud(let provider): return provider.displayName
        case .local(let type): return type.displayName
        }
    }

    public var shortName: String {
        switch self {
        case .cloud(let provider): return provider.shortName
        case .local(let type): return type.displayName
        }
    }

    public var icon: String {
        switch self {
        case .cloud(let provider): return provider.icon
        case .local(let type): return type.icon
        }
    }

    public var isLocal: Bool {
        if case .local = self { return true }
        return false
    }

    public var isCloud: Bool {
        if case .cloud = self { return true }
        return false
    }

    /// Check if this provider type supports a given capability
    public func supports(_ category: ProviderUsageCategory) -> Bool {
        switch self {
        case .cloud(let provider):
            return provider.supportedCategories.contains(category)
        case .local(let type):
            return type.supportedCategories.contains(category)
        }
    }
}

// Custom Codable for ProviderType
public extension ProviderType {
    enum CodingKeys: String, CodingKey {
        case type, cloudProvider, localType
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        if type == "cloud" {
            let provider = try container.decode(AIProvider.self, forKey: .cloudProvider)
            self = .cloud(provider)
        } else {
            let localType = try container.decode(LocalModelType.self, forKey: .localType)
            self = .local(localType)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .cloud(let provider):
            try container.encode("cloud", forKey: .type)
            try container.encode(provider, forKey: .cloudProvider)
        case .local(let localType):
            try container.encode("local", forKey: .type)
            try container.encode(localType, forKey: .localType)
        }
    }
}

/// Global default provider settings per capability
public struct ProviderDefaults: Codable, Equatable {
    public var transcription: ProviderSelection?
    public var translation: ProviderSelection?
    public var powerMode: ProviderSelection?
    public var useLocalWhenOffline: Bool

    public init(
        transcription: ProviderSelection? = nil,
        translation: ProviderSelection? = nil,
        powerMode: ProviderSelection? = nil,
        useLocalWhenOffline: Bool = true
    ) {
        self.transcription = transcription
        self.translation = translation
        self.powerMode = powerMode
        self.useLocalWhenOffline = useLocalWhenOffline
    }

    public static var `default`: ProviderDefaults {
        ProviderDefaults()
    }
}
