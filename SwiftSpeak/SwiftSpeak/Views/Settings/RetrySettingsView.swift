//
//  RetrySettingsView.swift
//  SwiftSpeak
//
//  Retry and failed recording settings
//

import SwiftUI
import SwiftSpeakCore

// MARK: - Retry Settings View

struct RetrySettingsView: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            List {
                Section {
                    Toggle(isOn: $settings.autoRetryEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Retry on Failure")
                                .font(.callout)
                            Text("Automatically retry failed transcriptions")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(AppTheme.accent)
                    .listRowBackground(rowBackground)

                    if settings.autoRetryEnabled {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Maximum Retries")
                                    .font(.callout)
                                Text("Retry up to \(settings.maxRetryCount) times")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Stepper("", value: $settings.maxRetryCount, in: 1...10)
                                .labelsHidden()
                        }
                        .listRowBackground(rowBackground)
                    }
                } header: {
                    Text("Automatic Retry")
                } footer: {
                    Text("Failed transcriptions retry with exponential backoff (1s, 2s, 4s...).")
                }

                Section {
                    Toggle(isOn: $settings.keepFailedRecordings) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keep Failed Recordings")
                                .font(.callout)
                            Text("Save audio for manual retry")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(AppTheme.accent)
                    .listRowBackground(rowBackground)

                    if settings.keepFailedRecordings {
                        Picker(selection: $settings.pendingAudioRetentionDays) {
                            Text("Never delete").tag(0)
                            Text("1 day").tag(1)
                            Text("7 days").tag(7)
                            Text("30 days").tag(30)
                        } label: {
                            Text("Auto-Delete After")
                                .font(.callout)
                        }
                        .listRowBackground(rowBackground)
                    }

                    if !settings.pendingAudioQueue.isEmpty {
                        NavigationLink {
                            PendingAudioListView()
                        } label: {
                            SettingsRow(
                                icon: "waveform.badge.exclamationmark",
                                iconColor: .orange,
                                title: "Pending Recordings",
                                subtitle: "\(settings.pendingAudioQueue.count) recording\(settings.pendingAudioQueue.count == 1 ? "" : "s") pending"
                            )
                        }
                        .listRowBackground(rowBackground)
                    }
                } header: {
                    Text("Failed Recordings")
                } footer: {
                    Text("Save recordings that failed to transcribe for manual retry later.")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Retry Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Retry Settings") {
    NavigationStack {
        RetrySettingsView()
            .environmentObject(SharedSettings.shared)
    }
}
