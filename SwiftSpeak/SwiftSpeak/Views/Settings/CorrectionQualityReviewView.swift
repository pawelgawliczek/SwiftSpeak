//
//  CorrectionQualityReviewView.swift
//  SwiftSpeak
//
//  Debug view for reviewing autocorrection quality.
//  Allows marking corrections as good/bad and adding comments.
//

import SwiftUI

struct CorrectionQualityReviewView: View {
    @StateObject private var service = CorrectionQualityReviewService.shared
    @State private var selectedEntry: CorrectionQualityEntry?
    @State private var showExportSheet = false
    @State private var exportedJSON = ""
    @State private var filterRating: CorrectionQualityRating?
    @State private var filterType: CorrectionType?
    @State private var showClearConfirmation = false

    var body: some View {
        List {
            statsSection
            typeStatsSection
            filterSection
            entriesSection
        }
        .navigationTitle("Correction Quality")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Export All") {
                        exportedJSON = service.exportAsJSON()
                        showExportSheet = true
                    }
                    Button("Export Rated Only") {
                        exportedJSON = service.exportRatedEntriesAsJSON()
                        showExportSheet = true
                    }
                    Divider()
                    Button("Clear All", role: .destructive) {
                        showClearConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            service.loadEntries()
        }
        .sheet(item: $selectedEntry) { entry in
            EntryDetailSheet(entry: entry, service: service)
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(json: exportedJSON)
        }
        .alert("Clear All Entries?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                service.clearAllEntries()
            }
        } message: {
            Text("This will delete all \(service.totalCount) correction records. This cannot be undone.")
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        Section("Statistics") {
            HStack {
                StatBadge(label: "Total", value: service.totalCount, color: .blue)
                Spacer()
                StatBadge(label: "Good", value: service.goodCount, color: .green)
                Spacer()
                StatBadge(label: "Bad", value: service.badCount, color: .red)
                Spacer()
                StatBadge(label: "Pending", value: service.pendingCount, color: .gray)
            }
            .padding(.vertical, 4)

            if service.goodCount + service.badCount > 0 {
                HStack {
                    Text("Quality Score:")
                    Spacer()
                    Text("\(service.goodPercentage, specifier: "%.1f")%")
                        .fontWeight(.semibold)
                        .foregroundStyle(service.goodPercentage >= 80 ? .green : service.goodPercentage >= 50 ? .orange : .red)
                }
            }
        }
    }

    // MARK: - Type Stats Section

    private var typeStatsSection: some View {
        Section("By Type") {
            HStack {
                TypeStatBadge(
                    type: .autocorrected,
                    count: service.autocorrectedCount,
                    isSelected: filterType == .autocorrected
                ) {
                    filterType = filterType == .autocorrected ? nil : .autocorrected
                }
                Spacer()
                TypeStatBadge(
                    type: .skipped,
                    count: service.skippedCount,
                    isSelected: filterType == .skipped
                ) {
                    filterType = filterType == .skipped ? nil : .skipped
                }
                Spacer()
                TypeStatBadge(
                    type: .reported,
                    count: service.reportedCount,
                    isSelected: filterType == .reported
                ) {
                    filterType = filterType == .reported ? nil : .reported
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        Section("Filter by Rating") {
            Picker("Show", selection: $filterRating) {
                Text("All").tag(CorrectionQualityRating?.none)
                ForEach(CorrectionQualityRating.allCases, id: \.self) { rating in
                    Label(rating.displayName, systemImage: rating.icon)
                        .tag(CorrectionQualityRating?.some(rating))
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Entries Section

    private var entriesSection: some View {
        Section("Corrections (\(filteredEntries.count))") {
            if filteredEntries.isEmpty {
                ContentUnavailableView(
                    "No Corrections",
                    systemImage: "textformat.abc",
                    description: Text("Type in the keyboard to generate autocorrections")
                )
            } else {
                ForEach(filteredEntries) { entry in
                    EntryRow(entry: entry, service: service) {
                        selectedEntry = entry
                    }
                }
            }
        }
    }

    private var filteredEntries: [CorrectionQualityEntry] {
        var result = service.entries

        // Filter by type if selected
        if let typeFilter = filterType {
            result = result.filter { $0.effectiveType == typeFilter }
        }

        // Filter by rating if selected
        if let ratingFilter = filterRating {
            result = result.filter { $0.rating == ratingFilter }
        }

        return result
    }
}

// MARK: - Type Stat Badge

private struct TypeStatBadge: View {
    let type: CorrectionType
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.system(size: 16))
                Text("\(count)")
                    .font(.headline)
                Text(type.displayName)
                    .font(.caption2)
            }
            .foregroundStyle(isSelected ? .white : type.color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isSelected ? type.color : type.color.opacity(0.1),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Entry Row

private struct EntryRow: View {
    let entry: CorrectionQualityEntry
    let service: CorrectionQualityReviewService
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                // Correction display
                HStack {
                    Text(entry.originalWord)
                        .strikethrough()
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(entry.correctedWord)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: entry.rating.icon)
                        .foregroundStyle(ratingColor)
                }

                // Context
                if !entry.contextBefore.isEmpty {
                    Text("...\(entry.contextBefore)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Metadata
                HStack(spacing: 6) {
                    // Type badge
                    HStack(spacing: 2) {
                        Image(systemName: entry.effectiveType.icon)
                            .font(.system(size: 8))
                        Text(entry.effectiveType.displayName)
                            .font(.caption2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(entry.effectiveType.color.opacity(0.2))
                    .foregroundStyle(entry.effectiveType.color)
                    .clipShape(Capsule())

                    // Language badge
                    Text(entry.language.uppercased())
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(Capsule())

                    Text(entry.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let comment = entry.comment, !comment.isEmpty {
                        Image(systemName: "text.bubble")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                service.setRating(.good, for: entry.id)
            } label: {
                Label("Good", systemImage: "checkmark")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                service.setRating(.bad, for: entry.id)
            } label: {
                Label("Bad", systemImage: "xmark")
            }
            .tint(.red)
        }
    }

    private var ratingColor: Color {
        switch entry.rating {
        case .pending: return .gray
        case .good: return .green
        case .bad: return .red
        }
    }
}

// MARK: - Entry Detail Sheet

private struct EntryDetailSheet: View {
    let entry: CorrectionQualityEntry
    let service: CorrectionQualityReviewService
    @Environment(\.dismiss) private var dismiss
    @State private var comment: String = ""
    @State private var rating: CorrectionQualityRating = .pending

    var body: some View {
        NavigationStack {
            Form {
                Section("Correction") {
                    LabeledContent("Original") {
                        Text(entry.originalWord)
                            .fontWeight(.medium)
                    }
                    LabeledContent(entry.effectiveType == .skipped ? "Suggestion" : "Corrected") {
                        Text(entry.correctedWord)
                            .fontWeight(.medium)
                    }
                    LabeledContent("Type") {
                        HStack(spacing: 4) {
                            Image(systemName: entry.effectiveType.icon)
                            Text(entry.effectiveType.displayName)
                        }
                        .foregroundStyle(entry.effectiveType.color)
                    }
                    if let skipReason = entry.skipReason {
                        LabeledContent("Skip Reason") {
                            Text(skipReason.displayName)
                                .foregroundStyle(.orange)
                        }
                    }
                    LabeledContent("Language") {
                        Text(entry.language.uppercased())
                    }
                    LabeledContent("Time") {
                        Text(entry.timestamp, style: .date)
                        Text(entry.timestamp, style: .time)
                    }
                }

                if !entry.contextBefore.isEmpty {
                    Section("Context") {
                        Text("...\(entry.contextBefore) [\(entry.originalWord)]")
                            .font(.body)
                    }
                }

                Section("Rating") {
                    Picker("Quality", selection: $rating) {
                        ForEach(CorrectionQualityRating.allCases, id: \.self) { r in
                            Label(r.displayName, systemImage: r.icon)
                                .tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Comment") {
                    TextField("Add notes (e.g., 'should not correct proper nouns')", text: $comment, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Review Correction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = entry
                        updated.rating = rating
                        updated.comment = comment.isEmpty ? nil : comment
                        service.updateEntry(updated)
                        dismiss()
                    }
                }
            }
            .onAppear {
                rating = entry.rating
                comment = entry.comment ?? ""
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Export Sheet

private struct ExportSheet: View {
    let json: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(json)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Exported JSON")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        UIPasteboard.general.string = json
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CorrectionQualityReviewView()
    }
}
