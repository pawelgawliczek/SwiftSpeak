//
//  MacHistoryView.swift
//  SwiftSpeakMac
//
//  History view for macOS showing past transcriptions
//  Matches iOS HistoryView feature parity
//

import SwiftUI
import SwiftSpeakCore

struct MacHistoryView: View {
    @ObservedObject var settings: MacSettings
    @State private var searchText = ""
    @State private var selectedRecord: TranscriptionRecord?
    @State private var showDeleteConfirmation = false
    @State private var isSelecting = false
    @State private var selectedRecords: Set<UUID> = []

    // Interactive filters
    @State private var selectedPowerModeFilter: UUID?
    @State private var selectedContextFilter: UUID?
    @State private var selectedSourceFilter: TranscriptionSource?
    @State private var showFilterPopover = false

    private var hasActiveFilters: Bool {
        selectedPowerModeFilter != nil || selectedContextFilter != nil || selectedSourceFilter != nil
    }

    private var filteredRecords: [TranscriptionRecord] {
        var result = settings.transcriptionHistory

        // Apply power mode filter
        if let selected = selectedPowerModeFilter {
            result = result.filter { $0.powerModeId == selected }
        }

        // Apply context filter
        if let selected = selectedContextFilter {
            result = result.filter { $0.contextId == selected }
        }

        // Apply source filter
        if let source = selectedSourceFilter {
            result = result.filter { $0.source == source }
        }

        // Text search
        if !searchText.isEmpty {
            result = result.filter {
                $0.text.localizedCaseInsensitiveContains(searchText) ||
                $0.rawTranscribedText.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    var body: some View {
        HSplitView {
            // List of transcriptions
            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 8) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search transcriptions...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                    // Filter button
                    Button(action: { showFilterPopover.toggle() }) {
                        Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundStyle(hasActiveFilters ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showFilterPopover) {
                        MacHistoryFilterView(
                            selectedPowerModeId: $selectedPowerModeFilter,
                            selectedContextId: $selectedContextFilter,
                            selectedSource: $selectedSourceFilter,
                            powerModes: settings.powerModes,
                            contexts: settings.contexts
                        )
                        .frame(width: 280)
                    }

                    // Select button
                    if !settings.transcriptionHistory.isEmpty {
                        Button(action: {
                            withAnimation {
                                isSelecting.toggle()
                                if !isSelecting {
                                    selectedRecords.removeAll()
                                }
                            }
                        }) {
                            Text(isSelecting ? "Cancel" : "Select")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    // More menu
                    if !settings.transcriptionHistory.isEmpty {
                        Menu {
                            Button(action: { showDeleteConfirmation = true }) {
                                Label("Clear All History", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 24)
                    }
                }
                .padding(8)

                Divider()

                // Transcription list or empty state
                if settings.transcriptionHistory.isEmpty {
                    MacEmptyHistoryView()
                } else {
                    List(filteredRecords, selection: $selectedRecord) { record in
                        HStack(spacing: 12) {
                            // Selection checkbox
                            if isSelecting {
                                Image(systemName: selectedRecords.contains(record.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedRecords.contains(record.id) ? .blue : .secondary)
                            }

                            MacHistoryRowView(record: record)
                                .tag(record)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isSelecting {
                                toggleSelection(record.id)
                            } else {
                                selectedRecord = record
                            }
                        }
                        .contextMenu {
                            Button(action: { copyToClipboard(record.text) }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            Button(action: { selectedRecord = record }) {
                                Label("Details", systemImage: "info.circle")
                            }
                            Divider()
                            Button(role: .destructive, action: { deleteRecord(record) }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .listStyle(.inset)

                    // Selection action bar
                    if isSelecting && !selectedRecords.isEmpty {
                        HStack {
                            Button(action: {
                                selectedRecords = Set(filteredRecords.map { $0.id })
                            }) {
                                Text("Select All")
                                    .font(.caption.weight(.medium))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.blue)

                            Spacer()

                            Text("\(selectedRecords.count) selected")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button(action: { showDeleteConfirmation = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                    Text("Delete")
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                    }
                }
            }
            .frame(minWidth: 320)

            // Detail view
            if let record = selectedRecord {
                MacHistoryDetailView(record: record, settings: settings)
                    .frame(minWidth: 400)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Select a transcription")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 800, minHeight: 500)
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

    private func toggleSelection(_ id: UUID) {
        if selectedRecords.contains(id) {
            selectedRecords.remove(id)
        } else {
            selectedRecords.insert(id)
        }
    }

    private func deleteRecord(_ record: TranscriptionRecord) {
        settings.transcriptionHistory.removeAll { $0.id == record.id }
        if selectedRecord?.id == record.id {
            selectedRecord = nil
        }
    }

    private func deleteSelectedRecords() {
        settings.transcriptionHistory.removeAll { selectedRecords.contains($0.id) }
        if let selected = selectedRecord, selectedRecords.contains(selected.id) {
            selectedRecord = nil
        }
        selectedRecords.removeAll()
        isSelecting = false
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Empty History View

private struct MacEmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)

            VStack(spacing: 8) {
                Text("No Transcriptions Yet")
                    .font(.title3.weight(.semibold))

                Text("Your transcription history will appear here")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - History Row View (Enhanced with Badges)

struct MacHistoryRowView: View {
    let record: TranscriptionRecord
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header badges
            headerBadges

            // Input section (if different from output)
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

            // Output text
            VStack(alignment: .leading, spacing: 4) {
                if record.hasTransformation {
                    Text("Output")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
                Text(record.text)
                    .font(.system(size: 13))
                    .lineLimit(3)
            }

            // Footer with cost, duration, provider
            footerInfo
        }
        .padding(.vertical, 6)
    }

    // MARK: - Header Badges

    private var headerBadges: some View {
        HStack(spacing: 6) {
            // Mode badge
            HStack(spacing: 4) {
                Image(systemName: record.mode.icon)
                    .font(.caption2)
                Text(record.mode.displayName)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(.blue)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.blue.opacity(0.12), in: Capsule())

            // Power Mode badge
            if let powerModeName = record.powerModeName {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                    Text(powerModeName)
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.12), in: Capsule())
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
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.purple.opacity(0.12), in: Capsule())
            }

            // Translation badge
            if record.translated, let lang = record.targetLanguage {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.caption2)
                    Text(lang.displayName)
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.teal)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.teal.opacity(0.12), in: Capsule())
            }

            Spacer()

            // Timestamp
            Text(record.timestamp, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Footer Info

    private var footerInfo: some View {
        HStack(spacing: 8) {
            // Duration
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(formattedDuration)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)

            // Cost badges
            if let breakdown = record.costBreakdown {
                if breakdown.transcriptionCost > 0 {
                    MacCostBadge(icon: "waveform", cost: breakdown.transcriptionCost)
                }
                if let translationCost = breakdown.translationCost, translationCost > 0 {
                    MacCostBadge(icon: "globe", cost: translationCost)
                }
                if let powerModeCost = breakdown.powerModeCost, powerModeCost > 0 {
                    MacCostBadge(icon: "bolt.fill", cost: powerModeCost)
                }
            } else if let cost = record.estimatedCost, cost > 0 {
                Text(cost.formattedCostCompact)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Provider
            HStack(spacing: 4) {
                MacProviderIcon(record.provider, size: .small)
                Text(record.provider.shortName)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
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

// MARK: - Cost Badge

private struct MacCostBadge: View {
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
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(.quaternary, in: Capsule())
    }
}

// MARK: - History Detail View (Enhanced with Tabs)

struct MacHistoryDetailView: View {
    let record: TranscriptionRecord
    let settings: MacSettings
    @State private var copied = false
    @State private var selectedTab = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.timestamp, style: .date)
                        .font(.headline)
                    Text(record.timestamp, style: .time)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Copy button
                Button(action: copyText) {
                    HStack(spacing: 6) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied!" : "Copy")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(copied ? .green : .blue)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Text content section
                    textContentSection

                    // Tabbed details
                    Picker("Details", selection: $selectedTab) {
                        Text("Timing").tag(0)
                        Text("Providers").tag(1)
                        Text("Prompts").tag(2)
                        Text("Costs").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    // Tab content
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
                .padding()
            }
        }
    }

    // MARK: - Text Content Section

    private var textContentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Raw transcription (if different)
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
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            // Final output
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "text.alignleft")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("Final Output")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                }
                Text(record.text)
                    .font(.body)
                    .textSelection(.enabled)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: - Timing Section

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            MacSectionHeader(title: "PROCESSING TIMELINE")

            if let metadata = record.processingMetadata, !metadata.steps.isEmpty {
                VStack(spacing: 10) {
                    ForEach(metadata.steps) { step in
                        HStack {
                            Image(systemName: step.stepType.icon)
                                .font(.caption)
                                .foregroundStyle(step.stepType.color)
                                .frame(width: 20)

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
                            .foregroundStyle(.blue)
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("Detailed timing not available")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            MacSectionHeader(title: "AUDIO INFO")

            VStack(spacing: 10) {
                MacMetadataRow(icon: "calendar", label: "Date", value: formattedFullDate)
                MacMetadataRow(icon: "clock", label: "Duration", value: formattedDuration)
            }
            .padding(12)
            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: - Providers Section

    private var providersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            MacSectionHeader(title: "SETTINGS USED")

            VStack(spacing: 0) {
                // Mode
                MacSettingsRow(
                    icon: record.mode.icon,
                    iconColor: .blue,
                    label: "Formatting Mode",
                    value: record.mode.displayName
                )

                if let contextName = record.contextName {
                    Divider().padding(.leading, 36)
                    MacSettingsRow(
                        icon: record.contextIcon ?? "person.crop.circle",
                        iconColor: .purple,
                        label: "Context",
                        value: contextName
                    )
                }

                if let powerModeName = record.powerModeName {
                    Divider().padding(.leading, 36)
                    MacSettingsRow(
                        icon: "bolt.fill",
                        iconColor: .orange,
                        label: "Power Mode",
                        value: powerModeName
                    )
                }

                if record.translated, let lang = record.targetLanguage {
                    Divider().padding(.leading, 36)
                    MacSettingsRow(
                        icon: "globe",
                        iconColor: .teal,
                        label: "Translation",
                        value: "\(lang.flag) \(lang.displayName)"
                    )
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            MacSectionHeader(title: "PROVIDERS & MODELS")

            if let metadata = record.processingMetadata, !metadata.steps.isEmpty {
                VStack(spacing: 10) {
                    ForEach(metadata.steps) { step in
                        HStack {
                            MacProviderIcon(step.provider, size: .small)

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
                .padding(12)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    HStack {
                        MacProviderIcon(record.provider, size: .small)

                        Text("Transcription")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(record.provider.displayName)
                            .font(.subheadline)
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            // Parameters
            if let metadata = record.processingMetadata {
                if metadata.sourceLanguageHint != nil ||
                   (metadata.vocabularyApplied?.isEmpty == false) ||
                   (metadata.memorySourcesUsed?.isEmpty == false) {

                    MacSectionHeader(title: "PARAMETERS")

                    VStack(spacing: 10) {
                        if let lang = metadata.sourceLanguageHint {
                            MacMetadataRow(icon: "character.bubble", label: "Source Language", value: lang.displayName)
                        }

                        if let vocab = metadata.vocabularyApplied, !vocab.isEmpty {
                            HStack(alignment: .top) {
                                Image(systemName: "text.word.spacing")
                                    .foregroundStyle(.blue)
                                    .frame(width: 20)
                                Text("Vocabulary")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(vocab.joined(separator: ", "))
                                    .font(.subheadline.weight(.medium))
                                    .multilineTextAlignment(.trailing)
                            }
                            .font(.subheadline)
                        }

                        if let memory = metadata.memorySourcesUsed, !memory.isEmpty {
                            HStack(alignment: .top) {
                                Image(systemName: "brain")
                                    .foregroundStyle(.blue)
                                    .frame(width: 20)
                                Text("Memory Sources")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(memory.joined(separator: ", "))
                                    .font(.subheadline.weight(.medium))
                                    .multilineTextAlignment(.trailing)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    // MARK: - Prompts Section

    private var promptsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            MacSectionHeader(title: "TRANSCRIPTION CONFIG")

            VStack(spacing: 0) {
                MacPromptConfigRow(
                    icon: "waveform",
                    iconColor: .blue,
                    label: "Transcription",
                    value: record.provider.displayName
                )

                Divider().padding(.leading, 36)

                MacPromptConfigRow(
                    icon: record.mode.icon,
                    iconColor: .blue,
                    label: "Mode",
                    value: record.mode.displayName
                )

                Divider().padding(.leading, 36)

                MacPromptConfigRow(
                    icon: record.contextIcon ?? "person.crop.circle.dashed",
                    iconColor: .purple,
                    label: "Context",
                    value: record.contextName ?? "No context"
                )

                if let powerModeName = record.powerModeName {
                    Divider().padding(.leading, 36)
                    MacPromptConfigRow(
                        icon: "bolt.fill",
                        iconColor: .orange,
                        label: "Power Mode",
                        value: powerModeName
                    )
                }

                if record.translated, let lang = record.targetLanguage {
                    Divider().padding(.leading, 36)
                    MacPromptConfigRow(
                        icon: "globe",
                        iconColor: .teal,
                        label: "Translation",
                        value: "\(lang.flag) \(lang.displayName)"
                    )
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Show prompts if available
            if let metadata = record.processingMetadata {
                let prompts = metadata.allPrompts
                if !prompts.isEmpty {
                    MacSectionHeader(title: "PROMPTS SENT TO AI")

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
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 150)
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: - Costs Section

    private var costsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            MacSectionHeader(title: "COST BREAKDOWN")

            if let breakdown = record.costBreakdown, breakdown.hasCosts {
                VStack(spacing: 10) {
                    MacCostDetailRow(icon: "waveform", label: "Transcription", cost: breakdown.transcriptionCost)

                    if record.mode != .raw {
                        MacCostDetailRow(
                            icon: "text.alignleft",
                            label: "Formatting",
                            cost: breakdown.formattingCost,
                            note: breakdown.formattingCost == 0 ? "Local" : nil
                        )
                    }

                    if let translationCost = breakdown.translationCost {
                        MacCostDetailRow(icon: "globe", label: "Translation", cost: translationCost)
                    }

                    if let powerModeCost = breakdown.powerModeCost {
                        MacCostDetailRow(icon: "bolt.fill", label: "Power Mode", cost: powerModeCost)
                    }

                    Divider()

                    HStack {
                        Text("Total")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(breakdown.total.formattedCost)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.blue)
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Token usage
                if let metadata = record.processingMetadata,
                   (metadata.totalInputTokens > 0 || metadata.totalOutputTokens > 0) {
                    MacSectionHeader(title: "TOKEN USAGE")

                    VStack(spacing: 10) {
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
                    .padding(12)
                    .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.text, forType: .string)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            copied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.3)) {
                copied = false
            }
        }
    }
}

// MARK: - Supporting Views

private struct MacSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 8)
    }
}

private struct MacMetadataRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
        .font(.subheadline)
    }
}

private struct MacSettingsRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack {
            MacIconView(icon: icon, color: iconColor)
                .frame(width: 20)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
        .font(.subheadline)
        .padding(.vertical, 4)
    }
}

private struct MacPromptConfigRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack {
            MacIconView(icon: icon, color: iconColor)
                .frame(width: 20)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
        .font(.subheadline)
        .padding(.vertical, 4)
    }
}

/// Helper view that auto-detects emoji vs SF Symbol
private struct MacIconView: View {
    let icon: String
    let color: Color

    private var isEmoji: Bool {
        guard let first = icon.unicodeScalars.first else { return false }
        // Check if it's an emoji (not ASCII and not a typical SF Symbol name character)
        return !first.isASCII || icon.unicodeScalars.contains { scalar in
            // Emoji ranges
            (0x1F600...0x1F64F).contains(scalar.value) || // Emoticons
            (0x1F300...0x1F5FF).contains(scalar.value) || // Misc Symbols and Pictographs
            (0x1F680...0x1F6FF).contains(scalar.value) || // Transport and Map
            (0x1F1E0...0x1F1FF).contains(scalar.value) || // Flags
            (0x2600...0x26FF).contains(scalar.value) ||   // Misc symbols
            (0x2700...0x27BF).contains(scalar.value) ||   // Dingbats
            (0xFE00...0xFE0F).contains(scalar.value) ||   // Variation Selectors
            (0x1F900...0x1F9FF).contains(scalar.value) || // Supplemental Symbols
            (0x1FA00...0x1FA6F).contains(scalar.value) || // Chess Symbols
            (0x1FA70...0x1FAFF).contains(scalar.value) || // Symbols and Pictographs Extended-A
            (0x231A...0x231B).contains(scalar.value) ||   // Watch, Hourglass
            (0x23E9...0x23F3).contains(scalar.value) ||   // Media control symbols
            (0x23F8...0x23FA).contains(scalar.value)      // More media controls
        }
    }

    var body: some View {
        if isEmoji {
            Text(icon)
                .font(.subheadline)
        } else {
            Image(systemName: icon)
                .foregroundStyle(color)
        }
    }
}

private struct MacCostDetailRow: View {
    let icon: String
    let label: String
    let cost: Double
    var note: String? = nil

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)

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

// MARK: - Filter View

private struct MacHistoryFilterView: View {
    @Binding var selectedPowerModeId: UUID?
    @Binding var selectedContextId: UUID?
    @Binding var selectedSource: TranscriptionSource?
    let powerModes: [PowerMode]
    let contexts: [ConversationContext]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Filters")
                .font(.headline)

            // Power Mode filter
            VStack(alignment: .leading, spacing: 8) {
                Text("Power Mode")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Picker("Power Mode", selection: $selectedPowerModeId) {
                    Text("All").tag(nil as UUID?)
                    ForEach(powerModes) { mode in
                        Text(mode.name).tag(mode.id as UUID?)
                    }
                }
                .labelsHidden()
            }

            // Context filter
            VStack(alignment: .leading, spacing: 8) {
                Text("Context")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Picker("Context", selection: $selectedContextId) {
                    Text("All").tag(nil as UUID?)
                    ForEach(contexts) { context in
                        Text("\(context.icon ?? "") \(context.name)").tag(context.id as UUID?)
                    }
                }
                .labelsHidden()
            }

            // Source filter
            VStack(alignment: .leading, spacing: 8) {
                Text("Source")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Picker("Source", selection: $selectedSource) {
                    Text("All").tag(nil as TranscriptionSource?)
                    ForEach([TranscriptionSource.app, .swiftLink, .keyboardAI, .edit, .prediction], id: \.self) { source in
                        Text(source.displayName).tag(source as TranscriptionSource?)
                    }
                }
                .labelsHidden()
            }

            // Clear button
            if selectedPowerModeId != nil || selectedContextId != nil || selectedSource != nil {
                Button(action: clearFilters) {
                    Text("Clear Filters")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    private func clearFilters() {
        selectedPowerModeId = nil
        selectedContextId = nil
        selectedSource = nil
    }
}

// MARK: - Preview

#Preview {
    MacHistoryView(settings: MacSettings.shared)
}
