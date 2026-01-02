//
//  SpanishAutocorrectService.swift
//  SwiftSpeakKeyboard
//
//  Spanish language autocorrection service
//  Handles accent restoration and common corrections
//

import Foundation

/// Spanish autocorrection service for intelligent Spanish text correction
enum SpanishAutocorrectService {

    // MARK: - Main Correction Method

    /// Fix Spanish word - restores accents and applies corrections
    /// Returns nil if no correction needed
    static func fixSpanishWord(_ word: String) -> String? {
        let lowercased = word.lowercased()

        // Check for accent corrections
        if let corrected = spanishAccents[lowercased] {
            return preserveCase(original: word, corrected: corrected)
        }

        // Check for proper nouns
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
    // Words typed without accents → correct form with accents

    private static let spanishAccents: [String: String] = [
        // Common question words (always accented in questions)
        "que": "qué",
        "como": "cómo",
        "cuando": "cuándo",
        "donde": "dónde",
        "quien": "quién",
        "cual": "cuál",
        "cuanto": "cuánto",
        "cuantos": "cuántos",
        "porque": "porqué",

        // Common verbs with accents
        "esta": "está",
        "estan": "están",
        "estaba": "estaba",
        "podria": "podría",
        "podrias": "podrías",
        "seria": "sería",
        "serias": "serías",
        "haria": "haría",
        "harias": "harías",
        "tendria": "tendría",
        "tendrias": "tendrías",
        "queria": "quería",
        "querias": "querías",
        "sabia": "sabía",
        "sabias": "sabías",
        "hacia": "hacía",
        "hacias": "hacías",
        "tenia": "tenía",
        "tenias": "tenías",
        "venia": "venía",
        "venias": "venías",

        // Common nouns with accents
        "telefono": "teléfono",
        "numero": "número",
        "musica": "música",
        "pelicula": "película",
        "pagina": "página",
        "compania": "compañía",
        "familia": "familia",
        "informacion": "información",
        "direccion": "dirección",
        "atencion": "atención",
        "situacion": "situación",
        "educacion": "educación",
        "comunicacion": "comunicación",
        "organizacion": "organización",
        "relacion": "relación",
        "decision": "decisión",
        "opinion": "opinión",
        "razon": "razón",
        "corazon": "corazón",
        "cancion": "canción",
        "tradicion": "tradición",
        "revolucion": "revolución",
        "habitacion": "habitación",
        "estacion": "estación",
        "nacion": "nación",

        // Days and months
        "sabado": "sábado",
        "miercoles": "miércoles",

        // Common adverbs
        "mas": "más",
        "tambien": "también",
        "asi": "así",
        "aqui": "aquí",
        "ahi": "ahí",
        "alli": "allí",
        "despues": "después",
        "todavia": "todavía",
        "quiza": "quizá",
        "quizas": "quizás",

        // Other common words
        "si": "sí",  // Yes (vs "si" = if)
        "tu": "tú",  // You (vs "tu" = your)
        "el": "él",  // He (vs "el" = the)
        "cafe": "café",
        "menu": "menú",
        "bebe": "bebé",
        "papa": "papá",
        "mama": "mamá",
        "adios": "adiós",
        "facil": "fácil",
        "dificil": "difícil",
        "util": "útil",
        "inutil": "inútil",
        "rapido": "rápido",
        "clasico": "clásico",
        "publico": "público",
        "politica": "política",
        "economico": "económico",
        "economica": "económica",
        "historico": "histórico",
        "historica": "histórica",
        "tecnico": "técnico",
        "tecnica": "técnica",
        "medico": "médico",
        "medica": "médica",
        "unico": "único",
        "unica": "única",
        "ultimo": "último",
        "ultima": "última",
        "proximo": "próximo",
        "proxima": "próxima",
    ]

    // MARK: - Spanish Proper Nouns

    private static let spanishProperNouns: [String: String] = [
        // Spanish cities
        "madrid": "Madrid",
        "barcelona": "Barcelona",
        "valencia": "Valencia",
        "sevilla": "Sevilla",
        "zaragoza": "Zaragoza",
        "malaga": "Málaga",
        "murcia": "Murcia",
        "palma": "Palma",
        "bilbao": "Bilbao",
        "cordoba": "Córdoba",
        "granada": "Granada",
        "toledo": "Toledo",
        "salamanca": "Salamanca",

        // Latin American capitals
        "mexico": "México",
        "bogota": "Bogotá",
        "lima": "Lima",
        "santiago": "Santiago",
        "caracas": "Caracas",
        "buenos aires": "Buenos Aires",
        "montevideo": "Montevideo",
        "quito": "Quito",
        "la paz": "La Paz",
        "panama": "Panamá",
        "san jose": "San José",
        "managua": "Managua",
        "tegucigalpa": "Tegucigalpa",
        "guatemala": "Guatemala",

        // Countries
        "espana": "España",
        "peru": "Perú",
        "brasil": "Brasil",
        "argentina": "Argentina",
        "colombia": "Colombia",
        "venezuela": "Venezuela",
        "chile": "Chile",
        "ecuador": "Ecuador",
        "bolivia": "Bolivia",
        "paraguay": "Paraguay",
        "uruguay": "Uruguay",
        "cuba": "Cuba",
        "republica dominicana": "República Dominicana",
        "puerto rico": "Puerto Rico",
    ]
}
