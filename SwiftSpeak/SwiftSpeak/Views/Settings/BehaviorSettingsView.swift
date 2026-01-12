//
//  BehaviorSettingsView.swift
//  SwiftSpeak
//
//  Power Mode settings subpage - streaming, retry, webhooks, and advanced options
//

import SwiftUI
import SwiftSpeakCore

struct BehaviorSettingsView: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme
    @State private var showPaywall = false
    @State private var showAdvanced = false

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    private var webhooksSubtitle: String {
        let count = settings.webhooks.count
        if count == 0 {
            return "No webhooks configured"
        } else {
            return "\(count) webhook\(count == 1 ? "" : "s") configured"
        }
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            List {
                // Streaming Section
                streamingSection

                // Reliability Section
                reliabilitySection

                // Integrations Section
                integrationsSection

                // Advanced Section (collapsible)
                advancedSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Power Mode")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Streaming Section

    private var streamingSection: some View {
        Section {
            Toggle(isOn: $settings.powerModeStreamingEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stream Power Mode responses")
                        .font(.callout)
                    Text("Show text as it's generated")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(AppTheme.powerAccent)
            .listRowBackground(rowBackground)
        } header: {
            Text("Streaming")
        } footer: {
            Text("Streaming shows AI responses progressively instead of waiting for completion.")
        }
    }

    // MARK: - Reliability Section

    private var reliabilitySection: some View {
        Section {
            NavigationLink {
                RetrySettingsView()
            } label: {
                SettingsRow(
                    icon: "arrow.clockwise",
                    iconColor: .blue,
                    title: "Retry Settings",
                    subtitle: settings.autoRetryEnabled ? "Auto-retry enabled" : "Auto-retry disabled"
                )
            }
            .listRowBackground(rowBackground)
        } header: {
            Text("Reliability")
        } footer: {
            Text("Configure automatic retry behavior when transcription fails.")
        }
    }

    // MARK: - Integrations Section

    private var integrationsSection: some View {
        Section {
            if settings.subscriptionTier == .power {
                NavigationLink {
                    WebhooksView()
                } label: {
                    SettingsRow(
                        icon: "link",
                        iconColor: .cyan,
                        title: "Webhooks",
                        subtitle: webhooksSubtitle
                    )
                }
                .listRowBackground(rowBackground)
            } else {
                // Locked state for non-Power users
                Button(action: {
                    showPaywall = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "link")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Webhooks")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)

                                TierBadge(tier: .power)
                            }

                            Text("Connect to Slack, Notion, Make, Zapier")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(rowBackground)
            }
        } header: {
            Text("Integrations")
        } footer: {
            if settings.subscriptionTier == .power {
                Text("Send transcriptions to external services automatically.")
            } else {
                Text("Upgrade to Power to automate workflows with webhooks.")
            }
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showAdvanced) {
                NavigationLink {
                    AdvancedTokenLimitsView()
                } label: {
                    SettingsRow(
                        icon: "slider.horizontal.3",
                        iconColor: .purple,
                        title: "Token Limits",
                        subtitle: "Configure AI context usage"
                    )
                }
                .listRowBackground(rowBackground)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "gearshape.2.fill")
                        .font(.callout)
                        .foregroundStyle(.gray)
                        .frame(width: 28, height: 28)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    Text("Advanced")
                        .font(.callout)
                }
            }
            .listRowBackground(rowBackground)
        } header: {
            Text("Advanced")
        } footer: {
            Text("Fine-tune AI limits and access diagnostic tools.")
        }
    }
}

#Preview("Behavior - Free") {
    NavigationStack {
        BehaviorSettingsView()
            .environmentObject({
                let settings = SharedSettings.shared
                settings.subscriptionTier = .free
                return settings
            }())
    }
}

#Preview("Behavior - Power") {
    NavigationStack {
        BehaviorSettingsView()
            .environmentObject({
                let settings = SharedSettings.shared
                settings.subscriptionTier = .power
                return settings
            }())
    }
}
