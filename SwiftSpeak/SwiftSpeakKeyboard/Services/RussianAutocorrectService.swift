//
//  RussianAutocorrectService.swift
//  SwiftSpeakKeyboard
//
//  Russian language autocorrection service
//  Handles yoisation (ё) and proper noun capitalization
//

import Foundation

/// Russian autocorrection service for intelligent Russian text correction
enum RussianAutocorrectService {

    // MARK: - Main Correction Method

    /// Fix Russian word - restores ё and applies corrections
    /// Returns nil if no correction needed
    static func fixRussianWord(_ word: String) -> String? {
        let lowercased = word.lowercased()

        // Check for ё corrections (yoisation)
        if let corrected = russianYoisation[lowercased] {
            return preserveCase(original: word, corrected: corrected)
        }

        // Check for proper nouns
        if let properNoun = russianProperNouns[lowercased] {
            return properNoun
        }

        return nil
    }

    /// Check if word should be capitalized (Russian proper nouns)
    static func shouldCapitalizeRussian(_ word: String) -> String? {
        let lowercased = word.lowercased()
        return russianProperNouns[lowercased]
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

    // MARK: - Russian Yoisation Dictionary
    // Words with е that should be ё

    private static let russianYoisation: [String: String] = [
        // Common words with ё
        "все": "всё",
        "ее": "её",
        "еще": "ещё",
        "мое": "моё",
        "твое": "твоё",
        "свое": "своё",

        // Verbs
        "идет": "идёт",
        "берет": "берёт",
        "дает": "даёт",
        "поет": "поёт",
        "пьет": "пьёт",
        "везет": "везёт",
        "несет": "несёт",
        "живет": "живёт",
        "зовет": "зовёт",
        "ведет": "ведёт",
        "найдет": "найдёт",
        "придет": "придёт",
        "пойдет": "пойдёт",

        // Nouns
        "елка": "ёлка",
        "еж": "ёж",
        "мед": "мёд",
        "лед": "лёд",
        "счет": "счёт",
        "полет": "полёт",
        "самолет": "самолёт",
        "вертолет": "вертолёт",
        "черт": "чёрт",

        // Adjectives
        "зеленый": "зелёный",
        "зеленая": "зелёная",
        "зеленое": "зелёное",
        "теплый": "тёплый",
        "теплая": "тёплая",
        "теплое": "тёплое",
        "темный": "тёмный",
        "темная": "тёмная",
        "темное": "тёмное",

        // Other common words
        "звезды": "звёзды",
        "сестры": "сёстры",
        "вперед": "вперёд",
    ]

    // MARK: - Russian Proper Nouns

    private static let russianProperNouns: [String: String] = [
        // Russian cities
        "москва": "Москва",
        "санкт-петербург": "Санкт-Петербург",
        "петербург": "Петербург",
        "новосибирск": "Новосибирск",
        "екатеринбург": "Екатеринбург",
        "нижний новгород": "Нижний Новгород",
        "казань": "Казань",
        "челябинск": "Челябинск",
        "омск": "Омск",
        "самара": "Самара",
        "ростов-на-дону": "Ростов-на-Дону",
        "уфа": "Уфа",
        "красноярск": "Красноярск",
        "пермь": "Пермь",
        "воронеж": "Воронеж",
        "волгоград": "Волгоград",
        "краснодар": "Краснодар",
        "саратов": "Саратов",
        "тюмень": "Тюмень",
        "тольятти": "Тольятти",
        "сочи": "Сочи",

        // Countries
        "россия": "Россия",
        "украина": "Украина",
        "беларусь": "Беларусь",
        "белоруссия": "Белоруссия",
        "казахстан": "Казахстан",
        "узбекистан": "Узбекистан",
        "грузия": "Грузия",
        "армения": "Армения",
        "азербайджан": "Азербайджан",
        "молдова": "Молдова",

        // Rivers and landmarks
        "волга": "Волга",
        "дон": "Дон",
        "обь": "Обь",
        "енисей": "Енисей",
        "лена": "Лена",
        "амур": "Амур",
        "байкал": "Байкал",
        "кремль": "Кремль",
    ]
}
