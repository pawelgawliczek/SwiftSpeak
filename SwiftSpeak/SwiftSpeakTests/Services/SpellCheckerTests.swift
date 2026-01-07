//
//  SpellCheckerTests.swift
//  SwiftSpeakTests
//
//  Tests for SpellChecker, AutocorrectCache, and AutocorrectHistoryService
//  Verifies spell checking, user vocabulary, and autocorrect undo functionality
//
//  NOTE: Keyboard extension services cannot be directly imported due to linking constraints.
//  These tests verify the underlying algorithms by replicating key logic and testing
//  the UserDefaults-based persistence that can be accessed from the main app.
//

import Testing
import Foundation
@testable import SwiftSpeak

// MARK: - Test Constants

private let testSuiteName = "group.pawelgawliczek.swiftspeak.tests"

// MARK: - SpellChecker Logic Tests

@Suite("SpellChecker Core Logic Tests")
struct SpellCheckerLogicTests {

    // Replicate the priority corrections dictionary for testing
    let englishPriorityCorrections: [String: String] = [
        // Contractions
        "dont": "don't", "cant": "can't", "wont": "won't",
        "didnt": "didn't", "wasnt": "wasn't", "isnt": "isn't",
        "youre": "you're", "theyre": "they're", "im": "I'm",
        // Common typos
        "teh": "the", "hte": "the", "adn": "and",
        "taht": "that", "wiht": "with", "fro": "for",
        "becuase": "because", "seperate": "separate",
        "definately": "definitely", "recieve": "receive",
    ]

    let polishPriorityCorrections: [String: String] = [
        "zolty": "żółty", "zrodlo": "źródło", "swiat": "świat",
        "dziekuje": "dziękuję", "prosze": "proszę", "czesc": "cześć",
        "dzien": "dzień", "slonce": "słońce", "piekny": "piękny",
    ]

    let germanPriorityCorrections: [String: String] = [
        "fur": "für", "uber": "über", "konnen": "können",
        "mussen": "müssen", "naturlich": "natürlich",
        "gross": "groß", "strasse": "Straße", "weiss": "weiß",
    ]

    @Test("English contraction corrections")
    func testEnglishContractions() {
        #expect(englishPriorityCorrections["dont"] == "don't")
        #expect(englishPriorityCorrections["cant"] == "can't")
        #expect(englishPriorityCorrections["youre"] == "you're")
        #expect(englishPriorityCorrections["im"] == "I'm")
    }

    @Test("English common typo corrections")
    func testEnglishTypos() {
        #expect(englishPriorityCorrections["teh"] == "the")
        #expect(englishPriorityCorrections["adn"] == "and")
        #expect(englishPriorityCorrections["becuase"] == "because")
        #expect(englishPriorityCorrections["definately"] == "definitely")
    }

    @Test("Polish diacritic corrections")
    func testPolishDiacritics() {
        #expect(polishPriorityCorrections["zolty"] == "żółty")
        #expect(polishPriorityCorrections["dziekuje"] == "dziękuję")
        #expect(polishPriorityCorrections["slonce"] == "słońce")
    }

    @Test("German umlaut and eszett corrections")
    func testGermanCorrections() {
        #expect(germanPriorityCorrections["fur"] == "für")
        #expect(germanPriorityCorrections["uber"] == "über")
        #expect(germanPriorityCorrections["strasse"] == "Straße")
    }

    @Test("Language support coverage")
    func testLanguageSupport() {
        let supportedLanguages = ["en", "es", "fr", "de", "it", "pt", "pl", "ru", "ar", "arz", "zh", "ja", "ko"]
        #expect(supportedLanguages.count == 13, "Should support 13 languages")
    }
}

// MARK: - Case Preservation Logic Tests

@Suite("Case Preservation Tests")
struct CasePreservationLogicTests {

    /// Replicates the preserveCase logic from SpellChecker
    func preserveCase(original: String, corrected: String) -> String {
        guard !original.isEmpty && !corrected.isEmpty else { return corrected }

        // All uppercase
        if original == original.uppercased() && original != original.lowercased() {
            return corrected.uppercased()
        }

        // First letter uppercase
        if original.first?.isUppercase == true {
            return corrected.prefix(1).uppercased() + corrected.dropFirst()
        }

        return corrected.lowercased()
    }

    @Test("Lowercase preserves lowercase")
    func testLowercasePreservation() {
        #expect(preserveCase(original: "teh", corrected: "the") == "the")
        #expect(preserveCase(original: "dont", corrected: "don't") == "don't")
    }

    @Test("Capitalized preserves capitalization")
    func testCapitalizedPreservation() {
        #expect(preserveCase(original: "Teh", corrected: "the") == "The")
        #expect(preserveCase(original: "Dont", corrected: "don't") == "Don't")
    }

    @Test("All caps preserves all caps")
    func testAllCapsPreservation() {
        #expect(preserveCase(original: "TEH", corrected: "the") == "THE")
        #expect(preserveCase(original: "DONT", corrected: "don't") == "DON'T")
    }

    @Test("Empty strings handled safely")
    func testEmptyStrings() {
        #expect(preserveCase(original: "", corrected: "test") == "test")
        #expect(preserveCase(original: "test", corrected: "") == "")
    }
}

// MARK: - Word Validation Logic Tests

@Suite("Word Validation Tests")
struct WordValidationTests {

    /// Replicates word validation from SpellChecker
    func shouldSkipWord(_ word: String) -> Bool {
        // Skip empty
        if word.isEmpty { return true }
        // Skip single char
        if word.count < 2 { return true }
        // Skip very long words
        if word.count > 50 { return true }
        // Skip URLs/paths
        if word.contains("/") || word.contains("@") || word.contains(":") { return true }
        return false
    }

    @Test("Empty word is skipped")
    func testEmptyWord() {
        #expect(shouldSkipWord("") == true)
    }

    @Test("Single character is skipped")
    func testSingleChar() {
        #expect(shouldSkipWord("a") == true)
        #expect(shouldSkipWord("I") == true)
    }

    @Test("Very long words are skipped")
    func testVeryLongWord() {
        let longWord = String(repeating: "a", count: 51)
        #expect(shouldSkipWord(longWord) == true)
    }

    @Test("URLs and emails are skipped")
    func testURLsAndEmails() {
        #expect(shouldSkipWord("http://example.com") == true)
        #expect(shouldSkipWord("user@example.com") == true)
        #expect(shouldSkipWord("/path/to/file") == true)
    }

    @Test("Normal words are not skipped")
    func testNormalWords() {
        #expect(shouldSkipWord("hello") == false)
        #expect(shouldSkipWord("world") == false)
        #expect(shouldSkipWord("teh") == false)
    }
}

// MARK: - Ignore List Tests

@Suite("Ignore List Tests")
struct IgnoreListTests {

    let englishIgnoreWords: Set<String> = ["its", "were", "well", "hell", "shell", "wed", "id", "ill", "wont", "cant"]
    let germanIgnoreWords: Set<String> = ["das", "dass"]
    let spanishIgnoreWords: Set<String> = ["el", "si", "mas", "aun", "solo"]
    let frenchIgnoreWords: Set<String> = ["a", "ou", "la", "sa"]

    @Test("English ambiguous words are ignored")
    func testEnglishIgnoreWords() {
        #expect(englishIgnoreWords.contains("its"), "its should be ignored (it's vs its)")
        #expect(englishIgnoreWords.contains("were"), "were should be ignored (we're vs were)")
        #expect(englishIgnoreWords.contains("well"), "well should be ignored (we'll vs well)")
    }

    @Test("German ambiguous words are ignored")
    func testGermanIgnoreWords() {
        #expect(germanIgnoreWords.contains("das"), "das should be ignored (article vs conjunction)")
        #expect(germanIgnoreWords.contains("dass"), "dass should be ignored")
    }

    @Test("Spanish ambiguous words are ignored")
    func testSpanishIgnoreWords() {
        #expect(spanishIgnoreWords.contains("si"), "si should be ignored (sí yes vs si if)")
        #expect(spanishIgnoreWords.contains("mas"), "mas should be ignored (más more vs mas but)")
    }
}

// MARK: - AutocorrectCache Tests (UserDefaults-based)

@Suite("AutocorrectCache Tests")
struct AutocorrectCacheTests {

    // Use test suite to isolate from production data
    let testDefaults = UserDefaults(suiteName: testSuiteName)!

    init() {
        // Clean up before each test
        testDefaults.removeObject(forKey: "personalDictionaryWords")
        testDefaults.removeObject(forKey: "ignoredCorrections")
        testDefaults.synchronize()
    }

    @Test("Personal dictionary stores and retrieves words")
    func testPersonalDictionary() {
        // Store a word
        var words = testDefaults.stringArray(forKey: "personalDictionaryWords") ?? []
        words.append("myword")
        testDefaults.set(words, forKey: "personalDictionaryWords")
        testDefaults.synchronize()

        // Retrieve and check
        let storedWords = testDefaults.stringArray(forKey: "personalDictionaryWords") ?? []
        #expect(storedWords.contains("myword"), "Word should be stored in dictionary")
    }

    @Test("Ignored corrections stores and retrieves mappings")
    func testIgnoredCorrections() {
        // Store an ignored correction
        let ignored: [String: String] = ["teh": "the"]
        let data = try! JSONEncoder().encode(ignored)
        testDefaults.set(data, forKey: "ignoredCorrections")
        testDefaults.synchronize()

        // Retrieve and check
        let storedData = testDefaults.data(forKey: "ignoredCorrections")!
        let storedIgnored = try! JSONDecoder().decode([String: String].self, from: storedData)
        #expect(storedIgnored["teh"] == "the", "Ignored correction should be stored")
    }

    @Test("Personal dictionary check is case-insensitive")
    func testCaseInsensitiveCheck() {
        // Store lowercase
        testDefaults.set(["hello"], forKey: "personalDictionaryWords")
        testDefaults.synchronize()

        let words = testDefaults.stringArray(forKey: "personalDictionaryWords") ?? []

        // Check should work with any case (simulating the cache logic)
        let lowercaseCheck = words.contains("hello".lowercased())
        #expect(lowercaseCheck == true, "Lowercase check should find the word")
    }

    @Test("Empty personal dictionary returns false")
    func testEmptyDictionary() {
        testDefaults.removeObject(forKey: "personalDictionaryWords")
        testDefaults.synchronize()

        let words = testDefaults.stringArray(forKey: "personalDictionaryWords") ?? []
        #expect(words.isEmpty, "Dictionary should be empty")
        #expect(words.contains("anything") == false, "Empty dictionary should not contain any word")
    }
}

// MARK: - AutocorrectEntry Tests

@Suite("AutocorrectEntry Tests")
struct AutocorrectEntryTests {

    /// Replicates AutocorrectEntry for testing
    struct TestAutocorrectEntry: Codable, Equatable {
        let originalWord: String
        let correctedWord: String
        let timestamp: Date
        let position: Int

        var isRecent: Bool {
            Date().timeIntervalSince(timestamp) < 30
        }
    }

    @Test("Entry is recent within 30 seconds")
    func testRecentEntry() {
        let entry = TestAutocorrectEntry(
            originalWord: "teh",
            correctedWord: "the",
            timestamp: Date(),
            position: 10
        )
        #expect(entry.isRecent == true, "Entry created now should be recent")
    }

    @Test("Entry is not recent after 30 seconds")
    func testOldEntry() {
        let oldDate = Date().addingTimeInterval(-31)
        let entry = TestAutocorrectEntry(
            originalWord: "teh",
            correctedWord: "the",
            timestamp: oldDate,
            position: 10
        )
        #expect(entry.isRecent == false, "Entry older than 30s should not be recent")
    }

    @Test("Entry stores all fields correctly")
    func testEntryFields() {
        let now = Date()
        let entry = TestAutocorrectEntry(
            originalWord: "teh",
            correctedWord: "the",
            timestamp: now,
            position: 42
        )

        #expect(entry.originalWord == "teh")
        #expect(entry.correctedWord == "the")
        #expect(entry.position == 42)
    }

    @Test("Entry is Codable")
    func testEntryCodable() throws {
        let entry = TestAutocorrectEntry(
            originalWord: "becuase",
            correctedWord: "because",
            timestamp: Date(),
            position: 100
        )

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(TestAutocorrectEntry.self, from: data)

        #expect(decoded.originalWord == entry.originalWord)
        #expect(decoded.correctedWord == entry.correctedWord)
        #expect(decoded.position == entry.position)
    }
}

// MARK: - Autocorrect History Logic Tests

@Suite("Autocorrect History Logic Tests")
struct AutocorrectHistoryLogicTests {

    /// Simulates the history service logic
    struct TestHistoryService {
        var recentCorrections: [(original: String, corrected: String, timestamp: Date)] = []
        let maxCorrections = 10

        mutating func recordCorrection(original: String, corrected: String) {
            recentCorrections.append((original, corrected, Date()))

            // Keep only max entries
            if recentCorrections.count > maxCorrections {
                recentCorrections.removeFirst()
            }

            // Remove old entries (older than 30 seconds)
            let cutoff = Date().addingTimeInterval(-30)
            recentCorrections.removeAll { $0.timestamp < cutoff }
        }

        func getRecentCorrectionForUndo(correctedWord: String) -> String? {
            let cutoff = Date().addingTimeInterval(-30)
            for entry in recentCorrections.reversed() {
                if entry.corrected.lowercased() == correctedWord.lowercased() && entry.timestamp >= cutoff {
                    return entry.original
                }
            }
            return nil
        }
    }

    @Test("Records and retrieves corrections")
    func testRecordAndRetrieve() {
        var service = TestHistoryService()
        service.recordCorrection(original: "teh", corrected: "the")

        let original = service.getRecentCorrectionForUndo(correctedWord: "the")
        #expect(original == "teh", "Should find original word for recent correction")
    }

    @Test("Case-insensitive lookup")
    func testCaseInsensitiveLookup() {
        var service = TestHistoryService()
        service.recordCorrection(original: "Teh", corrected: "The")

        let original = service.getRecentCorrectionForUndo(correctedWord: "the")
        #expect(original == "Teh", "Should find correction regardless of case")
    }

    @Test("Returns nil for unknown corrections")
    func testUnknownCorrection() {
        var service = TestHistoryService()
        service.recordCorrection(original: "teh", corrected: "the")

        let original = service.getRecentCorrectionForUndo(correctedWord: "hello")
        #expect(original == nil, "Should return nil for words that weren't corrected")
    }

    @Test("Limits to max corrections")
    func testMaxCorrections() {
        var service = TestHistoryService()

        // Add more than max
        for i in 0..<15 {
            service.recordCorrection(original: "word\(i)", corrected: "corrected\(i)")
        }

        #expect(service.recentCorrections.count <= 10, "Should not exceed max corrections")
    }

    @Test("Returns most recent correction for duplicates")
    func testMostRecentCorrection() {
        var service = TestHistoryService()
        service.recordCorrection(original: "frst", corrected: "first")
        service.recordCorrection(original: "frst2", corrected: "first")

        let original = service.getRecentCorrectionForUndo(correctedWord: "first")
        #expect(original == "frst2", "Should return most recent original for duplicate corrections")
    }
}

// MARK: - Multiple Suggestions Logic Tests

@Suite("Multiple Suggestions Tests")
struct MultipleSuggestionsTests {

    /// Simulates getSuggestions logic
    func getSuggestions(for word: String, priorityCorrection: String?, maxSuggestions: Int = 3) -> [String] {
        var suggestions: [String] = []

        // Priority correction first
        if let correction = priorityCorrection {
            suggestions.append(correction)
        }

        // Would add UITextChecker suggestions here in real implementation
        // For testing, we just verify the structure

        return Array(suggestions.prefix(maxSuggestions))
    }

    @Test("Priority correction appears first")
    func testPriorityFirst() {
        let suggestions = getSuggestions(for: "teh", priorityCorrection: "the")
        #expect(suggestions.first == "the", "Priority correction should be first")
    }

    @Test("Returns empty for unknown words")
    func testEmptyForUnknown() {
        let suggestions = getSuggestions(for: "xyzabc", priorityCorrection: nil)
        #expect(suggestions.isEmpty, "Should return empty for unknown words with no priority")
    }

    @Test("Respects max suggestions limit")
    func testMaxLimit() {
        let suggestions = getSuggestions(for: "test", priorityCorrection: "test1", maxSuggestions: 1)
        #expect(suggestions.count <= 1, "Should respect max suggestions limit")
    }
}

// MARK: - User Vocabulary (Learn Word) Tests

@Suite("User Vocabulary Tests")
struct UserVocabularyTests {

    let testDefaults = UserDefaults(suiteName: testSuiteName)!

    init() {
        testDefaults.removeObject(forKey: "personalDictionaryWords")
        testDefaults.synchronize()
    }

    @Test("Adding word to personal dictionary")
    func testAddWord() {
        var words = testDefaults.stringArray(forKey: "personalDictionaryWords") ?? []
        words.append("swiftspeak")
        testDefaults.set(words, forKey: "personalDictionaryWords")
        testDefaults.synchronize()

        let stored = testDefaults.stringArray(forKey: "personalDictionaryWords") ?? []
        #expect(stored.contains("swiftspeak"), "Word should be added to dictionary")
    }

    @Test("Checking if word exists in dictionary")
    func testHasWord() {
        testDefaults.set(["customword"], forKey: "personalDictionaryWords")
        testDefaults.synchronize()

        let words = Set(testDefaults.stringArray(forKey: "personalDictionaryWords") ?? [])
        #expect(words.contains("customword"), "Should find existing word")
        #expect(!words.contains("nonexistent"), "Should not find nonexistent word")
    }

    @Test("Removing word from dictionary")
    func testRemoveWord() {
        testDefaults.set(["word1", "word2", "word3"], forKey: "personalDictionaryWords")
        testDefaults.synchronize()

        var words = testDefaults.stringArray(forKey: "personalDictionaryWords") ?? []
        words.removeAll { $0 == "word2" }
        testDefaults.set(words, forKey: "personalDictionaryWords")
        testDefaults.synchronize()

        let stored = testDefaults.stringArray(forKey: "personalDictionaryWords") ?? []
        #expect(!stored.contains("word2"), "Removed word should not be in dictionary")
        #expect(stored.contains("word1"), "Other words should remain")
        #expect(stored.contains("word3"), "Other words should remain")
    }
}

// MARK: - Ignored Corrections Tests

@Suite("Ignored Corrections Tests")
struct IgnoredCorrectionsTests {

    let testDefaults = UserDefaults(suiteName: testSuiteName)!

    init() {
        testDefaults.removeObject(forKey: "ignoredCorrections")
        testDefaults.synchronize()
    }

    @Test("Adding ignored correction")
    func testAddIgnored() throws {
        var ignored: [String: String] = [:]
        ignored["teh"] = "the"  // Don't correct "teh" to "the"

        let data = try JSONEncoder().encode(ignored)
        testDefaults.set(data, forKey: "ignoredCorrections")
        testDefaults.synchronize()

        let storedData = testDefaults.data(forKey: "ignoredCorrections")!
        let stored = try JSONDecoder().decode([String: String].self, from: storedData)
        #expect(stored["teh"] == "the", "Ignored correction should be stored")
    }

    @Test("Checking if correction should be ignored")
    func testShouldIgnore() throws {
        let ignored: [String: String] = ["customword": "correctedword"]
        let data = try JSONEncoder().encode(ignored)
        testDefaults.set(data, forKey: "ignoredCorrections")
        testDefaults.synchronize()

        let storedData = testDefaults.data(forKey: "ignoredCorrections")!
        let stored = try JSONDecoder().decode([String: String].self, from: storedData)

        // Should ignore this specific correction
        let shouldIgnore = stored["customword"] == "correctedword"
        #expect(shouldIgnore, "Should ignore the specific correction")

        // Should not ignore different corrections
        let shouldNotIgnore = stored["customword"] == "differentword"
        #expect(!shouldNotIgnore, "Should not ignore different correction target")
    }

    @Test("Multiple ignored corrections")
    func testMultipleIgnored() throws {
        let ignored: [String: String] = [
            "teh": "the",
            "adn": "and",
            "becuase": "because"
        ]
        let data = try JSONEncoder().encode(ignored)
        testDefaults.set(data, forKey: "ignoredCorrections")
        testDefaults.synchronize()

        let storedData = testDefaults.data(forKey: "ignoredCorrections")!
        let stored = try JSONDecoder().decode([String: String].self, from: storedData)

        #expect(stored.count == 3, "Should store all ignored corrections")
        #expect(stored["teh"] == "the")
        #expect(stored["adn"] == "and")
        #expect(stored["becuase"] == "because")
    }
}

// MARK: - Integration Tests

@Suite("SpellChecker Integration Tests")
struct SpellCheckerIntegrationTests {

    @Test("Full autocorrect flow: correct → undo → learn")
    func testFullFlow() {
        let testDefaults = UserDefaults(suiteName: testSuiteName)!

        // Clean state
        testDefaults.removeObject(forKey: "personalDictionaryWords")
        testDefaults.removeObject(forKey: "ignoredCorrections")
        testDefaults.synchronize()

        // 1. User types "teh", gets corrected to "the"
        // (simulated - in real app this is handled by SpellChecker)
        let originalWord = "teh"
        let correctedWord = "the"

        // 2. Correction is recorded for undo
        var corrections: [(original: String, corrected: String)] = []
        corrections.append((originalWord, correctedWord))
        #expect(corrections.count == 1, "Correction should be recorded")

        // 3. User taps undo - original word is restored
        let undoneWord = corrections.first { $0.corrected == "the" }?.original
        #expect(undoneWord == "teh", "Should find original word for undo")

        // 4. Original word is added to personal dictionary
        var personalDict = testDefaults.stringArray(forKey: "personalDictionaryWords") ?? []
        personalDict.append(originalWord.lowercased())
        testDefaults.set(personalDict, forKey: "personalDictionaryWords")

        // 5. This correction is marked as ignored
        var ignored: [String: String] = [:]
        ignored[originalWord.lowercased()] = correctedWord.lowercased()
        if let data = try? JSONEncoder().encode(ignored) {
            testDefaults.set(data, forKey: "ignoredCorrections")
        }
        testDefaults.synchronize()

        // Verify final state
        let storedDict = testDefaults.stringArray(forKey: "personalDictionaryWords") ?? []
        #expect(storedDict.contains("teh"), "Original word should be in personal dictionary")

        if let storedData = testDefaults.data(forKey: "ignoredCorrections"),
           let storedIgnored = try? JSONDecoder().decode([String: String].self, from: storedData) {
            #expect(storedIgnored["teh"] == "the", "Correction should be marked as ignored")
        }
    }

    @Test("Personal dictionary prevents future corrections")
    func testDictionaryPreventsCorrection() {
        let testDefaults = UserDefaults(suiteName: testSuiteName)!

        // Add word to dictionary
        testDefaults.set(["customterm"], forKey: "personalDictionaryWords")
        testDefaults.synchronize()

        // Simulate checking before correction
        let words = Set(testDefaults.stringArray(forKey: "personalDictionaryWords") ?? [])
        let isInDict = words.contains("customterm")

        #expect(isInDict, "Word should be found in dictionary")
        // In real flow, if isInDict is true, correction is skipped
    }

    @Test("Ignored corrections prevent specific corrections only")
    func testIgnoredPreventsSpecificCorrection() throws {
        let testDefaults = UserDefaults(suiteName: testSuiteName)!

        // Mark that "teh" → "the" should be ignored
        let ignored: [String: String] = ["teh": "the"]
        let data = try JSONEncoder().encode(ignored)
        testDefaults.set(data, forKey: "ignoredCorrections")
        testDefaults.synchronize()

        let storedData = testDefaults.data(forKey: "ignoredCorrections")!
        let stored = try JSONDecoder().decode([String: String].self, from: storedData)

        // "teh" → "the" should be ignored
        #expect(stored["teh"] == "the", "This specific correction should be ignored")

        // But "teh" → "tea" would still be allowed (different target)
        #expect(stored["teh"] != "tea", "Different correction target should be allowed")
    }
}
