//
//  ContextsView.swift
//  SwiftSpeak
//
//  Phase 4: List and manage Conversation Contexts
//  Contexts affect transcription, translation, and Power Mode behavior
//  Refactored: Uses SharedSettings and supports embedding in PowerTabView
//

import SwiftUI
import SwiftSpeakCore

// MARK: - Contexts View (Standalone wrapper)

struct ContextsView: View {
    var body: some View {
        NavigationStack {
            ContextsListContent()
                .navigationTitle("Contexts")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Contexts List Content (Embeddable in PowerTabView)

struct ContextsListContent: View {
    @EnvironmentObject var settings: SharedSettings

    @State private var showingNewEditor = false
    @State private var editingContext: ConversationContext?
    @State private var navigateToHistory: ConversationContext?
    @State private var navigateToDetail: ConversationContext?
    @State private var showingDeleteConfirmation = false
    @State private var contextToDelete: ConversationContext?
    @State private var showPaywall = false

    /// Whether the user can create custom contexts (Pro+ tier)
    private var canCreateCustomContexts: Bool {
        settings.subscriptionTier != .free
    }

    /// All contexts: presets + user's custom contexts
    private var allContexts: [ConversationContext] {
        ConversationContext.presets + settings.contexts.filter { !$0.isPreset }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header explanation
                headerSection

                // Preset contexts (available to all users)
                if !ConversationContext.presets.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PRESETS")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)

                        LazyVStack(spacing: 12) {
                            ForEach(ConversationContext.presets) { context in
                                PresetContextCard(
                                    context: context,
                                    isActive: settings.activeContextId == context.id,
                                    onTap: {
                                        HapticManager.selection()
                                        if settings.activeContextId == context.id {
                                            settings.setActiveContext(nil)
                                        } else {
                                            settings.setActiveContext(context)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // Custom contexts (Pro feature)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("CUSTOM")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        if !canCreateCustomContexts {
                            TierBadge.pro
                        }
                    }
                    .padding(.horizontal, 20)

                    if settings.contexts.filter({ !$0.isPreset }).isEmpty {
                        // Empty state for custom contexts
                        VStack(spacing: 12) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)

                            Text("No custom contexts")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if !canCreateCustomContexts {
                                Text("Upgrade to Pro to create your own")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .padding(.horizontal, 16)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(settings.contexts.filter { !$0.isPreset }) { context in
                                SwipeableContextCard(
                                    context: context,
                                    isActive: settings.activeContextId == context.id,
                                    onTap: {
                                        HapticManager.lightTap()
                                        navigateToDetail = context
                                    },
                                    onEdit: { editingContext = context },
                                    onDelete: {
                                        contextToDelete = context
                                        showingDeleteConfirmation = true
                                    },
                                    onShowHistory: { navigateToHistory = context }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // "No active context" option
                noContextOption
                    .padding(.horizontal, 16)

                // Create new button (Pro only)
                createNewButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
            }
        }
        .background(AppTheme.darkBase.ignoresSafeArea())
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    if canCreateCustomContexts {
                        showingNewEditor = true
                    } else {
                        showPaywall = true
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(canCreateCustomContexts ? AppTheme.accent : .secondary)
                }
            }
        }
        .sheet(isPresented: $showingNewEditor) {
            ContextEditorSheet(
                context: ConversationContext.empty,
                isNew: true,
                onSave: { savedContext in
                    settings.addContext(savedContext)
                    showingNewEditor = false
                },
                onDelete: {
                    showingNewEditor = false
                }
            )
        }
        .sheet(item: $editingContext) { context in
            ContextEditorSheet(
                context: context,
                isNew: false,
                onSave: { savedContext in
                    settings.updateContext(savedContext)
                    editingContext = nil
                },
                onDelete: {
                    settings.deleteContext(id: context.id)
                    editingContext = nil
                }
            )
        }
        .navigationDestination(item: $navigateToHistory) { context in
            HistoryView(filterContextId: context.id, showFilterBar: false)
                .navigationTitle("\(context.name) History")
        }
        .navigationDestination(item: $navigateToDetail) { context in
            ContextDetailView(
                context: context,
                onEdit: {
                    navigateToDetail = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        editingContext = context
                    }
                },
                onSetActive: {
                    HapticManager.selection()
                    if settings.activeContextId == context.id {
                        settings.setActiveContext(nil)
                    } else {
                        settings.setActiveContext(context)
                    }
                }
            )
        }
        .alert("Delete Context?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                contextToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let context = contextToDelete {
                    withAnimation(AppTheme.smoothSpring) {
                        settings.deleteContext(id: context.id)
                    }
                }
                contextToDelete = nil
            }
        } message: {
            if let context = contextToDelete {
                Text("Are you sure you want to delete \"\(context.name)\"? This action cannot be undone.")
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active context affects transcription, translation, and Power Mode behavior.")
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
            Image(systemName: "person.circle")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.accentGradient)

            Text("No Contexts")
                .font(.headline)

            Text("Create contexts to personalize AI behavior")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    // MARK: - No Context Option

    private var noContextOption: some View {
        Button(action: { clearActiveContext() }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 44, height: 44)

                    Image(systemName: "circle.slash")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("No active context")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Use default behavior for all features")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if settings.activeContextId == nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .padding(16)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                    .strokeBorder(
                        settings.activeContextId == nil ? AppTheme.accent.opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Create New Button

    private var createNewButton: some View {
        Button(action: {
            if canCreateCustomContexts {
                showingNewEditor = true
            } else {
                showPaywall = true
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: canCreateCustomContexts ? "plus" : "lock.fill")
                    .font(.body.weight(.semibold))
                Text("Create Custom Context")
                    .font(.callout.weight(.semibold))
                if !canCreateCustomContexts {
                    Text("PRO")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.accent)
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(canCreateCustomContexts ? AppTheme.accent : .secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background((canCreateCustomContexts ? AppTheme.accent : Color.secondary).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
    }

    // MARK: - Actions

    private func clearActiveContext() {
        HapticManager.selection()
        settings.setActiveContext(nil)
    }
}

// MARK: - Swipeable Context Card

struct SwipeableContextCard: View {
    let context: ConversationContext
    let isActive: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
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
                // Left side (revealed on right swipe): Edit
                leftActionButtons
                    .opacity(offset > 0 ? 1 : 0)

                Spacer()

                // Right side (revealed on left swipe): Delete
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

    // MARK: - Left Action Buttons (Edit)

    private var leftActionButtons: some View {
        HStack(spacing: 0) {
            ContextActionButton(
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
        }
    }

    // MARK: - Right Action Buttons (Delete)

    private var rightActionButtons: some View {
        HStack(spacing: 0) {
            ContextActionButton(
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
                // Icon
                ZStack {
                    Circle()
                        .fill(context.color.color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Text(context.icon)
                        .font(.title2)
                }

                // Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(context.name)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if isActive {
                            Text("Active")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.accent.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 12) {
                        // History link
                        Button(action: onShowHistory) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption2)
                                Text("History")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        // Memory indicator
                        if context.useContextMemory {
                            HStack(spacing: 4) {
                                Image(systemName: "brain")
                                    .font(.caption2)
                                Text("Memory")
                                    .font(.caption)
                            }
                            .foregroundStyle(.purple.opacity(0.8))
                        }

                        // Domain jargon indicator
                        if context.domainJargon != .none {
                            HStack(spacing: 4) {
                                Image(systemName: context.domainJargon.icon)
                                    .font(.caption2)
                                Text(context.domainJargon.displayName)
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
                    isActive ? context.color.color.opacity(0.5) : Color.clear,
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
                    // Right swipe (reveal left button - Edit)
                    offset = min(translation, maxSwipe)
                } else {
                    // Left swipe (reveal right button - Delete)
                    offset = max(translation, -maxSwipe)
                }
                isSwiping = true
            }
            .onEnded { value in
                isSwiping = false
                let translation = value.translation.width

                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if abs(translation) > swipeThreshold {
                        // Snap to show action button
                        if translation > 0 {
                            offset = actionButtonWidth
                        } else {
                            offset = -actionButtonWidth
                        }
                    } else {
                        // Snap back to center
                        offset = 0
                    }
                }
            }
    }
}

// MARK: - Preset Context Card (Simple, non-editable)

struct PresetContextCard: View {
    let context: ConversationContext
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(context.color.color.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Text(context.icon)
                        .font(.title3)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(context.name)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("PRESET")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }

                    Text(context.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Selection indicator
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(context.color.color)
                }
            }
            .padding(14)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                    .strokeBorder(
                        isActive ? context.color.color.opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Context Action Button

private struct ContextActionButton: View {
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
    ContextsView()
        .environmentObject(SharedSettings.shared)
        .preferredColorScheme(.dark)
}
