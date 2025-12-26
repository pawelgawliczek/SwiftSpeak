//
//  HistoryView.swift
//  SwiftSpeak
//
//  Past transcriptions list
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme
    @State private var searchText = ""
    @State private var selectedRecord: TranscriptionRecord?
    @State private var showDeleteConfirmation = false
    @State private var isSelecting = false
    @State private var selectedRecords: Set<UUID> = []

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    var filteredHistory: [TranscriptionRecord] {
        if searchText.isEmpty {
            return settings.transcriptionHistory
        }
        return settings.transcriptionHistory.filter {
            $0.text.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundColor.ignoresSafeArea()

                if settings.transcriptionHistory.isEmpty {
                    EmptyHistoryView()
                } else {
                    List {
                        ForEach(filteredHistory) { record in
                            HStack(spacing: 12) {
                                // Selection checkbox
                                if isSelecting {
                                    Image(systemName: selectedRecords.contains(record.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(selectedRecords.contains(record.id) ? AppTheme.accent : .secondary)
                                        .onTapGesture {
                                            HapticManager.lightTap()
                                            toggleSelection(record.id)
                                        }
                                }

                                HistoryRowView(record: record, colorScheme: colorScheme)
                                    .onTapGesture {
                                        if isSelecting {
                                            HapticManager.lightTap()
                                            toggleSelection(record.id)
                                        } else {
                                            HapticManager.lightTap()
                                            selectedRecord = record
                                        }
                                    }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: deleteRecords)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .searchable(text: $searchText, prompt: "Search transcriptions")
                }

                // Bottom action bar when selecting
                if isSelecting && !selectedRecords.isEmpty {
                    VStack {
                        Spacer()

                        HStack(spacing: 16) {
                            Button(action: {
                                HapticManager.lightTap()
                                selectedRecords = Set(filteredHistory.map { $0.id })
                            }) {
                                Text("Select All")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(AppTheme.accent)
                            }

                            Spacer()

                            Text("\(selectedRecords.count) selected")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button(action: {
                                HapticManager.mediumTap()
                                showDeleteConfirmation = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                    Text("Delete")
                                }
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.red)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !settings.transcriptionHistory.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            HapticManager.lightTap()
                            withAnimation {
                                isSelecting.toggle()
                                if !isSelecting {
                                    selectedRecords.removeAll()
                                }
                            }
                        }) {
                            Text(isSelecting ? "Cancel" : "Select")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(action: {
                                HapticManager.lightTap()
                                showDeleteConfirmation = true
                            }) {
                                Label("Clear All History", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                }
            }
            .sheet(item: $selectedRecord) { record in
                HistoryDetailView(record: record)
                    .environmentObject(settings)
            }
            .alert(isSelecting ? "Delete Selected" : "Clear History", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button(isSelecting ? "Delete \(selectedRecords.count)" : "Clear All", role: .destructive) {
                    if isSelecting {
                        deleteSelectedRecords()
                    } else {
                        settings.clearHistory()
                    }
                }
            } message: {
                Text(isSelecting
                     ? "This will permanently delete \(selectedRecords.count) transcription\(selectedRecords.count == 1 ? "" : "s")."
                     : "This will permanently delete all transcription history.")
            }
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedRecords.contains(id) {
            selectedRecords.remove(id)
        } else {
            selectedRecords.insert(id)
        }
    }

    private func deleteRecords(at offsets: IndexSet) {
        let recordsToDelete = offsets.map { filteredHistory[$0].id }
        settings.transcriptionHistory.removeAll { recordsToDelete.contains($0.id) }
    }

    private func deleteSelectedRecords() {
        HapticManager.success()
        settings.transcriptionHistory.removeAll { selectedRecords.contains($0.id) }
        selectedRecords.removeAll()
        isSelecting = false
    }
}

// MARK: - Empty History View
struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("No Transcriptions Yet")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Your transcription history will appear here")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
    }
}

// MARK: - History Row View
struct HistoryRowView: View {
    let record: TranscriptionRecord
    let colorScheme: ColorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with mode and time
            HStack {
                // Mode badge
                HStack(spacing: 4) {
                    Image(systemName: record.mode.icon)
                        .font(.caption2)
                    Text(record.mode.displayName)
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.accent.opacity(0.15))
                .clipShape(Capsule())

                if record.translated {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.caption2)
                        Text(record.targetLanguage?.displayName ?? "")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.15))
                    .clipShape(Capsule())
                }

                Spacer()

                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Text preview
            Text(record.text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)

            // Footer with duration and provider
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(formattedDuration)
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: record.provider.icon)
                        .font(.caption2)
                    Text(record.provider.displayName)
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 8, y: 2)
        .padding(.vertical, 4)
    }

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: record.timestamp, relativeTo: Date())
    }

    private var formattedDuration: String {
        let seconds = Int(record.duration)
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            return "\(seconds / 60)m \(seconds % 60)s"
        }
    }
}

// MARK: - History Detail View
struct HistoryDetailView: View {
    let record: TranscriptionRecord
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var settings: SharedSettings
    @State private var copied = false
    @State private var isReprocessing = false
    @State private var selectedMode: FormattingMode?

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Metadata
                        VStack(spacing: 16) {
                            MetadataRow(icon: "calendar", label: "Date", value: formattedFullDate)
                            MetadataRow(icon: "clock", label: "Duration", value: formattedDuration)
                            MetadataRow(icon: record.mode.icon, label: "Mode", value: record.mode.displayName)
                            MetadataRow(icon: record.provider.icon, label: "Provider", value: record.provider.displayName)

                            if record.translated, let lang = record.targetLanguage {
                                MetadataRow(icon: "globe", label: "Translated to", value: "\(lang.flag) \(lang.displayName)")
                            }
                        }
                        .padding(16)
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 8, y: 2)

                        // Text content
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Transcription")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)

                            Text(record.text)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                        }
                        .padding(16)
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 8, y: 2)

                        // Reprocess with different mode
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Reprocess with Different Mode")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(FormattingMode.allCases.filter { $0 != record.mode }) { mode in
                                    Button(action: {
                                        reprocessWithMode(mode)
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: mode.icon)
                                                .font(.caption)
                                            Text(mode.displayName)
                                                .font(.footnote.weight(.medium))
                                        }
                                        .foregroundStyle(selectedMode == mode ? .white : AppTheme.accent)
                                        .frame(maxWidth: .infinity)
                                        .frame(minHeight: 40)
                                        .background(
                                            selectedMode == mode
                                                ? AppTheme.accent
                                                : AppTheme.accent.opacity(0.15)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isReprocessing)
                                }
                            }

                            if isReprocessing {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Reprocessing...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 8)
                            }
                        }
                        .padding(16)
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 8, y: 2)

                        // Copy button
                        Button(action: copyText) {
                            HStack {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                Text(copied ? "Copied!" : "Copy to Clipboard")
                            }
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                            .background(copied ? Color.green : AppTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: (copied ? Color.green : AppTheme.accent).opacity(0.3), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func reprocessWithMode(_ mode: FormattingMode) {
        HapticManager.mediumTap()
        selectedMode = mode
        isReprocessing = true

        // Simulate reprocessing delay (in real app, this would call the formatting API)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Create new record with the new mode
            let newRecord = TranscriptionRecord(
                text: record.text, // In real app, this would be reformatted text from API
                mode: mode,
                provider: record.provider,
                duration: record.duration,
                translated: record.translated,
                targetLanguage: record.targetLanguage
            )

            // Add to history
            settings.transcriptionHistory.insert(newRecord, at: 0)

            HapticManager.success()
            isReprocessing = false

            // Dismiss after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismiss()
            }
        }
    }

    private var formattedFullDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: record.timestamp)
    }

    private var formattedDuration: String {
        let seconds = Int(record.duration)
        if seconds < 60 {
            return "\(seconds) seconds"
        } else {
            return "\(seconds / 60)m \(seconds % 60)s"
        }
    }

    private func copyText() {
        UIPasteboard.general.string = record.text
        HapticManager.success()
        withAnimation(AppTheme.quickSpring) {
            copied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(AppTheme.quickSpring) {
                copied = false
            }
        }
    }
}

struct MetadataRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Preview Helpers
extension TranscriptionRecord {
    static var sampleData: [TranscriptionRecord] {
        [
            TranscriptionRecord(
                text: "Hello, this is a test transcription. I'm speaking naturally and the app is converting my speech to text in real time.",
                mode: .raw,
                provider: .openAI,
                duration: 12.5
            ),
            TranscriptionRecord(
                text: "Dear Mr. Johnson, I hope this email finds you well. I wanted to follow up on our meeting last week regarding the Q4 roadmap.",
                mode: .email,
                provider: .openAI,
                duration: 25.3
            ),
            TranscriptionRecord(
                text: "Hola, esto es una prueba de traducción al español.",
                mode: .raw,
                provider: .openAI,
                duration: 8.2,
                translated: true,
                targetLanguage: .spanish
            ),
            TranscriptionRecord(
                text: "Quick voice memo: Remember to call the doctor tomorrow at 3pm and pick up groceries on the way home.",
                mode: .casual,
                provider: .openAI,
                duration: 6.1
            ),
            TranscriptionRecord(
                text: "The committee hereby resolves to adopt the proposed amendments to the bylaws, effective immediately upon ratification.",
                mode: .formal,
                provider: .openAI,
                duration: 15.7
            )
        ]
    }
}

// MARK: - Previews
#Preview("Empty - Dark") {
    HistoryView()
        .environmentObject(SharedSettings.shared)
        .preferredColorScheme(.dark)
}

#Preview("Empty - Light") {
    HistoryView()
        .environmentObject(SharedSettings.shared)
        .preferredColorScheme(.light)
}

#Preview("With Data - Dark") {
    let settings = SharedSettings.shared
    settings.transcriptionHistory = TranscriptionRecord.sampleData
    return HistoryView()
        .environmentObject(settings)
        .preferredColorScheme(.dark)
}

#Preview("With Data - Light") {
    let settings = SharedSettings.shared
    settings.transcriptionHistory = TranscriptionRecord.sampleData
    return HistoryView()
        .environmentObject(settings)
        .preferredColorScheme(.light)
}
