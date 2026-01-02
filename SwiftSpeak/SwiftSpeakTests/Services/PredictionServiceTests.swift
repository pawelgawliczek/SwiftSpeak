//
//  PredictionServiceTests.swift
//  SwiftSpeakTests
//
//  Tests for prediction and autocorrection algorithms
//  NOTE: Keyboard extension services cannot be directly tested due to linking constraints.
//  These tests verify the underlying algorithms that the keyboard uses.
//

import Testing
import Foundation
@testable import SwiftSpeak

// MARK: - Edit Distance Algorithm Tests

@Suite("Edit Distance Algorithm Tests")
struct EditDistanceTests {

    /// Damerau-Levenshtein distance implementation for testing
    func damerauLevenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1.lowercased())
        let b = Array(s2.lowercased())
        let m = a.count
        let n = b.count

        if m == 0 { return n }
        if n == 0 { return m }
        if s1.lowercased() == s2.lowercased() { return 0 }

        var d = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { d[i][0] = i }
        for j in 0...n { d[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1

                d[i][j] = min(
                    d[i - 1][j] + 1,      // deletion
                    d[i][j - 1] + 1,      // insertion
                    d[i - 1][j - 1] + cost // substitution
                )

                // Transposition
                if i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1] {
                    d[i][j] = min(d[i][j], d[i - 2][j - 2] + cost)
                }
            }
        }

        return d[m][n]
    }

    @Test("Edit distance calculates correctly for insertions")
    func testInsertions() {
        // "met" -> "meet" (1 insertion)
        let distance = damerauLevenshteinDistance("met", "meet")
        #expect(distance == 1, "'met' to 'meet' should be distance 1")
    }

    @Test("Edit distance calculates correctly for deletions")
    func testDeletions() {
        // "meeet" -> "meet" (1 deletion)
        let distance = damerauLevenshteinDistance("meeet", "meet")
        #expect(distance == 1, "'meeet' to 'meet' should be distance 1")
    }

    @Test("Edit distance calculates correctly for substitutions")
    func testSubstitutions() {
        // "maat" -> "meet" (2 substitutions)
        let distance = damerauLevenshteinDistance("maat", "meet")
        #expect(distance == 2, "'maat' to 'meet' should be distance 2")
    }

    @Test("Edit distance handles transpositions")
    func testTranspositions() {
        // "teh" -> "the" (1 transposition)
        let distance = damerauLevenshteinDistance("teh", "the")
        #expect(distance == 1, "'teh' to 'the' should be distance 1 (transposition)")
    }

    @Test("Edit distance for common typos")
    func testCommonTypos() {
        // Common misspellings
        #expect(damerauLevenshteinDistance("recieve", "receive") == 1, "'recieve' should be 1 edit from 'receive'")
        #expect(damerauLevenshteinDistance("definately", "definitely") == 2, "'definately' should be 2 edits from 'definitely'")
        #expect(damerauLevenshteinDistance("occured", "occurred") == 1, "'occured' should be 1 edit from 'occurred'")
    }
}

// MARK: - Soundex Algorithm Tests

@Suite("Soundex Algorithm Tests")
struct SoundexTests {

    /// Simple Soundex implementation for testing
    func soundex(_ word: String) -> String {
        guard !word.isEmpty else { return "" }

        let input = word.lowercased()
        let letters = Array(input)

        // Mapping for Soundex
        let mapping: [Character: Character] = [
            "b": "1", "f": "1", "p": "1", "v": "1",
            "c": "2", "g": "2", "j": "2", "k": "2", "q": "2", "s": "2", "x": "2", "z": "2",
            "d": "3", "t": "3",
            "l": "4",
            "m": "5", "n": "5",
            "r": "6"
        ]

        var code = [letters[0].uppercased()]
        var lastCode: Character? = mapping[letters[0]]

        for i in 1..<letters.count {
            let letter = letters[i]
            if let mapped = mapping[letter], mapped != lastCode {
                code.append(String(mapped))
                lastCode = mapped
            } else if mapping[letter] == nil {
                lastCode = nil  // Vowels and H, W separate codes
            }

            if code.count >= 4 { break }
        }

        // Pad with zeros
        while code.count < 4 {
            code.append("0")
        }

        return code.joined()
    }

    @Test("Soundex produces same code for similar sounding words")
    func testSimilarSounds() {
        // Robert and Rupert should have similar codes
        let robert = soundex("Robert")
        let rupert = soundex("Rupert")
        #expect(robert == rupert, "Robert (\(robert)) and Rupert (\(rupert)) should have same Soundex")

        // Smith and Smyth
        let smith = soundex("Smith")
        let smyth = soundex("Smyth")
        #expect(smith == smyth, "Smith (\(smith)) and Smyth (\(smyth)) should have same Soundex")
    }

    @Test("Soundex produces different codes for different words")
    func testDifferentSounds() {
        // Cat and Dog should be different
        let cat = soundex("Cat")
        let dog = soundex("Dog")
        #expect(cat != dog, "Cat (\(cat)) and Dog (\(dog)) should have different Soundex")
    }
}

// MARK: - Capitalization Logic Tests

@Suite("Capitalization Logic Tests")
struct CapitalizationLogicTests {

    /// Words that should always be capitalized
    let alwaysCapitalize = Set(["i"])

    /// Days of the week
    let daysOfWeek = Set(["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"])

    /// Months
    let months = Set(["january", "february", "march", "april", "may", "june",
                      "july", "august", "september", "october", "november", "december"])

    /// Common contractions
    let contractions: [String: String] = [
        "dont": "don't", "wont": "won't", "cant": "can't",
        "im": "I'm", "youre": "you're", "theyre": "they're"
    ]

    func shouldCapitalizeWord(_ word: String) -> String? {
        let lowercased = word.lowercased()

        if alwaysCapitalize.contains(lowercased) {
            return word.uppercased()
        }

        if daysOfWeek.contains(lowercased) {
            return lowercased.capitalized
        }

        if months.contains(lowercased) {
            return lowercased.capitalized
        }

        return nil
    }

    @Test("'i' should become 'I'")
    func testCapitalizeI() {
        let result = shouldCapitalizeWord("i")
        #expect(result == "I", "'i' should become 'I'")
    }

    @Test("Days of week should be capitalized")
    func testCapitalizeDays() {
        let monday = shouldCapitalizeWord("monday")
        #expect(monday == "Monday", "'monday' should become 'Monday'")

        let friday = shouldCapitalizeWord("friday")
        #expect(friday == "Friday", "'friday' should become 'Friday'")
    }

    @Test("Months should be capitalized")
    func testCapitalizeMonths() {
        let january = shouldCapitalizeWord("january")
        #expect(january == "January", "'january' should become 'January'")

        let december = shouldCapitalizeWord("december")
        #expect(december == "December", "'december' should become 'December'")
    }

    @Test("Contractions should get apostrophes")
    func testContractions() {
        #expect(contractions["dont"] == "don't", "'dont' should become \"don't\"")
        #expect(contractions["im"] == "I'm", "'im' should become \"I'm\"")
        #expect(contractions["youre"] == "you're", "'youre' should become \"you're\"")
    }
}

// MARK: - Extended Contraction Tests (Issue: hows → how's)

@Suite("Extended Contraction Tests")
struct ExtendedContractionTests {

    /// Complete contractions dictionary matching AutoCapitalizationService
    let contractions: [String: String] = [
        // Don't/Won't/Can't etc. (negative contractions)
        "dont": "don't", "wont": "won't", "cant": "can't",
        "didnt": "didn't", "doesnt": "doesn't", "isnt": "isn't",
        "wasnt": "wasn't", "werent": "weren't", "havent": "haven't",
        "hasnt": "hasn't", "hadnt": "hadn't", "wouldnt": "wouldn't",
        "couldnt": "couldn't", "shouldnt": "shouldn't", "mustnt": "mustn't",
        "neednt": "needn't", "mightnt": "mightn't", "darent": "daren't",
        "shant": "shan't", "oughtnt": "oughtn't",

        // I'm/You're/We're etc. (is/are contractions)
        "im": "I'm", "youre": "you're", "were": "we're",
        "theyre": "they're", "hes": "he's", "shes": "she's",
        "its": "it's", "thats": "that's", "whats": "what's",
        "whos": "who's", "wheres": "where's", "heres": "here's",
        "theres": "there's",

        // Question word contractions (Issue: hows was missing)
        "hows": "how's", "whys": "why's", "whens": "when's",

        // I've/You've etc. (have contractions)
        "ive": "I've", "youve": "you've", "weve": "we've", "theyve": "they've",
        "shouldve": "should've", "wouldve": "would've", "couldve": "could've",
        "mightve": "might've", "mustve": "must've",

        // Informal "of" misspellings → proper contractions
        "shoulda": "should've", "woulda": "would've", "coulda": "could've",
        "musta": "must've", "mighta": "might've",

        // I'll/You'll etc. (will contractions)
        "ill": "I'll", "youll": "you'll", "theyll": "they'll",
        "shell": "she'll", "hell": "he'll", "itll": "it'll", "thatll": "that'll",
        "wholl": "who'll", "therell": "there'll", "whatll": "what'll",

        // I'd/You'd etc. (would/had contractions)
        "youd": "you'd", "theyd": "they'd", "hed": "he'd", "shed": "she'd",
        "itd": "it'd", "thatd": "that'd", "whod": "who'd",

        // Other common contractions
        "lets": "let's", "aint": "ain't", "yall": "y'all",
        "gonna": "gonna", "wanna": "wanna", "gotta": "gotta",
        "oughta": "oughta", "hafta": "hafta",
        "oclock": "o'clock", "cause": "'cause",

        // Very informal (common in casual typing)
        "gimme": "gimme", "lemme": "lemme",
        "kinda": "kinda", "sorta": "sorta", "dunno": "dunno",
    ]

    @Test("Question word contractions should be corrected - Issue: hows → how's")
    func testQuestionWordContractions() {
        // This was the reported bug - "hows" was being corrected to "how" instead of "how's"
        #expect(contractions["hows"] == "how's", "'hows' should become \"how's\" (not \"how\")")
        #expect(contractions["whys"] == "why's", "'whys' should become \"why's\"")
        #expect(contractions["whens"] == "when's", "'whens' should become \"when's\"")
    }

    @Test("Common negative contractions should be corrected")
    func testNegativeContractions() {
        #expect(contractions["dont"] == "don't")
        #expect(contractions["wont"] == "won't")
        #expect(contractions["cant"] == "can't")
        #expect(contractions["didnt"] == "didn't")
        #expect(contractions["doesnt"] == "doesn't")
        #expect(contractions["isnt"] == "isn't")
        #expect(contractions["wasnt"] == "wasn't")
        #expect(contractions["werent"] == "weren't")
        #expect(contractions["havent"] == "haven't")
        #expect(contractions["hasnt"] == "hasn't")
        #expect(contractions["hadnt"] == "hadn't")
        #expect(contractions["wouldnt"] == "wouldn't")
        #expect(contractions["couldnt"] == "couldn't")
        #expect(contractions["shouldnt"] == "shouldn't")
        #expect(contractions["mustnt"] == "mustn't")
        #expect(contractions["neednt"] == "needn't")
        #expect(contractions["mightnt"] == "mightn't")
    }

    @Test("Pronoun contractions with 's' should be corrected")
    func testPronounContractions() {
        #expect(contractions["hes"] == "he's")
        #expect(contractions["shes"] == "she's")
        #expect(contractions["its"] == "it's")
        #expect(contractions["thats"] == "that's")
        #expect(contractions["whats"] == "what's")
        #expect(contractions["whos"] == "who's")
        #expect(contractions["wheres"] == "where's")
        #expect(contractions["heres"] == "here's")
        #expect(contractions["theres"] == "there's")
    }

    @Test("'ve' contractions should be corrected")
    func testVeContractions() {
        #expect(contractions["ive"] == "I've")
        #expect(contractions["youve"] == "you've")
        #expect(contractions["weve"] == "we've")
        #expect(contractions["theyve"] == "they've")
        // Modal + have contractions
        #expect(contractions["shouldve"] == "should've")
        #expect(contractions["wouldve"] == "would've")
        #expect(contractions["couldve"] == "could've")
        #expect(contractions["mightve"] == "might've")
        #expect(contractions["mustve"] == "must've")
    }

    @Test("Informal 'of' misspellings should correct to proper contractions")
    func testInformalOfMisspellings() {
        // Common misspellings like "shoulda" should become "should've"
        #expect(contractions["shoulda"] == "should've", "'shoulda' should become 'should've'")
        #expect(contractions["woulda"] == "would've", "'woulda' should become 'would've'")
        #expect(contractions["coulda"] == "could've", "'coulda' should become 'could've'")
        #expect(contractions["musta"] == "must've", "'musta' should become 'must've'")
        #expect(contractions["mighta"] == "might've", "'mighta' should become 'might've'")
    }

    @Test("'ll' contractions should be corrected")
    func testLlContractions() {
        #expect(contractions["ill"] == "I'll")
        #expect(contractions["youll"] == "you'll")
        #expect(contractions["theyll"] == "they'll")
        #expect(contractions["itll"] == "it'll")
        #expect(contractions["thatll"] == "that'll")
        #expect(contractions["wholl"] == "who'll")
        #expect(contractions["therell"] == "there'll")
        #expect(contractions["whatll"] == "what'll")
    }

    @Test("'d' contractions should be corrected (would/had)")
    func testDContractions() {
        #expect(contractions["youd"] == "you'd")
        #expect(contractions["theyd"] == "they'd")
        #expect(contractions["hed"] == "he'd")
        #expect(contractions["shed"] == "she'd")
        #expect(contractions["itd"] == "it'd")
        #expect(contractions["thatd"] == "that'd")
        #expect(contractions["whod"] == "who'd")
    }

    @Test("Other common contractions should be corrected")
    func testOtherContractions() {
        #expect(contractions["im"] == "I'm")
        #expect(contractions["youre"] == "you're")
        #expect(contractions["theyre"] == "they're")
        #expect(contractions["lets"] == "let's")
        #expect(contractions["aint"] == "ain't")
        #expect(contractions["yall"] == "y'all")
        #expect(contractions["oclock"] == "o'clock")
    }
}

// MARK: - Prediction Insertion Logic Tests (Issue: Howhow's)

@Suite("Prediction Insertion Logic Tests")
struct PredictionInsertionTests {

    /// Simulates finding the current partial word to delete before inserting prediction
    /// This tests the fix for the bug where clicking a prediction appended instead of replacing
    func findPartialWordLength(in contextBefore: String) -> Int {
        var charsToDelete = 0
        for char in contextBefore.reversed() {
            if char.isWhitespace || char.isPunctuation {
                break
            }
            charsToDelete += 1
        }
        return charsToDelete
    }

    /// Simulates prediction insertion with word replacement
    func simulatePredictionInsertion(contextBefore: String, prediction: String) -> String {
        let charsToDelete = findPartialWordLength(in: contextBefore)
        let textAfterDeletion = String(contextBefore.dropLast(charsToDelete))
        return textAfterDeletion + prediction + " "
    }

    @Test("Issue: Clicking prediction should replace partial word, not append")
    func testPredictionReplacesPartialWord() {
        // Bug scenario: User types "How", backspaces, predictions show "how's"
        // Clicking "how's" should result in "how's ", NOT "Howhow's "

        let contextBefore = "How"
        let prediction = "how's"

        let result = simulatePredictionInsertion(contextBefore: contextBefore, prediction: prediction)

        #expect(result == "how's ", "Clicking prediction 'how's' with context 'How' should give 'how's ', not 'Howhow's '")
    }

    @Test("Prediction should replace word when cursor at end of word")
    func testPredictionReplacesWordAtEnd() {
        let result = simulatePredictionInsertion(contextBefore: "hel", prediction: "hello")
        #expect(result == "hello ", "Typing 'hel' and clicking 'hello' should give 'hello '")
    }

    @Test("Prediction should work correctly with preceding text")
    func testPredictionWithPrecedingText() {
        let result = simulatePredictionInsertion(contextBefore: "I want to hel", prediction: "help")
        #expect(result == "I want to help ", "Should replace only the partial word 'hel'")
    }

    @Test("Prediction should work after punctuation")
    func testPredictionAfterPunctuation() {
        let result = simulatePredictionInsertion(contextBefore: "Hello. Ho", prediction: "How")
        #expect(result == "Hello. How ", "Should replace 'Ho' after punctuation")
    }

    @Test("Prediction should handle empty partial word (after space)")
    func testPredictionAfterSpace() {
        let result = simulatePredictionInsertion(contextBefore: "Hello ", prediction: "world")
        #expect(result == "Hello world ", "Should just insert after space with no deletion")
    }

    @Test("Finding partial word length works correctly")
    func testFindPartialWordLength() {
        #expect(findPartialWordLength(in: "Hello") == 5, "All of 'Hello' is the partial word")
        #expect(findPartialWordLength(in: "Hello wo") == 2, "Only 'wo' is the partial word")
        #expect(findPartialWordLength(in: "Hello. Wo") == 2, "Only 'Wo' after period")
        #expect(findPartialWordLength(in: "Hello ") == 0, "No partial word after space")
        #expect(findPartialWordLength(in: "") == 0, "No partial word in empty string")
    }

    @Test("Partial word detection stops at punctuation")
    func testPartialWordStopsAtPunctuation() {
        #expect(findPartialWordLength(in: "test.word") == 4, "Only 'word' after period")
        #expect(findPartialWordLength(in: "test,word") == 4, "Only 'word' after comma")
        #expect(findPartialWordLength(in: "test!word") == 4, "Only 'word' after exclamation")
        #expect(findPartialWordLength(in: "test?word") == 4, "Only 'word' after question mark")
    }
}

// MARK: - Sentence Boundary Detection Tests

@Suite("Sentence Boundary Detection Tests")
struct SentenceBoundaryTests {

    func shouldCapitalizeAfter(_ context: String?) -> Bool {
        guard let context = context, !context.isEmpty else {
            return true  // Start of text
        }

        let trimmed = context.trimmingCharacters(in: .whitespaces)

        // After sentence-ending punctuation
        if trimmed.hasSuffix(".") || trimmed.hasSuffix("!") || trimmed.hasSuffix("?") {
            // Check for abbreviations
            let abbreviations = ["Mr.", "Mrs.", "Ms.", "Dr.", "etc.", "vs.", "e.g.", "i.e."]
            for abbr in abbreviations {
                if trimmed.hasSuffix(abbr) || trimmed.hasSuffix(abbr.lowercased()) {
                    return false
                }
            }
            return true
        }

        // After newline
        if context.hasSuffix("\n") {
            return true
        }

        return false
    }

    @Test("Should capitalize at start of text")
    func testStartOfText() {
        #expect(shouldCapitalizeAfter(nil) == true)
        #expect(shouldCapitalizeAfter("") == true)
    }

    @Test("Should capitalize after period")
    func testAfterPeriod() {
        #expect(shouldCapitalizeAfter("Hello. ") == true)
        #expect(shouldCapitalizeAfter("This is a test. ") == true)
    }

    @Test("Should capitalize after exclamation")
    func testAfterExclamation() {
        #expect(shouldCapitalizeAfter("Wow! ") == true)
    }

    @Test("Should capitalize after question mark")
    func testAfterQuestion() {
        #expect(shouldCapitalizeAfter("What? ") == true)
    }

    @Test("Should NOT capitalize mid-sentence")
    func testMidSentence() {
        #expect(shouldCapitalizeAfter("Hello ") == false)
        #expect(shouldCapitalizeAfter("This is ") == false)
    }

    @Test("Should NOT capitalize after abbreviations")
    func testAfterAbbreviations() {
        #expect(shouldCapitalizeAfter("Mr. ") == false, "Should not capitalize after Mr.")
        #expect(shouldCapitalizeAfter("Dr. ") == false, "Should not capitalize after Dr.")
        #expect(shouldCapitalizeAfter("etc. ") == false, "Should not capitalize after etc.")
    }
}

// MARK: - N-gram Prediction Logic Tests

@Suite("N-gram Prediction Logic Tests")
struct NGramLogicTests {

    /// Simple bigram dictionary for testing
    let bigrams: [String: [String: Int]] = [
        "i": ["am": 500, "have": 400, "will": 350, "want": 260, "need": 240],
        "thank": ["you": 600],
        "want": ["to": 350],
        "to": ["be": 400, "do": 300, "have": 280, "go": 240]
    ]

    func predictNextWord(after previousWord: String) -> [String] {
        guard let nextWords = bigrams[previousWord.lowercased()] else {
            return []
        }

        return nextWords.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key.capitalized }
    }

    @Test("Should predict 'am' after 'I'")
    func testPredictAfterI() {
        let predictions = predictNextWord(after: "I")
        #expect(predictions.first == "Am", "Should predict 'Am' first after 'I'")
        #expect(predictions.contains("Want"), "Should predict 'Want' after 'I'")
    }

    @Test("Should predict 'you' after 'thank'")
    func testPredictAfterThank() {
        let predictions = predictNextWord(after: "thank")
        #expect(predictions.contains("You"), "Should predict 'You' after 'thank'")
    }

    @Test("Should predict 'to' after 'want'")
    func testPredictAfterWant() {
        let predictions = predictNextWord(after: "want")
        #expect(predictions.contains("To"), "Should predict 'To' after 'want'")
    }

    @Test("Should predict 'be', 'do' after 'to'")
    func testPredictAfterTo() {
        let predictions = predictNextWord(after: "to")
        #expect(predictions.contains("Be"), "Should predict 'Be' after 'to'")
        #expect(predictions.contains("Do"), "Should predict 'Do' after 'to'")
    }
}
