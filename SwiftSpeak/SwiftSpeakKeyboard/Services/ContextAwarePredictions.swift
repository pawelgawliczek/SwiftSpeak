//
//  ContextAwarePredictions.swift
//  SwiftSpeakKeyboard
//
//  Context-aware predictions based on app type and conversation context
//  Provides different predictions for email vs messaging vs code
//

import Foundation

/// Typing context types for prediction customization
enum TypingContextType: String, Codable {
    case email
    case messaging
    case social
    case code
    case notes
    case search
    case formal
    case casual
    case unknown
}

/// Context-aware prediction service
actor ContextAwarePredictions {
    static let shared = ContextAwarePredictions()

    private let appGroupID = "group.pawelgawliczek.swiftspeak"

    // Context-specific vocabulary
    private var contextVocabulary: [TypingContextType: [String: Int]] = [:]

    // Current detected context
    private var currentContext: TypingContextType = .unknown

    private var isInitialized = false

    private init() {}

    // MARK: - Initialization

    func initialize() async {
        guard !isInitialized else { return }

        loadContextVocabulary()
        isInitialized = true
        keyboardLog("ContextAwarePredictions initialized", category: "Prediction")
    }

    // MARK: - Context Detection

    /// Detect typing context from current text and active context
    func detectContext(text: String, activeContextName: String?) -> TypingContextType {
        // Check active context name from keyboard
        if let contextName = activeContextName?.lowercased() {
            if contextName.contains("work") || contextName.contains("email") {
                return .email
            } else if contextName.contains("personal") || contextName.contains("casual") {
                return .messaging
            } else if contextName.contains("creative") {
                return .notes
            }
        }

        // Analyze text patterns
        let lowercased = text.lowercased()

        // Email patterns
        if lowercased.contains("dear ") || lowercased.contains("sincerely") ||
           lowercased.contains("regards") || lowercased.contains("attached") ||
           lowercased.contains("meeting") || lowercased.contains("schedule") {
            return .email
        }

        // Messaging patterns
        if lowercased.contains("lol") || lowercased.contains("omg") ||
           lowercased.contains("btw") || lowercased.contains("gonna") ||
           lowercased.contains("wanna") || text.contains("😊") || text.contains("🙂") {
            return .messaging
        }

        // Code patterns
        if lowercased.contains("func ") || lowercased.contains("var ") ||
           lowercased.contains("let ") || lowercased.contains("class ") ||
           lowercased.contains("import ") || text.contains("{}") || text.contains("()") {
            return .code
        }

        // Formal patterns
        if lowercased.contains("therefore") || lowercased.contains("furthermore") ||
           lowercased.contains("regarding") || lowercased.contains("pursuant") {
            return .formal
        }

        return .unknown
    }

    /// Set current context for predictions
    func setContext(_ context: TypingContextType) {
        currentContext = context
    }

    // MARK: - Context-Specific Predictions

    /// Get predictions appropriate for the current context
    func getPredictions(for prefix: String, context: TypingContextType? = nil) -> [String] {
        let ctx = context ?? currentContext
        let lowercased = prefix.lowercased()

        // Get context-specific words
        guard let vocab = contextVocabulary[ctx] else {
            return getDefaultPredictions(prefix: lowercased)
        }

        // Filter and sort by frequency
        var matches: [(String, Int)] = []

        for (word, freq) in vocab {
            if prefix.isEmpty || word.hasPrefix(lowercased) {
                matches.append((word, freq))
            }
        }

        // Return lowercase - caller (PredictionEngine) handles capitalization
        return matches
            .sorted { $0.1 > $1.1 }
            .prefix(10)
            .map { $0.0 }
    }

    /// Get starter predictions when no text is typed
    /// Returns lowercase - caller handles smart capitalization
    func getStarterPredictions(for context: TypingContextType) -> [String] {
        switch context {
        case .email:
            return ["hi", "hello", "dear", "thank", "please", "i", "we"]
        case .messaging:
            return ["hey", "hi", "what's", "how's", "thanks", "sure", "ok"]
        case .social:
            return ["just", "so", "finally", "anyone", "can't", "love", "this"]
        case .code:
            return ["func", "let", "var", "if", "for", "class", "import"]
        case .notes:
            return ["the", "i", "this", "today", "need", "remember", "ideas"]
        case .search:
            return ["how", "what", "why", "where", "best", "top", "how to"]
        case .formal:
            return ["i", "we", "the", "regarding", "please", "thank", "as"]
        case .casual:
            return ["i", "so", "just", "hey", "yeah", "what", "how"]
        case .unknown:
            return ["i", "the", "hi", "thanks", "please", "what", "how"]
        }
    }

    /// Get common phrases for context
    func getCommonPhrases(for context: TypingContextType) -> [String] {
        switch context {
        case .email:
            return [
                "Thank you for",
                "Please let me know",
                "I hope this email finds you well",
                "Looking forward to",
                "Best regards",
                "As discussed",
                "Attached please find"
            ]
        case .messaging:
            return [
                "What's up",
                "How are you",
                "See you later",
                "On my way",
                "Sounds good",
                "Let me know",
                "Talk soon"
            ]
        case .formal:
            return [
                "I would like to",
                "In accordance with",
                "Please be advised",
                "At your earliest convenience",
                "I am writing to",
                "We are pleased to"
            ]
        default:
            return []
        }
    }

    // MARK: - Vocabulary Loading

    private func loadContextVocabulary() {
        // Email vocabulary
        contextVocabulary[.email] = [
            "thank": 500, "thanks": 450, "please": 400, "meeting": 350,
            "attached": 300, "schedule": 280, "email": 270, "regarding": 250,
            "forward": 240, "update": 230, "follow": 220, "confirm": 210,
            "available": 200, "discuss": 190, "proposal": 180, "report": 170,
            "deadline": 160, "reminder": 150, "urgent": 140, "priority": 130,
            "agenda": 120, "presentation": 110, "document": 100, "review": 95,
            "sincerely": 90, "regards": 85, "cordially": 80, "respectfully": 75,
            "dear": 70, "hello": 300, "hi": 280, "hey": 100,
            "appreciate": 85, "assistance": 80, "clarification": 75,
            "monday": 100, "tuesday": 95, "wednesday": 90, "thursday": 95,
            "friday": 100, "tomorrow": 150, "today": 180, "week": 160,
        ]

        // Messaging vocabulary
        contextVocabulary[.messaging] = [
            "hey": 500, "hi": 480, "hello": 400, "what's": 350,
            "how's": 340, "thanks": 330, "ok": 320, "okay": 310,
            "yeah": 300, "yes": 290, "no": 280, "sure": 270,
            "cool": 260, "nice": 250, "great": 240, "awesome": 230,
            "lol": 220, "haha": 210, "omg": 200, "btw": 190,
            "gonna": 180, "wanna": 170, "gotta": 160, "kinda": 150,
            "later": 140, "soon": 130, "now": 120, "here": 110,
            "there": 100, "where": 95, "when": 90, "why": 85,
            "love": 80, "miss": 75, "sorry": 200, "please": 180,
        ]

        // Code vocabulary
        contextVocabulary[.code] = [
            "func": 500, "function": 480, "let": 450, "var": 440,
            "const": 430, "if": 420, "else": 410, "for": 400,
            "while": 390, "return": 380, "class": 370, "struct": 360,
            "enum": 350, "import": 340, "export": 330, "default": 320,
            "public": 310, "private": 300, "static": 290, "async": 280,
            "await": 270, "try": 260, "catch": 250, "throw": 240,
            "nil": 230, "null": 220, "true": 210, "false": 200,
            "self": 190, "this": 180, "super": 170, "override": 160,
        ]

        // Formal vocabulary
        contextVocabulary[.formal] = [
            "therefore": 300, "furthermore": 290, "however": 280,
            "moreover": 270, "nevertheless": 260, "accordingly": 250,
            "consequently": 240, "regarding": 230, "pursuant": 220,
            "hereby": 210, "whereas": 200, "notwithstanding": 190,
            "aforementioned": 180, "undersigned": 170, "henceforth": 160,
            "herein": 150, "therein": 140, "thereto": 130,
        ]

        // Casual vocabulary
        contextVocabulary[.casual] = [
            "like": 400, "just": 380, "really": 360, "actually": 340,
            "pretty": 320, "super": 300, "totally": 280, "definitely": 260,
            "probably": 240, "maybe": 220, "kinda": 200, "sorta": 180,
            "stuff": 160, "thing": 140, "things": 120, "guys": 100,
        ]
    }

    private func getDefaultPredictions(prefix: String) -> [String] {
        // Common words as fallback
        let commonWords = [
            "the", "be", "to", "of", "and", "a", "in", "that", "have", "i",
            "it", "for", "not", "on", "with", "he", "as", "you", "do", "at",
            "this", "but", "his", "by", "from", "they", "we", "say", "her", "she"
        ]

        if prefix.isEmpty {
            return commonWords.prefix(7).map { $0.capitalized }
        }

        return commonWords
            .filter { $0.hasPrefix(prefix) }
            .prefix(7)
            .map { $0.capitalized }
    }
}
