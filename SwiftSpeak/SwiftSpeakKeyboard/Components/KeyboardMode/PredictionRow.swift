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
    var settings: KeyboardSettings = KeyboardSettings()  // Phase 16: For programmable button
    var sizing: KeyboardSizing = KeyboardSizing(.normal)  // Dynamic sizing support
    @State private var predictions: [Prediction] = []
    @State private var lastShownPredictions: [Prediction] = []  // For feedback tracking
    @State private var previousWord: String? = nil  // For contextual feedback

    // Autocorrect undo state
    @State private var autocorrectUndoSuggestion: AutocorrectUndoSuggestion? = nil

    // Shared prediction engine instance
    private static let predictionEngine: PredictionEngine = {
        keyboardLog("PredictionRow: Creating static PredictionEngine", category: "Prediction")
        return PredictionEngine()
    }()

    // Debounce task for predictions
    @State private var predictionTask: Task<Void, Never>?

    /// Minimum width for each prediction slot
    private var minSlotWidth: CGFloat {
        sizing.isCompact ? 70 : 90
    }

    var body: some View {
        HStack(spacing: 0) {
            // Settings button on the left (fixed)
            Button(action: {
                KeyboardHaptics.lightTap()
                viewModel.showQuickSettings = true
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: sizing.isCompact ? 11 : 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .frame(width: sizing.predictionButtonSize, height: sizing.predictionButtonSize)
            }
            .buttonStyle(.plain)

            Divider()
                .background(Color.white.opacity(0.1))

            // Scrollable predictions area
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    // Show autocorrect undo as first item if available
                    if let undoSuggestion = autocorrectUndoSuggestion {
                        AutocorrectUndoSlot(suggestion: undoSuggestion, sizing: sizing) {
                            handleAutocorrectUndoTap(undoSuggestion)
                        }
                        .frame(minWidth: minSlotWidth)

                        if !predictions.isEmpty {
                            Divider()
                                .background(Color.white.opacity(0.1))
                        }
                    }

                    // All predictions
                    ForEach(Array(predictions.enumerated()), id: \.element.id) { index, prediction in
                        PredictionSlot(
                            prediction: prediction,
                            sizing: sizing
                        ) {
                            handlePredictionTap(prediction)
                        }
                        .frame(minWidth: minSlotWidth)

                        // Divider between predictions (not after last one)
                        if index < predictions.count - 1 {
                            Divider()
                                .background(Color.white.opacity(0.1))
                        }
                    }
                }
            }
            // Fade edges to hint at scrollability
            .mask(
                HStack(spacing: 0) {
                    // Left fade (subtle)
                    LinearGradient(
                        colors: [.clear, .black],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 8)

                    // Full visibility in the middle
                    Rectangle().fill(.black)

                    // Right fade (more prominent to indicate more content)
                    LinearGradient(
                        colors: [.black, .black.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: predictions.count > 3 ? 20 : 0)
                }
            )

            Divider()
                .background(Color.white.opacity(0.1))

            // Phase 16: Programmable button on the right (fixed)
            ProgrammableButton(
                action: settings.programmableAction,
                viewModel: viewModel,
                sizing: sizing
            )
        }
        .frame(height: sizing.predictionRowHeight)
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
        // Safety: Skip empty or very long contexts
        guard !context.isEmpty, context.count <= 5000 else {
            return nil
        }

        // Get the word at or before the cursor
        let trimmed = context.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Extract the last word (the one the cursor is touching or just left)
        let words = trimmed.split(separator: " ", omittingEmptySubsequences: true)
        guard let lastWord = words.last else { return nil }

        // Clean the word of trailing punctuation for lookup
        let cleanWord = String(lastWord).trimmingCharacters(in: .punctuationCharacters)
        guard !cleanWord.isEmpty, cleanWord.count <= 50 else { return nil }

        // Safety: Skip if the word has unusual characters
        guard cleanWord.allSatisfy({ $0.isLetter || $0 == "'" || $0 == "-" || $0 == "'" }) else {
            return nil
        }

        // Check if this word was recently corrected
        if let originalWord = await AutocorrectHistoryService.shared.getRecentCorrectionForUndo(correctedWord: cleanWord) {
            // Don't suggest if original is same as corrected (shouldn't happen but safety check)
            guard originalWord.lowercased() != cleanWord.lowercased() else { return nil }
            guard !originalWord.isEmpty, originalWord.count <= 50 else { return nil }

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
            let chars = Array(beforeText)
            var index = chars.count - 1

            // Step 1: Skip trailing whitespace (handles "word |" case)
            var trailingSpaces = 0
            while index >= 0 && chars[index].isWhitespace {
                trailingSpaces += 1
                index -= 1
            }

            // Step 2: Count word characters to delete
            var wordChars = 0
            while index >= 0 && !chars[index].isWhitespace {
                wordChars += 1
                index -= 1
            }

            // Total characters to delete = word + trailing spaces
            let charsToDelete = wordChars + trailingSpaces

            // Delete the corrected word (and trailing space if present)
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

    private func handlePredictionTap(_ prediction: Prediction) {
        guard !prediction.text.isEmpty else { return }
        guard let proxy = viewModel.textDocumentProxy else { return }

        KeyboardHaptics.lightTap()

        // Record feedback - user accepted this prediction
        Task {
            await Self.predictionEngine.recordPredictionAccepted(prediction.text, previousWord: previousWord)
        }

        // Behavior differs based on prediction type:
        // - Corrections: Replace the current (misspelled) word
        // - Predictions: Add to text (just insert, don't delete)
        if prediction.type == .correction {
            // CORRECTION: Delete the current word and replace with corrected word
            if let beforeText = proxy.documentContextBeforeInput {
                let chars = Array(beforeText)
                var index = chars.count - 1

                // Step 1: Skip trailing whitespace (handles "word |" case)
                var trailingSpaces = 0
                while index >= 0 && chars[index].isWhitespace {
                    trailingSpaces += 1
                    index -= 1
                }

                // Step 2: Count word characters to delete
                var wordChars = 0
                while index >= 0 && !chars[index].isWhitespace && !chars[index].isPunctuation {
                    wordChars += 1
                    index -= 1
                }

                // Total characters to delete = word + trailing spaces
                let charsToDelete = wordChars + trailingSpaces

                // Delete the misspelled word
                for _ in 0..<charsToDelete {
                    proxy.deleteBackward()
                }
            }
        } else {
            // PREDICTION: Only delete partial word being typed (not previous completed words)
            // This allows predictions to complete the current word or add next word
            if let beforeText = proxy.documentContextBeforeInput,
               !beforeText.isEmpty,
               !beforeText.hasSuffix(" ") {
                // User is typing a partial word - delete it to complete with prediction
                let chars = Array(beforeText)
                var index = chars.count - 1

                // Count word characters to delete (no trailing spaces here)
                var wordChars = 0
                while index >= 0 && !chars[index].isWhitespace && !chars[index].isPunctuation {
                    wordChars += 1
                    index -= 1
                }

                // Delete only the partial word
                for _ in 0..<wordChars {
                    proxy.deleteBackward()
                }
            }
            // If text ends with space, don't delete anything - just add the prediction
        }

        // Insert prediction with space
        proxy.insertText(prediction.text + " ")

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
        let rejectedPredictions = oldPredictions.filter { $0.text != prediction.text }
        if !rejectedPredictions.isEmpty {
            Task {
                await Self.predictionEngine.recordPredictionsRejected(
                    rejectedPredictions.map(\.text),
                    actuallyTyped: prediction.text,
                    previousWord: previousWord
                )
            }
        }
    }

    /// Call this when user types something without using predictions
    func recordUserTypedWord(_ word: String) {
        guard !lastShownPredictions.isEmpty else { return }

        // User typed something different from predictions
        if !lastShownPredictions.contains(where: { $0.text.lowercased() == word.lowercased() }) {
            Task {
                await Self.predictionEngine.recordPredictionsRejected(
                    lastShownPredictions.map(\.text),
                    actuallyTyped: word,
                    previousWord: previousWord
                )
            }
        }
    }
}

// MARK: - Prediction Slot
private struct PredictionSlot: View {
    let prediction: Prediction?
    var sizing: KeyboardSizing = KeyboardSizing(.normal)
    let action: () -> Void

    /// Text to display
    private var displayText: String {
        prediction?.text ?? ""
    }

    /// Whether this slot is empty
    private var isEmpty: Bool {
        displayText.isEmpty
    }

    /// Whether this is a spelling correction (not a prediction)
    private var isCorrection: Bool {
        prediction?.type == .correction
    }

    /// Background color based on prediction type
    private var backgroundColor: Color {
        guard !isEmpty else { return .clear }

        if isCorrection {
            // Subtle blue/cyan background for spelling corrections
            return Color(red: 0.2, green: 0.5, blue: 0.7).opacity(0.25)
        } else {
            // No background for regular predictions
            return .clear
        }
    }

    /// Text color based on prediction type
    private var textColor: Color {
        guard !isEmpty else { return .clear }

        if isCorrection {
            // Slightly brighter text for corrections to stand out
            return Color(red: 0.6, green: 0.85, blue: 1.0)
        } else {
            return .white.opacity(0.7)
        }
    }

    var body: some View {
        Button(action: action) {
            Text(isEmpty ? " " : displayText)
                .font(.system(size: sizing.predictionFontSize, weight: isCorrection ? .medium : .regular))
                .foregroundStyle(textColor)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: sizing.predictionRowHeight)
                .background(backgroundColor)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isEmpty)
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
    var sizing: KeyboardSizing = KeyboardSizing(.normal)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: sizing.isCompact ? 2 : 4) {
                // Undo arrow icon
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: sizing.isCompact ? 8 : 10, weight: .medium))
                    .foregroundStyle(Color.orange.opacity(0.8))

                // Original word with quotes to distinguish from corrections
                Text("\"\(suggestion.originalWord)\"")
                    .font(.system(size: sizing.predictionFontSize, weight: .medium))
                    .foregroundStyle(Color.orange.opacity(0.9))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: sizing.predictionRowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Programmable Button (Phase 16)

/// Programmable button that can be assigned different actions
private struct ProgrammableButton: View {
    let action: ProgrammableButtonAction
    @ObservedObject var viewModel: KeyboardViewModel
    var sizing: KeyboardSizing = KeyboardSizing(.normal)

    var body: some View {
        Button(action: {
            KeyboardHaptics.lightTap()
            executeAction()
        }) {
            buttonContent
                .frame(width: sizing.predictionButtonSize, height: sizing.predictionButtonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var buttonContent: some View {
        switch action {
        case .transcribe:
            // Use SwiftSpeak logo for transcribe
            SwiftSpeakLogoView()
                .frame(width: sizing.isCompact ? 14 : 20, height: sizing.isCompact ? 14 : 20)
                .foregroundStyle(iconGradient)
        default:
            Image(systemName: action.iconName)
                .font(.system(size: sizing.isCompact ? 11 : 14, weight: .medium))
                .foregroundStyle(iconGradient)
        }
    }

    private var iconGradient: some ShapeStyle {
        switch action {
        case .aiSparkles:
            return AnyShapeStyle(LinearGradient(
                colors: [.purple, .blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        case .transcribe:
            return AnyShapeStyle(LinearGradient(
                colors: [KeyboardTheme.accent, KeyboardTheme.accent.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        case .translate:
            return AnyShapeStyle(LinearGradient(
                colors: [.green, .teal],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        case .aiFormat:
            return AnyShapeStyle(LinearGradient(
                colors: [.orange, .yellow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        }
    }

    private func executeAction() {
        switch action {
        case .aiSparkles:
            keyboardLog("Programmable button: AI sparkles", category: "AI")
            viewModel.triggerAISentencePrediction()
        case .transcribe:
            keyboardLog("Programmable button: Transcribe", category: "Transcription")
            viewModel.startTranscription()
        case .translate:
            keyboardLog("Programmable button: Translate", category: "Translation")
            // Enable translation and start transcription
            viewModel.startTranslation()
            viewModel.startTranscription()
        case .aiFormat:
            keyboardLog("Programmable button: AI Format", category: "AI")
            viewModel.processTextWithAI()
        }
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
