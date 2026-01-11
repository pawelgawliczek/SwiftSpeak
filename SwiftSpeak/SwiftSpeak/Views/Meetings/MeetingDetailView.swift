//
//  MeetingDetailView.swift
//  SwiftSpeak
//
//  Full-screen detail view for a single meeting (matches Context/PowerMode detail style)
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

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header section
                headerSection

                // Action buttons
                actionButtons

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

                // Stats section
                statsSection
            }
            .padding(16)
        }
        .background(AppTheme.darkBase.ignoresSafeArea())
        .navigationTitle(meeting.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if meeting.status == .completed {
                        Button {
                            showShareSheet = true
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            copyToClipboard()
                            HapticManager.success()
                        } label: {
                            Label("Copy Transcript", systemImage: "doc.on.doc")
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
                            Label("Retry Transcription", systemImage: "arrow.clockwise")
                        }
                        .disabled(isRetrying)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            MeetingShareSheet(items: [meeting.bestTranscript])
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Status icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 80, height: 80)

                if isActivelyProcessing {
                    ProgressView()
                        .scaleEffect(1.2)
                } else {
                    Image(systemName: meeting.status.iconName)
                        .font(.system(size: 36))
                        .foregroundStyle(statusColor)
                }
            }

            // Status badge
            HStack(spacing: 4) {
                if isActivelyProcessing {
                    ProgressView()
                        .scaleEffect(0.6)
                }
                Text(meeting.status.displayName)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.15))
            .clipShape(Capsule())

            // Processing hint
            if isActivelyProcessing {
                Text("This meeting is being processed. You can close this screen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Metadata row
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(meeting.formattedDuration)
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text(meeting.recordedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)

                if meeting.speakerCount > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2")
                            .font(.caption)
                        Text("\(meeting.speakerCount)")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.blue.opacity(0.8))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            if meeting.status == .completed {
                Button {
                    copyToClipboard()
                    HapticManager.success()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.doc")
                            .font(.body.weight(.semibold))
                        Text("Copy")
                            .font(.callout.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(statusColor.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                }

                Button {
                    showShareSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.body.weight(.semibold))
                        Text("Share")
                            .font(.callout.weight(.semibold))
                    }
                    .foregroundStyle(.primary)
                    .frame(width: 100)
                    .frame(height: 50)
                    .background(Color.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                }
            } else if meeting.status.canRetry, let onRetry = onRetry {
                Button {
                    Task {
                        isRetrying = true
                        await onRetry()
                        isRetrying = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isRetrying {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.body.weight(.semibold))
                        }
                        Text("Retry Transcription")
                            .font(.callout.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.orange.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                }
                .disabled(isRetrying)
            }
        }
    }

    // MARK: - Error Section

    private var errorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ERROR")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("Transcription Failed")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.red)
                }

                if let error = meeting.errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }

                Text("Audio is preserved. You can retry transcription at any time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if meeting.transcriptionAttempts > 1 {
                    Text("Attempted \(meeting.transcriptionAttempts) times")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
    }

    // MARK: - Transcript Section

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TRANSCRIPT")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let diarized = meeting.diarizedTranscript {
                // Diarized transcript with speaker segments
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(diarized.segments.enumerated()), id: \.offset) { _, segment in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(diarized.displayName(for: segment.speaker))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.blue)

                                if meeting.settings.includeTimestamps {
                                    Text(segment.formattedTimestamp)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            Text(segment.text)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                    }
                }
            } else {
                Text(meeting.plainTranscript)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            }
        }
    }

    // MARK: - Notes Section

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MEETING NOTES")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(notes)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DETAILS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                MeetingDetailRow(label: "Provider", value: meeting.provider ?? "Unknown")

                if let cost = meeting.estimatedCost {
                    Divider()
                        .padding(.horizontal, 16)
                    MeetingDetailRow(label: "Est. Cost", value: String(format: "$%.4f", cost))
                }

                Divider()
                    .padding(.horizontal, 16)
                MeetingDetailRow(label: "Audio Source", value: meeting.settings.audioSource.displayName)

                if meeting.settings.requireDiarization {
                    Divider()
                        .padding(.horizontal, 16)
                    MeetingDetailRow(label: "Diarization", value: "Enabled")
                }

                if let obsidianPath = meeting.obsidianNotePath {
                    Divider()
                        .padding(.horizontal, 16)
                    MeetingDetailRow(label: "Obsidian", value: obsidianPath)
                }
            }
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STATS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                MeetingStatCard(
                    title: "Recorded",
                    value: meeting.recordedAt.formatted(date: .abbreviated, time: .omitted),
                    icon: "calendar"
                )
                MeetingStatCard(
                    title: "Duration",
                    value: meeting.formattedDuration,
                    icon: "clock"
                )
            }
        }
    }

    // MARK: - Helpers

    private func copyToClipboard() {
        UIPasteboard.general.string = meeting.bestTranscript
    }
}

// MARK: - Meeting Detail Row

private struct MeetingDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Meeting Stat Card

private struct MeetingStatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
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
    .preferredColorScheme(.dark)
}
