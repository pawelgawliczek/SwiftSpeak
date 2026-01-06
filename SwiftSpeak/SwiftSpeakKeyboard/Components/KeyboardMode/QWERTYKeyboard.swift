//
//  QWERTYKeyboard.swift
//  SwiftSpeakKeyboard
//
//  Main QWERTY keyboard view assembling all key components
//

import SwiftUI
import UIKit

// MARK: - QWERTY Keyboard
struct QWERTYKeyboard: View {
    let textDocumentProxy: UITextDocumentProxy?
    let onNextKeyboard: () -> Void
    var viewModel: KeyboardViewModel?  // Phase 13.6: For predictions

    @State private var shiftState: ShiftState = .lowercase
    @State private var layoutState: KeyboardLayoutState = .letters

    // Accent popup state
    @State private var showingAccentPopup: Bool = false
    @State private var accentPopupLetter: String = ""
    @State private var accentPopupKeyFrame: CGRect = .zero
    @State private var keyboardFrame: CGRect = .zero  // Track keyboard frame for accent popup

    // Auto-capitalization tracking - uses AutoCapitalizationService
    private var shouldAutoCapitalize: Bool {
        guard let proxy = textDocumentProxy else { return false }
        let before = proxy.documentContextBeforeInput
        return AutoCapitalizationService.shouldCapitalize(contextBefore: before)
    }

    var body: some View {
        VStack(spacing: KeyboardTheme.rowSpacing) {
            if layoutState == .letters {
                letterLayout
            } else {
                numberSymbolLayout
            }

            bottomRow
        }
        .padding(.horizontal, KeyboardTheme.horizontalPadding)
        .padding(.vertical, 4)
        .background(
            GeometryReader { geometry in
                KeyboardTheme.keyboardBackground
                    .onAppear {
                        keyboardFrame = geometry.frame(in: .global)
                    }
                    .onChange(of: geometry.frame(in: .global)) { _, newFrame in
                        keyboardFrame = newFrame
                    }
            }
        )
        .onAppear {
            // Auto-shift on keyboard appear if at start of text or after sentence
            checkAutoShift()
        }
        .onChange(of: textDocumentProxy?.documentContextBeforeInput) { _, _ in
            // Auto-shift when context changes
            checkAutoShift()
        }
        // Accent popup as true overlay - floats above everything
        .overlay {
            if showingAccentPopup, let accents = AccentMappings.popupFor(accentPopupLetter) {
                AccentPopup(
                    accents: accents,
                    keyFrame: accentPopupKeyFrame,
                    shiftState: shiftState,
                    onSelect: { accent in
                        // Insert directly without auto-return (popup selections stay on current layout)
                        textDocumentProxy?.insertText(accent)
                        viewModel?.updateTypingContext()
                        showingAccentPopup = false
                    },
                    onCancel: {
                        showingAccentPopup = false
                    },
                    keyboardFrame: keyboardFrame
                )
                .transition(.opacity)
            }
        }
    }

    // MARK: - Letter Layout

    private var letterLayout: some View {
        VStack(spacing: KeyboardTheme.rowSpacing) {
            // Row 1: Q W E R T Y U I O P
            HStack(spacing: KeyboardTheme.keySpacing) {
                ForEach(KeyboardLayout.qwertyRow1, id: \.self) { key in
                    let displayKey = shouldUppercase ? key : key.lowercased()
                    LetterKey(
                        letter: displayKey,
                        shiftState: shiftState,
                        action: {
                            insertText(displayKey)
                            afterLetterInsert()
                        },
                        onShowAccentPopup: { letter, frame in
                            showAccentPopup(for: letter, at: frame)
                        }
                    )
                }
            }

            // Row 2: A S D F G H J K L (centered)
            HStack(spacing: KeyboardTheme.keySpacing) {
                ForEach(KeyboardLayout.qwertyRow2, id: \.self) { key in
                    let displayKey = shouldUppercase ? key : key.lowercased()
                    LetterKey(
                        letter: displayKey,
                        shiftState: shiftState,
                        action: {
                            insertText(displayKey)
                            afterLetterInsert()
                        },
                        onShowAccentPopup: { letter, frame in
                            showAccentPopup(for: letter, at: frame)
                        }
                    )
                }
            }
            .padding(.horizontal, 18) // Center middle row

            // Row 3: Shift + Z X C V B N M + Backspace
            HStack(spacing: KeyboardTheme.keySpacing) {
                // Shift key
                ActionKey(
                    icon: shiftIconName,
                    isHighlighted: shiftState != .lowercase
                ) {
                    handleShiftTap()
                }
                .frame(width: 42)

                ForEach(KeyboardLayout.qwertyRow3, id: \.self) { key in
                    let displayKey = shouldUppercase ? key : key.lowercased()
                    LetterKey(
                        letter: displayKey,
                        shiftState: shiftState,
                        action: {
                            insertText(displayKey)
                            afterLetterInsert()
                        },
                        onShowAccentPopup: { letter, frame in
                            showAccentPopup(for: letter, at: frame)
                        }
                    )
                }

                // Backspace key with long-press repeat and swipe-delete
                ActionKey(
                    icon: "delete.left",
                    action: { deleteBackward() },
                    onSwipeDelete: { wordCount in deleteWords(count: wordCount) },
                    enableLongPressRepeat: true
                )
                .frame(width: 42)
            }
        }
    }

    // MARK: - Number/Symbol Layout

    // Characters that should auto-return to letters keyboard after insertion
    private let autoReturnCharacters: Set<Character> = [
        ".", ",", "!", "?", ";", ":", "'", "\"", ")", "]", "}"
    ]

    private var numberSymbolLayout: some View {
        let rows = layoutState == .symbols ? symbolRows : numberRows

        return VStack(spacing: KeyboardTheme.rowSpacing) {
            // Row 1: Numbers (have fraction popups) or symbols
            HStack(spacing: KeyboardTheme.keySpacing) {
                ForEach(rows.0, id: \.self) { key in
                    LetterKey(
                        letter: key,
                        shiftState: shiftState,
                        action: {
                            insertTextAndMaybeReturnToLetters(key)
                        },
                        onShowAccentPopup: AccentMappings.hasPopup(key) ? { letter, frame in
                            showAccentPopup(for: letter, at: frame)
                        } : nil
                    )
                }
            }

            // Row 2: More characters ($ has currency popup)
            HStack(spacing: KeyboardTheme.keySpacing) {
                ForEach(rows.1, id: \.self) { key in
                    LetterKey(
                        letter: key,
                        shiftState: shiftState,
                        action: {
                            insertTextAndMaybeReturnToLetters(key)
                        },
                        onShowAccentPopup: AccentMappings.hasPopup(key) ? { letter, frame in
                            showAccentPopup(for: letter, at: frame)
                        } : nil
                    )
                }
            }

            // Row 3: Symbol toggle + punctuation (. has punctuation popup) + backspace
            HStack(spacing: KeyboardTheme.keySpacing) {
                // Symbol/Number toggle
                ActionKey(text: layoutState == .symbols ? "123" : "#+=") {
                    toggleSymbols()
                }
                .frame(width: 42)

                ForEach(rows.2, id: \.self) { key in
                    LetterKey(
                        letter: key,
                        shiftState: shiftState,
                        action: {
                            insertTextAndMaybeReturnToLetters(key)
                        },
                        onShowAccentPopup: AccentMappings.hasPopup(key) ? { letter, frame in
                            showAccentPopup(for: letter, at: frame)
                        } : nil
                    )
                }

                // Backspace key with long-press repeat and swipe-delete
                ActionKey(
                    icon: "delete.left",
                    action: { deleteBackward() },
                    onSwipeDelete: { wordCount in deleteWords(count: wordCount) },
                    enableLongPressRepeat: true
                )
                .frame(width: 42)
            }
        }
    }

    // MARK: - Bottom Row

    private var bottomRow: some View {
        HStack(spacing: KeyboardTheme.keySpacing) {
            // 123/ABC toggle - slightly bigger for easier access
            ActionKey(text: layoutState == .letters ? "123" : "ABC") {
                toggleLayout()
            }
            .frame(width: 58)

            // Emoji button
            ActionKey(icon: "face.smiling") {
                KeyboardHaptics.lightTap()
                viewModel?.showEmojiPanel = true
            }
            .frame(width: 42)

            // Space bar (Phase 13.5: with cursor control)
            SpaceBar(
                action: {
                    insertText(" ")
                },
                textDocumentProxy: textDocumentProxy
            )

            // Return key - Phase 13.11: Check for context processing
            ActionKey(text: "return") {
                // Check if context wants to process on Enter
                if viewModel?.handleReturnKey() == true {
                    // Context handled the return key (with AI processing or special behavior)
                    KeyboardHaptics.mediumTap()
                } else {
                    // Normal return key behavior
                    insertText("\n")
                    KeyboardHaptics.mediumTap()
                }
            }
            .frame(width: 95)
        }
    }

    // MARK: - Helper Properties

    private var shouldUppercase: Bool {
        shiftState == .shift || shiftState == .capsLock
    }

    private var shiftIconName: String {
        switch shiftState {
        case .lowercase:
            return "shift"
        case .shift:
            return "shift.fill"
        case .capsLock:
            return "capslock.fill"
        }
    }

    private var numberRows: ([String], [String], [String]) {
        (KeyboardLayout.numbersRow1, KeyboardLayout.numbersRow2, KeyboardLayout.numbersRow3)
    }

    private var symbolRows: ([String], [String], [String]) {
        (KeyboardLayout.symbolsRow1, KeyboardLayout.symbolsRow2, KeyboardLayout.symbolsRow3)
    }

    // MARK: - Actions

    /// Insert text and automatically return to letters keyboard if it's a punctuation character
    private func insertTextAndMaybeReturnToLetters(_ text: String) {
        insertText(text)

        // Auto-return to letters keyboard after punctuation
        if let char = text.first, autoReturnCharacters.contains(char) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                layoutState = .letters
            }
        }
    }

    private func insertText(_ text: String) {
        guard let proxy = textDocumentProxy else { return }
        let contextBefore = proxy.documentContextBeforeInput

        // Autocorrect on space/punctuation - using minimal version to avoid hangs
        if text == " " || text == "." || text == "," || text == "!" || text == "?" {
            performAutocorrectThenInsert(text, proxy: proxy, contextBefore: contextBefore)
            return
        }

        // Apply smart punctuation if enabled
        if smartPunctuationEnabled {
            // Handle double space → period
            if text == " " {
                if let result = SmartPunctuationService.handleDoubleSpace(contextBefore: contextBefore) {
                    if result.shouldDeleteSpace {
                        proxy.deleteBackward()
                    }
                    proxy.insertText(result.text)
                    viewModel?.updateTypingContext()
                    return
                }
            }

            // Handle smart quotes
            if text == "\"" || text == "'" {
                let smartQuote = SmartPunctuationService.smartQuote(for: text, contextBefore: contextBefore)
                proxy.insertText(smartQuote)
                viewModel?.updateTypingContext()
                return
            }

            // Handle dash → em dash (when typing second -)
            if text == "-" {
                if let result = SmartPunctuationService.handleDash(contextBefore: contextBefore) {
                    for _ in 0..<result.deleteCount {
                        proxy.deleteBackward()
                    }
                    proxy.insertText(result.text)
                    viewModel?.updateTypingContext()
                    return
                }
            }

            // Handle ellipsis (when typing third .)
            if text == "." {
                if let result = SmartPunctuationService.handleEllipsis(contextBefore: contextBefore) {
                    for _ in 0..<result.deleteCount {
                        proxy.deleteBackward()
                    }
                    proxy.insertText(result.text)
                    viewModel?.updateTypingContext()
                    return
                }
            }
        }

        proxy.insertText(text)
        // Phase 13.6: Update typing context after inserting text
        viewModel?.updateTypingContext()
    }

    /// Check if autocorrect is enabled
    private var autocorrectEnabled: Bool {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        return (defaults?.object(forKey: "keyboardAutocorrect") as? Bool) ?? true
    }

    /// Check if smart punctuation is enabled
    private var smartPunctuationEnabled: Bool {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        return (defaults?.object(forKey: "keyboardSmartPunctuation") as? Bool) ?? true
    }

    /// Current autocorrect language (syncs with spoken language setting)
    private var autocorrectLanguage: String {
        let settings = KeyboardSettings.load()
        // Always sync with spoken language
        return settings.spokenLanguage
    }

    /// Perform autocorrection on the last typed word, then insert the triggering character
    private func performAutocorrectThenInsert(_ text: String, proxy: UITextDocumentProxy, contextBefore: String?) {
        guard let beforeText = contextBefore else {
            proxy.insertText(text)
            viewModel?.updateTypingContext()
            return
        }

        // Safety: Skip very long context
        guard beforeText.count <= 10000 else {
            proxy.insertText(text)
            viewModel?.updateTypingContext()
            return
        }

        // Find the last word
        let words = beforeText.split(separator: " ", omittingEmptySubsequences: true)
        guard let lastWord = words.last else {
            proxy.insertText(text)
            viewModel?.updateTypingContext()
            return
        }

        let wordString = String(lastWord)

        // Special case: handle "i" → "I" (English only)
        if wordString.lowercased() == "i" && wordString.count == 1 {
            proxy.deleteBackward()
            proxy.insertText("I")
            KeyboardHaptics.lightTap()
            proxy.insertText(text)
            viewModel?.updateTypingContext()
            return
        }

        // Skip autocorrect if word is too short or contains numbers
        guard wordString.count >= 2,
              !wordString.contains(where: { $0.isNumber }),
              wordString.allSatisfy({ $0.isLetter || $0 == "'" || $0 == "-" || $0 == "'" }) else {
            proxy.insertText(text)
            viewModel?.updateTypingContext()
            return
        }

        // Use SpellChecker (static functions, no singleton hang)
        let currentLang = autocorrectLanguage
        if let correction = SpellChecker.correctWord(wordString, language: currentLang),
           correction != wordString {

            // Check personal dictionary and ignored corrections (synchronous from cache)
            if AutocorrectCache.isInPersonalDictionary(wordString) {
                // Word is in personal dictionary - don't correct
                proxy.insertText(text)
                viewModel?.updateTypingContext()
                return
            }

            if AutocorrectCache.shouldIgnoreCorrection(original: wordString, correctedTo: correction) {
                // User previously undid this correction - don't apply
                proxy.insertText(text)
                viewModel?.updateTypingContext()
                return
            }

            // Apply correction
            for _ in 0..<wordString.count {
                proxy.deleteBackward()
            }
            proxy.insertText(correction)
            KeyboardHaptics.lightTap()

            // Record correction for undo functionality (async is fine here)
            let position = beforeText.count
            Task {
                await AutocorrectHistoryService.shared.recordCorrection(
                    original: wordString,
                    corrected: correction,
                    atPosition: position
                )
            }
        }

        proxy.insertText(text)
        viewModel?.updateTypingContext()
    }

    /// Insert text with smart punctuation applied
    private func insertTextWithSmartPunctuation(_ text: String, proxy: UITextDocumentProxy, contextBefore: String?) {
        if smartPunctuationEnabled {
            // Handle double space → period
            if text == " " {
                if let result = SmartPunctuationService.handleDoubleSpace(contextBefore: contextBefore) {
                    if result.shouldDeleteSpace {
                        proxy.deleteBackward()
                    }
                    proxy.insertText(result.text)
                    viewModel?.updateTypingContext()
                    return
                }
            }

            // Handle ellipsis (when typing third .)
            if text == "." {
                if let result = SmartPunctuationService.handleEllipsis(contextBefore: contextBefore) {
                    for _ in 0..<result.deleteCount {
                        proxy.deleteBackward()
                    }
                    proxy.insertText(result.text)
                    viewModel?.updateTypingContext()
                    return
                }
            }
        }

        proxy.insertText(text)
        viewModel?.updateTypingContext()
    }

    private func deleteBackward() {
        // Capture deleted character for undo stack
        if let proxy = textDocumentProxy,
           let beforeText = proxy.documentContextBeforeInput,
           !beforeText.isEmpty {
            let deletedChar = String(beforeText.suffix(1))
            viewModel?.pushToUndoStack(deletedChar)
        }

        textDocumentProxy?.deleteBackward()
        // Phase 13.6: Update typing context after deleting
        viewModel?.updateTypingContext()
        // Auto-shift if we're now at start of sentence
        checkAutoShift()
    }

    /// Delete multiple words (swipe-delete feature like Gboard)
    private func deleteWords(count: Int) {
        guard let proxy = textDocumentProxy else { return }

        var totalDeletedText = ""

        for _ in 0..<count {
            // Get text before cursor
            guard let beforeText = proxy.documentContextBeforeInput, !beforeText.isEmpty else { break }

            // Find word boundary
            let trimmed = beforeText.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                // Just spaces, delete one character
                totalDeletedText = " " + totalDeletedText
                proxy.deleteBackward()
            } else {
                // Find the last word and delete it
                var charsToDelete = 0
                var foundWord = false

                // Count backwards from end
                for char in beforeText.reversed() {
                    if char.isWhitespace {
                        if foundWord {
                            break  // End of word
                        }
                        charsToDelete += 1  // Delete trailing whitespace
                    } else {
                        foundWord = true
                        charsToDelete += 1
                    }
                }

                // Capture what we're about to delete
                let deletedPart = String(beforeText.suffix(charsToDelete))
                totalDeletedText = deletedPart + totalDeletedText

                // Delete the characters
                for _ in 0..<charsToDelete {
                    proxy.deleteBackward()
                }
            }
        }

        // Push all deleted text to undo stack as a single item
        if !totalDeletedText.isEmpty {
            viewModel?.pushToUndoStack(totalDeletedText)
        }

        viewModel?.updateTypingContext()
        // Auto-shift if we're now at start of sentence
        checkAutoShift()
    }

    private func handleShiftTap() {
        switch shiftState {
        case .lowercase:
            shiftState = .shift
        case .shift:
            shiftState = .capsLock
        case .capsLock:
            shiftState = .lowercase
        }
    }

    private func afterLetterInsert() {
        // After inserting a letter, turn off single shift (but not caps lock)
        if shiftState == .shift {
            shiftState = .lowercase
        }
    }

    private func toggleLayout() {
        if layoutState == .letters {
            layoutState = .numbers
        } else {
            layoutState = .letters
        }
    }

    private func toggleSymbols() {
        if layoutState == .numbers {
            layoutState = .symbols
        } else {
            layoutState = .numbers
        }
    }

    // MARK: - Auto-Shift

    /// Check if keyboard should auto-shift based on context
    private func checkAutoShift() {
        // Don't override caps lock
        guard shiftState != .capsLock else { return }

        // Check if we should capitalize
        if shouldAutoCapitalize {
            // Only auto-shift if currently lowercase
            if shiftState == .lowercase {
                shiftState = .shift
            }
        } else {
            // Turn off shift if we shouldn't capitalize (e.g., mid-sentence)
            // But only if it was auto-shifted, not manually set
            // We can't distinguish, so leave it alone for now
        }
    }

    // MARK: - Accent Popup

    private func showAccentPopup(for letter: String, at frame: CGRect) {
        accentPopupLetter = letter
        accentPopupKeyFrame = frame
        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
            showingAccentPopup = true
        }
    }

}

// MARK: - Preview
#Preview {
    QWERTYKeyboard(
        textDocumentProxy: nil,
        onNextKeyboard: { print("Next keyboard") }
    )
    .preferredColorScheme(.dark)
}
