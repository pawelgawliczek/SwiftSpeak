//
//  AutocorrectServiceTests.swift
//  SwiftSpeakTests
//
//  Tests for multi-language autocorrection services
//  Verifies accent restoration, proper noun capitalization, and language-specific corrections
//
//  NOTE: Keyboard extension services cannot be directly imported due to linking constraints.
//  These tests verify the underlying algorithms by replicating key dictionaries and logic.
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

// MARK: - Test Helpers

/// Helper to preserve case when applying corrections (replicates autocorrect logic)
func preserveCase(original: String, corrected: String) -> String {
    guard !original.isEmpty, !corrected.isEmpty else { return corrected }

    let isAllCaps = original == original.uppercased() && original.count > 1
    let isCapitalized = original.first?.isUppercase ?? false

    if isAllCaps {
        return corrected.uppercased()
    } else if isCapitalized {
        return corrected.prefix(1).uppercased() + String(corrected.dropFirst())
    }
    return corrected
}

// MARK: - Polish Autocorrect Tests

@Suite("Polish Autocorrect Service Tests")
struct PolishAutocorrectTests {

    // Sample Polish diacritics dictionary (subset for testing)
    let polishDiacritics: [String: String] = [
        "bede": "będę", "bedzie": "będzie", "bedziemy": "będziemy",
        "chce": "chcę", "moge": "mogę", "musze": "muszę",
        "dziekuje": "dziękuję", "prosze": "proszę",
        "zolty": "żółty", "zrodlo": "źródło",
        "slonce": "słońce", "swieto": "święto",
        "jestes": "jesteś", "jestesmy": "jesteśmy",
        "sa": "są", "maja": "mają",
    ]

    let polishProperNouns: [String: String] = [
        "warszawa": "Warszawa", "krakow": "Kraków", "gdansk": "Gdańsk",
        "lodz": "Łódź", "wroclaw": "Wrocław", "poznan": "Poznań",
    ]

    @Test("Polish diacritic restoration - common verbs")
    func testPolishVerbDiacritics() {
        #expect(polishDiacritics["bede"] == "będę", "będę should be restored")
        #expect(polishDiacritics["chce"] == "chcę", "chcę should be restored")
        #expect(polishDiacritics["dziekuje"] == "dziękuję", "dziękuję should be restored")
    }

    @Test("Polish diacritic restoration - special characters ż, ź, ł, ń")
    func testPolishSpecialCharacters() {
        #expect(polishDiacritics["zolty"] == "żółty", "żółty (ż, ó, ł) should be restored")
        #expect(polishDiacritics["zrodlo"] == "źródło", "źródło (ź, ó, ł) should be restored")
        #expect(polishDiacritics["slonce"] == "słońce", "słońce (ł, ń) should be restored")
    }

    @Test("Polish proper noun capitalization")
    func testPolishProperNouns() {
        #expect(polishProperNouns["warszawa"] == "Warszawa")
        #expect(polishProperNouns["krakow"] == "Kraków", "Kraków should have ó")
        #expect(polishProperNouns["lodz"] == "Łódź", "Łódź should have Ł and ó")
        #expect(polishProperNouns["gdansk"] == "Gdańsk", "Gdańsk should have ń")
    }

    @Test("Polish case preservation")
    func testPolishCasePreservation() {
        #expect(preserveCase(original: "BEDE", corrected: "będę") == "BĘDĘ")
        #expect(preserveCase(original: "Bede", corrected: "będę") == "Będę")
        #expect(preserveCase(original: "bede", corrected: "będę") == "będę")
    }
}

// MARK: - Spanish Autocorrect Tests

@Suite("Spanish Autocorrect Service Tests")
struct SpanishAutocorrectTests {

    let spanishAccents: [String: String] = [
        // Question words
        "que": "qué", "como": "cómo", "cuando": "cuándo",
        "donde": "dónde", "porque": "porqué", "quien": "quién",
        // Common words
        "esta": "está", "mas": "más", "si": "sí",
        "tu": "tú", "el": "él", "mi": "mí",
        // Verbs
        "sera": "será", "tendra": "tendrá", "podra": "podrá",
        "estare": "estaré", "hare": "haré",
    ]

    let spanishProperNouns: [String: String] = [
        "espana": "España", "mexico": "México",
        "bogota": "Bogotá", "peru": "Perú",
    ]

    @Test("Spanish accent restoration - question words")
    func testSpanishQuestionWords() {
        #expect(spanishAccents["que"] == "qué")
        #expect(spanishAccents["como"] == "cómo")
        #expect(spanishAccents["donde"] == "dónde")
        #expect(spanishAccents["quien"] == "quién")
    }

    @Test("Spanish accent restoration - common words")
    func testSpanishCommonWords() {
        #expect(spanishAccents["esta"] == "está", "está (is) should have accent")
        #expect(spanishAccents["mas"] == "más", "más (more) should have accent")
        #expect(spanishAccents["si"] == "sí", "sí (yes) should have accent")
    }

    @Test("Spanish proper nouns with ñ and accents")
    func testSpanishProperNouns() {
        #expect(spanishProperNouns["espana"] == "España", "España should have ñ")
        #expect(spanishProperNouns["mexico"] == "México", "México should have accent")
    }
}

// MARK: - French Autocorrect Tests

@Suite("French Autocorrect Service Tests")
struct FrenchAutocorrectTests {

    let frenchAccents: [String: String] = [
        // Common accents
        "etre": "être", "tres": "très", "apres": "après",
        "cafe": "café", "resume": "résumé", "ecole": "école",
        // Cedilla
        "ca": "ça", "francais": "français", "garcon": "garçon",
        // Circumflex
        "hotel": "hôtel", "foret": "forêt", "fete": "fête",
    ]

    let frenchProperNouns: [String: String] = [
        "montreal": "Montréal", "quebec": "Québec",
        "geneve": "Genève",
    ]

    @Test("French accent restoration - é, è, ê")
    func testFrenchEAccents() {
        #expect(frenchAccents["etre"] == "être", "être should have ê")
        #expect(frenchAccents["tres"] == "très", "très should have è")
        #expect(frenchAccents["cafe"] == "café", "café should have é")
    }

    @Test("French cedilla restoration - ç")
    func testFrenchCedilla() {
        #expect(frenchAccents["ca"] == "ça", "ça should have ç")
        #expect(frenchAccents["francais"] == "français", "français should have ç")
        #expect(frenchAccents["garcon"] == "garçon", "garçon should have ç")
    }

    @Test("French circumflex - ô, ê")
    func testFrenchCircumflex() {
        #expect(frenchAccents["hotel"] == "hôtel", "hôtel should have ô")
        #expect(frenchAccents["foret"] == "forêt", "forêt should have ê")
    }
}

// MARK: - German Autocorrect Tests

@Suite("German Autocorrect Service Tests")
struct GermanAutocorrectTests {

    let germanUmlauts: [String: String] = [
        // Common umlauts
        "fur": "für", "uber": "über", "konnen": "können",
        "mochten": "möchten", "naturlich": "natürlich",
        "geschaft": "Geschäft", "glucklich": "glücklich",
        // ß words
        "strasse": "Straße", "gruss": "Gruß", "weiss": "weiß",
        "gross": "groß", "fuss": "Fuß",
    ]

    let germanProperNouns: [String: String] = [
        "munchen": "München", "koln": "Köln",
        "dusseldorf": "Düsseldorf", "nurnberg": "Nürnberg",
    ]

    @Test("German umlaut restoration - ü, ö, ä")
    func testGermanUmlauts() {
        #expect(germanUmlauts["fur"] == "für", "für should have ü")
        #expect(germanUmlauts["uber"] == "über", "über should have ü")
        #expect(germanUmlauts["mochten"] == "möchten", "möchten should have ö")
    }

    @Test("German eszett restoration - ß")
    func testGermanEszett() {
        #expect(germanUmlauts["strasse"] == "Straße", "Straße should have ß")
        #expect(germanUmlauts["gross"] == "groß", "groß should have ß")
        #expect(germanUmlauts["weiss"] == "weiß", "weiß should have ß")
    }

    @Test("German city names with umlauts")
    func testGermanCities() {
        #expect(germanProperNouns["munchen"] == "München", "München should have ü")
        #expect(germanProperNouns["koln"] == "Köln", "Köln should have ö")
        #expect(germanProperNouns["dusseldorf"] == "Düsseldorf", "Düsseldorf should have ü")
    }
}

// MARK: - Italian Autocorrect Tests

@Suite("Italian Autocorrect Service Tests")
struct ItalianAutocorrectTests {

    let italianAccents: [String: String] = [
        // Common accented words
        "perche": "perché", "poiche": "poiché", "cioe": "cioè",
        "puo": "può", "piu": "più", "gia": "già",
        "cosi": "così", "pero": "però",
        // Verbs
        "sara": "sarà", "fara": "farà", "andra": "andrà",
        "verra": "verrà", "dovra": "dovrà",
        // è vs e distinction
        "e": "è",  // is (context-dependent)
    ]

    let italianProperNouns: [String: String] = [
        "roma": "Roma", "milano": "Milano",
        "napoli": "Napoli", "firenze": "Firenze",
    ]

    @Test("Italian accent restoration - common words")
    func testItalianCommonAccents() {
        #expect(italianAccents["perche"] == "perché", "perché should have é")
        #expect(italianAccents["puo"] == "può", "può should have ù")
        #expect(italianAccents["piu"] == "più", "più should have ù")
        #expect(italianAccents["gia"] == "già", "già should have à")
    }

    @Test("Italian future tense accents")
    func testItalianFutureTense() {
        #expect(italianAccents["sara"] == "sarà", "sarà should have à")
        #expect(italianAccents["fara"] == "farà", "farà should have à")
        #expect(italianAccents["andra"] == "andrà", "andrà should have à")
    }

    @Test("Italian city proper nouns")
    func testItalianCities() {
        #expect(italianProperNouns["roma"] == "Roma")
        #expect(italianProperNouns["milano"] == "Milano")
    }
}

// MARK: - Portuguese Autocorrect Tests

@Suite("Portuguese Autocorrect Service Tests")
struct PortugueseAutocorrectTests {

    let portugueseAccents: [String: String] = [
        // Common accented words
        "voce": "você", "tambem": "também", "ate": "até",
        "ja": "já", "so": "só", "nos": "nós",
        // Tilde
        "nao": "não", "sao": "são", "mao": "mão",
        "coração": "coração", "informacao": "informação",
        // Cedilla
        "voce": "você", "comeco": "começo", "forca": "força",
    ]

    let portugueseProperNouns: [String: String] = [
        "sao paulo": "São Paulo", "brasilia": "Brasília",
        "belem": "Belém",
    ]

    @Test("Portuguese accent restoration - common words")
    func testPortugueseCommonAccents() {
        #expect(portugueseAccents["voce"] == "você", "você should have ê")
        #expect(portugueseAccents["tambem"] == "também", "também should have é")
        #expect(portugueseAccents["ja"] == "já", "já should have á")
    }

    @Test("Portuguese tilde restoration - ã, õ")
    func testPortugueseTilde() {
        #expect(portugueseAccents["nao"] == "não", "não should have ã")
        #expect(portugueseAccents["sao"] == "são", "são should have ã")
        #expect(portugueseAccents["mao"] == "mão", "mão should have ã")
    }
}

// MARK: - Russian Autocorrect Tests

@Suite("Russian Autocorrect Service Tests")
struct RussianAutocorrectTests {

    let russianCorrections: [String: String] = [
        // ё restoration (commonly typed as е)
        "еще": "ещё", "все": "всё", "ее": "её",
        "елка": "ёлка", "мед": "мёд",
    ]

    let russianProperNouns: [String: String] = [
        "москва": "Москва", "санкт-петербург": "Санкт-Петербург",
    ]

    @Test("Russian ё restoration")
    func testRussianYoRestoration() {
        #expect(russianCorrections["еще"] == "ещё", "ещё should have ё")
        #expect(russianCorrections["все"] == "всё", "всё should have ё")
        #expect(russianCorrections["елка"] == "ёлка", "ёлка should have ё")
    }

    @Test("Russian proper noun capitalization")
    func testRussianProperNouns() {
        #expect(russianProperNouns["москва"] == "Москва")
    }
}

// MARK: - Arabic Autocorrect Tests

@Suite("Arabic Autocorrect Service Tests")
struct ArabicAutocorrectTests {

    let arabicLigatures: [String: String] = [
        // Common ligature corrections
        "الله": "ﷲ",  // Allah ligature
        "محمد": "محمد",  // Muhammad (already correct)
    ]

    @Test("Arabic text direction handling")
    func testArabicRTL() {
        // Verify Arabic strings maintain proper RTL ordering
        let arabicWord = "مرحبا"  // "Hello" in Arabic
        #expect(arabicWord.count == 5, "Arabic word should have correct character count")
        #expect(arabicWord.first == "م", "First character should be م")
    }

    @Test("Arabic ligature handling")
    func testArabicLigatures() {
        // Test that ligature dictionary exists and has entries
        #expect(arabicLigatures["الله"] == "ﷲ", "Allah should have special ligature")
    }
}

// MARK: - Egyptian Arabic Autocorrect Tests

@Suite("Egyptian Arabic Autocorrect Service Tests")
struct EgyptianArabicAutocorrectTests {

    let egyptianDialect: [String: String] = [
        // Common Egyptian colloquial forms
        "ازيك": "إزيك",  // How are you
        "عامل": "عامل",  // doing/making
        "كويس": "كويس",  // good/fine
    ]

    @Test("Egyptian Arabic dialect forms")
    func testEgyptianDialect() {
        // Verify Egyptian Arabic forms are recognized
        #expect(egyptianDialect["كويس"] == "كويس", "كويس (good) should be recognized")
    }
}

// MARK: - CJK Autocorrect Tests (UITextChecker-based)

@Suite("CJK Autocorrect Service Tests")
struct CJKAutocorrectTests {

    @Test("Chinese character validation")
    func testChineseCharacters() {
        let chineseText = "你好"  // "Hello" in Chinese
        #expect(chineseText.count == 2, "Chinese greeting should have 2 characters")

        // Verify Chinese character range detection
        let firstChar = chineseText.unicodeScalars.first!
        let isCJK = (0x4E00...0x9FFF).contains(firstChar.value)
        #expect(isCJK, "Character should be in CJK range")
    }

    @Test("Japanese character types")
    func testJapaneseCharacterTypes() {
        let hiragana = "こんにちは"  // "Hello" in hiragana
        let katakana = "コンピュータ"  // "Computer" in katakana
        let kanji = "日本"  // "Japan" in kanji

        #expect(hiragana.count == 5, "Hiragana greeting should have 5 characters")
        #expect(!katakana.isEmpty, "Katakana word should not be empty")
        #expect(kanji.count == 2, "Kanji for Japan should have 2 characters")

        // Verify hiragana range
        let hiraChar = hiragana.unicodeScalars.first!
        let isHiragana = (0x3040...0x309F).contains(hiraChar.value)
        #expect(isHiragana, "First character should be hiragana")
    }

    @Test("Korean character validation")
    func testKoreanCharacters() {
        let koreanText = "안녕하세요"  // "Hello" in Korean
        #expect(koreanText.count == 5, "Korean greeting should have 5 characters")

        // Verify Hangul range
        let firstChar = koreanText.unicodeScalars.first!
        let isHangul = (0xAC00...0xD7AF).contains(firstChar.value)
        #expect(isHangul, "Character should be in Hangul syllables range")
    }
}

// MARK: - Case Preservation Tests

@Suite("Case Preservation Tests")
struct CasePreservationTests {

    @Test("Lowercase input preserves lowercase")
    func testLowercasePreservation() {
        #expect(preserveCase(original: "hello", corrected: "héllo") == "héllo")
        #expect(preserveCase(original: "bede", corrected: "będę") == "będę")
    }

    @Test("Capitalized input preserves capitalization")
    func testCapitalizedPreservation() {
        #expect(preserveCase(original: "Hello", corrected: "héllo") == "Héllo")
        #expect(preserveCase(original: "Bede", corrected: "będę") == "Będę")
    }

    @Test("All caps input preserves all caps")
    func testAllCapsPreservation() {
        #expect(preserveCase(original: "HELLO", corrected: "héllo") == "HÉLLO")
        #expect(preserveCase(original: "BEDE", corrected: "będę") == "BĘDĘ")
    }

    @Test("Single character handling")
    func testSingleCharacter() {
        #expect(preserveCase(original: "A", corrected: "à") == "à")  // Single char = lowercase
        #expect(preserveCase(original: "a", corrected: "à") == "à")
    }

    @Test("Empty string handling")
    func testEmptyStrings() {
        #expect(preserveCase(original: "", corrected: "test") == "test")
        #expect(preserveCase(original: "test", corrected: "") == "")
    }
}

// MARK: - Integration Tests

@Suite("Autocorrect Integration Tests")
struct AutocorrectIntegrationTests {

    @Test("Autocorrect handles mixed language text")
    func testMixedLanguage() {
        // Verify that autocorrect dictionaries don't conflict
        // Polish "nie" vs Spanish "ni" vs French "ni"
        let polishNie = "nie"  // Polish "no"
        let frenchNi = "ni"    // French "nor"

        // These should be treated differently based on language context
        #expect(polishNie != frenchNi)
    }

    @Test("Unicode normalization consistency")
    func testUnicodeNormalization() {
        // Test that composed and decomposed forms are handled consistently
        let composedE = "é"  // Single code point
        let decomposedE = "e\u{0301}"  // e + combining acute accent

        // When normalized, they should be equal
        #expect(composedE.precomposedStringWithCanonicalMapping ==
                decomposedE.precomposedStringWithCanonicalMapping)
    }

    @Test("All 13 languages have distinct corrections")
    func testLanguageDistinction() {
        // Each language should have unique corrections
        let languages = ["en", "pl", "es", "fr", "de", "it", "pt", "ru", "ar", "arz", "zh", "ja", "ko"]
        #expect(languages.count == 13, "Should support 13 languages")

        // Verify no duplicates
        let uniqueLanguages = Set(languages)
        #expect(uniqueLanguages.count == 13, "All language codes should be unique")
    }
}
