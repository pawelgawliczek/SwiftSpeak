//
//  PhoneticCorrector.swift
//  SwiftSpeakKeyboard
//
//  Phonetic-based spelling correction using Soundex and Double Metaphone
//  Catches sound-alike misspellings that edit distance misses
//

import Foundation

/// Phonetic spelling correction service
/// Complements SymSpell by catching phonetically similar misspellings
actor PhoneticCorrector {
    static let shared = PhoneticCorrector()

    // Phonetic index: soundex code -> words with that pronunciation
    private var soundexIndex: [String: Set<String>] = [:]
    private var metaphoneIndex: [String: Set<String>] = [:]
    private var wordFrequencies: [String: Int] = [:]

    private var isInitialized = false

    private init() {}

    // MARK: - Initialization

    func initialize(words: [(String, Int)]) async {
        guard !isInitialized else { return }

        for (word, frequency) in words {
            addWord(word, frequency: frequency)
        }

        isInitialized = true
        keyboardLog("PhoneticCorrector initialized with \(soundexIndex.count) soundex codes", category: "Autocorrect")
    }

    /// Add a word to the phonetic index
    func addWord(_ word: String, frequency: Int = 1) {
        let lowercased = word.lowercased()
        guard lowercased.count >= 2 else { return }

        // Store frequency
        wordFrequencies[lowercased] = (wordFrequencies[lowercased] ?? 0) + frequency

        // Index by Soundex
        let soundex = soundexCode(lowercased)
        soundexIndex[soundex, default: []].insert(lowercased)

        // Index by Double Metaphone
        let metaphones = doubleMetaphone(lowercased)
        for metaphone in metaphones where !metaphone.isEmpty {
            metaphoneIndex[metaphone, default: []].insert(lowercased)
        }
    }

    // MARK: - Correction

    /// Get phonetically similar corrections for a misspelled word
    func getCorrections(for word: String, maxResults: Int = 3) -> [String] {
        let lowercased = word.lowercased()

        // Already correctly spelled? No corrections needed
        if wordFrequencies[lowercased] != nil {
            return []
        }

        var candidates: [(word: String, score: Int)] = []
        var seenWords = Set<String>()

        // Find candidates with same Soundex code
        let inputSoundex = soundexCode(lowercased)
        if let soundexMatches = soundexIndex[inputSoundex] {
            for match in soundexMatches where match != lowercased {
                if seenWords.insert(match).inserted {
                    let freq = wordFrequencies[match] ?? 0
                    var score = freq

                    // Bonus for same first letter
                    if match.first == lowercased.first {
                        score += 1000
                    }

                    // Bonus for similar length
                    let lengthDiff = abs(match.count - lowercased.count)
                    if lengthDiff <= 1 {
                        score += 500
                    } else if lengthDiff <= 2 {
                        score += 200
                    }

                    candidates.append((match, score))
                }
            }
        }

        // Find candidates with same Metaphone code
        let inputMetaphones = doubleMetaphone(lowercased)
        for metaphone in inputMetaphones {
            if let metaphoneMatches = metaphoneIndex[metaphone] {
                for match in metaphoneMatches where match != lowercased {
                    if seenWords.insert(match).inserted {
                        let freq = wordFrequencies[match] ?? 0
                        var score = freq

                        // Metaphone matches are higher quality
                        score += 200

                        // Bonus for same first letter
                        if match.first == lowercased.first {
                            score += 1000
                        }

                        candidates.append((match, score))
                    }
                }
            }
        }

        // Sort by score descending
        candidates.sort { $0.score > $1.score }

        return candidates.prefix(maxResults).map { $0.word }
    }

    /// Get best phonetic correction (for autocorrect)
    func getBestCorrection(for word: String) -> String? {
        let corrections = getCorrections(for: word, maxResults: 1)
        guard let best = corrections.first else { return nil }

        // Only return if it's likely a phonetic misspelling
        let lowercased = word.lowercased()

        // Same first letter required
        guard best.first == lowercased.first else { return nil }

        // Similar length required
        guard abs(best.count - lowercased.count) <= 2 else { return nil }

        // Must have reasonable frequency
        guard (wordFrequencies[best] ?? 0) >= 50 else { return nil }

        return best
    }

    // MARK: - Soundex Algorithm

    /// Generate Soundex code for a word
    /// Soundex encodes words by their pronunciation pattern
    private func soundexCode(_ word: String) -> String {
        guard !word.isEmpty else { return "" }

        let chars = Array(word.uppercased())
        var code = String(chars[0])

        // Soundex encoding table
        let soundexMap: [Character: Character] = [
            "B": "1", "F": "1", "P": "1", "V": "1",
            "C": "2", "G": "2", "J": "2", "K": "2", "Q": "2", "S": "2", "X": "2", "Z": "2",
            "D": "3", "T": "3",
            "L": "4",
            "M": "5", "N": "5",
            "R": "6"
        ]

        var lastCode: Character = "0"

        for char in chars.dropFirst() {
            if let digit = soundexMap[char] {
                if digit != lastCode {
                    code.append(digit)
                    lastCode = digit
                }
            } else {
                lastCode = "0"  // Vowels and H/W reset the duplicate check
            }

            if code.count == 4 {
                break
            }
        }

        // Pad with zeros to make length 4
        while code.count < 4 {
            code.append("0")
        }

        return code
    }

    // MARK: - Double Metaphone Algorithm

    /// Generate Double Metaphone codes for a word
    /// Returns up to 2 codes (primary and alternate)
    private func doubleMetaphone(_ word: String) -> [String] {
        let input = word.uppercased()
        guard !input.isEmpty else { return [] }

        var primary = ""
        var secondary = ""
        var index = 0
        let chars = Array(input)
        let length = chars.count

        // Helper functions
        func charAt(_ i: Int) -> Character {
            guard i >= 0 && i < length else { return " " }
            return chars[i]
        }

        func stringAt(_ start: Int, _ len: Int, _ options: [String]) -> Bool {
            guard start >= 0 && start + len <= length else { return false }
            let substring = String(chars[start..<(start + len)])
            return options.contains(substring)
        }

        // Skip initial silent letters
        if stringAt(0, 2, ["GN", "KN", "PN", "WR", "PS"]) {
            index += 1
        }

        // Main loop
        while index < length && (primary.count < 6 || secondary.count < 6) {
            let char = charAt(index)

            switch char {
            case "A", "E", "I", "O", "U":
                if index == 0 {
                    primary += "A"
                    secondary += "A"
                }
                index += 1

            case "B":
                primary += "P"
                secondary += "P"
                index += charAt(index + 1) == "B" ? 2 : 1

            case "C":
                if stringAt(index, 2, ["CH"]) {
                    primary += "X"
                    secondary += "X"
                    index += 2
                } else if stringAt(index, 2, ["CI", "CE", "CY"]) {
                    primary += "S"
                    secondary += "S"
                    index += 1
                } else {
                    primary += "K"
                    secondary += "K"
                    index += stringAt(index, 2, ["CK", "CC"]) ? 2 : 1
                }

            case "D":
                if stringAt(index, 2, ["DG"]) {
                    if stringAt(index + 2, 1, ["I", "E", "Y"]) {
                        primary += "J"
                        secondary += "J"
                        index += 3
                    } else {
                        primary += "TK"
                        secondary += "TK"
                        index += 2
                    }
                } else {
                    primary += "T"
                    secondary += "T"
                    index += stringAt(index, 2, ["DT", "DD"]) ? 2 : 1
                }

            case "F":
                primary += "F"
                secondary += "F"
                index += charAt(index + 1) == "F" ? 2 : 1

            case "G":
                if stringAt(index + 1, 1, ["H"]) {
                    if index > 0 && !isVowel(charAt(index - 1)) {
                        primary += "K"
                        secondary += "K"
                    }
                    index += 2
                } else if stringAt(index, 2, ["GN"]) {
                    primary += "N"
                    secondary += "N"
                    index += 2
                } else if stringAt(index + 1, 1, ["I", "E", "Y"]) {
                    primary += "J"
                    secondary += "K"
                    index += 1
                } else {
                    primary += "K"
                    secondary += "K"
                    index += charAt(index + 1) == "G" ? 2 : 1
                }

            case "H":
                // H is silent unless before a vowel and not after CGPST
                if index == 0 || isVowel(charAt(index + 1)) {
                    if !stringAt(index - 1, 1, ["C", "G", "P", "S", "T"]) {
                        primary += "H"
                        secondary += "H"
                    }
                }
                index += 1

            case "J":
                primary += "J"
                secondary += "J"
                index += charAt(index + 1) == "J" ? 2 : 1

            case "K":
                primary += "K"
                secondary += "K"
                index += charAt(index + 1) == "K" ? 2 : 1

            case "L":
                primary += "L"
                secondary += "L"
                index += charAt(index + 1) == "L" ? 2 : 1

            case "M":
                primary += "M"
                secondary += "M"
                index += charAt(index + 1) == "M" ? 2 : 1

            case "N":
                primary += "N"
                secondary += "N"
                index += charAt(index + 1) == "N" ? 2 : 1

            case "P":
                if charAt(index + 1) == "H" {
                    primary += "F"
                    secondary += "F"
                    index += 2
                } else {
                    primary += "P"
                    secondary += "P"
                    index += stringAt(index, 2, ["PP", "PB"]) ? 2 : 1
                }

            case "Q":
                primary += "K"
                secondary += "K"
                index += charAt(index + 1) == "Q" ? 2 : 1

            case "R":
                primary += "R"
                secondary += "R"
                index += charAt(index + 1) == "R" ? 2 : 1

            case "S":
                if stringAt(index, 2, ["SH"]) {
                    primary += "X"
                    secondary += "X"
                    index += 2
                } else if stringAt(index, 3, ["SIO", "SIA"]) {
                    primary += "X"
                    secondary += "S"
                    index += 3
                } else {
                    primary += "S"
                    secondary += "S"
                    index += stringAt(index, 2, ["SS", "SC"]) ? 2 : 1
                }

            case "T":
                if stringAt(index, 2, ["TH"]) {
                    primary += "0"  // Using 0 for th sound
                    secondary += "T"
                    index += 2
                } else if stringAt(index, 4, ["TION"]) {
                    primary += "X"
                    secondary += "X"
                    index += 4
                } else {
                    primary += "T"
                    secondary += "T"
                    index += stringAt(index, 2, ["TT", "TD"]) ? 2 : 1
                }

            case "V":
                primary += "F"
                secondary += "F"
                index += charAt(index + 1) == "V" ? 2 : 1

            case "W":
                if isVowel(charAt(index + 1)) {
                    primary += "A"
                    secondary += "F"
                }
                index += 1

            case "X":
                primary += "KS"
                secondary += "KS"
                index += charAt(index + 1) == "X" ? 2 : 1

            case "Y":
                if isVowel(charAt(index + 1)) {
                    primary += "A"
                    secondary += "A"
                }
                index += 1

            case "Z":
                primary += "S"
                secondary += "S"
                index += charAt(index + 1) == "Z" ? 2 : 1

            default:
                index += 1
            }
        }

        var result = [primary]
        if secondary != primary && !secondary.isEmpty {
            result.append(secondary)
        }
        return result
    }

    private func isVowel(_ char: Character) -> Bool {
        return "AEIOU".contains(char)
    }
}

// MARK: - Common Phonetic Misspellings

extension PhoneticCorrector {
    /// Dictionary of common phonetic misspellings to their corrections
    /// These are patterns that Soundex/Metaphone might miss
    static let commonPhoneticMisspellings: [String: String] = [
        // -ible/-able confusion
        "responsable": "responsible",
        "visable": "visible",
        "flexable": "flexible",
        "accessable": "accessible",

        // -ance/-ence confusion
        "independance": "independence",
        "occurance": "occurrence",
        "persistance": "persistence",

        // Double letter confusion
        "accomodate": "accommodate",
        "occured": "occurred",
        "reccomend": "recommend",
        "tommorrow": "tomorrow",
        "neccessary": "necessary",

        // Silent letters
        "goverment": "government",
        "enviroment": "environment",
        "reciept": "receipt",
        "foriegn": "foreign",

        // -ie/-ei confusion
        "recieve": "receive",
        "beleive": "believe",
        "acheive": "achieve",
        "wierd": "weird",
        "thier": "their",

        // Common phonetic errors
        "definately": "definitely",
        "seperate": "separate",
        "calender": "calendar",
        "febuary": "february",
        "Febuary": "February",
        "wensday": "wednesday",
        "Wensday": "Wednesday",
        "probly": "probably",
        "libary": "library",
        "gauruntee": "guarantee",
        "garantee": "guarantee",
        "untill": "until",
        "sincerly": "sincerely",

        // Phonetic vowel confusion
        "defintion": "definition",
        "expirience": "experience",
        "explaination": "explanation",
        "grammer": "grammar",
        "maintainance": "maintenance",
        "pronounciation": "pronunciation",
        "refering": "referring",
        "restaraunt": "restaurant",
        "vaccum": "vacuum",
    ]

    /// Check for known phonetic misspelling patterns
    func checkKnownMisspelling(_ word: String) -> String? {
        return Self.commonPhoneticMisspellings[word.lowercased()]
    }
}
