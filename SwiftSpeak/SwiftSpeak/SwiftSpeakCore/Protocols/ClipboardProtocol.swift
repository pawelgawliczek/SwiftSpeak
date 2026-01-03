import Foundation

public protocol ClipboardProtocol: Sendable {
    func copyToClipboard(_ text: String)
    func getClipboardText() -> String?
}
