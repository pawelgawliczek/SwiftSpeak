//
//  ProcessingMetadataTests.swift
//  SwiftSpeakTests
//
//  Tests for ProcessingStepType, ProcessingStepInfo, and ProcessingMetadata
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

// MARK: - ProcessingStepType Tests

@Suite("ProcessingStepType")
struct ProcessingStepTypeTests {

    @Test("All step types have display names")
    func allTypesHaveDisplayNames() {
        for stepType in ProcessingStepType.allCases {
            #expect(!stepType.displayName.isEmpty)
        }
    }

    @Test("All step types have icons")
    func allTypesHaveIcons() {
        for stepType in ProcessingStepType.allCases {
            #expect(!stepType.icon.isEmpty)
        }
    }

    @Test("Display names are unique")
    func displayNamesAreUnique() {
        let names = ProcessingStepType.allCases.map { $0.displayName }
        let uniqueNames = Set(names)
        #expect(names.count == uniqueNames.count)
    }

    @Test("Transcription step type properties")
    func transcriptionStepType() {
        let type = ProcessingStepType.transcription
        #expect(type.displayName == "Transcription")
        #expect(type.icon == "waveform")
    }

    @Test("Formatting step type properties")
    func formattingStepType() {
        let type = ProcessingStepType.formatting
        #expect(type.displayName == "Formatting")
        #expect(type.icon == "text.alignleft")
    }

    @Test("Translation step type properties")
    func translationStepType() {
        let type = ProcessingStepType.translation
        #expect(type.displayName == "Translation")
        #expect(type.icon == "globe")
    }

    @Test("Power mode step type properties")
    func powerModeStepType() {
        let type = ProcessingStepType.powerMode
        #expect(type.displayName == "Power Mode")
        #expect(type.icon == "bolt.fill")
    }

    @Test("Encodes and decodes correctly")
    func codable() throws {
        for stepType in ProcessingStepType.allCases {
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(stepType)
            let decoded = try decoder.decode(ProcessingStepType.self, from: data)

            #expect(decoded == stepType)
        }
    }
}

// MARK: - ProcessingStepInfo Tests

@Suite("ProcessingStepInfo")
struct ProcessingStepInfoTests {

    @Test("Creation with all fields")
    func creationWithAllFields() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(0.5) // 500ms later

        let step = ProcessingStepInfo(
            stepType: .transcription,
            provider: .openAI,
            modelName: "whisper-1",
            startTime: startTime,
            endTime: endTime,
            inputTokens: nil,
            outputTokens: nil,
            cost: 0.001,
            prompt: "Test prompt"
        )

        #expect(step.stepType == .transcription)
        #expect(step.provider == .openAI)
        #expect(step.modelName == "whisper-1")
        #expect(step.startTime == startTime)
        #expect(step.endTime == endTime)
        #expect(step.cost == 0.001)
        #expect(step.prompt == "Test prompt")
    }

    @Test("Response time calculation in milliseconds")
    func responseTimeMs() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(0.847) // 847ms

        let step = ProcessingStepInfo(
            stepType: .transcription,
            provider: .openAI,
            modelName: "whisper-1",
            startTime: startTime,
            endTime: endTime,
            cost: 0.001
        )

        #expect(step.responseTimeMs == 847)
    }

    @Test("Response time formatting for milliseconds")
    func responseTimeFormattedMs() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(0.523) // 523ms

        let step = ProcessingStepInfo(
            stepType: .formatting,
            provider: .anthropic,
            modelName: "claude-3-haiku",
            startTime: startTime,
            endTime: endTime,
            cost: 0.0001
        )

        #expect(step.responseTimeFormatted == "523ms")
    }

    @Test("Response time formatting for seconds")
    func responseTimeFormattedSeconds() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(2.5) // 2500ms = 2.5s

        let step = ProcessingStepInfo(
            stepType: .powerMode,
            provider: .anthropic,
            modelName: "claude-3-opus",
            startTime: startTime,
            endTime: endTime,
            cost: 0.05
        )

        #expect(step.responseTimeFormatted == "2.5s")
    }

    @Test("Token counts are optional")
    func tokenCountsOptional() {
        let step = ProcessingStepInfo(
            stepType: .transcription,
            provider: .openAI,
            modelName: "whisper-1",
            startTime: Date(),
            endTime: Date(),
            cost: 0.001
        )

        #expect(step.inputTokens == nil)
        #expect(step.outputTokens == nil)
    }

    @Test("Token counts when provided")
    func tokenCountsProvided() {
        let step = ProcessingStepInfo(
            stepType: .formatting,
            provider: .openAI,
            modelName: "gpt-4o-mini",
            startTime: Date(),
            endTime: Date(),
            inputTokens: 127,
            outputTokens: 89,
            cost: 0.0001
        )

        #expect(step.inputTokens == 127)
        #expect(step.outputTokens == 89)
    }

    @Test("Encodes and decodes correctly")
    @MainActor
    func codable() throws {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(0.5)

        let step = ProcessingStepInfo(
            stepType: .translation,
            provider: .deepL,
            modelName: "deepl-translate",
            startTime: startTime,
            endTime: endTime,
            inputTokens: 50,
            outputTokens: 55,
            cost: 0.0005,
            prompt: "Translate to Spanish"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(step)
        let decoded = try decoder.decode(ProcessingStepInfo.self, from: data)

        #expect(decoded.id == step.id)
        #expect(decoded.stepType == step.stepType)
        #expect(decoded.provider == step.provider)
        #expect(decoded.modelName == step.modelName)
        #expect(decoded.cost == step.cost)
        #expect(decoded.prompt == step.prompt)
    }

    @Test("Identifiable with unique IDs")
    func identifiable() {
        let step1 = ProcessingStepInfo(
            stepType: .transcription,
            provider: .openAI,
            modelName: "whisper-1",
            startTime: Date(),
            endTime: Date(),
            cost: 0.001
        )

        let step2 = ProcessingStepInfo(
            stepType: .transcription,
            provider: .openAI,
            modelName: "whisper-1",
            startTime: Date(),
            endTime: Date(),
            cost: 0.001
        )

        #expect(step1.id != step2.id)
    }
}

// MARK: - ProcessingMetadata Tests

@Suite("ProcessingMetadata")
struct ProcessingMetadataTests {

    private func createTestStep(
        type: ProcessingStepType,
        provider: AIProvider = .openAI,
        duration: TimeInterval = 0.5,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        cost: Double = 0.001,
        prompt: String? = nil
    ) -> ProcessingStepInfo {
        let startTime = Date()
        return ProcessingStepInfo(
            stepType: type,
            provider: provider,
            modelName: "test-model",
            startTime: startTime,
            endTime: startTime.addingTimeInterval(duration),
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cost: cost,
            prompt: prompt
        )
    }

    @Test("Creation with steps")
    func creationWithSteps() {
        let steps = [
            createTestStep(type: .transcription),
            createTestStep(type: .formatting)
        ]

        let metadata = ProcessingMetadata(
            steps: steps,
            totalProcessingTime: 1.0
        )

        #expect(metadata.steps.count == 2)
        #expect(metadata.totalProcessingTime == 1.0)
    }

    @Test("Step lookup by type")
    func stepLookupByType() {
        let steps = [
            createTestStep(type: .transcription, provider: .openAI),
            createTestStep(type: .formatting, provider: .anthropic),
            createTestStep(type: .translation, provider: .deepL)
        ]

        let metadata = ProcessingMetadata(
            steps: steps,
            totalProcessingTime: 1.5
        )

        let transcription = metadata.step(ofType: .transcription)
        #expect(transcription?.provider == .openAI)

        let formatting = metadata.step(ofType: .formatting)
        #expect(formatting?.provider == .anthropic)

        let translation = metadata.step(ofType: .translation)
        #expect(translation?.provider == .deepL)

        let powerMode = metadata.step(ofType: .powerMode)
        #expect(powerMode == nil)
    }

    @Test("Total response time in milliseconds")
    func totalResponseTimeMs() {
        let metadata = ProcessingMetadata(
            steps: [],
            totalProcessingTime: 1.682
        )

        #expect(metadata.totalResponseTimeMs == 1682)
    }

    @Test("Total input tokens calculation")
    func totalInputTokens() {
        let steps = [
            createTestStep(type: .transcription),  // nil tokens
            createTestStep(type: .formatting, inputTokens: 127, outputTokens: 89),
            createTestStep(type: .translation, inputTokens: 89, outputTokens: 95)
        ]

        let metadata = ProcessingMetadata(
            steps: steps,
            totalProcessingTime: 1.5
        )

        #expect(metadata.totalInputTokens == 216)  // 127 + 89
    }

    @Test("Total output tokens calculation")
    func totalOutputTokens() {
        let steps = [
            createTestStep(type: .formatting, inputTokens: 127, outputTokens: 89),
            createTestStep(type: .translation, inputTokens: 89, outputTokens: 95)
        ]

        let metadata = ProcessingMetadata(
            steps: steps,
            totalProcessingTime: 1.0
        )

        #expect(metadata.totalOutputTokens == 184)  // 89 + 95
    }

    @Test("All prompts extraction")
    func allPromptsExtraction() {
        let steps = [
            createTestStep(type: .transcription, prompt: "Language: English"),
            createTestStep(type: .formatting, prompt: "Format as email"),
            createTestStep(type: .translation)  // nil prompt
        ]

        let metadata = ProcessingMetadata(
            steps: steps,
            totalProcessingTime: 1.0
        )

        let prompts = metadata.allPrompts
        #expect(prompts.count == 2)
        #expect(prompts[0].stepType == .transcription)
        #expect(prompts[0].prompt == "Language: English")
        #expect(prompts[1].stepType == .formatting)
        #expect(prompts[1].prompt == "Format as email")
    }

    @Test("Optional parameters")
    func optionalParameters() {
        let metadata = ProcessingMetadata(
            steps: [],
            totalProcessingTime: 1.0,
            sourceLanguageHint: .english,
            vocabularyApplied: ["SwiftSpeak", "iOS"],
            memorySourcesUsed: ["Global Memory", "Work Context"],
            ragDocumentsQueried: ["docs/api.pdf"],
            webhooksExecuted: ["company-context"]
        )

        #expect(metadata.sourceLanguageHint == .english)
        #expect(metadata.vocabularyApplied?.count == 2)
        #expect(metadata.memorySourcesUsed?.count == 2)
        #expect(metadata.ragDocumentsQueried?.count == 1)
        #expect(metadata.webhooksExecuted?.count == 1)
    }

    @Test("Encodes and decodes correctly")
    @MainActor
    func codable() throws {
        let steps = [
            createTestStep(type: .transcription, prompt: "Test prompt")
        ]

        let metadata = ProcessingMetadata(
            steps: steps,
            totalProcessingTime: 0.5,
            sourceLanguageHint: .english,
            vocabularyApplied: ["test"]
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(metadata)
        let decoded = try decoder.decode(ProcessingMetadata.self, from: data)

        #expect(decoded.steps.count == 1)
        #expect(decoded.totalProcessingTime == 0.5)
        #expect(decoded.sourceLanguageHint == .english)
        #expect(decoded.vocabularyApplied == ["test"])
    }
}

// MARK: - TranscriptionRecord with Processing Metadata Tests

@Suite("TranscriptionRecord Processing Metadata")
struct TranscriptionRecordProcessingMetadataTests {

    @Test("New record with raw and formatted text")
    func newRecordWithRawAndFormattedText() {
        let record = TranscriptionRecord(
            rawTranscribedText: "hey can you send me the report",
            text: "Hey, could you please send me the report?",
            mode: .email,
            provider: .openAI,
            duration: 3.5
        )

        #expect(record.rawTranscribedText == "hey can you send me the report")
        #expect(record.text == "Hey, could you please send me the report?")
        #expect(record.hasTransformation == true)
    }

    @Test("Raw mode record has same input and output")
    func rawModeRecordSameInputOutput() {
        let record = TranscriptionRecord(
            rawTranscribedText: "this is raw text",
            text: "this is raw text",
            mode: .raw,
            provider: .openAI,
            duration: 2.0
        )

        #expect(record.hasTransformation == false)
    }

    @Test("Legacy record migration - rawTranscribedText defaults to text")
    func legacyRecordMigration() {
        // Simulating legacy record without rawTranscribedText
        let record = TranscriptionRecord(
            rawTranscribedText: nil,  // Not provided
            text: "legacy text",
            mode: .raw,
            provider: .openAI,
            duration: 2.0
        )

        #expect(record.rawTranscribedText == "legacy text")
        #expect(record.hasTransformation == false)
    }

    @Test("Record with processing metadata")
    func recordWithProcessingMetadata() {
        let step = ProcessingStepInfo(
            stepType: .transcription,
            provider: .openAI,
            modelName: "whisper-1",
            startTime: Date(),
            endTime: Date().addingTimeInterval(0.5),
            cost: 0.001
        )

        let metadata = ProcessingMetadata(
            steps: [step],
            totalProcessingTime: 0.5
        )

        let record = TranscriptionRecord(
            rawTranscribedText: "test",
            text: "Test formatted",
            mode: .email,
            provider: .openAI,
            duration: 3.0,
            processingMetadata: metadata
        )

        #expect(record.hasProcessingDetails == true)
        #expect(record.processingMetadata?.steps.count == 1)
    }

    @Test("Record without processing metadata")
    func recordWithoutProcessingMetadata() {
        let record = TranscriptionRecord(
            rawTranscribedText: "test",
            text: "test",
            mode: .raw,
            provider: .openAI,
            duration: 2.0,
            processingMetadata: nil
        )

        #expect(record.hasProcessingDetails == false)
    }

    @Test("formattingWasApplied for different modes")
    func formattingWasApplied() {
        let rawRecord = TranscriptionRecord(
            text: "test",
            mode: .raw,
            provider: .openAI,
            duration: 1.0
        )
        #expect(rawRecord.formattingWasApplied == false)

        let emailRecord = TranscriptionRecord(
            text: "test",
            mode: .email,
            provider: .openAI,
            duration: 1.0
        )
        #expect(emailRecord.formattingWasApplied == true)

        let powerModeRecord = TranscriptionRecord(
            text: "test",
            mode: .raw,
            provider: .openAI,
            duration: 1.0,
            powerModeId: UUID()
        )
        #expect(powerModeRecord.formattingWasApplied == true)
    }

    @Test("Backward compatible Codable decoding")
    @MainActor
    func backwardCompatibleDecoding() throws {
        // Simulate legacy JSON without new fields
        let legacyJSON = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "text": "Legacy transcription text",
            "mode": "raw",
            "provider": "openAI",
            "timestamp": 0,
            "duration": 5.0,
            "translated": false
        }
        """

        let decoder = JSONDecoder()
        let data = legacyJSON.data(using: .utf8)!
        let record = try decoder.decode(TranscriptionRecord.self, from: data)

        #expect(record.text == "Legacy transcription text")
        #expect(record.rawTranscribedText == "Legacy transcription text")  // Falls back to text
        #expect(record.processingMetadata == nil)
        #expect(record.hasProcessingDetails == false)
    }

    @Test("Full Codable round-trip with new fields")
    @MainActor
    func fullCodableRoundTrip() throws {
        let step = ProcessingStepInfo(
            stepType: .transcription,
            provider: .openAI,
            modelName: "whisper-1",
            startTime: Date(),
            endTime: Date().addingTimeInterval(0.5),
            inputTokens: nil,
            outputTokens: nil,
            cost: 0.001,
            prompt: "Test"
        )

        let metadata = ProcessingMetadata(
            steps: [step],
            totalProcessingTime: 0.5,
            sourceLanguageHint: .english,
            vocabularyApplied: ["test"]
        )

        let original = TranscriptionRecord(
            rawTranscribedText: "raw input",
            text: "Formatted output",
            mode: .email,
            provider: .openAI,
            duration: 3.0,
            translated: true,
            targetLanguage: .spanish,
            processingMetadata: metadata
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TranscriptionRecord.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.rawTranscribedText == "raw input")
        #expect(decoded.text == "Formatted output")
        #expect(decoded.hasTransformation == true)
        #expect(decoded.hasProcessingDetails == true)
        #expect(decoded.processingMetadata?.steps.count == 1)
        #expect(decoded.processingMetadata?.sourceLanguageHint == .english)
    }
}
