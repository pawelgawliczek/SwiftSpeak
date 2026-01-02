//
//  ItalianAutocorrectService.swift
//  SwiftSpeak
//
//  Italian language autocorrection service
//  Handles accent restoration, proper nouns, and common corrections
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

/// Italian autocorrection service for intelligent Italian text correction
enum ItalianAutocorrectService {

    // MARK: - Main Correction Method

    /// Fix Italian word - restores accents and applies corrections
    /// Returns nil if no correction needed
    static func fixItalianWord(_ word: String) -> String? {
        let lowercased = word.lowercased()

        // Check for accent corrections (most common need)
        if let corrected = italianAccents[lowercased] {
            return preserveCase(original: word, corrected: corrected)
        }

        // Check for proper nouns (cities, etc.)
        if let properNoun = italianProperNouns[lowercased] {
            return properNoun
        }

        return nil
    }

    /// Check if word should be capitalized (Italian proper nouns)
    static func shouldCapitalizeItalian(_ word: String) -> String? {
        let lowercased = word.lowercased()
        return italianProperNouns[lowercased]
    }

    // MARK: - Helper Methods

    /// Preserve the original case pattern when applying correction
    private static func preserveCase(original: String, corrected: String) -> String {
        guard !original.isEmpty, !corrected.isEmpty else { return corrected }

        let isAllCaps = original == original.uppercased() && original.count > 1
        let isCapitalized = original.first?.isUppercase ?? false

        if isAllCaps {
            return corrected.uppercased()
        } else if isCapitalized {
            return corrected.prefix(1).uppercased() + corrected.dropFirst()
        }
        return corrected
    }

    // MARK: - Italian Accents Dictionary
    // Words typed without accents → correct form with accents

    private static let italianAccents: [String: String] = [
        // ==========================================
        // MOST COMMON ACCENT WORDS (high frequency)
        // ==========================================

        // È/é - "is" vs "and" distinction
        "e": "è",  // is (when standalone, context-dependent - keyboard should offer both)
        "perche": "perché", "perché": "perché",
        "affinche": "affinché", "benche": "benché", "finche": "finché",
        "giacche": "giacché", "poiche": "poiché", "purche": "purché",
        "sicche": "sicché", "cosicche": "cosicché",

        // Ciò - that/this
        "cioe": "cioè", "percio": "perciò",

        // Può/più - can/more
        "puo": "può", "piu": "più",

        // Sì - yes
        "si": "sì",  // yes (when standalone, context-dependent)

        // Già - already
        "gia": "già",

        // Così - so/thus
        "cosi": "così",

        // Là/lì - there/here
        "la": "là",  // there (context-dependent - "la" = the/it/her)
        "li": "lì",  // there (context-dependent - "li" = them)

        // Né - neither/nor
        "ne": "né",  // neither/nor (context-dependent - "ne" = of it/some)

        // ==========================================
        // COMMON VERBS WITH ACCENTS
        // ==========================================

        // Essere (to be) - future/remote past
        "sara": "sarà", "saro": "sarò", "saranno": "saranno",
        "fu": "fu", "fui": "fui",

        // Avere (to have) - future
        "avra": "avrà", "avro": "avrò", "avranno": "avranno",

        // Fare (to do/make) - future
        "fara": "farà", "faro": "farò", "faranno": "faranno",

        // Andare (to go) - future
        "andra": "andrà", "andro": "andrò", "andranno": "andranno",

        // Potere (to be able) - future
        "potra": "potrà", "potro": "potrò", "potranno": "potranno",

        // Volere (to want) - future
        "vorra": "vorrà", "vorro": "vorrò", "vorranno": "vorranno",

        // Dovere (to have to) - future
        "dovra": "dovrà", "dovro": "dovrò", "dovranno": "dovranno",

        // Venire (to come) - future
        "verra": "verrà", "verro": "verrò", "verranno": "verranno",

        // Stare (to stay/be) - future
        "stara": "starà", "staro": "starò", "staranno": "staranno",

        // Dire (to say) - future
        "dira": "dirà", "diro": "dirò", "diranno": "diranno",

        // Dare (to give) - future/present
        "dara": "darà", "daro": "darò", "da": "dà", "daranno": "daranno",

        // Sapere (to know) - future
        "sapra": "saprà", "sapro": "saprò", "sapranno": "sapranno",

        // Vedere (to see) - future
        "vedra": "vedrà", "vedro": "vedrò", "vedranno": "vedranno",

        // ==========================================
        // COMMON NOUNS WITH ACCENTS
        // ==========================================

        // -tà endings (feminines)
        "citta": "città", "universita": "università", "liberta": "libertà",
        "verita": "verità", "felicita": "felicità", "capacita": "capacità",
        "possibilita": "possibilità", "qualita": "qualità", "quantita": "quantità",
        "societa": "società", "comunita": "comunità", "realta": "realtà",
        "attivita": "attività", "difficolta": "difficoltà", "opportunita": "opportunità",
        "responsabilita": "responsabilità", "disponibilita": "disponibilità",
        "necessita": "necessità", "facolta": "facoltà", "varieta": "varietà",
        "novita": "novità", "curiosita": "curiosità", "eta": "età",
        "onesta": "onestà", "bonta": "bontà", "carita": "carità",
        "volonta": "volontà", "umanita": "umanità", "creativita": "creatività",
        "identita": "identità", "dignita": "dignità", "serenita": "serenità",
        "oscurita": "oscurità", "stabilita": "stabilità", "unita": "unità",
        "meta": "metà", "eredita": "eredità", "santita": "santità",

        // -tù endings
        "virtu": "virtù", "gioventu": "gioventù", "servitu": "servitù",

        // Food and drink
        "caffe": "caffè", "te": "tè",
        "tiramisu": "tiramisù",

        // Other common words
        "lunedi": "lunedì", "martedi": "martedì", "mercoledi": "mercoledì",
        "giovedi": "giovedì", "venerdi": "venerdì",
        "pero": "però", // however (also: pear tree - context)
        "piu": "più", "giu": "giù", "su": "su",
        "blu": "blu", // no accent needed
        "cio": "ciò",
        "tre": "tre", // no accent (but trentatré has one)
        "trentatre": "trentatré",

        // ==========================================
        // COMMON PHRASES/EXPRESSIONS
        // ==========================================

        "ce": "c'è",  // there is (contraction of ci + è)
        "com'e": "com'è",  // how is
        "dov'e": "dov'è",  // where is
        "cos'e": "cos'è",  // what is
        "quand'e": "quand'è",  // when is
        "chi'e": "chi è",  // who is
        "cose": "cos'è",  // common typo for "what is"
        "dove": "dov'è",  // common typo for "where is"

        // ==========================================
        // ADVERBS AND CONJUNCTIONS
        // ==========================================

        "ormai": "ormai",  // no accent
        "eppure": "eppure",  // no accent
        "oppure": "oppure",  // no accent
        "anziche": "anziché",
        "nonche": "nonché",
        "allorche": "allorché",
        "laggiu": "laggiù",
        "lassu": "lassù",
        "quassu": "quassù",
        "quaggiu": "quaggiù",

        // ==========================================
        // QUESTION WORDS
        // ==========================================

        "come": "come",  // no accent (how)
        "dove": "dove",  // no accent (where) - also dov'è contraction
        "quando": "quando",  // no accent (when)
        "quanto": "quanto",  // no accent (how much)
        "chi": "chi",  // no accent (who)
        "che": "che",  // no accent (what/that)

        // ==========================================
        // COMMON GREETINGS/EXPRESSIONS
        // ==========================================

        "buongiorno": "buongiorno",  // no accent
        "buonasera": "buonasera",  // no accent
        "buonanotte": "buonanotte",  // no accent
        "arrivederci": "arrivederci",  // no accent
        "ciao": "ciao",  // no accent
        "salve": "salve",  // no accent
        "grazie": "grazie",  // no accent
        "prego": "prego",  // no accent
        "scusa": "scusa",  // no accent
        "scusi": "scusi",  // no accent
    ]

    // MARK: - Italian Proper Nouns
    // Cities, regions, and other proper nouns requiring capitalization

    private static let italianProperNouns: [String: String] = [
        // Major Italian cities
        "roma": "Roma",
        "milano": "Milano",
        "napoli": "Napoli",
        "torino": "Torino",
        "palermo": "Palermo",
        "genova": "Genova",
        "bologna": "Bologna",
        "firenze": "Firenze",
        "bari": "Bari",
        "catania": "Catania",
        "venezia": "Venezia",
        "verona": "Verona",
        "messina": "Messina",
        "padova": "Padova",
        "trieste": "Trieste",
        "taranto": "Taranto",
        "brescia": "Brescia",
        "parma": "Parma",
        "prato": "Prato",
        "modena": "Modena",
        "reggio calabria": "Reggio Calabria",
        "reggio emilia": "Reggio Emilia",
        "perugia": "Perugia",
        "ravenna": "Ravenna",
        "livorno": "Livorno",
        "cagliari": "Cagliari",
        "foggia": "Foggia",
        "rimini": "Rimini",
        "salerno": "Salerno",
        "ferrara": "Ferrara",
        "sassari": "Sassari",
        "latina": "Latina",
        "giugliano": "Giugliano",
        "monza": "Monza",
        "siracusa": "Siracusa",
        "pescara": "Pescara",
        "bergamo": "Bergamo",
        "forlì": "Forlì",
        "forli": "Forlì",
        "trento": "Trento",
        "vicenza": "Vicenza",
        "terni": "Terni",
        "bolzano": "Bolzano",
        "novara": "Novara",
        "piacenza": "Piacenza",
        "ancona": "Ancona",
        "andria": "Andria",
        "arezzo": "Arezzo",
        "udine": "Udine",
        "cesena": "Cesena",
        "lecce": "Lecce",
        "pesaro": "Pesaro",
        "barletta": "Barletta",
        "alessandria": "Alessandria",
        "la spezia": "La Spezia",
        "pisa": "Pisa",
        "catanzaro": "Catanzaro",
        "lucca": "Lucca",
        "como": "Como",
        "treviso": "Treviso",
        "varese": "Varese",
        "grosseto": "Grosseto",
        "caserta": "Caserta",
        "asti": "Asti",
        "ragusa": "Ragusa",
        "cremona": "Cremona",
        "pavia": "Pavia",
        "massa": "Massa",
        "trapani": "Trapani",
        "cosenza": "Cosenza",
        "potenza": "Potenza",
        "viterbo": "Viterbo",
        "crotone": "Crotone",
        "caltanissetta": "Caltanissetta",
        "benevento": "Benevento",
        "brindisi": "Brindisi",
        "cuneo": "Cuneo",
        "olbia": "Olbia",
        "pordenone": "Pordenone",
        "campobasso": "Campobasso",
        "aosta": "Aosta",
        "matera": "Matera",
        "agrigento": "Agrigento",
        "siena": "Siena",
        "nuoro": "Nuoro",
        "mantova": "Mantova",
        "avellino": "Avellino",
        "isernia": "Isernia",
        "rieti": "Rieti",
        "rovigo": "Rovigo",
        "enna": "Enna",
        "belluno": "Belluno",
        "oristano": "Oristano",
        "sondrio": "Sondrio",
        "l'aquila": "L'Aquila",
        "laquila": "L'Aquila",
        "chieti": "Chieti",
        "teramo": "Teramo",
        "ascoli piceno": "Ascoli Piceno",
        "fermo": "Fermo",
        "macerata": "Macerata",
        "urbino": "Urbino",
        "gorizia": "Gorizia",

        // Italian Regions
        "lombardia": "Lombardia",
        "lazio": "Lazio",
        "campania": "Campania",
        "sicilia": "Sicilia",
        "veneto": "Veneto",
        "emilia-romagna": "Emilia-Romagna",
        "emilia romagna": "Emilia-Romagna",
        "piemonte": "Piemonte",
        "puglia": "Puglia",
        "toscana": "Toscana",
        "calabria": "Calabria",
        "sardegna": "Sardegna",
        "liguria": "Liguria",
        "marche": "Marche",
        "abruzzo": "Abruzzo",
        "friuli-venezia giulia": "Friuli-Venezia Giulia",
        "friuli venezia giulia": "Friuli-Venezia Giulia",
        "trentino-alto adige": "Trentino-Alto Adige",
        "trentino alto adige": "Trentino-Alto Adige",
        "umbria": "Umbria",
        "basilicata": "Basilicata",
        "molise": "Molise",
        "valle d'aosta": "Valle d'Aosta",
        "valle daosta": "Valle d'Aosta",

        // Italy and nearby countries
        "italia": "Italia",
        "svizzera": "Svizzera",
        "francia": "Francia",
        "austria": "Austria",
        "slovenia": "Slovenia",
        "croazia": "Croazia",
        "germania": "Germania",
        "spagna": "Spagna",
        "portogallo": "Portogallo",
        "grecia": "Grecia",
        "regno unito": "Regno Unito",
        "stati uniti": "Stati Uniti",
        "canada": "Canada",
        "australia": "Australia",
        "giappone": "Giappone",
        "cina": "Cina",
        "india": "India",
        "brasile": "Brasile",
        "argentina": "Argentina",
        "messico": "Messico",
        "russia": "Russia",
        "europa": "Europa",
        "america": "America",
        "asia": "Asia",
        "africa": "Africa",
        "oceania": "Oceania",

        // Rivers, mountains, seas
        "tevere": "Tevere",
        "po": "Po",
        "arno": "Arno",
        "adige": "Adige",
        "piave": "Piave",
        "brenta": "Brenta",
        "reno": "Reno",
        "tirreno": "Tirreno",
        "adriatico": "Adriatico",
        "mediterraneo": "Mediterraneo",
        "alpi": "Alpi",
        "dolomiti": "Dolomiti",
        "appennini": "Appennini",
        "etna": "Etna",
        "vesuvio": "Vesuvio",
        "monte bianco": "Monte Bianco",

        // Famous places and landmarks
        "vaticano": "Vaticano",
        "colosseo": "Colosseo",
        "san pietro": "San Pietro",
        "cappella sistina": "Cappella Sistina",
        "fontana di trevi": "Fontana di Trevi",
        "piazza san marco": "Piazza San Marco",
        "ponte vecchio": "Ponte Vecchio",
        "duomo": "Duomo",
        "uffizi": "Uffizi",
        "accademia": "Accademia",
        "pompei": "Pompei",
        "ercolano": "Ercolano",
        "cinque terre": "Cinque Terre",
        "costiera amalfitana": "Costiera Amalfitana",
    ]

    // MARK: - Italian Abbreviations

    /// Common Italian abbreviations
    static let italianAbbreviations: Set<String> = [
        // Titles
        "sig.", "sig.ra", "sig.na", "dott.", "dott.ssa", "prof.", "prof.ssa",
        "ing.", "avv.", "arch.", "geom.", "rag.",
        "on.", "sen.", "dep.",

        // Common abbreviations
        "tel.", "cell.", "fax",
        "n.", "nr.", "pag.", "pagg.", "p.", "pp.",
        "es.", "ecc.", "etc.",
        "cfr.", "vd.", "v.",
        "ca.", "c.a.",
        "s.p.a.", "s.r.l.", "s.n.c.", "s.a.s.",
        "c.so", "v.le", "p.za", "p.le",

        // Time and dates
        "h.", "min.", "sec.",
        "gg.", "sett.", "aa.",
        "a.c.", "d.c.",

        // Days (abbreviated)
        "lun.", "mar.", "mer.", "gio.", "ven.", "sab.", "dom.",

        // Months (abbreviated)
        "gen.", "feb.", "mar.", "apr.", "mag.", "giu.",
        "lug.", "ago.", "set.", "ott.", "nov.", "dic.",

        // Measurements
        "km", "m", "cm", "mm",
        "kg", "g", "mg",
        "l", "ml",
        "mq", "mc",

        // Currency
        "€", "eur",
    ]
}
