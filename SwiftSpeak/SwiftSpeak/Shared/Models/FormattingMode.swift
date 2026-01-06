//
//  FormattingMode.swift
//  SwiftSpeak
//
//  Formatting mode definitions for transcription processing
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation
import SwiftSpeakCore

// MARK: - Formatting Mode
enum FormattingMode: String, Codable, CaseIterable, Identifiable {
    case raw = "raw"
    case email = "email"
    case formal = "formal"
    case casual = "casual"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .raw: return "Raw"
        case .email: return "Email"
        case .formal: return "Formal"
        case .casual: return "Casual"
        }
    }

    var icon: String {
        switch self {
        case .raw: return "text.alignleft"
        case .email: return "envelope.fill"
        case .formal: return "briefcase.fill"
        case .casual: return "face.smiling.fill"
        }
    }

    var prompt: String {
        switch self {
        case .raw:
            return ""
        case .email:
            return """
            Format this dictated text as a professional email.
            Add appropriate greeting and sign-off.
            Fix grammar and punctuation. Keep the original meaning.
            """
        case .formal:
            return """
            Rewrite this text in a formal, professional tone.
            Use proper business language. Fix any grammatical errors.
            """
        case .casual:
            return """
            Clean up this text while keeping a casual, friendly tone.
            Fix grammar but maintain conversational style.
            """
        }
    }
}
