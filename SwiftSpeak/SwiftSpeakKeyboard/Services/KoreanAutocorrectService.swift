//
//  KoreanAutocorrectService.swift
//  SwiftSpeak
//
//  Korean language autocorrection service
//  Handles common spacing errors and proper nouns
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//
//  NOTE: Korean typically uses IME for input, so autocorrect is limited compared
//  to alphabetic languages. Main focus is on spacing rules and proper nouns.
//

import Foundation

/// Korean autocorrection service for intelligent Korean text correction
enum KoreanAutocorrectService {

    // MARK: - Main Correction Method

    /// Fix Korean word - handles spacing errors and proper nouns
    /// Returns nil if no correction needed
    static func fixKoreanWord(_ word: String) -> String? {
        // Check for proper nouns (cities, countries, etc.)
        if let properNoun = koreanProperNouns[word] {
            return properNoun
        }

        // Korean is typically typed with IME, so minimal corrections needed
        // Check for common spacing fixes in compound words
        if let spacingFix = koreanSpacingFixes[word] {
            return spacingFix
        }

        return nil
    }

    /// Check if word should be capitalized (not typically needed for Korean)
    /// Korean doesn't have capitalization, but this is kept for API consistency
    static func shouldCapitalizeKorean(_ word: String) -> String? {
        return koreanProperNouns[word]
    }

    // MARK: - Korean Proper Nouns
    // Cities, regions, countries, and other proper nouns

    private static let koreanProperNouns: [String: String] = [
        // Major Korean cities
        "서울": "서울",
        "부산": "부산",
        "인천": "인천",
        "대구": "대구",
        "대전": "대전",
        "광주": "광주",
        "울산": "울산",
        "세종": "세종",
        "수원": "수원",
        "성남": "성남",
        "고양": "고양",
        "용인": "용인",
        "창원": "창원",
        "청주": "청주",
        "전주": "전주",
        "천안": "천안",
        "안산": "안산",
        "안양": "안양",
        "평택": "평택",
        "제주": "제주",
        "포항": "포항",
        "김해": "김해",
        "의정부": "의정부",
        "파주": "파주",
        "시흥": "시흥",
        "화성": "화성",
        "광명": "광명",
        "구리": "구리",
        "남양주": "남양주",
        "오산": "오산",
        "하남": "하남",
        "이천": "이천",
        "안성": "안성",
        "의왕": "의왕",
        "군포": "군포",
        "양주": "양주",
        "원주": "원주",
        "강릉": "강릉",
        "속초": "속초",
        "춘천": "춘천",
        "충주": "충주",
        "제천": "제천",
        "아산": "아산",
        "논산": "논산",
        "서산": "서산",
        "공주": "공주",
        "보령": "보령",
        "익산": "익산",
        "군산": "군산",
        "정읍": "정읍",
        "남원": "남원",
        "김제": "김제",
        "목포": "목포",
        "여수": "여수",
        "순천": "순천",
        "광양": "광양",
        "나주": "나주",
        "경주": "경주",
        "김천": "김천",
        "안동": "안동",
        "구미": "구미",
        "영주": "영주",
        "영천": "영천",
        "상주": "상주",
        "문경": "문경",
        "경산": "경산",
        "진주": "진주",
        "통영": "통영",
        "사천": "사천",
        "밀양": "밀양",
        "거제": "거제",
        "양산": "양산",

        // Provinces/Regions
        "경기도": "경기도",
        "강원도": "강원도",
        "충청북도": "충청북도",
        "충청남도": "충청남도",
        "전라북도": "전라북도",
        "전라남도": "전라남도",
        "경상북도": "경상북도",
        "경상남도": "경상남도",
        "제주도": "제주도",
        "제주특별자치도": "제주특별자치도",

        // Countries
        "한국": "한국",
        "대한민국": "대한민국",
        "북한": "북한",
        "조선": "조선",
        "일본": "일본",
        "중국": "중국",
        "미국": "미국",
        "영국": "영국",
        "프랑스": "프랑스",
        "독일": "독일",
        "이탈리아": "이탈리아",
        "스페인": "스페인",
        "러시아": "러시아",
        "캐나다": "캐나다",
        "호주": "호주",
        "뉴질랜드": "뉴질랜드",
        "브라질": "브라질",
        "멕시코": "멕시코",
        "인도": "인도",
        "태국": "태국",
        "베트남": "베트남",
        "필리핀": "필리핀",
        "인도네시아": "인도네시아",
        "말레이시아": "말레이시아",
        "싱가포르": "싱가포르",
        "대만": "대만",
        "홍콩": "홍콩",

        // Continents and regions
        "아시아": "아시아",
        "유럽": "유럽",
        "아프리카": "아프리카",
        "북미": "북미",
        "남미": "남미",
        "오세아니아": "오세아니아",
        "동남아시아": "동남아시아",
        "동아시아": "동아시아",

        // Famous landmarks/districts
        "강남": "강남",
        "홍대": "홍대",
        "명동": "명동",
        "이태원": "이태원",
        "동대문": "동대문",
        "남대문": "남대문",
        "경복궁": "경복궁",
        "창덕궁": "창덕궁",
        "덕수궁": "덕수궁",
        "광화문": "광화문",
        "남산": "남산",
        "북한산": "북한산",
        "한강": "한강",
        "낙동강": "낙동강",
        "금강": "금강",
        "영산강": "영산강",
        "설악산": "설악산",
        "지리산": "지리산",
        "한라산": "한라산",
        "백두산": "백두산",
    ]

    // MARK: - Korean Spacing Fixes
    // Common words that are often typed without proper spacing

    private static let koreanSpacingFixes: [String: String] = [:]
        // These are compound words that might need spacing adjustments
        // Korean spacing rules are complex - most corrections should be minimal
        // Common errors: extra spaces or missing spaces
        // Note: Korean IME typically handles this, so these are edge cases

    // MARK: - Korean Abbreviations/Honorifics

    /// Common Korean honorific suffixes and titles
    static let koreanHonorifics: Set<String> = [
        // Honorific suffixes
        "씨",        // -ssi (Mr./Ms.)
        "님",        // -nim (honorific)
        "군",        // -gun (young man)
        "양",        // -yang (young woman)

        // Professional titles
        "선생님",     // teacher (honorific)
        "교수님",     // professor (honorific)
        "사장님",     // CEO/boss (honorific)
        "부장님",     // department head (honorific)
        "과장님",     // section chief (honorific)
        "대리님",     // assistant manager (honorific)
        "사원님",     // employee (honorific)
        "회장님",     // chairman (honorific)
        "이사님",     // director (honorific)
        "실장님",     // team leader (honorific)
        "팀장님",     // team leader (honorific)
        "차장님",     // deputy manager (honorific)
        "상무님",     // managing director (honorific)
        "전무님",     // executive director (honorific)

        // Academic titles
        "박사님",     // PhD/Doctor (honorific)
        "석사",       // Master's degree holder
        "학사",       // Bachelor's degree holder

        // Medical titles
        "의사",       // doctor
        "간호사",     // nurse
        "약사",       // pharmacist

        // Other titles
        "기사님",     // driver (honorific, for taxi/bus)
        "사모님",     // madam (wife of respected person)
        "아저씨",     // uncle/middle-aged man
        "아줌마",     // aunt/middle-aged woman
        "할아버지",    // grandfather
        "할머니",     // grandmother
        "아버지",     // father
        "어머니",     // mother
        "형",        // older brother (male speaker)
        "누나",       // older sister (male speaker)
        "오빠",       // older brother (female speaker)
        "언니",       // older sister (female speaker)
        "동생",       // younger sibling
    ]

    // MARK: - Common Korean Abbreviations

    /// Common Korean abbreviations and slang
    static let koreanAbbreviations: Set<String> = [
        // Internet/texting abbreviations
        "ㅋㅋ",       // laughing (kk)
        "ㅋㅋㅋ",      // laughing harder
        "ㅎㅎ",       // laughing softly (hh)
        "ㅎㅎㅎ",      // laughing softly more
        "ㅠㅠ",       // crying
        "ㅜㅜ",       // crying
        "ㄱㅅ",       // 감사 (thanks - abbreviated)
        "ㄴㄴ",       // 노노 (no no)
        "ㅇㅇ",       // 응응 (yes yes)
        "ㅇㅋ",       // OK
        "ㄷㄷ",       // 덜덜 (shaking/nervous)
        "ㅎㄷㄷ",      // 후덜덜 (very nervous)
        "ㄱㄱ",       // 고고 (go go)
        "ㅂㅂ",       // 바이바이 (bye bye)
        "ㅈㅅ",       // 죄송 (sorry - abbreviated)
        "ㄹㅇ",       // 레알/리얼 (real)
        "ㅁㅊ",       // 미쳤 (crazy - abbreviated)
        "ㄱㅊ",       // 괜찮 (it's okay - abbreviated)

        // Common short forms
        "안녕",       // hello (informal)
        "감사",       // thanks
        "죄송",       // sorry
        "미안",       // sorry (informal)
        "고마워",     // thank you (informal)
        "괜찮아",     // it's okay
        "알겠어",     // I understand

        // Units and measurements
        "원",        // won (currency)
        "kg",       // kilogram
        "km",       // kilometer
        "cm",       // centimeter
        "mm",       // millimeter
        "ml",       // milliliter
        "개",        // counter for objects
        "명",        // counter for people
        "권",        // counter for books
        "장",        // counter for flat objects
        "병",        // counter for bottles
        "잔",        // counter for glasses/cups
        "그릇",       // counter for bowls
        "마리",       // counter for animals
        "대",        // counter for vehicles/machines
        "채",        // counter for buildings
        "벌",        // counter for clothes sets

        // Time-related
        "초",        // second
        "분",        // minute
        "시",        // hour
        "일",        // day
        "월",        // month
        "년",        // year
        "주",        // week
    ]
}
