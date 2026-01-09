//
//  MeetingDetailView.swift
//  SwiftSpeak
//
//  Full-screen detail view for a single meeting
//

import SwiftUI
import SwiftSpeakCore

struct MeetingDetailView: View {
    let meeting: MeetingRecord
    let onRetry: (() async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var isRetrying = false
    @State private var showShareSheet = false

    init(meeting: MeetingRecord, onRetry: (() async -> Void)? = nil) {
        self.meeting = meeting
        self.onRetry = onRetry
    }

    /// Whether this meeting is actively processing
    private var isActivelyProcessing: Bool {
        switch meeting.status {
        case .recording, .pendingTranscription, .transcribing:
            return true
        default:
            return false
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header section
                headerSection

                Divider()

                // Error section if failed
                if meeting.status == .transcriptionFailed {
                    errorSection
                }

                // Transcript section
                if !meeting.plainTranscript.isEmpty {
                    transcriptSection
                }

                // Notes section
                if let notes = meeting.generatedNotes, !notes.isEmpty {
                    notesSection(notes)
                }

                // Metadata section
                metadataSection
            }
            .padding()
        }
        .navigationTitle(meeting.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if meeting.status == .completed {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }

                    Button {
                        copyToClipboard()
                        HapticManager.success()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }

                if meeting.status.canRetry, let onRetry = onRetry {
                    Button {
                        Task {
                            isRetrying = true
                            await onRetry()
                            isRetrying = false
                        }
                    } label: {
                        if isRetrying {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isRetrying)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            MeetingShareSheet(items: [meeting.bestTranscript])
        }
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status row
            HStack(spacing: 12) {
                if isActivelyProcessing {
                    ProgressView()
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: meeting.status.iconName)
                        .font(.title2)
                        .foregroundStyle(statusColor)
                }

                Text(meeting.status.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            // Processing hint
            if isActivelyProcessing {
                Text("This meeting is being processed. You can close this screen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Metadata row
            HStack(spacing: 16) {
                Label(meeting.formattedDuration, systemImage: "clock")
                Label(meeting.recordedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                if meeting.speakerCount > 1 {
                    Label("\(meeting.speakerCount) speakers", systemImage: "person.2")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Error Section

    @ViewBuilder
    private var errorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Transcription Failed", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.red)

            if let error = meeting.errorMessage {
                Text(error)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Text("Audio is preserved. You can retry transcription at any time.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if meeting.transcriptionAttempts > 1 {
                Text("Attempted \(meeting.transcriptionAttempts) times")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if let onRetry = onRetry {
                Button {
                    Task {
                        isRetrying = true
                        await onRetry()
                        isRetrying = false
                    }
                } label: {
                    HStack {
                        if isRetrying {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Retry Transcription")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRetrying)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Transcript Section

    @ViewBuilder
    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Transcript", systemImage: "text.alignleft")
                .font(.headline)

            if let diarized = meeting.diarizedTranscript {
                // Diarized transcript with speaker segments
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(diarized.segments.enumerated()), id: \.offset) { _, segment in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(diarized.displayName(for: segment.speaker))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)

                                if meeting.settings.includeTimestamps {
                                    Text(segment.formattedTimestamp)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            Text(segment.text)
                                .font(.body)
                        }
                    }
                }
            } else {
                Text(meeting.plainTranscript)
                    .font(.body)
            }
        }
    }

    // MARK: - Notes Section

    @ViewBuilder
    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Meeting Notes", systemImage: "note.text")
                .font(.headline)

            Text(notes)
                .font(.body)
        }
    }

    // MARK: - Metadata Section

    @ViewBuilder
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Details", systemImage: "info.circle")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                MeetingMetadataRow(label: "Provider", value: meeting.provider ?? "Unknown")

                if let cost = meeting.estimatedCost {
                    MeetingMetadataRow(label: "Est. Cost", value: String(format: "$%.4f", cost))
                }

                MeetingMetadataRow(label: "Audio Source", value: meeting.settings.audioSource.displayName)

                if meeting.settings.requireDiarization {
                    MeetingMetadataRow(label: "Diarization", value: "Enabled")
                }

                if let obsidianPath = meeting.obsidianNotePath {
                    MeetingMetadataRow(label: "Obsidian", value: obsidianPath)
                }
            }
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch meeting.status {
        case .recording:
            return .red
        case .pendingTranscription, .transcribing:
            return .orange
        case .transcriptionFailed:
            return .red
        case .completed:
            return .green
        case .cancelled:
            return .gray
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = meeting.bestTranscript
    }
}

// MARK: - Meeting Metadata Row

private struct MeetingMetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
    }
}

// MARK: - Meeting Share Sheet

private struct MeetingShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MeetingDetailView(
            meeting: MeetingRecord(
                title: "Team Standup",
                recordedAt: Date(),
                duration: 1234,
                status: .completed,
                diarizedTranscript: DiarizedTranscript(
                    segments: [
                        SpeakerSegment(speaker: "A", text: "Good morning everyone. Let's go around and share updates.", startMs: 0, endMs: 5000),
                        SpeakerSegment(speaker: "B", text: "I finished the API integration yesterday. Now working on tests.", startMs: 5000, endMs: 12000),
                        SpeakerSegment(speaker: "C", text: "I'm blocked on the design review. Waiting for feedback.", startMs: 12000, endMs: 18000)
                    ],
                    speakerNames: ["A": "Alice", "B": "Bob", "C": "Charlie"]
                ),
                plainTranscript: "Good morning everyone. Let's go around and share updates.",
                estimatedCost: 0.0515,
                provider: "AssemblyAI"
            )
        )
    }
}
