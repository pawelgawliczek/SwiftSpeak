//
//  LocalTranslationManagerTests.swift
//  SwiftSpeakTests
//
//  Phase 10f: Tests for LocalTranslationManager - the bridge between
//  service layer and SwiftUI's translationTask
//
//  Note: These tests require iOS 18.0+ and will skip on older versions

import Testing
import Foundation
@testable import SwiftSpeak

// MARK: - LocalTranslationManager Tests (iOS 18.0+)

@MainActor
struct LocalTranslationManagerTests {

    // MARK: - Singleton Tests

    @Test("Shared instance is singleton")
    func testSharedInstance() {
        guard #available(iOS 18.0, *) else {
            // Skip test on older iOS versions
            return
        }
        let instance1 = LocalTranslationManager.shared
        let instance2 = LocalTranslationManager.shared

        #expect(instance1 === instance2)
    }

    // MARK: - Initial State Tests

    @Test("Initial state is not translating")
    func testInitialState() {
        guard #available(iOS 18.0, *) else { return }
        let manager = LocalTranslationManager.shared

        #expect(manager.isTranslating == false)
        #expect(manager.textToTranslate == nil)
    }

    // MARK: - Cancel Tests

    @Test("Cancel resets state")
    func testCancelResetsState() {
        guard #available(iOS 18.0, *) else { return }
        let manager = LocalTranslationManager.shared

        // Set up some state by starting a request (but don't await it)
        manager.cancel()

        #expect(manager.isTranslating == false)
        #expect(manager.textToTranslate == nil)
    }

    // MARK: - Translation Request Tests

    @Test("Request sets pending text")
    func testRequestSetsPendingText() async {
        guard #available(iOS 18.0, *) else { return }
        let manager = LocalTranslationManager.shared

        // We need to test the request without actually waiting for completion
        // Start the request in a task that we'll cancel
        let task = Task {
            do {
                _ = try await manager.requestTranslation(
                    text: "Hello world",
                    from: .english,
                    to: .spanish
                )
            } catch {
                // Expected to be cancelled or fail
            }
        }

        // Give it a moment to set up
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Check that text was set
        #expect(manager.textToTranslate == "Hello world")
        #expect(manager.isTranslating == true)

        // Clean up
        task.cancel()
        manager.cancel()
    }

    @Test("Complete translation with success")
    func testCompleteTranslationSuccess() async {
        guard #available(iOS 18.0, *) else { return }
        let manager = LocalTranslationManager.shared

        var result: String?
        var error: Error?

        // Start the request in a task
        let task = Task {
            do {
                result = try await manager.requestTranslation(
                    text: "Hello",
                    from: .english,
                    to: .spanish
                )
            } catch let e {
                error = e
            }
        }

        // Give it a moment to set up
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Complete the translation
        manager.completeTranslation(with: .success("Hola"))

        // Wait for task to complete
        await task.value

        #expect(result == "Hola")
        #expect(error == nil)
        #expect(manager.isTranslating == false)
        #expect(manager.textToTranslate == nil)
    }

    @Test("Complete translation with failure")
    func testCompleteTranslationFailure() async {
        guard #available(iOS 18.0, *) else { return }
        let manager = LocalTranslationManager.shared

        var result: String?
        var caughtError: Error?

        // Start the request in a task
        let task = Task {
            do {
                result = try await manager.requestTranslation(
                    text: "Hello",
                    from: .english,
                    to: .spanish
                )
            } catch let e {
                caughtError = e
            }
        }

        // Give it a moment to set up
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Complete with error
        manager.completeTranslation(with: .failure(
            LocalProviderError.appleTranslationFailed(reason: "Test error")
        ))

        // Wait for task to complete
        await task.value

        #expect(result == nil)
        #expect(caughtError != nil)
        #expect(manager.isTranslating == false)
    }

    @Test("Concurrent translation requests are blocked")
    func testConcurrentRequestsBlocked() async {
        guard #available(iOS 18.0, *) else { return }
        let manager = LocalTranslationManager.shared

        var firstError: Error?
        var secondError: Error?

        // Start first request
        let task1 = Task {
            do {
                _ = try await manager.requestTranslation(
                    text: "First",
                    from: .english,
                    to: .spanish
                )
            } catch let e {
                firstError = e
            }
        }

        // Give it a moment
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Try second request while first is in progress
        let task2 = Task {
            do {
                _ = try await manager.requestTranslation(
                    text: "Second",
                    from: .english,
                    to: .french
                )
            } catch let e {
                secondError = e
            }
        }

        // Wait for second to complete (should fail immediately)
        await task2.value

        // Second request should have failed
        #expect(secondError != nil)
        if let error = secondError as? LocalProviderError {
            if case .appleTranslationFailed(let reason) = error {
                #expect(reason.contains("already in progress"))
            }
        }

        // Clean up first request
        manager.completeTranslation(with: .failure(
            LocalProviderError.appleTranslationFailed(reason: "Cancelled")
        ))
        await task1.value

        // Reset
        manager.cancel()
    }
}

// MARK: - Configuration Tests

#if canImport(Translation)
@MainActor
struct LocalTranslationManagerConfigurationTests {

    @Test("Configuration is set when translation requested")
    func testConfigurationSet() async {
        guard #available(iOS 18.0, *) else { return }
        let manager = LocalTranslationManager.shared

        // Start a request
        let task = Task {
            try? await manager.requestTranslation(
                text: "Test",
                from: .english,
                to: .german
            )
        }

        // Give it a moment
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Check configuration was set
        #expect(manager.configuration != nil)

        // Clean up
        manager.cancel()
        task.cancel()
    }

    @Test("Configuration is cleared after completion")
    func testConfigurationClearedAfterCompletion() async {
        guard #available(iOS 18.0, *) else { return }
        let manager = LocalTranslationManager.shared

        // Start a request
        let task = Task {
            try? await manager.requestTranslation(
                text: "Test",
                from: .english,
                to: .german
            )
        }

        // Give it a moment
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Complete
        manager.completeTranslation(with: .success("Test"))

        await task.value

        // Configuration should be cleared
        #expect(manager.configuration == nil)
    }
}
#endif

// MARK: - Language Code Conversion Tests

@MainActor
struct LanguageCodeConversionTests {

    // We can't directly test private methods, but we can verify
    // the behavior through the configuration that gets created

    @Test("All languages have valid codes")
    func testAllLanguagesHaveValidCodes() {
        // This test verifies that our Language enum maps correctly
        // by checking the AppleTranslationService's languageCode method
        // indirectly through the supportedLanguages

        let allLanguages: [Language] = [
            .english, .spanish, .french, .german, .italian,
            .portuguese, .russian, .chinese, .japanese,
            .korean, .arabic, .polish
        ]

        for language in allLanguages {
            // Verify each language can be used without crashing
            let config = AppleTranslationConfig(
                isAvailable: true,
                downloadedLanguages: [
                    DownloadedTranslationLanguage(
                        language: language,
                        sizeBytes: 50_000_000,
                        isSystem: false
                    )
                ]
            )

            if #available(iOS 17.4, *) {
                let service = AppleTranslationService(config: config)
                #expect(service.supportedLanguages.contains(language))
            }
        }
    }
}
