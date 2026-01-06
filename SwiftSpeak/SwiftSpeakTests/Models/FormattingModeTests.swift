//
//  FormattingModeTests.swift
//  SwiftSpeakTests
//
//  Tests for FormattingMode enum
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

struct FormattingModeTests {

    // MARK: - Basic Properties

    @Test func allModesHaveDisplayNames() {
        for mode in FormattingMode.allCases {
            #expect(!mode.displayName.isEmpty)
        }
    }

    @Test func allModesHaveIcons() {
        for mode in FormattingMode.allCases {
            #expect(!mode.icon.isEmpty)
        }
    }

    @Test func allModesHavePrompts() {
        for mode in FormattingMode.allCases {
            // Raw mode should have empty prompt
            if mode == .raw {
                #expect(mode.prompt.isEmpty)
            } else {
                #expect(!mode.prompt.isEmpty)
            }
        }
    }

    // MARK: - Specific Modes

    @Test func rawModeHasExpectedProperties() {
        let mode = FormattingMode.raw
        #expect(mode.displayName == "Raw")
        #expect(mode.prompt.isEmpty)
    }

    @Test func emailModeHasExpectedProperties() {
        let mode = FormattingMode.email
        #expect(mode.displayName == "Email")
        #expect(mode.prompt.lowercased().contains("email"))
    }

    @Test func formalModeHasExpectedProperties() {
        let mode = FormattingMode.formal
        #expect(mode.displayName == "Formal")
        let promptLower = mode.prompt.lowercased()
        #expect(promptLower.contains("formal") || promptLower.contains("professional"))
    }

    @Test func casualModeHasExpectedProperties() {
        let mode = FormattingMode.casual
        #expect(mode.displayName == "Casual")
        let promptLower = mode.prompt.lowercased()
        #expect(promptLower.contains("casual") || promptLower.contains("friendly") || promptLower.contains("conversational"))
    }

    // MARK: - Codable

    @Test func modeEncodesAndDecodes() throws {
        let mode = FormattingMode.email
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(mode)
        let decoded = try decoder.decode(FormattingMode.self, from: data)

        #expect(decoded == mode)
    }

    @Test func allModesAreEncodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for mode in FormattingMode.allCases {
            let data = try encoder.encode(mode)
            let decoded = try decoder.decode(FormattingMode.self, from: data)
            #expect(decoded == mode)
        }
    }

    // MARK: - Identifiable

    @Test func modesHaveUniqueIds() {
        let ids = FormattingMode.allCases.map { $0.id }
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count)
    }
}
