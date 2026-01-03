//
//  MockProviderFactory.swift
//  SwiftSpeak
//
//  Mock provider factory for testing PowerModeOrchestrator
//

import Foundation

/// Mock provider factory for unit testing
/// Returns configurable mock providers
@MainActor
final class MockProviderFactory: ProviderFactoryProtocol {

    // MARK: - Mock Providers

    /// Mock transcription provider to return
    public var mockTranscriptionProvider: MockTranscriptionProvider?

    /// Mock formatting provider to return
    public var mockFormattingProvider: MockFormattingProvider?

    // MARK: - Call Tracking

    /// Number of times createSelectedTranscriptionProvider was called
    private(set) var createTranscriptionProviderCallCount = 0

    /// Number of times createSelectedTextFormattingProvider was called
    private(set) var createFormattingProviderCallCount = 0

    // MARK: - Initialization

    public init(
        transcriptionProvider: MockTranscriptionProvider? = nil,
        formattingProvider: MockFormattingProvider? = nil
    ) {
        self.mockTranscriptionProvider = transcriptionProvider
        self.mockFormattingProvider = formattingProvider
    }

    // MARK: - Factory Methods

    public func createSelectedTranscriptionProvider() -> TranscriptionProvider? {
        createTranscriptionProviderCallCount += 1
        return mockTranscriptionProvider
    }

    public func createSelectedTextFormattingProvider() -> FormattingProvider? {
        createFormattingProviderCallCount += 1
        return mockFormattingProvider
    }

    // MARK: - Test Helpers

    public func reset() {
        createTranscriptionProviderCallCount = 0
        createFormattingProviderCallCount = 0
    }
}

// MARK: - Preset Configurations

extension MockProviderFactory {

    /// Factory with successful instant providers
    static var instant: MockProviderFactory {
        MockProviderFactory(
            transcriptionProvider: .instant,
            formattingProvider: .instant
        )
    }

    /// Factory with no providers configured (returns nil)
    static var unconfigured: MockProviderFactory {
        MockProviderFactory(
            transcriptionProvider: nil,
            formattingProvider: nil
        )
    }

    /// Factory where transcription fails
    static var transcriptionFailure: MockProviderFactory {
        MockProviderFactory(
            transcriptionProvider: .networkFailure,
            formattingProvider: .instant
        )
    }

    /// Factory where formatting fails
    static var formattingFailure: MockProviderFactory {
        MockProviderFactory(
            transcriptionProvider: .instant,
            formattingProvider: .networkFailure
        )
    }

    /// Factory with custom result
    static func withResult(transcription: String, formatted: String) -> MockProviderFactory {
        let transcriptionProvider = MockTranscriptionProvider(shouldSucceed: true, mockResult: transcription, delay: 0)
        let formattingProvider = MockFormattingProvider(shouldSucceed: true, customResult: formatted, delay: 0)
        return MockProviderFactory(
            transcriptionProvider: transcriptionProvider,
            formattingProvider: formattingProvider
        )
    }
}
