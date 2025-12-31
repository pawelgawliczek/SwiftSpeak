//
//  BiometricGateView.swift
//  SwiftSpeak
//
//  Phase 6: View wrapper that requires biometric authentication
//

import SwiftUI

/// A view wrapper that requires biometric authentication to access its content
/// Uses session-based authentication - once authenticated, remains valid for 5 minutes
struct BiometricGateView<Content: View>: View {
    @EnvironmentObject var settings: SharedSettings
    @ObservedObject private var authManager = BiometricAuthManager.shared

    /// The content to display when authenticated
    let protectedContent: () -> Content

    /// Reason shown to user during authentication prompt
    let authReason: String

    /// Whether authentication has been attempted this session
    @State private var hasAttemptedAuth = false

    /// Whether there was an error during authentication
    @State private var showError = false

    /// Error message to display
    @State private var errorMessage: String?

    /// Whether authentication is in progress
    @State private var isAuthenticating = false

    init(
        authReason: String,
        @ViewBuilder protectedContent: @escaping () -> Content
    ) {
        self.authReason = authReason
        self.protectedContent = protectedContent
    }

    var body: some View {
        Group {
            if !settings.biometricProtectionEnabled {
                // Biometric protection disabled - show content directly
                protectedContent()
            } else if authManager.isSessionValid {
                // Session is valid - show content
                protectedContent()
            } else {
                // Need authentication
                LockedView(
                    biometricType: authManager.biometricType,
                    hasError: showError,
                    errorMessage: errorMessage,
                    onUnlock: performAuthentication
                )
            }
        }
        .onAppear {
            // Auto-attempt authentication when view appears
            if settings.biometricProtectionEnabled && !hasAttemptedAuth && !authManager.isSessionValid && !isAuthenticating {
                performAuthentication()
            }
        }
    }

    // MARK: - Private Methods

    private func performAuthentication() {
        guard !isAuthenticating else { return }

        hasAttemptedAuth = true
        isAuthenticating = true
        showError = false
        errorMessage = nil

        Task { @MainActor in
            let result = await authManager.authenticate(reason: authReason)

            isAuthenticating = false

            switch result {
            case .success:
                showError = false
                errorMessage = nil
            case .failure(let error):
                showError = true
                errorMessage = error.errorDescription

                // Only show error state for recoverable errors
                // For non-recoverable, the LockedView will show appropriate message
                if !error.isRecoverable {
                    HapticManager.error()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Protected Content") {
    BiometricGateView(authReason: "Access protected content") {
        VStack {
            Text("Protected Content")
                .font(.title)
            Text("You are authenticated!")
                .foregroundStyle(.secondary)
        }
    }
    .environmentObject(SharedSettings.shared)
}
