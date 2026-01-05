import Foundation

public enum TextInsertionResult: Sendable {
    case accessibilitySuccess
    case clipboardFallback
    case failed(Error)
}

@MainActor
public protocol TextInsertionProtocol {
    var isAccessibilityAvailable: Bool { get }
    func insertText(_ text: String, replaceSelection: Bool) async -> TextInsertionResult
    func getSelectedText() async -> String?
    func replaceAllText(with text: String) async -> TextInsertionResult
}
