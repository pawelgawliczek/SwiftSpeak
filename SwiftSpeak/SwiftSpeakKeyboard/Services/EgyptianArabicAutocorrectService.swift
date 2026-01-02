//
//  EgyptianArabicAutocorrectService.swift
//  SwiftSpeak
//
//  Egyptian Arabic (العامية المصرية) autocorrection service
//  Handles colloquial Egyptian spellings, proper nouns, and common corrections
//  Language code: arz (ISO 639-3)
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

/// Egyptian Arabic autocorrection service for colloquial Egyptian text correction
/// Handles Egyptian dialect spellings, common variations, and Romanized input
enum EgyptianArabicAutocorrectService {

    // MARK: - Main Correction Method

    /// Fix Egyptian Arabic word - handles spelling variations and common mistakes
    /// Returns nil if no correction needed
    static func fixEgyptianArabicWord(_ word: String) -> String? {
        let normalized = word

        // Check for spelling corrections (Egyptian-specific)
        if let corrected = egyptianSpellings[normalized] {
            return corrected
        }

        // Check for Romanized to Arabic conversion
        if let arabicForm = romanizedToArabic[word.lowercased()] {
            return arabicForm
        }

        // Check for proper nouns (cities, regions)
        if let properNoun = egyptianProperNouns[normalized] {
            return properNoun
        }

        return nil
    }

    /// Check if word is an Egyptian proper noun
    static func shouldCapitalizeEgyptian(_ word: String) -> String? {
        return egyptianProperNouns[word]
    }

    // MARK: - Egyptian Arabic Spellings Dictionary
    // Common spelling variations and corrections for Egyptian colloquial

    private static let egyptianSpellings: [String: String] = [
        // ==========================================
        // DEMONSTRATIVES (Egyptian vs MSA)
        // ==========================================
        // Egyptian uses ده/دي/دول instead of MSA هذا/هذه/هؤلاء
        "هذا": "ده",        // this (masc) - Egyptian form preferred in colloquial
        "هذه": "دي",        // this (fem) - Egyptian form preferred in colloquial
        "هؤلاء": "دول",     // these (plural) - Egyptian form

        // Common misspellings/variations of demonstratives
        "دة": "ده",         // alternate spelling
        "دى": "دي",         // alternate spelling with ya

        // ==========================================
        // PRONOUNS AND VERB FORMS (Egyptian)
        // ==========================================
        // Egyptian uses انت/احنا vs MSA أنت/نحن
        "أنت": "انت",       // you (masc) - Egyptian without hamza
        "نحن": "احنا",      // we - Egyptian colloquial form

        // Egyptian progressive/continuous forms with ب
        "يحب": "بيحب",      // he loves - Egyptian progressive
        "تحب": "بتحب",      // you love - Egyptian progressive
        "يعمل": "بيعمل",    // he does/makes
        "تعمل": "بتعمل",    // you do/make

        // ==========================================
        // COMMON WORDS (Egyptian variants)
        // ==========================================
        // Words where Egyptian spelling differs

        // "Want" - عايز/عاوز (Egyptian) vs أريد (MSA)
        "اريد": "عايز",     // I want
        "تريد": "عايز",     // you want
        "عاوز": "عايز",     // alternate spelling

        // "Now" - دلوقتي (Egyptian) vs الآن (MSA)
        "الان": "دلوقتي",   // now
        "الآن": "دلوقتي",

        // "What" - ايه (Egyptian) vs ماذا (MSA)
        "ماذا": "ايه",      // what
        "إيه": "ايه",       // alternate spelling

        // "Where" - فين (Egyptian) vs أين (MSA)
        "أين": "فين",       // where
        "اين": "فين",

        // "How" - ازاي (Egyptian) vs كيف (MSA)
        "كيف": "ازاي",      // how
        "إزاي": "ازاي",     // alternate spelling

        // "When" - امتى (Egyptian) vs متى (MSA)
        "متى": "امتى",      // when
        "إمتى": "امتى",

        // "Why" - ليه (Egyptian) vs لماذا (MSA)
        "لماذا": "ليه",     // why
        "لية": "ليه",       // alternate spelling

        // "Not/No" variations
        "لست": "مش",        // I'm not
        "ليس": "مش",        // is not

        // "There is/are" - فيه (Egyptian) vs يوجد/هناك (MSA)
        "يوجد": "فيه",      // there is
        "هناك": "فيه",      // there

        // ==========================================
        // GREETING VARIATIONS
        // ==========================================
        "إزيك": "ازيك",     // how are you (alternate)
        "عامل إيه": "عامل ايه",  // how are you doing
        "الحمد لله": "الحمدلله",  // praise God (compact form common)

        // ==========================================
        // COMMON EXPRESSIONS (normalize spellings)
        // ==========================================
        "يالا": "يلا",      // let's go
        "ماشى": "ماشي",     // okay
        "أوكي": "اوكي",     // okay (from English)
        "هههه": "ههه",      // laughter (normalize)
        "هههههه": "ههه",
        "معليش": "معلش",    // never mind/sorry

        // ==========================================
        // VERBS - Common Egyptian Forms
        // ==========================================
        // Egyptian uses different verb patterns
        "أذهب": "اروح",     // I go - Egyptian روح vs MSA ذهب
        "يذهب": "بيروح",    // he goes
        "تذهب": "بتروح",    // you/she goes
        "نذهب": "بنروح",    // we go

        "آكل": "باكل",      // I eat
        "يأكل": "بياكل",    // he eats
        "تأكل": "بتاكل",    // you eat

        "أشرب": "باشرب",    // I drink
        "يشرب": "بيشرب",    // he drinks

        "أنام": "بنام",     // I sleep
        "ينام": "بينام",    // he sleeps

        // ==========================================
        // NOUNS - Egyptian Colloquial
        // ==========================================
        "سيارة": "عربية",   // car - Egyptian uses عربية
        "كثير": "كتير",     // a lot/many
        "صغير": "صغير",     // small (same)
        "كبير": "كبير",     // big (same)
        "جميل": "حلو",      // beautiful - Egyptian often uses حلو
        "سيء": "وحش",       // bad - Egyptian وحش
        "ممتاز": "تمام",    // excellent - Egyptian تمام more common

        // ==========================================
        // QUESTION WORDS (normalize)
        // ==========================================
        "مين": "مين",       // who (Egyptian - same)
        "ليه": "ليه",       // why
        "إزاى": "ازاي",     // how (alternate)
        "إمتى": "امتى",     // when (alternate)
    ]

    // MARK: - Romanized to Arabic Conversion
    // Common Romanized spellings typed on English keyboard

    private static let romanizedToArabic: [String: String] = [
        // Greetings
        "ezayak": "ازيك",
        "ezayek": "ازيك",
        "3amel eh": "عامل ايه",
        "3amla eh": "عاملة ايه",
        "tamam": "تمام",
        "kwayes": "كويس",
        "kwayesa": "كويسة",
        "alhamdulillah": "الحمدلله",
        "el7amdolellah": "الحمدلله",

        // Common words
        "yalla": "يلا",
        "yala": "يلا",
        "mashi": "ماشي",
        "ok": "اوكي",
        "okay": "اوكي",
        "inshallah": "ان شاء الله",
        "insha2allah": "ان شاء الله",
        "ma3lesh": "معلش",
        "ma3lish": "معلش",

        // Pronouns/Question words
        "ana": "انا",
        "enta": "انت",
        "enti": "انتي",
        "howa": "هو",
        "heya": "هي",
        "e7na": "احنا",
        "ehna": "احنا",
        "feen": "فين",
        "fein": "فين",
        "emta": "امتى",
        "imta": "امتى",
        "ezay": "ازاي",
        "izzay": "ازاي",
        "leh": "ليه",
        "leeh": "ليه",
        "meen": "مين",
        "min": "مين",
        "eh": "ايه",
        "eih": "ايه",

        // Common expressions
        "shokran": "شكرا",
        "shukran": "شكرا",
        "3afwan": "عفوا",
        "afwan": "عفوا",
        "saba7 el5eer": "صباح الخير",
        "sabah elkheer": "صباح الخير",
        "masa2 el5eer": "مساء الخير",
        "masaa elkheer": "مساء الخير",
        "tesba7 3ala 5eer": "تصبح على خير",

        // Demonstratives
        "da": "ده",
        "dah": "ده",
        "di": "دي",
        "dih": "دي",
        "dol": "دول",

        // Common verbs (Romanized)
        "3ayez": "عايز",
        "3ayza": "عايزة",
        "msh": "مش",
        "mesh": "مش",

        // Titles
        "ya basha": "يا باشا",
        "yabasha": "يا باشا",
        "ya m3alem": "يا معلم",
        "ya rayes": "يا ريس",
    ]

    // MARK: - Egyptian Proper Nouns
    // Cities, regions, and landmarks in Egypt

    private static let egyptianProperNouns: [String: String] = [
        // Major Cities
        "القاهرة": "القاهرة",           // Cairo
        "القاهره": "القاهرة",           // alternate spelling
        "الاسكندرية": "اسكندرية",       // Alexandria
        "الإسكندرية": "اسكندرية",       // with hamza
        "اسكندريه": "اسكندرية",         // alternate
        "الجيزة": "الجيزة",             // Giza
        "الجيزه": "الجيزة",             // alternate
        "شبرا": "شبرا",                 // Shubra
        "المعادي": "المعادي",           // Maadi
        "المعادى": "المعادي",           // alternate
        "مصر الجديدة": "مصر الجديدة",   // Heliopolis
        "الزمالك": "الزمالك",           // Zamalek
        "المهندسين": "المهندسين",       // Mohandessin
        "الدقي": "الدقي",               // Dokki
        "الدقى": "الدقي",               // alternate
        "مدينة نصر": "مدينة نصر",       // Nasr City
        "التجمع": "التجمع",             // Tagamo3
        "الشروق": "الشروق",             // El Shorouk

        // Other Major Cities
        "الاقصر": "الأقصر",             // Luxor
        "أسوان": "اسوان",               // Aswan
        "اسوان": "اسوان",
        "شرم الشيخ": "شرم الشيخ",       // Sharm El Sheikh
        "الغردقة": "الغردقة",           // Hurghada
        "بورسعيد": "بورسعيد",           // Port Said
        "السويس": "السويس",             // Suez
        "الاسماعيلية": "الاسماعيلية",   // Ismailia
        "المنصورة": "المنصورة",         // Mansoura
        "طنطا": "طنطا",                 // Tanta
        "الزقازيق": "الزقازيق",         // Zagazig
        "دمياط": "دمياط",               // Damietta
        "اسيوط": "اسيوط",               // Asyut
        "سوهاج": "سوهاج",               // Sohag
        "المنيا": "المنيا",             // Minya
        "بني سويف": "بني سويف",         // Beni Suef
        "الفيوم": "الفيوم",             // Fayoum

        // Country
        "مصر": "مصر",                   // Egypt
        "ام الدنيا": "ام الدنيا",       // "Mother of the World" (Egypt nickname)

        // Landmarks
        "الاهرامات": "الاهرامات",       // The Pyramids
        "ابو الهول": "ابو الهول",       // The Sphinx
        "برج القاهرة": "برج القاهرة",   // Cairo Tower
        "النيل": "النيل",               // The Nile
        "المتحف المصري": "المتحف المصري", // Egyptian Museum
        "خان الخليلي": "خان الخليلي",   // Khan El Khalili
        "الازهر": "الازهر",             // Al-Azhar
        "الحسين": "الحسين",             // Hussein (area)
        "سيتي ستارز": "سيتي ستارز",     // City Stars mall
        "مول مصر": "مول مصر",           // Mall of Egypt

        // Regions/Governorates
        "الصعيد": "الصعيد",             // Upper Egypt
        "الدلتا": "الدلتا",             // The Delta
        "سيناء": "سينا",                // Sinai
        "سينا": "سينا",
        "البحر الاحمر": "البحر الاحمر", // Red Sea
        "مطروح": "مرسى مطروح",          // Marsa Matrouh
    ]

    // MARK: - Egyptian Arabic Abbreviations

    /// Common Egyptian Arabic abbreviations
    static let egyptianAbbreviations: Set<String> = [
        // Titles
        "د.",      // doctor
        "م.",      // engineer (muhandis)
        "أ.",      // ustaz (teacher/mr)
        "ا.",      // alternate
        "حج.",     // hajj
        "ست.",     // sit (mrs)

        // Common abbreviations
        "ش.",      // street (shari3)
        "م.",      // metro
        "ت.",      // telephone

        // Religious
        "ص",       // salla allahu alayhi wa sallam
        "رض",      // radi allahu anhu

        // Time
        "ص",       // morning (saba7)
        "م",       // evening (masa2)

        // Currency
        "ج.م",     // Egyptian pound
        "جنيه",    // pound

        // Units
        "كجم",     // kilogram
        "كم",      // kilometer
        "سم",      // centimeter
        "م",       // meter
    ]

    // MARK: - Egyptian Arabic Word Endings

    /// Common Egyptian word endings for verb conjugation detection
    static let egyptianVerbEndings: [String: String] = [
        // Progressive prefix ب
        "ب": "progressive",

        // Verb endings
        "ت": "you/I (past)",
        "نا": "we",
        "وا": "they",
        "ي": "feminine",
    ]
}
