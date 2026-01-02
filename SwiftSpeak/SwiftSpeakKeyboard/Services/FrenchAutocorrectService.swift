//
//  FrenchAutocorrectService.swift
//  SwiftSpeakKeyboard
//
//  French language autocorrection service
//  Handles accent restoration and elision rules
//

import Foundation

/// French autocorrection service for intelligent French text correction
enum FrenchAutocorrectService {

    // MARK: - Main Correction Method

    /// Fix French word - restores accents and applies corrections
    /// Returns nil if no correction needed
    static func fixFrenchWord(_ word: String) -> String? {
        let lowercased = word.lowercased()

        // Check for accent corrections
        if let corrected = frenchAccents[lowercased] {
            return preserveCase(original: word, corrected: corrected)
        }

        // Check for proper nouns
        if let properNoun = frenchProperNouns[lowercased] {
            return properNoun
        }

        return nil
    }

    /// Check if word should be capitalized (French proper nouns)
    static func shouldCapitalizeFrench(_ word: String) -> String? {
        let lowercased = word.lowercased()
        return frenchProperNouns[lowercased]
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

    // MARK: - French Accents Dictionary
    // Words typed without accents → correct form with accents

    private static let frenchAccents: [String: String] = [
        // Common verbs
        "etre": "être",
        "etes": "êtes",
        "etais": "étais",
        "etait": "était",
        "etaient": "étaient",
        "ete": "été",

        // Articles and pronouns
        "a": "à",  // "à" preposition (vs "a" = has)
        "ou": "où",  // "où" = where (vs "ou" = or)
        "ca": "ça",
        "deja": "déjà",

        // Common words with accents
        "tres": "très",
        "apres": "après",
        "pres": "près",
        "des": "dès",
        "bientot": "bientôt",
        "plutot": "plutôt",
        "tot": "tôt",
        "meme": "même",
        "fenetre": "fenêtre",
        "tete": "tête",
        "fete": "fête",
        "foret": "forêt",
        "arret": "arrêt",
        "interet": "intérêt",

        // Common nouns
        "ecole": "école",
        "eglise": "église",
        "hopital": "hôpital",
        "hotel": "hôtel",
        "ile": "île",
        "regle": "règle",
        "numero": "numéro",
        "telephone": "téléphone",
        "cafe": "café",
        "musee": "musée",
        "idee": "idée",
        "annee": "année",
        "journee": "journée",
        "soiree": "soirée",
        "matinee": "matinée",
        "entree": "entrée",
        "arrivee": "arrivée",
        "pensee": "pensée",
        "epoque": "époque",
        "etat": "état",
        "etude": "étude",
        "etudiant": "étudiant",
        "etudiante": "étudiante",

        // Common adjectives
        "general": "général",
        "generale": "générale",
        "special": "spécial",
        "speciale": "spéciale",
        "different": "différent",
        "differente": "différente",
        "prefere": "préféré",
        "preferee": "préférée",
        "interesse": "intéressé",
        "interessant": "intéressant",
        "necessaire": "nécessaire",
        "celebre": "célèbre",
        "etranger": "étranger",
        "etrangere": "étrangère",

        // Common adverbs
        "deja": "déjà",
        "peut-etre": "peut-être",
        "evidemment": "évidemment",
        "generalement": "généralement",
        "immediatement": "immédiatement",
        "particulierement": "particulièrement",
        "regulierement": "régulièrement",

        // Days of the week (no accents needed in French)
        // Months (no accents needed in French)

        // Other common words
        "reponse": "réponse",
        "question": "question",
        "probleme": "problème",
        "systeme": "système",
        "theme": "thème",
        "poeme": "poème",
        "scene": "scène",
        "pere": "père",
        "mere": "mère",
        "frere": "frère",
        "derniere": "dernière",
        "premiere": "première",
        "deuxieme": "deuxième",
        "troisieme": "troisième",
        "quatrieme": "quatrième",
        "cinquieme": "cinquième",
    ]

    // MARK: - French Proper Nouns

    private static let frenchProperNouns: [String: String] = [
        // French cities
        "paris": "Paris",
        "marseille": "Marseille",
        "lyon": "Lyon",
        "toulouse": "Toulouse",
        "nice": "Nice",
        "nantes": "Nantes",
        "strasbourg": "Strasbourg",
        "montpellier": "Montpellier",
        "bordeaux": "Bordeaux",
        "lille": "Lille",
        "rennes": "Rennes",
        "reims": "Reims",
        "orleans": "Orléans",
        "grenoble": "Grenoble",

        // Regions
        "ile-de-france": "Île-de-France",
        "bretagne": "Bretagne",
        "normandie": "Normandie",
        "provence": "Provence",
        "cote d'azur": "Côte d'Azur",
        "alsace": "Alsace",
        "bourgogne": "Bourgogne",

        // Countries
        "france": "France",
        "belgique": "Belgique",
        "suisse": "Suisse",
        "canada": "Canada",
        "quebec": "Québec",
        "senegal": "Sénégal",
        "cote d'ivoire": "Côte d'Ivoire",
        "algerie": "Algérie",
        "maroc": "Maroc",
        "tunisie": "Tunisie",
    ]
}
