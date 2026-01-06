//
//  VocabularyView.swift
//  SwiftSpeak
//
//  Vocabulary management view
//

import SwiftUI
import SwiftSpeakCore

// MARK: - Vocabulary View

struct VocabularyView: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme
    @State private var showAddSheet = false
    @State private var editingEntry: VocabularyEntry?
    @State private var showDeleteConfirmation = false
    @State private var entryToDelete: VocabularyEntry?
    @State private var searchText = ""

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    private var filteredEntries: [VocabularyEntry] {
        if searchText.isEmpty {
            return settings.vocabulary.sorted { $0.category.rawValue < $1.category.rawValue }
        }
        return settings.vocabulary.filter {
            $0.recognizedWord.localizedCaseInsensitiveContains(searchText) ||
            $0.replacementWord.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedEntries: [(VocabularyCategory, [VocabularyEntry])] {
        let grouped = Dictionary(grouping: filteredEntries) { $0.category }
        return VocabularyCategory.allCases.compactMap { category in
            guard let entries = grouped[category], !entries.isEmpty else { return nil }
            return (category, entries)
        }
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            if settings.vocabulary.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(groupedEntries, id: \.0) { category, entries in
                        Section {
                            ForEach(entries) { entry in
                                VocabularyEntryRow(
                                    entry: entry,
                                    colorScheme: colorScheme,
                                    onToggle: {
                                        settings.toggleVocabularyEntry(entry)
                                    },
                                    onEdit: {
                                        editingEntry = entry
                                    }
                                )
                                .listRowBackground(rowBackground)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        entryToDelete = entry
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Image(systemName: category.icon)
                                    .font(.caption)
                                    .foregroundStyle(category.color)
                                Text(category.displayName)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .searchable(text: $searchText, prompt: "Search vocabulary")
            }
        }
        .navigationTitle("Vocabulary")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    showAddSheet = true
                }) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            VocabularyEditorSheet(
                entry: nil,
                onSave: { entry in
                    settings.addVocabularyEntry(entry)
                }
            )
        }
        .sheet(item: $editingEntry) { entry in
            VocabularyEditorSheet(
                entry: entry,
                onSave: { updatedEntry in
                    settings.updateVocabularyEntry(updatedEntry)
                }
            )
        }
        .alert("Delete Word?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                entryToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete {
                    settings.removeVocabularyEntry(entry)
                }
                entryToDelete = nil
            }
        } message: {
            if let entry = entryToDelete {
                Text("This will remove \"\(entry.recognizedWord)\" from your vocabulary.")
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "character.book.closed.fill")
                .font(.system(size: 50))
                .foregroundStyle(.teal.opacity(0.5))

            Text("No Vocabulary Words")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Add names, companies, acronyms, and slang\nto improve transcription accuracy")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                showAddSheet = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Word")
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.teal)
                .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .padding()
    }
}

// MARK: - Vocabulary Entry Row

struct VocabularyEntryRow: View {
    let entry: VocabularyEntry
    let colorScheme: ColorScheme
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                // Enable/disable toggle
                Button(action: {
                    HapticManager.selection()
                    onToggle()
                }) {
                    Image(systemName: entry.isEnabled ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(entry.isEnabled ? entry.category.color : Color.secondary.opacity(0.3))
                }
                .buttonStyle(.plain)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(entry.recognizedWord)
                            .font(.callout)
                            .foregroundStyle(entry.isEnabled ? .secondary : .tertiary)
                            .strikethrough(!entry.isEnabled)

                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Text(entry.replacementWord)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(entry.isEnabled ? .primary : .secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Vocabulary Editor Sheet

struct VocabularyEditorSheet: View {
    let entry: VocabularyEntry?
    let onSave: (VocabularyEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var recognizedWord: String = ""
    @State private var replacementWord: String = ""
    @State private var selectedCategory: VocabularyCategory = .name
    @State private var isEnabled: Bool = true

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    private var isValid: Bool {
        !recognizedWord.trimmingCharacters(in: .whitespaces).isEmpty &&
        !replacementWord.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isEditing: Bool {
        entry != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                List {
                    // Words Section
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recognized As")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)

                            TextField("e.g., john doe", text: $recognizedWord)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .listRowBackground(rowBackground)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Replace With")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)

                            TextField("e.g., John Doe", text: $replacementWord)
                                .autocorrectionDisabled()
                        }
                        .listRowBackground(rowBackground)
                    } header: {
                        Text("Word Replacement")
                    } footer: {
                        Text("The recognized word is what the transcription might produce. The replacement is the correct form.")
                    }

                    // Category Section
                    Section {
                        ForEach(VocabularyCategory.allCases) { category in
                            Button(action: {
                                HapticManager.selection()
                                selectedCategory = category
                            }) {
                                HStack {
                                    Image(systemName: category.icon)
                                        .font(.body)
                                        .foregroundStyle(category.color)
                                        .frame(width: 24)

                                    Text(category.displayName)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if selectedCategory == category {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.teal)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(rowBackground)
                        }
                    } header: {
                        Text("Category")
                    }

                    // Enable Section
                    Section {
                        Toggle("Enabled", isOn: $isEnabled)
                            .listRowBackground(rowBackground)
                    } footer: {
                        Text("Disabled words will not be replaced during transcription.")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(isEditing ? "Edit Word" : "Add Word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveEntry()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let entry = entry {
                    recognizedWord = entry.recognizedWord
                    replacementWord = entry.replacementWord
                    selectedCategory = entry.category
                    isEnabled = entry.isEnabled
                }
            }
        }
    }

    private func saveEntry() {
        let savedEntry = VocabularyEntry(
            id: entry?.id ?? UUID(),
            recognizedWord: recognizedWord.trimmingCharacters(in: .whitespaces),
            replacementWord: replacementWord.trimmingCharacters(in: .whitespaces),
            category: selectedCategory,
            isEnabled: isEnabled,
            createdAt: entry?.createdAt ?? Date(),
            updatedAt: Date()
        )
        onSave(savedEntry)
        dismiss()
    }
}

#Preview("Vocabulary View") {
    NavigationStack {
        VocabularyView()
            .environmentObject(SharedSettings.shared)
    }
}
