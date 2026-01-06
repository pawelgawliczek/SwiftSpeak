//
//  ClipboardProtocol.swift
//  SwiftSpeakCore
//
//  Protocol for clipboard operations to abstract iOS/macOS differences
//

import Foundation
import SwiftSpeakCore

/// Protocol for clipboard operations
/// iOS uses UIPasteboard, macOS uses NSPasteboard
protocol ClipboardProtocol: Sendable {
    /// Copy text to the system clipboard
    func copyToClipboard(_ text: String)

    /// Get text from the system clipboard
    func getClipboardText() -> String?
}
