//
//  AppAssignmentSection.swift
//  SwiftSpeak
//
//  Reusable component for assigning apps and categories to Contexts/PowerModes.
//  Used in ContextEditorSheet and PowerModeEditorView.
//

import SwiftUI

/// A section for editing app assignments in Context or PowerMode editors
struct AppAssignmentSection: View {
    @Binding var appAssignment: AppAssignment
    @EnvironmentObject var settings: SharedSettings
    @State private var showingAppPicker = false
    @State private var showingCategoryPicker = false

    var body: some View {
        Section {
            // Summary row
            if appAssignment.hasAssignments {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Auto-enabled for:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(appAssignment.summary)
                        .font(.body)
                }
                .padding(.vertical, 4)
            }

            // Add apps button
            Button {
                showingAppPicker = true
            } label: {
                Label("Add Apps", systemImage: "plus.app")
            }

            // Add categories button
            Button {
                showingCategoryPicker = true
            } label: {
                Label("Add Categories", systemImage: "folder.badge.plus")
            }

            // Show assigned apps
            if !appAssignment.assignedAppIds.isEmpty {
                ForEach(Array(appAssignment.assignedAppIds).sorted(), id: \.self) { bundleId in
                    if let app = AppLibrary.find(bundleId: bundleId) {
                        AssignedAppRow(
                            app: app,
                            effectiveCategory: settings.effectiveCategory(for: bundleId) ?? app.defaultCategory,
                            onRemove: {
                                appAssignment.assignedAppIds.remove(bundleId)
                            }
                        )
                    }
                }
            }

            // Show assigned categories
            if !appAssignment.assignedCategories.isEmpty {
                ForEach(Array(appAssignment.assignedCategories).sorted { $0.displayName < $1.displayName }, id: \.self) { category in
                    AssignedCategoryRow(
                        category: category,
                        appCount: settings.apps(in: category).count,
                        onRemove: {
                            appAssignment.assignedCategories.remove(category)
                        }
                    )
                }
            }
        } header: {
            Text("App Auto-Enable")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Auto-enables when the keyboard opens in an assigned app or category.")
                Text("Manual selection always takes precedence over app auto-enable.")
                    .fontWeight(.medium)
            }
        }
        .sheet(isPresented: $showingAppPicker) {
            AppPickerSheet(
                selectedAppIds: $appAssignment.assignedAppIds,
                excludedCategories: appAssignment.assignedCategories
            )
            .environmentObject(settings)
        }
        .sheet(isPresented: $showingCategoryPicker) {
            CategoryAssignmentSheet(
                selectedCategories: $appAssignment.assignedCategories
            )
        }
    }
}

// MARK: - Assigned App Row

private struct AssignedAppRow: View {
    let app: AppInfo
    let effectiveCategory: AppCategory
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AppIcon(app, size: .medium, style: .filled)

            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.subheadline)

                Text(effectiveCategory.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Assigned Category Row

private struct AssignedCategoryRow: View {
    let category: AppCategory
    let appCount: Int
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(category.color.opacity(0.2))
                    .frame(width: 32, height: 32)

                Image(systemName: category.icon)
                    .font(.subheadline)
                    .foregroundStyle(category.color)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(category.displayName)
                    .font(.subheadline)

                Text("\(appCount) apps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - App Picker Sheet

private struct AppPickerSheet: View {
    @Binding var selectedAppIds: Set<String>
    let excludedCategories: Set<AppCategory>
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredApps: [AppInfo] {
        var apps: [AppInfo]
        if searchText.isEmpty {
            apps = AppLibrary.apps
        } else {
            apps = AppLibrary.search(query: searchText)
        }

        // Exclude apps that are in already-assigned categories
        return apps.filter { app in
            let category = settings.effectiveCategory(for: app.id) ?? app.defaultCategory
            return !excludedCategories.contains(category)
        }
    }

    private var groupedApps: [(category: AppCategory, apps: [AppInfo])] {
        var groups: [AppCategory: [AppInfo]] = [:]

        for app in filteredApps {
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
                    Section(group.category.displayName) {
                        ForEach(group.apps) { app in
                            let isSelected = selectedAppIds.contains(app.id)
                            Button {
                                if isSelected {
                                    selectedAppIds.remove(app.id)
                                } else {
                                    selectedAppIds.insert(app.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    AppIcon(app, size: .medium, style: .filled)

                                    Text(app.name)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search apps...")
            .navigationTitle("Select Apps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Category Assignment Sheet

private struct CategoryAssignmentSheet: View {
    @Binding var selectedCategories: Set<AppCategory>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(AppCategory.allCases) { category in
                        let isSelected = selectedCategories.contains(category)
                        Button {
                            if isSelected {
                                selectedCategories.remove(category)
                            } else {
                                selectedCategories.insert(category)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: category.icon)
                                    .font(.title3)
                                    .foregroundStyle(category.color)
                                    .frame(width: 28)

                                Text(category.displayName)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("Selecting a category will auto-enable for all apps in that category.")
                }
            }
            .navigationTitle("Select Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Empty Assignment") {
    Form {
        AppAssignmentSection(
            appAssignment: .constant(AppAssignment())
        )
        .environmentObject(SharedSettings.shared)
    }
}

#Preview("With Assignments") {
    Form {
        AppAssignmentSection(
            appAssignment: .constant(AppAssignment(
                assignedAppIds: ["net.whatsapp.WhatsApp", "com.facebook.Messenger"],
                assignedCategories: [.email, .work]
            ))
        )
        .environmentObject(SharedSettings.shared)
    }
}
