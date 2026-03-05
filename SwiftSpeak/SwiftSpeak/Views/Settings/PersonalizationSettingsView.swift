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
        } header: {
            Text("AI Memory")
        } footer: {
            Text("View and manage AI memory. The AI learns your preferences and context over time.")
        }
    }

    // MARK: - App Library Section

    private var appLibrarySection: some View {
        Section {
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
        } header: {
            Text("App Automation")
        } footer: {
            Text("Assign apps to categories. Contexts and Power Modes can auto-enable based on which app you're using.")
        }
    }
}

#Preview("Personalization") {
    NavigationStack {
        PersonalizationSettingsView()
            .environmentObject(SharedSettings.shared)
    }
}
