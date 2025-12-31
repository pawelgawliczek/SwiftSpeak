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
struct ProviderSelection: Codable, Equatable, Hashable {
    var providerType: ProviderType
    var model: String?  // Optional model override, nil = use provider default

    init(providerType: ProviderType, model: String? = nil) {
        self.providerType = providerType
        self.model = model
    }

    var displayName: String {
        if let model = model {
            return "\(providerType.displayName) \(model)"
        }
        return providerType.displayName
    }

    var icon: String {
        providerType.icon
    }

    var isLocal: Bool {
        providerType.isLocal
    }
}

/// Unified provider type that covers both cloud and local providers
enum ProviderType: Codable, Equatable, Hashable {
    case cloud(AIProvider)
    case local(LocalModelType)

    var displayName: String {
        switch self {
        case .cloud(let provider): return provider.displayName
        case .local(let type): return type.displayName
        }
    }

    var shortName: String {
        switch self {
        case .cloud(let provider): return provider.shortName
        case .local(let type): return type.displayName
        }
    }

    var icon: String {
        switch self {
        case .cloud(let provider): return provider.icon
        case .local(let type): return type.icon
        }
    }

    var isLocal: Bool {
        if case .local = self { return true }
        return false
    }

    var isCloud: Bool {
        if case .cloud = self { return true }
        return false
    }

    /// Check if this provider type supports a given capability
    func supports(_ category: ProviderUsageCategory) -> Bool {
        switch self {
        case .cloud(let provider):
            return provider.supportedCategories.contains(category)
        case .local(let type):
            return type.supportedCategories.contains(category)
        }
    }
}

// Custom Codable for ProviderType
extension ProviderType {
    enum CodingKeys: String, CodingKey {
        case type, cloudProvider, localType
    }

    init(from decoder: Decoder) throws {
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

    func encode(to encoder: Encoder) throws {
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
struct ProviderDefaults: Codable, Equatable {
    var transcription: ProviderSelection?
    var translation: ProviderSelection?
    var powerMode: ProviderSelection?
    var useLocalWhenOffline: Bool

    init(
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

    static var `default`: ProviderDefaults {
        ProviderDefaults()
    }
}
