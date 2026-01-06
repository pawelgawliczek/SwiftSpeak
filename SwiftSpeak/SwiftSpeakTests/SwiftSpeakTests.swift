//
//  SwiftSpeakTests.swift
//  SwiftSpeakTests
//
//  Main test file for SwiftSpeak unit tests
//

import Testing
import SwiftSpeakCore
@testable import SwiftSpeak

// This file serves as the entry point for the test module.
// Individual test suites are organized in subdirectories:
//
// Models/
//   - AIProviderTests.swift
//   - FormattingModeTests.swift
//   - LanguageTests.swift
//
// Services/
//   - MockTranscriptionProviderTests.swift
//   - MockFormattingProviderTests.swift
//   - TranscriptionErrorTests.swift

struct SwiftSpeakTests {

    @Test func moduleLoads() {
        // Verify the SwiftSpeak module loads correctly
        #expect(true)
    }
}
