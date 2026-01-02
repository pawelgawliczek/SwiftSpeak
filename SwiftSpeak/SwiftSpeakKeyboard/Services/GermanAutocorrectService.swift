//
//  GermanAutocorrectService.swift
//  SwiftSpeakKeyboard
//
//  German language autocorrection service
//  Handles umlaut restoration (ä, ö, ü, ß), noun capitalization, and proper nouns
//

import Foundation

/// German autocorrection service for intelligent German text correction
enum GermanAutocorrectService {

    // MARK: - Main Correction Method

    /// Fix German word - restores umlauts, capitalizes nouns, and applies corrections
    /// Returns nil if no correction needed
    static func fixGermanWord(_ word: String) -> String? {
        let lowercased = word.lowercased()

        // Check for umlaut corrections (most common need)
        if let corrected = germanUmlauts[lowercased] {
            return preserveCase(original: word, corrected: corrected)
        }

        // Check for common nouns that need capitalization
        if let noun = germanNouns[lowercased] {
            return noun
        }

        // Check for proper nouns (cities, countries, etc.)
        if let properNoun = germanProperNouns[lowercased] {
            return properNoun
        }

        // Check for common misspellings/confusions
        if let corrected = germanMisspellings[lowercased] {
            return preserveCase(original: word, corrected: corrected)
        }

        return nil
    }

    /// Check if word should be capitalized (German nouns and proper nouns)
    static func shouldCapitalizeGerman(_ word: String) -> String? {
        let lowercased = word.lowercased()

        // Check nouns first
        if let noun = germanNouns[lowercased] {
            return noun
        }

        // Then proper nouns
        return germanProperNouns[lowercased]
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

    // MARK: - German Umlauts Dictionary
    // Words typed without umlauts → correct form with ä, ö, ü, ß

    private static let germanUmlauts: [String: String] = [
        // ==========================================
        // COMMON WORDS WITH ü
        // ==========================================

        // Modal verbs and common verbs with ü
        "fur": "für",
        "uber": "über",
        "zuruck": "zurück",
        "naturlich": "natürlich",
        "gluckich": "glücklich",
        "unglucklich": "unglücklich",
        "mude": "müde",
        "fruh": "früh",
        "spuren": "spüren",
        "prufen": "prüfen",
        "fullen": "füllen",
        "wunschen": "wünschen",
        "kussen": "küssen",
        "grussen": "grüßen",
        "stutzen": "stützen",
        "schutteln": "schütteln",
        "begrussen": "begrüßen",

        // müssen conjugations
        "mussen": "müssen",
        "muss": "muss",  // no umlaut in ich/er/sie/es form
        "musst": "musst",  // no umlaut
        "musste": "musste",
        "mussten": "mussten",
        "gemusst": "gemusst",

        // können conjugations (Konjunktiv II - subjunctive forms)
        // Note: konnte/konnten without umlaut is simple past (Präteritum), not autocorrected
        // könnte/könnten with umlaut is subjunctive - users must type explicitly
        "konntest": "könntest",  // rare form, likely meant subjunctive
        "konntet": "könntet",    // rare form, likely meant subjunctive

        // Other verbs with ü
        "uberlegen": "überlegen",
        "uberraschen": "überraschen",
        "uben": "üben",
        "ubernehmen": "übernehmen",
        "ubertragen": "übertragen",
        "ubersetzen": "übersetzen",
        "uberzeugen": "überzeugen",

        // Nouns with ü (will be capitalized separately)
        "tur": "Tür",
        "bucher": "Bücher",
        "bruder": "Brüder",
        "mutter": "Mütter",
        "munchen": "München",
        "nurnberg": "Nürnberg",
        "zurich": "Zürich",
        "thuringen": "Thüringen",
        "wurzburg": "Würzburg",
        "lubeck": "Lübeck",
        "dusseldorf": "Düsseldorf",
        "saarbrucken": "Saarbrücken",
        "osnabruck": "Osnabrück",

        // ==========================================
        // COMMON WORDS WITH ö
        // ==========================================

        // Adjectives with ö
        "schon": "schön",
        "moglich": "möglich",
        "unmoglich": "unmöglich",
        "notig": "nötig",
        "plotzlich": "plötzlich",
        "gewohnlich": "gewöhnlich",
        "personlich": "persönlich",
        "offentlich": "öffentlich",
        "hoflich": "höflich",
        "bose": "böse",

        // Verbs with ö
        "konnen": "können",
        "mochten": "möchten",
        "mogen": "mögen",
        "horen": "hören",
        "gehoren": "gehören",
        "storen": "stören",
        "zerstoren": "zerstören",
        "eroffnen": "eröffnen",
        "offnen": "öffnen",
        "losen": "lösen",
        "toten": "töten",

        // mögen/möchten
        "mochte": "möchte",

        // Other common words with ö
        "konig": "König",
        "konigin": "Königin",
        "korper": "Körper",
        "kopf": "Kopf",  // no umlaut needed
        "wort": "Wort",  // no umlaut, but plural is Wörter
        "worter": "Wörter",

        // ==========================================
        // COMMON WORDS WITH ä
        // ==========================================

        // Common words with ä
        "wahlen": "wählen",
        "zahlen": "zählen",
        "erzahlen": "erzählen",
        "erklaren": "erklären",
        "andern": "ändern",
        "verandern": "verändern",
        "ahnlich": "ähnlich",
        "ungefahrlich": "ungefährlich",
        "gefahrlich": "gefährlich",
        "nachste": "nächste",
        "nachsten": "nächsten",
        "nachstes": "nächstes",
        "spater": "später",
        "langer": "länger",
        "starker": "stärker",
        "alter": "älter",
        "kalter": "kälter",
        "warmer": "wärmer",
        "naher": "näher",
        "schwacher": "schwächer",
        "haufig": "häufig",
        "jahrlich": "jährlich",
        "taglich": "täglich",
        "monatlich": "monatlich",  // no umlaut
        "wochentlich": "wöchentlich",
        "manlich": "männlich",
        "weiblich": "weiblich",  // no umlaut
        "arztlich": "ärztlich",
        "stadtisch": "städtisch",
        "landlich": "ländlich",
        "auslandisch": "ausländisch",
        "inlandisch": "inländisch",

        // Nouns with ä
        "manner": "Männer",
        "madchen": "Mädchen",
        "arzt": "Arzt",  // no umlaut, but plural is Ärzte
        "arzte": "Ärzte",
        "hande": "Hände",
        "lander": "Länder",
        "stadte": "Städte",
        "platze": "Plätze",
        "satze": "Sätze",
        "gaste": "Gäste",
        "baume": "Bäume",
        "traume": "Träume",
        "raume": "Räume",
        "hauser": "Häuser",
        "facher": "Fächer",
        "bader": "Bäder",
        "rader": "Räder",
        "vater": "Väter",
        "garten": "Gärten",
        "markte": "Märkte",
        "vertrage": "Verträge",
        "antrage": "Anträge",
        "auftrage": "Aufträge",

        // ==========================================
        // COMMON WORDS WITH ß
        // ==========================================

        // Greetings and common expressions
        "gruss": "Gruß",
        "grusse": "Grüße",
        "strasse": "Straße",
        "strassen": "Straßen",
        "fuss": "Fuß",
        "fusse": "Füße",
        "fussball": "Fußball",
        "mass": "Maß",
        "masse": "Maße",
        "spass": "Spaß",
        "heiss": "heiß",
        "weiss": "weiß",
        "suess": "süß",
        "gross": "groß",
        "grosse": "große",
        "grossen": "großen",
        "grosser": "großer",
        "grosses": "großes",
        "grossartig": "großartig",
        "grosseltern": "Großeltern",
        "grossmutter": "Großmutter",
        "grossvater": "Großvater",
        "draussen": "draußen",
        "aussen": "außen",
        "ausser": "außer",
        "ausserdem": "außerdem",
        "ausserhalb": "außerhalb",
        "aussergewohnlich": "außergewöhnlich",
        "ausserordentlich": "außerordentlich",
        "schliessen": "schließen",
        "schiessen": "schießen",
        "giessen": "gießen",
        "fliessen": "fließen",
        "geniessen": "genießen",

        // ==========================================
        // ALTERNATIVE SPELLINGS (ae, oe, ue → ä, ö, ü)
        // ==========================================

        // Common ae → ä conversions
        "aendern": "ändern",
        "aehnlich": "ähnlich",
        "aerger": "Ärger",
        "aergerlich": "ärgerlich",
        "aeltere": "ältere",
        "aelter": "älter",

        // Common oe → ö conversions
        "oeffnen": "öffnen",
        "oeffentlich": "öffentlich",
        "oesterreich": "Österreich",
        "koeln": "Köln",
        "goettingen": "Göttingen",
        "hoeren": "hören",
        "moegen": "mögen",
        "koennen": "können",
        "schoen": "schön",
        "moeglich": "möglich",
        "groesse": "Größe",
        "hoehe": "Höhe",

        // Common ue → ü conversions
        "muenchen": "München",
        "nuernberg": "Nürnberg",
        "zuerich": "Zürich",
        "duesseldorf": "Düsseldorf",
        "muessen": "müssen",
        "muede": "müde",
        "ueber": "über",
        "fuer": "für",
        "zurueck": "zurück",
        "natuerlich": "natürlich",
        "gluecklich": "glücklich",
        "frueh": "früh",
        "pruefen": "prüfen",
        "gruessen": "grüßen",
        "kuessen": "küssen",
        "wuenschen": "wünschen",
        "thueringen": "Thüringen",
        "wuerzburg": "Würzburg",
        "luebeck": "Lübeck",
        "saarbruecken": "Saarbrücken",
        "osnabrueck": "Osnabrück",
    ]

    // MARK: - German Nouns Dictionary
    // Common German nouns that should always be capitalized

    private static let germanNouns: [String: String] = [
        // Time-related nouns
        "tag": "Tag",
        "tage": "Tage",
        "woche": "Woche",
        "wochen": "Wochen",
        "monat": "Monat",
        "monate": "Monate",
        "jahr": "Jahr",
        "jahre": "Jahre",
        "stunde": "Stunde",
        "stunden": "Stunden",
        "minute": "Minute",
        "minuten": "Minuten",
        "sekunde": "Sekunde",
        "zeit": "Zeit",
        "zeiten": "Zeiten",
        "morgen": "Morgen",
        "abend": "Abend",
        "nacht": "Nacht",
        "mittag": "Mittag",
        "vormittag": "Vormittag",
        "nachmittag": "Nachmittag",

        // Days of the week
        "montag": "Montag",
        "dienstag": "Dienstag",
        "mittwoch": "Mittwoch",
        "donnerstag": "Donnerstag",
        "freitag": "Freitag",
        "samstag": "Samstag",
        "sonntag": "Sonntag",

        // Months
        "januar": "Januar",
        "februar": "Februar",
        "marz": "März",
        "maerz": "März",
        "april": "April",
        "mai": "Mai",
        "juni": "Juni",
        "juli": "Juli",
        "august": "August",
        "september": "September",
        "oktober": "Oktober",
        "november": "November",
        "dezember": "Dezember",

        // People
        "mensch": "Mensch",
        "menschen": "Menschen",
        "mann": "Mann",
        "frau": "Frau",
        "kind": "Kind",
        "kinder": "Kinder",
        "familie": "Familie",
        "eltern": "Eltern",
        "vater": "Vater",
        "mutter": "Mutter",
        "bruder": "Bruder",
        "schwester": "Schwester",
        "sohn": "Sohn",
        "tochter": "Tochter",
        "freund": "Freund",
        "freunde": "Freunde",
        "freundin": "Freundin",
        "kollege": "Kollege",
        "kollegin": "Kollegin",
        "chef": "Chef",
        "chefin": "Chefin",
        "lehrer": "Lehrer",
        "lehrerin": "Lehrerin",
        "student": "Student",
        "studentin": "Studentin",
        "arzt": "Arzt",
        "name": "Name",
        "namen": "Namen",

        // Places
        "haus": "Haus",
        "wohnung": "Wohnung",
        "zimmer": "Zimmer",
        "raum": "Raum",
        "platz": "Platz",
        "stadt": "Stadt",
        "land": "Land",
        "dorf": "Dorf",
        "schule": "Schule",
        "universitat": "Universität",
        "universitaet": "Universität",
        "uni": "Uni",
        "krankenhaus": "Krankenhaus",
        "bahnhof": "Bahnhof",
        "flughafen": "Flughafen",
        "hotel": "Hotel",
        "restaurant": "Restaurant",
        "supermarkt": "Supermarkt",
        "laden": "Laden",
        "geschaft": "Geschäft",
        "geschaeft": "Geschäft",
        "bank": "Bank",
        "post": "Post",
        "kirche": "Kirche",
        "museum": "Museum",
        "theater": "Theater",
        "kino": "Kino",
        "park": "Park",
        "garten": "Garten",
        "wald": "Wald",
        "berg": "Berg",
        "fluss": "Fluss",
        "see": "See",
        "meer": "Meer",
        "strand": "Strand",

        // Transportation
        "auto": "Auto",
        "autos": "Autos",
        "wagen": "Wagen",
        "bus": "Bus",
        "bahn": "Bahn",
        "zug": "Zug",
        "flugzeug": "Flugzeug",
        "fahrrad": "Fahrrad",
        "taxi": "Taxi",
        "fahrt": "Fahrt",
        "reise": "Reise",

        // Work and business
        "arbeit": "Arbeit",
        "job": "Job",
        "beruf": "Beruf",
        "firma": "Firma",
        "unternehmen": "Unternehmen",
        "buro": "Büro",
        "buero": "Büro",
        "projekt": "Projekt",
        "aufgabe": "Aufgabe",
        "meeting": "Meeting",
        "termin": "Termin",
        "vertrag": "Vertrag",
        "rechnung": "Rechnung",
        "preis": "Preis",
        "geld": "Geld",
        "euro": "Euro",
        "konto": "Konto",

        // Communication
        "telefon": "Telefon",
        "handy": "Handy",
        "email": "Email",
        "brief": "Brief",
        "nachricht": "Nachricht",
        "anruf": "Anruf",
        "gesprach": "Gespräch",
        "gespraech": "Gespräch",
        "frage": "Frage",
        "antwort": "Antwort",
        "information": "Information",

        // Technology
        "computer": "Computer",
        "laptop": "Laptop",
        "internet": "Internet",
        "website": "Website",
        "app": "App",
        "programm": "Programm",
        "software": "Software",
        "daten": "Daten",
        "datei": "Datei",
        "passwort": "Passwort",

        // Food and drink
        "essen": "Essen",
        "trinken": "Trinken",
        "fruhstuck": "Frühstück",
        "fruehstueck": "Frühstück",
        "mittagessen": "Mittagessen",
        "abendessen": "Abendessen",
        "kaffee": "Kaffee",
        "tee": "Tee",
        "wasser": "Wasser",
        "bier": "Bier",
        "wein": "Wein",
        "brot": "Brot",
        "fleisch": "Fleisch",
        "fisch": "Fisch",
        "gemuse": "Gemüse",
        "gemuese": "Gemüse",
        "obst": "Obst",
        "kuchen": "Kuchen",

        // Abstract nouns
        "leben": "Leben",
        "liebe": "Liebe",
        "freude": "Freude",
        "gluck": "Glück",
        "glueck": "Glück",
        "erfolg": "Erfolg",
        "problem": "Problem",
        "losung": "Lösung",
        "loesung": "Lösung",
        "hilfe": "Hilfe",
        "unterstutzung": "Unterstützung",
        "unterstuetzung": "Unterstützung",
        "grund": "Grund",
        "ziel": "Ziel",
        "idee": "Idee",
        "moglichkeit": "Möglichkeit",
        "moeglichkeit": "Möglichkeit",
        "chance": "Chance",
        "risiko": "Risiko",
        "sicherheit": "Sicherheit",
        "qualitat": "Qualität",
        "qualitaet": "Qualität",

        // Education
        "buch": "Buch",
        "bucher": "Bücher",
        "seite": "Seite",
        "text": "Text",
        "sprache": "Sprache",
        "deutsch": "Deutsch",
        "englisch": "Englisch",
        "kurs": "Kurs",
        "unterricht": "Unterricht",
        "prufung": "Prüfung",
        "pruefung": "Prüfung",
        "note": "Note",
        "zeugnis": "Zeugnis",

        // Health
        "gesundheit": "Gesundheit",
        "krankheit": "Krankheit",
        "medizin": "Medizin",
        "apotheke": "Apotheke",
        "korper": "Körper",
        "koerper": "Körper",
        "kopf": "Kopf",
        "herz": "Herz",
        "hand": "Hand",
        "auge": "Auge",
        "ohr": "Ohr",
    ]

    // MARK: - German Proper Nouns
    // Cities, countries, and other proper nouns requiring capitalization

    private static let germanProperNouns: [String: String] = [
        // Major German cities
        "berlin": "Berlin",
        "hamburg": "Hamburg",
        "munchen": "München",
        "muenchen": "München",
        "koln": "Köln",
        "koeln": "Köln",
        "frankfurt": "Frankfurt",
        "stuttgart": "Stuttgart",
        "dusseldorf": "Düsseldorf",
        "duesseldorf": "Düsseldorf",
        "dortmund": "Dortmund",
        "essen": "Essen",
        "leipzig": "Leipzig",
        "bremen": "Bremen",
        "dresden": "Dresden",
        "hannover": "Hannover",
        "nurnberg": "Nürnberg",
        "nuernberg": "Nürnberg",
        "duisburg": "Duisburg",
        "bochum": "Bochum",
        "wuppertal": "Wuppertal",
        "bielefeld": "Bielefeld",
        "bonn": "Bonn",
        "munster": "Münster",
        "muenster": "Münster",
        "karlsruhe": "Karlsruhe",
        "mannheim": "Mannheim",
        "augsburg": "Augsburg",
        "wiesbaden": "Wiesbaden",
        "gelsenkirchen": "Gelsenkirchen",
        "monchengladbach": "Mönchengladbach",
        "moenchengladbach": "Mönchengladbach",
        "braunschweig": "Braunschweig",
        "chemnitz": "Chemnitz",
        "kiel": "Kiel",
        "aachen": "Aachen",
        "halle": "Halle",
        "magdeburg": "Magdeburg",
        "freiburg": "Freiburg",
        "krefeld": "Krefeld",
        "lubeck": "Lübeck",
        "luebeck": "Lübeck",
        "mainz": "Mainz",
        "erfurt": "Erfurt",
        "rostock": "Rostock",
        "kassel": "Kassel",
        "hagen": "Hagen",
        "saarbrucken": "Saarbrücken",
        "saarbruecken": "Saarbrücken",
        "hamm": "Hamm",
        "potsdam": "Potsdam",
        "ludwigshafen": "Ludwigshafen",
        "leverkusen": "Leverkusen",
        "oldenburg": "Oldenburg",
        "osnabruck": "Osnabrück",
        "osnabrueck": "Osnabrück",
        "solingen": "Solingen",
        "heidelberg": "Heidelberg",
        "darmstadt": "Darmstadt",
        "paderborn": "Paderborn",
        "regensburg": "Regensburg",
        "wurzburg": "Würzburg",
        "wuerzburg": "Würzburg",
        "ingolstadt": "Ingolstadt",
        "ulm": "Ulm",
        "gottingen": "Göttingen",
        "goettingen": "Göttingen",
        "wolfsburg": "Wolfsburg",
        "reutlingen": "Reutlingen",
        "jena": "Jena",
        "tubingen": "Tübingen",
        "tuebingen": "Tübingen",

        // German states (Bundesländer)
        "bayern": "Bayern",
        "baden-wurttemberg": "Baden-Württemberg",
        "baden-wuerttemberg": "Baden-Württemberg",
        "nordrhein-westfalen": "Nordrhein-Westfalen",
        "niedersachsen": "Niedersachsen",
        "hessen": "Hessen",
        "rheinland-pfalz": "Rheinland-Pfalz",
        "sachsen": "Sachsen",
        "thuringen": "Thüringen",
        "thueringen": "Thüringen",
        "schleswig-holstein": "Schleswig-Holstein",
        "sachsen-anhalt": "Sachsen-Anhalt",
        "brandenburg": "Brandenburg",
        "mecklenburg-vorpommern": "Mecklenburg-Vorpommern",
        "saarland": "Saarland",

        // German-speaking countries
        "deutschland": "Deutschland",
        "osterreich": "Österreich",
        "oesterreich": "Österreich",
        "schweiz": "Schweiz",
        "liechtenstein": "Liechtenstein",
        "luxemburg": "Luxemburg",

        // Neighboring countries
        "frankreich": "Frankreich",
        "belgien": "Belgien",
        "niederlande": "Niederlande",
        "holland": "Holland",
        "polen": "Polen",
        "tschechien": "Tschechien",
        "danemark": "Dänemark",
        "daenemark": "Dänemark",
        "italien": "Italien",
        "spanien": "Spanien",
        "portugal": "Portugal",
        "griechenland": "Griechenland",
        "turkei": "Türkei",
        "tuerkei": "Türkei",
        "russland": "Russland",
        "england": "England",
        "grossbritannien": "Großbritannien",
        "irland": "Irland",
        "schottland": "Schottland",
        "wales": "Wales",
        "schweden": "Schweden",
        "norwegen": "Norwegen",
        "finnland": "Finnland",
        "ungarn": "Ungarn",
        "rumanien": "Rumänien",
        "rumaenien": "Rumänien",
        "bulgarien": "Bulgarien",
        "kroatien": "Kroatien",
        "slowenien": "Slowenien",
        "slowakei": "Slowakei",
        "ukraine": "Ukraine",

        // Other major countries
        "amerika": "Amerika",
        "usa": "USA",
        "kanada": "Kanada",
        "mexiko": "Mexiko",
        "brasilien": "Brasilien",
        "argentinien": "Argentinien",
        "china": "China",
        "japan": "Japan",
        "korea": "Korea",
        "indien": "Indien",
        "australien": "Australien",
        "neuseeland": "Neuseeland",
        "agypten": "Ägypten",
        "aegypten": "Ägypten",
        "sudafrika": "Südafrika",
        "suedafrika": "Südafrika",
        "europa": "Europa",
        "asien": "Asien",
        "afrika": "Afrika",

        // Austrian cities
        "wien": "Wien",
        "graz": "Graz",
        "linz": "Linz",
        "salzburg": "Salzburg",
        "innsbruck": "Innsbruck",
        "klagenfurt": "Klagenfurt",

        // Swiss cities
        "zurich": "Zürich",
        "zuerich": "Zürich",
        "bern": "Bern",
        "basel": "Basel",
        "genf": "Genf",
        "lausanne": "Lausanne",

        // Rivers
        "rhein": "Rhein",
        "donau": "Donau",
        "elbe": "Elbe",
        "main": "Main",
        "weser": "Weser",
        "mosel": "Mosel",
        "neckar": "Neckar",
        "spree": "Spree",
        "isar": "Isar",

        // Mountains and regions
        "alpen": "Alpen",
        "schwarzwald": "Schwarzwald",
        "harz": "Harz",
        "erzgebirge": "Erzgebirge",
        "thuringer wald": "Thüringer Wald",
        "bayerischer wald": "Bayerischer Wald",

        // Famous landmarks
        "brandenburger tor": "Brandenburger Tor",
        "reichstag": "Reichstag",
        "neuschwanstein": "Neuschwanstein",
        "kolner dom": "Kölner Dom",
        "koelner dom": "Kölner Dom",
        "oktoberfest": "Oktoberfest",
    ]

    // MARK: - Common German Misspellings/Confusions

    private static let germanMisspellings: [String: String] = [
        // das/dass confusion - these need context, but we can handle obvious cases
        // Note: "das" = article/relative pronoun, "dass" = conjunction
        // We cannot fix this without context, so leaving out

        // seit/seid confusion
        // "seit" = since (preposition/conjunction)
        // "seid" = are (2nd person plural of sein)
        // We cannot fix this without context, so leaving out

        // wider/wieder confusion
        // "wider" = against
        // "wieder" = again
        // We cannot fix this without context, so leaving out

        // Common phonetic misspellings
        "standart": "Standard",  // Common mistake
        "entgültig": "endgültig",
        "endgueltig": "endgültig",
        "vorraus": "voraus",
        "warscheinlich": "wahrscheinlich",
        "villeicht": "vielleicht",
        "vieleicht": "vielleicht",
        "vileicht": "vielleicht",
        "eigendlich": "eigentlich",
        "anderst": "anders",
        "ebend": "eben",
        "garnicht": "gar nicht",  // Should be two words
        "vorallem": "vor allem",  // Should be two words
        "weis": "weiß",  // Common shortening mistake
        "bissle": "bisschen",
        "bissl": "bisschen",
        "bischen": "bisschen",
        "bissche": "bisschen",
        "oke": "okay",
        "okee": "okay",
        "nich": "nicht",
        "nix": "nichts",
        "ham": "haben",  // Colloquial
        "simma": "sind wir",  // Colloquial
        "gehts": "geht's",
        "gibts": "gibt's",
        "hats": "hat's",
        "ists": "ist's",
        "wos": "wo's",

        // English loanwords often misspelled
        "downloaden": "herunterladen",  // German equivalent
        "mailen": "mailen",  // Accepted
        "googlen": "googeln",  // German spelling
        "skypen": "skypen",  // Accepted
    ]

    // MARK: - German Abbreviations

    /// Common German abbreviations
    static let germanAbbreviations: Set<String> = [
        // Common abbreviations
        "z.B.", "z. B.", "d.h.", "d. h.", "u.a.", "u. a.", "usw.", "etc.",
        "bzw.", "ggf.", "evtl.", "ca.", "inkl.", "exkl.", "max.", "min.",
        "Nr.", "Str.", "Tel.", "Fax", "E-Mail",
        "Mo.", "Di.", "Mi.", "Do.", "Fr.", "Sa.", "So.",
        "Jan.", "Feb.", "Mär.", "Apr.", "Jun.", "Jul.", "Aug.", "Sep.", "Okt.", "Nov.", "Dez.",
        "Dr.", "Prof.", "Dipl.", "Ing.", "Mag.", "Hr.", "Fr.",
        "GmbH", "AG", "KG", "OHG", "e.V.", "e.G.",
        "Mio.", "Mrd.", "Tsd.",
        "km", "m", "cm", "mm", "kg", "g", "mg", "l", "ml",
        "€", "EUR", "CHF",
        "h", "min", "sek", "Std.", "Min.", "Sek.",
        "S.", "Abs.", "Art.", "Kap.",
        "v.a.", "m.E.", "o.ä.", "o. ä.", "u.U.", "u. U.",
        "PS", "ABS", "ESP", "TÜV", "ADAC",
        "BRD", "DDR", "EU", "UN", "NATO", "USA",
        "IT", "EDV", "PC", "TV", "DVD", "CD", "USB",
    ]
}
