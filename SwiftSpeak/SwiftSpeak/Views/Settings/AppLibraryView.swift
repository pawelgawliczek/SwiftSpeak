//
//  AppLibraryView.swift
//  SwiftSpeak
//
//  View for browsing and managing the app library.
//  Users can search apps and reassign them to different categories.
//

import SwiftUI

struct AppLibraryView: View {
    @EnvironmentObject var settings: SharedSettings
    @State private var searchText = ""
    @State private var selectedApp: AppInfo?
    @State private var showingCategoryPicker = false
    @Environment(\.dismiss) private var dismiss

    private var filteredApps: [AppInfo] {
        if searchText.isEmpty {
            return AppLibrary.apps
        }
        return AppLibrary.search(query: searchText)
    }

    private var groupedApps: [(category: AppCategory, apps: [AppInfo])] {
        let apps = filteredApps
        var groups: [AppCategory: [AppInfo]] = [:]

        for app in apps {
            let category = settings.effectiveCategory(for: app.id) ?? app.defaultCategory
            groups[category, default: []].append(app)
        }

        return AppCategory.allCases.compactMap { category in
            guard let apps = groups[category], !apps.isEmpty else { return nil }
            return (category: category, apps: apps.sorted { $0.name < $1.name })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedApps, id: \.category) { group in
                    Section {
                        ForEach(group.apps) { app in
                            AppRow(
                                app: app,
                                effectiveCategory: settings.effectiveCategory(for: app.id) ?? app.defaultCategory,
                                hasOverride: settings.hasAppCategoryOverride(bundleId: app.id),
                                onTap: {
                                    selectedApp = app
                                    showingCategoryPicker = true
                                }
                            )
                        }
                    } header: {
                        Label(group.category.displayName, systemImage: group.category.icon)
                            .foregroundStyle(group.category.color)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search apps...")
            .navigationTitle("App Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCategoryPicker) {
                if let app = selectedApp {
                    CategoryPickerSheet(
                        app: app,
                        currentCategory: settings.effectiveCategory(for: app.id) ?? app.defaultCategory,
                        onSelect: { category in
                            if category == app.defaultCategory {
                                settings.removeAppCategoryOverride(bundleId: app.id)
                            } else {
                                settings.setAppCategoryOverride(bundleId: app.id, category: category)
                            }
                            showingCategoryPicker = false
                        }
                    )
                    .presentationDetents([.medium])
                }
            }
        }
    }
}

// MARK: - App Row

private struct AppRow: View {
    let app: AppInfo
    let effectiveCategory: AppCategory
    let hasOverride: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // App icon - use real icon from asset catalog
                AppIcon(app, size: .large, style: .filled)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(app.name)
                            .font(.body)
                            .foregroundStyle(.primary)

                        if hasOverride {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(effectiveCategory.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Picker Sheet

private struct CategoryPickerSheet: View {
    let app: AppInfo
    let currentCategory: AppCategory
    let onSelect: (AppCategory) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(AppCategory.allCases) { category in
                        Button {
                            onSelect(category)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: category.icon)
                                    .font(.title3)
                                    .foregroundStyle(category.color)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.displayName)
                                        .foregroundStyle(.primary)

                                    if category == app.defaultCategory {
                                        Text("Default")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                if category == currentCategory {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Select category for \(app.name)")
                }
            }
            .navigationTitle("Change Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AppLibraryView()
        .environmentObject(SharedSettings.shared)
}
