//
//  ChineseAutocorrectService.swift
//  SwiftSpeak
//
//  Chinese language autocorrection service
//  Handles common character corrections and proper nouns
//
//  NOTE: Chinese typically uses IME (Input Method Editor) for character input,
//  so autocorrect is more limited than alphabetic languages. This service focuses on:
//  - Common character corrections (similar-looking characters)
//  - Proper noun capitalization/standardization
//  - Simplified/Traditional character preferences
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation

/// Chinese autocorrection service for intelligent Chinese text correction
enum ChineseAutocorrectService {

    // MARK: - Main Correction Method

    /// Fix Chinese character - applies common corrections
    /// Returns nil if no correction needed
    static func fixChineseCharacter(_ text: String) -> String? {
        // Check for common character corrections
        if let corrected = commonCorrections[text] {
            return corrected
        }

        // Check for proper nouns (places, etc.)
        if let properNoun = chineseProperNouns[text] {
            return properNoun
        }

        // Check for simplified/traditional standardization
        if let standardized = simplifiedStandard[text] {
            return standardized
        }

        return nil
    }

    /// Check if text is a Chinese proper noun
    static func isChineseProperNoun(_ text: String) -> Bool {
        return chineseProperNouns.keys.contains(text)
    }

    /// Get the standard form of a proper noun
    static func standardizeProperNoun(_ text: String) -> String? {
        return chineseProperNouns[text]
    }

    // MARK: - Common Character Corrections
    // Fixes for commonly confused or mistyped characters

    private static let commonCorrections: [String: String] = [
        // Commonly confused characters (homophone/similar shape)
        "的": "的",    // No change - most common particle (placeholder for structure)
        "地": "地",    // Adverbial marker vs 的
        "得": "得",    // Complement marker vs 的

        // Common typos and confusions
        "那": "哪",    // "that" vs "which" (context-dependent)
        "在": "再",    // "at/in" vs "again" (context-dependent)

        // Number-related corrections
        "二": "两",    // "two" formal vs colloquial (context-dependent)

        // Punctuation normalization (full-width to consistent)
        ",": "，",     // Half-width to full-width comma
        ".": "。",     // Half-width to full-width period
        "!": "！",     // Half-width to full-width exclamation
        "?": "？",     // Half-width to full-width question mark
        ":": "：",     // Half-width to full-width colon
        ";": "；",     // Half-width to full-width semicolon
        "(": "（",     // Half-width to full-width parenthesis
        ")": "）",     // Half-width to full-width parenthesis
    ]

    // MARK: - Simplified/Traditional Standardization
    // Prefer simplified Chinese for consistency (most users)

    private static let simplifiedStandard: [String: String] = [
        // Common traditional -> simplified mappings
        "國": "国",    // country
        "說": "说",    // speak
        "學": "学",    // study
        "時": "时",    // time
        "見": "见",    // see
        "長": "长",    // long
        "開": "开",    // open
        "問": "问",    // ask
        "裡": "里",    // inside
        "實": "实",    // real
        "現": "现",    // now
        "機": "机",    // machine
        "動": "动",    // move
        "東": "东",    // east
        "紅": "红",    // red
        "馬": "马",    // horse
        "魚": "鱼",    // fish
        "鳥": "鸟",    // bird
        "電": "电",    // electricity
        "車": "车",    // car
        "門": "门",    // door
        "書": "书",    // book
        "話": "话",    // speech
        "語": "语",    // language
        "認": "认",    // recognize
        "識": "识",    // know
        "記": "记",    // remember
        "請": "请",    // please
        "謝": "谢",    // thank
        "對": "对",    // correct/toward
        "關": "关",    // close/about
        "體": "体",    // body
        "頭": "头",    // head
        "臉": "脸",    // face
        "號": "号",    // number
        "錢": "钱",    // money
        "買": "买",    // buy
        "賣": "卖",    // sell
    ]

    // MARK: - Chinese Proper Nouns
    // Major cities, regions, and landmarks

    private static let chineseProperNouns: [String: String] = [
        // Major Chinese cities
        "北京": "北京",
        "上海": "上海",
        "广州": "广州",
        "深圳": "深圳",
        "杭州": "杭州",
        "南京": "南京",
        "天津": "天津",
        "重庆": "重庆",
        "成都": "成都",
        "武汉": "武汉",
        "西安": "西安",
        "苏州": "苏州",
        "长沙": "长沙",
        "郑州": "郑州",
        "青岛": "青岛",
        "大连": "大连",
        "厦门": "厦门",
        "宁波": "宁波",
        "福州": "福州",
        "昆明": "昆明",
        "哈尔滨": "哈尔滨",
        "沈阳": "沈阳",
        "济南": "济南",
        "长春": "长春",
        "合肥": "合肥",
        "南昌": "南昌",
        "太原": "太原",
        "石家庄": "石家庄",
        "贵阳": "贵阳",
        "南宁": "南宁",
        "海口": "海口",
        "兰州": "兰州",
        "银川": "银川",
        "西宁": "西宁",
        "呼和浩特": "呼和浩特",
        "乌鲁木齐": "乌鲁木齐",
        "拉萨": "拉萨",

        // Special Administrative Regions
        "香港": "香港",
        "澳门": "澳门",
        "台北": "台北",
        "高雄": "高雄",

        // Countries
        "中国": "中国",
        "美国": "美国",
        "英国": "英国",
        "法国": "法国",
        "德国": "德国",
        "日本": "日本",
        "韩国": "韩国",
        "俄罗斯": "俄罗斯",
        "加拿大": "加拿大",
        "澳大利亚": "澳大利亚",
        "新西兰": "新西兰",
        "新加坡": "新加坡",
        "印度": "印度",
        "巴西": "巴西",
        "墨西哥": "墨西哥",
        "意大利": "意大利",
        "西班牙": "西班牙",
        "荷兰": "荷兰",
        "瑞士": "瑞士",
        "瑞典": "瑞典",

        // Major regions/provinces
        "广东": "广东",
        "江苏": "江苏",
        "浙江": "浙江",
        "山东": "山东",
        "河南": "河南",
        "四川": "四川",
        "湖北": "湖北",
        "湖南": "湖南",
        "福建": "福建",
        "安徽": "安徽",
        "河北": "河北",
        "辽宁": "辽宁",
        "陕西": "陕西",
        "江西": "江西",
        "云南": "云南",
        "贵州": "贵州",
        "山西": "山西",
        "吉林": "吉林",
        "黑龙江": "黑龙江",
        "内蒙古": "内蒙古",
        "新疆": "新疆",
        "西藏": "西藏",
        "广西": "广西",
        "海南": "海南",
        "甘肃": "甘肃",
        "宁夏": "宁夏",
        "青海": "青海",

        // Famous landmarks
        "长城": "长城",
        "故宫": "故宫",
        "天安门": "天安门",
        "颐和园": "颐和园",
        "天坛": "天坛",
        "圆明园": "圆明园",
        "西湖": "西湖",
        "黄山": "黄山",
        "泰山": "泰山",
        "华山": "华山",
        "峨眉山": "峨眉山",
        "桂林": "桂林",
        "九寨沟": "九寨沟",
        "丽江": "丽江",
        "外滩": "外滩",
        "东方明珠": "东方明珠",

        // Rivers and geography
        "长江": "长江",
        "黄河": "黄河",
        "珠江": "珠江",
        "黑龙江": "黑龙江",
        "太湖": "太湖",
        "鄱阳湖": "鄱阳湖",
        "洞庭湖": "洞庭湖",
        "喜马拉雅": "喜马拉雅",

        // Major companies/brands (Chinese origin)
        "阿里巴巴": "阿里巴巴",
        "腾讯": "腾讯",
        "百度": "百度",
        "华为": "华为",
        "小米": "小米",
        "京东": "京东",
        "字节跳动": "字节跳动",
        "抖音": "抖音",
        "微信": "微信",
        "微博": "微博",
        "淘宝": "淘宝",
        "支付宝": "支付宝",
    ]

    // MARK: - Chinese Abbreviations/Honorifics

    /// Common Chinese titles and honorifics
    static let chineseHonorifics: [String: String] = [
        "先生": "先生",      // Mr./Sir
        "女士": "女士",      // Ms./Madam
        "小姐": "小姐",      // Miss
        "太太": "太太",      // Mrs.
        "老师": "老师",      // Teacher
        "教授": "教授",      // Professor
        "博士": "博士",      // Doctor (PhD)
        "医生": "医生",      // Doctor (medical)
        "律师": "律师",      // Lawyer
        "经理": "经理",      // Manager
        "总监": "总监",      // Director
        "董事长": "董事长",  // Chairman
        "总裁": "总裁",      // CEO
        "主任": "主任",      // Director/Chief
        "院长": "院长",      // Dean/President
        "校长": "校长",      // Principal
        "部长": "部长",      // Minister/Department Head
        "市长": "市长",      // Mayor
        "省长": "省长",      // Governor
        "主席": "主席",      // Chairman/President
    ]

    /// Common Chinese abbreviations
    static let chineseAbbreviations: Set<String> = [
        // Titles
        "先生", "女士", "教授", "博士",
        // Units
        "元", "角", "分", "块",
        "米", "厘米", "毫米", "公里",
        "克", "千克", "公斤", "斤",
        "升", "毫升",
        "平方米", "平米",
        // Time
        "年", "月", "日", "号",
        "时", "分", "秒",
        "点", "半",
        // Counters/Measure words
        "个", "位", "只", "条",
        "本", "张", "件", "把",
        "辆", "架", "艘", "台",
        // Common abbreviations
        "等", "即", "如", "例如",
        "比如", "包括", "及", "和",
    ]
}
