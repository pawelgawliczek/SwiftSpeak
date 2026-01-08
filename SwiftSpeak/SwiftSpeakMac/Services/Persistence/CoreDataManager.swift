//
//  CoreDataManager.swift
//  SwiftSpeak
//
//  Provides a clean CRUD interface for Core Data entities.
//  Handles conversion between Core Data entities and app model structs.
//  Uses JSON serialization for full model fidelity with CloudKit sync.
//  Shared between iOS and macOS.
//

import CoreData
import Combine
import Foundation
import SwiftSpeakCore

// MARK: - Platform-aware Logging

/// Log helper that works on both iOS and macOS
#if os(iOS)
private func coreDataLog(_ message: String, level: LogEntry.LogLevel = .info) {
    appLog(message, category: "CoreData", level: level)
}
#elseif os(macOS)
private func coreDataLog(_ message: String, level: MacLogLevel = .info) {
    macLog(message, category: "CoreData", level: level)
}
#endif

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

    /// Debounce timer for CloudKit sync notifications
    private var cloudSyncDebounceTask: Task<Void, Never>?

    /// Flag to prevent reloading while we just saved
    private var isLocalSaveInProgress = false

    /// Last time we reloaded data (for throttling)
    private var lastReloadTime: Date = .distantPast

    /// Minimum interval between reloads (seconds)
    private let minimumReloadInterval: TimeInterval = 5.0

    // MARK: - Published Properties for UI Binding

    @Published private(set) var transcriptionHistory: [TranscriptionRecord] = []
    @Published private(set) var contexts: [ConversationContext] = []
    @Published private(set) var powerModes: [PowerMode] = []
    @Published private(set) var customTemplates: [CustomTemplate] = []
    @Published private(set) var vocabulary: [VocabularyEntry] = []
    @Published private(set) var webhooks: [Webhook] = []
    @Published private(set) var knowledgeDocuments: [KnowledgeDocument] = []
    @Published private(set) var aiProviderConfigs: [AIProviderConfig] = []
    @Published private(set) var meetingRecords: [MeetingRecord] = []

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
        // Skip if we just saved locally (our own changes echoing back)
        guard !isLocalSaveInProgress else {
            return  // Silent skip - don't log every notification
        }

        // Throttle: Skip if we reloaded recently
        let timeSinceLastReload = Date().timeIntervalSince(lastReloadTime)
        guard timeSinceLastReload >= minimumReloadInterval else {
            return  // Silent skip - don't log throttled notifications
        }

        // Debounce: Cancel any pending reload and schedule a new one
        cloudSyncDebounceTask?.cancel()
        cloudSyncDebounceTask = Task { @MainActor in
            // Wait 500ms for notifications to settle
            try? await Task.sleep(nanoseconds: 500_000_000)

            guard !Task.isCancelled else { return }

            // Double-check throttle after debounce wait
            let timeSinceLastReload = Date().timeIntervalSince(self.lastReloadTime)
            guard timeSinceLastReload >= self.minimumReloadInterval else { return }

            self.lastReloadTime = Date()
            loadAllData()
            coreDataLog("Reloaded data after iCloud sync")
        }
    }

    /// Mark that we're about to save locally (to prevent reload echo)
    func beginLocalSave() {
        isLocalSaveInProgress = true
    }

    /// Mark that local save is complete
    func endLocalSave() {
        // Delay clearing the flag to let CloudKit notifications pass
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds - CloudKit can be slow
            isLocalSaveInProgress = false
        }
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
        loadMeetingRecords()
    }

    // MARK: - TranscriptionRecord CRUD

    private func loadTranscriptionHistory() {
        let request = TranscriptionRecordEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TranscriptionRecordEntity.timestamp, ascending: false)]

        do {
            let entities = try viewContext.fetch(request)
            transcriptionHistory = entities.compactMap { $0.toModel() }
        } catch {
            coreDataLog("Failed to load transcription history: \(error)", level: .error)
        }
    }

    func addTranscription(_ record: TranscriptionRecord) {
        beginLocalSave()
        let entity = TranscriptionRecordEntity(context: viewContext)
        entity.update(from: record)
        persistence.save()
        loadTranscriptionHistory()
        endLocalSave()
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
            coreDataLog("Failed to update transcription: \(error)", level: .error)
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
            coreDataLog("Failed to delete transcription: \(error)", level: .error)
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
            coreDataLog("Failed to clear history: \(error)", level: .error)
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
            coreDataLog("Failed to load contexts: \(error)", level: .error)
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
            coreDataLog("Failed to update context: \(error)", level: .error)
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
            coreDataLog("Failed to delete context: \(error)", level: .error)
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
            coreDataLog("Failed to load power modes: \(error)", level: .error)
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
            coreDataLog("Failed to update power mode: \(error)", level: .error)
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
            coreDataLog("Failed to delete power mode: \(error)", level: .error)
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
            coreDataLog("Failed to load custom templates: \(error)", level: .error)
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
            coreDataLog("Failed to update custom template: \(error)", level: .error)
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
            coreDataLog("Failed to delete custom template: \(error)", level: .error)
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
            coreDataLog("Failed to load vocabulary: \(error)", level: .error)
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
            coreDataLog("Failed to update vocabulary entry: \(error)", level: .error)
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
            coreDataLog("Failed to delete vocabulary entry: \(error)", level: .error)
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
            coreDataLog("Failed to load webhooks: \(error)", level: .error)
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
            coreDataLog("Failed to update webhook: \(error)", level: .error)
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
            coreDataLog("Failed to delete webhook: \(error)", level: .error)
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
            coreDataLog("Failed to load knowledge documents: \(error)", level: .error)
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
            coreDataLog("Failed to update knowledge document: \(error)", level: .error)
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
            coreDataLog("Failed to delete knowledge document: \(error)", level: .error)
        }
    }

    // MARK: - AIProviderConfig CRUD

    private func loadAIProviderConfigs() {
        let request = AIProviderConfigEntity.fetchRequest()

        do {
            let entities = try viewContext.fetch(request)
            aiProviderConfigs = entities.compactMap { $0.toModel() }
        } catch {
            coreDataLog("Failed to load AI provider configs: \(error)", level: .error)
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
            coreDataLog("Failed to update AI provider config: \(error)", level: .error)
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
            coreDataLog("Failed to delete AI provider config: \(error)", level: .error)
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

    // MARK: - MeetingRecord CRUD

    private func loadMeetingRecords() {
        let request = MeetingRecordEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MeetingRecordEntity.recordedAt, ascending: false)]

        do {
            let entities = try viewContext.fetch(request)
            meetingRecords = entities.compactMap { $0.toModel() }
        } catch {
            coreDataLog("Failed to load meeting records: \(error)", level: .error)
        }
    }

    func addMeetingRecord(_ record: MeetingRecord) {
        beginLocalSave()
        let entity = MeetingRecordEntity(context: viewContext)
        entity.update(from: record)
        persistence.save()
        loadMeetingRecords()
        endLocalSave()
    }

    func updateMeetingRecord(_ record: MeetingRecord) {
        let request = MeetingRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", record.id as CVarArg)

        do {
            if let entity = try viewContext.fetch(request).first {
                entity.update(from: record)
                persistence.save()
                loadMeetingRecords()
            } else {
                // Record doesn't exist, create it
                addMeetingRecord(record)
            }
        } catch {
            coreDataLog("Failed to update meeting record: \(error)", level: .error)
        }
    }

    func deleteMeetingRecord(id: UUID) {
        let request = MeetingRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            if let entity = try viewContext.fetch(request).first {
                viewContext.delete(entity)
                persistence.save()
                loadMeetingRecords()
            }
        } catch {
            coreDataLog("Failed to delete meeting record: \(error)", level: .error)
        }
    }

    func getMeetingRecord(id: UUID) -> MeetingRecord? {
        meetingRecords.first { $0.id == id }
    }

    /// Get meetings that need transcription (pending or failed)
    var pendingMeetingRecords: [MeetingRecord] {
        meetingRecords.filter { $0.status.canRetry }
    }

    /// Get completed meetings count
    var completedMeetingRecordsCount: Int {
        meetingRecords.filter { $0.status == .completed }.count
    }

    /// Get total meeting duration
    var totalMeetingDuration: TimeInterval {
        meetingRecords.reduce(0) { $0 + $1.duration }
    }

    /// Get total estimated cost from all meetings
    var totalMeetingCost: Double {
        meetingRecords.compactMap { $0.estimatedCost }.reduce(0, +)
    }
}
