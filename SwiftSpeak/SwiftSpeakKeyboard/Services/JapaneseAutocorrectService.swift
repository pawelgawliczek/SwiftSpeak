//
//  JapaneseAutocorrectService.swift
//  SwiftSpeakKeyboard
//
//  Japanese language autocorrection service
//  Handles particle corrections, common kanji variants, and proper nouns
//
//  NOTE: Japanese input typically uses IME (Input Method Editor) for
//  hiragana-to-kanji conversion. This service handles post-IME corrections
//  and common confusion patterns.
//

import Foundation

/// Japanese autocorrection service for intelligent Japanese text correction
enum JapaneseAutocorrectService {

    // MARK: - Main Correction Method

    /// Fix Japanese word - applies particle corrections and common fixes
    /// Returns nil if no correction needed
    static func fixJapaneseWord(_ word: String) -> String? {
        // Check for particle corrections (most common need)
        if let corrected = particleCorrections[word] {
            return corrected
        }

        // Check for common kanji corrections
        if let corrected = kanjiCorrections[word] {
            return corrected
        }

        // Check for proper nouns (ensure proper form)
        if let properNoun = japaneseProperNouns[word] {
            return properNoun
        }

        return nil
    }

    /// Check if word is a Japanese proper noun
    static func isProperNoun(_ word: String) -> Bool {
        return japaneseProperNouns[word] != nil
    }

    // MARK: - Particle Corrections
    // Common particle confusion patterns in Japanese
    // Note: は (wa) as topic marker is written as は not わ
    //       を (wo/o) as object marker is written as を not お

    private static let particleCorrections: [String: String] = [
        // Topic particle は written incorrectly as わ
        // These are phrases where わ should be は (topic marker)
        "わたしわ": "私は",      // watashi wa (I + topic)
        "あなたわ": "あなたは",  // anata wa (you + topic)
        "これわ": "これは",      // kore wa (this + topic)
        "それわ": "それは",      // sore wa (that + topic)
        "あれわ": "あれは",      // are wa (that over there + topic)
        "なにわ": "何は",        // nani wa (what + topic) - though rare
        "きょうわ": "今日は",    // kyou wa (today + topic)
        "あしたわ": "明日は",    // ashita wa (tomorrow + topic)
        "きのうわ": "昨日は",    // kinou wa (yesterday + topic)

        // Object particle を written incorrectly as お
        // These are common verb phrases with を
        "おたべる": "を食べる",   // o taberu (eat [object])
        "おのむ": "を飲む",       // o nomu (drink [object])
        "おみる": "を見る",       // o miru (see [object])
        "おきく": "を聞く",       // o kiku (hear/listen [object])
        "およむ": "を読む",       // o yomu (read [object])
        "おかく": "を書く",       // o kaku (write [object])
        "おつくる": "を作る",     // o tsukuru (make [object])

        // Direction particle へ/に confusion (less critical but helpful)
        "いええ": "家へ",         // ie e (to home)
        "えきえ": "駅へ",         // eki e (to station)
        "がっこうえ": "学校へ",   // gakkou e (to school)
    ]

    // MARK: - Kanji Corrections
    // Common kanji variants and corrections

    private static let kanjiCorrections: [String: String] = [
        // Simplified/variant forms to standard forms
        "斉": "斎",              // Variant kanji
        "験": "驗",              // Traditional to standard (if user types wrong one)

        // Common homophone confusions (these are educated guesses based on context)
        // Note: True homophone resolution requires context, so we keep this minimal
        "以外": "意外",          // igai - "other than" vs "unexpected" (common confusion)
        "私達": "私たち",        // watashitachi - mixed form to hiragana ending

        // Counter/unit standardization
        "一つ": "ひとつ",        // hitotsu - can be written either way
        "二つ": "ふたつ",        // futatsu
        "三つ": "みっつ",        // mittsu

        // Common phrases with preferred kanji
        "今日わ": "今日は",      // konnichiwa - greeting
        "今晩わ": "今晩は",      // konbanwa - good evening
    ]

    // MARK: - Japanese Proper Nouns
    // Major Japanese cities, regions, and landmarks

    private static let japaneseProperNouns: [String: String] = [
        // Major cities (already in kanji but ensure correct form)
        "とうきょう": "東京",     // Tokyo
        "おおさか": "大阪",       // Osaka
        "きょうと": "京都",       // Kyoto
        "よこはま": "横浜",       // Yokohama
        "なごや": "名古屋",       // Nagoya
        "さっぽろ": "札幌",       // Sapporo
        "ふくおか": "福岡",       // Fukuoka
        "こうべ": "神戸",         // Kobe
        "かわさき": "川崎",       // Kawasaki
        "さいたま": "さいたま",   // Saitama (officially in hiragana)
        "ひろしま": "広島",       // Hiroshima
        "せんだい": "仙台",       // Sendai
        "ちば": "千葉",           // Chiba
        "きたきゅうしゅう": "北九州", // Kitakyushu
        "にいがた": "新潟",       // Niigata
        "はままつ": "浜松",       // Hamamatsu
        "くまもと": "熊本",       // Kumamoto
        "おかやま": "岡山",       // Okayama
        "しずおか": "静岡",       // Shizuoka
        "ながさき": "長崎",       // Nagasaki
        "かなざわ": "金沢",       // Kanazawa
        "なら": "奈良",           // Nara

        // Prefectures
        "ほっかいどう": "北海道", // Hokkaido
        "あおもり": "青森",       // Aomori
        "いわて": "岩手",         // Iwate
        "みやぎ": "宮城",         // Miyagi
        "あきた": "秋田",         // Akita
        "やまがた": "山形",       // Yamagata
        "ふくしま": "福島",       // Fukushima
        "いばらき": "茨城",       // Ibaraki
        "とちぎ": "栃木",         // Tochigi
        "ぐんま": "群馬",         // Gunma
        "かながわ": "神奈川",     // Kanagawa
        "とやま": "富山",         // Toyama
        "いしかわ": "石川",       // Ishikawa
        "ふくい": "福井",         // Fukui
        "やまなし": "山梨",       // Yamanashi
        "ながの": "長野",         // Nagano
        "ぎふ": "岐阜",           // Gifu
        "あいち": "愛知",         // Aichi
        "みえ": "三重",           // Mie
        "しが": "滋賀",           // Shiga
        "ひょうご": "兵庫",       // Hyogo
        "わかやま": "和歌山",     // Wakayama
        "とっとり": "鳥取",       // Tottori
        "しまね": "島根",         // Shimane
        "やまぐち": "山口",       // Yamaguchi
        "とくしま": "徳島",       // Tokushima
        "かがわ": "香川",         // Kagawa
        "えひめ": "愛媛",         // Ehime
        "こうち": "高知",         // Kochi
        "さが": "佐賀",           // Saga
        "おおいた": "大分",       // Oita
        "みやざき": "宮崎",       // Miyazaki
        "かごしま": "鹿児島",     // Kagoshima
        "おきなわ": "沖縄",       // Okinawa

        // Country
        "にほん": "日本",         // Nihon/Japan
        "にっぽん": "日本",       // Nippon/Japan

        // Famous landmarks
        "ふじさん": "富士山",     // Mt. Fuji
        "びわこ": "琵琶湖",       // Lake Biwa
        "とうきょうたわー": "東京タワー", // Tokyo Tower
        "きんかくじ": "金閣寺",   // Kinkakuji
        "ぎんかくじ": "銀閣寺",   // Ginkakuji
        "きよみずでら": "清水寺", // Kiyomizu-dera
        "ふしみいなり": "伏見稲荷", // Fushimi Inari
        "あさくさ": "浅草",       // Asakusa
        "しぶや": "渋谷",         // Shibuya
        "しんじゅく": "新宿",     // Shinjuku
        "あきはばら": "秋葉原",   // Akihabara
        "ぎんざ": "銀座",         // Ginza
        "はらじゅく": "原宿",     // Harajuku
        "うえの": "上野",         // Ueno
    ]

    // MARK: - Japanese Abbreviations / Honorifics
    // Common suffixes and titles

    static let japaneseHonorifics: Set<String> = [
        // Personal honorifics
        "様",      // sama - very formal
        "さま",    // sama in hiragana
        "殿",      // dono - formal (documents)
        "さん",    // san - standard polite
        "君",      // kun - for males, subordinates
        "くん",    // kun in hiragana
        "ちゃん",  // chan - affectionate
        "先生",    // sensei - teacher/doctor
        "氏",      // shi - formal (articles)

        // Professional titles
        "社長",    // shachou - company president
        "部長",    // buchou - department head
        "課長",    // kachou - section chief
        "係長",    // kakarichou - subsection chief
        "教授",    // kyouju - professor
        "博士",    // hakase - doctor (PhD)
    ]

    // MARK: - Common Sentence-Ending Patterns
    // These help with prediction more than correction

    static let sentenceEndings: Set<String> = [
        "です",    // desu - polite copula
        "ます",    // masu - polite verb ending
        "でした",  // deshita - past polite
        "ました",  // mashita - past polite verb
        "ません",  // masen - negative polite
        "ですか",  // desu ka - polite question
        "ますか",  // masu ka - polite verb question
        "ですね",  // desu ne - seeking agreement
        "ですよ",  // desu yo - emphatic
        "だ",      // da - plain copula
        "である",  // de aru - formal written
        "ございます", // gozaimasu - very polite
    ]
}
