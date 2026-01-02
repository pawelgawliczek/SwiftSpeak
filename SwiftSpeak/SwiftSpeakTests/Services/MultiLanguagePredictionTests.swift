//
//  MultiLanguagePredictionTests.swift
//  SwiftSpeakTests
//
//  Tests for multi-language N-gram prediction and context-aware predictions
//  Verifies lazy loading, language-specific n-grams, and vocabulary support
//
//  NOTE: Keyboard extension services cannot be directly imported due to linking constraints.
//  These tests verify the underlying algorithms and data structures.
//

import Testing
import Foundation
@testable import SwiftSpeak

// MARK: - N-Gram Data Structure Tests

@Suite("N-Gram Data Structure Tests")
struct NGramDataTests {

    // Simulate NGramData structure
    struct NGramData {
        var unigrams: [String: Int] = [:]
        var bigrams: [String: [String: Int]] = [:]
        var trigrams: [String: [String: Int]] = [:]
    }

    @Test("N-gram data structure stores unigrams correctly")
    func testUnigramStorage() {
        var data = NGramData()
        data.unigrams["hello"] = 100
        data.unigrams["world"] = 50

        #expect(data.unigrams["hello"] == 100)
        #expect(data.unigrams["world"] == 50)
        #expect(data.unigrams["missing"] == nil)
    }

    @Test("N-gram data structure stores bigrams correctly")
    func testBigramStorage() {
        var data = NGramData()
        data.bigrams["hello", default: [:]][" world"] = 80
        data.bigrams["hello", default: [:]][" there"] = 60

        #expect(data.bigrams["hello"]?["world"] == nil)  // Key includes space
        #expect(data.bigrams["hello"]?[" world"] == 80)
    }

    @Test("N-gram data structure stores trigrams correctly")
    func testTrigramStorage() {
        var data = NGramData()
        let key = "hello_world"
        data.trigrams[key, default: [:]][" today"] = 40

        #expect(data.trigrams[key]?[" today"] == 40)
    }
}

// MARK: - Multi-Language N-Gram Tests

@Suite("Multi-Language N-Gram Tests")
struct MultiLanguageNGramTests {

    // Sample n-grams for testing (subset of actual data)
    let englishBigrams: [(String, String, Int)] = [
        ("i", "am", 500), ("i", "have", 400), ("i", "will", 350),
        ("you", "are", 450), ("you", "have", 380),
        ("the", "quick", 200), ("quick", "brown", 180),
    ]

    let polishBigrams: [(String, String, Int)] = [
        ("ja", "jestem", 500), ("ja", "mam", 400),
        ("nie", "wiem", 550), ("nie", "mam", 530),
        ("jak", "sie", 500), ("sie", "masz", 480),
    ]

    let spanishBigrams: [(String, String, Int)] = [
        ("yo", "soy", 500), ("yo", "tengo", 400),
        ("muchas", "gracias", 600), ("buenos", "días", 520),
    ]

    let frenchBigrams: [(String, String, Int)] = [
        ("je", "suis", 500), ("je", "vais", 350),
        ("merci", "beaucoup", 600), ("bonjour", "madame", 480),
    ]

    let germanBigrams: [(String, String, Int)] = [
        ("ich", "bin", 500), ("ich", "habe", 450),
        ("vielen", "dank", 580), ("guten", "morgen", 500),
    ]

    @Test("English n-grams contain common phrases")
    func testEnglishNGrams() {
        let iAmBigram = englishBigrams.first { $0.0 == "i" && $0.1 == "am" }
        #expect(iAmBigram != nil, "'i am' should be a common English bigram")
        #expect(iAmBigram?.2 == 500, "'i am' should have high frequency")
    }

    @Test("Polish n-grams contain common phrases")
    func testPolishNGrams() {
        let jakSie = polishBigrams.first { $0.0 == "jak" && $0.1 == "sie" }
        #expect(jakSie != nil, "'jak sie' should be a common Polish bigram")

        let nieWiem = polishBigrams.first { $0.0 == "nie" && $0.1 == "wiem" }
        #expect(nieWiem != nil, "'nie wiem' should be a common Polish bigram")
    }

    @Test("Spanish n-grams contain greetings")
    func testSpanishNGrams() {
        let gracias = spanishBigrams.first { $0.0 == "muchas" && $0.1 == "gracias" }
        #expect(gracias != nil, "'muchas gracias' should be common in Spanish")
        #expect(gracias?.2 == 600, "Greeting should have high frequency")
    }

    @Test("French n-grams contain polite phrases")
    func testFrenchNGrams() {
        let merci = frenchBigrams.first { $0.0 == "merci" && $0.1 == "beaucoup" }
        #expect(merci != nil, "'merci beaucoup' should be common in French")
    }

    @Test("German n-grams contain common expressions")
    func testGermanNGrams() {
        let ichBin = germanBigrams.first { $0.0 == "ich" && $0.1 == "bin" }
        #expect(ichBin != nil, "'ich bin' should be common in German")

        let vielenDank = germanBigrams.first { $0.0 == "vielen" && $0.1 == "dank" }
        #expect(vielenDank != nil, "'vielen dank' should be common in German")
    }
}

// MARK: - Italian N-Gram Tests

@Suite("Italian N-Gram Tests")
struct ItalianNGramTests {

    let italianBigrams: [(String, String, Int)] = [
        ("io", "sono", 500), ("io", "ho", 450), ("io", "voglio", 400),
        ("grazie", "mille", 600), ("buon", "giorno", 550),
        ("come", "stai", 520), ("come", "va", 500),
        ("va", "bene", 500), ("per", "favore", 500),
    ]

    @Test("Italian n-grams contain greetings")
    func testItalianGreetings() {
        let buonGiorno = italianBigrams.first { $0.0 == "buon" && $0.1 == "giorno" }
        #expect(buonGiorno != nil, "'buon giorno' should be common")

        let comeStai = italianBigrams.first { $0.0 == "come" && $0.1 == "stai" }
        #expect(comeStai != nil, "'come stai' should be common")
    }

    @Test("Italian n-grams contain polite phrases")
    func testItalianPolite() {
        let grazie = italianBigrams.first { $0.0 == "grazie" && $0.1 == "mille" }
        #expect(grazie != nil, "'grazie mille' should be common")
        #expect(grazie?.2 == 600, "Polite phrase should have high frequency")
    }
}

// MARK: - Portuguese N-Gram Tests

@Suite("Portuguese N-Gram Tests")
struct PortugueseNGramTests {

    let portugueseBigrams: [(String, String, Int)] = [
        ("eu", "sou", 500), ("eu", "tenho", 450), ("eu", "vou", 420),
        ("muito", "obrigado", 600), ("bom", "dia", 550),
        ("como", "vai", 480), ("tudo", "bem", 550),
    ]

    @Test("Portuguese n-grams contain greetings")
    func testPortugueseGreetings() {
        let bomDia = portugueseBigrams.first { $0.0 == "bom" && $0.1 == "dia" }
        #expect(bomDia != nil, "'bom dia' should be common")

        let tudoBem = portugueseBigrams.first { $0.0 == "tudo" && $0.1 == "bem" }
        #expect(tudoBem != nil, "'tudo bem' should be common")
    }

    @Test("Portuguese n-grams contain thank you")
    func testPortugueseThanks() {
        let obrigado = portugueseBigrams.first { $0.0 == "muito" && $0.1 == "obrigado" }
        #expect(obrigado != nil, "'muito obrigado' should be common")
    }
}

// MARK: - Russian N-Gram Tests

@Suite("Russian N-Gram Tests")
struct RussianNGramTests {

    let russianBigrams: [(String, String, Int)] = [
        ("я", "есть", 400), ("я", "хочу", 500), ("я", "могу", 450),
        ("спасибо", "большое", 600), ("добрый", "день", 500),
        ("как", "дела", 550),
    ]

    @Test("Russian n-grams contain greetings")
    func testRussianGreetings() {
        let dobryDen = russianBigrams.first { $0.0 == "добрый" && $0.1 == "день" }
        #expect(dobryDen != nil, "'добрый день' should be common")

        let kakDela = russianBigrams.first { $0.0 == "как" && $0.1 == "дела" }
        #expect(kakDela != nil, "'как дела' should be common")
    }

    @Test("Russian n-grams contain thank you")
    func testRussianThanks() {
        let spasibo = russianBigrams.first { $0.0 == "спасибо" && $0.1 == "большое" }
        #expect(spasibo != nil, "'спасибо большое' should be common")
    }
}

// MARK: - Arabic N-Gram Tests

@Suite("Arabic N-Gram Tests")
struct ArabicNGramTests {

    let arabicBigrams: [(String, String, Int)] = [
        ("أنا", "أريد", 500), ("أنا", "أستطيع", 450),
        ("شكراً", "جزيلاً", 600), ("كيف", "حالك", 550),
        ("إن", "شاء", 500),  // In sha Allah (part 1)
    ]

    @Test("Arabic n-grams contain greetings")
    func testArabicGreetings() {
        let kayfaHalak = arabicBigrams.first { $0.0 == "كيف" && $0.1 == "حالك" }
        #expect(kayfaHalak != nil, "'كيف حالك' should be common")
    }

    @Test("Arabic n-grams contain religious phrases")
    func testArabicReligious() {
        let inShaa = arabicBigrams.first { $0.0 == "إن" && $0.1 == "شاء" }
        #expect(inShaa != nil, "'إن شاء' should be common")
    }

    @Test("Arabic RTL text handling")
    func testArabicRTL() {
        let arabicPhrase = "كيف حالك"
        // Arabic text is right-to-left, but Swift handles this internally
        #expect(!arabicPhrase.isEmpty)
        #expect(arabicPhrase.contains("كيف"))
    }
}

// MARK: - CJK N-Gram Tests

@Suite("CJK N-Gram Tests")
struct CJKNGramTests {

    let chineseBigrams: [(String, String, Int)] = [
        ("我", "是", 600), ("我", "要", 550), ("我", "想", 520),
        ("你", "好", 700), ("谢", "谢", 650),
    ]

    let japaneseBigrams: [(String, String, Int)] = [
        ("私", "は", 500), ("これ", "は", 480),
        ("です", "か", 550), ("ます", "か", 500),
    ]

    let koreanBigrams: [(String, String, Int)] = [
        ("안녕", "하세요", 600), ("감사", "합니다", 580),
        ("네", "알겠", 400),
    ]

    @Test("Chinese character-based n-grams")
    func testChineseNGrams() {
        let niHao = chineseBigrams.first { $0.0 == "你" && $0.1 == "好" }
        #expect(niHao != nil, "'你好' should be common")
        #expect(niHao?.2 == 700, "Greeting should have highest frequency")
    }

    @Test("Japanese particle patterns")
    func testJapaneseParticles() {
        let watashiWa = japaneseBigrams.first { $0.0 == "私" && $0.1 == "は" }
        #expect(watashiWa != nil, "'私は' should be common")

        let desuKa = japaneseBigrams.first { $0.0 == "です" && $0.1 == "か" }
        #expect(desuKa != nil, "'ですか' (question) should be common")
    }

    @Test("Korean syllable blocks")
    func testKoreanNGrams() {
        let annyeong = koreanBigrams.first { $0.0 == "안녕" && $0.1 == "하세요" }
        #expect(annyeong != nil, "'안녕하세요' should be common")

        let gamsa = koreanBigrams.first { $0.0 == "감사" && $0.1 == "합니다" }
        #expect(gamsa != nil, "'감사합니다' should be common")
    }
}

// MARK: - Context-Aware Vocabulary Tests

@Suite("Context-Aware Vocabulary Tests")
struct ContextAwareVocabularyTests {

    // Sample context vocabulary (email context)
    let emailVocabularyEN: [String: Int] = [
        "dear": 500, "hello": 480, "hi": 450, "regards": 400,
        "sincerely": 380, "meeting": 350, "attached": 340,
    ]

    let emailVocabularyPL: [String: Int] = [
        "szanowny": 500, "witam": 480, "pozdrawiam": 400,
        "załącznik": 350, "spotkanie": 340,
    ]

    let emailVocabularyES: [String: Int] = [
        "estimado": 500, "hola": 480, "saludos": 400,
        "adjunto": 350, "reunión": 340,
    ]

    let emailVocabularyIT: [String: Int] = [
        "gentile": 500, "salve": 480, "cordiali": 400,
        "allegato": 350, "riunione": 340,
    ]

    let emailVocabularyPT: [String: Int] = [
        "prezado": 500, "olá": 480, "atenciosamente": 400,
        "anexo": 350, "reunião": 340,
    ]

    let emailVocabularyRU: [String: Int] = [
        "уважаемый": 500, "здравствуйте": 480, "с уважением": 400,
        "вложение": 350, "встреча": 340,
    ]

    @Test("English email vocabulary")
    func testEnglishEmailVocab() {
        #expect(emailVocabularyEN["dear"] == 500)
        #expect(emailVocabularyEN["regards"] == 400)
        #expect(emailVocabularyEN["meeting"] != nil)
    }

    @Test("Polish email vocabulary")
    func testPolishEmailVocab() {
        #expect(emailVocabularyPL["szanowny"] == 500, "Polish 'dear' equivalent")
        #expect(emailVocabularyPL["pozdrawiam"] == 400, "Polish 'regards'")
    }

    @Test("Spanish email vocabulary")
    func testSpanishEmailVocab() {
        #expect(emailVocabularyES["estimado"] == 500, "Spanish 'dear' equivalent")
        #expect(emailVocabularyES["saludos"] == 400, "Spanish 'regards'")
    }

    @Test("Italian email vocabulary")
    func testItalianEmailVocab() {
        #expect(emailVocabularyIT["gentile"] == 500, "Italian 'dear' equivalent")
        #expect(emailVocabularyIT["cordiali"] == 400, "Italian 'regards'")
    }

    @Test("Portuguese email vocabulary")
    func testPortugueseEmailVocab() {
        #expect(emailVocabularyPT["prezado"] == 500, "Portuguese 'dear' equivalent")
        #expect(emailVocabularyPT["atenciosamente"] == 400, "Portuguese 'regards'")
    }

    @Test("Russian email vocabulary")
    func testRussianEmailVocab() {
        #expect(emailVocabularyRU["уважаемый"] == 500, "Russian 'dear' equivalent")
        #expect(emailVocabularyRU["с уважением"] == 400, "Russian 'regards'")
    }
}

// MARK: - Lazy Loading Simulation Tests

@Suite("Lazy Loading Simulation Tests")
struct LazyLoadingTests {

    // Simulate lazy loading behavior
    class MockNGramPredictor {
        private var loadedLanguages: Set<String> = ["en"]  // English always loaded
        private var ngramsByLanguage: [String: Bool] = ["en": true]

        func ensureLanguageLoaded(_ language: String) {
            guard !loadedLanguages.contains(language) else { return }
            // Simulate loading
            loadedLanguages.insert(language)
            ngramsByLanguage[language] = true
        }

        func isLanguageLoaded(_ language: String) -> Bool {
            return loadedLanguages.contains(language)
        }

        var loadedLanguageCount: Int {
            return loadedLanguages.count
        }
    }

    @Test("English is always loaded by default")
    func testEnglishAlwaysLoaded() {
        let predictor = MockNGramPredictor()
        #expect(predictor.isLanguageLoaded("en"), "English should be loaded by default")
        #expect(predictor.loadedLanguageCount == 1, "Only English should be loaded initially")
    }

    @Test("Other languages are lazy loaded on demand")
    func testLazyLoading() {
        let predictor = MockNGramPredictor()

        #expect(!predictor.isLanguageLoaded("pl"), "Polish not loaded initially")
        #expect(!predictor.isLanguageLoaded("es"), "Spanish not loaded initially")

        predictor.ensureLanguageLoaded("pl")
        #expect(predictor.isLanguageLoaded("pl"), "Polish loaded after request")
        #expect(predictor.loadedLanguageCount == 2, "Two languages loaded")

        predictor.ensureLanguageLoaded("es")
        #expect(predictor.isLanguageLoaded("es"), "Spanish loaded after request")
        #expect(predictor.loadedLanguageCount == 3, "Three languages loaded")
    }

    @Test("Duplicate loading requests are idempotent")
    func testIdempotentLoading() {
        let predictor = MockNGramPredictor()

        predictor.ensureLanguageLoaded("pl")
        let countAfterFirst = predictor.loadedLanguageCount

        predictor.ensureLanguageLoaded("pl")  // Load again
        let countAfterSecond = predictor.loadedLanguageCount

        #expect(countAfterFirst == countAfterSecond, "Loading same language twice should not increase count")
    }

    @Test("All 13 languages can be loaded")
    func testAll13Languages() {
        let predictor = MockNGramPredictor()
        let languages = ["en", "pl", "es", "fr", "de", "it", "pt", "ru", "ar", "arz", "zh", "ja", "ko"]

        for lang in languages {
            predictor.ensureLanguageLoaded(lang)
        }

        #expect(predictor.loadedLanguageCount == 13, "All 13 languages should be loadable")

        for lang in languages {
            #expect(predictor.isLanguageLoaded(lang), "\(lang) should be loaded")
        }
    }
}

// MARK: - Language Code Mapping Tests

@Suite("Language Code Mapping Tests")
struct LanguageCodeMappingTests {

    func languageCodeFromRawValue(_ rawValue: String) -> String {
        switch rawValue.lowercased() {
        case "english", "en": return "en"
        case "polish", "pl": return "pl"
        case "spanish", "es": return "es"
        case "french", "fr": return "fr"
        case "german", "de": return "de"
        case "italian", "it": return "it"
        case "portuguese", "pt": return "pt"
        case "russian", "ru": return "ru"
        case "arabic", "ar": return "ar"
        case "egyptian arabic", "arz": return "arz"
        case "chinese", "zh": return "zh"
        case "japanese", "ja": return "ja"
        case "korean", "ko": return "ko"
        default:
            return rawValue.count == 2 ? rawValue.lowercased() : "en"
        }
    }

    @Test("Full language names map to correct codes")
    func testFullLanguageNames() {
        #expect(languageCodeFromRawValue("english") == "en")
        #expect(languageCodeFromRawValue("polish") == "pl")
        #expect(languageCodeFromRawValue("spanish") == "es")
        #expect(languageCodeFromRawValue("french") == "fr")
        #expect(languageCodeFromRawValue("german") == "de")
        #expect(languageCodeFromRawValue("italian") == "it")
        #expect(languageCodeFromRawValue("portuguese") == "pt")
        #expect(languageCodeFromRawValue("russian") == "ru")
        #expect(languageCodeFromRawValue("arabic") == "ar")
        #expect(languageCodeFromRawValue("chinese") == "zh")
        #expect(languageCodeFromRawValue("japanese") == "ja")
        #expect(languageCodeFromRawValue("korean") == "ko")
    }

    @Test("ISO codes pass through correctly")
    func testISOCodes() {
        #expect(languageCodeFromRawValue("en") == "en")
        #expect(languageCodeFromRawValue("pl") == "pl")
        #expect(languageCodeFromRawValue("de") == "de")
    }

    @Test("Unknown languages default to English")
    func testUnknownLanguage() {
        #expect(languageCodeFromRawValue("klingon") == "en")
        #expect(languageCodeFromRawValue("unknown") == "en")
    }

    @Test("Case insensitivity")
    func testCaseInsensitivity() {
        #expect(languageCodeFromRawValue("ENGLISH") == "en")
        #expect(languageCodeFromRawValue("Polish") == "pl")
        #expect(languageCodeFromRawValue("SPANISH") == "es")
    }
}
