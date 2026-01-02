//
//  PredictionRow.swift
//  SwiftSpeakKeyboard
//
//  AI prediction row with 3 suggestion slots (Phase 13.6)
//  Includes feedback loop for learning from user behavior
//  Supports autocorrect undo - shows original word when cursor is on corrected word
//

import SwiftUI

struct PredictionRow: View {
    @ObservedObject var viewModel: KeyboardViewModel
    @State private var predictions: [String] = []
    @State private var lastShownPredictions: [String] = []  // For feedback tracking
    @State private var previousWord: String? = nil  // For contextual feedback

    // Autocorrect undo state
    @State private var autocorrectUndoSuggestion: AutocorrectUndoSuggestion? = nil

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

            // Show autocorrect undo as first slot if available
            if let undoSuggestion = autocorrectUndoSuggestion {
                AutocorrectUndoSlot(suggestion: undoSuggestion) {
                    handleAutocorrectUndoTap(undoSuggestion)
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                // Show remaining 2 predictions
                ForEach(0..<2, id: \.self) { index in
                    PredictionSlot(
                        text: index < predictions.count ? predictions[index] : ""
                    ) {
                        if index < predictions.count {
                            handlePredictionTap(predictions[index])
                        }
                    }

                    if index < 1 {
                        Divider()
                            .background(Color.white.opacity(0.1))
                    }
                }
            } else {
                // Normal 3-slot predictions
                ForEach(0..<3, id: \.self) { index in
                    PredictionSlot(
                        text: index < predictions.count ? predictions[index] : ""
                    ) {
                        if index < predictions.count {
                            handlePredictionTap(predictions[index])
                        }
                    }

                    if index < 2 {
                        Divider()
                            .background(Color.white.opacity(0.1))
                    }
                }
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // AI Sentence Prediction button on the right
            Button(action: {
                keyboardLog("AI sparkles button tapped", category: "AI")
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
                    .contentShape(Rectangle())
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
            updatePredictionsDebounced(for: newContext)
        }
    }

    private func loadInitialPredictions() async {
        await updatePredictions(for: "")
    }

    /// Debounced prediction update - waits for typing to pause
    private func updatePredictionsDebounced(for context: String) {
        // Cancel previous pending prediction
        predictionTask?.cancel()

        // Create new debounced task
        predictionTask = Task {
            // Wait 150ms for typing to settle
            try? await Task.sleep(for: .milliseconds(150))

            // Check if cancelled (user typed another character)
            guard !Task.isCancelled else { return }

            await updatePredictions(for: context)
        }
    }

    private func updatePredictions(for context: String) async {
        // Extract previous word for feedback context
        let words = context.split(separator: " ").map(String.init)
        let prevWord = words.dropLast().last

        // Check for autocorrect undo opportunity
        // When cursor is at the end of a word, check if it was recently corrected
        let undoSuggestion = await checkForAutocorrectUndo(context: context)

        let predictionContext = PredictionContext(fullText: context)

        // Get active context name for context-aware predictions
        let activeContextName = viewModel.activeContext?.name

        // Load keyboard settings to get language
        let settings = KeyboardSettings.load()
        let language = settings.spokenLanguage  // Use spoken language for predictions

        let newPredictions = await Self.predictionEngine.getPredictions(
            for: predictionContext,
            activeContext: activeContextName,
            language: language
        )

        await MainActor.run {
            // Track what we're showing for feedback
            lastShownPredictions = predictions
            previousWord = prevWord

            predictions = newPredictions
            autocorrectUndoSuggestion = undoSuggestion
        }
    }

    /// Check if cursor is at/near a recently corrected word and offer undo
    private func checkForAutocorrectUndo(context: String) async -> AutocorrectUndoSuggestion? {
        // Get the word at or before the cursor
        let trimmed = context.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Extract the last word (the one the cursor is touching or just left)
        let words = trimmed.split(separator: " ", omittingEmptySubsequences: true)
        guard let lastWord = words.last else { return nil }

        // Clean the word of trailing punctuation for lookup
        let cleanWord = String(lastWord).trimmingCharacters(in: .punctuationCharacters)
        guard !cleanWord.isEmpty else { return nil }

        // Check if this word was recently corrected
        if let originalWord = await AutocorrectHistoryService.shared.getRecentCorrectionForUndo(correctedWord: cleanWord) {
            // Don't suggest if original is same as corrected (shouldn't happen but safety check)
            guard originalWord.lowercased() != cleanWord.lowercased() else { return nil }

            return AutocorrectUndoSuggestion(
                originalWord: originalWord,
                correctedWord: cleanWord
            )
        }

        return nil
    }

    /// Handle tap on autocorrect undo suggestion
    private func handleAutocorrectUndoTap(_ suggestion: AutocorrectUndoSuggestion) {
        guard let proxy = viewModel.textDocumentProxy else { return }

        KeyboardHaptics.mediumTap()
        keyboardLog("Autocorrect undo: '\(suggestion.correctedWord)' → '\(suggestion.originalWord)'", category: "Autocorrect")

        // Delete the corrected word and insert the original
        if let beforeText = proxy.documentContextBeforeInput {
            // Find the corrected word at the end
            var charsToDelete = 0
            for char in beforeText.reversed() {
                if char.isWhitespace {
                    break
                }
                charsToDelete += 1
            }

            // Delete the corrected word
            for _ in 0..<charsToDelete {
                proxy.deleteBackward()
            }
        }

        // Insert original word with space
        proxy.insertText(suggestion.originalWord + " ")

        // Learn from this: add original to personal dictionary and ignore this correction
        Task {
            // Add to personal dictionary - user confirmed this word is correct
            await AutocorrectHistoryService.shared.addToPersonalDictionary(suggestion.originalWord)

            // Mark that this correction should be ignored in the future
            await AutocorrectHistoryService.shared.ignoreCorrection(
                original: suggestion.originalWord,
                correctedTo: suggestion.correctedWord
            )

            // Clear this correction from history
            await AutocorrectHistoryService.shared.clearCorrection(original: suggestion.originalWord)
        }

        // Clear the undo suggestion and update context
        autocorrectUndoSuggestion = nil
        viewModel.updateTypingContext()

        // Refresh predictions
        Task {
            try? await Task.sleep(for: .milliseconds(50))
            await updatePredictions(for: viewModel.currentTypingContext)
        }
    }

    private func handlePredictionTap(_ text: String) {
        guard !text.isEmpty else { return }
        guard let proxy = viewModel.textDocumentProxy else { return }

        KeyboardHaptics.lightTap()

        // Record feedback - user accepted this prediction
        Task {
            await Self.predictionEngine.recordPredictionAccepted(text, previousWord: previousWord)
        }

        // Delete the current partial word before inserting the prediction
        // This ensures clicking a prediction replaces what the user was typing
        if let beforeText = proxy.documentContextBeforeInput {
            // Find how many characters of the current word to delete
            // Go backwards until we hit a space, punctuation, or start of text
            var charsToDelete = 0
            for char in beforeText.reversed() {
                if char.isWhitespace || char.isPunctuation {
                    break
                }
                charsToDelete += 1
            }

            // Delete the partial word
            for _ in 0..<charsToDelete {
                proxy.deleteBackward()
            }
        }

        // Insert prediction with space
        proxy.insertText(text + " ")

        // Update typing context
        viewModel.updateTypingContext()

        // Clear predictions momentarily
        let oldPredictions = predictions
        predictions = []

        // Load new predictions for next word
        Task {
            // Short delay to let context update
            try? await Task.sleep(for: .milliseconds(50))
            await updatePredictions(for: viewModel.currentTypingContext)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text.isEmpty ? " " : text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(text.isEmpty ? .clear : .white.opacity(0.7))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(text.isEmpty)
    }
}

// MARK: - Autocorrect Undo Model

/// Represents an autocorrect undo suggestion
struct AutocorrectUndoSuggestion {
    let originalWord: String   // What user originally typed
    let correctedWord: String  // What it was autocorrected to
}

// MARK: - Autocorrect Undo Slot

/// Special prediction slot for autocorrect undo with distinct styling
private struct AutocorrectUndoSlot: View {
    let suggestion: AutocorrectUndoSuggestion
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                // Undo arrow icon
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.orange.opacity(0.8))

                // Original word with quotes to distinguish from corrections
                Text("\"\(suggestion.originalWord)\"")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.orange.opacity(0.9))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
