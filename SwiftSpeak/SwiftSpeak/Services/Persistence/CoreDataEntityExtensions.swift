//
//  CoreDataEntityExtensions.swift
//  SwiftSpeak
//
//  Extensions for Core Data entities to convert to/from model structs.
//  Uses JSON serialization for full model fidelity with CloudKit sync.
//

import CoreData
import Foundation

// MARK: - TranscriptionRecordEntity Extensions

extension TranscriptionRecordEntity {

    func toModel() -> TranscriptionRecord? {
        guard let jsonData = jsonData else { return nil }
        return try? JSONDecoder().decode(TranscriptionRecord.self, from: jsonData)
    }

    func update(from model: TranscriptionRecord) {
        id = model.id
        timestamp = model.timestamp
        jsonData = try? JSONEncoder().encode(model)
    }
}

// MARK: - ConversationContextEntity Extensions

extension ConversationContextEntity {

    func toModel() -> ConversationContext? {
        guard let jsonData = jsonData else { return nil }
        return try? JSONDecoder().decode(ConversationContext.self, from: jsonData)
    }

    func update(from model: ConversationContext) {
        id = model.id
        name = model.name
        updatedAt = model.updatedAt
        jsonData = try? JSONEncoder().encode(model)
    }
}

// MARK: - PowerModeEntity Extensions

extension PowerModeEntity {

    func toModel() -> PowerMode? {
        guard let jsonData = jsonData else { return nil }
        return try? JSONDecoder().decode(PowerMode.self, from: jsonData)
    }

    func update(from model: PowerMode) {
        id = model.id
        name = model.name
        updatedAt = model.updatedAt
        jsonData = try? JSONEncoder().encode(model)
    }
}

// MARK: - CustomTemplateEntity Extensions

extension CustomTemplateEntity {

    func toModel() -> CustomTemplate? {
        guard let jsonData = jsonData else { return nil }
        return try? JSONDecoder().decode(CustomTemplate.self, from: jsonData)
    }

    func update(from model: CustomTemplate) {
        id = model.id
        name = model.name
        updatedAt = model.updatedAt
        jsonData = try? JSONEncoder().encode(model)
    }
}

// MARK: - VocabularyEntryEntity Extensions

extension VocabularyEntryEntity {

    func toModel() -> VocabularyEntry? {
        guard let jsonData = jsonData else { return nil }
        return try? JSONDecoder().decode(VocabularyEntry.self, from: jsonData)
    }

    func update(from model: VocabularyEntry) {
        id = model.id
        recognizedWord = model.recognizedWord
        updatedAt = model.updatedAt
        jsonData = try? JSONEncoder().encode(model)
    }
}

// MARK: - WebhookEntity Extensions

extension WebhookEntity {

    func toModel() -> Webhook? {
        guard let jsonData = jsonData else { return nil }
        return try? JSONDecoder().decode(Webhook.self, from: jsonData)
    }

    func update(from model: Webhook) {
        id = model.id
        name = model.name
        updatedAt = model.updatedAt
        jsonData = try? JSONEncoder().encode(model)
    }
}

// MARK: - KnowledgeDocumentEntity Extensions

extension KnowledgeDocumentEntity {

    func toModel() -> KnowledgeDocument? {
        guard let jsonData = jsonData else { return nil }
        return try? JSONDecoder().decode(KnowledgeDocument.self, from: jsonData)
    }

    func update(from model: KnowledgeDocument) {
        id = model.id
        name = model.name
        updatedAt = model.lastUpdated
        jsonData = try? JSONEncoder().encode(model)
    }
}

// MARK: - AIProviderConfigEntity Extensions

extension AIProviderConfigEntity {

    func toModel() -> AIProviderConfig? {
        guard let jsonData = jsonData else { return nil }
        // Note: API key is NOT stored in Core Data for security
        // It's retrieved from Keychain separately
        var config = try? JSONDecoder().decode(AIProviderConfig.self, from: jsonData)
        // Clear the API key - it should come from Keychain
        config?.apiKey = ""
        return config
    }

    func update(from model: AIProviderConfig) {
        if id == nil { id = UUID() }
        providerRawValue = model.provider.rawValue
        updatedAt = Date()
        // Create a copy without API key for storage
        var modelForStorage = model
        modelForStorage.apiKey = ""  // Don't store API key in Core Data
        jsonData = try? JSONEncoder().encode(modelForStorage)
    }
}

// MARK: - GlobalSettingsEntity Extensions

extension GlobalSettingsEntity {

    static func get(key: String, in context: NSManagedObjectContext) -> String? {
        let request = GlobalSettingsEntity.fetchRequest()
        request.predicate = NSPredicate(format: "key == %@", key)
        request.fetchLimit = 1
        return try? context.fetch(request).first?.value
    }

    static func set(key: String, value: String?, in context: NSManagedObjectContext) {
        let request = GlobalSettingsEntity.fetchRequest()
        request.predicate = NSPredicate(format: "key == %@", key)
        request.fetchLimit = 1

        let entity: GlobalSettingsEntity
        if let existing = try? context.fetch(request).first {
            entity = existing
        } else {
            entity = GlobalSettingsEntity(context: context)
            entity.id = UUID()
            entity.key = key
        }
        entity.value = value
        entity.updatedAt = Date()
    }
}
