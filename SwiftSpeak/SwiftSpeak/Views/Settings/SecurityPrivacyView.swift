//
//  SecurityPrivacyView.swift
//  SwiftSpeak
//
//  Security and privacy settings
//

import SwiftUI

// MARK: - Security & Privacy View

struct SecurityPrivacyView: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    private var biometricAvailable: Bool {
        BiometricAuthManager.shared.isBiometricAvailable
    }

    private var biometricName: String {
        BiometricAuthManager.shared.biometricName
    }

    private var biometricIcon: String {
        BiometricAuthManager.shared.biometricIcon
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            List {
                Section {
                    Toggle(isOn: $settings.biometricProtectionEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: biometricIcon)
                                .font(.title2)
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Require \(biometricName)")
                                    .font(.callout)
                                Text("Protect Settings and History")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(!biometricAvailable)
                    .tint(AppTheme.accent)
                    .listRowBackground(rowBackground)
                } header: {
                    Text("Authentication")
                } footer: {
                    if !biometricAvailable {
                        Text("Biometric authentication is not available on this device.")
                    } else {
                        Text("When enabled, \(biometricName) is required to access Settings and History.")
                    }
                }

                Section {
                    Picker(selection: $settings.dataRetentionPeriod) {
                        ForEach(DataRetentionPeriod.allCases) { period in
                            Text(period.displayName).tag(period)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.title2)
                                .foregroundStyle(.orange)
                                .frame(width: 32)

                            Text("Auto-Delete History")
                                .font(.callout)
                        }
                    }
                    .listRowBackground(rowBackground)
                } header: {
                    Text("Data Retention")
                } footer: {
                    Text("Automatically delete transcription history after the specified period.")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Security & Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Security & Privacy") {
    NavigationStack {
        SecurityPrivacyView()
            .environmentObject(SharedSettings.shared)
    }
}
