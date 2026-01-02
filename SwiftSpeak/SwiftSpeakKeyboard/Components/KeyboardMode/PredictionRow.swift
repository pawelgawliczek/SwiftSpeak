//
//  PredictionRow.swift
//  SwiftSpeakKeyboard
//
//  AI prediction row with 3 suggestion slots (Phase 13.6)
//  Includes feedback loop for learning from user behavior
//

import SwiftUI

struct PredictionRow: View {
    @ObservedObject var viewModel: KeyboardViewModel
    @State private var predictions: [String] = []
    @State private var isLoadingLLM = false
    @State private var lastShownPredictions: [String] = []  // For feedback tracking
    @State private var previousWord: String? = nil  // For contextual feedback

    // Shared prediction engine instance
    private static let predictionEngine = PredictionEngine()

    // Debounce task for predictions
    @State private var predictionTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 0) {
            // Settings button on the left
            Button(action: {
                KeyboardHaptics.lightTap()
                viewModel.showQuickSettings = true
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Divider()
                .background(Color.white.opacity(0.1))

            ForEach(0..<3, id: \.self) { index in
                PredictionSlot(
                    text: index < predictions.count ? predictions[index] : "",
                    isLoading: isLoadingLLM && index == 0
                ) {
                    handlePredictionTap(predictions[index])
                }

                if index < 2 {
                    Divider()
                        .background(Color.white.opacity(0.1))
                }
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // AI Sentence Prediction button on the right
            Button(action: {
                KeyboardHaptics.lightTap()
                viewModel.triggerAISentencePrediction()
            }) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 36)
        .background(Color(white: 0.08))
        .onAppear {
            Task {
                await loadInitialPredictions()
            }
        }
        .onChange(of: viewModel.currentTypingContext) { _, newContext in
            // Debounce predictions - wait 150ms after typing stops
            updatePredictionsDebounced(for: newContext, useLLM: false)
        }
        .onChange(of: viewModel.shouldTriggerLLMPredictions) { _, shouldTrigger in
            if shouldTrigger {
                Task {
                    await updatePredictions(for: viewModel.currentTypingContext, useLLM: true)
                    viewModel.shouldTriggerLLMPredictions = false
                }
            }
        }
    }

    private func loadInitialPredictions() async {
        await updatePredictions(for: "", useLLM: false)
    }

    /// Debounced prediction update - waits for typing to pause
    private func updatePredictionsDebounced(for context: String, useLLM: Bool) {
        // Cancel previous pending prediction
        predictionTask?.cancel()

        // Create new debounced task
        predictionTask = Task {
            // Wait 150ms for typing to settle
            try? await Task.sleep(for: .milliseconds(150))

            // Check if cancelled (user typed another character)
            guard !Task.isCancelled else { return }

            await updatePredictions(for: context, useLLM: useLLM)
        }
    }

    private func updatePredictions(for context: String, useLLM: Bool) async {
        if useLLM {
            isLoadingLLM = true
        }

        // Extract previous word for feedback context
        let words = context.split(separator: " ").map(String.init)
        let prevWord = words.dropLast().last

        let predictionContext = PredictionContext(
            fullText: context,
            shouldUseLLM: useLLM
        )

        // Get active context name for context-aware predictions
        let activeContextName = viewModel.activeContext?.name

        let newPredictions = await Self.predictionEngine.getPredictions(
            for: predictionContext,
            activeContext: activeContextName
        )

        await MainActor.run {
            // Track what we're showing for feedback
            lastShownPredictions = predictions
            previousWord = prevWord

            predictions = newPredictions
            isLoadingLLM = false
        }
    }

    private func handlePredictionTap(_ text: String) {
        guard !text.isEmpty else { return }

        KeyboardHaptics.lightTap()

        // Record feedback - user accepted this prediction
        Task {
            await Self.predictionEngine.recordPredictionAccepted(text, previousWord: previousWord)
        }

        // Insert prediction with space
        viewModel.textDocumentProxy?.insertText(text + " ")

        // Update typing context
        viewModel.updateTypingContext()

        // Clear predictions momentarily
        let oldPredictions = predictions
        predictions = []

        // Load new predictions for next word
        Task {
            // Short delay to let context update
            try? await Task.sleep(for: .milliseconds(50))
            await updatePredictions(for: viewModel.currentTypingContext, useLLM: false)
        }

        // Record that other predictions were not selected (implicit rejection)
        let rejectedPredictions = oldPredictions.filter { $0 != text }
        if !rejectedPredictions.isEmpty {
            Task {
                await Self.predictionEngine.recordPredictionsRejected(
                    rejectedPredictions,
                    actuallyTyped: text,
                    previousWord: previousWord
                )
            }
        }
    }

    /// Call this when user types something without using predictions
    func recordUserTypedWord(_ word: String) {
        guard !lastShownPredictions.isEmpty else { return }

        // User typed something different from predictions
        if !lastShownPredictions.contains(where: { $0.lowercased() == word.lowercased() }) {
            Task {
                await Self.predictionEngine.recordPredictionsRejected(
                    lastShownPredictions,
                    actuallyTyped: word,
                    previousWord: previousWord
                )
            }
        }
    }
}

// MARK: - Prediction Slot
private struct PredictionSlot: View {
    let text: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    // Loading indicator
                    HStack(spacing: 2) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.white.opacity(0.5))
                                .frame(width: 4, height: 4)
                                .scaleEffect(isLoading ? 1.0 : 0.5)
                                .animation(
                                    Animation.easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                    value: isLoading
                                )
                        }
                    }
                } else {
                    Text(text.isEmpty ? " " : text)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(text.isEmpty ? .clear : .white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(text.isEmpty || isLoading)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 0) {
        // Empty prediction row (initial state)
        PredictionRow(viewModel: KeyboardViewModel())

        // Prediction row with suggestions
        HStack(spacing: 0) {
            ForEach(["Hello", "Thanks", "Meeting"], id: \.self) { text in
                Button(action: {}) {
                    Text(text)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(.plain)
                if text != "Meeting" {
                    Divider()
                        .background(Color.white.opacity(0.1))
                }
            }
        }
        .background(Color(white: 0.08))

        // Loading state
        HStack(spacing: 0) {
            ForEach(0..<3) { index in
                HStack(spacing: 2) {
                    ForEach(0..<3) { _ in
                        Circle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)

                if index < 2 {
                    Divider()
                        .background(Color.white.opacity(0.1))
                }
            }
        }
        .background(Color(white: 0.08))
    }
    .preferredColorScheme(.dark)
}
