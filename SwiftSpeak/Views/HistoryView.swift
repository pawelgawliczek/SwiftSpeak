//
//  HistoryView.swift
//  SwiftSpeak
//
//  Past transcriptions list
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var settings: SharedSettings
    @State private var searchText = ""
    @State private var selectedRecord: TranscriptionRecord?
    @State private var showDeleteConfirmation = false

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
                AppTheme.darkBase.ignoresSafeArea()

                if settings.transcriptionHistory.isEmpty {
                    EmptyHistoryView()
                } else {
                    List {
                        ForEach(filteredHistory) { record in
                            HistoryRowView(record: record)
                                .listRowBackground(Color.white.opacity(0.05))
                                .listRowSeparator(.hidden)
                                .onTapGesture {
                                    HapticManager.lightTap()
                                    selectedRecord = record
                                }
                        }
                        .onDelete(perform: deleteRecords)
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "Search transcriptions")
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !settings.transcriptionHistory.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            HapticManager.lightTap()
                            showDeleteConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .sheet(item: $selectedRecord) { record in
                HistoryDetailView(record: record)
            }
            .alert("Clear History", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    settings.clearHistory()
                }
            } message: {
                Text("This will permanently delete all transcription history.")
            }
        }
    }

    private func deleteRecords(at offsets: IndexSet) {
        var history = settings.transcriptionHistory
        history.remove(atOffsets: offsets)
        settings.transcriptionHistory = history
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
                .background(AppTheme.accent.opacity(0.2))
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
                    .background(Color.purple.opacity(0.2))
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
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
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
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.darkBase.ignoresSafeArea()

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
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))

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
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))

                        // Copy button
                        Button(action: copyText) {
                            HStack {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                Text(copied ? "Copied!" : "Copy to Clipboard")
                            }
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(
                                    colors: copied ? [.green, .green] : [AppTheme.accent, AppTheme.accentSecondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                        }
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

#Preview {
    HistoryView()
        .environmentObject(SharedSettings.shared)
}
