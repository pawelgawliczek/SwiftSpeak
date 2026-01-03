//
//  MacBiometricAuth.swift
//  SwiftSpeakMac
//
//  Touch ID authentication for macOS (same as iOS)
//

import LocalAuthentication

@MainActor
public final class MacBiometricAuth: ObservableObject {

    @Published private(set) public var isAuthenticated = false
    @Published private(set) public var biometricType: LABiometryType = .none

    private var lastAuthTime: Date?
    private let sessionTimeout: TimeInterval = 300 // 5 minutes

    public init() {
        checkBiometricAvailability()
    }

    // MARK: - Public Methods

    /// Check if biometric authentication is available
    public func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
        } else {
            biometricType = .none
        }
    }

    /// Authenticate using Touch ID
    public func authenticate(reason: String = "Authenticate to access SwiftSpeak settings") async -> Bool {
        // Check if session is still valid
        if let lastAuth = lastAuthTime, Date().timeIntervalSince(lastAuth) < sessionTimeout {
            return true
        }

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Fallback to device passcode
            return await authenticateWithPasscode(reason: reason)
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            if success {
                lastAuthTime = Date()
                isAuthenticated = true
            }
            return success
        } catch {
            // Try passcode fallback
            return await authenticateWithPasscode(reason: reason)
        }
    }

    /// Authenticate with device passcode (fallback)
    public func authenticateWithPasscode(reason: String) async -> Bool {
        let context = LAContext()

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            if success {
                lastAuthTime = Date()
                isAuthenticated = true
            }
            return success
        } catch {
            return false
        }
    }

    /// Clear authentication session
    public func clearSession() {
        isAuthenticated = false
        lastAuthTime = nil
    }

    /// Check if session is still valid
    public var isSessionValid: Bool {
        guard let lastAuth = lastAuthTime else { return false }
        return Date().timeIntervalSince(lastAuth) < sessionTimeout
    }

    /// Display name for the available biometric type
    public var biometricName: String {
        switch biometricType {
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"  // Not available on Mac, but included for completeness
        case .opticID:
            return "Optic ID"
        case .none:
            return "Passcode"
        @unknown default:
            return "Biometric"
        }
    }
}
