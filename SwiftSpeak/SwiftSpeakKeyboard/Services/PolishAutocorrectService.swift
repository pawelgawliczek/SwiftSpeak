//
//  PolishAutocorrectService.swift
//  SwiftSpeak
//
//  Polish language autocorrection service
//  Handles diacritic restoration, proper nouns, and common corrections
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

/// Polish autocorrection service for intelligent Polish text correction
enum PolishAutocorrectService {

    // MARK: - Main Correction Method

    /// Fix Polish word - restores diacritics and applies corrections
    /// Returns nil if no correction needed
    static func fixPolishWord(_ word: String) -> String? {
        let lowercased = word.lowercased()

        // Check for diacritic corrections (most common need)
        if let corrected = polishDiacritics[lowercased] {
            return preserveCase(original: word, corrected: corrected)
        }

        // Check for proper nouns (cities, etc.)
        if let properNoun = polishProperNouns[lowercased] {
            return properNoun
        }

        return nil
    }

    /// Check if word should be capitalized (Polish proper nouns)
    static func shouldCapitalizePolish(_ word: String) -> String? {
        let lowercased = word.lowercased()
        return polishProperNouns[lowercased]
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

    // MARK: - Polish Diacritics Dictionary
    // Words typed without Polish characters → correct form with diacritics

    private static let polishDiacritics: [String: String] = [
        // ==========================================
        // MOST COMMON WORDS (high frequency)
        // ==========================================

        // Common verbs
        "bede": "będę", "bedziemy": "będziemy", "bedzie": "będzie",
        "bedziesz": "będziesz", "beda": "będą",
        "chce": "chcę", "chcesz": "chcesz", "chca": "chcą",
        "moge": "mogę", "mozesz": "możesz", "moze": "może",
        "mozemy": "możemy", "mozecie": "możecie", "moga": "mogą",
        "musze": "muszę", "musisz": "musisz", "musza": "muszą",
        "ide": "idę", "idziemy": "idziemy", "idzie": "idzie",
        "jade": "jadę", "jedziesz": "jedziesz", "jedzie": "jedzie",
        "robie": "robię", "robisz": "robisz", "robia": "robią",
        "mysle": "myślę", "myslisz": "myślisz", "mysli": "myśli",
        "wiem": "wiem", "wiesz": "wiesz", "wiedza": "wiedzą",
        "widze": "widzę", "widzisz": "widzisz", "widza": "widzą",
        "slucham": "słucham", "slyszysz": "słyszysz", "slyszy": "słyszy",
        "prosze": "proszę", "prosisz": "prosisz", "prosza": "proszą",
        "dziekuje": "dziękuję", "dziekujemy": "dziękujemy",
        "przepraszam": "przepraszam", // no diacritics needed
        "lubie": "lubię", "lubisz": "lubisz", "lubia": "lubią",
        "kocham": "kocham", // no diacritics needed
        "czekam": "czekam", "czeka": "czeka",
        "pracuje": "pracuję", "pracujesz": "pracujesz",
        "mieszkam": "mieszkam", "mieszka": "mieszka",
        "nazywam": "nazywam", "nazywa": "nazywa",
        "mowisz": "mówisz", "mowi": "mówi", "mowia": "mówią",
        "pisze": "piszę", "piszesz": "piszesz", "pisza": "piszą",
        "czytam": "czytam", "czyta": "czyta",
        "ucze": "uczę", "uczy": "uczy", "ucza": "uczą",
        "pamietam": "pamiętam", "pamieta": "pamięta",
        "rozumiem": "rozumiem", "rozumie": "rozumie",
        "znam": "znam", "zna": "zna", "znaja": "znają",
        "mam": "mam", "ma": "ma", "maja": "mają",
        "jestem": "jestem", "jestes": "jesteś", "jest": "jest",
        "jestesmy": "jesteśmy", "jestescie": "jesteście", "sa": "są",
        "byl": "był", "byla": "była", "bylo": "było", "byli": "byli",

        // Common conjunctions and particles
        "ze": "że", "zeby": "żeby", "zebym": "żebym", "zebys": "żebyś",
        "zle": "źle",
        "bo": "bo", // no diacritics
        "ale": "ale", // no diacritics
        "wiec": "więc", "jednak": "jednak",
        "albo": "albo", "lub": "lub",
        "jesli": "jeśli", "jezeli": "jeżeli",
        "poniewaz": "ponieważ", "gdyz": "gdyż",
        "chociaz": "chociaż", "mimo": "mimo",
        "az": "aż", "juz": "już", "tez": "też",
        "jeszcze": "jeszcze", "ciągle": "ciągle",
        "bardzo": "bardzo", "dosc": "dość", "malo": "mało",
        "duzo": "dużo", "wiecej": "więcej", "mniej": "mniej",
        "tylko": "tylko", "takze": "także", "rowniez": "również",

        // Common nouns
        "dzien": "dzień", "noc": "noc",
        "rano": "rano", "wieczor": "wieczór",
        "piatek": "piątek", "sobota": "sobota", "niedziela": "niedziela",
        "poniedzialek": "poniedziałek", "wtorek": "wtorek",
        "sroda": "środa", "czwartek": "czwartek",
        "styczen": "styczeń", "luty": "luty", "marzec": "marzec",
        "kwiecien": "kwiecień", "maj": "maj", "czerwiec": "czerwiec",
        "lipiec": "lipiec", "sierpien": "sierpień", "wrzesien": "wrzesień",
        "pazdziernik": "październik", "listopad": "listopad", "grudzien": "grudzień",
        "rok": "rok", "miesiac": "miesiąc", "tydzien": "tydzień",
        "godzina": "godzina", "minuta": "minuta", "sekunda": "sekunda",
        "czlowiek": "człowiek", "ludzie": "ludzie",
        "kobieta": "kobieta", "mezczyzna": "mężczyzna",
        "dziecko": "dziecko", "dzieci": "dzieci",
        "rodzina": "rodzina", "przyjaciel": "przyjaciel",
        "dom": "dom", "mieszkanie": "mieszkanie",
        "praca": "praca", "szkola": "szkoła",
        "miasto": "miasto", "wies": "wieś",
        "ulica": "ulica", "droga": "droga",
        "samochod": "samochód", "autobus": "autobus",
        "pociag": "pociąg", "samolot": "samolot",
        "pieniadze": "pieniądze", "cena": "cena",
        "czas": "czas", "miejsce": "miejsce",
        "pytanie": "pytanie", "odpowiedz": "odpowiedź",
        "problem": "problem", "rozwiazanie": "rozwiązanie",
        "pomoc": "pomoc", "informacja": "informacja",
        "wiadomosc": "wiadomość", "telefon": "telefon",
        "komputer": "komputer", "internet": "internet",
        "ksiazka": "książka", "gazeta": "gazeta",
        "film": "film", "muzyka": "muzyka",
        "jedzenie": "jedzenie", "picie": "picie",
        "sniadanie": "śniadanie", "obiad": "obiad", "kolacja": "kolacja",
        "kawa": "kawa", "herbata": "herbata",
        "woda": "woda", "sok": "sok",
        "chleb": "chleb", "mieso": "mięso",
        "zdrowie": "zdrowie", "lekarz": "lekarz",
        "szpital": "szpital", "apteka": "apteka",

        // Common adjectives
        "dobry": "dobry", "zly": "zły", "ladny": "ładny",
        "piekny": "piękny", "brzydki": "brzydki",
        "duzy": "duży", "maly": "mały",
        "stary": "stary", "mlody": "młody", "nowy": "nowy",
        "dlugi": "długi", "krotki": "krótki",
        "wysoki": "wysoki", "niski": "niski",
        "szybki": "szybki", "wolny": "wolny",
        "latwy": "łatwy", "trudny": "trudny",
        "prosty": "prosty", "skomplikowany": "skomplikowany",
        "wazny": "ważny", "glowny": "główny",
        "pierwszy": "pierwszy", "ostatni": "ostatni",
        "nastepny": "następny", "poprzedni": "poprzedni",
        "caly": "cały", "kazdy": "każdy",
        "wszystko": "wszystko", "nic": "nic",
        "inny": "inny", "ten sam": "ten sam",
        "swoj": "swój", "moj": "mój", "twoj": "twój",
        "nasz": "nasz", "wasz": "wasz", "ich": "ich",
        "jakis": "jakiś", "zaden": "żaden",
        "ktory": "który", "jaki": "jaki",
        "taki": "taki", "ten": "ten", "ta": "ta", "to": "to",
        "tamten": "tamten", "tamta": "tamta", "tamto": "tamto",

        // Common adverbs
        "teraz": "teraz", "pozniej": "później", "wczesniej": "wcześniej",
        "dzisiaj": "dzisiaj", "dzis": "dziś",
        "wczoraj": "wczoraj", "jutro": "jutro",
        "zawsze": "zawsze", "nigdy": "nigdy",
        "czasami": "czasami", "czesto": "często", "rzadko": "rzadko",
        "szybko": "szybko", "wolno": "wolno",
        "dobrze": "dobrze",
        "latwo": "łatwo", "trudno": "trudno",
        "blisko": "blisko", "daleko": "daleko",
        "tu": "tu", "tutaj": "tutaj", "tam": "tam",
        "gdzie": "gdzie", "skad": "skąd", "dokad": "dokąd",
        "kiedy": "kiedy", "jak": "jak", "dlaczego": "dlaczego",
        "po co": "po co", "ile": "ile",
        "naprawde": "naprawdę", "prawdopodobnie": "prawdopodobnie",
        "oczywiscie": "oczywiście", "niestety": "niestety",
        "na pewno": "na pewno",

        // Common prepositions
        "dla": "dla", "do": "do", "od": "od",
        "na": "na", "w": "w", "z": "z",
        "przez": "przez", "po": "po",
        "przed": "przed", "za": "za",
        "nad": "nad", "pod": "pod",
        "miedzy": "między", "wsrod": "wśród",
        "okolo": "około", "wokol": "wokół",
        "bez": "bez", "o": "o",

        // Common pronouns
        "ty": "ty", "on": "on", "ona": "ona", "ono": "ono",
        "my": "my", "wy": "wy", "oni": "oni", "one": "one",
        "mnie": "mnie", "mi": "mi", "mna": "mną",
        "ciebie": "ciebie", "ci": "ci", "toba": "tobą",
        "jego": "jego", "go": "go", "jemu": "jemu", "mu": "mu", "nim": "nim",
        "jej": "jej", "nia": "nią",
        "nas": "nas", "nam": "nam", "nami": "nami",
        "was": "was", "wam": "wam", "wami": "wami",
        "sie": "się",  // Reflexive pronoun - very common
        "siebie": "siebie", "sobie": "sobie", "soba": "sobą",
        "kto": "kto", "co": "co",
        "ktos": "ktoś", "cos": "coś",
        "nikt": "nikt",

        // Numbers
        "jeden": "jeden", "dwa": "dwa", "trzy": "trzy",
        "cztery": "cztery", "piec": "pięć", "szesc": "sześć",
        "siedem": "siedem", "osiem": "osiem", "dziewiec": "dziewięć",
        "dziesiec": "dziesięć", "jedenascie": "jedenaście",
        "dwanascie": "dwanaście", "trzynascie": "trzynaście",
        "czternascie": "czternaście", "pietnascie": "piętnaście",
        "szesnascie": "szesnaście", "siedemnascie": "siedemnaście",
        "osiemnascie": "osiemnaście", "dziewietnascie": "dziewiętnaście",
        "dwadziescia": "dwadzieścia", "trzydziesci": "trzydzieści",
        "czterdziesci": "czterdzieści", "piecdziesiat": "pięćdziesiąt",
        "szescdziesiat": "sześćdziesiąt", "siedemdziesiat": "siedemdziesiąt",
        "osiemdziesiat": "osiemdziesiąt", "dziewiecdziesiat": "dziewięćdziesiąt",
        "sto": "sto", "tysiac": "tysiąc", "milion": "milion",

        // Common phrases/expressions
        "dzien dobry": "dzień dobry",
        "dobry wieczor": "dobry wieczór",
        "dobranoc": "dobranoc",
        "do widzenia": "do widzenia",
        "do zobaczenia": "do zobaczenia",
        "czesc": "cześć",
        "jak sie masz": "jak się masz",
        "swietnie": "świetnie",
        "ok": "ok",
        "nie ma za co": "nie ma za co",
        "prosze bardzo": "proszę bardzo",
        "smacznego": "smacznego",
        "na zdrowie": "na zdrowie",
        "powodzenia": "powodzenia",
        "wszystkiego najlepszego": "wszystkiego najlepszego",
        "gratulacje": "gratulacje",
        "przykro mi": "przykro mi",
        "nie wiem": "nie wiem",
        "nie rozumiem": "nie rozumiem",
        "tak": "tak",
        "nie": "nie",
    ]

    // MARK: - Polish Proper Nouns
    // Cities, regions, and other proper nouns requiring capitalization

    private static let polishProperNouns: [String: String] = [
        // Major Polish cities
        "warszawa": "Warszawa",
        "krakow": "Kraków",
        "lodz": "Łódź",
        "wroclaw": "Wrocław",
        "poznan": "Poznań",
        "gdansk": "Gdańsk",
        "szczecin": "Szczecin",
        "bydgoszcz": "Bydgoszcz",
        "lublin": "Lublin",
        "bialystok": "Białystok",
        "katowice": "Katowice",
        "gdynia": "Gdynia",
        "czestochowa": "Częstochowa",
        "radom": "Radom",
        "sosnowiec": "Sosnowiec",
        "torun": "Toruń",
        "kielce": "Kielce",
        "rzeszow": "Rzeszów",
        "gliwice": "Gliwice",
        "zabrze": "Zabrze",
        "olsztyn": "Olsztyn",
        "bielsko-biala": "Bielsko-Biała",
        "bytom": "Bytom",
        "zielona gora": "Zielona Góra",
        "rybnik": "Rybnik",
        "ruda slaska": "Ruda Śląska",
        "tychy": "Tychy",
        "opole": "Opole",
        "gorzow wielkopolski": "Gorzów Wielkopolski",
        "elblag": "Elbląg",
        "plock": "Płock",
        "walbrzych": "Wałbrzych",
        "wloclawek": "Włocławek",
        "tarnow": "Tarnów",
        "chorzow": "Chorzów",
        "koszalin": "Koszalin",
        "kalisz": "Kalisz",
        "legnica": "Legnica",
        "grudziadz": "Grudziądz",
        "slupsk": "Słupsk",
        "jaworzno": "Jaworzno",
        "jastrzebie-zdroj": "Jastrzębie-Zdrój",
        "nowy sacz": "Nowy Sącz",
        "jelenia gora": "Jelenia Góra",
        "siedlce": "Siedlce",
        "myslowice": "Mysłowice",
        "piotrkow trybunalski": "Piotrków Trybunalski",
        "lubin": "Lubin",
        "ostrowiec swietokrzyski": "Ostrowiec Świętokrzyski",
        "gniezno": "Gniezno",
        "stargard": "Stargard",
        "siemianowice slaskie": "Siemianowice Śląskie",
        "glogow": "Głogów",
        "zamosc": "Zamość",
        "leszno": "Leszno",
        "lomza": "Łomża",
        "zory": "Żory",
        "pruszków": "Pruszków",
        "zyrardow": "Żyrardów",
        "pabianice": "Pabianice",
        "oswiecim": "Oświęcim",
        "zakopane": "Zakopane",
        "sopot": "Sopot",
        "kolobrzeg": "Kołobrzeg",
        "swinoujscie": "Świnoujście",
        "mielec": "Mielec",
        "stalowa wola": "Stalowa Wola",
        "przemysl": "Przemyśl",
        "sanok": "Sanok",
        "krosno": "Krosno",
        "jaslo": "Jasło",
        "debica": "Dębica",
        "tarnobrzeg": "Tarnobrzeg",
        "nisko": "Nisko",
        "sandomierz": "Sandomierz",
        "starachowice": "Starachowice",
        "skarzysko-kamienna": "Skarżysko-Kamienna",
        "konskie": "Końskie",
        "ostroleka": "Ostrołęka",
        "ciechanow": "Ciechanów",
        "mława": "Mława",
        "kutno": "Kutno",
        "skierniewice": "Skierniewice",
        "lowicz": "Łowicz",
        "zgierz": "Zgierz",
        "sieradz": "Sieradz",
        "belchatow": "Bełchatów",
        "piotrkow": "Piotrków",
        "radomsko": "Radomsko",
        "tomaszow mazowiecki": "Tomaszów Mazowiecki",
        "wielun": "Wieluń",
        "srem": "Śrem",
        "sroda wielkopolska": "Środa Wielkopolska",
        "wrzesnia": "Września",
        "konin": "Konin",
        "turek": "Turek",
        "kolo": "Koło",
        "pila": "Piła",
        "wagrowiec": "Wągrowiec",
        "ostrów wielkopolski": "Ostrów Wielkopolski",
        "jarocin": "Jarocin",
        "pleszew": "Pleszew",
        "nowy tomysl": "Nowy Tomyśl",
        "wolsztyn": "Wolsztyn",
        "swarzedz": "Swarzędz",
        "lubon": "Luboń",
        "mosina": "Mosina",
        "koscian": "Kościan",

        // Regions/Voivodeships
        "mazowieckie": "Mazowieckie",
        "malopolskie": "Małopolskie",
        "slaskie": "Śląskie",
        "wielkopolskie": "Wielkopolskie",
        "dolnoslaskie": "Dolnośląskie",
        "lodzkie": "Łódzkie",
        "pomorskie": "Pomorskie",
        "lubelskie": "Lubelskie",
        "podkarpackie": "Podkarpackie",
        "kujawsko-pomorskie": "Kujawsko-Pomorskie",
        "zachodniopomorskie": "Zachodniopomorskie",
        "warminsko-mazurskie": "Warmińsko-Mazurskie",
        "swietokrzyskie": "Świętokrzyskie",
        "podlaskie": "Podlaskie",
        "lubuskie": "Lubuskie",
        "opolskie": "Opolskie",

        // Countries/regions
        "polska": "Polska",
        "niemcy": "Niemcy",
        "francja": "Francja",
        "anglia": "Anglia",
        "wielka brytania": "Wielka Brytania",
        "wlochy": "Włochy",
        "hiszpania": "Hiszpania",
        "holandia": "Holandia",
        "belgia": "Belgia",
        "austria": "Austria",
        "szwajcaria": "Szwajcaria",
        "czechy": "Czechy",
        "slowacja": "Słowacja",
        "ukraina": "Ukraina",
        "rosja": "Rosja",
        "bialorus": "Białoruś",
        "litwa": "Litwa",
        "lotwa": "Łotwa",
        "estonia": "Estonia",
        "szwecja": "Szwecja",
        "norwegia": "Norwegia",
        "dania": "Dania",
        "finlandia": "Finlandia",
        "wegry": "Węgry",
        "rumunia": "Rumunia",
        "bulgaria": "Bułgaria",
        "grecja": "Grecja",
        "turcja": "Turcja",
        "portugalia": "Portugalia",
        "irlandia": "Irlandia",
        "szkocja": "Szkocja",
        "walia": "Walia",
        "stany zjednoczone": "Stany Zjednoczone",
        "ameryka": "Ameryka",
        "kanada": "Kanada",
        "meksyk": "Meksyk",
        "brazylia": "Brazylia",
        "argentyna": "Argentyna",
        "chile": "Chile",
        "australia": "Australia",
        "nowa zelandia": "Nowa Zelandia",
        "chiny": "Chiny",
        "japonia": "Japonia",
        "korea": "Korea",
        "indie": "Indie",
        "europa": "Europa",
        "azja": "Azja",
        "afryka": "Afryka",

        // Rivers, mountains, seas
        "wisla": "Wisła",
        "odra": "Odra",
        "warta": "Warta",
        "bug": "Bug",
        "san": "San",
        "narew": "Narew",
        "pilica": "Pilica",
        "bzura": "Bzura",
        "tatry": "Tatry",
        "karpaty": "Karpaty",
        "sudety": "Sudety",
        "beskidy": "Beskidy",
        "bieszczady": "Bieszczady",
        "baltyk": "Bałtyk",
        "morze baltyckie": "Morze Bałtyckie",

        // Famous places
        "wawel": "Wawel",
        "sukiennice": "Sukiennice",
        "rynek": "Rynek",
        "stare miasto": "Stare Miasto",
        "lazienki": "Łazienki",
        "wilanow": "Wilanów",
        "malbork": "Malbork",
        "wieliczka": "Wieliczka",
    ]

    // MARK: - Polish Abbreviations

    /// Common Polish abbreviations
    static let polishAbbreviations: Set<String> = [
        "np.", "itp.", "itd.", "m.in.", "tzw.", "tj.", "tzn.",
        "dr", "mgr", "inż.", "prof.", "hab.", "lek.",
        "ul.", "al.", "pl.", "os.",
        "woj.", "pow.", "gm.",
        "r.", "w.", "s.", "str.",
        "zł", "gr", "tys.", "mln", "mld",
        "godz.", "min.", "sek.",
        "tel.", "fax.", "e-mail",
        "pn.", "wt.", "śr.", "czw.", "pt.", "sob.", "niedz.",
        "sty.", "lut.", "mar.", "kwi.", "maj", "cze.",
        "lip.", "sie.", "wrz.", "paź.", "lis.", "gru.",
    ]
}
