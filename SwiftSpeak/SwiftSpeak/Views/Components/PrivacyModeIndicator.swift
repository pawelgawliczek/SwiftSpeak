//
//  PrivacyModeIndicator.swift
//  SwiftSpeak
//
//  Phase 10: Visual indicator when Privacy Mode is active
//

import SwiftUI

/// Compact indicator showing Privacy Mode is enabled
struct PrivacyModeIndicator: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if settings.forcePrivacyMode {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.caption2.weight(.semibold))
                Text("Private")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.green)
            )
        }
    }
}

/// Larger banner for showing in views where privacy is relevant
struct PrivacyModeBanner: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme

    let showDetails: Bool

    init(showDetails: Bool = true) {
        self.showDetails = showDetails
    }

    var body: some View {
        if settings.forcePrivacyMode {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: "lock.shield.fill")
                        .font(.body)
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Privacy Mode Active")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)

                    if showDetails {
                        Text("All processing uses local models only")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.green.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

/// Warning shown when a Power Mode requires cloud providers but privacy mode is on
struct PrivacyModeWarning: View {
    let powerModeName: String
    let requiredProvider: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Cloud Provider Required")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)

                Text("\"\(powerModeName)\" requires \(requiredProvider), but Privacy Mode is on.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

/// Alert content for when user tries to use cloud provider in privacy mode
struct PrivacyModeBlockedAlert: View {
    let providerName: String
    let onDisablePrivacyMode: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: "lock.shield.fill")
                    .font(.title)
                    .foregroundStyle(.orange)
            }

            // Message
            VStack(spacing: 8) {
                Text("Privacy Mode Active")
                    .font(.headline)

                Text("\(providerName) is a cloud provider. Privacy Mode only allows local processing.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Actions
            VStack(spacing: 12) {
                Button(action: onDisablePrivacyMode) {
                    Text("Disable Privacy Mode")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
    }
}

// MARK: - Preview Helper

private struct PrivacyModePreviewWrapper<Content: View>: View {
    @StateObject private var settings = SharedSettings.shared
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .environmentObject(settings)
            .onAppear {
                settings.forcePrivacyMode = true
            }
    }
}

// MARK: - Previews

#Preview("Indicator") {
    PrivacyModePreviewWrapper {
        VStack {
            Text("Privacy Mode Indicator")
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer().frame(height: 20)

            PrivacyModeIndicator()

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.darkBase)
    }
    .preferredColorScheme(.dark)
}

#Preview("Banner") {
    PrivacyModePreviewWrapper {
        VStack {
            Text("Privacy Mode Banner")
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer().frame(height: 20)

            PrivacyModeBanner()

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.darkBase)
    }
    .preferredColorScheme(.dark)
}

#Preview("Warning") {
    VStack {
        Text("Privacy Mode Warning")
            .font(.headline)
            .foregroundStyle(.secondary)

        Spacer().frame(height: 20)

        PrivacyModeWarning(
            powerModeName: "Email Assistant",
            requiredProvider: "OpenAI GPT-4"
        )

        Spacer()
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppTheme.darkBase)
    .preferredColorScheme(.dark)
}

#Preview("Blocked Alert") {
    VStack {
        PrivacyModeBlockedAlert(
            providerName: "OpenAI",
            onDisablePrivacyMode: {},
            onCancel: {}
        )
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppTheme.darkBase)
    .preferredColorScheme(.dark)
}
