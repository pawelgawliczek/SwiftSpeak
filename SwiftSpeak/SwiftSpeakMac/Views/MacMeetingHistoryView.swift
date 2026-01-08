//
//  MacMeetingHistoryView.swift
//  SwiftSpeakMac
//
//  Meeting history list with status tracking and retry support
//

import SwiftUI
import SwiftSpeakCore

struct MacMeetingHistoryView: View {
    @ObservedObject private var historyManager = MeetingHistoryManager.shared
    @State private var selectedMeeting: MeetingRecord?
    @State private var showingDeleteConfirmation = false
    @State private var meetingToDelete: MeetingRecord?
    @State private var isRetrying = false
    @State private var retryError: String?

    // Injected orchestrator for retry
    let orchestrator: MeetingRecordingOrchestrator?

    var body: some View {
        HSplitView {
            // Sidebar - Meeting list
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Meetings")
                        .font(.headline)
                    Spacer()
                    Menu {
                        Button("Clean up old meetings") {
                            historyManager.cleanupOldMeetings()
                        }
                        Button("Clean up orphaned audio") {
                            historyManager.cleanupOrphanedAudio()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 24)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                // Meeting list
                List(selection: $selectedMeeting) {
                    if historyManager.meetings.isEmpty {
                        emptyState
                    } else {
                        ForEach(historyManager.meetings) { meeting in
                            MeetingRowView(meeting: meeting)
                                .tag(meeting)
                                .contextMenu {
                                    meetingContextMenu(for: meeting)
                                }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)

            // Detail view
            VStack(spacing: 0) {
                if let meeting = selectedMeeting {
                    MeetingDetailView(
                        meeting: meeting,
                        orchestrator: orchestrator,
                        onRetry: { await retryMeeting(meeting) }
                    )
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text("Select a meeting")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 400)
        }
        .alert("Delete Meeting", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let meeting = meetingToDelete {
                    historyManager.deleteMeeting(id: meeting.id)
                }
            }
        } message: {
            Text("Are you sure you want to delete this meeting? This cannot be undone.")
        }
        .alert("Retry Failed", isPresented: .constant(retryError != nil)) {
            Button("OK") { retryError = nil }
        } message: {
            Text(retryError ?? "")
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No meetings yet")
                .font(.headline)
            Text("Recorded meetings will appear here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private func meetingContextMenu(for meeting: MeetingRecord) -> some View {
        if meeting.status.canRetry {
            Button {
                Task { await retryMeeting(meeting) }
            } label: {
                Label("Retry Transcription", systemImage: "arrow.clockwise")
            }
        }

        if meeting.status == .completed {
            Button {
                copyTranscript(meeting)
            } label: {
                Label("Copy Transcript", systemImage: "doc.on.doc")
            }
        }

        Divider()

        if meeting.status.canDelete {
            Button(role: .destructive) {
                meetingToDelete = meeting
                showingDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func retryMeeting(_ meeting: MeetingRecord) async {
        guard let orchestrator = orchestrator else {
            macLog("Retry failed: No orchestrator configured", category: "Meeting", level: .error)
            retryError = "Retry not available - orchestrator not configured"
            return
        }

        isRetrying = true
        defer { isRetrying = false }

        macLog("Starting retry for meeting: \(meeting.id)", category: "Meeting")

        do {
            try await orchestrator.retryTranscription(meetingId: meeting.id)
            macLog("Retry completed successfully", category: "Meeting")
        } catch {
            macLog("Retry failed: \(error.localizedDescription)", category: "Meeting", level: .error)
            retryError = error.localizedDescription
        }
    }

    private func copyTranscript(_ meeting: MeetingRecord) {
        let transcript = meeting.bestTranscript
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcript, forType: .string)
    }
}

// MARK: - Meeting Row View

struct MeetingRowView: View {
    let meeting: MeetingRecord

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
        HStack(spacing: 12) {
            // Status icon - show spinner for active processing
            if isActivelyProcessing {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: meeting.status.iconName)
                    .foregroundStyle(statusColor)
                    .font(.title3)
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(meeting.formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.tertiary)

                    Text(meeting.recordedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Status badge
            Text(meeting.status.displayName)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.15))
                .foregroundStyle(statusColor)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
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
}

// MARK: - Meeting Detail View

struct MeetingDetailView: View {
    let meeting: MeetingRecord
    let orchestrator: MeetingRecordingOrchestrator?
    let onRetry: () async -> Void

    @State private var isRetrying = false

    var body: some View {
        VStack(spacing: 0) {
            // Title bar with actions
            HStack {
                Text(meeting.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Spacer()

                // Action buttons
                if meeting.status.canRetry {
                    Button {
                        Task {
                            isRetrying = true
                            await onRetry()
                            isRetrying = false
                        }
                    } label: {
                        if isRetrying {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Label("Retry", systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRetrying)
                }

                if meeting.status == .completed {
                    Button {
                        copyToClipboard()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection

                    Divider()

                    // Status/Error section
                    if meeting.status == .transcriptionFailed {
                        errorSection
                    }

                    // Transcript section
                    if !meeting.plainTranscript.isEmpty {
                        transcriptSection
                    }

                    // Notes section
                    if let notes = meeting.generatedNotes {
                        notesSection(notes)
                    }

                    // Metadata
                    metadataSection
                }
                .padding(20)
            }
        }
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

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if isActivelyProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: meeting.status.iconName)
                        .font(.title2)
                        .foregroundStyle(statusColor)
                }

                Text(meeting.status.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            // Show processing hint for active meetings
            if isActivelyProcessing {
                Text("This meeting is being processed in the background. You can close this window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }

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
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Transcript", systemImage: "text.alignleft")
                .font(.headline)

            if let diarized = meeting.diarizedTranscript {
                // Show diarized transcript with speaker segments
                ForEach(Array(diarized.segments.enumerated()), id: \.offset) { _, segment in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
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
                    .padding(.vertical, 4)
                }
            } else {
                Text(meeting.plainTranscript)
                    .font(.body)
            }
        }
    }

    @ViewBuilder
    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Meeting Notes", systemImage: "note.text")
                .font(.headline)

            Text(notes)
                .font(.body)
        }
    }

    @ViewBuilder
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Details", systemImage: "info.circle")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Provider")
                        .foregroundStyle(.secondary)
                    Text(meeting.provider ?? "Unknown")
                }

                if let cost = meeting.estimatedCost {
                    GridRow {
                        Text("Est. Cost")
                            .foregroundStyle(.secondary)
                        Text(String(format: "$%.4f", cost))
                    }
                }

                GridRow {
                    Text("Audio Source")
                        .foregroundStyle(.secondary)
                    Text(meeting.settings.audioSource.displayName)
                }

                if meeting.settings.requireDiarization {
                    GridRow {
                        Text("Diarization")
                            .foregroundStyle(.secondary)
                        Text("Enabled")
                    }
                }
            }
            .font(.subheadline)
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

    private func copyToClipboard() {
        let content = meeting.bestTranscript
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }
}

// MARK: - Preview

#Preview {
    MacMeetingHistoryView(orchestrator: nil)
}
