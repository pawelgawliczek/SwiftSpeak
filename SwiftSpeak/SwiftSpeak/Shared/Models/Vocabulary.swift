//
//  Vocabulary.swift
//  SwiftSpeak
//
//  Vocabulary and custom template models
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation
import SwiftUI

// MARK: - Custom Template (LEGACY - No UI, kept for data compatibility)
// NOTE: CustomTemplate is legacy code kept for backwards compatibility with existing user data.
// New features should use Power Modes instead. Do not add new functionality to this type.
struct CustomTemplate: Codable, Identifiable {
    let id: UUID
    var name: String
    var prompt: String
    var icon: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        prompt: String,
        icon: String = "doc.text",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.icon = icon
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Vocabulary Entry
struct VocabularyEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var recognizedWord: String      // What the STT might produce (e.g., "john doe")
    var replacementWord: String     // What to replace it with (e.g., "John Doe")
    var category: VocabularyCategory
    var isEnabled: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        recognizedWord: String,
        replacementWord: String,
        category: VocabularyCategory = .name,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.recognizedWord = recognizedWord.lowercased()
        self.replacementWord = replacementWord
        self.category = category
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Sample entries for preview
    static let samples: [VocabularyEntry] = [
        VocabularyEntry(recognizedWord: "john doe", replacementWord: "John Doe", category: .name),
        VocabularyEntry(recognizedWord: "acme corp", replacementWord: "ACME Corp.", category: .company),
        VocabularyEntry(recognizedWord: "asap", replacementWord: "ASAP", category: .acronym),
        VocabularyEntry(recognizedWord: "gonna", replacementWord: "going to", category: .slang)
    ]
}

// MARK: - Vocabulary Category
enum VocabularyCategory: String, Codable, CaseIterable, Identifiable {
    case name = "name"
    case company = "company"
    case acronym = "acronym"
    case slang = "slang"
    case technical = "technical"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .name: return "Name"
        case .company: return "Company"
        case .acronym: return "Acronym"
        case .slang: return "Slang"
        case .technical: return "Technical"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .name: return "person.fill"
        case .company: return "building.2.fill"
        case .acronym: return "textformat.abc"
        case .slang: return "bubble.left.fill"
        case .technical: return "wrench.fill"
        case .other: return "tag.fill"
        }
    }

    var color: Color {
        switch self {
        case .name: return .blue
        case .company: return .purple
        case .acronym: return .orange
        case .slang: return .pink
        case .technical: return .green
        case .other: return .gray
        }
    }
}
