//
//  PredictionModels.swift
//  SwiftSpeakKeyboard
//
//  Data models for AI predictions (Phase 13.6)
//

import Foundation

// MARK: - Prediction
struct Prediction: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let source: PredictionSource
    let confidence: Double

    init(text: String, source: PredictionSource, confidence: Double = 1.0) {
        self.text = text
        self.source = source
        self.confidence = confidence
    }

    static func == (lhs: Prediction, rhs: Prediction) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Prediction Source
enum PredictionSource {
    case local          // Based on vocabulary and typing context
    case vocabulary     // From custom vocabulary
    case frequent       // From recent/frequent words
    case llm            // From AI provider
}

// MARK: - Prediction Context
struct PredictionContext {
    let fullText: String
    let currentWord: String
    let previousWords: [String]
    let shouldUseLLM: Bool

    init(fullText: String, shouldUseLLM: Bool = false) {
        self.fullText = fullText
        self.shouldUseLLM = shouldUseLLM

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
