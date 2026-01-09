//
//  MeetingHistoryView.swift
//  SwiftSpeak
//
//  iOS meeting history list with navigation to details
//

import SwiftUI
import SwiftSpeakCore

struct MeetingHistoryView: View {
    @ObservedObject private var historyManager = MeetingHistoryManager.shared
    @StateObject private var orchestrator = MeetingRecordingOrchestrator()

    @State private var showingDeleteConfirmation = false
    @State private var meetingToDelete: MeetingRecord?
    @State private var retryError: String?
    @State private var showRetryError = false

    var body: some View {
        Group {
            if historyManager.meetings.isEmpty {
                emptyState
            } else {
                meetingsList
            }
        }
        .navigationTitle("Meetings")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        historyManager.cleanupOldMeetings()
                        HapticManager.success()
                    } label: {
                        Label("Clean up old meetings", systemImage: "trash.circle")
                    }

                    Button {
                        historyManager.cleanupOrphanedAudio()
                        HapticManager.success()
                    } label: {
                        Label("Clean up orphaned audio", systemImage: "waveform.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Delete Meeting", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let meeting = meetingToDelete {
                    historyManager.deleteMeeting(id: meeting.id)
                    HapticManager.mediumTap()
                }
            }
        } message: {
            Text("Are you sure you want to delete this meeting? This cannot be undone.")
        }
        .alert("Retry Failed", isPresented: $showRetryError) {
            Button("OK") { retryError = nil }
        } message: {
            Text(retryError ?? "An unknown error occurred")
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No meetings yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Recorded meetings will appear here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Meetings List

    @ViewBuilder
    private var meetingsList: some View {
        List {
            ForEach(historyManager.meetings) { meeting in
                NavigationLink(value: meeting) {
                    MeetingRowView(meeting: meeting)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if meeting.status.canDelete {
                        Button(role: .destructive) {
                            meetingToDelete = meeting
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if meeting.status.canRetry {
                        Button {
                            Task { await retryMeeting(meeting) }
                        } label: {
                            Label("Retry", systemImage: "arrow.clockwise")
                        }
                        .tint(.orange)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: MeetingRecord.self) { [self] meeting in
            if meeting.status.canRetry {
                MeetingDetailView(meeting: meeting) {
                    await self.retryMeeting(meeting)
                }
            } else {
                MeetingDetailView(meeting: meeting, onRetry: nil)
            }
        }
    }

    // MARK: - Actions

    private func retryMeeting(_ meeting: MeetingRecord) async {
        appLog("Starting retry for meeting: \(meeting.id)", category: "Meeting")
        HapticManager.lightTap()

        do {
            try await orchestrator.retryTranscription(meetingId: meeting.id)
            appLog("Retry completed successfully", category: "Meeting")
            HapticManager.success()
        } catch {
            appLog("Retry failed: \(error.localizedDescription)", category: "Meeting", level: .error)
            retryError = error.localizedDescription
            showRetryError = true
            HapticManager.error()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MeetingHistoryView()
    }
}
