//
//  SentencePredictionView.swift
//  SwiftSpeakKeyboard
//
//  AI-powered sentence prediction panel
//  Shows 4 sentence options for user to select
//

import SwiftUI

struct SentencePredictionView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("AI Suggestions")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button(action: {
                    KeyboardHaptics.lightTap()
                    onClose()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(white: 0.1))

            // Loading state
            if viewModel.isLoadingSentencePredictions {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)

                    Text("Generating suggestions...")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(white: 0.08))
            }
            // Error state
            else if let error = viewModel.sentencePredictionError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)

                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Button(action: {
                        KeyboardHaptics.lightTap()
                        onClose()
                    }) {
                        Text("Close")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(white: 0.08))
            }
            // Sentence options
            else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(viewModel.sentencePredictions.enumerated()), id: \.offset) { index, sentence in
                            SentenceOptionButton(
                                sentence: sentence,
                                index: index + 1,
                                action: {
                                    KeyboardHaptics.mediumTap()
                                    viewModel.insertSentencePrediction(sentence)
                                    onClose()
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
                .background(Color(white: 0.08))
            }
        }
    }
}

// MARK: - Sentence Option Button

private struct SentenceOptionButton: View {
    let sentence: String
    let index: Int
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                // Number badge
                Text("\(index)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(
                        LinearGradient(
                            colors: [.purple.opacity(0.8), .blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())

                // Sentence text
                Text(sentence)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)

                Spacer(minLength: 0)

                // Insert icon
                Image(systemName: "arrow.turn.down.left")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isPressed ? 0.15 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()

        SentencePredictionView(
            viewModel: {
                let vm = KeyboardViewModel()
                vm.sentencePredictions = [
                    "I'll be there in about 10 minutes.",
                    "Let me check my schedule and get back to you.",
                    "That sounds great! I'm looking forward to it.",
                    "I'm running a bit late, sorry for the delay."
                ]
                return vm
            }(),
            onClose: { print("Closed") }
        )
        .frame(height: 300)
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}
