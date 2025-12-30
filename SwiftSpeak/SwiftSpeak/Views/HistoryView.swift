//
//  HistoryView.swift
//  SwiftSpeak
//
//  Past transcriptions list
//

import SwiftUI

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
    @State private var showFilterSheet = false

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var hasActiveFilters: Bool {
        selectedPowerModeFilter != nil || selectedContextFilter != nil
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

                                HistoryRowView(record: record, colorScheme: colorScheme) {
                                    // Tap to copy output
                                    UIPasteboard.general.string = record.text
                                    HapticManager.success()
                                }
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
                    powerModes: settings.powerModes,
                    contexts: settings.contexts
                )
                .presentationDetents([.medium])
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

    @State private var showCopied = false

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with mode, power mode, context, translation, and time
            headerBadges

            // Input text (if different from output)
            if record.hasTransformation {
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
                if record.hasTransformation {
                    HStack {
                        Text("Output")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        if showCopied {
                            Label("Copied", systemImage: "checkmark")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.green)
                        } else {
                            Label("Tap to copy", systemImage: "doc.on.doc")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                Text(record.text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onCopy()
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCopied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showCopied = false
                    }
                }
            }

            // Footer with duration, cost badges, and provider
            costAndProviderFooter
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 8, y: 2)
        .padding(.vertical, 4)
    }

    // MARK: - Header Badges

    private var headerBadges: some View {
        HStack {
            // Mode badge
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
                Image(systemName: record.provider.icon)
                    .font(.caption2)
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
            // Input (if different from output)
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
            // Providers & Models
            SectionHeader(title: "PROVIDERS & MODELS")

            if let metadata = record.processingMetadata, !metadata.steps.isEmpty {
                VStack(spacing: 12) {
                    ForEach(metadata.steps) { step in
                        HStack {
                            Image(systemName: step.provider.icon)
                                .font(.caption)
                                .foregroundStyle(step.stepType.color)
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
                    MetadataRow(icon: record.provider.icon, label: "Transcription", value: record.provider.displayName)
                    MetadataRow(icon: record.mode.icon, label: "Mode", value: record.mode.displayName)
                    if record.translated, let lang = record.targetLanguage {
                        MetadataRow(icon: "globe", label: "Translated to", value: "\(lang.flag) \(lang.displayName)")
                    }
                }
                .padding(16)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // Parameters
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

                if let contextName = record.contextName {
                    MetadataRow(icon: "person.crop.circle", label: "Context", value: "\(record.contextIcon ?? "") \(contextName)")
                }

                if let powerModeName = record.powerModeName {
                    MetadataRow(icon: "bolt.fill", label: "Power Mode", value: powerModeName)
                }
            }
            .padding(16)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Prompts Section

    private var promptsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "PROMPTS SENT")

            if let metadata = record.processingMetadata {
                let prompts = metadata.allPrompts
                if !prompts.isEmpty {
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
                } else {
                    noPromptsCard
                }
            } else {
                noPromptsCard
            }
        }
    }

    private var noPromptsCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("No prompts recorded")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text("Prompt logging was added in a later version.")
                .font(.caption2)
                .foregroundStyle(.quaternary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

// MARK: - Preview Helpers
extension TranscriptionRecord {
    static var sampleData: [TranscriptionRecord] {
        [
            TranscriptionRecord(
                text: "Hello, this is a test transcription. I'm speaking naturally and the app is converting my speech to text in real time.",
                mode: .raw,
                provider: .openAI,
                duration: 12.5
            ),
            TranscriptionRecord(
                text: "Dear Mr. Johnson, I hope this email finds you well. I wanted to follow up on our meeting last week regarding the Q4 roadmap.",
                mode: .email,
                provider: .openAI,
                duration: 25.3
            ),
            TranscriptionRecord(
                text: "Hola, esto es una prueba de traducción al español.",
                mode: .raw,
                provider: .openAI,
                duration: 8.2,
                translated: true,
                targetLanguage: .spanish
            ),
            TranscriptionRecord(
                text: "Quick voice memo: Remember to call the doctor tomorrow at 3pm and pick up groceries on the way home.",
                mode: .casual,
                provider: .openAI,
                duration: 6.1
            ),
            TranscriptionRecord(
                text: "The committee hereby resolves to adopt the proposed amendments to the bylaws, effective immediately upon ratification.",
                mode: .formal,
                provider: .openAI,
                duration: 15.7
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
