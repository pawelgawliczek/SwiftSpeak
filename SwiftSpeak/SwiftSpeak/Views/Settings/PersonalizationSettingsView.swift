//
//  PersonalizationSettingsView.swift
//  SwiftSpeak
//
//  Personalization settings subpage - contexts, memory, and app automation
//

import SwiftUI
import SwiftSpeakCore

struct PersonalizationSettingsView: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme
    @State private var showPaywall = false

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    private var contextsSubtitle: String {
        let count = settings.contexts.count
        if count == 0 {
            return "No contexts configured"
        }
        if let active = settings.activeContext {
            return "Active: \(active.name)"
        }
        return "\(count) context\(count == 1 ? "" : "s")"
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            List {
                // Contexts Section
                contextsSection

                // Memory Section
                memorySection

                // App Library Section
                appLibrarySection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Personalization")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Contexts Section

    private var contextsSection: some View {
        Section {
            NavigationLink {
                ContextsView()
            } label: {
                SettingsRow(
                    icon: "person.2.fill",
                    iconColor: .blue,
                    title: "Contexts",
                    subtitle: contextsSubtitle
                )
            }
            .listRowBackground(rowBackground)
        } header: {
            Text("Conversation Contexts")
        } footer: {
            Text("Create contexts for different situations (Work, Personal, Casual). Each context can have its own formatting style and instructions.")
        }
    }

    // MARK: - Memory Section

    private var memorySection: some View {
        Section {
            if settings.subscriptionTier == .power {
                NavigationLink {
                    MemoryView()
                } label: {
                    SettingsRow(
                        icon: "brain.head.profile",
                        iconColor: .pink,
                        title: "Memory",
                        subtitle: "History, workflow & context memory"
                    )
                }
                .listRowBackground(rowBackground)
            } else {
                // Locked state for non-Power users
                Button(action: {
                    showPaywall = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Memory")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)

                                TierBadge(tier: .power)
                            }

                            Text("AI remembers context across conversations")
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
            Text("AI Memory")
        } footer: {
            if settings.subscriptionTier == .power {
                Text("View and manage AI memory. The AI learns your preferences and context over time.")
            } else {
                Text("Upgrade to Power for AI memory that learns your preferences and writing style.")
            }
        }
    }

    // MARK: - App Library Section

    private var appLibrarySection: some View {
        Section {
            if settings.subscriptionTier != .free {
                NavigationLink {
                    AppLibraryView()
                } label: {
                    SettingsRow(
                        icon: "square.grid.2x2.fill",
                        iconColor: .indigo,
                        title: "App Library",
                        subtitle: "Manage app categories"
                    )
                }
                .listRowBackground(rowBackground)
            } else {
                // Locked state for free users
                Button(action: {
                    showPaywall = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("App Library")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)

                                TierBadge(tier: .pro)
                            }

                            Text("Auto-enable modes based on app")
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
            Text("App Automation")
        } footer: {
            if settings.subscriptionTier != .free {
                Text("Assign apps to categories. Contexts and Power Modes can auto-enable based on which app you're using.")
            } else {
                Text("Upgrade to Pro for automatic mode switching based on which app you're using.")
            }
        }
    }
}

#Preview("Personalization - Free") {
    NavigationStack {
        PersonalizationSettingsView()
            .environmentObject({
                let settings = SharedSettings.shared
                settings.subscriptionTier = .free
                return settings
            }())
    }
}

#Preview("Personalization - Power") {
    NavigationStack {
        PersonalizationSettingsView()
            .environmentObject({
                let settings = SharedSettings.shared
                settings.subscriptionTier = .power
                return settings
            }())
    }
}
