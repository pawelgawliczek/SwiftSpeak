//
//  SwipeablePowerModeCard.swift
//  SwiftSpeak
//
//  Phase 4: WhatsApp-style swipe actions for Power Mode cards
//  Left swipe: Delete, Archive
//  Right swipe: Edit, Run
//

import SwiftUI

struct SwipeablePowerModeCard: View {
    let powerMode: PowerMode
    let onTap: () -> Void
    let onEdit: () -> Void
    let onRun: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    let onShowHistory: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isSwiping = false

    private let actionButtonWidth: CGFloat = 70
    private let swipeThreshold: CGFloat = 50

    var body: some View {
        ZStack {
            // Background action buttons
            HStack(spacing: 0) {
                // Left side (revealed on right swipe): Edit, Run
                leftActionButtons
                    .opacity(offset > 0 ? 1 : 0)

                Spacer()

                // Right side (revealed on left swipe): Archive, Delete
                rightActionButtons
                    .opacity(offset < 0 ? 1 : 0)
            }

            // Main card content (slides)
            cardContent
                .offset(x: offset)
                .gesture(swipeGesture)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
    }

    // MARK: - Left Action Buttons (Edit, Run)

    private var leftActionButtons: some View {
        HStack(spacing: 0) {
            SwipeActionButton(
                icon: "pencil",
                label: "Edit",
                color: .blue,
                action: {
                    HapticManager.lightTap()
                    withAnimation(.spring(response: 0.3)) { offset = 0 }
                    onEdit()
                }
            )
            .frame(width: actionButtonWidth)

            SwipeActionButton(
                icon: "play.fill",
                label: "Run",
                color: .green,
                action: {
                    HapticManager.mediumTap()
                    withAnimation(.spring(response: 0.3)) { offset = 0 }
                    onRun()
                }
            )
            .frame(width: actionButtonWidth)
        }
    }

    // MARK: - Right Action Buttons (Archive, Delete)

    private var rightActionButtons: some View {
        HStack(spacing: 0) {
            SwipeActionButton(
                icon: powerMode.isArchived ? "tray.and.arrow.up.fill" : "archivebox.fill",
                label: powerMode.isArchived ? "Restore" : "Archive",
                color: .orange,
                action: {
                    HapticManager.lightTap()
                    withAnimation(.spring(response: 0.3)) { offset = 0 }
                    onArchive()
                }
            )
            .frame(width: actionButtonWidth)

            SwipeActionButton(
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
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(powerMode.iconBackgroundColor.gradient.opacity(0.2))
                        .frame(width: 56, height: 56)

                    Image(systemName: powerMode.icon)
                        .font(.title2)
                        .foregroundStyle(powerMode.iconColor.gradient)
                }

                // Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(powerMode.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 12) {
                        // Usage count with history link
                        Button(action: onShowHistory) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption2)
                                Text("\(powerMode.usageCount) uses")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        // Memory indicator
                        if powerMode.memoryEnabled {
                            HStack(spacing: 4) {
                                Image(systemName: "brain")
                                    .font(.caption2)
                                Text("Memory")
                                    .font(.caption)
                            }
                            .foregroundStyle(.purple.opacity(0.8))
                        }

                        // Knowledge base indicator
                        if !powerMode.knowledgeDocumentIds.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.caption2)
                                Text("\(powerMode.knowledgeDocumentIds.count)")
                                    .font(.caption)
                            }
                            .foregroundStyle(.blue.opacity(0.8))
                        }
                    }
                }

                Spacer()

                // Play indicator
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(powerMode.iconColor.gradient)
            }
            .padding(16)
            .background(Color.primary.opacity(0.05))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Swipe Gesture

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let translation = value.translation.width

                // Limit the swipe distance
                let maxSwipe = actionButtonWidth * 2
                if translation > 0 {
                    // Right swipe (reveal left buttons)
                    offset = min(translation, maxSwipe)
                } else {
                    // Left swipe (reveal right buttons)
                    offset = max(translation, -maxSwipe)
                }
                isSwiping = true
            }
            .onEnded { value in
                isSwiping = false
                let translation = value.translation.width

                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if abs(translation) > swipeThreshold {
                        // Snap to show action buttons
                        if translation > 0 {
                            offset = actionButtonWidth * 2
                        } else {
                            offset = -actionButtonWidth * 2
                        }
                    } else {
                        // Snap back to center
                        offset = 0
                    }
                }
            }
    }
}

// MARK: - Swipe Action Button

private struct SwipeActionButton: View {
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
        SwipeablePowerModeCard(
            powerMode: PowerMode.presets[0],
            onTap: {},
            onEdit: {},
            onRun: {},
            onArchive: {},
            onDelete: {},
            onShowHistory: {}
        )

        SwipeablePowerModeCard(
            powerMode: PowerMode.presets[1],
            onTap: {},
            onEdit: {},
            onRun: {},
            onArchive: {},
            onDelete: {},
            onShowHistory: {}
        )
    }
    .padding()
    .background(AppTheme.darkBase)
    .preferredColorScheme(.dark)
}
