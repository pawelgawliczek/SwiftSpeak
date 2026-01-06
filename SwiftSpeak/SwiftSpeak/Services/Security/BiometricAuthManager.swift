//
//  BiometricAuthManager.swift
//  SwiftSpeak
//
//  Phase 6: Biometric authentication manager with session support
//

import Foundation
import SwiftSpeakCore
import LocalAuthentication
import Combine

// MARK: - Authentication Error

enum BiometricAuthError: LocalizedError {
    case biometryNotAvailable
    case biometryNotEnrolled
    case biometryLockout
    case userCancel
    case userFallback
    case systemCancel
    case passcodeNotSet
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .biometryNotAvailable:
            return "Biometric authentication is not available on this device."
        case .biometryNotEnrolled:
            return "No biometric data is enrolled. Please set up Face ID or Touch ID in Settings."
        case .biometryLockout:
            return "Biometric authentication is locked. Please use your device passcode."
        case .userCancel:
            return "Authentication was cancelled."
        case .userFallback:
            return "Please use your device passcode."
        case .systemCancel:
            return "Authentication was cancelled by the system."
        case .passcodeNotSet:
            return "No passcode is set. Please set up a passcode in Settings."
        case .unknown(let error):
            return error.localizedDescription
        }
    }

    var isRecoverable: Bool {
        switch self {
        case .userCancel, .userFallback, .systemCancel:
            return true
        default:
            return false
        }
    }
}

// MARK: - Biometric Auth Manager

/// Manages biometric authentication with session-based persistence
/// Session remains valid for 5 minutes after successful authentication
@MainActor
final class BiometricAuthManager: ObservableObject {

    // MARK: - Singleton

    static let shared = BiometricAuthManager()

    // MARK: - Published Properties

    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var biometricType: LABiometryType = .none
    @Published private(set) var lastError: BiometricAuthError?

    // MARK: - Session Management

    /// Time of last successful authentication
    private var lastAuthTime: Date?

    /// Session timeout duration (5 minutes)
    private let sessionTimeout: TimeInterval = 300

    /// Whether the current session is still valid
    var isSessionValid: Bool {
        guard let lastAuth = lastAuthTime else { return false }
        return Date().timeIntervalSince(lastAuth) < sessionTimeout
    }

    // MARK: - Initialization

    private init() {
        updateBiometricType()
    }

    // MARK: - Public Methods

    /// Check biometric availability on this device
    func checkBiometricAvailability() -> (available: Bool, type: LABiometryType) {
        let context = LAContext()
        var error: NSError?
        let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return (available, context.biometryType)
    }

    /// Update the stored biometric type
    func updateBiometricType() {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        biometricType = context.biometryType
    }

    /// Perform biometric authentication
    /// Tries biometrics first (Face ID/Touch ID), falls back to passcode only if unavailable
    /// - Parameter reason: Localized reason shown to user
    /// - Returns: Success or error result
    func authenticate(reason: String) async -> Result<Void, BiometricAuthError> {
        // If session is still valid, skip authentication
        if isSessionValid {
            return .success(())
        }

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        // Check if biometrics are available
        var biometricsError: NSError?
        let biometricsAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &biometricsError)

        // If biometrics available, try them first
        if biometricsAvailable {
            context.localizedFallbackTitle = "Use Passcode"

            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: reason
                )

                if success {
                    lastAuthTime = Date()
                    isAuthenticated = true
                    lastError = nil
                    return .success(())
                } else {
                    // Shouldn't happen, but fall back to passcode
                    return await authenticateWithPasscode(reason: reason)
                }
            } catch let error as LAError {
                // If user chose fallback or biometrics locked out, try passcode
                if error.code == .userFallback || error.code == .biometryLockout {
                    return await authenticateWithPasscode(reason: reason)
                }
                // User cancelled or other error
                let authError = mapLAError(error)
                lastError = authError
                return .failure(authError)
            } catch {
                let authError = BiometricAuthError.unknown(error)
                lastError = authError
                return .failure(authError)
            }
        }

        // Biometrics not available, fall back to passcode
        return await authenticateWithPasscode(reason: reason)
    }

    /// Authenticate using device passcode only
    private func authenticateWithPasscode(reason: String) async -> Result<Void, BiometricAuthError> {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )

            if success {
                lastAuthTime = Date()
                isAuthenticated = true
                lastError = nil
                return .success(())
            } else {
                let error = BiometricAuthError.unknown(NSError(domain: "BiometricAuth", code: -1))
                lastError = error
                return .failure(error)
            }
        } catch let error as LAError {
            let authError = mapLAError(error)
            lastError = authError
            return .failure(authError)
        } catch {
            let authError = BiometricAuthError.unknown(error)
            lastError = authError
            return .failure(authError)
        }
    }

    /// Invalidate the current session
    /// Call this when app goes to background
    func invalidateSession() {
        lastAuthTime = nil
        isAuthenticated = false
    }

    /// Reset authentication state and clear error
    func reset() {
        isAuthenticated = false
        lastError = nil
        lastAuthTime = nil
    }

    // MARK: - Convenience Properties

    /// Human-readable name for the biometric type
    var biometricName: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        @unknown default: return "Passcode"
        }
    }

    /// SF Symbol name for the biometric type
    var biometricIcon: String {
        switch biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        @unknown default: return "lock.fill"
        }
    }

    /// Whether any form of authentication is available
    var isAuthenticationAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Whether biometric authentication specifically is available
    var isBiometricAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    // MARK: - Private Methods

    private func mapLAError(_ error: LAError) -> BiometricAuthError {
        switch error.code {
        case .biometryNotAvailable:
            return .biometryNotAvailable
        case .biometryNotEnrolled:
            return .biometryNotEnrolled
        case .biometryLockout:
            return .biometryLockout
        case .userCancel:
            return .userCancel
        case .userFallback:
            return .userFallback
        case .systemCancel:
            return .systemCancel
        case .passcodeNotSet:
            return .passcodeNotSet
        default:
            return .unknown(error)
        }
    }
}
