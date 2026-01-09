//
//  MeetingRowView.swift
//  SwiftSpeak
//
//  Reusable row component for meeting list
//

import SwiftUI
import SwiftSpeakCore

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
            ZStack {
                if isActivelyProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: meeting.status.iconName)
                        .font(.title3)
                        .foregroundStyle(statusColor)
                }
            }
            .frame(width: 28, height: 28)

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

                    if meeting.speakerCount > 1 {
                        Text("•")
                            .foregroundStyle(.tertiary)

                        HStack(spacing: 2) {
                            Image(systemName: "person.2.fill")
                                .font(.caption2)
                            Text("\(meeting.speakerCount)")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Status badge
            Text(meeting.status.displayName)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.15))
                .foregroundStyle(statusColor)
                .clipShape(Capsule())
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
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

// MARK: - Preview

#Preview {
    List {
        MeetingRowView(meeting: MeetingRecord(
            title: "Team Standup",
            recordedAt: Date(),
            duration: 1234,
            status: .completed
        ))

        MeetingRowView(meeting: MeetingRecord(
            title: "Product Planning Q4",
            recordedAt: Date().addingTimeInterval(-86400),
            duration: 3600,
            status: .transcribing
        ))

        MeetingRowView(meeting: MeetingRecord(
            title: "Client Call - Acme Corp",
            recordedAt: Date().addingTimeInterval(-172800),
            duration: 2700,
            status: .transcriptionFailed,
            errorMessage: "Network timeout"
        ))

        MeetingRowView(meeting: MeetingRecord(
            title: "Weekly Review",
            recordedAt: Date().addingTimeInterval(-259200),
            duration: 1800,
            status: .pendingTranscription
        ))
    }
}
