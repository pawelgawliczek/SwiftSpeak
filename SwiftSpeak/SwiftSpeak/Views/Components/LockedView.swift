//
//  LockedView.swift
//  SwiftSpeak
//
//  Phase 6: UI shown when biometric authentication is required
//

import SwiftUI
import SwiftSpeakCore
import LocalAuthentication

/// View displayed when access to a protected section requires authentication
struct LockedView: View {
    let biometricType: LABiometryType
    let hasError: Bool
    let errorMessage: String?
    let onUnlock: () -> Void

    init(
        biometricType: LABiometryType,
        hasError: Bool = false,
        errorMessage: String? = nil,
        onUnlock: @escaping () -> Void
    ) {
        self.biometricType = biometricType
        self.hasError = hasError
        self.errorMessage = errorMessage
        self.onUnlock = onUnlock
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Lock icon with biometric type
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentGradient.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Image(systemName: biometricIcon)
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(AppTheme.accentGradient)
                }

                Text("Authentication Required")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Use \(biometricName) to access this section")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Error message
            if hasError, let message = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Spacer()

            // Unlock button
            Button(action: {
                HapticManager.mediumTap()
                onUnlock()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: biometricIcon)
                        .font(.body.weight(.semibold))
                    Text("Unlock with \(biometricName)")
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.accentGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Computed Properties

    private var biometricIcon: String {
        switch biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        case .none: return "lock.fill"
        @unknown default: return "lock.fill"
        }
    }

    private var biometricName: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        case .none: return "Passcode"
        @unknown default: return "Passcode"
        }
    }
}

// MARK: - Preview

#Preview("Face ID") {
    LockedView(
        biometricType: .faceID,
        onUnlock: {}
    )
}

#Preview("Touch ID") {
    LockedView(
        biometricType: .touchID,
        onUnlock: {}
    )
}

#Preview("With Error") {
    LockedView(
        biometricType: .faceID,
        hasError: true,
        errorMessage: "Authentication failed. Tap to try again.",
        onUnlock: {}
    )
}
