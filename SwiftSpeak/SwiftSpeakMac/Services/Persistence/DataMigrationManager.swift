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

// MARK: - Platform-aware Logging

#if os(iOS)
private func migrationLog(_ message: String, level: LogEntry.LogLevel = .info) {
    appLog(message, category: "Migration", level: level)
}
#elseif os(macOS)
private func migrationLog(_ message: String, level: MacLogLevel = .info) {
    macLog(message, category: "Migration", level: level)
}
#endif

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
        migrationLog("Data migration marked as complete")
    }

    // MARK: - Main Migration

    /// Performs migration if needed. Call this on app launch.
    func migrateIfNeeded() {
        guard !hasMigrated else {
            migrationLog("Migration already completed, skipping", level: .debug)
            return
        }

        migrationLog("Starting data migration from UserDefaults to Core Data...")

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
        migrationLog("Data migration completed in \(String(format: "%.2f", duration))s")

        markMigrationComplete()
    }

    // MARK: - Individual Migrations

    private func migrateTranscriptionHistory() {
        guard let data = defaults?.data(forKey: "transcriptionHistory"),
              let records = try? JSONDecoder().decode([TranscriptionRecord].self, from: data) else {
            migrationLog("No transcription history to migrate", level: .debug)
            return
        }

        let coreData = CoreDataManager.shared
        for record in records {
            coreData.addTranscription(record)
        }

        migrationLog("Migrated \(records.count) transcription records")
    }

    private func migrateContexts() {
        guard let data = defaults?.data(forKey: "contexts"),
              let contexts = try? JSONDecoder().decode([ConversationContext].self, from: data) else {
            migrationLog("No contexts to migrate (will use presets)", level: .debug)
            return
        }

        let coreData = CoreDataManager.shared
        for context in contexts {
            coreData.addContext(context)
        }

        migrationLog("Migrated \(contexts.count) contexts")
    }

    private func migratePowerModes() {
        guard let data = defaults?.data(forKey: "powerModes"),
              let powerModes = try? JSONDecoder().decode([PowerMode].self, from: data) else {
            migrationLog("No power modes to migrate (will use presets)", level: .debug)
            return
        }

        let coreData = CoreDataManager.shared
        for powerMode in powerModes {
            coreData.addPowerMode(powerMode)
        }

        migrationLog("Migrated \(powerModes.count) power modes")
    }

    private func migrateCustomTemplates() {
        guard let data = defaults?.data(forKey: "customTemplates"),
              let templates = try? JSONDecoder().decode([CustomTemplate].self, from: data) else {
            migrationLog("No custom templates to migrate", level: .debug)
            return
        }

        let coreData = CoreDataManager.shared
        for template in templates {
            coreData.addCustomTemplate(template)
        }

        migrationLog("Migrated \(templates.count) custom templates")
    }

    private func migrateVocabulary() {
        guard let data = defaults?.data(forKey: "vocabulary"),
              let entries = try? JSONDecoder().decode([VocabularyEntry].self, from: data) else {
            migrationLog("No vocabulary to migrate", level: .debug)
            return
        }

        let coreData = CoreDataManager.shared
        for entry in entries {
            coreData.addVocabularyEntry(entry)
        }

        migrationLog("Migrated \(entries.count) vocabulary entries")
    }

    private func migrateWebhooks() {
        guard let data = defaults?.data(forKey: "webhooks"),
              let webhooks = try? JSONDecoder().decode([Webhook].self, from: data) else {
            migrationLog("No webhooks to migrate", level: .debug)
            return
        }

        let coreData = CoreDataManager.shared
        for webhook in webhooks {
            coreData.addWebhook(webhook)
        }

        migrationLog("Migrated \(webhooks.count) webhooks")
    }

    private func migrateKnowledgeDocuments() {
        guard let data = defaults?.data(forKey: "knowledgeDocuments"),
              let documents = try? JSONDecoder().decode([KnowledgeDocument].self, from: data) else {
            migrationLog("No knowledge documents to migrate", level: .debug)
            return
        }

        let coreData = CoreDataManager.shared
        for document in documents {
            coreData.addKnowledgeDocument(document)
        }

        migrationLog("Migrated \(documents.count) knowledge documents")
    }

    private func migrateAIProviderConfigs() {
        guard let data = defaults?.data(forKey: "configuredAIProviders"),
              let configs = try? JSONDecoder().decode([AIProviderConfig].self, from: data) else {
            migrationLog("No AI provider configs to migrate", level: .debug)
            return
        }

        let coreData = CoreDataManager.shared
        for config in configs {
            coreData.addAIProviderConfig(config)
        }

        migrationLog("Migrated \(configs.count) AI provider configs")
    }

    private func migrateGlobalSettings() {
        // Global settings remain in UserDefaults/iCloud KV store for now
        // as they're simple key-value pairs that don't need CloudKit sync
        migrationLog("Global settings remain in UserDefaults (no migration needed)", level: .debug)
    }

    // MARK: - Reset Migration (for testing)

    #if DEBUG
    func resetMigration() {
        defaults?.removeObject(forKey: migrationKey)
        migrationLog("Migration status reset")
    }
    #endif
}
