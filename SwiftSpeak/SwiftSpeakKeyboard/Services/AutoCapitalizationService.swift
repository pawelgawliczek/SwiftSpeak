//
//  AutoCapitalizationService.swift
//  SwiftSpeakKeyboard
//
//  Smart auto-capitalization rules beyond basic sentence detection
//  Handles names, abbreviations, and special patterns
//

import Foundation

/// Auto-capitalization service for intelligent capitalization
enum AutoCapitalizationService {

    // MARK: - Should Capitalize

    /// Determine if next character should be capitalized
    static func shouldCapitalize(contextBefore: String?) -> Bool {
        guard let context = contextBefore else {
            return true  // Start of text
        }

        // Empty context = start of text
        if context.isEmpty {
            return true
        }

        let trimmed = context.trimmingCharacters(in: .whitespaces)

        // After sentence-ending punctuation
        if trimmed.hasSuffix(".") || trimmed.hasSuffix("!") || trimmed.hasSuffix("?") {
            // Exception: check for abbreviations like "Mr." "Dr." "etc."
            if !isAbbreviation(trimmed) {
                return true
            }
        }

        // After newline
        if context.hasSuffix("\n") {
            return true
        }

        // After colon in specific patterns (like "Note:" or "Subject:")
        if trimmed.hasSuffix(":") && isColonCapitalizePattern(trimmed) {
            return true
        }

        return false
    }

    // MARK: - Auto-Capitalize Word

    /// Check if a word should be auto-capitalized (proper nouns, etc.)
    static func shouldAutoCapitalizeWord(_ word: String, contextBefore: String?) -> String? {
        let lowercased = word.lowercased()

        // Always capitalize "I"
        if lowercased == "i" {
            return "I"
        }

        // Check for known proper nouns
        if let properNoun = properNouns[lowercased] {
            return properNoun
        }

        // Check for day/month names
        if let dayOrMonth = daysAndMonths[lowercased] {
            return dayOrMonth
        }

        // Check for common acronyms/abbreviations
        if let acronym = commonAcronyms[lowercased] {
            return acronym
        }

        return nil
    }

    // MARK: - Smart Contractions

    /// Fix contractions that should have apostrophes
    static func fixContraction(_ word: String) -> String? {
        let lowercased = word.lowercased()
        return contractions[lowercased]
    }

    // MARK: - Private Helpers

    private static func isAbbreviation(_ text: String) -> Bool {
        let abbreviations = [
            "Mr.", "Mrs.", "Ms.", "Dr.", "Prof.", "Sr.", "Jr.",
            "etc.", "vs.", "e.g.", "i.e.", "Fig.", "No.", "Vol.",
            "St.", "Ave.", "Blvd.", "Rd.", "Inc.", "Corp.", "Ltd.",
            "a.m.", "p.m.", "A.M.", "P.M."
        ]

        for abbr in abbreviations {
            if text.hasSuffix(abbr) || text.hasSuffix(abbr.lowercased()) {
                return true
            }
        }

        return false
    }

    private static func isColonCapitalizePattern(_ text: String) -> Bool {
        // Patterns where text after colon should be capitalized
        let patterns = [
            "note:", "subject:", "re:", "to:", "from:", "dear:",
            "attention:", "warning:", "important:", "reminder:",
            "ps:", "p.s.:", "nb:", "n.b.:"
        ]

        let lowercased = text.lowercased()
        for pattern in patterns {
            if lowercased.hasSuffix(pattern) {
                return true
            }
        }

        return false
    }

    // MARK: - Data

    /// Common proper nouns to capitalize
    private static let properNouns: [String: String] = [
        // Tech companies
        "apple": "Apple", "google": "Google", "microsoft": "Microsoft",
        "amazon": "Amazon", "facebook": "Facebook", "meta": "Meta",
        "netflix": "Netflix", "spotify": "Spotify", "uber": "Uber",
        "tesla": "Tesla", "nvidia": "NVIDIA", "intel": "Intel",

        // Social media
        "twitter": "Twitter", "instagram": "Instagram", "tiktok": "TikTok",
        "snapchat": "Snapchat", "linkedin": "LinkedIn", "youtube": "YouTube",
        "whatsapp": "WhatsApp", "telegram": "Telegram",

        // Programming
        "swift": "Swift", "python": "Python", "javascript": "JavaScript",
        "typescript": "TypeScript", "kotlin": "Kotlin", "java": "Java",

        // Products
        "iphone": "iPhone", "ipad": "iPad", "imac": "iMac", "macbook": "MacBook",
        "airpods": "AirPods", "siri": "Siri", "alexa": "Alexa",
        "chatgpt": "ChatGPT", "github": "GitHub", "gitlab": "GitLab",
    ]

    /// Days and months
    private static let daysAndMonths: [String: String] = [
        // Days
        "monday": "Monday", "tuesday": "Tuesday", "wednesday": "Wednesday",
        "thursday": "Thursday", "friday": "Friday", "saturday": "Saturday",
        "sunday": "Sunday",

        // Months
        "january": "January", "february": "February", "march": "March",
        "april": "April", "may": "May", "june": "June", "july": "July",
        "august": "August", "september": "September", "october": "October",
        "november": "November", "december": "December",

        // Abbreviations
        "mon": "Mon", "tue": "Tue", "wed": "Wed", "thu": "Thu",
        "fri": "Fri", "sat": "Sat", "sun": "Sun",
        "jan": "Jan", "feb": "Feb", "mar": "Mar", "apr": "Apr",
        "jun": "Jun", "jul": "Jul", "aug": "Aug", "sep": "Sep",
        "oct": "Oct", "nov": "Nov", "dec": "Dec",
    ]

    /// Common acronyms
    private static let commonAcronyms: [String: String] = [
        "usa": "USA", "uk": "UK", "eu": "EU", "un": "UN",
        "fyi": "FYI", "asap": "ASAP", "rsvp": "RSVP", "eta": "ETA",
        "ceo": "CEO", "cto": "CTO", "cfo": "CFO", "hr": "HR",
        "vip": "VIP", "diy": "DIY", "faq": "FAQ", "atm": "ATM",
        "gps": "GPS", "pdf": "PDF", "api": "API", "url": "URL",
        "html": "HTML", "css": "CSS", "sql": "SQL", "json": "JSON",
        "ios": "iOS", "macos": "macOS", "tvos": "tvOS", "watchos": "watchOS",
        "wifi": "WiFi", "usb": "USB", "hdmi": "HDMI", "led": "LED",
        "ai": "AI", "ml": "ML", "vr": "VR", "ar": "AR",
        "ok": "OK", "tv": "TV", "id": "ID", "dj": "DJ",
    ]

    /// Common contractions
    private static let contractions: [String: String] = [
        // Don't/Won't/Can't etc. (negative contractions)
        "dont": "don't", "wont": "won't", "cant": "can't",
        "didnt": "didn't", "doesnt": "doesn't", "isnt": "isn't",
        "wasnt": "wasn't", "werent": "weren't", "havent": "haven't",
        "hasnt": "hasn't", "hadnt": "hadn't", "wouldnt": "wouldn't",
        "couldnt": "couldn't", "shouldnt": "shouldn't", "mustnt": "mustn't",
        "neednt": "needn't", "mightnt": "mightn't", "darent": "daren't",
        "shant": "shan't", "oughtnt": "oughtn't",

        // I'm/You're/We're etc. (is/are contractions)
        "im": "I'm", "youre": "you're", "were": "we're", // Note: "were" also valid word
        "theyre": "they're", "hes": "he's", "shes": "she's",
        "its": "it's",  // Note: "its" also valid (possessive)
        "thats": "that's", "whats": "what's", "whos": "who's",
        "wheres": "where's", "heres": "here's", "theres": "there's",
        "hows": "how's", "whys": "why's", "whens": "when's",

        // I've/You've etc. (have contractions)
        "ive": "I've", "youve": "you've", "weve": "we've", "theyve": "they've",
        "shouldve": "should've", "wouldve": "would've", "couldve": "could've",
        "mightve": "might've", "mustve": "must've",

        // Informal "of" misspellings → proper contractions
        "shoulda": "should've", "woulda": "would've", "coulda": "could've",
        "musta": "must've", "mighta": "might've",

        // I'll/You'll etc. (will contractions)
        "ill": "I'll", "youll": "you'll", "well": "we'll", // Note: "well" also valid word
        "theyll": "they'll", "shell": "she'll", "hell": "he'll", // Note: conflicts
        "itll": "it'll", "thatll": "that'll", "wholl": "who'll",
        "therell": "there'll", "whatll": "what'll",

        // I'd/You'd etc. (would/had contractions)
        "id": "I'd", // Note: "id" also valid (identification)
        "youd": "you'd", "wed": "we'd", // Note: "wed" also valid word
        "theyd": "they'd", "hed": "he'd", "shed": "she'd",
        "itd": "it'd", "thatd": "that'd", "whod": "who'd",

        // Other common contractions
        "lets": "let's", "aint": "ain't", "yall": "y'all",
        "gonna": "gonna", "wanna": "wanna", "gotta": "gotta",
        "oughta": "oughta", "hafta": "hafta",
        "oclock": "o'clock", "cause": "'cause",

        // Very informal (common in casual typing)
        "gimme": "gimme", "lemme": "lemme",
        "kinda": "kinda", "sorta": "sorta",
        "dunno": "dunno",
    ]

    /// Words that should NOT be auto-contracted (they have other valid meanings)
    static let ambiguousWords: Set<String> = [
        "were", "well", "hell", "shell", "wed", "id", "its"
    ]
}
