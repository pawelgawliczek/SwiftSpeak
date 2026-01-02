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
            // Polish - comprehensive starters for all contexts
            case ("pl", .email):
                return ["szanowny", "witam", "dzien", "dziekuje", "prosze", "pozdrawiam", "drogi"]
            case ("pl", .messaging):
                return ["czesc", "hej", "co", "jak", "spoko", "ok", "siema"]
            case ("pl", .formal):
                return ["szanowni", "szanowna", "z", "w", "prosze", "dziekuje", "uprzejmie"]
            case ("pl", .casual):
                return ["hej", "siema", "no", "co", "spoko", "wiesz", "stary"]

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
        // Polish (pl) - COMPREHENSIVE vocabulary (one of the strongest languages)
        contextVocabularyByLanguage["pl"] = [
            .email: [
                // Greetings & Openings
                "szanowny": 500, "szanowna": 480, "witam": 450, "dzien": 430,
                "dobry": 420, "dziekuje": 400, "prosze": 380, "pozdrawiam": 360,
                "drogi": 350, "droga": 340, "panie": 330, "pani": 320,
                // Closings
                "z powazaniem": 350, "powazaniem": 340, "serdecznie": 320,
                "pozdrawiam": 310, "zyczenia": 300, "milego": 290, "dnia": 280,
                // Attachments & Documents
                "w zalaczeniu": 300, "zalaczeniu": 290, "zalaczam": 280,
                "przesylam": 270, "dokument": 260, "dokumenty": 250, "plik": 240,
                "pliki": 230, "raport": 220, "sprawozdanie": 210, "prezentacja": 200,
                // Actions
                "odpowiedz": 280, "odpowiadam": 270, "informuje": 260, "potwierdzam": 250,
                "pragne": 240, "zwracam": 230, "prosze": 220, "uprzejmie": 210,
                // Business terms
                "spotkanie": 270, "termin": 260, "sprawa": 250, "projekt": 240,
                "umowa": 230, "oferta": 220, "zamowienie": 210, "faktura": 200,
                "pilne": 210, "priorytetu": 200, "wazne": 190, "konieczne": 180,
                "agenda": 190, "przeglad": 170, "analiza": 160, "rozwiazanie": 150,
                // Days of week
                "poniedzialek": 100, "wtorek": 95, "sroda": 90, "czwartek": 95,
                "piatek": 100, "sobota": 80, "niedziela": 75,
                // Time
                "jutro": 150, "dzisiaj": 180, "tydzien": 160, "miesiac": 140,
                "rano": 120, "poludnie": 110, "wieczorem": 100,
                // Professional phrases
                "odnosnie": 180, "nawiazujac": 170, "w zwiazku": 160, "zgodnie": 150,
            ],
            .messaging: [
                // Greetings
                "czesc": 500, "hej": 480, "witam": 400, "siema": 390,
                "yo": 380, "elo": 370, "joł": 360,
                // Questions
                "co": 380, "tam": 370, "jak": 360, "sie": 350, "masz": 340,
                "leci": 330, "slychac": 320, "robisz": 310, "gdzie": 300,
                "kiedy": 290, "dlaczego": 280, "czemu": 270,
                // Responses
                "dzięki": 330, "ok": 320, "okej": 310, "tak": 300,
                "nie": 290, "jasne": 280, "super": 270, "spoko": 260,
                "fajnie": 250, "cool": 240, "git": 230, "luzik": 220,
                // Reactions
                "haha": 230, "lol": 220, "omg": 210, "wtf": 200,
                "wow": 190, "serio": 180, "nooo": 170, "ale": 160,
                // Common words
                "zaraz": 190, "pozniej": 180, "teraz": 170, "juz": 160,
                "jeszcze": 150, "moze": 140, "chyba": 130, "pewnie": 120,
                // Farewells
                "nara": 170, "do": 160, "zobaczenia": 150, "pa": 140,
                "papa": 130, "buziaki": 120, "do jutra": 110,
                // Emotions
                "kocham": 100, "tesknie": 90, "przepraszam": 200, "sorry": 180,
                // Slang
                "stary": 150, "ziomek": 140, "koles": 130, "morda": 100,
            ],
            .formal: [
                // Salutations
                "szanowni": 400, "panstwo": 390, "szanowny": 380, "szanowna": 370,
                "wielce": 360, "czcigodny": 350, "dostojny": 340,
                // Opening phrases
                "z gory": 380, "gory": 370, "dziekuje": 360,
                "uprzejmie": 340, "prosze": 330, "informuje": 320,
                "zwracam": 310, "sie": 300, "odnosnie": 290,
                "nawiazujac": 280, "w odpowiedzi": 270, "odpowiedzi": 260,
                // Legal/formal terms
                "zgodnie": 280, "niniejszym": 270, "w zwiazku": 260,
                "z tym": 250, "powyzszym": 240, "zatem": 230,
                "w mysl": 220, "na podstawie": 210, "stosownie": 200,
                "ponadto": 190, "wobec": 180, "czego": 170,
                // Closings
                "w zalaczeniu": 350, "lacze": 340, "wyrazy": 330,
                "szacunku": 320, "powazania": 310, "z powazaniem": 300,
                "laczę": 290, "pozdrowienia": 280, "serdeczne": 270,
                // Actions
                "wnosze": 200, "oswiadczam": 190, "zobowiazuje": 180,
                "deklaruje": 170, "potwierdza": 160, "zapewniam": 150,
            ],
            .casual: [
                // Greetings
                "hej": 500, "siema": 480, "czesc": 470, "yo": 460,
                "elo": 450, "joł": 440, "mordo": 430, "co": 420,
                // Fillers
                "no": 400, "wlasnie": 390, "tak": 380, "nie": 370,
                "wiesz": 360, "jakby": 350, "znaczy": 340, "generalnie": 330,
                // Reactions
                "super": 320, "spoko": 310, "git": 300, "luzik": 290,
                "zajebiscie": 280, "kozacko": 270, "ekstra": 260, "bomba": 250,
                // Common slang
                "ogarnac": 240, "ogarniasz": 230, "kumasz": 220, "lapiesz": 210,
                "leci": 200, "idzie": 190, "jazda": 180, "akcja": 170,
                // Negatives
                "zonk": 160, "lipa": 150, "kicha": 140, "dramat": 130,
                "masakra": 120, "porazka": 110, "klapa": 100,
                // Questions
                "powaznie": 250, "serio": 240, "naprawde": 230, "zart": 220,
                // Expressions
                "stary": 200, "ziomek": 190, "koles": 180, "gosciu": 170,
                "czlowieku": 160, "facet": 150, "laska": 140,
                // Verbs
                "ogar": 130, "wypad": 120, "bywaj": 110, "spadaj": 100,
                "luz": 300, "spokoj": 280, "wyluzuj": 260, "chilluj": 240,
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

        // Italian (it)
        contextVocabularyByLanguage["it"] = [
            .email: [
                "gentile": 500, "egregio": 480, "buongiorno": 450, "salve": 420,
                "grazie": 400, "cordiali": 380, "saluti": 360, "distinti": 340,
                "allegato": 320, "riunione": 300, "appuntamento": 280,
                "documento": 260, "urgente": 240, "priorità": 220,
                "lunedì": 100, "martedì": 95, "mercoledì": 90, "giovedì": 95,
                "venerdì": 100, "domani": 150, "oggi": 180, "settimana": 160,
            ],
            .messaging: [
                "ciao": 500, "hey": 480, "come": 450, "stai": 440,
                "bene": 430, "grazie": 420, "ok": 410, "sì": 400,
                "no": 390, "va": 380, "bene": 370, "super": 360,
                "fantastico": 350, "haha": 340, "lol": 330, "dove": 320,
                "quando": 310, "perché": 300, "a": 290, "dopo": 280,
            ],
            .formal: [
                "gentilissimo": 400, "gentilissima": 390, "egregio": 380,
                "spettabile": 370, "cordialmente": 360, "distinti": 350,
                "saluti": 340, "ringraziando": 330, "anticipatamente": 320,
                "porgo": 310, "ossequi": 300, "riferimento": 290,
                "oggetto": 280, "allegato": 270, "sottoscritto": 260,
            ]
        ]

        // Portuguese (pt)
        contextVocabularyByLanguage["pt"] = [
            .email: [
                "prezado": 500, "prezada": 480, "olá": 450, "bom": 420,
                "dia": 410, "obrigado": 400, "obrigada": 390, "cordialmente": 380,
                "atenciosamente": 360, "anexo": 340, "reunião": 320,
                "documento": 300, "urgente": 280, "prioridade": 260,
                "segunda": 100, "terça": 95, "quarta": 90, "quinta": 95,
                "sexta": 100, "amanhã": 150, "hoje": 180, "semana": 160,
            ],
            .messaging: [
                "oi": 500, "olá": 480, "como": 450, "vai": 440,
                "tudo": 430, "bem": 420, "obrigado": 410, "ok": 400,
                "sim": 390, "não": 380, "legal": 370, "massa": 360,
                "haha": 350, "lol": 340, "onde": 330, "quando": 320,
                "por": 310, "quê": 300, "até": 290, "tchau": 280,
            ],
            .formal: [
                "ilustríssimo": 400, "excelentíssimo": 390, "prezados": 380,
                "senhores": 370, "cordiais": 360, "saudações": 350,
                "atenciosamente": 340, "respeitosamente": 330, "referente": 320,
                "conforme": 310, "anexo": 300, "segue": 290,
                "solicitamos": 280, "informamos": 270, "aguardamos": 260,
            ]
        ]

        // Russian (ru)
        contextVocabularyByLanguage["ru"] = [
            .email: [
                "уважаемый": 500, "уважаемая": 480, "здравствуйте": 450,
                "добрый": 420, "день": 410, "спасибо": 400, "благодарю": 380,
                "с уважением": 360, "вложение": 340, "встреча": 320,
                "документ": 300, "срочно": 280, "приоритет": 260,
                "понедельник": 100, "вторник": 95, "среда": 90, "четверг": 95,
                "пятница": 100, "завтра": 150, "сегодня": 180, "неделя": 160,
            ],
            .messaging: [
                "привет": 500, "здравствуй": 480, "как": 450, "дела": 440,
                "хорошо": 430, "спасибо": 420, "ок": 410, "да": 400,
                "нет": 390, "классно": 380, "круто": 370, "супер": 360,
                "хаха": 350, "лол": 340, "где": 330, "когда": 320,
                "почему": 310, "зачем": 300, "пока": 290, "давай": 280,
            ],
            .formal: [
                "глубокоуважаемый": 400, "многоуважаемый": 390, "уважаемые": 380,
                "господа": 370, "искренне": 360, "ваш": 350,
                "с уважением": 340, "с почтением": 330, "касательно": 320,
                "относительно": 310, "приложение": 300, "прилагается": 290,
                "просим": 280, "сообщаем": 270, "надеемся": 260,
            ]
        ]
    }
}
