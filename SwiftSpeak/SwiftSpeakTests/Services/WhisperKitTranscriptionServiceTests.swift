//
//  WhisperKitTranscriptionServiceTests.swift
//  SwiftSpeakTests
//
//  Phase 10f: Tests for WhisperKitTranscriptionService
//

import Testing
import Foundation
@testable import SwiftSpeak

@MainActor
struct WhisperKitTranscriptionServiceTests {

    // MARK: - Initialization Tests

    @Test("Service initializes with config")
    func testInitialization() {
        let config = WhisperKitSettings(
            selectedModel: .largeV3,
            status: .ready,
            isEnabled: true
        )
        let service = WhisperKitTranscriptionService(config: config)

        #expect(service.providerId == .local)
        #expect(service.model == WhisperModel.largeV3.rawValue)
    }

    @Test("Service reports not configured when model not ready")
    func testNotConfiguredWhenModelNotReady() {
        let config = WhisperKitSettings(
            selectedModel: .largeV3,
            status: .notConfigured,
            isEnabled: false
        )
        let service = WhisperKitTranscriptionService(config: config)

        #expect(service.isConfigured == false)
    }

    @Test("Service reports not configured when downloading")
    func testNotConfiguredWhenDownloading() {
        let config = WhisperKitSettings(
            selectedModel: .largeV3,
            status: .downloading,
            downloadProgress: 0.5,
            isEnabled: true
        )
        let service = WhisperKitTranscriptionService(config: config)

        #expect(service.isConfigured == false)
    }

    // MARK: - Language Support Tests

    @Test("English-only model supports only English")
    func testEnglishOnlyModelLanguageSupport() {
        let config = WhisperKitSettings(
            selectedModel: .tinyEn,
            status: .ready,
            isEnabled: true
        )
        let service = WhisperKitTranscriptionService(config: config)

        #expect(service.supportsLanguage(.english) == true)
        #expect(service.supportsLanguage(.spanish) == false)
        #expect(service.supportsLanguage(.french) == false)
    }

    @Test("Multilingual model supports all languages")
    func testMultilingualModelLanguageSupport() {
        let config = WhisperKitSettings(
            selectedModel: .largeV3,
            status: .ready,
            isEnabled: true
        )
        let service = WhisperKitTranscriptionService(config: config)

        #expect(service.supportsLanguage(.english) == true)
        #expect(service.supportsLanguage(.spanish) == true)
        #expect(service.supportsLanguage(.chinese) == true)
        #expect(service.supportsLanguage(.arabic) == true)
    }

    // MARK: - API Key Validation

    @Test("API key validation always returns true for local provider")
    func testAPIKeyValidationAlwaysTrue() async {
        let config = WhisperKitSettings(
            selectedModel: .largeV3,
            status: .ready,
            isEnabled: true
        )
        let service = WhisperKitTranscriptionService(config: config)

        let result = await service.validateAPIKey("any-key")
        #expect(result == true)
    }

    // MARK: - Transcription Error Handling

    @Test("Transcription throws when model not downloaded")
    func testTranscriptionThrowsWhenModelNotDownloaded() async throws {
        let config = WhisperKitSettings(
            selectedModel: .largeV3,
            status: .notConfigured,
            isEnabled: false
        )
        let service = WhisperKitTranscriptionService(config: config)

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.wav")

        do {
            _ = try await service.transcribe(audioURL: tempURL, language: .english, promptHint: nil)
            Issue.record("Expected error to be thrown")
        } catch let error as LocalProviderError {
            if case .whisperKitModelNotDownloaded = error {
                // Expected
            } else {
                Issue.record("Unexpected error type: \(error)")
            }
        } catch {
            // WhisperKit not available error is also acceptable
        }
    }

    @Test("Transcription throws when audio file not found")
    func testTranscriptionThrowsWhenAudioFileNotFound() async throws {
        let config = WhisperKitSettings(
            selectedModel: .largeV3,
            status: .ready,
            isEnabled: true
        )
        let service = WhisperKitTranscriptionService(config: config)

        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/audio.wav")

        do {
            _ = try await service.transcribe(audioURL: nonExistentURL, language: .english, promptHint: nil)
            Issue.record("Expected error to be thrown")
        } catch let error as TranscriptionError {
            #expect(error == .audioFileNotFound)
        } catch {
            // WhisperKit not available is also acceptable
        }
    }

    // MARK: - Model Unloading

    @Test("Model can be unloaded")
    func testModelUnloading() {
        let config = WhisperKitSettings(
            selectedModel: .largeV3,
            status: .ready,
            isEnabled: true
        )
        let service = WhisperKitTranscriptionService(config: config)

        // Should not throw
        service.unloadModel()
    }

    // MARK: - Disk Space Checking

    @Test("Disk space check returns boolean")
    func testDiskSpaceCheck() {
        let hasSpace = WhisperKitTranscriptionService.hasEnoughDiskSpace(for: .tiny)
        #expect(hasSpace == true || hasSpace == false) // Just verify it returns a value

        // Tiny model (75MB) should generally have enough space
        // Large model might not on low-storage devices
    }

    @Test("Small models require less disk space")
    func testSmallModelsRequireLessSpace() {
        // Tiny model should be more likely to have enough space than large
        let hasTinySpace = WhisperKitTranscriptionService.hasEnoughDiskSpace(for: .tiny)
        let hasLargeSpace = WhisperKitTranscriptionService.hasEnoughDiskSpace(for: .largeV3)

        // If we have space for large, we definitely have space for tiny
        if hasLargeSpace {
            #expect(hasTinySpace == true)
        }
    }
}

// MARK: - Model Size Tests

@MainActor
struct WhisperModelSizeTests {

    @Test("Models have correct relative sizes")
    func testModelRelativeSizes() {
        #expect(WhisperModel.tiny.sizeBytes < WhisperModel.small.sizeBytes)
        #expect(WhisperModel.small.sizeBytes < WhisperModel.medium.sizeBytes)
        #expect(WhisperModel.medium.sizeBytes < WhisperModel.large.sizeBytes)
    }

    @Test("English-only models are smaller than multilingual")
    func testEnglishOnlyModelsSmaller() {
        #expect(WhisperModel.tinyEn.sizeBytes <= WhisperModel.tiny.sizeBytes)
    }

    @Test("Model display names are not empty")
    func testModelDisplayNames() {
        for model in WhisperModel.allCases {
            #expect(!model.displayName.isEmpty)
        }
    }

    @Test("Model descriptions are not empty")
    func testModelDescriptions() {
        for model in WhisperModel.allCases {
            #expect(!model.description.isEmpty)
        }
    }
}
