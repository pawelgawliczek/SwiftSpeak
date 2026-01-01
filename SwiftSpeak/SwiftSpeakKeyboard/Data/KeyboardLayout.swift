//
//  KeyboardLayout.swift
//  SwiftSpeakKeyboard
//
//  Keyboard layout definitions for QWERTY, numbers, and symbols
//

import Foundation

// MARK: - Keyboard Layout
struct KeyboardLayout {
    // MARK: - QWERTY Letters
    static let qwertyRow1 = ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
    static let qwertyRow2 = ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
    static let qwertyRow3 = ["Z", "X", "C", "V", "B", "N", "M"]

    // MARK: - Numbers & Punctuation
    static let numbersRow1 = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    static let numbersRow2 = ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""]
    static let numbersRow3 = [".", ",", "?", "!", "'"]

    // MARK: - Symbols
    static let symbolsRow1 = ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="]
    static let symbolsRow2 = ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"]
    static let symbolsRow3 = [".", ",", "?", "!", "'"]
}

// MARK: - Shift State
enum ShiftState {
    case lowercase
    case shift      // One letter, then back to lowercase
    case capsLock   // All caps until toggled off
}

// MARK: - Keyboard Layout State
enum KeyboardLayoutState {
    case letters
    case numbers
    case symbols
}
