//
//  KeyboardActionTests.swift
//  SwiftSpeakTests
//
//  Extensive tests for the unified keyboard action system.
//  This is critical functionality for keyboard-to-app communication.
//

import Testing
import Foundation
@testable import SwiftSpeak

// MARK: - KeyboardActionType Tests

struct KeyboardActionTypeTests {

    @Test("All action types have valid raw values")
    func allActionTypesHaveValidRawValues() {
        #expect(KeyboardActionType.transcription.rawValue == "transcription")
        #expect(KeyboardActionType.edit.rawValue == "edit")
        #expect(KeyboardActionType.aiProcess.rawValue == "aiProcess")
        #expect(KeyboardActionType.prediction.rawValue == "prediction")
        #expect(KeyboardActionType.enableSwiftLink.rawValue == "enableSwiftLink")
    }

    @Test("All action types have display names")
    func allActionTypesHaveDisplayNames() {
        for type in KeyboardActionType.allCases {
            #expect(!type.displayName.isEmpty, "Display name should not be empty for \(type)")
        }
    }

    @Test("All action types have processing messages")
    func allActionTypesHaveProcessingMessages() {
        for type in KeyboardActionType.allCases {
            #expect(!type.processingMessage.isEmpty, "Processing message should not be empty for \(type)")
        }
    }

    @Test("All action types have completed messages")
    func allActionTypesHaveCompletedMessages() {
        for type in KeyboardActionType.allCases {
            #expect(!type.completedMessage.isEmpty, "Completed message should not be empty for \(type)")
        }
    }

    @Test("All action types have icons")
    func allActionTypesHaveIcons() {
        for type in KeyboardActionType.allCases {
            #expect(!type.icon.isEmpty, "Icon should not be empty for \(type)")
        }
    }

    @Test("RequiresSwiftLink returns correct values")
    func requiresSwiftLinkReturnsCorrectValues() {
        #expect(KeyboardActionType.transcription.requiresSwiftLink == true)
        #expect(KeyboardActionType.edit.requiresSwiftLink == true)
        #expect(KeyboardActionType.aiProcess.requiresSwiftLink == true)
        #expect(KeyboardActionType.prediction.requiresSwiftLink == true)
        #expect(KeyboardActionType.enableSwiftLink.requiresSwiftLink == false)
    }

    @Test("SupportsAutoReturn returns correct values")
    func supportsAutoReturnReturnsCorrectValues() {
        for type in KeyboardActionType.allCases {
            #expect(type.supportsAutoReturn == true, "All action types should support auto-return")
        }
    }

    @Test("Action type encoding and decoding")
    func actionTypeEncodingDecoding() throws {
        for type in KeyboardActionType.allCases {
            let encoded = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(KeyboardActionType.self, from: encoded)
            #expect(decoded == type)
        }
    }
}

// MARK: - KeyboardActionStatus Tests

struct KeyboardActionStatusTests {

    @Test("All statuses have valid raw values")
    func allStatusesHaveValidRawValues() {
        #expect(KeyboardActionStatus.pending.rawValue == "pending")
        #expect(KeyboardActionStatus.starting.rawValue == "starting")
        #expect(KeyboardActionStatus.recording.rawValue == "recording")
        #expect(KeyboardActionStatus.processing.rawValue == "processing")
        #expect(KeyboardActionStatus.streaming.rawValue == "streaming")
        #expect(KeyboardActionStatus.complete.rawValue == "complete")
        #expect(KeyboardActionStatus.error.rawValue == "error")
        #expect(KeyboardActionStatus.cancelled.rawValue == "cancelled")
    }

    @Test("IsActive returns correct values for active statuses")
    func isActiveForActiveStatuses() {
        #expect(KeyboardActionStatus.pending.isActive == true)
        #expect(KeyboardActionStatus.starting.isActive == true)
        #expect(KeyboardActionStatus.recording.isActive == true)
        #expect(KeyboardActionStatus.processing.isActive == true)
        #expect(KeyboardActionStatus.streaming.isActive == true)
    }

    @Test("IsActive returns correct values for inactive statuses")
    func isActiveForInactiveStatuses() {
        #expect(KeyboardActionStatus.complete.isActive == false)
        #expect(KeyboardActionStatus.error.isActive == false)
        #expect(KeyboardActionStatus.cancelled.isActive == false)
    }

    @Test("ShouldShowOverlay returns correct values")
    func shouldShowOverlayReturnsCorrectValues() {
        #expect(KeyboardActionStatus.starting.shouldShowOverlay == true)
        #expect(KeyboardActionStatus.recording.shouldShowOverlay == true)
        #expect(KeyboardActionStatus.processing.shouldShowOverlay == true)
        #expect(KeyboardActionStatus.streaming.shouldShowOverlay == true)

        #expect(KeyboardActionStatus.pending.shouldShowOverlay == false)
        #expect(KeyboardActionStatus.complete.shouldShowOverlay == false)
        #expect(KeyboardActionStatus.error.shouldShowOverlay == false)
        #expect(KeyboardActionStatus.cancelled.shouldShowOverlay == false)
    }

    @Test("Status encoding and decoding")
    func statusEncodingDecoding() throws {
        let statuses: [KeyboardActionStatus] = [.pending, .starting, .recording, .processing, .streaming, .complete, .error, .cancelled]
        for status in statuses {
            let encoded = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(KeyboardActionStatus.self, from: encoded)
            #expect(decoded == status)
        }
    }
}

// MARK: - KeyboardAction Model Tests

struct KeyboardActionModelTests {

    @Test("Default initializer creates action with correct defaults")
    func defaultInitializerCreatesActionWithCorrectDefaults() {
        let action = KeyboardAction(type: .transcription)

        #expect(action.type == .transcription)
        #expect(action.sourceAppURLScheme == nil)
        #expect(action.sourceAppBundleId == nil)
        #expect(action.sourceAppName == nil)
        #expect(action.autoReturnRequested == true)
        #expect(action.formattingMode == nil)
        #expect(action.translateEnabled == false)
        #expect(action.targetLanguage == nil)
        #expect(action.customTemplateId == nil)
        #expect(action.originalText == nil)
        #expect(action.textToProcess == nil)
        #expect(action.contextId == nil)
        #expect(action.contextName == nil)
        #expect(action.powerModeId == nil)
        #expect(action.powerModeName == nil)
        #expect(action.typingContext == nil)
        #expect(action.activeContextName == nil)
        #expect(action.activeContextId == nil)
    }

    @Test("Action has unique IDs")
    func actionHasUniqueIDs() {
        let action1 = KeyboardAction(type: .transcription)
        let action2 = KeyboardAction(type: .transcription)

        #expect(action1.id != action2.id)
    }

    @Test("Action timestamp is set to now")
    func actionTimestampIsSetToNow() {
        let before = Date()
        let action = KeyboardAction(type: .transcription)
        let after = Date()

        #expect(action.timestamp >= before)
        #expect(action.timestamp <= after)
    }

    @Test("Action is Identifiable")
    func actionIsIdentifiable() {
        let action = KeyboardAction(type: .transcription)
        let identifier: UUID = action.id
        #expect(identifier == action.id)
    }
}

// MARK: - KeyboardAction Convenience Initializers Tests

struct KeyboardActionConvenienceInitializerTests {

    @Test("Transcription action convenience initializer")
    func transcriptionActionConvenienceInitializer() {
        let action = KeyboardAction.transcription(
            mode: .email,
            translate: true,
            targetLanguage: .spanish,
            customTemplateId: UUID(),
            sourceApp: (urlScheme: "myapp://", bundleId: "com.example.app", name: "My App"),
            autoReturn: false
        )

        #expect(action.type == .transcription)
        #expect(action.formattingMode == .email)
        #expect(action.translateEnabled == true)
        #expect(action.targetLanguage == .spanish)
        #expect(action.customTemplateId != nil)
        #expect(action.sourceAppURLScheme == "myapp://")
        #expect(action.sourceAppBundleId == "com.example.app")
        #expect(action.sourceAppName == "My App")
        #expect(action.autoReturnRequested == false)
    }

    @Test("Transcription action with minimal parameters")
    func transcriptionActionMinimalParameters() {
        let action = KeyboardAction.transcription(mode: .raw)

        #expect(action.type == .transcription)
        #expect(action.formattingMode == .raw)
        #expect(action.translateEnabled == false)
        #expect(action.targetLanguage == nil)
        #expect(action.autoReturnRequested == true)
    }

    @Test("Edit action convenience initializer")
    func editActionConvenienceInitializer() {
        let originalText = "Hello world"
        let action = KeyboardAction.edit(
            originalText: originalText,
            mode: .email,
            sourceApp: (urlScheme: "messages://", bundleId: nil, name: nil),
            autoReturn: true
        )

        #expect(action.type == .edit)
        #expect(action.originalText == originalText)
        #expect(action.formattingMode == .email)
        #expect(action.sourceAppURLScheme == "messages://")
        #expect(action.autoReturnRequested == true)
    }

    @Test("AI process action convenience initializer with context")
    func aiProcessActionWithContext() {
        let contextId = UUID()
        let action = KeyboardAction.aiProcess(
            text: "Process this text",
            contextId: contextId,
            contextName: "Work Context",
            powerModeId: nil,
            powerModeName: nil,
            translate: true,
            targetLanguage: .french,
            sourceApp: nil,
            autoReturn: true
        )

        #expect(action.type == .aiProcess)
        #expect(action.textToProcess == "Process this text")
        #expect(action.contextId == contextId)
        #expect(action.contextName == "Work Context")
        #expect(action.powerModeId == nil)
        #expect(action.translateEnabled == true)
        #expect(action.targetLanguage == .french)
    }

    @Test("AI process action convenience initializer with power mode")
    func aiProcessActionWithPowerMode() {
        let powerModeId = UUID()
        let action = KeyboardAction.aiProcess(
            text: "Summarize this",
            contextId: nil,
            contextName: nil,
            powerModeId: powerModeId,
            powerModeName: "Summarizer",
            translate: false,
            targetLanguage: nil,
            sourceApp: nil,
            autoReturn: true
        )

        #expect(action.type == .aiProcess)
        #expect(action.textToProcess == "Summarize this")
        #expect(action.contextId == nil)
        #expect(action.powerModeId == powerModeId)
        #expect(action.powerModeName == "Summarizer")
    }

    @Test("Prediction action convenience initializer")
    func predictionActionConvenienceInitializer() {
        let contextId = UUID()
        let action = KeyboardAction.prediction(
            typingContext: "I would like to",
            activeContextId: contextId,
            activeContextName: "Work",
            sourceApp: (urlScheme: "slack://", bundleId: nil, name: nil),
            autoReturn: true
        )

        #expect(action.type == .prediction)
        #expect(action.typingContext == "I would like to")
        #expect(action.activeContextId == contextId)
        #expect(action.activeContextName == "Work")
        #expect(action.sourceAppURLScheme == "slack://")
    }

    @Test("Enable SwiftLink action convenience initializer")
    func enableSwiftLinkActionConvenienceInitializer() {
        let action = KeyboardAction.enableSwiftLink(
            sourceApp: (urlScheme: "notion://", bundleId: "com.notion", name: "Notion"),
            autoReturn: false
        )

        #expect(action.type == .enableSwiftLink)
        #expect(action.sourceAppURLScheme == "notion://")
        #expect(action.sourceAppBundleId == "com.notion")
        #expect(action.sourceAppName == "Notion")
        #expect(action.autoReturnRequested == false)
    }
}

// MARK: - KeyboardAction Encoding/Decoding Tests

struct KeyboardActionEncodingTests {

    @Test("Transcription action encoding and decoding")
    func transcriptionActionEncodingDecoding() throws {
        let original = KeyboardAction.transcription(
            mode: .email,
            translate: true,
            targetLanguage: .german,
            customTemplateId: nil,
            sourceApp: (urlScheme: "test://", bundleId: "com.test", name: "Test"),
            autoReturn: true
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KeyboardAction.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.type == original.type)
        #expect(decoded.formattingMode == original.formattingMode)
        #expect(decoded.translateEnabled == original.translateEnabled)
        #expect(decoded.targetLanguage == original.targetLanguage)
        #expect(decoded.sourceAppURLScheme == original.sourceAppURLScheme)
        #expect(decoded.autoReturnRequested == original.autoReturnRequested)
    }

    @Test("Edit action encoding and decoding")
    func editActionEncodingDecoding() throws {
        let original = KeyboardAction.edit(
            originalText: "Test text to edit",
            mode: .formal,
            sourceApp: nil,
            autoReturn: true
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KeyboardAction.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.type == original.type)
        #expect(decoded.originalText == original.originalText)
        #expect(decoded.formattingMode == original.formattingMode)
    }

    @Test("AI process action encoding and decoding")
    func aiProcessActionEncodingDecoding() throws {
        let contextId = UUID()
        let original = KeyboardAction.aiProcess(
            text: "Process this",
            contextId: contextId,
            contextName: "Work",
            powerModeId: nil,
            powerModeName: nil,
            translate: true,
            targetLanguage: .japanese,
            sourceApp: nil,
            autoReturn: true
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KeyboardAction.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.type == original.type)
        #expect(decoded.textToProcess == original.textToProcess)
        #expect(decoded.contextId == original.contextId)
        #expect(decoded.contextName == original.contextName)
        #expect(decoded.translateEnabled == original.translateEnabled)
        #expect(decoded.targetLanguage == original.targetLanguage)
    }

    @Test("Prediction action encoding and decoding")
    func predictionActionEncodingDecoding() throws {
        let contextId = UUID()
        let original = KeyboardAction.prediction(
            typingContext: "Hello, I would like to",
            activeContextId: contextId,
            activeContextName: "Personal",
            sourceApp: nil,
            autoReturn: true
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KeyboardAction.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.type == original.type)
        #expect(decoded.typingContext == original.typingContext)
        #expect(decoded.activeContextId == original.activeContextId)
        #expect(decoded.activeContextName == original.activeContextName)
    }

    @Test("Enable SwiftLink action encoding and decoding")
    func enableSwiftLinkActionEncodingDecoding() throws {
        let original = KeyboardAction.enableSwiftLink(
            sourceApp: (urlScheme: "whatsapp://", bundleId: "com.whatsapp", name: "WhatsApp"),
            autoReturn: true
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KeyboardAction.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.type == original.type)
        #expect(decoded.sourceAppURLScheme == original.sourceAppURLScheme)
        #expect(decoded.sourceAppBundleId == original.sourceAppBundleId)
        #expect(decoded.sourceAppName == original.sourceAppName)
    }

    @Test("All action types can be encoded and decoded")
    func allActionTypesCanBeEncodedAndDecoded() throws {
        let actions: [KeyboardAction] = [
            KeyboardAction.transcription(mode: .raw),
            KeyboardAction.edit(originalText: "test"),
            KeyboardAction.aiProcess(text: "test", contextId: nil, contextName: nil, powerModeId: nil, powerModeName: nil, translate: false, targetLanguage: nil, sourceApp: nil, autoReturn: true),
            KeyboardAction.prediction(typingContext: "test", activeContextId: nil, activeContextName: nil, sourceApp: nil, autoReturn: true),
            KeyboardAction.enableSwiftLink(sourceApp: nil, autoReturn: true)
        ]

        for action in actions {
            let encoded = try JSONEncoder().encode(action)
            let decoded = try JSONDecoder().decode(KeyboardAction.self, from: encoded)
            #expect(decoded.type == action.type, "Failed for action type: \(action.type)")
            #expect(decoded.id == action.id, "ID mismatch for action type: \(action.type)")
        }
    }
}

// MARK: - KeyboardActionResult Tests

struct KeyboardActionResultTests {

    @Test("Result initializer creates result with correct values")
    func resultInitializerCreatesResultWithCorrectValues() {
        let actionId = UUID()
        let result = KeyboardActionResult(
            actionId: actionId,
            type: .transcription,
            status: .complete,
            resultText: "Transcribed text",
            predictions: nil,
            errorMessage: nil,
            duration: 2.5,
            estimatedCost: 0.001
        )

        #expect(result.actionId == actionId)
        #expect(result.type == .transcription)
        #expect(result.status == .complete)
        #expect(result.resultText == "Transcribed text")
        #expect(result.predictions == nil)
        #expect(result.errorMessage == nil)
        #expect(result.duration == 2.5)
        #expect(result.estimatedCost == 0.001)
    }

    @Test("IsSuccess returns true for successful completion")
    func isSuccessReturnsTrueForSuccessfulCompletion() {
        let result = KeyboardActionResult(
            actionId: UUID(),
            type: .transcription,
            status: .complete,
            resultText: "Success"
        )

        #expect(result.isSuccess == true)
    }

    @Test("IsSuccess returns false for error status")
    func isSuccessReturnsFalseForErrorStatus() {
        let result = KeyboardActionResult(
            actionId: UUID(),
            type: .transcription,
            status: .error,
            errorMessage: "Something went wrong"
        )

        #expect(result.isSuccess == false)
    }

    @Test("IsSuccess returns false when complete but has error message")
    func isSuccessReturnsFalseWhenCompleteButHasErrorMessage() {
        let result = KeyboardActionResult(
            actionId: UUID(),
            type: .transcription,
            status: .complete,
            errorMessage: "Partial failure"
        )

        #expect(result.isSuccess == false)
    }

    @Test("Prediction result with predictions array")
    func predictionResultWithPredictionsArray() {
        let predictions = [
            "I would like to schedule a meeting",
            "I would like to discuss the project",
            "I would like to thank you",
            "I would like to ask about"
        ]

        let result = KeyboardActionResult(
            actionId: UUID(),
            type: .prediction,
            status: .complete,
            predictions: predictions
        )

        #expect(result.predictions?.count == 4)
        #expect(result.predictions == predictions)
    }

    @Test("Result encoding and decoding")
    func resultEncodingDecoding() throws {
        let original = KeyboardActionResult(
            actionId: UUID(),
            type: .aiProcess,
            status: .complete,
            resultText: "Processed output",
            duration: 1.25,
            estimatedCost: 0.0025
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KeyboardActionResult.self, from: encoded)

        #expect(decoded.actionId == original.actionId)
        #expect(decoded.type == original.type)
        #expect(decoded.status == original.status)
        #expect(decoded.resultText == original.resultText)
        #expect(decoded.duration == original.duration)
        #expect(decoded.estimatedCost == original.estimatedCost)
    }

    @Test("Result with error information")
    func resultWithErrorInformation() {
        let result = KeyboardActionResult(
            actionId: UUID(),
            type: .transcription,
            status: .error,
            errorMessage: "Network connection failed"
        )

        #expect(result.status == .error)
        #expect(result.errorMessage == "Network connection failed")
        #expect(result.isSuccess == false)
    }
}

// MARK: - App Groups Integration Tests

struct KeyboardActionAppGroupsTests {

    @Test("Action can be stored and retrieved from App Groups")
    func actionCanBeStoredAndRetrievedFromAppGroups() throws {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        let action = KeyboardAction.transcription(
            mode: .email,
            translate: true,
            targetLanguage: .spanish,
            sourceApp: (urlScheme: "testapp://", bundleId: "com.test", name: "Test App"),
            autoReturn: true
        )

        // Store
        let encoded = try JSONEncoder().encode(action)
        defaults?.set(encoded, forKey: Constants.KeyboardActionKeys.currentAction)
        defaults?.synchronize()

        // Retrieve
        guard let retrieved = defaults?.data(forKey: Constants.KeyboardActionKeys.currentAction) else {
            #expect(Bool(false), "Failed to retrieve action data")
            return
        }

        let decoded = try JSONDecoder().decode(KeyboardAction.self, from: retrieved)

        #expect(decoded.id == action.id)
        #expect(decoded.type == action.type)
        #expect(decoded.formattingMode == action.formattingMode)
        #expect(decoded.translateEnabled == action.translateEnabled)
        #expect(decoded.targetLanguage == action.targetLanguage)

        // Cleanup
        defaults?.removeObject(forKey: Constants.KeyboardActionKeys.currentAction)
    }

    @Test("Status can be stored and retrieved from App Groups")
    func statusCanBeStoredAndRetrievedFromAppGroups() {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        let status = KeyboardActionStatus.processing

        // Store
        defaults?.set(status.rawValue, forKey: Constants.KeyboardActionKeys.status)
        defaults?.synchronize()

        // Retrieve
        guard let rawValue = defaults?.string(forKey: Constants.KeyboardActionKeys.status),
              let decoded = KeyboardActionStatus(rawValue: rawValue) else {
            #expect(Bool(false), "Failed to retrieve status")
            return
        }

        #expect(decoded == status)

        // Cleanup
        defaults?.removeObject(forKey: Constants.KeyboardActionKeys.status)
    }

    @Test("Result can be stored and retrieved from App Groups")
    func resultCanBeStoredAndRetrievedFromAppGroups() throws {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        let result = KeyboardActionResult(
            actionId: UUID(),
            type: .transcription,
            status: .complete,
            resultText: "This is the transcription result",
            duration: 3.5
        )

        // Store
        let encoded = try JSONEncoder().encode(result)
        defaults?.set(encoded, forKey: Constants.KeyboardActionKeys.result)
        defaults?.synchronize()

        // Retrieve
        guard let retrieved = defaults?.data(forKey: Constants.KeyboardActionKeys.result) else {
            #expect(Bool(false), "Failed to retrieve result data")
            return
        }

        let decoded = try JSONDecoder().decode(KeyboardActionResult.self, from: retrieved)

        #expect(decoded.actionId == result.actionId)
        #expect(decoded.type == result.type)
        #expect(decoded.status == result.status)
        #expect(decoded.resultText == result.resultText)
        #expect(decoded.duration == result.duration)

        // Cleanup
        defaults?.removeObject(forKey: Constants.KeyboardActionKeys.result)
    }
}

// MARK: - Edge Cases and Boundary Tests

struct KeyboardActionEdgeCaseTests {

    @Test("Empty string handling in text fields")
    func emptyStringHandlingInTextFields() {
        let action = KeyboardAction.edit(originalText: "")
        #expect(action.originalText == "")

        let aiAction = KeyboardAction.aiProcess(
            text: "",
            contextId: nil,
            contextName: nil,
            powerModeId: nil,
            powerModeName: nil,
            translate: false,
            targetLanguage: nil,
            sourceApp: nil,
            autoReturn: true
        )
        #expect(aiAction.textToProcess == "")
    }

    @Test("Very long text handling")
    func veryLongTextHandling() throws {
        let longText = String(repeating: "a", count: 100000)
        let action = KeyboardAction.aiProcess(
            text: longText,
            contextId: nil,
            contextName: nil,
            powerModeId: nil,
            powerModeName: nil,
            translate: false,
            targetLanguage: nil,
            sourceApp: nil,
            autoReturn: true
        )

        #expect(action.textToProcess?.count == 100000)

        // Verify encoding/decoding works with long text
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(KeyboardAction.self, from: encoded)
        #expect(decoded.textToProcess?.count == 100000)
    }

    @Test("Unicode and emoji handling in text")
    func unicodeAndEmojiHandlingInText() throws {
        let unicodeText = "Hello \u{1F600} World \u{1F4BB} \u{1F30D} 你好 مرحبا"
        let action = KeyboardAction.edit(originalText: unicodeText)

        #expect(action.originalText == unicodeText)

        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(KeyboardAction.self, from: encoded)
        #expect(decoded.originalText == unicodeText)
    }

    @Test("Special characters in URL scheme")
    func specialCharactersInURLScheme() throws {
        let action = KeyboardAction.transcription(
            mode: .raw,
            sourceApp: (urlScheme: "my-app+test://", bundleId: nil, name: nil),
            autoReturn: true
        )

        #expect(action.sourceAppURLScheme == "my-app+test://")

        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(KeyboardAction.self, from: encoded)
        #expect(decoded.sourceAppURLScheme == "my-app+test://")
    }

    @Test("All nil optional fields")
    func allNilOptionalFields() throws {
        let action = KeyboardAction(type: .transcription)

        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(KeyboardAction.self, from: encoded)

        #expect(decoded.sourceAppURLScheme == nil)
        #expect(decoded.sourceAppBundleId == nil)
        #expect(decoded.sourceAppName == nil)
        #expect(decoded.formattingMode == nil)
        #expect(decoded.targetLanguage == nil)
        #expect(decoded.customTemplateId == nil)
        #expect(decoded.originalText == nil)
        #expect(decoded.textToProcess == nil)
        #expect(decoded.contextId == nil)
        #expect(decoded.contextName == nil)
        #expect(decoded.powerModeId == nil)
        #expect(decoded.powerModeName == nil)
        #expect(decoded.typingContext == nil)
        #expect(decoded.activeContextName == nil)
        #expect(decoded.activeContextId == nil)
    }

    @Test("Concurrent encoding/decoding")
    func concurrentEncodingDecoding() async throws {
        let action = KeyboardAction.transcription(mode: .email, translate: true, targetLanguage: .spanish)

        // Perform multiple concurrent encode/decode operations
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    do {
                        let encoded = try JSONEncoder().encode(action)
                        let decoded = try JSONDecoder().decode(KeyboardAction.self, from: encoded)
                        return decoded.id == action.id
                    } catch {
                        return false
                    }
                }
            }

            var allSucceeded = true
            for await result in group {
                if !result {
                    allSucceeded = false
                }
            }

            #expect(allSucceeded, "All concurrent operations should succeed")
        }
    }
}
