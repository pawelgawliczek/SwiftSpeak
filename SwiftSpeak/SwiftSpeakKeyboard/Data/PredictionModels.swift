//
//  PredictionModels.swift
//  SwiftSpeakKeyboard
//
//  Data models for AI predictions (Phase 13.6)
//

import Foundation

// MARK: - Prediction Type

/// Type of prediction for visual differentiation in the UI
enum PredictionType: Equatable {
    /// Spelling correction for a misspelled word
    case correction
    /// Word completion or next-word prediction
    case prediction
}

// MARK: - Prediction
struct Prediction: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let source: PredictionSource
    let confidence: Double
    let type: PredictionType
    let score: Double

    init(text: String, source: PredictionSource = .local, confidence: Double = 1.0, type: PredictionType = .prediction, score: Double = 0) {
        self.text = text
        self.source = source
        self.confidence = confidence
        self.type = type
        self.score = score
    }

    static func == (lhs: Prediction, rhs: Prediction) -> Bool {
        lhs.id == rhs.id
    }

    /// Convenience for creating a correction
    static func correction(_ text: String, score: Double = 0) -> Prediction {
        Prediction(text: text, type: .correction, score: score)
    }

    /// Convenience for creating a prediction
    static func prediction(_ text: String, score: Double = 0) -> Prediction {
        Prediction(text: text, type: .prediction, score: score)
    }
}

// MARK: - Prediction Source
enum PredictionSource {
    case local          // Based on vocabulary and typing context
    case vocabulary     // From custom vocabulary
    case frequent       // From recent/frequent words
    case context        // From context-aware predictions
    case ai             // From AI/LLM word predictions
}

// MARK: - Prediction Context
struct PredictionContext {
    let fullText: String
    let currentWord: String
    let previousWords: [String]

    init(fullText: String) {
        self.fullText = fullText

        // Extract current word being typed
        let words = fullText.split(separator: " ").map(String.init)
        if fullText.hasSuffix(" ") {
            self.currentWord = ""
            self.previousWords = words
        } else {
            self.currentWord = words.last ?? ""
            self.previousWords = words.dropLast()
        }
    }
}
