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

    // Context-specific vocabulary (English)
    private var contextVocabulary: [TypingContextType: [String: Int]] = [:]

    // Multi-language context vocabulary
    // Language code -> Context -> Word -> Frequency
    private var contextVocabularyByLanguage: [String: [TypingContextType: [String: Int]]] = [:]

    // Current detected context
    private var currentContext: TypingContextType = .unknown

    private var isInitialized = false

    private init() {}

    // MARK: - Initialization

    func initialize() async {
        guard !isInitialized else { return }

        loadContextVocabulary()
        loadMultiLanguageVocabulary()
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
    func getPredictions(for prefix: String, context: TypingContextType? = nil, language: String? = nil) -> [String] {
        let ctx = context ?? currentContext
        let lowercased = prefix.lowercased()

        // Get language-specific vocabulary if available
        var vocab: [String: Int]?

        if let lang = language, let langVocab = contextVocabularyByLanguage[lang], let contextVocab = langVocab[ctx] {
            vocab = contextVocab
        } else {
            // Fallback to English vocabulary
            vocab = contextVocabulary[ctx]
        }

        // Get context-specific words
        guard let vocab = vocab else {
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
    func getStarterPredictions(for context: TypingContextType, language: String? = nil) -> [String] {
        // Check for language-specific starters
        if let lang = language {
            switch (lang, context) {
            // Polish
            case ("pl", .email):
                return ["szanowny", "witam", "dzień", "dziękuję", "proszę", "pozdrawiam"]
            case ("pl", .messaging):
                return ["cześć", "hej", "co", "jak", "spoko", "ok"]
            case ("pl", .formal):
                return ["szanowni", "szanowna", "z", "w", "proszę", "dziękuję"]

            // Spanish
            case ("es", .email):
                return ["estimado", "hola", "buenos", "gracias", "por", "favor"]
            case ("es", .messaging):
                return ["hola", "qué", "cómo", "hasta", "vale", "ok"]
            case ("es", .formal):
                return ["estimados", "distinguido", "por", "favor", "gracias", "atentamente"]

            // French
            case ("fr", .email):
                return ["cher", "bonjour", "merci", "veuillez", "cordialement", "bien"]
            case ("fr", .messaging):
                return ["salut", "ça", "comment", "à", "ok", "super"]
            case ("fr", .formal):
                return ["madame", "monsieur", "veuillez", "je", "nous", "cordialement"]

            // German
            case ("de", .email):
                return ["sehr", "hallo", "guten", "danke", "bitte", "mit"]
            case ("de", .messaging):
                return ["hallo", "hi", "wie", "bis", "ok", "toll"]
            case ("de", .formal):
                return ["sehr", "geehrter", "geehrte", "bitte", "danke", "mit"]

            default:
                break
            }
        }

        // Default English starters
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

    // MARK: - Multi-Language Vocabulary

    private func loadMultiLanguageVocabulary() {
        // Polish (pl)
        contextVocabularyByLanguage["pl"] = [
            .email: [
                "szanowny": 500, "szanowna": 480, "witam": 450, "dzień": 430,
                "dobry": 420, "dziękuję": 400, "proszę": 380, "pozdrawiam": 360,
                "z poważaniem": 350, "poważaniem": 340, "serdecznie": 320,
                "w załączeniu": 300, "załączeniu": 290, "odpowiedź": 280,
                "spotkanie": 270, "termin": 260, "sprawa": 250, "projekt": 240,
                "raport": 230, "dokument": 220, "pilne": 210, "priorytetu": 200,
                "agenda": 190, "prezentacja": 180, "przegląd": 170,
                "poniedziałek": 100, "wtorek": 95, "środa": 90, "czwartek": 95,
                "piątek": 100, "jutro": 150, "dzisiaj": 180, "tydzień": 160,
            ],
            .messaging: [
                "cześć": 500, "hej": 480, "witam": 400, "co": 380,
                "tam": 370, "jak": 360, "się": 350, "masz": 340,
                "dzięki": 330, "ok": 320, "okej": 310, "tak": 300,
                "nie": 290, "jasne": 280, "super": 270, "spoko": 260,
                "fajnie": 250, "cool": 240, "haha": 230, "lol": 220,
                "omg": 210, "btw": 200, "zaraz": 190, "później": 180,
                "nara": 170, "do": 160, "zobaczenia": 150, "pa": 140,
                "gdzie": 130, "kiedy": 120, "dlaczego": 110, "kocham": 100,
            ],
            .formal: [
                "szanowni": 400, "państwo": 390, "z góry": 380,
                "góry": 370, "dziękuję": 360, "w załączeniu": 350,
                "uprzejmie": 340, "proszę": 330, "informuję": 320,
                "zwracam": 310, "się": 300, "odnośnie": 290,
                "zgodnie": 280, "niniejszym": 270, "w związku": 260,
                "z tym": 250, "powyższym": 240, "zatem": 230,
            ]
        ]

        // Spanish (es)
        contextVocabularyByLanguage["es"] = [
            .email: [
                "estimado": 500, "estimada": 480, "hola": 450, "buenos": 430,
                "días": 420, "gracias": 400, "por": 380, "favor": 360,
                "saludos": 350, "cordialmente": 340, "atentamente": 330,
                "cordiales": 320, "adjunto": 310, "reunión": 300,
                "agenda": 290, "informe": 280, "documento": 270,
                "urgente": 260, "prioridad": 250, "proyecto": 240,
                "lunes": 100, "martes": 95, "miércoles": 90, "jueves": 95,
                "viernes": 100, "mañana": 150, "hoy": 180, "semana": 160,
            ],
            .messaging: [
                "hola": 500, "hey": 480, "qué": 450, "tal": 440,
                "cómo": 430, "estás": 420, "gracias": 410, "ok": 400,
                "vale": 390, "sí": 380, "no": 370, "claro": 360,
                "genial": 350, "super": 340, "jaja": 330, "lol": 320,
                "omg": 310, "hasta": 300, "luego": 290, "pronto": 280,
                "dónde": 270, "cuándo": 260, "por qué": 250, "amor": 240,
            ],
            .formal: [
                "estimados": 400, "señores": 390, "distinguido": 380,
                "distinguida": 370, "por": 360, "favor": 350,
                "agradezco": 340, "cordialmente": 330, "atentamente": 320,
                "respecto": 310, "referencia": 300, "conformidad": 290,
                "presente": 280, "adjunto": 270, "mediante": 260,
            ]
        ]

        // French (fr)
        contextVocabularyByLanguage["fr"] = [
            .email: [
                "cher": 500, "chère": 480, "bonjour": 450, "madame": 430,
                "monsieur": 420, "merci": 400, "beaucoup": 380,
                "veuillez": 360, "cordialement": 350, "bien": 340,
                "vous": 330, "salutations": 320, "pièce": 310,
                "jointe": 300, "réunion": 290, "rendez-vous": 280,
                "rapport": 270, "document": 260, "urgent": 250,
                "lundi": 100, "mardi": 95, "mercredi": 90, "jeudi": 95,
                "vendredi": 100, "demain": 150, "aujourd'hui": 180, "semaine": 160,
            ],
            .messaging: [
                "salut": 500, "coucou": 480, "ça": 450, "va": 440,
                "comment": 430, "vas": 420, "merci": 410, "ok": 400,
                "d'accord": 390, "oui": 380, "non": 370, "super": 360,
                "génial": 350, "cool": 340, "mdr": 330, "lol": 320,
                "omg": 310, "à": 300, "plus": 290, "tard": 280,
                "où": 270, "quand": 260, "pourquoi": 250, "bisous": 240,
            ],
            .formal: [
                "madame": 400, "monsieur": 390, "messieurs": 380,
                "veuillez": 370, "agréer": 360, "cordialement": 350,
                "respectueusement": 340, "concernant": 330, "objet": 320,
                "conformément": 310, "ci-joint": 300, "par": 290,
                "présente": 280, "suite": 270, "référence": 260,
            ]
        ]

        // German (de)
        contextVocabularyByLanguage["de"] = [
            .email: [
                "sehr": 500, "geehrter": 480, "geehrte": 470, "hallo": 450,
                "guten": 440, "tag": 430, "danke": 420, "vielen": 410,
                "dank": 400, "bitte": 390, "mit": 380, "freundlichen": 370,
                "grüßen": 360, "grüße": 350, "anhang": 340,
                "besprechung": 330, "termin": 320, "bericht": 310,
                "dokument": 300, "dringend": 290, "priorität": 280,
                "montag": 100, "dienstag": 95, "mittwoch": 90, "donnerstag": 95,
                "freitag": 100, "morgen": 150, "heute": 180, "woche": 160,
            ],
            .messaging: [
                "hallo": 500, "hi": 480, "hey": 470, "wie": 450,
                "geht's": 440, "gehts": 430, "danke": 420, "ok": 410,
                "okay": 400, "ja": 390, "nein": 380, "klar": 370,
                "super": 360, "toll": 350, "cool": 340, "haha": 330,
                "lol": 320, "omg": 310, "bis": 300, "später": 290,
                "tschüss": 280, "wo": 270, "wann": 260, "warum": 250,
            ],
            .formal: [
                "sehr": 400, "geehrte": 390, "damen": 380,
                "herren": 370, "bitte": 360, "danke": 350,
                "hochachtungsvoll": 340, "mit": 330, "freundlichen": 320,
                "grüßen": 310, "bezüglich": 300, "betreff": 290,
                "anlage": 280, "gemäß": 270, "hiermit": 260,
            ]
        ]
    }
}
