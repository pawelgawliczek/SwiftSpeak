//
//  MacHistoryView.swift
//  SwiftSpeakMac
//
//  History view for macOS showing past transcriptions
//

import SwiftUI
import SwiftSpeakCore

struct MacHistoryView: View {
    @ObservedObject var settings: MacSettings
    @State private var searchText = ""
    @State private var selectedRecord: TranscriptionRecord?

    var body: some View {
        HSplitView {
            // List of transcriptions
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search transcriptions...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1))

                Divider()

                // Transcription list
                List(filteredRecords, selection: $selectedRecord) { record in
                    HistoryRowView(record: record)
                        .tag(record)
                }
                .listStyle(.inset)
            }
            .frame(minWidth: 250)

            // Detail view
            if let record = selectedRecord {
                HistoryDetailView(record: record)
                    .frame(minWidth: 300)
            } else {
                VStack {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Select a transcription")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    private var filteredRecords: [TranscriptionRecord] {
        if searchText.isEmpty {
            return settings.transcriptionHistory
        }
        return settings.transcriptionHistory.filter { record in
            record.rawTranscribedText.localizedCaseInsensitiveContains(searchText) ||
            record.text.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - History Row View

struct HistoryRowView: View {
    let record: TranscriptionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Preview text
            Text(record.text)
                .font(.system(size: 13))
                .lineLimit(2)
                .foregroundStyle(.primary)

            // Metadata
            HStack {
                Text(record.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // Cost badge (if available)
                if let cost = record.estimatedCost, cost > 0 {
                    Text(cost.formattedCost)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15), in: Capsule())
                }

                Text(formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var formattedDuration: String {
        let minutes = Int(record.duration) / 60
        let seconds = Int(record.duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

// MARK: - History Detail View

struct HistoryDetailView: View {
    let record: TranscriptionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(record.timestamp, style: .date)
                        .font(.headline)
                    Text(record.timestamp, style: .time)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Copy button
                Button(action: copyToClipboard) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.top)

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Formatted/Translated text
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Result")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(record.text)
                            .font(.body)
                            .textSelection(.enabled)
                    }

                    // Original transcription (if different)
                    if record.text != record.rawTranscribedText {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Original Transcription")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            Text(record.rawTranscribedText)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }

                    // Metadata
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Details")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        HStack {
                            Label(record.provider.displayName, systemImage: "waveform")
                            Spacer()
                            Text("Duration: \(formattedDuration)")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    // Cost Breakdown (if available)
                    if let breakdown = record.costBreakdown, breakdown.hasCosts {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Cost Breakdown")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                Spacer()
                                Text(breakdown.total.formattedCost)
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(.green)
                            }

                            VStack(spacing: 6) {
                                if breakdown.transcriptionCost > 0 {
                                    CostRow(label: "Transcription", cost: breakdown.transcriptionCost, icon: "waveform", color: .blue)
                                }
                                if breakdown.formattingCost > 0 {
                                    CostRow(label: "Formatting", cost: breakdown.formattingCost, icon: "text.alignleft", color: .purple)
                                }
                                if let translationCost = breakdown.translationCost, translationCost > 0 {
                                    CostRow(label: "Translation", cost: translationCost, icon: "globe", color: .green)
                                }
                                if let powerModeCost = breakdown.powerModeCost, powerModeCost > 0 {
                                    CostRow(label: "Power Mode", cost: powerModeCost, icon: "bolt.fill", color: .orange)
                                }
                                if let ragCost = breakdown.ragCost, ragCost > 0 {
                                    CostRow(label: "RAG", cost: ragCost, icon: "doc.text.magnifyingglass", color: .cyan)
                                }
                            }

                            if let wordCount = breakdown.wordCount {
                                Text("\(wordCount) words")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var formattedDuration: String {
        let minutes = Int(record.duration) / 60
        let seconds = Int(record.duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.text, forType: .string)
    }
}

// MARK: - Cost Row

private struct CostRow: View {
    let label: String
    let cost: Double
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 16)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(cost.formattedCost)
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .font(.caption)
    }
}

// MARK: - Preview

#Preview {
    MacHistoryView(settings: MacSettings.shared)
}
