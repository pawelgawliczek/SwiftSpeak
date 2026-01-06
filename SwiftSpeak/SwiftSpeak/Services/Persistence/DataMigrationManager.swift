//
//  DataMigrationManager.swift
//  SwiftSpeak
//
//  Handles one-time migration from UserDefaults to Core Data.
//  Runs on first launch after update, preserves all existing user data.
//

import CoreData
import Foundation
import SwiftSpeakCore

/// Manages migration of existing UserDefaults data to Core Data.
/// Runs once per device, tracks migration status to prevent re-running.
@MainActor
final class DataMigrationManager {

    // MARK: - Singleton

    static let shared = DataMigrationManager()

    // MARK: - Properties

    private let migrationKey = "CoreDataMigrationCompleted_v1"

    private var defaults: UserDefaults? {
        #if os(iOS)
        return UserDefaults(suiteName: "group.pawelgawliczek.swiftspeak")
        #else
        return UserDefaults.standard
        #endif
    }

    // MARK: - Migration Status

    var hasMigrated: Bool {
        defaults?.bool(forKey: migrationKey) ?? false
    }

    private func markMigrationComplete() {
        defaults?.set(true, forKey: migrationKey)
        appLog("Data migration marked as complete", category: "Migration")
    }

    // MARK: - Main Migration

    /// Performs migration if needed. Call this on app launch.
    func migrateIfNeeded() {
        guard !hasMigrated else {
            appLog("Migration already completed, skipping", category: "Migration", level: .debug)
            return
        }

        appLog("Starting data migration from UserDefaults to Core Data...", category: "Migration")

        let startTime = Date()

        // Migrate each data type
        migrateTranscriptionHistory()
        migrateContexts()
        migratePowerModes()
        migrateCustomTemplates()
        migrateVocabulary()
        migrateWebhooks()
        migrateKnowledgeDocuments()
        migrateAIProviderConfigs()
        migrateGlobalSettings()

        let duration = Date().timeIntervalSince(startTime)
        appLog("Data migration completed in \(String(format: "%.2f", duration))s", category: "Migration")

        markMigrationComplete()
    }

    // MARK: - Individual Migrations

    private func migrateTranscriptionHistory() {
        guard let data = defaults?.data(forKey: "transcriptionHistory"),
              let records = try? JSONDecoder().decode([TranscriptionRecord].self, from: data) else {
            appLog("No transcription history to migrate", category: "Migration", level: .debug)
            return
        }

        let coreData = CoreDataManager.shared
        for record in records {
            coreData.addTranscription(record)
        }

        appLog("Migrated \(records.count) transcription records", category: "Migration")
    }

    private func migrateContexts() {
        guard let data = defaults?.data(forKey: "contexts"),
              let contexts = try? JSONDecoder().decode([ConversationContext].self, from: data) else {
            appLog("No contexts to migrate (will use presets)", category: "Migration", level: .debug)
            return
        }

        let coreData = CoreDataManager.shared
        for context in contexts {
            coreData.addContext(context)
        }

        appLog("Migrated \(contexts.count) contexts", category: "Migration")
    }

    private func migratePowerModes() {
        guard let data = defaults?.data(forKey: "powerModes"),
              let powerModes = try? JSONDecoder().decode([PowerMode].self, from: data) else {
            appLog("No power modes to migrate (will use presets)", category: "Migration", level: .debug)
            return
        }

        let coreData = CoreDataManager.shared
        for powerMode in powerModes {
            coreData.addPowerMode(powerMode)
        }

        appLog("Migrated \(powerModes.count) power modes", category: "Migration")
    }

    private func migrateCustomTemplates() {
        guard let data = defaults?.data(forKey: "customTemplates"),
              let templates = try? JSONDecoder().decode([CustomTemplate].self, from: data) else {
            appLog("No custom templates to migrate", category: "Migration", level: .debug)
            return
        }

        let coreData = CoreDataManager.shared
        for template in templates {
            coreData.addCustomTemplate(template)
        }

        appLog("Migrated \(templates.count) custom templates", category: "Migration")
    }

    private func migrateVocabulary() {
        guard let data = defaults?.data(forKey: "vocabulary"),
              let entries = try? JSONDecoder().decode([VocabularyEntry].self, from: data) else {
            appLog("No vocabulary to migrate", category: "Migration", level: .debug)
            return
        }

        let coreData = CoreDataManager.shared
        for entry in entries {
            coreData.addVocabularyEntry(entry)
        }

        appLog("Migrated \(entries.count) vocabulary entries", category: "Migration")
    }

    private func migrateWebhooks() {
        guard let data = defaults?.data(forKey: "webhooks"),
              let webhooks = try? JSONDecoder().decode([Webhook].self, from: data) else {
            appLog("No webhooks to migrate", category: "Migration", level: .debug)
            return
        }

        let coreData = CoreDataManager.shared
        for webhook in webhooks {
            coreData.addWebhook(webhook)
        }

        appLog("Migrated \(webhooks.count) webhooks", category: "Migration")
    }

    private func migrateKnowledgeDocuments() {
        guard let data = defaults?.data(forKey: "knowledgeDocuments"),
              let documents = try? JSONDecoder().decode([KnowledgeDocument].self, from: data) else {
            appLog("No knowledge documents to migrate", category: "Migration", level: .debug)
            return
        }

        let coreData = CoreDataManager.shared
        for document in documents {
            coreData.addKnowledgeDocument(document)
        }

        appLog("Migrated \(documents.count) knowledge documents", category: "Migration")
    }

    private func migrateAIProviderConfigs() {
        guard let data = defaults?.data(forKey: "configuredAIProviders"),
              let configs = try? JSONDecoder().decode([AIProviderConfig].self, from: data) else {
            appLog("No AI provider configs to migrate", category: "Migration", level: .debug)
            return
        }

        let coreData = CoreDataManager.shared
        for config in configs {
            coreData.addAIProviderConfig(config)
        }

        appLog("Migrated \(configs.count) AI provider configs", category: "Migration")
    }

    private func migrateGlobalSettings() {
        // Global settings remain in UserDefaults/iCloud KV store for now
        // as they're simple key-value pairs that don't need CloudKit sync
        appLog("Global settings remain in UserDefaults (no migration needed)", category: "Migration", level: .debug)
    }

    // MARK: - Reset Migration (for testing)

    #if DEBUG
    func resetMigration() {
        defaults?.removeObject(forKey: migrationKey)
        appLog("Migration status reset", category: "Migration")
    }
    #endif
}
