//
//  CoreDataManager.swift
//  SwiftSpeak
//
//  Provides a clean CRUD interface for Core Data entities.
//  Handles conversion between Core Data entities and app model structs.
//  Uses JSON serialization for full model fidelity with CloudKit sync.
//

import CoreData
import Foundation
import Combine

/// Manages Core Data operations with a clean interface for the app.
/// Converts between Core Data entities and existing model structs.
@MainActor
final class CoreDataManager: ObservableObject {

    // MARK: - Shared Instance

    static let shared = CoreDataManager()

    // MARK: - Properties

    private let persistence: PersistenceController
    private var viewContext: NSManagedObjectContext {
        persistence.viewContext
    }

    // MARK: - Published Properties for UI Binding

    @Published private(set) var transcriptionHistory: [TranscriptionRecord] = []
    @Published private(set) var contexts: [ConversationContext] = []
    @Published private(set) var powerModes: [PowerMode] = []
    @Published private(set) var customTemplates: [CustomTemplate] = []
    @Published private(set) var vocabulary: [VocabularyEntry] = []
    @Published private(set) var webhooks: [Webhook] = []
    @Published private(set) var knowledgeDocuments: [KnowledgeDocument] = []
    @Published private(set) var aiProviderConfigs: [AIProviderConfig] = []

    // MARK: - Initialization

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        loadAllData()

        // Listen for iCloud sync updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudSync),
            name: .coreDataDidSyncFromCloud,
            object: nil
        )
    }

    @objc private func handleCloudSync() {
        loadAllData()
        appLog("CoreDataManager: Reloaded data after iCloud sync", category: "CoreData")
    }

    // MARK: - Load All Data

    func loadAllData() {
        loadTranscriptionHistory()
        loadContexts()
        loadPowerModes()
        loadCustomTemplates()
        loadVocabulary()
        loadWebhooks()
        loadKnowledgeDocuments()
        loadAIProviderConfigs()
    }

    // MARK: - TranscriptionRecord CRUD

    private func loadTranscriptionHistory() {
        let request = TranscriptionRecordEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TranscriptionRecordEntity.timestamp, ascending: false)]

        do {
            let entities = try viewContext.fetch(request)
            transcriptionHistory = entities.compactMap { $0.toModel() }
        } catch {
            appLog("Failed to load transcription history: \(error)", category: "CoreData", level: .error)
        }
    }

    func addTranscription(_ record: TranscriptionRecord) {
        let entity = TranscriptionRecordEntity(context: viewContext)
        entity.update(from: record)
        persistence.save()
        loadTranscriptionHistory()
    }

    func updateTranscription(_ record: TranscriptionRecord) {
        let request = TranscriptionRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", record.id as CVarArg)

        do {
            if let entity = try viewContext.fetch(request).first {
                entity.update(from: record)
                persistence.save()
                loadTranscriptionHistory()
            }
        } catch {
            appLog("Failed to update transcription: \(error)", category: "CoreData", level: .error)
        }
    }

    func deleteTranscription(id: UUID) {
        let request = TranscriptionRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            if let entity = try viewContext.fetch(request).first {
                viewContext.delete(entity)
                persistence.save()
                loadTranscriptionHistory()
            }
        } catch {
            appLog("Failed to delete transcription: \(error)", category: "CoreData", level: .error)
        }
    }

    func clearTranscriptionHistory() {
        let request = TranscriptionRecordEntity.fetchRequest()

        do {
            let entities = try viewContext.fetch(request)
            entities.forEach { viewContext.delete($0) }
            persistence.save()
            transcriptionHistory = []
        } catch {
            appLog("Failed to clear history: \(error)", category: "CoreData", level: .error)
        }
    }

    // MARK: - ConversationContext CRUD

    private func loadContexts() {
        let request = ConversationContextEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ConversationContextEntity.name, ascending: true)]

        do {
            let entities = try viewContext.fetch(request)
            contexts = entities.compactMap { $0.toModel() }

            // Add presets if no contexts exist
            if contexts.isEmpty {
                for preset in ConversationContext.presets {
                    addContext(preset)
                }
            }
        } catch {
            appLog("Failed to load contexts: \(error)", category: "CoreData", level: .error)
        }
    }

    func addContext(_ context: ConversationContext) {
        let entity = ConversationContextEntity(context: viewContext)
        entity.update(from: context)
        persistence.save()
        loadContexts()
    }

    func updateContext(_ context: ConversationContext) {
        let request = ConversationContextEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", context.id as CVarArg)

        do {
            if let entity = try viewContext.fetch(request).first {
                entity.update(from: context)
                persistence.save()
                loadContexts()
            }
        } catch {
            appLog("Failed to update context: \(error)", category: "CoreData", level: .error)
        }
    }

    func deleteContext(id: UUID) {
        let request = ConversationContextEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            if let entity = try viewContext.fetch(request).first {
                viewContext.delete(entity)
                persistence.save()
                loadContexts()
            }
        } catch {
            appLog("Failed to delete context: \(error)", category: "CoreData", level: .error)
        }
    }

    func getContext(id: UUID) -> ConversationContext? {
        contexts.first { $0.id == id }
    }

    // MARK: - PowerMode CRUD

    private func loadPowerModes() {
        let request = PowerModeEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PowerModeEntity.name, ascending: true)]

        do {
            let entities = try viewContext.fetch(request)
            powerModes = entities.compactMap { $0.toModel() }

            // Add presets if no power modes exist
            if powerModes.isEmpty {
                for preset in PowerMode.presets {
                    addPowerMode(preset)
                }
            }
        } catch {
            appLog("Failed to load power modes: \(error)", category: "CoreData", level: .error)
        }
    }

    func addPowerMode(_ powerMode: PowerMode) {
        let entity = PowerModeEntity(context: viewContext)
        entity.update(from: powerMode)
        persistence.save()
        loadPowerModes()
    }

    func updatePowerMode(_ powerMode: PowerMode) {
        let request = PowerModeEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", powerMode.id as CVarArg)

        do {
            if let entity = try viewContext.fetch(request).first {
                entity.update(from: powerMode)
                persistence.save()
                loadPowerModes()
            }
        } catch {
            appLog("Failed to update power mode: \(error)", category: "CoreData", level: .error)
        }
    }

    func deletePowerMode(id: UUID) {
        let request = PowerModeEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            if let entity = try viewContext.fetch(request).first {
                viewContext.delete(entity)
                persistence.save()
                loadPowerModes()
            }
        } catch {
            appLog("Failed to delete power mode: \(error)", category: "CoreData", level: .error)
        }
    }

    func getPowerMode(id: UUID) -> PowerMode? {
        powerModes.first { $0.id == id }
    }

    // MARK: - CustomTemplate CRUD

    private func loadCustomTemplates() {
        let request = CustomTemplateEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CustomTemplateEntity.name, ascending: true)]

        do {
            let entities = try viewContext.fetch(request)
            customTemplates = entities.compactMap { $0.toModel() }
        } catch {
            appLog("Failed to load custom templates: \(error)", category: "CoreData", level: .error)
        }
    }

    func addCustomTemplate(_ template: CustomTemplate) {
        let entity = CustomTemplateEntity(context: viewContext)
        entity.update(from: template)
        persistence.save()
        loadCustomTemplates()
    }

    func updateCustomTemplate(_ template: CustomTemplate) {
        let request = CustomTemplateEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", template.id as CVarArg)

        do {
            if let entity = try viewContext.fetch(request).first {
                entity.update(from: template)
                persistence.save()
                loadCustomTemplates()
            }
        } catch {
            appLog("Failed to update custom template: \(error)", category: "CoreData", level: .error)
        }
    }

    func deleteCustomTemplate(id: UUID) {
        let request = CustomTemplateEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            if let entity = try viewContext.fetch(request).first {
                viewContext.delete(entity)
                persistence.save()
                loadCustomTemplates()
            }
        } catch {
            appLog("Failed to delete custom template: \(error)", category: "CoreData", level: .error)
        }
    }

    // MARK: - VocabularyEntry CRUD

    private func loadVocabulary() {
        let request = VocabularyEntryEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \VocabularyEntryEntity.recognizedWord, ascending: true)]

        do {
            let entities = try viewContext.fetch(request)
            vocabulary = entities.compactMap { $0.toModel() }
        } catch {
            appLog("Failed to load vocabulary: \(error)", category: "CoreData", level: .error)
        }
    }

    func addVocabularyEntry(_ entry: VocabularyEntry) {
        let entity = VocabularyEntryEntity(context: viewContext)
        entity.update(from: entry)
        persistence.save()
        loadVocabulary()
    }

    func updateVocabularyEntry(_ entry: VocabularyEntry) {
        let request = VocabularyEntryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)

        do {
            if let entity = try viewContext.fetch(request).first {
                entity.update(from: entry)
                persistence.save()
                loadVocabulary()
            }
        } catch {
            appLog("Failed to update vocabulary entry: \(error)", category: "CoreData", level: .error)
        }
    }

    func deleteVocabularyEntry(id: UUID) {
        let request = VocabularyEntryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            if let entity = try viewContext.fetch(request).first {
                viewContext.delete(entity)
                persistence.save()
                loadVocabulary()
            }
        } catch {
            appLog("Failed to delete vocabulary entry: \(error)", category: "CoreData", level: .error)
        }
    }

    // MARK: - Webhook CRUD

    private func loadWebhooks() {
        let request = WebhookEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WebhookEntity.name, ascending: true)]

        do {
            let entities = try viewContext.fetch(request)
            webhooks = entities.compactMap { $0.toModel() }
        } catch {
            appLog("Failed to load webhooks: \(error)", category: "CoreData", level: .error)
        }
    }

    func addWebhook(_ webhook: Webhook) {
        let entity = WebhookEntity(context: viewContext)
        entity.update(from: webhook)
        persistence.save()
        loadWebhooks()
    }

    func updateWebhook(_ webhook: Webhook) {
        let request = WebhookEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", webhook.id as CVarArg)

        do {
            if let entity = try viewContext.fetch(request).first {
                entity.update(from: webhook)
                persistence.save()
                loadWebhooks()
            }
        } catch {
            appLog("Failed to update webhook: \(error)", category: "CoreData", level: .error)
        }
    }

    func deleteWebhook(id: UUID) {
        let request = WebhookEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            if let entity = try viewContext.fetch(request).first {
                viewContext.delete(entity)
                persistence.save()
                loadWebhooks()
            }
        } catch {
            appLog("Failed to delete webhook: \(error)", category: "CoreData", level: .error)
        }
    }

    // MARK: - KnowledgeDocument CRUD

    private func loadKnowledgeDocuments() {
        let request = KnowledgeDocumentEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \KnowledgeDocumentEntity.name, ascending: true)]

        do {
            let entities = try viewContext.fetch(request)
            knowledgeDocuments = entities.compactMap { $0.toModel() }
        } catch {
            appLog("Failed to load knowledge documents: \(error)", category: "CoreData", level: .error)
        }
    }

    func addKnowledgeDocument(_ document: KnowledgeDocument) {
        let entity = KnowledgeDocumentEntity(context: viewContext)
        entity.update(from: document)
        persistence.save()
        loadKnowledgeDocuments()
    }

    func updateKnowledgeDocument(_ document: KnowledgeDocument) {
        let request = KnowledgeDocumentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", document.id as CVarArg)

        do {
            if let entity = try viewContext.fetch(request).first {
                entity.update(from: document)
                persistence.save()
                loadKnowledgeDocuments()
            }
        } catch {
            appLog("Failed to update knowledge document: \(error)", category: "CoreData", level: .error)
        }
    }

    func deleteKnowledgeDocument(id: UUID) {
        let request = KnowledgeDocumentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            if let entity = try viewContext.fetch(request).first {
                viewContext.delete(entity)
                persistence.save()
                loadKnowledgeDocuments()
            }
        } catch {
            appLog("Failed to delete knowledge document: \(error)", category: "CoreData", level: .error)
        }
    }

    // MARK: - AIProviderConfig CRUD

    private func loadAIProviderConfigs() {
        let request = AIProviderConfigEntity.fetchRequest()

        do {
            let entities = try viewContext.fetch(request)
            aiProviderConfigs = entities.compactMap { $0.toModel() }
        } catch {
            appLog("Failed to load AI provider configs: \(error)", category: "CoreData", level: .error)
        }
    }

    func addAIProviderConfig(_ config: AIProviderConfig) {
        let entity = AIProviderConfigEntity(context: viewContext)
        entity.update(from: config)
        persistence.save()
        loadAIProviderConfigs()
    }

    func updateAIProviderConfig(_ config: AIProviderConfig) {
        let request = AIProviderConfigEntity.fetchRequest()
        request.predicate = NSPredicate(format: "providerRawValue == %@", config.provider.rawValue)

        do {
            if let entity = try viewContext.fetch(request).first {
                entity.update(from: config)
                persistence.save()
                loadAIProviderConfigs()
            }
        } catch {
            appLog("Failed to update AI provider config: \(error)", category: "CoreData", level: .error)
        }
    }

    func deleteAIProviderConfig(provider: AIProvider) {
        let request = AIProviderConfigEntity.fetchRequest()
        request.predicate = NSPredicate(format: "providerRawValue == %@", provider.rawValue)

        do {
            if let entity = try viewContext.fetch(request).first {
                viewContext.delete(entity)
                persistence.save()
                loadAIProviderConfigs()
            }
        } catch {
            appLog("Failed to delete AI provider config: \(error)", category: "CoreData", level: .error)
        }
    }

    func getAIProviderConfig(for provider: AIProvider) -> AIProviderConfig? {
        aiProviderConfigs.first { $0.provider == provider }
    }

    // MARK: - Global Settings

    func getGlobalSetting(key: String) -> String? {
        GlobalSettingsEntity.get(key: key, in: viewContext)
    }

    func setGlobalSetting(key: String, value: String?) {
        GlobalSettingsEntity.set(key: key, value: value, in: viewContext)
        persistence.save()
    }
}
