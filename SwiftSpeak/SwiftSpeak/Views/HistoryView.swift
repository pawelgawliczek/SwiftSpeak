//
//  HistoryView.swift
//  SwiftSpeak
//
//  Past transcriptions list
//

import SwiftUI
import SwiftSpeakCore

struct HistoryView: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme

    // Optional filter parameters for reuse from other views
    var filterPowerModeId: UUID? = nil
    var filterContextId: UUID? = nil
    var showFilterBar: Bool = true

    @State private var searchText = ""
    @State private var selectedRecord: TranscriptionRecord?
    @State private var showDeleteConfirmation = false
    @State private var isSelecting = false
    @State private var selectedRecords: Set<UUID> = []

    // Interactive filters (used when showFilterBar is true)
    @State private var selectedPowerModeFilter: UUID?
    @State private var selectedContextFilter: UUID?
    @State private var selectedSourceFilter: TranscriptionSource?
    @State private var showFilterSheet = false

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var hasActiveFilters: Bool {
        selectedPowerModeFilter != nil || selectedContextFilter != nil || selectedSourceFilter != nil
    }

    var filteredHistory: [TranscriptionRecord] {
        var result = settings.transcriptionHistory

        // Apply passed-in filter (takes precedence, used when embedded)
        if let powerModeId = filterPowerModeId {
            result = result.filter { $0.powerModeId == powerModeId }
        } else if let selected = selectedPowerModeFilter {
            result = result.filter { $0.powerModeId == selected }
        }

        if let contextId = filterContextId {
            result = result.filter { $0.contextId == contextId }
        } else if let selected = selectedContextFilter {
            result = result.filter { $0.contextId == selected }
        }

        // Source filter (Phase 13.11 - Keyboard AI tracking)
        if let source = selectedSourceFilter {
            result = result.filter { $0.source == source }
        }

        // Text search
        if !searchText.isEmpty {
            result = result.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundColor.ignoresSafeArea()

                if settings.transcriptionHistory.isEmpty {
                    EmptyHistoryView()
                } else {
                    List {
                        ForEach(filteredHistory) { record in
                            HStack(spacing: 12) {
                                // Selection checkbox
                                if isSelecting {
                                    Image(systemName: selectedRecords.contains(record.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(selectedRecords.contains(record.id) ? AppTheme.accent : .secondary)
                                        .onTapGesture {
                                            HapticManager.lightTap()
                                            toggleSelection(record.id)
                                        }
                                }

                                HistoryRowView(
                                    record: record,
                                    colorScheme: colorScheme,
                                    onCopy: {
                                        UIPasteboard.general.string = record.text
                                    },
                                    onDetails: {
                                        selectedRecord = record
                                    }
                                )
                                .onTapGesture {
                                    if isSelecting {
                                        HapticManager.lightTap()
                                        toggleSelection(record.id)
                                    }
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteRecord(record)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    HapticManager.lightTap()
                                    selectedRecord = record
                                } label: {
                                    Label("Details", systemImage: "info.circle")
                                }
                                .tint(AppTheme.accent)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .searchable(text: $searchText, prompt: "Search transcriptions")
                }

                // Bottom action bar when selecting
                if isSelecting && !selectedRecords.isEmpty {
                    VStack {
                        Spacer()

                        HStack(spacing: 16) {
                            Button(action: {
                                HapticManager.lightTap()
                                selectedRecords = Set(filteredHistory.map { $0.id })
                            }) {
                                Text("Select All")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(AppTheme.accent)
                            }

                            Spacer()

                            Text("\(selectedRecords.count) selected")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button(action: {
                                HapticManager.mediumTap()
                                showDeleteConfirmation = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                    Text("Delete")
                                }
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.red)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !settings.transcriptionHistory.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            HapticManager.lightTap()
                            withAnimation {
                                isSelecting.toggle()
                                if !isSelecting {
                                    selectedRecords.removeAll()
                                }
                            }
                        }) {
                            Text(isSelecting ? "Cancel" : "Select")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }

                    if showFilterBar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: {
                                HapticManager.lightTap()
                                showFilterSheet = true
                            }) {
                                Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                    .foregroundStyle(hasActiveFilters ? AppTheme.accent : .secondary)
                            }
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(action: {
                                HapticManager.lightTap()
                                showDeleteConfirmation = true
                            }) {
                                Label("Clear All History", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                HistoryFilterSheet(
                    selectedPowerModeId: $selectedPowerModeFilter,
                    selectedContextId: $selectedContextFilter,
                    selectedSource: $selectedSourceFilter,
                    powerModes: settings.powerModes,
                    contexts: settings.contexts
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(item: $selectedRecord) { record in
                HistoryDetailView(record: record)
                    .environmentObject(settings)
            }
            .alert(isSelecting ? "Delete Selected" : "Clear History", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button(isSelecting ? "Delete \(selectedRecords.count)" : "Clear All", role: .destructive) {
                    if isSelecting {
                        deleteSelectedRecords()
                    } else {
                        settings.clearHistory()
                    }
                }
            } message: {
                Text(isSelecting
                     ? "This will permanently delete \(selectedRecords.count) transcription\(selectedRecords.count == 1 ? "" : "s")."
                     : "This will permanently delete all transcription history.")
            }
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedRecords.contains(id) {
            selectedRecords.remove(id)
        } else {
            selectedRecords.insert(id)
        }
    }

    private func deleteRecords(at offsets: IndexSet) {
        let recordsToDelete = offsets.map { filteredHistory[$0].id }
        settings.transcriptionHistory.removeAll { recordsToDelete.contains($0.id) }
    }

    private func deleteRecord(_ record: TranscriptionRecord) {
        HapticManager.mediumTap()
        settings.transcriptionHistory.removeAll { $0.id == record.id }
    }

    private func deleteSelectedRecords() {
        HapticManager.success()
        settings.transcriptionHistory.removeAll { selectedRecords.contains($0.id) }
        selectedRecords.removeAll()
        isSelecting = false
    }
}

// MARK: - Empty History View
struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("No Transcriptions Yet")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Your transcription history will appear here")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
    }
}

// MARK: - History Row View
struct HistoryRowView: View {
    let record: TranscriptionRecord
    let colorScheme: ColorScheme
    let onCopy: () -> Void
    let onDetails: () -> Void

    @State private var showCopied = false
    @State private var copyScale: CGFloat = 1.0

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                // Header with mode, power mode, context, translation, and time
                headerBadges

                // Phase 13.12: Prediction entries show typing context and predictions
                if record.isPrediction, let predContext = record.sentencePredictionContext {
                    // For predictions: show typing context
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "text.cursor")
                                .font(.caption2)
                            Text("Typing Context")
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(.purple)
                        Text(predContext.typingContext.isEmpty ? "(empty)" : predContext.typingContext)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                            .lineLimit(2)
                    }
                // Phase 12: Edit entries show instructions, regular entries show input
                } else if record.isEditOperation, let editContext = record.editContext {
                    // For edit operations: show instructions (what user asked)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "quote.bubble")
                                .font(.caption2)
                            Text("Instructions")
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(.green)
                        Text(editContext.instructions)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                            .lineLimit(2)
                    }
                } else if record.hasTransformation {
                    // Regular entries: show input if different from output
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Input")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tertiary)
                        Text(record.rawTranscribedText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                // Output text (larger, tappable to copy)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if record.isPrediction {
                            Text("Predictions")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.purple)
                        } else if record.isEditOperation {
                            Text("Result")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.green)
                        } else if record.hasTransformation {
                            Text("Output")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Label("Tap to copy", systemImage: "doc.on.doc")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .opacity(showCopied ? 0 : 1)
                    }

                    // For predictions, show numbered list
                    if record.isPrediction, let predContext = record.sentencePredictionContext {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(predContext.predictions.prefix(3).enumerated()), id: \.offset) { index, prediction in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("\(index + 1).")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.purple)
                                    Text(prediction)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                }
                            }
                            if predContext.predictions.count > 3 {
                                Text("+\(predContext.predictions.count - 3) more")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    } else {
                        Text(record.text)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    triggerCopyAnimation()
                }

                // Footer with duration, cost badges, provider, and details button
                HStack(spacing: 8) {
                    costAndProviderFooter

                    // Details button
                    Button(action: {
                        HapticManager.lightTap()
                        onDetails()
                    }) {
                        HStack(spacing: 4) {
                            Text("Details")
                                .font(.caption2.weight(.medium))
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 8, y: 2)
            .padding(.vertical, 4)

            // Copy success overlay
            if showCopied {
                copiedOverlay
            }
        }
    }

    // MARK: - Copy Animation

    private func triggerCopyAnimation() {
        onCopy()
        HapticManager.success()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showCopied = true
            copyScale = 1.2
        }

        withAnimation(.spring(response: 0.2, dampingFraction: 0.8).delay(0.1)) {
            copyScale = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                showCopied = false
            }
        }
    }

    private var copiedOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
                .scaleEffect(copyScale)

            Text("Copied!")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Header Badges

    private var headerBadges: some View {
        HStack {
            // Phase 13.12: Prediction badge (purple, with sparkles icon)
            if record.isPrediction {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption2.weight(.semibold))
                    Text("Prediction")
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple)
                .clipShape(Capsule())
            // Phase 12: Edit badge (green, with pencil icon)
            } else if record.isEditOperation {
                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                        .font(.caption2.weight(.semibold))
                    Text("Edit")
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green)
                .clipShape(Capsule())
            } else {
                // Mode badge (only show for non-edit/prediction entries)
                HStack(spacing: 4) {
                    Image(systemName: record.mode.icon)
                        .font(.caption2)
                    Text(record.mode.displayName)
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.accent.opacity(0.15))
                .clipShape(Capsule())
            }

            // Power Mode badge
            if let powerModeName = record.powerModeName {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                    Text(powerModeName)
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
            }

            // Context badge
            if let contextName = record.contextName {
                HStack(spacing: 4) {
                    if let icon = record.contextIcon {
                        Text(icon)
                            .font(.caption2)
                    }
                    Text(contextName)
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.purple)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.15))
                .clipShape(Capsule())
            }

            // Translation badge
            if record.translated {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.caption2)
                    Text(record.targetLanguage?.displayName ?? "")
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.teal)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.teal.opacity(0.15))
                .clipShape(Capsule())
            }

            Spacer()

            Text(formattedDate)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Cost and Provider Footer

    private var costAndProviderFooter: some View {
        HStack(spacing: 8) {
            // Duration
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(formattedDuration)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)

            // Cost badges per capability
            if let breakdown = record.costBreakdown {
                // Transcription cost
                if breakdown.transcriptionCost > 0 {
                    CostBadge(icon: "waveform", cost: breakdown.transcriptionCost)
                }

                // Translation cost
                if let translationCost = breakdown.translationCost, translationCost > 0 {
                    CostBadge(icon: "globe", cost: translationCost)
                }

                // Power Mode cost
                if let powerModeCost = breakdown.powerModeCost, powerModeCost > 0 {
                    CostBadge(icon: "bolt.fill", cost: powerModeCost)
                }
            } else if let cost = record.estimatedCost, cost > 0 {
                // Fallback for legacy records
                Text(cost.formattedCostCompact)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            Spacer()

            // Provider
            HStack(spacing: 4) {
                ProviderIcon(record.provider, size: .small, style: .filled)
                Text(record.provider.shortName)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
    }

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: record.timestamp, relativeTo: Date())
    }

    private var formattedDuration: String {
        let seconds = Int(record.duration)
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            return "\(seconds / 60)m \(seconds % 60)s"
        }
    }
}

// MARK: - Cost Badge Component

private struct CostBadge: View {
    let icon: String
    let cost: Double

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(cost.formattedCostCompact)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - History Detail View (Redesigned with Tabs)
struct HistoryDetailView: View {
    let record: TranscriptionRecord
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var settings: SharedSettings
    @State private var copied = false
    @State private var selectedTab = 0

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Text Content Section
                        textContentSection

                        // Copy Button
                        copyButton

                        // Tabbed Details
                        Picker("Details", selection: $selectedTab) {
                            Text("Timing").tag(0)
                            Text("Providers").tag(1)
                            Text("Prompts").tag(2)
                            Text("Costs").tag(3)
                        }
                        .pickerStyle(.segmented)

                        // Tab Content
                        Group {
                            switch selectedTab {
                            case 0: timingSection
                            case 1: providersSection
                            case 2: promptsSection
                            case 3: costsSection
                            default: EmptyView()
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: selectedTab)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Text Content Section

    private var textContentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Phase 13.12: Prediction entries have special display
            if record.isPrediction, let predContext = record.sentencePredictionContext {
                // Typing context
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "text.cursor")
                            .font(.caption)
                            .foregroundStyle(.purple)
                        Text("Typing Context")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.purple)

                        Spacer()

                        if let contextName = predContext.activeContextName {
                            HStack(spacing: 4) {
                                Image(systemName: "person.circle")
                                    .font(.caption2)
                                Text(contextName)
                                    .font(.caption2)
                            }
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                    Text(predContext.typingContext.isEmpty ? "(empty field)" : predContext.typingContext)
                        .font(.subheadline)
                        .foregroundStyle(predContext.typingContext.isEmpty ? .tertiary : .secondary)
                        .italic(predContext.typingContext.isEmpty)
                        .textSelection(.enabled)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.purple.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Predictions list
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.purple)
                        Text("AI Predictions")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.purple)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(predContext.predictions.enumerated()), id: \.offset) { index, prediction in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Color.purple)
                                    .clipShape(Circle())

                                Text(prediction)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 8, y: 2)

            // Phase 12: Edit entries have special display
            } else if record.isEditOperation, let editContext = record.editContext {
                // Original text that was being edited
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "doc.text")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Original Text")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer()

                        // Parent link badge if parent exists
                        if let parentId = editContext.parentEntryId,
                           let parentRecord = settings.transcriptionHistory.first(where: { $0.id == parentId }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.turn.up.left")
                                    .font(.caption2)
                                Text("from \(parentRecord.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                    Text(editContext.originalText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Instructions (what user asked for)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "quote.bubble")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("Instructions")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    Text(editContext.instructions)
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Result (the edited text)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("Edited Result")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    Text(record.text)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 8, y: 2)

            } else {
                // Regular entries: Input (if different from output)
                if record.hasTransformation {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "mic.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Raw Transcription")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Text(record.rawTranscribedText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                // Output (prominent)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "text.alignleft")
                            .font(.caption)
                            .foregroundStyle(AppTheme.accent)
                        Text("Final Output")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    Text(record.text)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 8, y: 2)
            }
        }
    }

    // MARK: - Copy Button

    private var copyButton: some View {
        Button(action: copyText) {
            HStack {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                Text(copied ? "Copied!" : "Copy to Clipboard")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .background(copied ? Color.green : AppTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timing Section

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Processing Timeline
            SectionHeader(title: "PROCESSING TIMELINE")

            if let metadata = record.processingMetadata, !metadata.steps.isEmpty {
                VStack(spacing: 12) {
                    ForEach(metadata.steps) { step in
                        HStack {
                            Image(systemName: step.stepType.icon)
                                .font(.caption)
                                .foregroundStyle(step.stepType.color)
                                .frame(width: 24)

                            Text(step.stepType.displayName)
                                .font(.subheadline)

                            Spacer()

                            Text(step.responseTimeFormatted)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    HStack {
                        Text("Total Processing")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(metadata.totalResponseTimeMs)ms")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .padding(16)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                legacyTimingCard
            }

            // Audio Info
            SectionHeader(title: "AUDIO INFO")

            VStack(spacing: 12) {
                MetadataRow(icon: "calendar", label: "Date", value: formattedFullDate)
                MetadataRow(icon: "clock", label: "Recording Duration", value: formattedDuration)
            }
            .padding(16)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var legacyTimingCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("Detailed timing not available")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text("This record was created before enhanced tracking was added.")
                .font(.caption2)
                .foregroundStyle(.quaternary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Providers Section

    private var providersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Settings Used (Context, Power Mode, Translation)
            if hasSettingsUsed {
                SectionHeader(title: "SETTINGS USED")

                VStack(spacing: 0) {
                    // Mode
                    SettingsUsedRow(
                        icon: record.mode.icon,
                        iconColor: AppTheme.accent,
                        label: "Formatting Mode",
                        value: record.mode.displayName
                    )

                    // Context
                    if let contextName = record.contextName {
                        Divider().padding(.leading, 44)
                        SettingsUsedRow(
                            icon: record.contextIcon ?? "person.crop.circle",
                            iconColor: .purple,
                            label: "Context",
                            value: contextName
                        )
                    }

                    // Power Mode
                    if let powerModeName = record.powerModeName {
                        Divider().padding(.leading, 44)
                        SettingsUsedRow(
                            icon: "bolt.fill",
                            iconColor: .orange,
                            label: "Power Mode",
                            value: powerModeName
                        )
                    }

                    // Translation
                    if record.translated, let lang = record.targetLanguage {
                        Divider().padding(.leading, 44)
                        SettingsUsedRow(
                            icon: "globe",
                            iconColor: .teal,
                            label: "Translation",
                            value: "\(lang.flag) \(lang.displayName)"
                        )
                    }
                }
                .padding(16)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // Providers & Models
            SectionHeader(title: "PROVIDERS & MODELS")

            if let metadata = record.processingMetadata, !metadata.steps.isEmpty {
                VStack(spacing: 12) {
                    ForEach(metadata.steps) { step in
                        HStack {
                            ProviderIcon(step.provider, size: .small, style: .filled)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.stepType.displayName)
                                    .font(.subheadline)
                                Text("\(step.provider.displayName) - \(step.modelName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }
                }
                .padding(16)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                // Legacy: show basic provider info
                VStack(spacing: 12) {
                    HStack {
                        ProviderIcon(record.provider, size: .small, style: .filled)
                            .frame(width: 24)

                        Text("Transcription")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(record.provider.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
                .padding(16)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // Parameters (vocabulary, memory sources, etc.)
            if hasParameters {
                SectionHeader(title: "PARAMETERS")

                VStack(spacing: 12) {
                    if let metadata = record.processingMetadata {
                        if let sourceHint = metadata.sourceLanguageHint {
                            MetadataRow(icon: "character.bubble", label: "Source Language", value: sourceHint.displayName)
                        }

                        if let vocab = metadata.vocabularyApplied, !vocab.isEmpty {
                            HStack(alignment: .top) {
                                Image(systemName: "text.word.spacing")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.accent)
                                    .frame(width: 24)
                                Text("Vocabulary")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(vocab.joined(separator: ", "))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.trailing)
                            }
                        }

                        if let memory = metadata.memorySourcesUsed, !memory.isEmpty {
                            HStack(alignment: .top) {
                                Image(systemName: "brain")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.accent)
                                    .frame(width: 24)
                                Text("Memory Sources")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(memory.joined(separator: ", "))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                }
                .padding(16)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var hasSettingsUsed: Bool {
        true // Always show at least the mode
    }

    private var hasParameters: Bool {
        guard let metadata = record.processingMetadata else { return false }
        return metadata.sourceLanguageHint != nil ||
               (metadata.vocabularyApplied?.isEmpty == false) ||
               (metadata.memorySourcesUsed?.isEmpty == false)
    }

    // MARK: - Prompts Section

    private var promptsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Phase 13.12: Prediction entries show prediction config
            if record.isPrediction, let predContext = record.sentencePredictionContext {
                SectionHeader(title: "PREDICTION CONFIG")

                VStack(spacing: 0) {
                    // Provider
                    PromptConfigRow(
                        icon: "sparkles",
                        iconColor: .purple,
                        label: "Provider",
                        value: record.provider.displayName
                    )

                    Divider().padding(.leading, 44)

                    // Context (if any)
                    PromptConfigRow(
                        icon: "person.circle",
                        iconColor: .purple,
                        label: "Context",
                        value: predContext.activeContextName ?? "No context"
                    )

                    Divider().padding(.leading, 44)

                    // Typing context length
                    PromptConfigRow(
                        icon: "text.cursor",
                        iconColor: .purple,
                        label: "Input Length",
                        value: "\(predContext.typingContext.count) characters"
                    )

                    Divider().padding(.leading, 44)

                    // Number of predictions
                    PromptConfigRow(
                        icon: "list.number",
                        iconColor: .purple,
                        label: "Predictions",
                        value: "\(predContext.predictions.count) sentences"
                    )
                }
                .padding(16)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Show the full prompt
                SectionHeader(title: "PROMPT SENT TO AI")

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.purple)
                        Text("SENTENCE PREDICTION")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.purple)
                    }

                    ScrollView {
                        Text(predContext.prompt)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                }
                .padding(12)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            } else {
                // Regular entries: show transcription configuration
                SectionHeader(title: "TRANSCRIPTION CONFIG")

                VStack(spacing: 0) {
                    // Transcription provider
                    PromptConfigRow(
                        icon: "waveform",
                        iconColor: AppTheme.accent,
                        label: "Transcription",
                        value: record.provider.displayName
                    )

                    Divider().padding(.leading, 44)

                    // Mode
                    PromptConfigRow(
                        icon: record.mode.icon,
                        iconColor: AppTheme.accent,
                        label: "Mode",
                        value: record.mode.displayName
                    )

                    Divider().padding(.leading, 44)

                    // Context
                    PromptConfigRow(
                        icon: record.contextIcon ?? "person.crop.circle.dashed",
                        iconColor: .purple,
                        label: "Context",
                        value: record.contextName ?? "No context"
                    )

                    // Power Mode (if used)
                    if let powerModeName = record.powerModeName {
                        Divider().padding(.leading, 44)
                        PromptConfigRow(
                            icon: "bolt.fill",
                            iconColor: .orange,
                            label: "Power Mode",
                            value: powerModeName
                        )
                    }

                    // Translation (if used)
                    if record.translated, let lang = record.targetLanguage {
                        Divider().padding(.leading, 44)
                        PromptConfigRow(
                            icon: "globe",
                            iconColor: .teal,
                            label: "Translation",
                            value: "\(lang.flag) \(lang.displayName)"
                        )
                    }
                }
                .padding(16)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Show actual prompts if recorded
                if let metadata = record.processingMetadata {
                    let prompts = metadata.allPrompts
                    if !prompts.isEmpty {
                        SectionHeader(title: "PROMPTS SENT TO AI")

                        ForEach(Array(prompts.enumerated()), id: \.offset) { _, item in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: item.stepType.icon)
                                        .font(.caption)
                                        .foregroundStyle(item.stepType.color)
                                    Text(item.stepType.displayName.uppercased())
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(item.stepType.color)
                                }

                                ScrollView {
                                    Text(item.prompt)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.primary)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxHeight: 150)
                            }
                            .padding(12)
                            .background(Color.primary.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Costs Section

    private var costsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "COST BREAKDOWN")

            if let breakdown = record.costBreakdown, breakdown.hasCosts {
                VStack(spacing: 12) {
                    CostDetailRow(icon: "waveform", label: "Transcription", cost: breakdown.transcriptionCost)

                    if record.mode != .raw {
                        CostDetailRow(
                            icon: "text.alignleft",
                            label: "Formatting",
                            cost: breakdown.formattingCost,
                            note: breakdown.formattingCost == 0 ? "Local" : nil
                        )
                    }

                    if let translationCost = breakdown.translationCost {
                        CostDetailRow(icon: "globe", label: "Translation", cost: translationCost)
                    }

                    if let powerModeCost = breakdown.powerModeCost {
                        CostDetailRow(icon: "bolt.fill", label: "Power Mode", cost: powerModeCost)
                    }

                    Divider()

                    HStack {
                        Text("Total")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(breakdown.total.formattedCost)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .padding(16)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Token Usage
                if let metadata = record.processingMetadata,
                   (metadata.totalInputTokens > 0 || metadata.totalOutputTokens > 0) {
                    SectionHeader(title: "TOKEN USAGE")

                    VStack(spacing: 12) {
                        HStack {
                            Label("\(metadata.totalInputTokens)", systemImage: "arrow.right.circle")
                                .font(.subheadline)
                            Text("input tokens")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        HStack {
                            Label("\(metadata.totalOutputTokens)", systemImage: "arrow.left.circle")
                                .font(.subheadline)
                            Text("output tokens")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        Divider()
                        HStack {
                            Text("Total Tokens")
                                .font(.subheadline)
                            Spacer()
                            Text("\(metadata.totalInputTokens + metadata.totalOutputTokens)")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                        }
                    }
                    .padding(16)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("No cost data")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - Helpers

    private var formattedFullDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: record.timestamp)
    }

    private var formattedDuration: String {
        let seconds = Int(record.duration)
        if seconds < 60 {
            return "\(seconds) seconds"
        } else {
            return "\(seconds / 60)m \(seconds % 60)s"
        }
    }

    private func copyText() {
        UIPasteboard.general.string = record.text
        HapticManager.success()
        withAnimation(AppTheme.quickSpring) {
            copied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(AppTheme.quickSpring) {
                copied = false
            }
        }
    }
}

// MARK: - Supporting Views for Detail View

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 8)
    }
}

private struct CostDetailRow: View {
    let icon: String
    let label: String
    let cost: Double
    var note: String? = nil

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)

            if let note = note {
                Text("(\(note))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(cost.formattedCost)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(cost == 0 ? .tertiary : .primary)
        }
    }
}

struct MetadataRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Settings Used Row (Prominent display for settings)

struct SettingsUsedRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Prompt Config Row (for Prompts tab)

private struct PromptConfigRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)

                // Handle emoji icons vs SF Symbols
                if icon.count <= 2 && !icon.contains(".") {
                    Text(icon)
                        .font(.system(size: 14))
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
            }

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Preview Helpers
extension TranscriptionRecord {
    static var sampleData: [TranscriptionRecord] {
        let now = Date()

        // Sample processing metadata for email formatting
        let emailMetadata = ProcessingMetadata(
            steps: [
                ProcessingStepInfo(
                    stepType: .transcription,
                    provider: .openAI,
                    modelName: "whisper-1",
                    startTime: now.addingTimeInterval(-2),
                    endTime: now.addingTimeInterval(-1.153),
                    cost: 0.0012,
                    prompt: "Language: English\nVocabulary: SwiftSpeak, iOS"
                ),
                ProcessingStepInfo(
                    stepType: .formatting,
                    provider: .anthropic,
                    modelName: "claude-3-5-haiku-latest",
                    startTime: now.addingTimeInterval(-1.153),
                    endTime: now.addingTimeInterval(-0.630),
                    inputTokens: 127,
                    outputTokens: 89,
                    cost: 0.0,
                    prompt: "Format as professional email..."
                )
            ],
            totalProcessingTime: 1.370,
            sourceLanguageHint: .english,
            vocabularyApplied: ["SwiftSpeak", "iOS"]
        )

        // Sample processing metadata for translation
        let translationMetadata = ProcessingMetadata(
            steps: [
                ProcessingStepInfo(
                    stepType: .transcription,
                    provider: .openAI,
                    modelName: "whisper-1",
                    startTime: now.addingTimeInterval(-1.5),
                    endTime: now.addingTimeInterval(-0.8),
                    cost: 0.0008,
                    prompt: nil
                ),
                ProcessingStepInfo(
                    stepType: .translation,
                    provider: .deepL,
                    modelName: "deepl-translate",
                    startTime: now.addingTimeInterval(-0.8),
                    endTime: now.addingTimeInterval(-0.488),
                    inputTokens: 45,
                    outputTokens: 52,
                    cost: 0.0005,
                    prompt: "Translate to Spanish"
                )
            ],
            totalProcessingTime: 1.012
        )

        // Sample for Power Mode
        let powerModeMetadata = ProcessingMetadata(
            steps: [
                ProcessingStepInfo(
                    stepType: .transcription,
                    provider: .openAI,
                    modelName: "whisper-1",
                    startTime: now.addingTimeInterval(-3),
                    endTime: now.addingTimeInterval(-2.2),
                    cost: 0.0015,
                    prompt: nil
                ),
                ProcessingStepInfo(
                    stepType: .powerMode,
                    provider: .anthropic,
                    modelName: "claude-3-5-sonnet-latest",
                    startTime: now.addingTimeInterval(-2.2),
                    endTime: now.addingTimeInterval(-0.5),
                    inputTokens: 850,
                    outputTokens: 420,
                    cost: 0.0089,
                    prompt: "You are a professional meeting notes assistant..."
                )
            ],
            totalProcessingTime: 2.5,
            memorySourcesUsed: ["Global Memory", "Work Context"]
        )

        return [
            // 1. Raw transcription (no transformation)
            TranscriptionRecord(
                rawTranscribedText: "hello this is a test transcription im speaking naturally and the app is converting my speech to text in real time",
                text: "hello this is a test transcription im speaking naturally and the app is converting my speech to text in real time",
                mode: .raw,
                provider: .openAI,
                duration: 12.5,
                estimatedCost: 0.0012,
                costBreakdown: CostBreakdown(
                    transcriptionCost: 0.0012,
                    formattingCost: 0,
                    translationCost: nil,
                    inputTokens: nil,
                    outputTokens: nil
                )
            ),

            // 2. Email formatted (shows input vs output transformation)
            TranscriptionRecord(
                rawTranscribedText: "hey can you send me the report from last week thanks also let me know when youre free for a call",
                text: "Hey, could you please send me the report from last week? Thanks! Also, let me know when you're free for a call.",
                mode: .email,
                provider: .openAI,
                duration: 25.3,
                contextId: UUID(),
                contextName: "Work",
                contextIcon: "briefcase.fill",
                estimatedCost: 0.0012,
                costBreakdown: CostBreakdown(
                    transcriptionCost: 0.0012,
                    formattingCost: 0,
                    translationCost: nil,
                    inputTokens: 127,
                    outputTokens: 89
                ),
                processingMetadata: emailMetadata
            ),

            // 3. Translated transcription
            TranscriptionRecord(
                rawTranscribedText: "this is a translation test hello how are you today",
                text: "Esto es una prueba de traducción. ¡Hola! ¿Cómo estás hoy?",
                mode: .raw,
                provider: .openAI,
                duration: 8.2,
                translated: true,
                targetLanguage: .spanish,
                estimatedCost: 0.0013,
                costBreakdown: CostBreakdown(
                    transcriptionCost: 0.0008,
                    formattingCost: 0,
                    translationCost: 0.0005,
                    inputTokens: 45,
                    outputTokens: 52
                ),
                processingMetadata: translationMetadata
            ),

            // 4. Casual mode
            TranscriptionRecord(
                rawTranscribedText: "reminder call doctor tomorrow 3pm pick up groceries on way home",
                text: "Quick reminder: Call the doctor tomorrow at 3pm and pick up groceries on the way home.",
                mode: .casual,
                provider: .openAI,
                duration: 6.1,
                estimatedCost: 0.0006,
                costBreakdown: CostBreakdown(
                    transcriptionCost: 0.0006,
                    formattingCost: 0,
                    translationCost: nil,
                    inputTokens: 32,
                    outputTokens: 45
                )
            ),

            // 5. Power Mode with full metadata
            TranscriptionRecord(
                rawTranscribedText: "meeting notes from today we discussed the q4 roadmap john mentioned we need to prioritize the mobile app sarah will handle the backend integration deadline is end of november",
                text: "# Meeting Notes - Q4 Roadmap Discussion\n\n**Date:** Today\n\n## Key Points\n- Q4 roadmap was the main topic\n- Mobile app prioritization required\n\n## Action Items\n- [ ] Sarah: Handle backend integration\n- [ ] Team: Mobile app prioritization\n\n## Deadline\n- End of November",
                mode: .raw,
                provider: .openAI,
                duration: 15.7,
                powerModeId: UUID(),
                powerModeName: "Meeting Notes",
                contextId: UUID(),
                contextName: "Work",
                contextIcon: "briefcase.fill",
                estimatedCost: 0.0104,
                costBreakdown: CostBreakdown(
                    transcriptionCost: 0.0015,
                    formattingCost: 0,
                    translationCost: nil,
                    powerModeCost: 0.0089,
                    ragCost: nil,
                    inputTokens: 850,
                    outputTokens: 420
                ),
                processingMetadata: powerModeMetadata
            )
        ]
    }
}

// MARK: - Previews
#Preview("Empty - Dark") {
    HistoryView()
        .environmentObject(SharedSettings.shared)
        .preferredColorScheme(.dark)
}

#Preview("Empty - Light") {
    HistoryView()
        .environmentObject(SharedSettings.shared)
        .preferredColorScheme(.light)
}

#Preview("With Data - Dark") {
    let settings = SharedSettings.shared
    settings.transcriptionHistory = TranscriptionRecord.sampleData
    return HistoryView()
        .environmentObject(settings)
        .preferredColorScheme(.dark)
}

#Preview("With Data - Light") {
    let settings = SharedSettings.shared
    settings.transcriptionHistory = TranscriptionRecord.sampleData
    return HistoryView()
        .environmentObject(settings)
        .preferredColorScheme(.light)
}
