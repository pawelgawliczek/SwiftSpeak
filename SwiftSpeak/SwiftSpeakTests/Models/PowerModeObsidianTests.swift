//
//  PowerModeObsidianTests.swift
//  SwiftSpeakTests
//
//  Tests for PowerMode Obsidian integration properties
//  Phase 3: Obsidian Vault Integration
//

import Testing
import Foundation
@testable import SwiftSpeak
import SwiftSpeakCore

// Use typealias to disambiguate - use SwiftSpeakCore types
private typealias ActionConfig = SwiftSpeakCore.ObsidianActionConfig
private typealias Action = SwiftSpeakCore.ObsidianAction
private typealias PM = SwiftSpeakCore.PowerMode

@Suite("PowerMode Obsidian Integration Tests")
struct PowerModeObsidianTests {

    // MARK: - Initialization

    @Test("PowerMode initializes with default Obsidian properties")
    func testDefaultObsidianProperties() {
        let powerMode = PM(
            name: "Test Mode",
            instruction: "Test instruction"
        )

        #expect(powerMode.obsidianVaultIds.isEmpty)
        #expect(powerMode.includeWindowContext == false)
        #expect(powerMode.maxObsidianChunks == 3)
        #expect(powerMode.obsidianAction == nil)
    }

    @Test("PowerMode initializes with custom Obsidian properties")
    func testCustomObsidianProperties() {
        let vaultId = UUID()
        let action = ActionConfig(
            action: .appendToDaily,
            targetVaultId: vaultId,
            autoExecute: true
        )

        let powerMode = PM(
            name: "Test Mode",
            instruction: "Test instruction",
            obsidianVaultIds: [vaultId],
            includeWindowContext: true,
            maxObsidianChunks: 5,
            obsidianAction: action
        )

        #expect(powerMode.obsidianVaultIds == [vaultId])
        #expect(powerMode.includeWindowContext == true)
        #expect(powerMode.maxObsidianChunks == 5)
        #expect(powerMode.obsidianAction == action)
    }

    // MARK: - Codable

    @Test("PowerMode encodes and decodes Obsidian properties")
    func testObsidianPropertiesCodable() throws {
        let vaultId = UUID()
        let action = ActionConfig(
            action: .createNote,
            targetVaultId: vaultId,
            targetNoteName: "My Note",
            autoExecute: false
        )

        let original = PM(
            name: "Test Mode",
            instruction: "Test instruction",
            obsidianVaultIds: [vaultId],
            includeWindowContext: true,
            maxObsidianChunks: 7,
            obsidianAction: action
        )

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PM.self, from: data)

        // Verify
        #expect(decoded.obsidianVaultIds == original.obsidianVaultIds)
        #expect(decoded.includeWindowContext == original.includeWindowContext)
        #expect(decoded.maxObsidianChunks == original.maxObsidianChunks)
        #expect(decoded.obsidianAction == original.obsidianAction)
    }

    @Test("PowerMode backward compatible with missing Obsidian properties")
    func testBackwardCompatibility() throws {
        // Create JSON without Obsidian properties (simulating old data)
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "name": "Old Mode",
            "icon": "bolt.fill",
            "iconColor": "orange",
            "iconBackgroundColor": "orange",
            "instruction": "Old instruction",
            "outputFormat": "",
            "createdAt": \(Date().timeIntervalSince1970),
            "updatedAt": \(Date().timeIntervalSince1970),
            "usageCount": 0,
            "memoryEnabled": false,
            "memoryLimit": 2000,
            "knowledgeDocumentIds": [],
            "ragConfiguration": {
                "chunkingStrategy": "semantic",
                "maxChunkTokens": 500,
                "overlapTokens": 50,
                "maxContextChunks": 5,
                "similarityThreshold": 0.7,
                "embeddingModel": "text-embedding-3-small"
            },
            "isArchived": false,
            "appAssignment": {
                "mode": "none"
            },
            "enabledWebhookIds": [],
            "aiAutocorrectEnabled": false,
            "enterSendsMessage": true,
            "enterRunsContext": false
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let powerMode = try decoder.decode(PM.self, from: data)

        // Verify defaults are applied
        #expect(powerMode.obsidianVaultIds.isEmpty)
        #expect(powerMode.includeWindowContext == false)
        #expect(powerMode.maxObsidianChunks == 3)
        #expect(powerMode.obsidianAction == nil)
    }

    // MARK: - ObsidianActionConfig

    @Test("ObsidianActionConfig encodes and decodes correctly")
    func testActionConfigCodable() throws {
        let vaultId = UUID()
        let original = ActionConfig(
            action: .appendToNote,
            targetVaultId: vaultId,
            targetNoteName: "Work Notes",
            autoExecute: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ActionConfig.self, from: data)

        #expect(decoded.action == original.action)
        #expect(decoded.targetVaultId == original.targetVaultId)
        #expect(decoded.targetNoteName == original.targetNoteName)
        #expect(decoded.autoExecute == original.autoExecute)
    }

    // MARK: - ObsidianAction

    @Test("ObsidianAction has correct display names")
    func testActionDisplayNames() {
        #expect(Action.appendToDaily.displayName == "Append to Daily Note")
        #expect(Action.appendToNote.displayName == "Append to Note")
        #expect(Action.createNote.displayName == "Create New Note")
        #expect(Action.none.displayName == "No Action")
    }

    @Test("ObsidianAction has correct icons")
    func testActionIcons() {
        #expect(Action.appendToDaily.icon == "calendar.badge.plus")
        #expect(Action.appendToNote.icon == "doc.badge.plus")
        #expect(Action.createNote.icon == "doc.fill.badge.plus")
        #expect(Action.none.icon == "minus.circle")
    }

    @Test("ObsidianAction all cases are tested")
    func testAllActionCases() {
        let allCases = Action.allCases
        #expect(allCases.count == 4)
        #expect(allCases.contains(.appendToDaily))
        #expect(allCases.contains(.appendToNote))
        #expect(allCases.contains(.createNote))
        #expect(allCases.contains(.none))
    }

    // MARK: - Validation

    @Test("Max Obsidian chunks stays within valid range")
    func testMaxChunksValidation() {
        // Test minimum
        var powerMode = PM(
            name: "Test",
            instruction: "Test",
            maxObsidianChunks: 1
        )
        #expect(powerMode.maxObsidianChunks >= 1)

        // Test maximum
        powerMode = PM(
            name: "Test",
            instruction: "Test",
            maxObsidianChunks: 10
        )
        #expect(powerMode.maxObsidianChunks <= 10)

        // Test default
        powerMode = PM(
            name: "Test",
            instruction: "Test"
        )
        #expect(powerMode.maxObsidianChunks == 3)
    }
}
