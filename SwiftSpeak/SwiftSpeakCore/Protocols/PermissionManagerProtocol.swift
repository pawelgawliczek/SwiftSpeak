import Foundation

public enum PermissionType: String, CaseIterable, Sendable {
    case microphone
    case accessibility
    case speechRecognition
}

public enum PermissionStatus: String, Sendable {
    case authorized
    case denied
    case notDetermined
    case restricted
}

@MainActor
public protocol PermissionManagerProtocol: ObservableObject {
    public func checkPermission(_ type: PermissionType) -> PermissionStatus
    public func requestPermission(_ type: PermissionType) async -> Bool
    public func openSystemPreferences(for type: PermissionType)
    public func hasRequiredPermissions() -> Bool
}
