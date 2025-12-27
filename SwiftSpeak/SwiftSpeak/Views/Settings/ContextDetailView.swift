//
//  ContextDetailView.swift
//  SwiftSpeak
//
//  Detail view for a Context showing definition, history, and edit option
//

import SwiftUI

struct ContextDetailView: View {
    let context: ConversationContext
    let onEdit: () -> Void
    let onSetActive: () -> Void

    @EnvironmentObject var settings: SharedSettings

    private var isActive: Bool {
        settings.activeContextId == context.id
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with icon
                headerSection

                // Action buttons
                actionButtons

                // Definition section
                definitionSection

                // Tone & Style section
                if !context.toneDescription.isEmpty {
                    toneSection
                }

                // Languages section
                if !context.languageHints.isEmpty {
                    languagesSection
                }

                // Custom Instructions section
                if !context.customInstructions.isEmpty {
                    instructionsSection
                }

                // History section
                historySection

                // Memory section (if enabled)
                if context.memoryEnabled {
                    memorySection
                }

                // Stats section
                statsSection
            }
            .padding(16)
        }
        .background(AppTheme.darkBase.ignoresSafeArea())
        .navigationTitle(context.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onEdit) {
                    Text("Edit")
                        .fontWeight(.medium)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(context.color.color.opacity(0.15))
                    .frame(width: 80, height: 80)

                Text(context.icon)
                    .font(.system(size: 40))
            }

            if !context.description.isEmpty {
                Text(context.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            // Active status badge
            if isActive {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text("Active")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(context.color.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(context.color.color.opacity(0.15))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Set Active / Deactivate button
            Button(action: onSetActive) {
                HStack(spacing: 8) {
                    Image(systemName: isActive ? "xmark.circle" : "checkmark.circle")
                        .font(.body.weight(.semibold))
                    Text(isActive ? "Deactivate" : "Set Active")
                        .font(.callout.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isActive ? AnyShapeStyle(Color.secondary) : AnyShapeStyle(context.color.gradient))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            }

            // Edit button
            Button(action: onEdit) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .font(.body.weight(.semibold))
                    Text("Edit")
                        .font(.callout.weight(.semibold))
                }
                .foregroundStyle(.primary)
                .frame(width: 100)
                .frame(height: 50)
                .background(Color.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            }
        }
    }

    // MARK: - Definition Section

    private var definitionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DESCRIPTION")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(context.description.isEmpty ? "No description provided" : context.description)
                .font(.body)
                .foregroundStyle(context.description.isEmpty ? .tertiary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
    }

    // MARK: - Tone Section

    private var toneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TONE & STYLE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(context.toneDescription)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
    }

    // MARK: - Languages Section

    private var languagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EXPECTED LANGUAGES")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 8) {
                ForEach(context.languageHints) { language in
                    HStack(spacing: 4) {
                        Text(language.flag)
                        Text(language.displayName)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(context.color.color.opacity(0.15))
                    .foregroundStyle(context.color.color)
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Instructions Section

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CUSTOM INSTRUCTIONS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(context.customInstructions)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("HISTORY")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                NavigationLink(destination: HistoryView(filterContextId: context.id, showFilterBar: false)
                    .navigationTitle("\(context.name) History")) {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.caption.weight(.medium))
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.accent)
                }
            }

            let recentHistory = settings.transcriptionHistory(forContextId: context.id).prefix(3)

            if recentHistory.isEmpty {
                HStack {
                    Text("No history yet")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(recentHistory)) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.text)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Text(record.timestamp.formatted(.relative(presentation: .named)))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: - Memory Section

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CONTEXT MEMORY")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "brain")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    Text("Memory Enabled")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.purple)
                }

                if let memory = context.memory, !memory.isEmpty {
                    Text(memory)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(4)

                    if let lastUpdate = context.lastMemoryUpdate {
                        Text("Updated \(lastUpdate.formatted(.relative(presentation: .named)))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text("No memory stored yet")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.purple.opacity(0.1))
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
                ContextStatCard(title: "Created", value: context.createdAt.formatted(date: .abbreviated, time: .omitted), icon: "calendar")
                ContextStatCard(title: "Updated", value: context.updatedAt.formatted(date: .abbreviated, time: .omitted), icon: "clock")
            }
        }
    }
}

// MARK: - Context Stat Card

private struct ContextStatCard: View {
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

// MARK: - Preview

#Preview {
    NavigationStack {
        ContextDetailView(
            context: ConversationContext.samples[0],
            onEdit: {},
            onSetActive: {}
        )
        .environmentObject(SharedSettings.shared)
    }
    .preferredColorScheme(.dark)
}
