//
//  SpanishAutocorrectService.swift
//  SwiftSpeakKeyboard
//
//  Spanish language autocorrection service
//  Handles accent restoration, common misspellings, ñ restoration, and proper noun capitalization
//

import Foundation

/// Spanish autocorrection service for intelligent Spanish text correction
enum SpanishAutocorrectService {

    // MARK: - Main Correction Method

    /// Fix Spanish word - restores accents, ñ, and applies corrections
    /// Returns nil if no correction needed
    static func fixSpanishWord(_ word: String) -> String? {
        let lowercased = word.lowercased()

        // Check for accent corrections (most common need)
        if let corrected = spanishAccents[lowercased] {
            return preserveCase(original: word, corrected: corrected)
        }

        // Check for common misspellings
        if let corrected = spanishMisspellings[lowercased] {
            return preserveCase(original: word, corrected: corrected)
        }

        // Check for proper nouns (cities, countries, etc.)
        if let properNoun = spanishProperNouns[lowercased] {
            return properNoun
        }

        return nil
    }

    /// Check if word should be capitalized (Spanish proper nouns)
    static func shouldCapitalizeSpanish(_ word: String) -> String? {
        let lowercased = word.lowercased()
        return spanishProperNouns[lowercased]
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

    // MARK: - Spanish Accents Dictionary
    // Words typed without accents -> correct form with accents

    private static let spanishAccents: [String: String] = [
        // ==========================================
        // INTERROGATIVE/EXCLAMATORY WORDS (always accented)
        // ==========================================
        "que": "qué",           // what (interrogative)
        "quien": "quién",       // who (interrogative)
        "quienes": "quiénes",   // who (plural interrogative)
        "cual": "cuál",         // which (interrogative)
        "cuales": "cuáles",     // which (plural)
        "como": "cómo",         // how (interrogative)
        "cuando": "cuándo",     // when (interrogative)
        "donde": "dónde",       // where (interrogative)
        "adonde": "adónde",     // to where
        "cuanto": "cuánto",     // how much
        "cuanta": "cuánta",
        "cuantos": "cuántos",
        "cuantas": "cuántas",
        "porque": "porqué",     // reason/why (noun)

        // ==========================================
        // COMMON MONOSYLLABLES WITH DIACRITICS
        // ==========================================
        "si": "sí",             // yes (vs si = if)
        "tu": "tú",             // you (vs tu = your)
        "el": "él",             // he (vs el = the)
        "mi": "mí",             // me (vs mi = my)
        "mas": "más",           // more (vs mas = but)
        "aun": "aún",           // still/yet
        "solo": "sólo",         // only (optional but common)

        // ==========================================
        // COMMON VERBS - PRESENT TENSE
        // ==========================================
        // Estar (to be - state/location)
        "esta": "está",
        "estan": "están",
        "estare": "estaré",
        "estaras": "estarás",
        "estara": "estará",
        "estaremos": "estaremos",
        "estaran": "estarán",
        "estaria": "estaría",
        "estarias": "estarías",
        "estariamos": "estaríamos",
        "estarian": "estarían",
        "estabamos": "estábamos",

        // Ser (to be - essence)
        "sera": "será",
        "seras": "serás",
        "seran": "serán",
        "seria": "sería",
        "serias": "serías",
        "seriamos": "seríamos",
        "serian": "serían",
        "eramos": "éramos",

        // Tener (to have)
        "tendre": "tendré",
        "tendras": "tendrás",
        "tendra": "tendrá",
        "tendremos": "tendremos",
        "tendran": "tendrán",
        "tendria": "tendría",
        "tendrias": "tendrías",
        "tendriamos": "tendríamos",
        "tendrian": "tendrían",
        "tenia": "tenía",
        "tenias": "tenías",
        "teniamos": "teníamos",
        "tenian": "tenían",

        // Poder (to be able)
        "podre": "podré",
        "podras": "podrás",
        "podra": "podrá",
        "podremos": "podremos",
        "podran": "podrán",
        "podria": "podría",
        "podrias": "podrías",
        "podriamos": "podríamos",
        "podrian": "podrían",
        "podia": "podía",
        "podias": "podías",
        "podiamos": "podíamos",
        "podian": "podían",

        // Querer (to want)
        "querre": "querré",
        "querras": "querrás",
        "querra": "querrá",
        "querremos": "querremos",
        "querran": "querrán",
        "querria": "querría",
        "querrias": "querrías",
        "querriamos": "querríamos",
        "querrian": "querrían",
        "queria": "quería",
        "querias": "querías",
        "queriamos": "queríamos",
        "querian": "querían",

        // Saber (to know)
        "sabre": "sabré",
        "sabras": "sabrás",
        "sabra": "sabrá",
        "sabremos": "sabremos",
        "sabran": "sabrán",
        "sabria": "sabría",
        "sabrias": "sabrías",
        "sabriamos": "sabríamos",
        "sabrian": "sabrían",
        "sabia": "sabía",
        "sabias": "sabías",
        "sabiamos": "sabíamos",
        "sabian": "sabían",

        // Hacer (to do/make)
        "hare": "haré",
        "haras": "harás",
        "hara": "hará",
        "haremos": "haremos",
        "haran": "harán",
        "haria": "haría",
        "harias": "harías",
        "hariamos": "haríamos",
        "harian": "harían",
        "hacia": "hacía",
        "hacias": "hacías",
        "haciamos": "hacíamos",
        "hacian": "hacían",

        // Ir (to go)
        "ire": "iré",
        "iras": "irás",
        "ira": "irá",
        "iremos": "iremos",
        "iran": "irán",
        "iria": "iría",
        "irias": "irías",
        "iriamos": "iríamos",
        "irian": "irían",
        "ibamos": "íbamos",

        // Venir (to come)
        "vendre": "vendré",
        "vendras": "vendrás",
        "vendra": "vendrá",
        "vendremos": "vendremos",
        "vendran": "vendrán",
        "vendria": "vendría",
        "vendrias": "vendrías",
        "vendriamos": "vendríamos",
        "vendrian": "vendrían",
        "venia": "venía",
        "venias": "venías",
        "veniamos": "veníamos",
        "venian": "venían",

        // Decir (to say)
        "dire": "diré",
        "diras": "dirás",
        "dira": "dirá",
        "diremos": "diremos",
        "diran": "dirán",
        "diria": "diría",
        "dirias": "dirías",
        "diriamos": "diríamos",
        "dirian": "dirían",
        "decia": "decía",
        "decias": "decías",
        "deciamos": "decíamos",
        "decian": "decían",

        // Salir (to leave)
        "saldre": "saldré",
        "saldras": "saldrás",
        "saldra": "saldrá",
        "saldremos": "saldremos",
        "saldran": "saldrán",
        "saldria": "saldría",
        "saldrias": "saldrías",
        "saldriamos": "saldríamos",
        "saldrian": "saldrían",
        "salia": "salía",
        "salias": "salías",
        "saliamos": "salíamos",
        "salian": "salían",

        // Vivir (to live)
        "vivia": "vivía",
        "vivias": "vivías",
        "viviamos": "vivíamos",
        "vivian": "vivían",
        "viviria": "viviría",
        "vivirias": "vivirías",
        "viviriamos": "viviríamos",
        "vivirian": "vivirían",

        // Escribir (to write)
        "escribia": "escribía",
        "escribias": "escribías",
        "escribiamos": "escribíamos",
        "escribian": "escribían",

        // ==========================================
        // COMMON VERBS - PAST TENSE (PRETERITE)
        // ==========================================
        "hable": "hablé",
        "hablo": "habló",
        "comi": "comí",
        "comio": "comió",
        "vivi": "viví",
        "vivio": "vivió",
        "llegue": "llegué",
        "llego": "llegó",
        "pense": "pensé",
        "penso": "pensó",
        "trabaje": "trabajé",
        "trabajo": "trabajó",
        "compre": "compré",
        "compro": "compró",
        "llame": "llamé",
        "llamo": "llamó",
        "termine": "terminé",
        "termino": "terminó",
        "empezo": "empezó",
        "empece": "empecé",
        "encontre": "encontré",
        "encontro": "encontró",
        "pase": "pasé",
        "paso": "pasó",
        "deje": "dejé",
        "dejo": "dejó",
        "tome": "tomé",
        "tomo": "tomó",
        "mire": "miré",
        "miro": "miró",
        "escuche": "escuché",
        "escucho": "escuchó",
        "pregunte": "pregunté",
        "pregunto": "preguntó",
        "conteste": "contesté",
        "contesto": "contestó",
        "viaje": "viajé",
        "viajo": "viajó",
        "cambie": "cambié",
        "cambio": "cambió",
        "pague": "pagué",
        "pago": "pagó",
        "busque": "busqué",
        "busco": "buscó",
        "envie": "envié",
        "envio": "envió",
        "nacio": "nació",
        "murio": "murió",
        "cayo": "cayó",
        "oyo": "oyó",
        "leyo": "leyó",

        // ==========================================
        // COMMON NOUNS WITH ACCENTS
        // ==========================================
        // Technology
        "telefono": "teléfono",
        "telefonos": "teléfonos",
        "electronico": "electrónico",
        "electronica": "electrónica",
        "electronicos": "electrónicos",
        "electronicas": "electrónicas",
        "informatica": "informática",
        "automatico": "automático",
        "automatica": "automática",
        "tecnologia": "tecnología",
        "tecnologias": "tecnologías",
        "pagina": "página",
        "paginas": "páginas",

        // Food and drink
        "cafe": "café",
        "cafes": "cafés",
        "limon": "limón",
        "limones": "limones",
        "melon": "melón",
        "melocoton": "melocotón",
        "jamon": "jamón",
        "salmon": "salmón",
        "camaron": "camarón",
        "atun": "atún",
        "menu": "menú",
        "menus": "menús",

        // Time and dates
        "dia": "día",
        "dias": "días",
        "sabado": "sábado",
        "sabados": "sábados",
        "miercoles": "miércoles",
        "proxima": "próxima",
        "proximo": "próximo",
        "proximos": "próximos",
        "proximas": "próximas",
        "ultimo": "último",
        "ultima": "última",
        "ultimos": "últimos",
        "ultimas": "últimas",
        "despues": "después",
        "todavia": "todavía",
        "manana": "mañana",
        "mananas": "mañanas",
        "ano": "año",
        "anos": "años",

        // People and relationships
        "papa": "papá",
        "papas": "papás",
        "mama": "mamá",
        "mamas": "mamás",
        "bebe": "bebé",
        "bebes": "bebés",
        "nino": "niño",
        "nina": "niña",
        "ninos": "niños",
        "ninas": "niñas",
        "companero": "compañero",
        "companera": "compañera",
        "companeros": "compañeros",
        "companeras": "compañeras",
        "compania": "compañía",
        "companias": "compañías",

        // Places
        "pais": "país",
        "paises": "países",
        "jardin": "jardín",
        "jardines": "jardines",
        "habitacion": "habitación",
        "habitaciones": "habitaciones",
        "estacion": "estación",
        "estaciones": "estaciones",
        "direccion": "dirección",
        "direcciones": "direcciones",
        "informacion": "información",
        "educacion": "educación",
        "poblacion": "población",
        "region": "región",
        "regiones": "regiones",
        "nacion": "nación",
        "naciones": "naciones",

        // Abstract concepts
        "razon": "razón",
        "razones": "razones",
        "opinion": "opinión",
        "opiniones": "opiniones",
        "decision": "decisión",
        "decisiones": "decisiones",
        "situacion": "situación",
        "situaciones": "situaciones",
        "relacion": "relación",
        "relaciones": "relaciones",
        "solucion": "solución",
        "soluciones": "soluciones",
        "condicion": "condición",
        "condiciones": "condiciones",
        "comunicacion": "comunicación",
        "organizacion": "organización",
        "administracion": "administración",
        "atencion": "atención",
        "intencion": "intención",
        "intenciones": "intenciones",
        "cancion": "canción",
        "canciones": "canciones",
        "tradicion": "tradición",
        "tradiciones": "tradiciones",
        "revolucion": "revolución",
        "corazon": "corazón",
        "corazones": "corazones",

        // Music and culture
        "musica": "música",
        "pelicula": "película",
        "peliculas": "películas",

        // ==========================================
        // COMMON ADJECTIVES WITH ACCENTS
        // ==========================================
        "facil": "fácil",
        "faciles": "fáciles",
        "dificil": "difícil",
        "dificiles": "difíciles",
        "rapido": "rápido",
        "rapida": "rápida",
        "rapidos": "rápidos",
        "rapidas": "rápidas",
        "util": "útil",
        "utiles": "útiles",
        "inutil": "inútil",
        "inutiles": "inútiles",
        "publico": "público",
        "publica": "pública",
        "publicos": "públicos",
        "publicas": "públicas",
        "unico": "único",
        "unica": "única",
        "unicos": "únicos",
        "unicas": "únicas",
        "tipico": "típico",
        "tipica": "típica",
        "tipicos": "típicos",
        "tipicas": "típicas",
        "basico": "básico",
        "basica": "básica",
        "basicos": "básicos",
        "basicas": "básicas",
        "practico": "práctico",
        "practica": "práctica",
        "practicos": "prácticos",
        "practicas": "prácticas",
        "economico": "económico",
        "economica": "económica",
        "economicos": "económicos",
        "economicas": "económicas",
        "historico": "histórico",
        "historica": "histórica",
        "historicos": "históricos",
        "historicas": "históricas",
        "politico": "político",
        "politica": "política",
        "politicos": "políticos",
        "politicas": "políticas",
        "tecnico": "técnico",
        "tecnica": "técnica",
        "tecnicos": "técnicos",
        "tecnicas": "técnicas",
        "medico": "médico",
        "medica": "médica",
        "medicos": "médicos",
        "medicas": "médicas",
        "clasico": "clásico",
        "clasica": "clásica",
        "clasicos": "clásicos",
        "clasicas": "clásicas",
        "fantastico": "fantástico",
        "fantastica": "fantástica",
        "magnifico": "magnífico",
        "magnifica": "magnífica",
        "romantico": "romántico",
        "romantica": "romántica",
        "simpatico": "simpático",
        "simpatica": "simpática",
        "antipatico": "antipático",
        "antipatica": "antipática",

        // ==========================================
        // ADVERBS AND COMMON EXPRESSIONS
        // ==========================================
        "tambien": "también",
        "quiza": "quizá",
        "quizas": "quizás",
        "asi": "así",
        "aqui": "aquí",
        "ahi": "ahí",
        "alli": "allí",
        "alla": "allá",
        "atras": "atrás",
        "detras": "detrás",
        "ademas": "además",
        "jamas": "jamás",
        "demas": "demás",
        "adios": "adiós",
        "rapidamente": "rápidamente",
        "facilmente": "fácilmente",
        "dificilmente": "difícilmente",
        "ultimamente": "últimamente",

        // ==========================================
        // WORDS WITH ñ (n -> ñ restoration)
        // ==========================================
        "espana": "España",
        "espanol": "español",
        "espanola": "española",
        "espanoles": "españoles",
        "espanolas": "españolas",
        "senor": "señor",
        "senora": "señora",
        "senorita": "señorita",
        "senores": "señores",
        "senoras": "señoras",
        "pequeno": "pequeño",
        "pequena": "pequeña",
        "pequenos": "pequeños",
        "pequenas": "pequeñas",
        "sueno": "sueño",
        "suenos": "sueños",
        "montana": "montaña",
        "montanas": "montañas",
        "campana": "campaña",
        "campanas": "campañas",
        "cana": "caña",
        "canas": "cañas",
        "banera": "bañera",
        "baneras": "bañeras",
        "bano": "baño",
        "banos": "baños",
        "otono": "otoño",
        "ensenanza": "enseñanza",
        "ensenanzas": "enseñanzas",
        "diseno": "diseño",
        "disenos": "diseños",
        "cunado": "cuñado",
        "cunada": "cuñada",
        "cunados": "cuñados",
        "cunadas": "cuñadas",
        "enganar": "engañar",
        "engano": "engaño",
        "danino": "dañino",
        "danina": "dañina",
        "dano": "daño",
        "danos": "daños",
        "lenador": "leñador",
        "lenadora": "leñadora",
        "lena": "leña",
        "cabana": "cabaña",
        "cabanas": "cabañas",
        "arana": "araña",
        "aranas": "arañas",
        "pestana": "pestaña",
        "pestanas": "pestañas",
        "pinata": "piñata",
        "pinatas": "piñatas",
        "canon": "cañón",
        "canones": "cañones",

        // ==========================================
        // NUMBERS
        // ==========================================
        "numero": "número",
        "numeros": "números",
        "veintidos": "veintidós",
        "veintitres": "veintitrés",
        "veintiseis": "veintiséis",
        "decimo": "décimo",
        "vigesimo": "vigésimo",
        "trigesimo": "trigésimo",
        "milesimo": "milésimo",
    ]

    // MARK: - Spanish Common Misspellings Dictionary
    // Frequently confused words and typos

    private static let spanishMisspellings: [String: String] = [
        // ==========================================
        // HABER vs A VER / HAY vs AHI vs AY
        // ==========================================
        "haver": "haber",
        "aver": "haber",      // common error
        "aber": "haber",
        "ai": "hay",          // there is/are
        "ahy": "ahí",         // there (location)
        "ay": "hay",          // common error

        // ==========================================
        // HECHO vs ECHO
        // ==========================================
        // hecho = done/fact, echo = I throw/echo
        "hechar": "echar",
        "hechado": "echado",
        "hechando": "echando",
        "hechamos": "echamos",
        "hecharon": "echaron",

        // ==========================================
        // IBA vs HIBA
        // ==========================================
        "hiba": "iba",
        "hibas": "ibas",
        "hibamos": "íbamos",
        "hiban": "iban",

        // ==========================================
        // A VER vs HABER confusion
        // ==========================================
        "haber que": "a ver qué",
        "haver si": "a ver si",

        // ==========================================
        // B vs V CONFUSION (common in Latin America)
        // ==========================================
        "iva": "iba",
        "tubo que": "tuvo que",  // had to (vs tubo = tube)
        "bamos": "vamos",
        "benir": "venir",
        "bengo": "vengo",
        "benir": "venir",
        "bida": "vida",
        "nuebo": "nuevo",
        "nueba": "nueva",
        "nuebos": "nuevos",
        "nuebas": "nuevas",
        "serbir": "servir",
        "serbicio": "servicio",
        "escrivir": "escribir",
        "recivir": "recibir",
        "bivir": "vivir",
        "berdad": "verdad",
        "berde": "verde",
        "biejo": "viejo",
        "bieja": "vieja",
        "biajar": "viajar",
        "biaje": "viaje",
        "bolber": "volver",
        "buelvo": "vuelvo",
        "abiso": "aviso",
        "probocar": "provocar",
        "combersacion": "conversación",
        "combertir": "convertir",
        "inbierno": "invierno",

        // ==========================================
        // H OMISSION/ADDITION
        // ==========================================
        "acer": "hacer",
        "aciendo": "haciendo",
        "acia": "hacía",
        "abia": "había",
        "ablar": "hablar",
        "ablamos": "hablamos",
        "asta": "hasta",
        "oy": "hoy",
        "ora": "hora",
        "oras": "horas",
        "abitacion": "habitación",
        "ermano": "hermano",
        "ermana": "hermana",
        "ermanos": "hermanos",
        "ermanas": "hermanas",
        "ermoso": "hermoso",
        "ermosa": "hermosa",
        "istoria": "historia",
        "istorico": "histórico",
        "ospital": "hospital",
        "otel": "hotel",
        "ombre": "hombre",
        "ombres": "hombres",
        "uevo": "huevo",
        "uevos": "huevos",
        "umano": "humano",
        "umana": "humana",
        "umedad": "humedad",
        "umilde": "humilde",
        "umo": "humo",
        "eroe": "héroe",
        "eroes": "héroes",
        "eredar": "heredar",
        "erencia": "herencia",
        "erida": "herida",
        "erido": "herido",
        "ijo": "hijo",
        "ija": "hija",
        "ijos": "hijos",
        "ijas": "hijas",
        "ielo": "hielo",
        "ierba": "hierba",
        "ierro": "hierro",
        "igado": "hígado",
        "ilo": "hilo",
        "ipoteca": "hipoteca",

        // ==========================================
        // LL vs Y CONFUSION
        // ==========================================
        "yegar": "llegar",
        "yego": "llego",
        "yamar": "llamar",
        "yamo": "llamo",
        "yave": "llave",
        "yaves": "llaves",
        "yuvia": "lluvia",
        "yeno": "lleno",
        "yena": "llena",
        "yenar": "llenar",
        "yevar": "llevar",
        "yevo": "llevo",
        "yorar": "llorar",
        "yoro": "lloro",
        "yama": "llama",
        "yamas": "llamas",

        // ==========================================
        // S vs C vs Z CONFUSION (seseo/ceceo regions)
        // ==========================================
        "conoser": "conocer",
        "conosco": "conozco",
        "desir": "decir",
        "hazer": "hacer",
        "hize": "hice",
        "empesar": "empezar",
        "empese": "empecé",
        "organisar": "organizar",
        "organisacion": "organización",
        "utilisar": "utilizar",
        "realisar": "realizar",
        "realisacion": "realización",
        "analizar": "analizar",
        "comensar": "comenzar",
        "comense": "comencé",
        "forsoso": "forzoso",
        "forsosamente": "forzosamente",

        // ==========================================
        // G vs J CONFUSION
        // ==========================================
        "jente": "gente",
        "jeneral": "general",
        "jeneroso": "generoso",
        "jenero": "género",
        "jeografia": "geografía",
        "jerente": "gerente",
        "jimnasio": "gimnasio",

        // ==========================================
        // COMMON TYPOS AND TEXT SPEAK
        // ==========================================
        "qe": "que",
        "porq": "porque",
        "xq": "porque",
        "pq": "porque",
        "tb": "también",
        "tmb": "también",
        "bn": "bien",
        "grax": "gracias",
        "dnd": "donde",
        "pra": "para",
        "tner": "tener",
        "kiero": "quiero",
        "kieres": "quieres",
        "kiere": "quiere",
        "kieremos": "queremos",
        "kien": "quien",
        "ke": "que",
        "cm": "como",
        "xfa": "por favor",
        "nse": "no sé",
        "weno": "bueno",
        "wena": "buena",
        "wenas": "buenas",
        "xo": "pero",
        "ola": "hola",
        "ksa": "casa",
        "mxo": "mucho",
        "mxa": "mucha",
        "mxos": "muchos",
        "mxas": "muchas",
        "klase": "clase",
        "100pre": "siempre",

        // ==========================================
        // ACCENT PLACEMENT ERRORS
        // ==========================================
        "incluído": "incluido",  // no accent needed (after reform)
        "construído": "construido",
        "destruído": "destruido",
        "huído": "huido",

        // ==========================================
        // COMMON DOUBLE LETTER ERRORS
        // ==========================================
        "dessarrollo": "desarrollo",
        "dessarrollar": "desarrollar",
        "neccesario": "necesario",
        "neccesidad": "necesidad",
        "acceso": "acceso",
        "occidente": "occidente",
    ]

    // MARK: - Spanish Proper Nouns
    // Cities, countries, and other proper nouns requiring capitalization and/or accents

    private static let spanishProperNouns: [String: String] = [
        // ==========================================
        // SPANISH CITIES
        // ==========================================
        "madrid": "Madrid",
        "barcelona": "Barcelona",
        "valencia": "Valencia",
        "sevilla": "Sevilla",
        "zaragoza": "Zaragoza",
        "malaga": "Málaga",
        "murcia": "Murcia",
        "palma": "Palma",
        "bilbao": "Bilbao",
        "alicante": "Alicante",
        "cordoba": "Córdoba",
        "valladolid": "Valladolid",
        "vigo": "Vigo",
        "gijon": "Gijón",
        "granada": "Granada",
        "la coruna": "La Coruña",
        "a coruna": "A Coruña",
        "vitoria": "Vitoria",
        "san sebastian": "San Sebastián",
        "donostia": "Donostia",
        "pamplona": "Pamplona",
        "santander": "Santander",
        "burgos": "Burgos",
        "salamanca": "Salamanca",
        "leon": "León",
        "cadiz": "Cádiz",
        "almeria": "Almería",
        "oviedo": "Oviedo",
        "toledo": "Toledo",
        "segovia": "Segovia",
        "avila": "Ávila",
        "cuenca": "Cuenca",
        "tarragona": "Tarragona",
        "girona": "Girona",
        "lleida": "Lleida",
        "ibiza": "Ibiza",
        "tenerife": "Tenerife",
        "las palmas": "Las Palmas",
        "santa cruz": "Santa Cruz",
        "huelva": "Huelva",
        "jaen": "Jaén",
        "logrono": "Logroño",
        "badajoz": "Badajoz",
        "caceres": "Cáceres",
        "merida": "Mérida",
        "pontevedra": "Pontevedra",
        "ourense": "Ourense",
        "lugo": "Lugo",
        "teruel": "Teruel",
        "huesca": "Huesca",
        "soria": "Soria",
        "palencia": "Palencia",
        "zamora": "Zamora",

        // ==========================================
        // LATIN AMERICAN CITIES
        // ==========================================
        "mexico": "México",
        "ciudad de mexico": "Ciudad de México",
        "guadalajara": "Guadalajara",
        "monterrey": "Monterrey",
        "cancun": "Cancún",
        "tijuana": "Tijuana",
        "puebla": "Puebla",
        "merida": "Mérida",
        "acapulco": "Acapulco",
        "bogota": "Bogotá",
        "medellin": "Medellín",
        "cali": "Cali",
        "cartagena": "Cartagena",
        "barranquilla": "Barranquilla",
        "bucaramanga": "Bucaramanga",
        "buenos aires": "Buenos Aires",
        "cordoba": "Córdoba",
        "rosario": "Rosario",
        "mendoza": "Mendoza",
        "mar del plata": "Mar del Plata",
        "bariloche": "Bariloche",
        "lima": "Lima",
        "cusco": "Cusco",
        "arequipa": "Arequipa",
        "trujillo": "Trujillo",
        "santiago": "Santiago",
        "valparaiso": "Valparaíso",
        "vina del mar": "Viña del Mar",
        "concepcion": "Concepción",
        "caracas": "Caracas",
        "maracaibo": "Maracaibo",
        "valencia": "Valencia",
        "barquisimeto": "Barquisimeto",
        "quito": "Quito",
        "guayaquil": "Guayaquil",
        "cuenca": "Cuenca",
        "la paz": "La Paz",
        "santa cruz": "Santa Cruz",
        "cochabamba": "Cochabamba",
        "sucre": "Sucre",
        "montevideo": "Montevideo",
        "punta del este": "Punta del Este",
        "asuncion": "Asunción",
        "la habana": "La Habana",
        "santiago de cuba": "Santiago de Cuba",
        "varadero": "Varadero",
        "san juan": "San Juan",
        "ponce": "Ponce",
        "santo domingo": "Santo Domingo",
        "punta cana": "Punta Cana",
        "panama": "Panamá",
        "san jose": "San José",
        "managua": "Managua",
        "tegucigalpa": "Tegucigalpa",
        "san pedro sula": "San Pedro Sula",
        "san salvador": "San Salvador",
        "guatemala": "Guatemala",
        "antigua guatemala": "Antigua Guatemala",

        // ==========================================
        // US CITIES (Spanish names)
        // ==========================================
        "los angeles": "Los Ángeles",
        "san francisco": "San Francisco",
        "san diego": "San Diego",
        "san antonio": "San Antonio",
        "el paso": "El Paso",
        "miami": "Miami",
        "nueva york": "Nueva York",
        "chicago": "Chicago",
        "houston": "Houston",
        "phoenix": "Phoenix",
        "albuquerque": "Albuquerque",
        "santa fe": "Santa Fe",
        "las vegas": "Las Vegas",

        // ==========================================
        // COUNTRIES
        // ==========================================
        "espana": "España",
        "mexico": "México",
        "argentina": "Argentina",
        "colombia": "Colombia",
        "peru": "Perú",
        "venezuela": "Venezuela",
        "chile": "Chile",
        "ecuador": "Ecuador",
        "bolivia": "Bolivia",
        "paraguay": "Paraguay",
        "uruguay": "Uruguay",
        "cuba": "Cuba",
        "republica dominicana": "República Dominicana",
        "puerto rico": "Puerto Rico",
        "panama": "Panamá",
        "costa rica": "Costa Rica",
        "nicaragua": "Nicaragua",
        "honduras": "Honduras",
        "el salvador": "El Salvador",
        "guatemala": "Guatemala",
        "belize": "Belice",

        // European countries
        "francia": "Francia",
        "alemania": "Alemania",
        "italia": "Italia",
        "portugal": "Portugal",
        "reino unido": "Reino Unido",
        "inglaterra": "Inglaterra",
        "escocia": "Escocia",
        "gales": "Gales",
        "irlanda": "Irlanda",
        "paises bajos": "Países Bajos",
        "holanda": "Holanda",
        "belgica": "Bélgica",
        "suiza": "Suiza",
        "austria": "Austria",
        "grecia": "Grecia",
        "turquia": "Turquía",
        "rusia": "Rusia",
        "polonia": "Polonia",
        "suecia": "Suecia",
        "noruega": "Noruega",
        "dinamarca": "Dinamarca",
        "finlandia": "Finlandia",
        "hungria": "Hungría",
        "rumania": "Rumanía",
        "bulgaria": "Bulgaria",
        "croacia": "Croacia",
        "ucrania": "Ucrania",
        "chequia": "Chequia",
        "republica checa": "República Checa",
        "eslovaquia": "Eslovaquia",
        "eslovenia": "Eslovenia",
        "serbia": "Serbia",

        // Other regions
        "estados unidos": "Estados Unidos",
        "canada": "Canadá",
        "brasil": "Brasil",
        "japon": "Japón",
        "china": "China",
        "corea del sur": "Corea del Sur",
        "corea del norte": "Corea del Norte",
        "corea": "Corea",
        "india": "India",
        "australia": "Australia",
        "nueva zelanda": "Nueva Zelanda",
        "filipinas": "Filipinas",
        "vietnam": "Vietnam",
        "tailandia": "Tailandia",
        "indonesia": "Indonesia",
        "malasia": "Malasia",
        "singapur": "Singapur",
        "taiwan": "Taiwán",
        "israel": "Israel",
        "palestina": "Palestina",
        "libano": "Líbano",
        "siria": "Siria",
        "iran": "Irán",
        "irak": "Irak",
        "arabia saudita": "Arabia Saudita",
        "emiratos arabes unidos": "Emiratos Árabes Unidos",
        "egipto": "Egipto",
        "marruecos": "Marruecos",
        "tunez": "Túnez",
        "argelia": "Argelia",
        "libia": "Libia",
        "sudafrica": "Sudáfrica",
        "nigeria": "Nigeria",
        "kenia": "Kenia",
        "etiopia": "Etiopía",

        // Continents
        "europa": "Europa",
        "asia": "Asia",
        "africa": "África",
        "america": "América",
        "america del norte": "América del Norte",
        "america del sur": "América del Sur",
        "norteamerica": "Norteamérica",
        "sudamerica": "Sudamérica",
        "centroamerica": "Centroamérica",
        "latinoamerica": "Latinoamérica",
        "oceania": "Oceanía",
        "antartida": "Antártida",

        // ==========================================
        // SPANISH REGIONS
        // ==========================================
        "andalucia": "Andalucía",
        "cataluna": "Cataluña",
        "catalunya": "Catalunya",
        "galicia": "Galicia",
        "pais vasco": "País Vasco",
        "euskadi": "Euskadi",
        "castilla": "Castilla",
        "castilla y leon": "Castilla y León",
        "castilla-la mancha": "Castilla-La Mancha",
        "aragon": "Aragón",
        "navarra": "Navarra",
        "asturias": "Asturias",
        "cantabria": "Cantabria",
        "extremadura": "Extremadura",
        "canarias": "Canarias",
        "islas canarias": "Islas Canarias",
        "baleares": "Baleares",
        "islas baleares": "Islas Baleares",
        "comunidad valenciana": "Comunidad Valenciana",
        "la rioja": "La Rioja",
        "region de murcia": "Región de Murcia",
        "comunidad de madrid": "Comunidad de Madrid",

        // ==========================================
        // RIVERS, MOUNTAINS, SEAS
        // ==========================================
        "rio grande": "Río Grande",
        "amazonas": "Amazonas",
        "rio amazonas": "Río Amazonas",
        "orinoco": "Orinoco",
        "parana": "Paraná",
        "rio de la plata": "Río de la Plata",
        "ebro": "Ebro",
        "tajo": "Tajo",
        "duero": "Duero",
        "guadalquivir": "Guadalquivir",
        "guadiana": "Guadiana",
        "mino": "Miño",
        "pirineos": "Pirineos",
        "andes": "Andes",
        "cordillera de los andes": "Cordillera de los Andes",
        "sierra nevada": "Sierra Nevada",
        "sierra madre": "Sierra Madre",
        "teide": "Teide",
        "aconcagua": "Aconcagua",
        "caribe": "Caribe",
        "mar caribe": "Mar Caribe",
        "mediterraneo": "Mediterráneo",
        "mar mediterraneo": "Mar Mediterráneo",
        "atlantico": "Atlántico",
        "oceano atlantico": "Océano Atlántico",
        "pacifico": "Pacífico",
        "oceano pacifico": "Océano Pacífico",
        "golfo de mexico": "Golfo de México",

        // ==========================================
        // FAMOUS PLACES AND LANDMARKS
        // ==========================================
        "alhambra": "Alhambra",
        "sagrada familia": "Sagrada Familia",
        "el prado": "El Prado",
        "museo del prado": "Museo del Prado",
        "la rambla": "La Rambla",
        "las ramblas": "Las Ramblas",
        "el escorial": "El Escorial",
        "alcazar": "Alcázar",
        "mezquita": "Mezquita",
        "machu picchu": "Machu Picchu",
        "chichen itza": "Chichén Itzá",
        "teotihuacan": "Teotihuacán",
        "tikal": "Tikal",
        "galapagos": "Galápagos",
        "islas galapagos": "Islas Galápagos",
        "patagonia": "Patagonia",
        "tierra del fuego": "Tierra del Fuego",
        "cataratas del iguazu": "Cataratas del Iguazú",
        "iguazu": "Iguazú",
        "nazca": "Nazca",
        "lineas de nazca": "Líneas de Nazca",
    ]

    // MARK: - Spanish Abbreviations

    /// Common Spanish abbreviations
    static let spanishAbbreviations: Set<String> = [
        // Titles
        "sr.", "sra.", "srta.", "dr.", "dra.", "lic.", "ing.", "arq.", "prof.",
        "d.", "dña.", "don", "doña",

        // Common abbreviations
        "etc.", "ej.", "pág.", "págs.", "núm.", "tel.", "fax", "cel.",
        "apdo.", "c/", "avda.", "av.", "ctra.", "pza.", "pl.",
        "admón.", "admr.", "aprox.", "atte.", "cta.", "dpto.",
        "ej.", "excmo.", "ilmo.", "máx.", "mín.", "p.ej.",
        "ref.", "s.a.", "sig.", "vol.", "vols.",

        // Time
        "h.", "min.", "seg.", "a.m.", "p.m.", "a.c.", "d.c.",

        // Units
        "km", "m", "cm", "mm", "kg", "g", "l", "ml", "ha",

        // Currency
        "€", "$", "usd", "mxn", "ars", "cop", "pen", "clp", "eur",

        // Organizations
        "s.a.", "s.l.", "s.r.l.", "cia.", "cía.", "corp.", "ltda.",

        // Days and months
        "lun.", "mar.", "mié.", "jue.", "vie.", "sáb.", "dom.",
        "ene.", "feb.", "mar.", "abr.", "may.", "jun.",
        "jul.", "ago.", "sep.", "oct.", "nov.", "dic.",
    ]
}
