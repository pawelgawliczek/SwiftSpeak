import Foundation

public protocol ClipboardProtocol: Sendable {
    public func copyToClipboard(_ text: String)
    public func getClipboardText() -> String?
}
