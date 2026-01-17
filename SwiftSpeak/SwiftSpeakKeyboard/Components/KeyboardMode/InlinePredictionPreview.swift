//
//  InlinePredictionPreview.swift
//  SwiftSpeakKeyboard
//
//  Inline AI prediction preview showing ghost text continuation.
//  Users can tap or swipe through the prediction to accept words progressively.
//

import SwiftUI

/// Preview zone for inline AI predictions (ghost text)
/// Shows typed text + cursor + predicted continuation in ghost style
struct InlinePredictionPreview: View {
    /// The text already typed (tail, last ~30 chars)
    let typedText: String

    /// The AI-predicted continuation text
    let prediction: String

    /// Whether prediction is currently loading
    let isLoading: Bool

    /// Error message to display (if any)
    let errorMessage: String?

    /// Callback when user accepts words from the prediction
    /// - Parameter words: Array of words accepted (in order)
    let onAcceptWords: ([String]) -> Void

    /// Callback when prediction is dismissed
    let onDismiss: () -> Void

    // MARK: - State

    @State private var highlightedWordCount: Int = 0
    @State private var isDragging: Bool = false

    // MARK: - Computed

    /// Split prediction into words for progressive acceptance
    private var predictionWords: [String] {
        prediction.split(separator: " ").map { String($0) }
    }

    /// Display tail of typed text
    private var displayTypedText: String {
        let maxChars = 30
        if typedText.count > maxChars {
            return "..." + String(typedText.suffix(maxChars - 3))
        }
        return typedText
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Line 1: Typed text with cursor
            HStack(spacing: 0) {
                Text(displayTypedText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.primary)

                // Cursor indicator
                Rectangle()
                    .fill(KeyboardTheme.accent)
                    .frame(width: 2, height: 18)
                    .opacity(isLoading ? 0.3 : 1.0)

                Spacer()

                // Dismiss button
                Button(action: {
                    KeyboardHaptics.lightTap()
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(4)
                }
                .buttonStyle(.plain)
            }

            // Line 2: Prediction or error or loading
            if let error = errorMessage, !error.isEmpty {
                errorView(message: error)
            } else if isLoading {
                loadingView
            } else if !prediction.isEmpty {
                predictionTextView
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - Subviews

    private var loadingView: some View {
        HStack(spacing: 4) {
            Text(" ")  // Spacer for cursor
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.5)))
                .scaleEffect(0.7)
            Text("Predicting...")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func errorView(message: String) -> some View {
        HStack(spacing: 4) {
            Text(" ")  // Spacer for cursor
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.orange.opacity(0.8))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.orange.opacity(0.7))
                .lineLimit(1)
        }
    }

    private var predictionTextView: some View {
        // Build attributed text showing highlighted vs non-highlighted words
        VStack(alignment: .leading, spacing: 0) {
            // Use Text with attributed string to show highlighting during swipe
            highlightedPredictionText
                .font(.system(size: 14))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Accept the full prediction
            KeyboardHaptics.mediumTap()
            acceptWordsUpTo(index: predictionWords.count - 1)
        }
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    isDragging = true
                    // Calculate which words to accept based on horizontal drag distance
                    let progress = max(0, value.translation.width / 50)  // ~50pt per word
                    let newCount = min(predictionWords.count, Int(progress) + 1)
                    if newCount != highlightedWordCount {
                        highlightedWordCount = newCount
                        KeyboardHaptics.selection()  // Haptic feedback as words are selected
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    if highlightedWordCount > 0 {
                        acceptWordsUpTo(index: highlightedWordCount - 1)
                    }
                    highlightedWordCount = 0
                }
        )
        .animation(.easeInOut(duration: 0.1), value: highlightedWordCount)
    }

    /// Build text with highlighted words shown in different style
    private var highlightedPredictionText: Text {
        var result = Text("")

        for (index, word) in predictionWords.enumerated() {
            let prefix = index == 0 ? "" : " "
            let isHighlighted = index < highlightedWordCount

            if isHighlighted {
                // Highlighted words: brighter, with underline
                result = result + Text(prefix + word)
                    .foregroundColor(.white.opacity(0.9))
                    .underline(true, color: .purple.opacity(0.8))
            } else {
                // Non-highlighted: ghost style
                result = result + Text(prefix + word)
                    .foregroundColor(.white.opacity(0.4))
            }
        }

        return result
    }

    // MARK: - Actions

    private func acceptWordsUpTo(index: Int) {
        let acceptedWords = Array(predictionWords.prefix(index + 1))
        KeyboardHaptics.mediumTap()
        onAcceptWords(acceptedWords)

        // Reset state
        highlightedWordCount = 0
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // Normal state
        InlinePredictionPreview(
            typedText: "Hey, I wanted to ask if you",
            prediction: "could come to the meeting tomorrow afternoon",
            isLoading: false,
            errorMessage: nil,
            onAcceptWords: { words in
                print("Accepted: \(words)")
            },
            onDismiss: {
                print("Dismissed")
            }
        )

        // Loading state
        InlinePredictionPreview(
            typedText: "Let me know when",
            prediction: "",
            isLoading: true,
            errorMessage: nil,
            onAcceptWords: { _ in },
            onDismiss: { }
        )

        // Error state
        InlinePredictionPreview(
            typedText: "Hi",
            prediction: "",
            isLoading: false,
            errorMessage: "Add OpenAI in Settings to enable predictions",
            onAcceptWords: { _ in },
            onDismiss: { }
        )

        // Short typed text
        InlinePredictionPreview(
            typedText: "Hi",
            prediction: "there! How are you doing today?",
            isLoading: false,
            errorMessage: nil,
            onAcceptWords: { _ in },
            onDismiss: { }
        )
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
