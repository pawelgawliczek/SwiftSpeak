//
//  SwipeableMeetingCard.swift
//  SwiftSpeak
//
//  Swipeable card for meeting history - matches Context/PowerMode card style
//  Left swipe: Delete
//  Right swipe: Retry (if failed)
//

import SwiftUI
import SwiftSpeakCore

struct SwipeableMeetingCard: View {
    let meeting: MeetingRecord
    let onTap: () -> Void
    let onDelete: () -> Void
    let onRetry: (() -> Void)?

    @State private var offset: CGFloat = 0
    @State private var isSwiping = false

    private let actionButtonWidth: CGFloat = 70
    private let swipeThreshold: CGFloat = 50

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
        ZStack {
            // Background action buttons
            HStack(spacing: 0) {
                // Left side (revealed on right swipe): Retry
                if meeting.status.canRetry, onRetry != nil {
                    leftActionButtons
                        .opacity(offset > 0 ? 1 : 0)
                }

                Spacer()

                // Right side (revealed on left swipe): Delete
                if meeting.status.canDelete {
                    rightActionButtons
                        .opacity(offset < 0 ? 1 : 0)
                }
            }

            // Main card content (slides)
            cardContent
                .offset(x: offset)
                .gesture(swipeGesture)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
    }

    // MARK: - Left Action Buttons (Retry)

    private var leftActionButtons: some View {
        HStack(spacing: 0) {
            MeetingActionButton(
                icon: "arrow.clockwise",
                label: "Retry",
                color: .orange,
                action: {
                    HapticManager.lightTap()
                    withAnimation(.spring(response: 0.3)) { offset = 0 }
                    onRetry?()
                }
            )
            .frame(width: actionButtonWidth)
        }
    }

    // MARK: - Right Action Buttons (Delete)

    private var rightActionButtons: some View {
        HStack(spacing: 0) {
            MeetingActionButton(
                icon: "trash.fill",
                label: "Delete",
                color: .red,
                action: {
                    HapticManager.warning()
                    withAnimation(.spring(response: 0.3)) { offset = 0 }
                    onDelete()
                }
            )
            .frame(width: actionButtonWidth)
        }
    }

    // MARK: - Card Content

    private var cardContent: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status icon
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 56, height: 56)

                    if isActivelyProcessing {
                        ProgressView()
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: meeting.status.iconName)
                            .font(.title2)
                            .foregroundStyle(statusColor)
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(meeting.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        // Status badge
                        Text(meeting.status.displayName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(statusColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusColor.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    HStack(spacing: 12) {
                        // Duration
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(meeting.formattedDuration)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)

                        // Date
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(meeting.recordedAt, style: .date)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)

                        // Speaker count (if more than 1)
                        if meeting.speakerCount > 1 {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.caption2)
                                Text("\(meeting.speakerCount)")
                                    .font(.caption)
                            }
                            .foregroundStyle(.blue.opacity(0.8))
                        }
                    }
                }

                Spacer()

                // Chevron for navigation
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color.primary.opacity(0.05))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .strokeBorder(
                    isActivelyProcessing ? statusColor.opacity(0.5) : Color.clear,
                    lineWidth: 1.5
                )
        )
    }

    // MARK: - Swipe Gesture

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let translation = value.translation.width

                // Limit the swipe distance
                let maxSwipe = actionButtonWidth
                if translation > 0 {
                    // Right swipe (reveal left button - Retry)
                    if meeting.status.canRetry && onRetry != nil {
                        offset = min(translation, maxSwipe)
                    }
                } else {
                    // Left swipe (reveal right button - Delete)
                    if meeting.status.canDelete {
                        offset = max(translation, -maxSwipe)
                    }
                }
                isSwiping = true
            }
            .onEnded { value in
                isSwiping = false
                let translation = value.translation.width

                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if abs(translation) > swipeThreshold {
                        // Snap to show action button
                        if translation > 0 && meeting.status.canRetry && onRetry != nil {
                            offset = actionButtonWidth
                        } else if translation < 0 && meeting.status.canDelete {
                            offset = -actionButtonWidth
                        } else {
                            offset = 0
                        }
                    } else {
                        // Snap back to center
                        offset = 0
                    }
                }
            }
    }
}

// MARK: - Meeting Action Button

private struct MeetingActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(color)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        SwipeableMeetingCard(
            meeting: MeetingRecord(
                title: "Team Standup",
                recordedAt: Date(),
                duration: 1234,
                status: .completed
            ),
            onTap: {},
            onDelete: {},
            onRetry: nil
        )

        SwipeableMeetingCard(
            meeting: MeetingRecord(
                title: "Product Planning Q4",
                recordedAt: Date().addingTimeInterval(-86400),
                duration: 3600,
                status: .transcribing
            ),
            onTap: {},
            onDelete: {},
            onRetry: nil
        )

        SwipeableMeetingCard(
            meeting: MeetingRecord(
                title: "Client Call - Acme Corp",
                recordedAt: Date().addingTimeInterval(-172800),
                duration: 2700,
                status: .transcriptionFailed,
                errorMessage: "Network timeout"
            ),
            onTap: {},
            onDelete: {},
            onRetry: { print("Retry") }
        )
    }
    .padding()
    .background(AppTheme.darkBase)
    .preferredColorScheme(.dark)
}
