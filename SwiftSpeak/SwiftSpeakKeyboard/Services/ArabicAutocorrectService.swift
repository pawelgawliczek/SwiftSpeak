//
//  ArabicAutocorrectService.swift
//  SwiftSpeak
//
//  Arabic language autocorrection service (Modern Standard Arabic - MSA/فصحى)
//  Handles hamza placement, alef variations, ta marbuta, and proper nouns
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

/// Arabic autocorrection service for intelligent Arabic text correction
/// Supports Modern Standard Arabic (MSA/فصحى) - formal register
enum ArabicAutocorrectService {

    // MARK: - Main Correction Method

    /// Fix Arabic word - corrects hamza placement, alef variations, ta marbuta, and common errors
    /// Returns nil if no correction needed
    static func fixArabicWord(_ word: String) -> String? {
        // Skip if not Arabic script
        guard isArabicScript(word) else { return nil }

        // Check for hamza and alef corrections (most common need)
        if let corrected = arabicHamzaCorrections[word] {
            return corrected
        }

        // Check for ta marbuta corrections (ه/ة confusion)
        if let corrected = arabicTaMarbutaCorrections[word] {
            return corrected
        }

        // Check for common word corrections
        if let corrected = arabicCommonCorrections[word] {
            return corrected
        }

        // Check for proper nouns (cities, countries)
        if let properNoun = arabicProperNouns[word] {
            return properNoun
        }

        return nil
    }

    /// Check if word is an Arabic proper noun
    static func isArabicProperNoun(_ word: String) -> Bool {
        return arabicProperNouns[word] != nil
    }

    // MARK: - Arabic Script Detection

    /// Check if text is in Arabic script
    static func isArabicScript(_ text: String) -> Bool {
        for char in text {
            // Arabic Unicode range: U+0600 to U+06FF
            if char >= "\u{0600}" && char <= "\u{06FF}" {
                return true
            }
            // Arabic Extended-A: U+08A0 to U+08FF
            if char >= "\u{08A0}" && char <= "\u{08FF}" {
                return true
            }
        }
        return false
    }

    // MARK: - Normalization

    /// Normalize Arabic text (remove diacritics for comparison)
    static func normalizeArabic(_ text: String) -> String {
        var result = text

        // Remove tashkeel (diacritics)
        let diacritics: [Character] = [
            "\u{064B}",  // Fathatan
            "\u{064C}",  // Dammatan
            "\u{064D}",  // Kasratan
            "\u{064E}",  // Fatha
            "\u{064F}",  // Damma
            "\u{0650}",  // Kasra
            "\u{0651}",  // Shadda
            "\u{0652}",  // Sukun
        ]

        for diacritic in diacritics {
            result = result.replacingOccurrences(of: String(diacritic), with: "")
        }

        return result
    }

    // MARK: - RTL Handling

    /// Check if text needs RTL direction
    static func needsRTL(_ text: String) -> Bool {
        return isArabicScript(text)
    }

    /// Get text direction for display
    static func getTextDirection(_ text: String) -> String {
        return needsRTL(text) ? "rtl" : "ltr"
    }

    // MARK: - Hamza and Alef Corrections
    // Common hamza placement errors and alef variations (أ, إ, آ)

    private static let arabicHamzaCorrections: [String: String] = [
        // ==========================================
        // HAMZA ON ALEF (أ, إ, آ) CORRECTIONS
        // ==========================================

        // إن/أن confusion (very common)
        "ان": "أن",           // أن (that - conjunction)
        "انا": "أنا",         // أنا (I)
        "انت": "أنت",         // أنت (you - masculine)
        "انتي": "أنتِ",       // أنتِ (you - feminine)
        "انتم": "أنتم",       // أنتم (you - plural masculine)
        "انتن": "أنتن",       // أنتن (you - plural feminine)

        // إلى (to) - very common
        "الى": "إلى",
        "الي": "إلى",

        // أو (or)
        "او": "أو",

        // أي (any/which)
        "اي": "أي",
        "ايّ": "أيّ",

        // أحد (one/someone)
        "احد": "أحد",

        // أخ/أخت (brother/sister)
        "اخ": "أخ",
        "اخت": "أخت",
        "اخي": "أخي",
        "اختي": "أختي",

        // أب/أم (father/mother)
        "اب": "أب",
        "ابي": "أبي",
        "ام": "أم",
        "امي": "أمي",

        // أهل (family/people)
        "اهل": "أهل",
        "اهلا": "أهلاً",
        "اهلًا": "أهلاً",

        // أمر (matter/command)
        "امر": "أمر",
        "امور": "أمور",

        // أول (first)
        "اول": "أول",
        "اولا": "أولاً",
        "اولًا": "أولاً",

        // أكثر/أقل (more/less)
        "اكثر": "أكثر",
        "اقل": "أقل",

        // أفضل/أحسن (better/best)
        "افضل": "أفضل",
        "احسن": "أحسن",

        // أجل (yes/for the sake of)
        "اجل": "أجل",

        // أيضاً (also)
        "ايضا": "أيضاً",
        "ايضًا": "أيضاً",

        // آخر (other/last)
        "اخر": "آخر",

        // آن (time/now) - in إلى الآن
        "الان": "الآن",

        // ==========================================
        // HAMZA IN MIDDLE OF WORD (ء, ؤ, ئ)
        // ==========================================

        // رأى/رأي (saw/opinion)
        "راى": "رأى",
        "راي": "رأي",
        "رايي": "رأيي",

        // سؤال (question)
        "سوال": "سؤال",
        "اسئلة": "أسئلة",

        // مسؤول (responsible)
        "مسوول": "مسؤول",
        "مسءول": "مسؤول",

        // شيء (thing)
        "شئ": "شيء",
        "اشياء": "أشياء",

        // بيئة (environment)
        "بيءة": "بيئة",
        "بيأة": "بيئة",

        // قراءة (reading)
        "قراءه": "قراءة",
        "قرائة": "قراءة",

        // ==========================================
        // COMMON WORDS WITH CORRECT HAMZA
        // ==========================================

        // أريد (I want)
        "اريد": "أريد",

        // أستطيع (I can)
        "استطيع": "أستطيع",

        // أفهم (I understand)
        "افهم": "أفهم",

        // أعرف (I know)
        "اعرف": "أعرف",

        // أحب (I love)
        "احب": "أحب",

        // أشكرك (I thank you)
        "اشكرك": "أشكرك",

        // أعتذر (I apologize)
        "اعتذر": "أعتذر",

        // أعتقد (I believe)
        "اعتقد": "أعتقد",

        // أقول (I say)
        "اقول": "أقول",

        // إذا (if)
        "اذا": "إذا",

        // إنشاء الله → إن شاء الله (God willing)
        "انشاء": "إنشاء",
        "انشالله": "إن شاء الله",

        // Additional common words
        "اسم": "اسم",         // name (no change needed but include for reference)
        "امس": "أمس",         // yesterday
        "اصبح": "أصبح",       // became
        "اخذ": "أخذ",         // took
        "اكل": "أكل",         // ate
        "اعطى": "أعطى",       // gave
        "ارسل": "أرسل",       // sent
    ]

    // MARK: - Ta Marbuta Corrections
    // ه/ة confusion at end of words (very common error)

    private static let arabicTaMarbutaCorrections: [String: String] = [
        // Common feminine nouns ending in ة
        "مدرسه": "مدرسة",     // school
        "جامعه": "جامعة",     // university
        "شركه": "شركة",       // company
        "مدينه": "مدينة",     // city
        "دوله": "دولة",       // country/state
        "حكومه": "حكومة",     // government
        "ساعه": "ساعة",       // hour/watch
        "دقيقه": "دقيقة",     // minute
        "سنه": "سنة",         // year
        "مره": "مرة",         // time (instance)
        "فتره": "فترة",       // period
        "صوره": "صورة",       // picture
        "فكره": "فكرة",       // idea
        "طريقه": "طريقة",     // way/method
        "حياه": "حياة",       // life
        "عائله": "عائلة",     // family
        "رساله": "رسالة",     // message/letter
        "زياره": "زيارة",     // visit
        "مساعده": "مساعدة",   // help
        "محادثه": "محادثة",   // conversation
        "اجابه": "إجابة",     // answer
        "مشكله": "مشكلة",     // problem
        "نتيجه": "نتيجة",     // result
        "خدمه": "خدمة",       // service
        "تجربه": "تجربة",     // experience
        "معلومه": "معلومة",   // information (piece of)
        "قصه": "قصة",         // story
        "لغه": "لغة",         // language
        "كلمه": "كلمة",       // word
        "جمله": "جملة",       // sentence
        "صفحه": "صفحة",       // page
        "وظيفه": "وظيفة",     // job/function
        "غرفه": "غرفة",       // room
        "سياره": "سيارة",     // car
        "رحله": "رحلة",       // trip
        "حفله": "حفلة",       // party/concert
        "وجبه": "وجبة",       // meal
        "قهوه": "قهوة",       // coffee
        "كتابه": "كتابة",     // writing
        "قراءه": "قراءة",     // reading (also hamza correction)
        "حاله": "حالة",       // situation/case
        "منطقه": "منطقة",     // area/region
        "درجه": "درجة",       // degree/grade
        "نسخه": "نسخة",       // copy
        "ليله": "ليلة",       // night
        "مقاله": "مقالة",     // article
        "صحيفه": "صحيفة",     // newspaper
        "مجله": "مجلة",       // magazine
        "مكتبه": "مكتبة",     // library/office
        "جريده": "جريدة",     // newspaper
    ]

    // MARK: - Common Word Corrections
    // Frequently mistyped or misspelled words

    private static let arabicCommonCorrections: [String: String] = [
        // Greetings and common phrases
        "مرحبا": "مرحباً",
        "اهلا": "أهلاً",
        "شكرا": "شكراً",
        "عفوا": "عفواً",
        "جدا": "جداً",
        "ابدا": "أبداً",
        "دائما": "دائماً",
        "احيانا": "أحياناً",
        "طبعا": "طبعاً",
        "فعلا": "فعلاً",
        "حقا": "حقاً",
        "معا": "معاً",
        "سويا": "سوياً",
        "قريبا": "قريباً",
        "لاحقا": "لاحقاً",
        "حالا": "حالاً",
        "فورا": "فوراً",
        "تقريبا": "تقريباً",
        "خصوصا": "خصوصاً",
        "عموما": "عموماً",
        "نهائيا": "نهائياً",
        "تماما": "تماماً",

        // Common phrases with proper spacing/spelling
        "ان شاء الله": "إن شاء الله",
        "انشاء الله": "إن شاء الله",
        "انشاءالله": "إن شاء الله",
        "الحمدلله": "الحمد لله",
        "الحمد الله": "الحمد لله",
        "ماشاء الله": "ما شاء الله",
        "ماشاءالله": "ما شاء الله",
        "سبحان الله": "سبحان الله",
        "جزاك الله خيرا": "جزاك الله خيراً",
        "بارك الله فيك": "بارك الله فيك",

        // Common words needing proper spelling
        "هاذا": "هذا",
        "هاذه": "هذه",
        "هاذي": "هذه",
        "كدا": "كذا",
        "هدا": "هذا",
        "هده": "هذه",

        // Question words
        "لمادا": "لماذا",
        "متي": "متى",
        "اين": "أين",

        // Preposition corrections
        "فى": "في",

        // Common conjunctions
        "لاكن": "لكن",
        "لاكنه": "لكنه",

        // Days of the week
        "الاحد": "الأحد",
        "الاثنين": "الاثنين",
        "الثلاثاء": "الثلاثاء",
        "الاربعاء": "الأربعاء",
        "الخميس": "الخميس",
        "الجمعه": "الجمعة",
        "السبت": "السبت",
    ]

    // MARK: - Arabic Proper Nouns
    // Cities, countries, and other proper nouns

    private static let arabicProperNouns: [String: String] = [
        // ==========================================
        // ARAB COUNTRIES
        // ==========================================
        "السعوديه": "السعودية",
        "السعودية": "السعودية",
        "الامارات": "الإمارات",
        "الإمارات": "الإمارات",
        "الكويت": "الكويت",
        "قطر": "قطر",
        "البحرين": "البحرين",
        "عمان": "عُمان",
        "اليمن": "اليمن",
        "العراق": "العراق",
        "سوريا": "سوريا",
        "لبنان": "لبنان",
        "الاردن": "الأردن",
        "الأردن": "الأردن",
        "فلسطين": "فلسطين",
        "مصر": "مصر",
        "السودان": "السودان",
        "ليبيا": "ليبيا",
        "تونس": "تونس",
        "الجزائر": "الجزائر",
        "المغرب": "المغرب",
        "موريتانيا": "موريتانيا",

        // ==========================================
        // MAJOR ARAB CITIES
        // ==========================================
        "الرياض": "الرياض",
        "جده": "جدة",
        "جدة": "جدة",
        "مكه": "مكة",
        "مكة": "مكة",
        "مكه المكرمه": "مكة المكرمة",
        "المدينه": "المدينة",
        "المدينة": "المدينة",
        "المدينه المنوره": "المدينة المنورة",
        "دبي": "دبي",
        "ابوظبي": "أبوظبي",
        "أبوظبي": "أبوظبي",
        "الشارقه": "الشارقة",
        "الشارقة": "الشارقة",
        "الدوحه": "الدوحة",
        "الدوحة": "الدوحة",
        "المنامه": "المنامة",
        "المنامة": "المنامة",
        "مسقط": "مسقط",
        "صنعاء": "صنعاء",
        "بغداد": "بغداد",
        "دمشق": "دمشق",
        "بيروت": "بيروت",
        "عمّان": "عمّان",         // Amman (capital of Jordan)
        "القدس": "القدس",
        "القاهره": "القاهرة",
        "القاهرة": "القاهرة",
        "الاسكندريه": "الإسكندرية",
        "الإسكندرية": "الإسكندرية",
        "الخرطوم": "الخرطوم",
        "طرابلس": "طرابلس",
        "الرباط": "الرباط",
        "الدار البيضاء": "الدار البيضاء",

        // ==========================================
        // OTHER COUNTRIES (Non-Arab)
        // ==========================================
        "امريكا": "أمريكا",
        "أمريكا": "أمريكا",
        "بريطانيا": "بريطانيا",
        "فرنسا": "فرنسا",
        "المانيا": "ألمانيا",
        "ألمانيا": "ألمانيا",
        "ايطاليا": "إيطاليا",
        "إيطاليا": "إيطاليا",
        "اسبانيا": "إسبانيا",
        "إسبانيا": "إسبانيا",
        "روسيا": "روسيا",
        "الصين": "الصين",
        "اليابان": "اليابان",
        "الهند": "الهند",
        "تركيا": "تركيا",
        "ايران": "إيران",
        "إيران": "إيران",
        "باكستان": "باكستان",
        "اندونيسيا": "إندونيسيا",
        "ماليزيا": "ماليزيا",
        "كندا": "كندا",
        "استراليا": "أستراليا",
        "أستراليا": "أستراليا",

        // ==========================================
        // INTERNATIONAL CITIES
        // ==========================================
        "لندن": "لندن",
        "باريس": "باريس",
        "نيويورك": "نيويورك",
        "طوكيو": "طوكيو",
        "بكين": "بكين",
        "موسكو": "موسكو",
        "برلين": "برلين",
        "روما": "روما",
        "مدريد": "مدريد",
        "اسطنبول": "إسطنبول",
        "إسطنبول": "إسطنبول",
    ]

    // MARK: - Arabic Abbreviations

    /// Common Arabic abbreviations and honorifics
    static let arabicAbbreviations: Set<String> = [
        // Honorifics and titles
        "السيد",        // Mr.
        "السيدة",       // Mrs.
        "الآنسة",       // Miss
        "الدكتور",      // Dr.
        "د.",           // Dr. (abbreviated)
        "الأستاذ",      // Professor/Teacher
        "أ.",           // Professor (abbreviated)
        "المهندس",      // Engineer
        "م.",           // Engineer (abbreviated)
        "الشيخ",        // Sheikh
        "الحاج",        // Hajj (pilgrim title)

        // Calendar
        "هـ",           // Hijri (Islamic calendar)
        "م",            // Miladi (Gregorian calendar)
        "ق.م",          // Before Christ (BC)
        "ب.م",          // After Christ (AD)

        // Common abbreviations
        "ص",            // Page
        "ج",            // Part/Volume
        "ط",            // Edition
        "رقم",          // Number
        "ت.",           // Telephone (abbreviated)

        // Common short forms
        "الخ",          // etc. (إلى آخره)
        "إلخ",          // etc. (إلى آخره)
        "أي",           // i.e.
    ]
}
