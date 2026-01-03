//
//  MacPermissionManager.swift
//  SwiftSpeakMac
//
//  macOS permission management for microphone and accessibility
//

import AVFoundation
import AppKit
import SwiftSpeakCore

@MainActor
public final class MacPermissionManager: PermissionManagerProtocol, ObservableObject {

    @Published private(set) public var microphoneStatus: PermissionStatus = .notDetermined
    @Published private(set) public var accessibilityStatus: PermissionStatus = .notDetermined

    public init() {
        checkAllPermissions()
    }

    // MARK: - PermissionManagerProtocol

    public func checkPermission(_ type: PermissionType) -> PermissionStatus {
        switch type {
        case .microphone:
            return checkMicrophonePermission()
        case .accessibility:
            return checkAccessibilityPermission()
        }
    }

    public func requestPermission(_ type: PermissionType) async -> Bool {
        switch type {
        case .microphone:
            return await requestMicrophonePermission()
        case .accessibility:
            // Accessibility can't be requested programmatically
            // Open System Preferences instead
            openSystemPreferences(for: .accessibility)
            return false
        }
    }

    public func openSystemPreferences(for type: PermissionType) {
        let urlString: String
        switch type {
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Microphone Permission

    private func checkMicrophonePermission() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphoneStatus = .authorized
        case .denied:
            microphoneStatus = .denied
        case .restricted:
            microphoneStatus = .restricted
        case .notDetermined:
            microphoneStatus = .notDetermined
        @unknown default:
            microphoneStatus = .notDetermined
        }
        return microphoneStatus
    }

    private func requestMicrophonePermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        microphoneStatus = granted ? .authorized : .denied
        return granted
    }

    // MARK: - Accessibility Permission

    private func checkAccessibilityPermission() -> PermissionStatus {
        let trusted = AXIsProcessTrusted()
        accessibilityStatus = trusted ? .authorized : .denied
        return accessibilityStatus
    }

    /// Prompt for accessibility permission with system dialog
    public func promptForAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    // MARK: - Helpers

    private func checkAllPermissions() {
        _ = checkMicrophonePermission()
        _ = checkAccessibilityPermission()
    }

    /// Refresh all permission statuses
    public func refreshPermissions() {
        checkAllPermissions()
    }
}
