//
//  PermissionManagerProtocol.swift
//  SwiftSpeakCore
//
//  Protocol for permission management
//

import Foundation
import SwiftSpeakCore

/// Types of permissions the app may need
enum PermissionType: String, CaseIterable, Sendable {
    case microphone
    case accessibility
    case speechRecognition
}

/// Status of a permission request
enum PermissionStatus: String, Sendable {
    case authorized
    case denied
    case notDetermined
    case restricted
}

/// Protocol for managing system permissions
@MainActor
protocol PermissionManagerProtocol: ObservableObject {
    /// Check the current status of a permission
    func checkPermission(_ type: PermissionType) -> PermissionStatus

    /// Request a permission from the user
    func requestPermission(_ type: PermissionType) async -> Bool

    /// Open system preferences for a permission type
    func openSystemPreferences(for type: PermissionType)

    /// Check if all required permissions are granted
    func hasRequiredPermissions() -> Bool
}
