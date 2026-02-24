//
//  PowerTabView.swift
//  SwiftSpeak
//
//  Phase 4: Power Tab with segmented control for Modes and Contexts
//

import SwiftUI
import SwiftSpeakCore

struct PowerTabView: View {
    enum Tab: String, CaseIterable {
        case contexts = "Contexts"
        case meetings = "Meetings"
        case modes = "Modes"
    }

    @State private var selectedTab: Tab = .contexts

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header subtitle
                Text("Power tools")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                // Segmented control
                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

                // Content based on selection - use frame to allow scrolling
                Group {
                    switch selectedTab {
                    case .contexts:
                        ContextsListContent()
                    case .meetings:
                        MeetingsListContent()
                    case .modes:
                        PowerModeListContent()
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .background(AppTheme.darkBase.ignoresSafeArea())
            .navigationTitle("Power")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Meetings List Content

/// Card-based meeting list matching Context/PowerMode style
private struct MeetingsListContent: View {
    @ObservedObject private var historyManager = MeetingHistoryManager.shared
    @StateObject private var orchestrator = MeetingRecordingOrchestrator()

    @State private var showingDeleteConfirmation = false
    @State private var meetingToDelete: MeetingRecord?
    @State private var navigateToDetail: MeetingRecord?
    @State private var retryError: String?
    @State private var showRetryError = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header section
                headerSection

                if historyManager.meetings.isEmpty {
                    emptyState
                } else {
                    // Meetings list
                    LazyVStack(spacing: 12) {
                        ForEach(historyManager.meetings) { meeting in
                            SwipeableMeetingCard(
                                meeting: meeting,
                                onTap: {
                                    HapticManager.lightTap()
                                    navigateToDetail = meeting
                                },
                                onDelete: {
                                    meetingToDelete = meeting
                                    showingDeleteConfirmation = true
                                },
                                onRetry: meeting.status.canRetry ? {
                                    Task { await retryMeeting(meeting) }
                                } : nil
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Bottom spacing
                Spacer()
                    .frame(height: 32)
            }
        }
        .navigationDestination(item: $navigateToDetail) { meeting in
            if meeting.status.canRetry {
                MeetingDetailView(meeting: meeting) {
                    await retryMeeting(meeting)
                }
            } else {
                MeetingDetailView(meeting: meeting, onRetry: nil)
            }
        }
        .alert("Delete Meeting?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                meetingToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let meeting = meetingToDelete {
                    withAnimation(AppTheme.smoothSpring) {
                        historyManager.deleteMeeting(id: meeting.id)
                    }
                    HapticManager.mediumTap()
                }
                meetingToDelete = nil
            }
        } message: {
            if let meeting = meetingToDelete {
                Text("Are you sure you want to delete \"\(meeting.title)\"? This action cannot be undone.")
            }
        }
        .alert("Retry Failed", isPresented: $showRetryError) {
            Button("OK") { retryError = nil }
        } message: {
            Text(retryError ?? "An unknown error occurred")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recorded meetings and their transcriptions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.accentGradient)

            Text("No Meetings")
                .font(.headline)

            Text("Start a meeting recording from the home screen")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
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
    PowerTabView()
        .environmentObject(SharedSettings.shared)
        .preferredColorScheme(.dark)
}
