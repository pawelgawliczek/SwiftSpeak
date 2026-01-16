//
//  MacPermissionManager.swift
//  SwiftSpeakMac
//
//  macOS permission management for microphone and accessibility
//

import AVFoundation
import AppKit
import Combine

// MARK: - Permission Types

public enum PermissionType: String, CaseIterable, Sendable {
    case microphone
    case accessibility
    case screenRecording
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
}

// MARK: - macOS Permission Manager

@MainActor
public final class MacPermissionManager: PermissionManagerProtocol, ObservableObject {

    @Published private(set) public var microphoneStatus: PermissionStatus = .notDetermined
    @Published private(set) public var accessibilityStatus: PermissionStatus = .notDetermined
    @Published private(set) public var screenRecordingStatus: PermissionStatus = .notDetermined

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
        case .screenRecording:
            return checkScreenRecordingPermission()
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
        case .screenRecording:
            return requestScreenRecordingPermission()
        }
    }

    public func openSystemPreferences(for type: PermissionType) {
        let urlString: String
        switch type {
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .screenRecording:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
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

        // Refresh status after prompting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            _ = self?.checkAccessibilityPermission()
        }
    }

    /// Check if accessibility is enabled (convenience for services)
    public var isAccessibilityEnabled: Bool {
        return accessibilityStatus == .authorized
    }

    // MARK: - Screen Recording Permission

    private func checkScreenRecordingPermission() -> PermissionStatus {
        // CGPreflightScreenCaptureAccess checks without prompting
        let hasAccess = CGPreflightScreenCaptureAccess()
        screenRecordingStatus = hasAccess ? .authorized : .denied
        return screenRecordingStatus
    }

    private func requestScreenRecordingPermission() -> Bool {
        // CGRequestScreenCaptureAccess triggers system prompt (only shows once)
        // After first prompt, user must manually enable in System Preferences
        let granted = CGRequestScreenCaptureAccess()
        screenRecordingStatus = granted ? .authorized : .denied

        // If not granted, the system has shown the prompt once
        // User needs to go to System Preferences to enable
        return granted
    }

    /// Prompt for screen recording permission
    /// Note: The system only shows the prompt once. After that, user must
    /// manually enable in System Preferences > Privacy & Security > Screen Recording
    public func promptForScreenRecordingPermission() {
        if !CGPreflightScreenCaptureAccess() {
            // This triggers the system prompt (only once per app)
            _ = CGRequestScreenCaptureAccess()

            // Refresh status after prompting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                _ = self?.checkScreenRecordingPermission()
            }
        }
    }

    /// Check if screen recording is enabled (convenience for services)
    public var isScreenRecordingEnabled: Bool {
        return screenRecordingStatus == .authorized
    }

    // MARK: - Helpers

    private func checkAllPermissions() {
        _ = checkMicrophonePermission()
        _ = checkAccessibilityPermission()
        _ = checkScreenRecordingPermission()
    }

    /// Refresh all permission statuses
    public func refreshPermissions() {
        checkAllPermissions()
    }
}
