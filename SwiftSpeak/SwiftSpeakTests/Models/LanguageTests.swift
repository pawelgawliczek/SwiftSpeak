//
//  LanguageTests.swift
//  SwiftSpeakTests
//
//  Tests for Language enum
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

struct LanguageTests {

    // MARK: - Basic Properties

    @Test func allLanguagesHaveDisplayNames() {
        for language in Language.allCases {
            #expect(!language.displayName.isEmpty)
        }
    }

    @Test func allLanguagesHaveFlags() {
        for language in Language.allCases {
            #expect(!language.flag.isEmpty)
        }
    }

    // MARK: - Specific Languages

    @Test func englishHasExpectedProperties() {
        let lang = Language.english
        #expect(lang.displayName == "English")
        #expect(lang.flag == "🇺🇸")
    }

    @Test func spanishHasExpectedProperties() {
        let lang = Language.spanish
        #expect(lang.displayName == "Spanish")
        #expect(lang.flag == "🇪🇸")
    }

    @Test func polishHasExpectedProperties() {
        let lang = Language.polish
        #expect(lang.displayName == "Polish")
        #expect(lang.flag == "🇵🇱")
    }

    // MARK: - All Languages Have Flags

    @Test func languageFlagsAreEmoji() {
        for language in Language.allCases {
            // Flags should be emoji (at least 1 character)
            #expect(language.flag.count >= 1)
        }
    }

    // MARK: - Codable

    @Test func languageEncodesAndDecodes() throws {
        let language = Language.spanish
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(language)
        let decoded = try decoder.decode(Language.self, from: data)

        #expect(decoded == language)
    }

    @Test func allLanguagesAreEncodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for language in Language.allCases {
            let data = try encoder.encode(language)
            let decoded = try decoder.decode(Language.self, from: data)
            #expect(decoded == language)
        }
    }

    // MARK: - Identifiable

    @Test func languagesHaveUniqueIds() {
        let ids = Language.allCases.map { $0.id }
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count)
    }

    // MARK: - Language Count

    @Test func allLanguagesEnumerated() {
        // Verify we have a reasonable number of languages
        #expect(Language.allCases.count >= 5)
    }
}
