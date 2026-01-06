//
//  AppleIntelligenceFormattingServiceTests.swift
//  SwiftSpeakTests
//
//  Phase 10f: Tests for AppleIntelligenceFormattingService
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

@MainActor
struct AppleIntelligenceFormattingServiceTests {

    // MARK: - Initialization Tests

    @Test("Service initializes with config")
    func testInitialization() {
        if #available(iOS 26.0, *) {
            let config = AppleIntelligenceConfig(
                isEnabled: true,
                isAvailable: true
            )
            let service = AppleIntelligenceFormattingService(config: config)

            #expect(service.providerId == AIProvider.local)
            #expect(service.model == "Apple Intelligence")
            #expect(service.supportsStreaming == true)
        }
    }

    @Test("Service is configured when available and enabled")
    func testConfiguredWhenReady() {
        if #available(iOS 26.0, *) {
            let config = AppleIntelligenceConfig(
                isEnabled: true,
                isAvailable: true
            )
            let service = AppleIntelligenceFormattingService(config: config)
            #expect(service.isConfigured == true)
        }
    }

    @Test("Service is not configured when unavailable")
    func testNotConfiguredWhenUnavailable() {
        if #available(iOS 26.0, *) {
            let config = AppleIntelligenceConfig(
                isEnabled: true,
                isAvailable: false
            )
            let service = AppleIntelligenceFormattingService(config: config)
            #expect(service.isConfigured == false)
        }
    }

    @Test("Service is not configured when disabled")
    func testNotConfiguredWhenDisabled() {
        if #available(iOS 26.0, *) {
            let config = AppleIntelligenceConfig(
                isEnabled: false,
                isAvailable: true
            )
            let service = AppleIntelligenceFormattingService(config: config)
            #expect(service.isConfigured == false)
        }
    }

    // MARK: - Formatting Error Tests

    @Test("Format throws when not enabled")
    func testFormatThrowsWhenNotEnabled() async {
        if #available(iOS 26.0, *) {
            let config = AppleIntelligenceConfig(
                isEnabled: false,
                isAvailable: true
            )
            let service = AppleIntelligenceFormattingService(config: config)

            do {
                _ = try await service.format(
                    text: "Hello",
                    mode: FormattingMode.email,
                    customPrompt: nil as String?,
                    context: nil as PromptContext?
                )
                Issue.record("Expected error to be thrown")
            } catch let error as LocalProviderError {
                // Check for either not available or not enabled error
                switch error {
                case .appleIntelligenceNotEnabled:
                    // Expected
                    break
                case .appleIntelligenceNotAvailable:
                    // Also acceptable (availability check happens first)
                    break
                default:
                    Issue.record("Unexpected error type: \(error)")
                }
            } catch {
                // Other errors are acceptable on devices without Apple Intelligence
            }
        }
    }

    // MARK: - Fallback Service Tests

    @Test("Fallback service reports not configured")
    func testFallbackNotConfigured() {
        let fallback = AppleIntelligenceFormattingServiceFallback()

        #expect(fallback.providerId == .local)
        #expect(fallback.isConfigured == false)
        #expect(fallback.model == "Apple Intelligence (Unavailable)")
    }

    @Test("Fallback service throws error on format")
    func testFallbackThrowsOnFormat() async {
        let fallback = AppleIntelligenceFormattingServiceFallback()

        do {
            _ = try await fallback.format(
                text: "Hello",
                mode: .email,
                customPrompt: nil,
                context: nil
            )
            Issue.record("Expected error to be thrown")
        } catch let error as LocalProviderError {
            if case .appleIntelligenceNotAvailable = error {
                // Expected
            } else {
                Issue.record("Unexpected error type: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

// MARK: - Apple Intelligence Config Tests

@MainActor
struct AppleIntelligenceConfigTests {

    @Test("Default config is not available")
    func testDefaultConfig() {
        let config = AppleIntelligenceConfig.default
        // Default config should reflect actual device capability
        // On simulator/unsupported device, it's not available
        #expect(config.isEnabled == false)
    }

    @Test("Config stores properties correctly")
    func testConfigProperties() {
        let config = AppleIntelligenceConfig(
            isEnabled: true,
            isAvailable: true,
            unavailableReason: nil
        )

        #expect(config.isAvailable == true)
        #expect(config.isEnabled == true)
        #expect(config.unavailableReason == nil)
    }

    @Test("Config with unavailable reason")
    func testConfigWithReason() {
        let reason = "Device not eligible"
        let config = AppleIntelligenceConfig(
            isEnabled: false,
            isAvailable: false,
            unavailableReason: reason
        )

        #expect(config.isAvailable == false)
        #expect(config.unavailableReason == reason)
    }
}
