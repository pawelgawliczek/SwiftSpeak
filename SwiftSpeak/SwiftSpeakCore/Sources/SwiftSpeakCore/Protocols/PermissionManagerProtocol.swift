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
    func checkPermission(_ type: PermissionType) -> PermissionStatus
    func requestPermission(_ type: PermissionType) async -> Bool
    func openSystemPreferences(for type: PermissionType)
    func hasRequiredPermissions() -> Bool
}
