//
//  SwipeTypingDictionary.swift
//  SwiftSpeakKeyboard
//
//  Phase 13.8: Word matching dictionary for swipe typing
//

import Foundation

// MARK: - Swipe Typing Dictionary
class SwipeTypingDictionary {
    private var words: Set<String> = []
    private var wordsByLength: [Int: Set<String>] = [:]

    init() {
        loadCommonWords()
    }

    private func loadCommonWords() {
        // Load top ~5000 common English words
        let commonWords = [
            // Most common words
            "the", "be", "to", "of", "and", "a", "in", "that", "have", "i",
            "it", "for", "not", "on", "with", "he", "as", "you", "do", "at",
            "this", "but", "his", "by", "from", "they", "we", "say", "her", "she",
            "or", "an", "will", "my", "one", "all", "would", "there", "their", "what",
            "so", "up", "out", "if", "about", "who", "get", "which", "go", "me",
            "when", "make", "can", "like", "time", "no", "just", "him", "know", "take",
            "people", "into", "year", "your", "good", "some", "could", "them", "see", "other",
            "than", "then", "now", "look", "only", "come", "its", "over", "think", "also",
            "back", "after", "use", "two", "how", "our", "work", "first", "well", "way",
            "even", "new", "want", "because", "any", "these", "give", "day", "most", "us",

            // Common messaging words
            "hello", "hi", "hey", "thanks", "thank", "please", "sorry", "okay", "ok", "yes",
            "no", "maybe", "sure", "great", "cool", "nice", "fine", "alright", "yeah", "nope",

            // Common work/email words
            "meeting", "email", "message", "send", "call", "later", "today", "tomorrow", "yesterday",
            "week", "month", "schedule", "appointment", "reminder", "urgent", "important", "follow",
            "regarding", "attached", "file", "document", "report", "update", "status", "review",

            // Common actions
            "help", "need", "want", "going", "coming", "doing", "working", "thinking", "feeling",
            "looking", "waiting", "trying", "starting", "stopping", "running", "walking", "talking",
            "writing", "reading", "watching", "listening", "eating", "drinking", "sleeping", "playing",

            // Common adjectives
            "big", "small", "large", "little", "long", "short", "high", "low", "old", "new",
            "young", "early", "late", "fast", "slow", "easy", "hard", "simple", "complex", "quick",
            "hot", "cold", "warm", "cool", "light", "dark", "heavy", "soft", "loud", "quiet",

            // Common nouns
            "home", "house", "car", "phone", "computer", "office", "school", "work", "friend",
            "family", "person", "place", "thing", "name", "number", "part", "question", "answer",
            "problem", "solution", "idea", "plan", "project", "task", "goal", "result", "success",

            // Time words
            "morning", "afternoon", "evening", "night", "midnight", "noon", "hour", "minute",
            "second", "daily", "weekly", "monthly", "yearly", "soon", "now", "never", "always",

            // Question words
            "what", "where", "when", "why", "how", "which", "whose", "whom", "whatever", "whenever",

            // Pronouns
            "I", "you", "he", "she", "it", "we", "they", "me", "him", "her", "us", "them",
            "mine", "yours", "his", "hers", "ours", "theirs", "myself", "yourself", "himself",
            "herself", "itself", "ourselves", "themselves", "someone", "anyone", "everyone",
            "something", "anything", "everything", "nothing", "nobody", "somebody", "anybody",

            // Prepositions
            "above", "across", "against", "along", "among", "around", "behind", "below", "beneath",
            "beside", "between", "beyond", "during", "inside", "near", "outside", "through",
            "toward", "under", "until", "upon", "within", "without",

            // Conjunctions
            "although", "unless", "while", "whereas", "since", "until", "before", "after",
            "whenever", "wherever", "whether", "neither", "either",

            // Common verbs
            "am", "are", "is", "was", "were", "been", "being", "has", "had", "having",
            "does", "did", "done", "doing", "may", "might", "must", "should", "shall",
            "would", "could", "ought", "need", "dare", "used", "let", "made", "find",
            "tell", "ask", "seem", "feel", "try", "leave", "call", "keep", "put", "set",
            "become", "bring", "begin", "run", "stand", "hold", "hear", "let", "mean",
            "meet", "include", "continue", "start", "provide", "serve", "create", "add",
            "change", "move", "play", "live", "believe", "happen", "appear", "lead",
            "understand", "watch", "follow", "stop", "speak", "read", "allow", "consider",
            "expect", "build", "stay", "fall", "cut", "reach", "kill", "remain", "suggest",
            "raise", "pass", "sell", "require", "report", "decide", "pull",

            // Numbers
            "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
            "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "twenty", "thirty",
            "forty", "fifty", "sixty", "seventy", "eighty", "ninety", "hundred", "thousand",

            // Technology
            "app", "phone", "computer", "internet", "website", "online", "download", "upload",
            "software", "hardware", "system", "program", "code", "data", "password", "login",
            "logout", "settings", "account", "profile", "search", "click", "type", "delete",

            // Social media
            "post", "share", "like", "comment", "follow", "unfollow", "friend", "message",
            "chat", "video", "photo", "picture", "image", "link", "tag", "mention", "dm",

            // Additional common words
            "each", "between", "same", "different", "such", "own", "much", "many", "few",
            "several", "both", "neither", "either", "every", "another", "next", "last",
            "still", "yet", "already", "enough", "very", "really", "quite", "rather",
            "pretty", "too", "also", "however", "therefore", "thus", "hence", "moreover",
        ]

        for word in commonWords {
            let lowercased = word.lowercased()
            words.insert(lowercased)
            let len = lowercased.count
            if wordsByLength[len] == nil {
                wordsByLength[len] = []
            }
            wordsByLength[len]?.insert(lowercased)
        }

        keyboardLog("Swipe dictionary loaded: \(words.count) words", category: "SwipeTyping")
    }

    func findMatches(for keys: [String]) -> [String] {
        guard keys.count >= 2 else {
            return []
        }

        var matches: [(String, Int)] = [] // word, score

        // Search words of similar length (±2 characters)
        let targetLength = keys.count
        for len in max(2, targetLength-2)...(targetLength+3) {
            guard let wordsOfLength = wordsByLength[len] else { continue }

            for word in wordsOfLength {
                let score = matchScore(word: word, keys: keys)
                if score > 0 {
                    matches.append((word, score))
                }
            }
        }

        // Sort by score descending
        matches.sort { $0.1 > $1.1 }

        // Return top 5 matches
        return matches.prefix(5).map { $0.0 }
    }

    private func matchScore(word: String, keys: [String]) -> Int {
        // Check if word matches the key sequence
        // Start must match, end must match, middle keys should be in order
        let wordChars = Array(word)
        var keyIndex = 0
        var score = 0

        guard !wordChars.isEmpty, !keys.isEmpty else { return 0 }

        // First and last key must match
        guard let firstKey = keys.first, let lastKey = keys.last,
              String(wordChars.first!).lowercased() == firstKey.lowercased(),
              String(wordChars.last!).lowercased() == lastKey.lowercased() else {
            return 0
        }

        // Bonus for matching first and last
        score += 30

        // Check if all keys appear in order
        for char in wordChars {
            if keyIndex < keys.count && String(char).lowercased() == keys[keyIndex].lowercased() {
                keyIndex += 1
                score += 10
            }
        }

        // Big bonus for matching all keys
        if keyIndex == keys.count {
            score += 50
        }

        // Penalty for length difference
        score -= abs(word.count - keys.count) * 5

        // Bonus for exact length match
        if word.count == keys.count {
            score += 20
        }

        return max(0, score)
    }
}
