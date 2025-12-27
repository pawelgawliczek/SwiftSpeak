//
//  AppAutoEnableTests.swift
//  SwiftSpeakTests
//
//  Tests for the App Auto-Enable feature including:
//  - Context matching by app ID and category
//  - Power Mode matching by app ID and category
//  - Manual selection precedence over auto-enable
//  - Specific app assignment precedence over category assignment
//

import Testing
import Foundation
@testable import SwiftSpeak

@Suite("App Auto-Enable Tests")
@MainActor
struct AppAutoEnableTests {

    // MARK: - Test Fixtures

    /// Creates a test context with the given app assignment
    func makeContext(
        id: UUID = UUID(),
        name: String,
        appIds: Set<String> = [],
        categories: Set<AppCategory> = []
    ) -> ConversationContext {
        ConversationContext(
            id: id,
            name: name,
            icon: "person.circle",
            color: .blue,
            description: "Test context",
            appAssignment: AppAssignment(
                assignedAppIds: appIds,
                assignedCategories: categories
            )
        )
    }

    /// Creates a test power mode with the given app assignment
    func makePowerMode(
        id: UUID = UUID(),
        name: String,
        appIds: Set<String> = [],
        categories: Set<AppCategory> = []
    ) -> PowerMode {
        PowerMode(
            id: id,
            name: name,
            icon: "bolt.fill",
            instruction: "Test instruction",
            appAssignment: AppAssignment(
                assignedAppIds: appIds,
                assignedCategories: categories
            )
        )
    }

    // MARK: - Context Matching Tests

    @Test("Context matches by specific app ID")
    func contextMatchesByAppId() {
        let settings = SharedSettings.shared
        let originalContexts = settings.contexts

        let whatsAppId = "net.whatsapp.WhatsApp"
        let testContext = makeContext(
            name: "Messaging",
            appIds: [whatsAppId]
        )

        settings.contexts = [testContext]

        let matchedContext = settings.contextForApp(bundleId: whatsAppId)
        #expect(matchedContext?.id == testContext.id)

        // Cleanup
        settings.contexts = originalContexts
    }

    @Test("Context matches by category")
    func contextMatchesByCategory() {
        let settings = SharedSettings.shared
        let originalContexts = settings.contexts

        let testContext = makeContext(
            name: "Social",
            categories: [AppCategory.social]
        )

        settings.contexts = [testContext]

        // Facebook is in the social category by default
        let facebookId = "com.facebook.Facebook"
        let matchedContext = settings.contextForApp(bundleId: facebookId)
        #expect(matchedContext?.id == testContext.id)

        // Cleanup
        settings.contexts = originalContexts
    }

    @Test("Context returns nil when no match")
    func contextReturnsNilWhenNoMatch() {
        let settings = SharedSettings.shared
        let originalContexts = settings.contexts

        let testContext = makeContext(
            name: "Work",
            appIds: ["com.example.SomeApp"],
            categories: [AppCategory.work]
        )

        settings.contexts = [testContext]

        // Netflix is in entertainment, not work
        let netflixId = "com.netflix.Netflix"
        let matchedContext = settings.contextForApp(bundleId: netflixId)
        #expect(matchedContext == nil)

        // Cleanup
        settings.contexts = originalContexts
    }

    @Test("Specific app ID takes precedence over category for context")
    func specificAppPrecedenceOverCategoryForContext() {
        let settings = SharedSettings.shared
        let originalContexts = settings.contexts

        let slackId = "com.tinyspeck.chatlyio" // Slack
        let specificContextId = UUID()
        let categoryContextId = UUID()

        // Create two contexts: one with specific app, one with category
        let specificContext = makeContext(
            id: specificContextId,
            name: "Slack Specific",
            appIds: [slackId]
        )
        let categoryContext = makeContext(
            id: categoryContextId,
            name: "Work Category",
            categories: [AppCategory.work]
        )

        // Put category context first to ensure specific app still wins
        settings.contexts = [categoryContext, specificContext]

        let matchedContext = settings.contextForApp(bundleId: slackId)
        #expect(matchedContext?.id == specificContextId)

        // Cleanup
        settings.contexts = originalContexts
    }

    // MARK: - Power Mode Matching Tests

    @Test("Power Mode matches by specific app ID")
    func powerModeMatchesByAppId() {
        let settings = SharedSettings.shared
        let originalPowerModes = settings.powerModes

        let notesAppId = "com.apple.mobilenotes"
        let testMode = makePowerMode(
            name: "Note Assistant",
            appIds: [notesAppId]
        )

        settings.powerModes = [testMode]

        let matchedMode = settings.powerModeForApp(bundleId: notesAppId)
        #expect(matchedMode?.id == testMode.id)

        // Cleanup
        settings.powerModes = originalPowerModes
    }

    @Test("Power Mode matches by category")
    func powerModeMatchesByCategory() {
        let settings = SharedSettings.shared
        let originalPowerModes = settings.powerModes

        let testMode = makePowerMode(
            name: "Email Assistant",
            categories: [AppCategory.email]
        )

        settings.powerModes = [testMode]

        // Gmail is in email category
        let gmailId = "com.google.Gmail"
        let matchedMode = settings.powerModeForApp(bundleId: gmailId)
        #expect(matchedMode?.id == testMode.id)

        // Cleanup
        settings.powerModes = originalPowerModes
    }

    @Test("Power Mode returns nil when no match")
    func powerModeReturnsNilWhenNoMatch() {
        let settings = SharedSettings.shared
        let originalPowerModes = settings.powerModes

        let testMode = makePowerMode(
            name: "Work Mode",
            categories: [AppCategory.work]
        )

        settings.powerModes = [testMode]

        // Instagram is in social, not work
        let instagramId = "com.burbn.instagram"
        let matchedMode = settings.powerModeForApp(bundleId: instagramId)
        #expect(matchedMode == nil)

        // Cleanup
        settings.powerModes = originalPowerModes
    }

    // MARK: - Manual Selection Precedence Tests

    @Test("Manual context selection takes precedence over app auto-enable")
    func manualContextPrecedence() {
        let settings = SharedSettings.shared
        let originalContexts = settings.contexts
        let originalActiveContextId = settings.activeContextId

        let whatsAppId = "net.whatsapp.WhatsApp"
        let autoContextId = UUID()
        let manualContextId = UUID()

        // Auto-enable context for WhatsApp
        let autoContext = makeContext(
            id: autoContextId,
            name: "Messaging Auto",
            appIds: [whatsAppId]
        )
        // Manually selected context (formal work context)
        let manualContext = makeContext(
            id: manualContextId,
            name: "Formal Work"
        )

        settings.contexts = [autoContext, manualContext]

        // Set manual selection
        settings.activeContextId = manualContextId

        // Manual selection should take precedence
        let effectiveContext = settings.effectiveContextForApp(bundleId: whatsAppId)
        #expect(effectiveContext?.id == manualContextId)

        // Cleanup
        settings.contexts = originalContexts
        settings.activeContextId = originalActiveContextId
    }

    @Test("Clearing manual selection falls back to app auto-enable")
    func clearingManualSelectionFallsBackToAutoEnable() {
        let settings = SharedSettings.shared
        let originalContexts = settings.contexts
        let originalActiveContextId = settings.activeContextId

        let whatsAppId = "net.whatsapp.WhatsApp"
        let autoContextId = UUID()
        let manualContextId = UUID()

        let autoContext = makeContext(
            id: autoContextId,
            name: "Messaging Auto",
            appIds: [whatsAppId]
        )
        let manualContext = makeContext(
            id: manualContextId,
            name: "Formal Work"
        )

        settings.contexts = [autoContext, manualContext]

        // Start with manual selection
        settings.activeContextId = manualContextId
        #expect(settings.effectiveContextForApp(bundleId: whatsAppId)?.id == manualContextId)

        // Clear manual selection
        settings.clearManualContextSelection()

        // Should now fall back to auto-enable
        let effectiveContext = settings.effectiveContextForApp(bundleId: whatsAppId)
        #expect(effectiveContext?.id == autoContextId)

        // Cleanup
        settings.contexts = originalContexts
        settings.activeContextId = originalActiveContextId
    }

    @Test("Manual Power Mode selection takes precedence over app auto-enable")
    func manualPowerModePrecedence() {
        let settings = SharedSettings.shared
        let originalPowerModes = settings.powerModes

        let gmailId = "com.google.Gmail"
        let autoModeId = UUID()
        let manualModeId = UUID()

        // Auto-enable power mode for email
        let autoMode = makePowerMode(
            id: autoModeId,
            name: "Email Assistant",
            categories: [AppCategory.email]
        )
        // Manually selected power mode
        let manualMode = makePowerMode(
            id: manualModeId,
            name: "Creative Writer"
        )

        settings.powerModes = [autoMode, manualMode]

        // Manual selection should take precedence
        let effectiveMode = settings.effectivePowerModeForApp(
            bundleId: gmailId,
            selectedPowerModeId: manualModeId
        )
        #expect(effectiveMode?.id == manualModeId)

        // Cleanup
        settings.powerModes = originalPowerModes
    }

    @Test("No manual Power Mode selection uses app auto-enable")
    func noManualPowerModeUsesAutoEnable() {
        let settings = SharedSettings.shared
        let originalPowerModes = settings.powerModes

        let gmailId = "com.google.Gmail"
        let autoModeId = UUID()

        let autoMode = makePowerMode(
            id: autoModeId,
            name: "Email Assistant",
            categories: [AppCategory.email]
        )

        settings.powerModes = [autoMode]

        // No manual selection (nil)
        let effectiveMode = settings.effectivePowerModeForApp(
            bundleId: gmailId,
            selectedPowerModeId: nil
        )
        #expect(effectiveMode?.id == autoModeId)

        // Cleanup
        settings.powerModes = originalPowerModes
    }

    // MARK: - Edge Cases

    @Test("Unknown app returns nil for both context and power mode")
    func unknownAppReturnsNil() {
        let settings = SharedSettings.shared
        let originalContexts = settings.contexts
        let originalPowerModes = settings.powerModes

        let testContext = makeContext(
            name: "Test",
            appIds: ["com.example.App"]
        )
        let testMode = makePowerMode(
            name: "Test",
            appIds: ["com.example.App"]
        )

        settings.contexts = [testContext]
        settings.powerModes = [testMode]

        let unknownBundleId = "com.completely.unknown.app"

        #expect(settings.contextForApp(bundleId: unknownBundleId) == nil)
        #expect(settings.powerModeForApp(bundleId: unknownBundleId) == nil)

        // Cleanup
        settings.contexts = originalContexts
        settings.powerModes = originalPowerModes
    }

    @Test("App with user-overridden category uses overridden category for matching")
    func userCategoryOverrideAffectsMatching() {
        let settings = SharedSettings.shared
        let originalContexts = settings.contexts
        let originalOverrides = settings.userAppCategoryOverrides

        // WhatsApp is in .messaging category by default
        let whatsAppId = "net.whatsapp.WhatsApp"

        let workContext = makeContext(
            name: "Work",
            categories: [AppCategory.work]
        )
        let messagingContext = makeContext(
            name: "Messaging",
            categories: [AppCategory.messaging]
        )

        settings.contexts = [workContext, messagingContext]

        // Without override, WhatsApp matches messaging
        let beforeOverride = settings.contextForApp(bundleId: whatsAppId)
        #expect(beforeOverride?.name == "Messaging")

        // Override WhatsApp to work category
        settings.setAppCategoryOverride(bundleId: whatsAppId, category: AppCategory.work)

        // Now WhatsApp should match work context
        let afterOverride = settings.contextForApp(bundleId: whatsAppId)
        #expect(afterOverride?.name == "Work")

        // Cleanup
        settings.contexts = originalContexts
        settings.userAppCategoryOverrides = originalOverrides
    }

    @Test("Empty app assignment matches nothing")
    func emptyAppAssignmentMatchesNothing() {
        let settings = SharedSettings.shared
        let originalContexts = settings.contexts

        let emptyContext = makeContext(
            name: "Empty Assignment",
            appIds: [],
            categories: []
        )

        settings.contexts = [emptyContext]

        // Any app should not match
        #expect(settings.contextForApp(bundleId: "com.any.app") == nil)
        #expect(settings.contextForApp(bundleId: "net.whatsapp.WhatsApp") == nil)

        // Cleanup
        settings.contexts = originalContexts
    }

    @Test("Multiple contexts: first match wins")
    func multipleContextsFirstMatchWins() {
        let settings = SharedSettings.shared
        let originalContexts = settings.contexts

        let firstContextId = UUID()
        let secondContextId = UUID()

        // Both contexts match social category
        let firstContext = makeContext(
            id: firstContextId,
            name: "First Social Context",
            categories: [AppCategory.social]
        )
        let secondContext = makeContext(
            id: secondContextId,
            name: "Second Social Context",
            categories: [AppCategory.social]
        )

        settings.contexts = [firstContext, secondContext]

        // Facebook is social - should match first context
        let facebookId = "com.facebook.Facebook"
        let matchedContext = settings.contextForApp(bundleId: facebookId)
        #expect(matchedContext?.id == firstContextId)

        // Cleanup
        settings.contexts = originalContexts
    }
}
