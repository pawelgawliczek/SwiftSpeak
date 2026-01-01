//
//  SwipeTypingEngine.swift
//  SwiftSpeakKeyboard
//
//  Phase 13.8: Swipe typing (glide) engine for tracking swipe paths and matching words
//

import SwiftUI
import Combine

// MARK: - Swipe Typing Engine
@MainActor
class SwipeTypingEngine: ObservableObject {
    @Published var isSwipeActive = false
    @Published var swipePath: [CGPoint] = []
    @Published var candidateWord: String = ""
    @Published var alternativeCandidates: [String] = []

    private var passedKeys: [String] = []
    private let dictionary: SwipeTypingDictionary

    init() {
        self.dictionary = SwipeTypingDictionary()
    }

    func startSwipe(at point: CGPoint, key: String) {
        isSwipeActive = true
        swipePath = [point]
        passedKeys = [key.lowercased()]
        updateCandidate()
        keyboardLog("Swipe started at key: \(key)", category: "SwipeTyping")
    }

    func continueSwipe(to point: CGPoint, nearestKey: String?) {
        guard isSwipeActive else { return }
        swipePath.append(point)

        if let key = nearestKey?.lowercased(),
           passedKeys.last != key {
            passedKeys.append(key)
            updateCandidate()

            // Light haptic when passing each new key
            KeyboardHaptics.lightTap()
        }
    }

    func endSwipe() -> String? {
        guard isSwipeActive else { return nil }

        isSwipeActive = false
        let result = candidateWord.isEmpty ? nil : candidateWord

        if result != nil {
            keyboardLog("Swipe completed: '\(result!)' from \(passedKeys.count) keys", category: "SwipeTyping")
            // Medium haptic when word is confirmed
            KeyboardHaptics.mediumTap()
        } else {
            keyboardLog("Swipe cancelled (no candidate)", category: "SwipeTyping")
        }

        reset()
        return result
    }

    func reset() {
        swipePath = []
        passedKeys = []
        candidateWord = ""
        alternativeCandidates = []
        isSwipeActive = false
    }

    private func updateCandidate() {
        // Convert passed keys to candidate word
        // Use dictionary to find best match
        let candidates = dictionary.findMatches(for: passedKeys)
        candidateWord = candidates.first ?? passedKeys.joined()
        alternativeCandidates = Array(candidates.dropFirst().prefix(2))
    }
}

// MARK: - Key Frame Preference
struct KeyFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
