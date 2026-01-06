//
//  AppleTranslationServiceTests.swift
//  SwiftSpeakTests
//
//  Phase 10f: Tests for AppleTranslationService
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

@MainActor
struct AppleTranslationServiceTests {

    // MARK: - Initialization Tests

    @Test("Service initializes with config")
    func testInitialization() {
        let config = AppleTranslationConfig(
            isAvailable: true,
            downloadedLanguages: [
                DownloadedTranslationLanguage(language: .english, sizeBytes: 50_000_000, isSystem: true),
                DownloadedTranslationLanguage(language: .spanish, sizeBytes: 45_000_000, isSystem: false)
            ]
        )

        if #available(iOS 17.4, *) {
            let service = AppleTranslationService(config: config)

            #expect(service.providerId == .local)
            #expect(service.model == "Apple Translation")
            #expect(service.supportsFormality == false)
        }
    }

    @Test("Service is configured when languages available")
    func testConfiguredWithLanguages() {
        let config = AppleTranslationConfig(
            isAvailable: true,
            downloadedLanguages: [
                DownloadedTranslationLanguage(language: .english, sizeBytes: 50_000_000, isSystem: true)
            ]
        )

        if #available(iOS 17.4, *) {
            let service = AppleTranslationService(config: config)
            #expect(service.isConfigured == true)
        }
    }

    @Test("Service is not configured when no languages")
    func testNotConfiguredWithoutLanguages() {
        let config = AppleTranslationConfig(
            isAvailable: true,
            downloadedLanguages: []
        )

        if #available(iOS 17.4, *) {
            let service = AppleTranslationService(config: config)
            #expect(service.isConfigured == false)
        }
    }

    @Test("Service is not configured when unavailable")
    func testNotConfiguredWhenUnavailable() {
        let config = AppleTranslationConfig(
            isAvailable: false,
            downloadedLanguages: [
                DownloadedTranslationLanguage(language: .english, sizeBytes: 50_000_000, isSystem: true)
            ]
        )

        if #available(iOS 17.4, *) {
            let service = AppleTranslationService(config: config)
            #expect(service.isConfigured == false)
        }
    }

    // MARK: - Supported Languages Tests

    @Test("Supported languages match downloaded languages")
    func testSupportedLanguages() {
        let config = AppleTranslationConfig(
            isAvailable: true,
            downloadedLanguages: [
                DownloadedTranslationLanguage(language: .english, sizeBytes: 50_000_000, isSystem: true),
                DownloadedTranslationLanguage(language: .french, sizeBytes: 45_000_000, isSystem: false),
                DownloadedTranslationLanguage(language: .german, sizeBytes: 48_000_000, isSystem: false)
            ]
        )

        if #available(iOS 17.4, *) {
            let service = AppleTranslationService(config: config)

            #expect(service.supportedLanguages.count == 3)
            #expect(service.supportedLanguages.contains(.english))
            #expect(service.supportedLanguages.contains(.french))
            #expect(service.supportedLanguages.contains(.german))
            #expect(!service.supportedLanguages.contains(.spanish))
        }
    }

    // MARK: - Language Availability Tests

    @Test("Language availability returns available for downloaded languages")
    func testLanguageAvailabilityAvailable() {
        let config = AppleTranslationConfig(
            isAvailable: true,
            downloadedLanguages: [
                DownloadedTranslationLanguage(language: .english, sizeBytes: 50_000_000, isSystem: true),
                DownloadedTranslationLanguage(language: .spanish, sizeBytes: 45_000_000, isSystem: false)
            ]
        )

        if #available(iOS 17.4, *) {
            let service = AppleTranslationService(config: config)

            let status = service.checkLanguageAvailability(from: .english, to: .spanish)
            #expect(status == .available)
        }
    }

    @Test("Language availability returns requires download for missing target")
    func testLanguageAvailabilityRequiresTargetDownload() {
        let config = AppleTranslationConfig(
            isAvailable: true,
            downloadedLanguages: [
                DownloadedTranslationLanguage(language: .english, sizeBytes: 50_000_000, isSystem: true)
            ]
        )

        if #available(iOS 17.4, *) {
            let service = AppleTranslationService(config: config)

            let status = service.checkLanguageAvailability(from: .english, to: .spanish)
            if case .requiresDownload(let languages) = status {
                #expect(languages.contains(.spanish))
            } else {
                Issue.record("Expected requiresDownload status")
            }
        }
    }

    @Test("Language availability returns requires download for missing source")
    func testLanguageAvailabilityRequiresSourceDownload() {
        let config = AppleTranslationConfig(
            isAvailable: true,
            downloadedLanguages: [
                DownloadedTranslationLanguage(language: .spanish, sizeBytes: 45_000_000, isSystem: false)
            ]
        )

        if #available(iOS 17.4, *) {
            let service = AppleTranslationService(config: config)

            let status = service.checkLanguageAvailability(from: .english, to: .spanish)
            if case .requiresDownload(let languages) = status {
                #expect(languages.contains(.english))
            } else {
                Issue.record("Expected requiresDownload status")
            }
        }
    }

    @Test("Language availability works with auto-detect source")
    func testLanguageAvailabilityAutoDetect() {
        let config = AppleTranslationConfig(
            isAvailable: true,
            downloadedLanguages: [
                DownloadedTranslationLanguage(language: .spanish, sizeBytes: 45_000_000, isSystem: false)
            ]
        )

        if #available(iOS 17.4, *) {
            let service = AppleTranslationService(config: config)

            let status = service.checkLanguageAvailability(from: nil, to: .spanish)
            #expect(status == .available)
        }
    }

    // MARK: - Translation Error Handling

    @Test("Translation throws when not available")
    func testTranslationThrowsWhenNotAvailable() async throws {
        let config = AppleTranslationConfig(
            isAvailable: false,
            downloadedLanguages: []
        )

        if #available(iOS 17.4, *) {
            let service = AppleTranslationService(config: config)

            do {
                _ = try await service.translate(
                    text: "Hello",
                    from: .english,
                    to: .spanish,
                    formality: nil,
                    context: nil
                )
                Issue.record("Expected error to be thrown")
            } catch let error as LocalProviderError {
                if case .appleTranslationNotAvailable = error {
                    // Expected
                } else {
                    Issue.record("Unexpected error type: \(error)")
                }
            }
        }
    }

    @Test("Translation throws when target language not installed")
    func testTranslationThrowsWhenLanguageNotInstalled() async throws {
        let config = AppleTranslationConfig(
            isAvailable: true,
            downloadedLanguages: [
                DownloadedTranslationLanguage(language: .english, sizeBytes: 50_000_000, isSystem: true)
            ]
        )

        if #available(iOS 17.4, *) {
            let service = AppleTranslationService(config: config)

            do {
                _ = try await service.translate(
                    text: "Hello",
                    from: .english,
                    to: .japanese,
                    formality: nil,
                    context: nil
                )
                Issue.record("Expected error to be thrown")
            } catch let error as LocalProviderError {
                if case .appleTranslationLanguageNotInstalled(let language) = error {
                    #expect(language == Language.japanese.displayName)
                } else {
                    Issue.record("Unexpected error type: \(error)")
                }
            }
        }
    }
}

// MARK: - Downloaded Language Tests

@MainActor
struct DownloadedTranslationLanguageTests {

    @Test("Size is formatted correctly")
    func testSizeFormatting() {
        let lang = DownloadedTranslationLanguage(
            language: .english,
            sizeBytes: 50_000_000,  // 50 MB
            isSystem: true
        )

        #expect(lang.sizeFormatted == "48 MB") // 50_000_000 / (1024*1024) ≈ 47.68
    }

    @Test("ID matches language rawValue")
    func testIdMatchesLanguage() {
        let lang = DownloadedTranslationLanguage(
            language: .spanish,
            sizeBytes: 45_000_000,
            isSystem: false
        )

        #expect(lang.id == Language.spanish.rawValue)
    }
}

// MARK: - Language Availability Status Tests

@MainActor
struct LanguageAvailabilityStatusTests {

    @Test("Available status returns isAvailable true")
    func testAvailableStatus() {
        let status = LanguageAvailabilityStatus.available
        #expect(status.isAvailable == true)
    }

    @Test("RequiresDownload status returns isAvailable false")
    func testRequiresDownloadStatus() {
        let status = LanguageAvailabilityStatus.requiresDownload(languages: [.spanish])
        #expect(status.isAvailable == false)
    }

    @Test("NotSupported status returns isAvailable false")
    func testNotSupportedStatus() {
        let status = LanguageAvailabilityStatus.notSupported
        #expect(status.isAvailable == false)
    }

    @Test("RequiresDownload contains correct languages")
    func testRequiresDownloadLanguages() {
        let status = LanguageAvailabilityStatus.requiresDownload(languages: [.spanish, .french])
        if case .requiresDownload(let languages) = status {
            #expect(languages.count == 2)
            #expect(languages.contains(.spanish))
            #expect(languages.contains(.french))
        } else {
            Issue.record("Expected requiresDownload status")
        }
    }
}
